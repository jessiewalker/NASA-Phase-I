//
//  UploadStatusCard.swift
//  EFB Agent
//
//  Upload status and control card
//

import SwiftUI

struct UploadStatusCard: View {
    @EnvironmentObject var agentController: AgentController
    @EnvironmentObject var configManager: ConfigManager
    @State private var showingClearUploadedConfirmation = false
    @State private var showingClearPendingConfirmation = false
    
    var isMockMode: Bool {
        return configManager.config.uploadEndpoint == nil
    }
    
    var uploadEndpoint: String {
        if isMockMode {
            return "Mock (Testing)"
        }
        return configManager.config.uploadEndpoint ?? "Not Configured"
    }
    
    var authStatus: String {
        if isMockMode {
            return "Not Required (Mock)"
        }
        if configManager.config.uploadSigningSecret != nil {
            return "Configured"
        }
        return "Missing"
    }
    
    var certPinningEnabled: Bool {
        return !configManager.config.debugMode
    }
    
    var uploadsAllowed: Bool {
        if isMockMode {
            return true
        }
        return configManager.config.uploadSigningSecret != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upload Status")
                .font(.headline)
            
            Divider()
            
            Group {
                StatusRow(label: "Endpoint", value: uploadEndpoint)
                StatusRow(label: "Auth Status", value: authStatus)
                StatusRow(label: "Cert Pinning", value: certPinningEnabled ? "Enabled" : "Disabled")
            }
            
            Divider()
            
            Group {
                if let lastAttempt = agentController.lastUploadAttemptTime {
                    StatusRow(label: "Last Attempt", value: TimeFormatter.relativePast(lastAttempt))
                }
                if let lastSuccess = agentController.lastSuccessfulUploadTime {
                    StatusRow(label: "Last Success", value: TimeFormatter.relativePast(lastSuccess))
                }
                StatusRow(label: "Pending Count", value: "\(agentController.pendingEventsCount)")
                StatusRow(label: "Pending Bytes", value: formatBytes(agentController.pendingEventBytes))
            }
            
            Divider()
            
            HStack {
                Text("Reporting Allowed (Policy)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(uploadsAllowed ? Color.green : Color.red)
                        .frame(width: 6, height: 6)
                    Text(uploadsAllowed ? "Yes" : "No")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(uploadsAllowed ? .green : .red)
                }
            }
            
            if isMockMode {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.blue)
                        .font(.caption)
                    Text("Mock mode: Auth not required")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            VStack(spacing: 8) {
                Button(action: {
                    Task {
                        await agentController.triggerUpload()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.up.circle.fill")
                        Text("Force Upload Now")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                
                #if DEBUG
                HStack(spacing: 8) {
                    Button(action: {
                        showingClearUploadedConfirmation = true
                    }) {
                        Text("Clear Uploaded")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(6)
                    }
                    
                    Button(action: {
                        showingClearPendingConfirmation = true
                    }) {
                        Text("Clear Pending")
                            .font(.caption)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.red.opacity(0.2))
                            .foregroundColor(.red)
                            .cornerRadius(6)
                    }
                }
                #endif
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .alert("Clear Uploaded Events?", isPresented: $showingClearUploadedConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await agentController.clearUploadedEvents()
                }
            }
        } message: {
            Text("This will delete all uploaded events from the local store. This action cannot be undone.")
        }
        .alert("Clear Pending Events?", isPresented: $showingClearPendingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await agentController.clearPendingEvents()
                }
            }
        } message: {
            Text("This will delete all pending (unuploaded) events. This action cannot be undone.")
        }
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: bytes)
    }
}

