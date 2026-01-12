//
//  RecentEventsSection.swift
//  EFB Agent
//
//  Recent events feed with filtering
//

import SwiftUI

struct RecentEventsSection: View {
    let events: [AgentEvent]
    let onSelectEvent: (AgentEvent) -> Void
    @Binding var selectedSeverity: EventSeverity?
    @Binding var selectedCategory: EventCategory?
    @EnvironmentObject var agentController: AgentController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Events")
                    .font(.headline)
                Spacer()
                Text("\(events.count)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                #if DEBUG
                Button(action: {
                    agentController.clearRecentEvents()
                }) {
                    Text("Clear")
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.leading, 8)
                #endif
            }
            
            // Severity filters - horizontal scroll with safe padding
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterButton(title: "All", isSelected: selectedSeverity == nil && selectedCategory == nil) {
                        selectedSeverity = nil
                        selectedCategory = nil
                    }
                    
                    Text("Severity:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(EventSeverity.allCases, id: \.self) { severity in
                        FilterButton(
                            title: severity.rawValue.capitalized,
                            isSelected: selectedSeverity == severity
                        ) {
                            selectedSeverity = selectedSeverity == severity ? nil : severity
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            
            // Category filters - horizontal scroll with safe padding
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Text("Category:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(EventCategory.allCases, id: \.self) { category in
                        FilterButton(
                            title: category.rawValue.capitalized,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = selectedCategory == category ? nil : category
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            
            Divider()
            
            if events.isEmpty {
                Text("No events")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                let maxVisible = 200
                ForEach(Array(events.prefix(maxVisible).enumerated()), id: \.element.eventId) { index, event in
                    EventRow(event: event)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectEvent(event)
                        }
                    
                    if index == maxVisible - 1 && events.count > maxVisible {
                        HStack {
                            Spacer()
                            Text("\(events.count - maxVisible) more events...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 8)
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct FilterButton: View {
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

struct EventRow: View {
    let event: AgentEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                SeverityBadge(severity: event.severity)
                Text(event.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text(TimeFormatter.relativePast(event.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
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
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.gray.opacity(0.2))
                    .foregroundColor(.secondary)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct SeverityBadge: View {
    let severity: EventSeverity
    
    var body: some View {
        Circle()
            .fill(colorForSeverity(severity))
            .frame(width: 8, height: 8)
    }
    
    private func colorForSeverity(_ severity: EventSeverity) -> Color {
        switch severity {
        case .critical: return .purple
        case .error: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

