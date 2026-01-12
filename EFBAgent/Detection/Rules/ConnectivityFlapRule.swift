//
//  ConnectivityFlapRule.swift
//  EFB Agent
//
//  Detects connectivity flapping (frequent connect/disconnect)
//

import Foundation

struct ConnectivityFlapRule: Rule {
    let id = "connectivity_flap"
    let name = "Connectivity Flapping"
    
    let changesPerMinute: Int
    let cooldown: TimeInterval
    
    init(changesPerMinute: Int = 5, cooldown: TimeInterval = 300) {
        self.changesPerMinute = changesPerMinute
        self.cooldown = cooldown
    }
    
    func evaluate(snapshot: TelemetrySnapshot, context: RuleContext, deviceId: String, sequenceNumber: @escaping () -> Int64) async -> [AgentEvent] {
        let cooldownKey = "\(id)_cooldown"
        if await context.isInCooldown(key: cooldownKey, cooldown: cooldown) {
            return []
        }
        
        // Track connectivity state
        let stateKey = snapshot.connectivity.isConnected ? "connected" : "disconnected"
        await context.addToWindow(key: "\(id)_\(stateKey)", timestamp: snapshot.timestamp, windowSize: 60)
        let connectedCount = await context.getWindowCount(key: "\(id)_connected")
        let disconnectedCount = await context.getWindowCount(key: "\(id)_disconnected")
        let totalChanges = connectedCount + disconnectedCount
        
        if totalChanges >= changesPerMinute {
            await context.setCooldown(key: cooldownKey, duration: cooldown)
            await context.clearWindow(key: "\(id)_connected")
            await context.clearWindow(key: "\(id)_disconnected")
            
            return [AgentEvent(
                deviceId: deviceId,
                timestamp: snapshot.timestamp,
                category: .connectivity,
                severity: .warning,
                name: "Connectivity Flapping Detected",
                attributes: [
                    "changesPerMinute": .int(totalChanges),
                    "threshold": .int(changesPerMinute)
                ],
                source: .ruleEngine,
                sequenceNumber: sequenceNumber()
            )]
        }
        
        return []
    }
}

