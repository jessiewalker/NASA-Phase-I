//
//  EventBrowserView.swift
//  EFB Agent
//
//  Full-featured event browser with search, filters, and live updates
//

import SwiftUI

struct EventBrowserView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var agentController: AgentController
    @StateObject private var viewModel = EventBrowserViewModel()
    @State private var selectedEvent: AgentEvent? = nil
    @State private var showingExport = false
    @State private var showingDBPath = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and filters
                VStack(spacing: 12) {
                    // Search bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        TextField("Search events...", text: $viewModel.searchText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // Filter chips
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            FilterChip(title: "All", isSelected: viewModel.selectedSeverity == nil && viewModel.selectedCategory == nil) {
                                viewModel.selectedSeverity = nil
                                viewModel.selectedCategory = nil
                            }
                            
                            Text("Severity:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(EventSeverity.allCases, id: \.self) { severity in
                                FilterChip(title: severity.rawValue.capitalized, isSelected: viewModel.selectedSeverity == severity) {
                                    viewModel.selectedSeverity = viewModel.selectedSeverity == severity ? nil : severity
                                }
                            }
                            
                            Text("Category:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            ForEach(EventCategory.allCases, id: \.self) { category in
                                FilterChip(title: category.rawValue.capitalized, isSelected: viewModel.selectedCategory == category) {
                                    viewModel.selectedCategory = viewModel.selectedCategory == category ? nil : category
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Live toggle
                    HStack {
                        Toggle("Live Updates", isOn: $viewModel.liveUpdates)
                            .toggleStyle(SwitchToggleStyle())
                        Spacer()
                        Text("\(viewModel.totalCount) events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Event list
                if viewModel.events.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No events found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.events) { event in
                            EventBrowserRow(event: event)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedEvent = event
                                }
                        }
                        
                        if viewModel.hasMore {
                            HStack {
                                Spacer()
                                Button("Load More") {
                                    Task {
                                        await viewModel.loadMore()
                                    }
                                }
                                .padding()
                                Spacer()
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Event Browser")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Export DB") {
                        showingExport = true
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    #if DEBUG
                    Button("DB Path") {
                        showingDBPath = true
                    }
                    #endif
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $selectedEvent) { event in
                NavigationView {
                    EventDetailBrowserView(event: event)
                }
            }
            .sheet(isPresented: $showingExport) {
                ShareSheet(activityItems: [viewModel.dbURL])
            }
            .alert("DB Path", isPresented: $showingDBPath) {
                Button("Copy") {
                    UIPasteboard.general.string = viewModel.dbPath
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.dbPath)
            }
            .task {
                await viewModel.setup(agentController: agentController)
            }
            .onChange(of: viewModel.searchText) { _ in
                Task {
                    await viewModel.refresh()
                }
            }
            .onChange(of: viewModel.selectedSeverity) { _ in
                Task {
                    await viewModel.refresh()
                }
            }
            .onChange(of: viewModel.selectedCategory) { _ in
                Task {
                    await viewModel.refresh()
                }
            }
            .onChange(of: viewModel.liveUpdates) { enabled in
                viewModel.setLiveUpdates(enabled)
            }
        }
    }
}

struct EventBrowserRow: View {
    let event: AgentEvent
    
    var body: some View {
        HStack(spacing: 12) {
            SeverityBadge(severity: event.severity)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack(spacing: 8) {
                    Text(event.category.rawValue.capitalized)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                    
                    Text(event.source.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(TimeFormatter.relativePast(event.timestamp))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue.opacity(0.2) : Color(.systemGray5))
                .foregroundColor(isSelected ? .blue : .primary)
                .cornerRadius(8)
        }
    }
}

@MainActor
class EventBrowserViewModel: ObservableObject {
    @Published var events: [AgentEvent] = []
    @Published var searchText: String = ""
    @Published var selectedSeverity: EventSeverity? = nil
    @Published var selectedCategory: EventCategory? = nil
    @Published var liveUpdates: Bool = false
    @Published var totalCount: Int = 0
    @Published var isLoading: Bool = false
    @Published var hasMore: Bool = false
    
    private weak var agentController: AgentController?
    private var liveTimer: Timer?
    private let pageSize = 50
    private var currentOffset = 0
    
    var dbPath: String {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("events.db").path
    }
    
    var dbURL: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("events.db")
    }
    
    func setup(agentController: AgentController) async {
        self.agentController = agentController
        await refresh()
    }
    
    func refresh() async {
        currentOffset = 0
        isLoading = true
        
        // Build filters
        var filters = EventFilters()
        if !searchText.isEmpty {
            filters.searchText = searchText
        }
        filters.severity = selectedSeverity
        filters.category = selectedCategory
        
        guard let store = agentController?.store else {
            isLoading = false
            return
        }
        
        do {
            let pageEvents = try await store.fetchPage(limit: pageSize, offset: 0, filters: filters)
            events = pageEvents
            currentOffset = pageEvents.count
            hasMore = pageEvents.count == pageSize
            
            // Update total count (simplified - could use fetchCountsBySeverityAndCategory)
            let counts = try await store.fetchCountsBySeverityAndCategory(dateRange: nil)
            totalCount = counts.total
        } catch {
            print("Error loading events: \(error)")
        }
        
        isLoading = false
    }
    
    func loadMore() async {
        guard !isLoading && hasMore else { return }
        
        isLoading = true
        
        var filters = EventFilters()
        if !searchText.isEmpty {
            filters.searchText = searchText
        }
        filters.severity = selectedSeverity
        filters.category = selectedCategory
        
        guard let store = agentController?.store else {
            isLoading = false
            return
        }
        
        do {
            let pageEvents = try await store.fetchPage(limit: pageSize, offset: currentOffset, filters: filters)
            events.append(contentsOf: pageEvents)
            currentOffset += pageEvents.count
            hasMore = pageEvents.count == pageSize
        } catch {
            print("Error loading more events: \(error)")
        }
        
        isLoading = false
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

struct EventDetailBrowserView: View {
    let event: AgentEvent
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Metadata
                VStack(alignment: .leading, spacing: 8) {
                    DetailRow(label: "Event ID", value: event.eventId.uuidString)
                    DetailRow(label: "Device ID", value: event.deviceId)
                    DetailRow(label: "Timestamp", value: formatDate(event.timestamp))
                    DetailRow(label: "Category", value: event.category.rawValue.capitalized)
                    DetailRow(label: "Severity", value: event.severity.rawValue.capitalized)
                    DetailRow(label: "Source", value: event.source.rawValue)
                    DetailRow(label: "Sequence Number", value: "\(event.sequenceNumber)")
                    DetailRow(label: "Name", value: event.name)
                }
                
                Divider()
                
                // Decrypted JSON
                VStack(alignment: .leading, spacing: 8) {
                    Text("Decrypted JSON (Internal)")
                        .font(.headline)
                    
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(prettyJSON(for: event))
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                Divider()
                
                // Redacted JSON
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
                    
                    ScrollView(.horizontal, showsIndicators: true) {
                        Text(prettyJSON(for: redactedEvent))
                            .font(.system(.caption, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Event Details")
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

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

