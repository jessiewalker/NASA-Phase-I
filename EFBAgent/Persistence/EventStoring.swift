//
//  EventStoring.swift
//  EFB Agent
//
//  Protocol for event storage
//

import Foundation

protocol EventStoring: Sendable {
    func append(_ event: AgentEvent) async throws
    func fetchBatch(limit: Int) async throws -> [AgentEvent]
    func markUploaded(ids: [UUID]) async throws
    func countPending() async throws -> Int
    func prune(retentionDays: Int) async throws
    func estimatePendingBytes() async throws -> Int64
    func getStoreSize() async throws -> Int64
    func deleteUploadedEvents() async throws
    func deleteAllEvents() async throws
    
    // Query APIs for browsing
    func fetchPage(limit: Int, offset: Int, filters: EventFilters?) async throws -> [AgentEvent]
    func fetchById(_ id: UUID) async throws -> AgentEvent?
    func fetchDateRange(start: Date, end: Date, limit: Int) async throws -> [AgentEvent]
    func fetchCountsBySeverityAndCategory(dateRange: (start: Date, end: Date)?) async throws -> EventCounts
    
    // Extended query APIs for DB Inspector
    func fetchEvents(limit: Int, offset: Int, filters: EventFilters?, sort: EventSort) async throws -> [AgentEvent]
    func fetchEventsSince(_ timestamp: Date, limit: Int, filters: EventFilters?) async throws -> [AgentEvent]
    func fetchEventById(_ eventId: UUID) async throws -> AgentEvent?
    func countEvents(filters: EventFilters?) async throws -> Int
    func listTables() async throws -> [TableInfo]
    func tableSchema(_ tableName: String) async throws -> String
    func fetchTableRows(_ tableName: String, limit: Int, offset: Int) async throws -> [TableRow]
    func getDBHealth() async throws -> DBHealth
    func executeQuery(_ sql: String, limit: Int) async throws -> String
}

struct EventFilters {
    var severity: EventSeverity?
    var category: EventCategory?
    var source: EventSource?
    var uploaded: Bool?
    var searchText: String?
    var startDate: Date?
    var endDate: Date?
}

struct EventCounts {
    var bySeverity: [EventSeverity: Int]
    var byCategory: [EventCategory: Int]
    var total: Int
}

enum EventSort {
    case timestampAsc
    case timestampDesc
    case sequenceNumberAsc
    case sequenceNumberDesc
}

struct DBHealth {
    let userVersion: Int
    let pageCount: Int
    let freelistCount: Int
    let integrityCheck: String?
}

struct TableInfo {
    let name: String
    let rowCount: Int
}

struct TableRow {
    let columns: [String: Any]
}

