//
//  EventDetailView.swift
//  EFB Agent
//
//  Event detail view with JSON display
//

import SwiftUI

struct EventDetailView: View {
    let event: AgentEvent
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Key fields
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
                    
                    // JSON
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Full Event JSON")
                            .font(.headline)
                        
                        ScrollView(.horizontal, showsIndicators: true) {
                            Text(prettyJSON)
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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        UIPasteboard.general.string = prettyJSON
                    }) {
                        Label("Copy JSON", systemImage: "doc.on.doc")
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var prettyJSON: String {
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

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

