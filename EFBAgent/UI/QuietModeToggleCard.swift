//
//  QuietModeToggleCard.swift
//  EFB Agent
//
//  Quiet Mode toggle card
//

import SwiftUI

struct QuietModeToggleCard: View {
    @EnvironmentObject var configManager: ConfigManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quiet Mode")
                    .font(.headline)
                Spacer()
                Toggle("", isOn: Binding(
                    get: { configManager.config.quietMode },
                    set: { newValue in
                        var config = configManager.config
                        config.quietMode = newValue
                        configManager.config = config
                    }
                ))
                .toggleStyle(SwitchToggleStyle(tint: .orange))
            }
            
            if configManager.config.quietMode {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("When enabled, rules still evaluate and events log, but uploads and alerts are rate-limited.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
            }
        }
        .padding()
        .background(configManager.config.quietMode ? Color.orange.opacity(0.1) : Color(.systemGray6))
        .cornerRadius(12)
    }
}

