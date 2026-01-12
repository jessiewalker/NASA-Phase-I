//
//  NetworkDestinationAllowlistRule.swift
//  EFB Agent
//
//  Detects network requests to non-allowlisted destinations
//

import Foundation

struct NetworkDestinationAllowlistRule: Rule {
    let id = "network_allowlist"
    let name = "Network Destination Allowlist"
    
    let allowedHosts: [String]
    let minimumHits: Int // Minimum connections before alerting
    let cooldown: TimeInterval
    
    init(allowedHosts: [String] = [], minimumHits: Int = 5, cooldown: TimeInterval = 300) {
        self.allowedHosts = allowedHosts
        self.minimumHits = minimumHits
        self.cooldown = cooldown
    }
    
    func evaluate(snapshot: TelemetrySnapshot, context: RuleContext, deviceId: String, sequenceNumber: @escaping () -> Int64) async -> [AgentEvent] {
        guard let networkMetrics = snapshot.networkMetrics,
              !networkMetrics.recentDestinations.isEmpty else {
            return []
        }
        
        let cooldownKey = "\(id)_cooldown"
        if await context.isInCooldown(key: cooldownKey, cooldown: cooldown) {
            return []
        }
        
        // Check each destination
        var violations: [String] = []
        for destination in networkMetrics.recentDestinations {
            let isAllowed = allowedHosts.contains { allowed in
                destination.hasSuffix(allowed) || destination == allowed
            }
            
            if !isAllowed {
                violations.append(destination)
                await context.addToWindow(key: "\(id)_\(destination)", timestamp: snapshot.timestamp, windowSize: 300)
                let hitCount = await context.getWindowCount(key: "\(id)_\(destination)")
                
                if hitCount >= minimumHits {
                    await context.setCooldown(key: cooldownKey, duration: cooldown)
                    
                    return [AgentEvent(
                        deviceId: deviceId,
                        timestamp: snapshot.timestamp,
                        category: .security,
                        severity: .warning,
                        name: "Non-Allowlisted Network Destination",
                        attributes: [
                            "destination": .string(destination),
                            "hitCount": .int(hitCount),
                            "allowedHosts": .array(allowedHosts.map { .string($0) })
                        ],
                        source: .ruleEngine,
                        sequenceNumber: sequenceNumber()
                    )]
                }
            }
        }
        
        return []
    }
}

