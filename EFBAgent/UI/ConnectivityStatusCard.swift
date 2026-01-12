//
//  ConnectivityStatusCard.swift
//  EFB Agent
//
//  Enhanced network connectivity status display
//

import SwiftUI

struct ConnectivityStatusCard: View {
    @EnvironmentObject var agentController: AgentController
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connectivity")
                .font(.headline)
            
            Divider()
            
            if let conn = agentController.currentConnectivity {
                ConnectivityRow(
                    label: "Status",
                    value: statusText(conn),
                    valueColor: statusColor(conn)
                )
                
                if let interface = conn.interfaceType {
                    ConnectivityRow(label: "Interface", value: interface)
                } else {
                    ConnectivityRow(label: "Interface", value: "None")
                }
                
                ConnectivityRow(label: "Expensive", value: conn.isExpensive ? "Yes" : "No")
                ConnectivityRow(label: "Constrained", value: conn.isConstrained ? "Yes" : "No")
                
                if let lastChange = conn.lastChangeTime {
                    ConnectivityRow(label: "Last Change", value: TimeFormatter.relativePast(lastChange))
                }
                
                Divider()
                
                let uploadAllowed = conn.isConnected && !conn.isConstrained
                ConnectivityRow(
                    label: "Reporting Allowed (Policy)",
                    value: uploadAllowed ? "Yes" : "No",
                    valueColor: uploadAllowed ? .green : .red
                )
            } else {
                Text("Unknown")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func statusText(_ conn: TelemetrySnapshot.ConnectivitySummary) -> String {
        if conn.isConnected {
            if conn.isConstrained {
                return "Constrained"
            } else {
                return "Online"
            }
        } else {
            return "Offline"
        }
    }
    
    private func statusColor(_ conn: TelemetrySnapshot.ConnectivitySummary) -> Color {
        if conn.isConnected {
            return conn.isConstrained ? .orange : .green
        } else {
            return .red
        }
    }
}

struct ConnectivityRow: View {
    let label: String
    let value: String
    var valueColor: Color? = nil
    
    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(valueColor)
        }
    }
}

