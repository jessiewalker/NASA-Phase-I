//
//  EFBAgentApp.swift
//  EFB Agent
//
//  App entry point
//

import SwiftUI

@main
struct EFBAgentApp: App {
    @StateObject private var configManager = ConfigManager()
    @StateObject private var agentController: AgentController
    
    init() {
        let config = ConfigManager()
        let controller = AgentController(configManager: config)
        _configManager = StateObject(wrappedValue: config)
        _agentController = StateObject(wrappedValue: controller)
    }
    
    var body: some Scene {
        WindowGroup {
            DashboardView()
                .environmentObject(agentController)
                .environmentObject(configManager)
        }
    }
}

