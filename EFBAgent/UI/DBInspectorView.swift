//
//  DBInspectorView.swift
//  EFB Agent
//
//  SQLite database inspector with real-time updates
//

import SwiftUI

struct DBInspectorView: View {
    @EnvironmentObject var agentController: AgentController
    @StateObject private var viewModel = DBInspectorViewModel()
    @State private var selectedTab: InspectorTab = .tables
    @State private var selectedTable: String? = nil
    @State private var selectedRow: TableRow? = nil
    @State private var developerMode = false
    
    enum InspectorTab: String, CaseIterable {
        case tables = "Tables"
        case events = "Events"
        case query = "Query"
        case health = "Health"
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab selector
                Picker("View", selection: $selectedTab) {
                    ForEach(InspectorTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                // Content
                ScrollView {
                    switch selectedTab {
                    case .tables:
                        TablesView(
                            viewModel: viewModel,
                            selectedTable: $selectedTable,
                            selectedRow: $selectedRow
                        )
                    case .events:
                        EventsBrowserView(
                            viewModel: viewModel,
                            developerMode: developerMode
                        )
                    case .query:
                        QueryConsoleView(viewModel: viewModel)
                    case .health:
                        DBHealthView(viewModel: viewModel)
                    }
                }
            }
            .navigationTitle("DB Inspector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Toggle("Live", isOn: $viewModel.liveUpdates)
                        .toggleStyle(SwitchToggleStyle())
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    #if DEBUG
                    Toggle("Dev", isOn: $developerMode)
                        .toggleStyle(SwitchToggleStyle())
                    #endif
                }
            }
            .sheet(item: Binding(
                get: { selectedRow },
                set: { selectedRow = $0 }
            )) { row in
                NavigationView {
                    RowDetailView(row: row, developerMode: developerMode)
                }
            }
            .task {
                await viewModel.setup(agentController: agentController)
            }
            .onChange(of: viewModel.liveUpdates) { enabled in
                viewModel.setLiveUpdates(enabled)
            }
        }
    }
}

