//
//  EventsSummaryCard.swift
//  EFB Agent
//
//  Enhanced events summary statistics with time window
//

import SwiftUI

enum TimeWindow: String, CaseIterable {
    case fifteenMinutes = "15m"
    case oneHour = "1h"
    case twentyFourHours = "24h"
    case all = "All"
    
    var timeInterval: TimeInterval? {
        switch self {
        case .fifteenMinutes: return 15 * 60
        case .oneHour: return 60 * 60
        case .twentyFourHours: return 24 * 60 * 60
        case .all: return nil
        }
    }
}

struct EventsSummaryCard: View {
    @EnvironmentObject var agentController: AgentController
    @State private var selectedTimeWindow: TimeWindow = .all
    
    private var filteredEvents: [AgentEvent] {
        let events = agentController.recentEvents
        
        guard let interval = selectedTimeWindow.timeInterval else {
            return events
        }
        
        let cutoff = Date().addingTimeInterval(-interval)
        return events.filter { $0.timestamp >= cutoff }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Events Summary")
                    .font(.headline)
                Spacer()
                
                Picker("Time Window", selection: $selectedTimeWindow) {
                    ForEach(TimeWindow.allCases, id: \.self) { window in
                        Text(window.rawValue).tag(window)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 80)
            }
            
            Divider()
            
            let events = filteredEvents
            let total = events.count
            let critical = events.filter { $0.severity == .critical }.count
            let errors = events.filter { $0.severity == .error }.count
            let warnings = events.filter { $0.severity == .warning }.count
            let info = events.filter { $0.severity == .info }.count
            
            let acknowledged = 0
            let suppressed = events.filter { event in
                false
            }.count
            
            HStack(spacing: 20) {
                EventStat(label: "Total", count: total)
                EventStat(label: "Critical", count: critical, color: .purple)
                EventStat(label: "Errors", count: errors, color: .red)
                EventStat(label: "Warnings", count: warnings, color: .orange)
            }
            
            Divider()
            
            HStack(spacing: 20) {
                EventStat(label: "Info", count: info, color: .blue)
                EventStat(label: "Acknowledged", count: acknowledged, color: .gray)
                EventStat(label: "Suppressed", count: suppressed, color: .secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct EventStat: View {
    let label: String
    let count: Int
    var color: Color = .primary
    
    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

