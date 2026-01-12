//
//  AgentStatusCard.swift
//  EFB Agent
//
//  Enhanced agent status display card
//

import SwiftUI

struct AgentStatusCard: View {
    @EnvironmentObject var agentController: AgentController
    @EnvironmentObject var configManager: ConfigManager
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Agent Status")
                    .font(.headline)
                Spacer()
                StatusBadge(isRunning: agentController.isRunning)
            }
            
            Divider()
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(agentController.isRunning ? "Running" : "Stopped")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                if agentController.isRunning {
                    Button(action: {
                        agentController.stop()
                    }) {
                        Text("Stop")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(8)
                    }
                } else {
                    Button(action: {
                        agentController.start()
                    }) {
                        Text("Start")
                            .font(.subheadline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(8)
                    }
                }
            }
            
            if agentController.isRunning, agentController.startTime != nil {
                StatusRow(label: "Uptime", value: formatUptime(agentController.uptime))
            }
            
            // Real-Time Metrics Sparklines
            if agentController.isRunning {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Real-Time Metrics (last 60s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 16) {
                        // CPU Sparkline (ESTIMATED)
                        SparklineView(
                            values: agentController.cpuSeries,
                            label: "CPU",
                            valueText: String(format: "%.0f%% est", (agentController.cpuSeries.last ?? 0.0) * 100.0),
                            color: Color.blue
                        )
                        
                        // Memory Sparkline (ESTIMATED)
                        SparklineView(
                            values: agentController.memSeries,
                            label: "Mem",
                            valueText: String(format: "%.0f MB est", agentController.memSeries.last ?? 0.0),
                            color: Color.green
                        )
                    }
                }
            }
            
            if let lastSnapshot = agentController.lastSnapshotTime {
                StatusRow(label: "Last Snapshot", value: TimeFormatter.relativePast(lastSnapshot))
            }
            
            if let lastRuleEval = agentController.lastRuleEvaluationTime {
                StatusRow(label: "Last Rule Evaluation", value: TimeFormatter.relativePast(lastRuleEval))
            }
            
            if let nextSnapshot = agentController.nextScheduledSnapshotTime {
                StatusRow(label: "Next Snapshot", value: TimeFormatter.relativeFuture(nextSnapshot))
            }
            
            Divider()
            
            Group {
                StatusRow(label: "Pending Events", value: "\(agentController.pendingEventsCount)")
                StatusRow(label: "Pending Bytes", value: formatBytes(agentController.pendingEventBytes))
                StatusRow(label: "Store Size", value: formatBytes(agentController.localStoreSizeBytes))
            }
            
            Divider()
            
            if let lastUploadAttempt = agentController.lastUploadAttemptTime {
                StatusRow(label: "Last Upload Attempt", value: TimeFormatter.relativePast(lastUploadAttempt))
            }
            if let lastSuccessful = agentController.lastSuccessfulUploadTime {
                StatusRow(label: "Last Successful Upload", value: TimeFormatter.relativePast(lastSuccessful))
            }
            if let nextUpload = agentController.nextUploadAttemptTime {
                StatusRow(
                    label: "Next Upload Attempt",
                    value: nextUploadValue(nextUpload: nextUpload, canUpload: agentController.canUpload())
                )
            }
            
            Divider()
            
            Group {
                StatusRow(label: "Ruleset Version", value: agentController.rulesetVersion)
                StatusRow(label: "Config Version", value: agentController.configVersion)
                HStack {
                    Text("Config Signature")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    ConfigSignatureBadge(status: agentController.configSignatureStatus)
                }
            }
            
            if let error = agentController.lastError {
                Divider()
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onReceive(timer) { _ in
            // Update uptime display every second
            if agentController.isRunning {
                // Force UI refresh for uptime
            }
        }
    }
    
    private func nextUploadValue(nextUpload: Date, canUpload: Bool) -> String {
        let timeUntil = nextUpload.timeIntervalSince(Date())
        if !canUpload {
            return "Blocked"
        } else if timeUntil <= 30 {
            return "Ready"
        } else {
            return TimeFormatter.relativeFuture(nextUpload)
        }
    }
    
    private func formatUptime(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        let seconds = Int(interval) % 60
        
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

struct StatusBadge: View {
    let isRunning: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isRunning ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isRunning ? "Running" : "Stopped")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(isRunning ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
        .cornerRadius(8)
    }
}

struct StatusRow: View {
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

struct ConfigSignatureBadge: View {
    let status: ConfigSignatureStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(colorForStatus(status))
                .frame(width: 6, height: 6)
            Text(status.rawValue.capitalized)
                .font(.caption)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(colorForStatus(status).opacity(0.2))
        .cornerRadius(4)
    }
    
    private func colorForStatus(_ status: ConfigSignatureStatus) -> Color {
        switch status {
        case .valid: return .green
        case .invalid: return .red
        case .notPresent: return .gray
        case .unknown: return .orange
        }
    }
}