struct TablesView: View {
    @ObservedObject var viewModel: DBInspectorViewModel
    @Binding var selectedTable: String?
    @Binding var selectedRow: TableRow?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if viewModel.tables.isEmpty {
                Text("No tables found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.tables, id: \.name) { table in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(table.name)
                                .font(.headline)
                            Spacer()
                            Text("\(table.rowCount) rows")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("View Schema") {
                            Task {
                                await viewModel.loadSchema(tableName: table.name)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        if let schema = viewModel.schemas[table.name] {
                            ScrollView(.horizontal) {
                                Text(schema)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                        }
                        
                        Button("Browse Rows") {
                            selectedTable = table.name
                            Task {
                                await viewModel.loadTableRows(tableName: table.name, limit: 50, offset: 0)
                            }
                        }
                        .buttonStyle(.bordered)
                        
                        if selectedTable == table.name, !viewModel.tableRows.isEmpty {
                            LazyVStack(spacing: 4) {
                                ForEach(Array(viewModel.tableRows.enumerated()), id: \.offset) { index, row in
                                    TableRowView(row: row, index: index)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            selectedRow = row
                                        }
                                }
                            }
                            .padding(.vertical)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}

struct TableRowView: View {
    let row: TableRow
    let index: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Row \(index + 1)")
                .font(.caption)
                .fontWeight(.semibold)
            ForEach(Array(row.columns.keys.sorted()), id: \.self) { key in
                HStack {
                    Text(key)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(describing: row.columns[key] ?? "nil"))
                        .font(.caption2)
                        .lineLimit(2)
                }
            }
        }
        .padding(8)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct EventsBrowserView: View {
    @ObservedObject var viewModel: DBInspectorViewModel
    let developerMode: Bool
    
    @State private var searchText: String = ""
    @State private var selectedSeverity: EventSeverity? = nil
    @State private var selectedCategory: EventCategory? = nil
    @State private var selectedSource: EventSource? = nil
    @State private var selectedEvent: AgentEvent? = nil
    @State private var viewModelFilters = EventFilters()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Filters
            VStack(spacing: 12) {
                TextField("Search events...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: searchText) { newValue in
                        Task {
                            var filters = EventFilters()
                            filters.searchText = newValue.isEmpty ? nil : newValue
                            filters.severity = viewModel.selectedSeverity
                            filters.category = viewModel.selectedCategory
                            filters.source = viewModel.selectedSource
                            await viewModel.refreshEvents(filters: filters)
                        }
                    }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", isSelected: selectedSeverity == nil && selectedCategory == nil && selectedSource == nil) {
                            selectedSeverity = nil
                            selectedCategory = nil
                            selectedSource = nil
                            viewModel.selectedSeverity = nil
                            viewModel.selectedCategory = nil
                            viewModel.selectedSource = nil
                            Task {
                                var filters = EventFilters()
                                filters.searchText = searchText.isEmpty ? nil : searchText
                                await viewModel.refreshEvents(filters: filters)
                            }
                        }
                        
                        ForEach(EventSeverity.allCases, id: \.self) { severity in
                            FilterChip(title: severity.rawValue.capitalized, isSelected: selectedSeverity == severity) {
                                selectedSeverity = selectedSeverity == severity ? nil : severity
                                viewModel.selectedSeverity = selectedSeverity
                                Task {
                                    var filters = EventFilters()
                                    filters.searchText = searchText.isEmpty ? nil : searchText
                                    filters.severity = selectedSeverity
                                    filters.category = selectedCategory
                                    filters.source = selectedSource
                                    await viewModel.refreshEvents(filters: filters)
                                }
                            }
                        }
                        
                        ForEach(EventCategory.allCases, id: \.self) { category in
                            FilterChip(title: category.rawValue.capitalized, isSelected: selectedCategory == category) {
                                selectedCategory = selectedCategory == category ? nil : category
                                viewModel.selectedCategory = selectedCategory
                                Task {
                                    var filters = EventFilters()
                                    filters.searchText = searchText.isEmpty ? nil : searchText
                                    filters.severity = selectedSeverity
                                    filters.category = selectedCategory
                                    filters.source = selectedSource
                                    await viewModel.refreshEvents(filters: filters)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
            
            // Events list
            HStack {
                Text("\(viewModel.eventCount) events")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            
            if viewModel.events.isEmpty {
                Text("No events found")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(viewModel.events) { event in
                    EventBrowserRow(event: event)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedEvent = event
                        }
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.events.count)
                }
            }
        }
        .padding()
        .sheet(item: $selectedEvent) { event in
            NavigationView {
                EventDetailInspectorView(event: event, developerMode: developerMode)
            }
        }
    }
}

struct EventDetailInspectorView: View {
    let event: AgentEvent
    let developerMode: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Event ID", value: event.eventId.uuidString)
                    DetailRow(label: "Timestamp", value: formatDate(event.timestamp))
                    DetailRow(label: "Category", value: event.category.rawValue)
                    DetailRow(label: "Severity", value: event.severity.rawValue)
                    DetailRow(label: "Source", value: event.source.rawValue)
                }
                
                Divider()
                
                // Decrypted JSON (only in developer mode)
                if developerMode {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Decrypted JSON (Developer Mode)")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        ScrollView(.horizontal) {
                            Text(prettyJSON(for: event))
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                    }
                }
                
                Divider()
                
                // Redacted JSON (always visible)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Redacted JSON (Safe to Share)")
                        .font(.headline)
                    
                    let redactedEvent = AgentEvent(
                        deviceId: event.deviceId,
                        timestamp: event.timestamp,
                        category: event.category,
                        severity: event.severity,
                        name: event.name,
                        attributes: Redactor.redact(event.attributes),
                        source: event.source,
                        sequenceNumber: event.sequenceNumber
                    )
                    
                    ScrollView(.horizontal) {
                        Text(prettyJSON(for: redactedEvent))
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                    
                    Button("Copy JSON") {
                        UIPasteboard.general.string = prettyJSON(for: redactedEvent)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("Event Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
    
    private func prettyJSON(for event: AgentEvent) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        if let data = try? encoder.encode(event),
           let string = String(data: data, encoding: .utf8) {
            return string
        }
        return "Unable to encode event"
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}

struct QueryConsoleView: View {
    @ObservedObject var viewModel: DBInspectorViewModel
    @State private var queryText: String = "SELECT * FROM events LIMIT 10"
    @State private var queryResult: String = ""
    @State private var queryError: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Read-only SELECT queries (parameterized, max 100 rows)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(text: $queryText)
                .font(.system(.caption, design: .monospaced))
                .frame(height: 100)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            
            Button("Execute") {
                Task {
                    await executeQuery()
                }
            }
            .buttonStyle(.borderedProminent)
            
            if let error = queryError {
                Text("Error: \(error)")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if !queryResult.isEmpty {
                HStack {
                    Spacer()
                    Button("Copy JSON") {
                        UIPasteboard.general.string = queryResult
                    }
                    .buttonStyle(.bordered)
                }
                
                ScrollView {
                    Text(queryResult)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding()
    }
    
    private func executeQuery() async {
        queryError = nil
        queryResult = ""
        
        // Validate query (read-only, SELECT only)
        let trimmed = queryText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard trimmed.hasPrefix("SELECT") else {
            queryError = "Only SELECT queries are allowed"
            return
        }
        
        // Prevent dangerous operations (additional safety)
        let dangerousKeywords = ["INSERT", "UPDATE", "DELETE", "DROP", "CREATE", "ALTER", "ATTACH", "DETACH"]
        for keyword in dangerousKeywords {
            if trimmed.contains(keyword) {
                queryError = "Query contains forbidden keyword: \(keyword)"
                return
            }
        }
        
        // Note: limit enforcement is handled in EventStore.executeQuery
        
        // Execute via viewModel
        do {
            let result = try await viewModel.executeQuery(queryText)
            queryResult = result
            queryError = nil
        } catch {
            queryError = error.localizedDescription
            queryResult = ""
        }
    }
}

struct DBHealthView: View {
    @ObservedObject var viewModel: DBInspectorViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let health = viewModel.health {
                VStack(alignment: .leading, spacing: 12) {
                    HealthRow(label: "User Version", value: "\(health.userVersion)")
                    HealthRow(label: "Page Count", value: "\(health.pageCount)")
                    HealthRow(label: "Freelist Count", value: "\(health.freelistCount)")
                    
                    if let integrity = health.integrityCheck {
                        HealthRow(label: "Integrity Check", value: integrity)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                Text("Loading health info...")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .task {
            await viewModel.loadHealth()
        }
    }
}

struct HealthRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

@MainActor
class DBInspectorViewModel: ObservableObject {
    @Published var tables: [TableInfo] = []
    @Published var schemas: [String: String] = [:]
    @Published var tableRows: [TableRow] = []
    @Published var events: [AgentEvent] = []
    @Published var eventCount: Int = 0
    @Published var health: DBHealth? = nil
    @Published var liveUpdates: Bool = false
    @Published var selectedSeverity: EventSeverity? = nil
    @Published var selectedCategory: EventCategory? = nil
    @Published var selectedSource: EventSource? = nil
    
    private weak var agentController: AgentController?
    private var liveTimer: Timer?
    private var lastEventTimestamp: Date? = nil
    
    func setup(agentController: AgentController) async {
        self.agentController = agentController
        await refresh()
    }
    
    func refresh() async {
        await loadTables()
        await refreshEvents()
    }
    
    func loadTables() async {
        guard let store = agentController?.store else { return }
        
        do {
            tables = try await store.listTables()
        } catch {
            print("Error loading tables: \(error)")
        }
    }
    
    func loadSchema(tableName: String) async {
        guard let store = agentController?.store else { return }
        
        do {
            let schema = try await store.tableSchema(tableName)
            schemas[tableName] = schema
        } catch {
            print("Error loading schema: \(error)")
        }
    }
    
    func loadTableRows(tableName: String, limit: Int, offset: Int) async {
        guard let store = agentController?.store else { return }
        
        do {
            tableRows = try await store.fetchTableRows(tableName, limit: limit, offset: offset)
        } catch {
            print("Error loading table rows: \(error)")
        }
    }
    
    func refreshEvents(filters: EventFilters? = nil) async {
        guard let store = agentController?.store else { return }
        
        let effectiveFilters = filters ?? EventFilters()
        
        do {
            eventCount = try await store.countEvents(filters: effectiveFilters)
            let newEvents = try await store.fetchEvents(limit: 50, offset: 0, filters: effectiveFilters, sort: .timestampDesc)
            
            // Track new events for highlighting (if live updates enabled)
            if liveUpdates, let lastTimestamp = lastEventTimestamp {
                // New events are those with timestamp > lastTimestamp
                // Highlighting is handled by UI animation
            }
            
            events = newEvents
            lastEventTimestamp = newEvents.first?.timestamp
        } catch {
            print("Error loading events: \(error)")
        }
    }
    
    func loadHealth() async {
        guard let store = agentController?.store else { return }
        
        do {
            health = try await store.getDBHealth()
        } catch {
            print("Error loading health: \(error)")
        }
    }
    
    func executeQuery(_ sql: String) async throws -> String {
        guard let store = agentController?.store else {
            throw NSError(domain: "DBInspector", code: 1, userInfo: [NSLocalizedDescriptionKey: "Store not available"])
        }
        return try await store.executeQuery(sql, limit: 100)
    }
    
    func setLiveUpdates(_ enabled: Bool) {
        liveTimer?.invalidate()
        liveTimer = nil
        
        if enabled {
            liveTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    await self?.refresh()
                }
            }
        }
    }
}

// Make TableRow Identifiable for sheet
extension TableRow: Identifiable {
    var id: String {
        columns.map { "\($0.key):\($0.value)" }.joined(separator: "|")
    }
}

struct RowDetailView: View {
    let row: TableRow
    let developerMode: Bool
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(row.columns.keys.sorted()), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(key)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Text(String(describing: row.columns[key] ?? "nil"))
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Row Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

