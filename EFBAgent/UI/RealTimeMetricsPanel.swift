//
//  RealTimeMetricsPanel.swift
//  EFB Agent
//
//  Real-time metrics panel with sparklines and time-series table
//

import SwiftUI

struct RealTimeMetricsPanel: View {
    @EnvironmentObject var agentController: AgentController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Real-Time Metrics")
                    .font(.headline)
                Spacer()
                Toggle("Pause", isOn: Binding(
                    get: { agentController.metricsPaused },
                    set: { paused in
                        if paused {
                            agentController.pauseMetrics()
                        } else {
                            agentController.resumeMetrics()
                        }
                    }
                ))
                .toggleStyle(SwitchToggleStyle())
                Button("Reset") {
                    Task {
                        await agentController.resetMetricsWindow()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            Divider()
            
            // Sparklines
            VStack(spacing: 12) {
                // CPU Sparkline (normalized 0.0-1.0 for sparkline)
                HStack(spacing: 12) {
                    SparklineView(
                        values: agentController.metricsSamples.map { max(0.0, min(1.0, $0.cpuPercent / 100.0)) },
                        label: "CPU",
                        valueText: String(format: "%.1f%% est", agentController.metricsSamples.last?.cpuPercent ?? 0.0),
                        color: .blue
                    )
                    
                    // Memory Sparkline (use raw MB values)
                    SparklineView(
                        values: agentController.metricsSamples.map { $0.memoryMB },
                        label: "Mem",
                        valueText: String(format: "%.0f MB est", agentController.metricsSamples.last?.memoryMB ?? 0.0),
                        color: .green
                    )
                }
            }
            
            Divider()
            
            // Time-series table
            VStack(alignment: .leading, spacing: 8) {
                Text("Time Series (Last 60 samples)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if agentController.metricsSamples.isEmpty {
                    Text("No data collected yet")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            // Header
                            HStack {
                                Text("Time")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(width: 80, alignment: .leading)
                                Text("CPU %")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(width: 70, alignment: .trailing)
                                Text("Mem MB")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(width: 80, alignment: .trailing)
                                Text("Tx KB/s")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(width: 80, alignment: .trailing)
                                Text("Rx KB/s")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .frame(width: 80, alignment: .trailing)
                            }
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray5))
                            
                            // Data rows (show in reverse chronological order - newest first)
                            ForEach(Array(agentController.metricsSamples.reversed().enumerated()), id: \.element.id) { index, sample in
                                MetricsTableRow(sample: sample)
                            }
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

struct MetricsTableRow: View {
    let sample: MetricsSample
    
    var body: some View {
        HStack {
            Text(formatTime(sample.timestamp))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 80, alignment: .leading)
            Text(String(format: "%.1f", sample.cpuPercent))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
            Text(String(format: "%.0f", sample.memoryMB))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
            Text(formatOptional(sample.netTxKBps, format: "%.2f"))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
            Text(formatOptional(sample.netRxKBps, format: "%.2f"))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
        .background(Color(.systemBackground))
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func formatOptional(_ value: Double?, format: String) -> String {
        if let value = value {
            return String(format: format, value)
        } else {
            return "—"
        }
    }
}

