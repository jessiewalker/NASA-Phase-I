//
//  DashboardView.swift
//  EFB Agent
//
//  Main dashboard view with agent status, events, and diagnostics
//

import SwiftUI
import Combine

struct DashboardView: View {
    @EnvironmentObject var agentController: AgentController
    @EnvironmentObject var configManager: ConfigManager
    @State private var selectedSeverity: EventSeverity? = nil
    @State private var selectedCategory: EventCategory? = nil
    @State private var selectedEvent: AgentEvent? = nil
    @State private var showingConfig = false
    @State private var showingLocalEvents = false
    @State private var showingDBInspector = false
    @State private var diagnosticsReport: DiagnosticsReport? = nil
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                if geometry.size.width > geometry.size.height {
                    // Landscape: split view
                    HStack(spacing: 16) {
                        // Left column: existing content
                        ScrollView {
                            VStack(spacing: 20) {
                                dashboardContent
                            }
                            .padding()
                        }
                        .frame(width: geometry.size.width * 0.6)
                        
                        // Right column: Real-Time Metrics panel
                        ScrollView {
                            RealTimeMetricsPanel()
                                .environmentObject(agentController)
                        }
                        .frame(width: geometry.size.width * 0.4)
                    }
                } else {
                    // Portrait: single column
                    ScrollView {
                        VStack(spacing: 20) {
                            dashboardContent
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("EFB Agent")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingLocalEvents = true }) {
                            Image(systemName: "doc.text.magnifyingglass")
                        }
                        Button(action: { showingDBInspector = true }) {
                            Image(systemName: "cylinder")
                        }
                        Button(action: { showingConfig = true }) {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingConfig) {
                ConfigView()
                    .environmentObject(configManager)
            }
            .sheet(isPresented: $showingLocalEvents) {
                EventBrowserView()
                    .environmentObject(agentController)
            }
            .sheet(isPresented: $showingDBInspector) {
                DBInspectorView()
                    .environmentObject(agentController)
            }
            .sheet(item: $selectedEvent) { event in
                NavigationView {
                    EventDetailView(event: event)
                }
            }
        }
    }
    
    private var dashboardContent: some View {
        Group {
                    // Agent Status Section
                    AgentStatusCard()
                        .environmentObject(agentController)
                        .environmentObject(configManager)
                    
                    // Diagnostics Buttons - stacked vertically to avoid text wrapping
                    VStack(spacing: 12) {
                        Button(action: {
                            runDiagnostics(safe: true)
                        }) {
                            HStack {
                                Image(systemName: "stethoscope")
                                Text("Run Diagnostics (Safe)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .minimumScaleFactor(0.8)
                        .lineLimit(2)
                        
                        Button(action: {
                            runDiagnostics(safe: false)
                        }) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                Text("Run Diagnostics (Stress)")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .minimumScaleFactor(0.8)
                        .lineLimit(2)
                    }
                    .padding(.horizontal)
                    
                    // Connectivity Status
                    ConnectivityStatusCard()
                        .environmentObject(agentController)
                    
                    // Upload Status Card
                    UploadStatusCard()
                        .environmentObject(agentController)
                        .environmentObject(configManager)
                    
                    // Quiet Mode Toggle
                    QuietModeToggleCard()
                        .environmentObject(configManager)
                    
                    // Events Summary
                    EventsSummaryCard()
                        .environmentObject(agentController)
                    
                    // Recent Events Feed
                    RecentEventsSection(
                        events: filteredEvents,
                        onSelectEvent: { event in
                            selectedEvent = event
                        },
                        selectedSeverity: $selectedSeverity,
                        selectedCategory: $selectedCategory
                    )
                    .environmentObject(agentController)
                    
            if let report = diagnosticsReport {
                DiagnosticsReportCard(report: report)
                    .padding()
            }
        }
    }
    
    private var filteredEvents: [AgentEvent] {
        var events = agentController.recentEvents
        
        if let severity = selectedSeverity {
            events = events.filter { $0.severity == severity }
        }
        
        if let category = selectedCategory {
            events = events.filter { $0.category == category }
        }
        
        return Array(events.prefix(200))
    }
    
    private func runDiagnostics(safe: Bool) {
        Task { @MainActor in
            diagnosticsReport = await DiagnosticsRunner.run(
                agentController: agentController,
                configManager: configManager,
                stressMode: !safe
            )
        }
    }
}

