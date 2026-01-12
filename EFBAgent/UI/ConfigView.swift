//
//  ConfigView.swift
//  EFB Agent
//
//  Enhanced configuration view with source badges
//

import SwiftUI

struct ConfigView: View {
    @EnvironmentObject var configManager: ConfigManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                Section("Configuration Source") {
                    ConfigRow(
                        label: "Signature Status",
                        value: configManager.configSignatureStatus.rawValue.capitalized,
                        source: .default,
                        showSource: false
                    )
                    .foregroundColor(colorForSignatureStatus(configManager.configSignatureStatus))
                    
                    if let lastUpdate = configManager.lastConfigUpdateTime {
                        ConfigRow(
                            label: "Last Updated",
                            value: formatDate(lastUpdate),
                            source: .default,
                            showSource: false
                        )
                    }
                }
                
                Section("Sampling") {
                    ConfigRow(
                        label: "Sampling Rate",
                        value: "\(Int(configManager.config.samplingRate))s",
                        source: configManager.getConfigSource(for: "samplingRate")
                    )
                    ConfigRow(
                        label: "Upload Interval",
                        value: "\(Int(configManager.config.uploadInterval))s",
                        source: configManager.getConfigSource(for: "uploadInterval")
                    )
                }
                
                Section("Rules") {
                    ConfigRow(
                        label: "CPU Threshold",
                        value: String(format: "%.2f", configManager.config.ruleThresholds.cpuThreshold),
                        source: configManager.getConfigSource(for: "cpuThreshold")
                    )
                    ConfigRow(
                        label: "Memory Threshold",
                        value: formatBytes(configManager.config.ruleThresholds.memoryThreshold),
                        source: configManager.getConfigSource(for: "memoryThreshold")
                    )
                    ConfigRow(
                        label: "Connectivity Flap",
                        value: "\(configManager.config.ruleThresholds.connectivityFlapThreshold)/min",
                        source: .default
                    )
                }
                
                Section("Network") {
                    ConfigRow(
                        label: "Allowed Hosts",
                        value: configManager.config.allowedHosts.joined(separator: ", "),
                        source: configManager.getConfigSource(for: "allowedHosts")
                    )
                }
                
                Section("Settings") {
                    ConfigRow(
                        label: "Quiet Mode",
                        value: configManager.config.quietMode ? "On" : "Off",
                        source: configManager.getConfigSource(for: "quietMode")
                    )
                    ConfigRow(
                        label: "Debug Mode",
                        value: configManager.config.debugMode ? "On" : "Off",
                        source: configManager.getConfigSource(for: "debugMode")
                    )
                    ConfigRow(
                        label: "Test Mode",
                        value: configManager.config.testMode ? "On" : "Off",
                        source: configManager.getConfigSource(for: "testMode")
                    )
                }
                
                Section("Storage") {
                    ConfigRow(
                        label: "Max Pending",
                        value: "\(configManager.config.maxPendingEvents)",
                        source: .default
                    )
                    ConfigRow(
                        label: "Retention",
                        value: "\(configManager.config.retentionDays) days",
                        source: .default
                    )
                }
            }
            .navigationTitle("Configuration")
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
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func colorForSignatureStatus(_ status: ConfigSignatureStatus) -> Color {
        switch status {
        case .valid: return .green
        case .invalid: return .red
        case .notPresent: return .gray
        case .unknown: return .orange
        }
    }
}

struct ConfigRow: View {
    let label: String
    let value: String
    let source: ConfigSource
    var showSource: Bool = true
    
    var body: some View {
        HStack {
            Text(label)
            Spacer()
            HStack(spacing: 8) {
                Text(value)
                    .foregroundColor(.secondary)
                
                if showSource {
                    SourceBadge(source: source)
                }
            }
        }
    }
}

struct SourceBadge: View {
    let source: ConfigSource
    
    var body: some View {
        Text(source.rawValue.uppercased())
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(colorForSource(source).opacity(0.2))
            .foregroundColor(colorForSource(source))
            .cornerRadius(4)
    }
    
    private func colorForSource(_ source: ConfigSource) -> Color {
        switch source {
        case .default: return .gray
        case .mdm: return .blue
        case .remoteSigned: return .green
        }
    }
}

