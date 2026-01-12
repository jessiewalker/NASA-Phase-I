//
//  EventStore.swift
//  EFB Agent
//
//  SQLite-based event storage with encryption support
//

import Foundation
import Dispatch
@preconcurrency import GRDB

actor EventStore: EventStoring {
    private let dbQueue: DatabaseQueue
    private let queue = DispatchQueue(label: "com.efbagent.EventStore", qos: .utility)
    
    init(dbPath: String? = nil) throws {
        let path = dbPath ?? Self.defaultDBPath()
        dbQueue = try DatabaseQueue(path: path)
        try setupSchema()
    }
    
    private static func defaultDBPath() -> String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("events.db").path
    }
    
    private func setupSchema() throws {
        try dbQueue.write { db in
            try db.execute(sql: """
                CREATE TABLE IF NOT EXISTS events (
                    id TEXT PRIMARY KEY,
                    device_id TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    category TEXT NOT NULL,
                    severity TEXT NOT NULL,
                    name TEXT NOT NULL,
                    attributes BLOB NOT NULL,
                    source TEXT NOT NULL,
                    sequence_number INTEGER NOT NULL,
                    uploaded INTEGER NOT NULL DEFAULT 0
                )
            """)
            
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_uploaded ON events(uploaded)")
            try db.execute(sql: "CREATE INDEX IF NOT EXISTS idx_created_at ON events(created_at)")
        }
    }
    
    func append(_ event: AgentEvent) async throws {
        // Validate timestamp is valid (guard against invalid dates)
        let timestampValue = event.timestamp.timeIntervalSince1970
        guard timestampValue.isFinite && timestampValue > 0 else {
            throw NSError(domain: "EventStore", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid event timestamp: \(event.timestamp)"])
        }
        
        // Store full event JSON in attributes field (encrypted) to preserve eventId
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let eventData = try encoder.encode(event)
        let encryption = EventEncryption()
        let encryptedData = try await encryption.encrypt(eventData)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    try self.dbQueue.write { db in
                        try db.execute(
                            sql: """
                                INSERT INTO events (id, device_id, created_at, category, severity, name, attributes, source, sequence_number, uploaded)
                                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0)
                            """,
                            arguments: [
                                event.eventId.uuidString,
                                event.deviceId,
                                timestampValue,
                                event.category.rawValue,
                                event.severity.rawValue,
                                event.name,
                                encryptedData,
                                event.source.rawValue,
                                event.sequenceNumber
                            ]
                        )
                    }
                    continuation.resume()
                } catch {
                    // Enhanced error logging to diagnose SQLite issues
                    let errorDescription = "SQLite error inserting event (ID: \(event.eventId.uuidString), timestamp: \(timestampValue)): \(error.localizedDescription)"
                    continuation.resume(throwing: NSError(domain: "EventStore", code: 2, userInfo: [
                        NSLocalizedDescriptionKey: errorDescription,
                        NSUnderlyingErrorKey: error
                    ]))
                }
            }
        }
    }
    
    func fetchBatch(limit: Int) async throws -> [AgentEvent] {
        // Fetch IDs and encrypted event data (attributes field contains encrypted full event JSON)
        let rows = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[(id: UUID, encryptedData: Data)], Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let rows = try self.dbQueue.read { db in
                        try Row.fetchAll(
                            db,
                            sql: "SELECT id, attributes FROM events WHERE uploaded = 0 ORDER BY created_at ASC LIMIT ?",
                            arguments: [limit]
                        )
                    }
                    
                    let idAndData = rows.compactMap { row -> (UUID, Data)? in
                        guard let idString = row["id"] as String?,
                              let eventId = UUID(uuidString: idString),
                              let encryptedData = row["attributes"] as Data? else {
                            return nil
                        }
                        return (eventId, encryptedData)
                    }
                    continuation.resume(returning: idAndData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // Decrypt and reconstruct events (attributes field contains encrypted full event JSON)
        let encryption = EventEncryption()
        var events: [AgentEvent] = []
        
        for (_, encryptedData) in rows {
            do {
                let decryptedData = try await encryption.decrypt(encryptedData)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                // Decode full event (preserves original eventId)
                let event = try decoder.decode(AgentEvent.self, from: decryptedData)
                events.append(event)
            } catch {
                // Skip events that can't be decrypted/decoded
                continue
            }
        }
        
        return events
    }
    
    func markUploaded(ids: [UUID]) async throws {
        let idStrings = ids.map { $0.uuidString }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    try self.dbQueue.write { db in
                        for idString in idStrings {
                            try db.execute(
                                sql: "UPDATE events SET uploaded = 1 WHERE id = ?",
                                arguments: [idString]
                            )
                        }
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func countPending() async throws -> Int {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let count = try self.dbQueue.read { db in
                        try Int.fetchOne(
                            db,
                            sql: "SELECT COUNT(*) FROM events WHERE uploaded = 0"
                        ) ?? 0
                    }
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func prune(retentionDays: Int) async throws {
        let cutoffDate = Date().addingTimeInterval(-Double(retentionDays * 24 * 60 * 60))
        let cutoffTimestamp = cutoffDate.timeIntervalSince1970
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    try self.dbQueue.write { db in
                        try db.execute(
                            sql: "DELETE FROM events WHERE uploaded = 1 AND created_at < ?",
                            arguments: [cutoffTimestamp]
                        )
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func estimatePendingBytes() async throws -> Int64 {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int64, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let bytes = try self.dbQueue.read { db in
                        let count = try Int.fetchOne(
                            db,
                            sql: "SELECT COUNT(*) FROM events WHERE uploaded = 0"
                        ) ?? 0
                        return Int64(count * 2048) // Estimate ~2KB per event
                    }
                    continuation.resume(returning: bytes)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getStoreSize() async throws -> Int64 {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int64, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let path = Self.defaultDBPath()
                    let attributes = try FileManager.default.attributesOfItem(atPath: path)
                    let size = attributes[.size] as? Int64 ?? 0
                    continuation.resume(returning: size)
                } catch {
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    func deleteUploadedEvents() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    try self.dbQueue.write { db in
                        try db.execute(sql: "DELETE FROM events WHERE uploaded = 1")
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func deleteAllEvents() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    try self.dbQueue.write { db in
                        try db.execute(sql: "DELETE FROM events")
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Query APIs for browsing
    
    func fetchPage(limit: Int, offset: Int, filters: EventFilters?) async throws -> [AgentEvent] {
        var conditions: [String] = []
        var arguments: [any DatabaseValueConvertible] = []
        
        if let filters = filters {
            if let severity = filters.severity {
                conditions.append("severity = ?")
                arguments.append(severity.rawValue)
            }
            if let category = filters.category {
                conditions.append("category = ?")
                arguments.append(category.rawValue)
            }
            if let source = filters.source {
                conditions.append("source = ?")
                arguments.append(source.rawValue)
            }
            if let uploaded = filters.uploaded {
                conditions.append("uploaded = ?")
                arguments.append(uploaded ? 1 : 0)
            }
            if let searchText = filters.searchText, !searchText.isEmpty {
                conditions.append("name LIKE ?")
                arguments.append("%\(searchText)%")
            }
        }
        
        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
        arguments.append(limit)
        arguments.append(offset)
        let sql = "SELECT id, attributes FROM events \(whereClause) ORDER BY created_at DESC LIMIT ? OFFSET ?"
        
        let rows = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[(id: UUID, encryptedData: Data)], Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let rows = try self.dbQueue.read { db in
                        try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
                    }
                    
                    let idAndData = rows.compactMap { row -> (UUID, Data)? in
                        guard let idString = row["id"] as String?,
                              let eventId = UUID(uuidString: idString),
                              let encryptedData = row["attributes"] as Data? else {
                            return nil
                        }
                        return (eventId, encryptedData)
                    }
                    continuation.resume(returning: idAndData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // Decrypt and reconstruct events
        let encryption = EventEncryption()
        var events: [AgentEvent] = []
        
        for (_, encryptedData) in rows {
            do {
                let decryptedData = try await encryption.decrypt(encryptedData)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let event = try decoder.decode(AgentEvent.self, from: decryptedData)
                events.append(event)
            } catch {
                continue
            }
        }
        
        return events
    }
    
    func fetchById(_ id: UUID) async throws -> AgentEvent? {
        let idString = id.uuidString
        let row = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<(UUID, Data)?, Error>) in
            queue.async {
                do {
                    let row = try self.dbQueue.read { db in
                        try Row.fetchOne(
                            db,
                            sql: "SELECT id, attributes FROM events WHERE id = ?",
                            arguments: [idString]
                        )
                    }
                    
                    guard let row = row,
                          let idString = row["id"] as String?,
                          let eventId = UUID(uuidString: idString),
                          let encryptedData = row["attributes"] as Data? else {
                        continuation.resume(returning: nil)
                        return
                    }
                    continuation.resume(returning: (eventId, encryptedData))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        guard let (_, encryptedData) = row else { return nil }
        
        let encryption = EventEncryption()
        let decryptedData = try await encryption.decrypt(encryptedData)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AgentEvent.self, from: decryptedData)
    }
    
    func fetchDateRange(start: Date, end: Date, limit: Int) async throws -> [AgentEvent] {
        let startTimestamp = start.timeIntervalSince1970
        let endTimestamp = end.timeIntervalSince1970
        
        let rows = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[(id: UUID, encryptedData: Data)], Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let rows = try self.dbQueue.read { db in
                        try Row.fetchAll(
                            db,
                            sql: "SELECT id, attributes FROM events WHERE created_at >= ? AND created_at <= ? ORDER BY created_at DESC LIMIT ?",
                            arguments: [startTimestamp, endTimestamp, limit]
                        )
                    }
                    
                    let idAndData = rows.compactMap { row -> (UUID, Data)? in
                        guard let idString = row["id"] as String?,
                              let eventId = UUID(uuidString: idString),
                              let encryptedData = row["attributes"] as Data? else {
                            return nil
                        }
                        return (eventId, encryptedData)
                    }
                    continuation.resume(returning: idAndData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // Decrypt and reconstruct events
        let encryption = EventEncryption()
        var events: [AgentEvent] = []
        
        for (_, encryptedData) in rows {
            do {
                let decryptedData = try await encryption.decrypt(encryptedData)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let event = try decoder.decode(AgentEvent.self, from: decryptedData)
                events.append(event)
            } catch {
                continue
            }
        }
        
        return events
    }
    
    func fetchCountsBySeverityAndCategory(dateRange: (start: Date, end: Date)?) async throws -> EventCounts {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<EventCounts, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    var whereClause = ""
                    var arguments: [any DatabaseValueConvertible] = []
                    
                    if let dateRange = dateRange {
                        whereClause = "WHERE created_at >= ? AND created_at <= ?"
                        arguments.append(dateRange.start.timeIntervalSince1970)
                        arguments.append(dateRange.end.timeIntervalSince1970)
                    }
                    
                    // Count by severity
                    var severityCounts: [EventSeverity: Int] = [:]
                    for severity in EventSeverity.allCases {
                        let severityWhere = whereClause.isEmpty ? "WHERE severity = ?" : "\(whereClause) AND severity = ?"
                        let sql = "SELECT COUNT(*) FROM events \(severityWhere)"
                        var args = arguments
                        args.append(severity.rawValue)
                        let count = try self.dbQueue.read { db in
                            try Int.fetchOne(db, sql: sql, arguments: StatementArguments(args)) ?? 0
                        }
                        severityCounts[severity] = count
                    }
                    
                    // Count by category
                    var categoryCounts: [EventCategory: Int] = [:]
                    for category in EventCategory.allCases {
                        let categoryWhere = whereClause.isEmpty ? "WHERE category = ?" : "\(whereClause) AND category = ?"
                        let sql = "SELECT COUNT(*) FROM events \(categoryWhere)"
                        var args = arguments
                        args.append(category.rawValue)
                        let count = try self.dbQueue.read { db in
                            try Int.fetchOne(db, sql: sql, arguments: StatementArguments(args)) ?? 0
                        }
                        categoryCounts[category] = count
                    }
                    
                    // Total count
                    let totalSql = "SELECT COUNT(*) FROM events \(whereClause)"
                    let total = try self.dbQueue.read { db in
                        try Int.fetchOne(db, sql: totalSql, arguments: StatementArguments(arguments)) ?? 0
                    }
                    
                    continuation.resume(returning: EventCounts(
                        bySeverity: severityCounts,
                        byCategory: categoryCounts,
                        total: total
                    ))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Extended Query APIs for DB Inspector
    
    func fetchEvents(limit: Int, offset: Int, filters: EventFilters?, sort: EventSort) async throws -> [AgentEvent] {
        var conditions: [String] = []
        var arguments: [any DatabaseValueConvertible] = []
        
        if let filters = filters {
            if let severity = filters.severity {
                conditions.append("severity = ?")
                arguments.append(severity.rawValue)
            }
            if let category = filters.category {
                conditions.append("category = ?")
                arguments.append(category.rawValue)
            }
            if let source = filters.source {
                conditions.append("source = ?")
                arguments.append(source.rawValue)
            }
            if let uploaded = filters.uploaded {
                conditions.append("uploaded = ?")
                arguments.append(uploaded ? 1 : 0)
            }
            if let startDate = filters.startDate {
                conditions.append("created_at >= ?")
                arguments.append(startDate.timeIntervalSince1970)
            }
            if let endDate = filters.endDate {
                conditions.append("created_at <= ?")
                arguments.append(endDate.timeIntervalSince1970)
            }
            if let searchText = filters.searchText, !searchText.isEmpty {
                conditions.append("name LIKE ?")
                arguments.append("%\(searchText)%")
            }
        }
        
        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
        
        let orderClause: String
        switch sort {
        case .timestampAsc: orderClause = "ORDER BY created_at ASC"
        case .timestampDesc: orderClause = "ORDER BY created_at DESC"
        case .sequenceNumberAsc: orderClause = "ORDER BY sequence_number ASC"
        case .sequenceNumberDesc: orderClause = "ORDER BY sequence_number DESC"
        }
        
        arguments.append(limit)
        arguments.append(offset)
        let sql = "SELECT id, attributes FROM events \(whereClause) \(orderClause) LIMIT ? OFFSET ?"
        
        let rows = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[(id: UUID, encryptedData: Data)], Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let rows = try self.dbQueue.read { db in
                        try Row.fetchAll(db, sql: sql, arguments: StatementArguments(arguments))
                    }
                    
                    let idAndData = rows.compactMap { row -> (UUID, Data)? in
                        guard let idString = row["id"] as String?,
                              let eventId = UUID(uuidString: idString),
                              let encryptedData = row["attributes"] as Data? else {
                            return nil
                        }
                        return (eventId, encryptedData)
                    }
                    continuation.resume(returning: idAndData)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
        
        // Decrypt and reconstruct events
        let encryption = EventEncryption()
        var events: [AgentEvent] = []
        
        for (_, encryptedData) in rows {
            do {
                let decryptedData = try await encryption.decrypt(encryptedData)
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let event = try decoder.decode(AgentEvent.self, from: decryptedData)
                events.append(event)
            } catch {
                continue
            }
        }
        
        return events
    }
    
    func fetchEventsSince(_ timestamp: Date, limit: Int, filters: EventFilters?) async throws -> [AgentEvent] {
        var filters = filters ?? EventFilters()
        filters.startDate = timestamp
        return try await fetchEvents(limit: limit, offset: 0, filters: filters, sort: .timestampAsc)
    }
    
    func fetchEventById(_ eventId: UUID) async throws -> AgentEvent? {
        return try await fetchById(eventId)
    }
    
    func countEvents(filters: EventFilters?) async throws -> Int {
        var conditions: [String] = []
        var arguments: [any DatabaseValueConvertible] = []
        
        if let filters = filters {
            if let severity = filters.severity {
                conditions.append("severity = ?")
                arguments.append(severity.rawValue)
            }
            if let category = filters.category {
                conditions.append("category = ?")
                arguments.append(category.rawValue)
            }
            if let source = filters.source {
                conditions.append("source = ?")
                arguments.append(source.rawValue)
            }
            if let uploaded = filters.uploaded {
                conditions.append("uploaded = ?")
                arguments.append(uploaded ? 1 : 0)
            }
            if let startDate = filters.startDate {
                conditions.append("created_at >= ?")
                arguments.append(startDate.timeIntervalSince1970)
            }
            if let endDate = filters.endDate {
                conditions.append("created_at <= ?")
                arguments.append(endDate.timeIntervalSince1970)
            }
            if let searchText = filters.searchText, !searchText.isEmpty {
                conditions.append("name LIKE ?")
                arguments.append("%\(searchText)%")
            }
        }
        
        let whereClause = conditions.isEmpty ? "" : "WHERE \(conditions.joined(separator: " AND "))"
        let sql = "SELECT COUNT(*) FROM events \(whereClause)"
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let count = try self.dbQueue.read { db in
                        try Int.fetchOne(db, sql: sql, arguments: StatementArguments(arguments)) ?? 0
                    }
                    continuation.resume(returning: count)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func listTables() async throws -> [TableInfo] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[TableInfo], Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let tables = try self.dbQueue.read { db -> [TableInfo] in
                        let rows = try Row.fetchAll(db, sql: """
                            SELECT name FROM sqlite_master 
                            WHERE type='table' AND name NOT LIKE 'sqlite_%'
                            ORDER BY name
                        """)
                        
                        return try rows.compactMap { row -> TableInfo? in
                            guard let tableName = row["name"] as String? else {
                                return nil
                            }
                            
                            // Sanitize table name for COUNT query
                            let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
                            guard tableName.unicodeScalars.allSatisfy({ allowedChars.contains($0) }) else {
                                throw NSError(domain: "EventStore", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid table name: \(tableName)"])
                            }
                            
                            let count = try Int.fetchOne(
                                db,
                                sql: "SELECT COUNT(*) FROM \(tableName)"
                            ) ?? 0
                            return TableInfo(name: tableName, rowCount: count)
                        }
                    }
                    continuation.resume(returning: tables)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func tableSchema(_ tableName: String) async throws -> String {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let sql = try self.dbQueue.read { db -> String in
                        guard let row = try Row.fetchOne(
                            db,
                            sql: "SELECT sql FROM sqlite_master WHERE type='table' AND name = ?",
                            arguments: [tableName]
                        ),
                        let createSQL = row["sql"] as String? else {
                            throw NSError(domain: "EventStore", code: 404, userInfo: [NSLocalizedDescriptionKey: "Table not found"])
                        }
                        return createSQL
                    }
                    continuation.resume(returning: sql)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func fetchTableRows(_ tableName: String, limit: Int, offset: Int) async throws -> [TableRow] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[TableRow], Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let rows = try self.dbQueue.read { db -> [TableRow] in
                        // Sanitize table name (prevent SQL injection) - only allow alphanumeric and underscore
                        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
                        guard tableName.unicodeScalars.allSatisfy({ allowedChars.contains($0) }),
                              tableName.unicodeScalars.first.map({ CharacterSet.letters.contains($0) || $0 == "_" }) == true else {
                            throw NSError(domain: "EventStore", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid table name"])
                        }
                        
                        // Use parameterized query where possible, but table name can't be parameterized in SQLite
                        // So we validate it above and use string interpolation (safe after validation)
                        let sql = "SELECT * FROM \(tableName) LIMIT ? OFFSET ?"
                        let dbRows = try Row.fetchAll(db, sql: sql, arguments: [limit, offset])
                        
                        return dbRows.map { row in
                            var columns: [String: Any] = [:]
                            let columnNames = row.columnNames
                            for name in columnNames {
                                // Safely extract value using DatabaseValue to check type first
                                guard let dbValue = try? row[name] as DatabaseValue else {
                                    columns[name] = NSNull()
                                    continue
                                }
                                
                                // Check if NULL first
                                if dbValue.isNull {
                                    columns[name] = NSNull()
                                    continue
                                }
                                
                                // Extract value based on storage type
                                switch dbValue.storage {
                                case .blob(let data):
                                    // For BLOB data, show hex preview
                                    let hexPreview = data.prefix(64).map { String(format: "%02x", $0) }.joined()
                                    columns[name] = "BLOB (\(data.count) bytes): \(hexPreview)..."
                                case .string(let string):
                                    columns[name] = string
                                case .double(let double):
                                    columns[name] = double
                                case .int64(let int64):
                                    columns[name] = int64
                                case .null:
                                    columns[name] = NSNull()
                                }
                            }
                            return TableRow(columns: columns)
                        }
                    }
                    continuation.resume(returning: rows)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func getDBHealth() async throws -> DBHealth {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DBHealth, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    let health = try self.dbQueue.read { db -> DBHealth in
                        let userVersion = try Int.fetchOne(db, sql: "PRAGMA user_version") ?? 0
                        let pageCount = try Int.fetchOne(db, sql: "PRAGMA page_count") ?? 0
                        let freelistCount = try Int.fetchOne(db, sql: "PRAGMA freelist_count") ?? 0
                        
                        // Integrity check (best-effort, safe mode)
                        var integrityCheck: String? = nil
                        do {
                            if let result = try String.fetchOne(db, sql: "PRAGMA integrity_check") {
                                integrityCheck = result
                            }
                        } catch {
                            // Ignore integrity check errors
                        }
                        
                        return DBHealth(
                            userVersion: userVersion,
                            pageCount: pageCount,
                            freelistCount: freelistCount,
                            integrityCheck: integrityCheck
                        )
                    }
                    continuation.resume(returning: health)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func executeQuery(_ sql: String, limit: Int = 100) async throws -> String {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            queue.async(group: nil, qos: .utility, flags: []) {
                do {
                    // Validate query (read-only, SELECT only)
                    let trimmed = sql.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    guard trimmed.hasPrefix("SELECT") else {
                        continuation.resume(throwing: NSError(domain: "EventStore", code: 400, userInfo: [NSLocalizedDescriptionKey: "Only SELECT queries are allowed"]))
                        return
                    }
                    
                    // Ensure limit is enforced
                    var finalSQL = sql.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !finalSQL.uppercased().contains("LIMIT") {
                        finalSQL += " LIMIT \(limit)"
                    }
                    
                    // Execute query
                    let rows = try self.dbQueue.read { db -> [[String: Any]] in
                        let dbRows = try Row.fetchAll(db, sql: finalSQL)
                        
                        return dbRows.map { row in
                            var dict: [String: Any] = [:]
                            let columnNames = row.columnNames
                            for name in columnNames {
                                // Safely extract value using DatabaseValue to check type first
                                // This avoids decoding errors when types don't match
                                guard let dbValue = try? row[name] as DatabaseValue else {
                                    dict[name] = NSNull()
                                    continue
                                }
                                
                                // Check if NULL first
                                if dbValue.isNull {
                                    dict[name] = NSNull()
                                    continue
                                }
                                
                                // Extract value based on storage type
                                switch dbValue.storage {
                                case .blob(let data):
                                    // For BLOB data, show hex preview
                                    let hexPreview = data.prefix(64).map { String(format: "%02x", $0) }.joined()
                                    dict[name] = "BLOB (\(data.count) bytes): \(hexPreview)..."
                                case .string(let string):
                                    dict[name] = string
                                case .double(let double):
                                    dict[name] = double
                                case .int64(let int64):
                                    dict[name] = int64
                                case .null:
                                    dict[name] = NSNull()
                                }
                            }
                            return dict
                        }
                    }
                    
                    // Convert to JSON for display
                    let jsonData = try JSONSerialization.data(withJSONObject: rows, options: [.prettyPrinted, .sortedKeys])
                    if let jsonString = String(data: jsonData, encoding: .utf8) {
                        continuation.resume(returning: jsonString)
                    } else {
                        continuation.resume(returning: "Unable to format results")
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}


