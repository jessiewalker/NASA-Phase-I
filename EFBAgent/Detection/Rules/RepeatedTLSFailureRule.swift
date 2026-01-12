//
//  RepeatedTLSFailureRule.swift
//  EFB Agent
//
//  Detects repeated TLS connection failures
//

import Foundation

struct RepeatedTLSFailureRule: Rule {
    let id = "repeated_tls_failure"
    let name = "Repeated TLS Failure"
    
    let failureCount: Int
    let window: TimeInterval
    let cooldown: TimeInterval
    
    init(failureCount: Int = 3, window: TimeInterval = 60, cooldown: TimeInterval = 300) {
        self.failureCount = failureCount
        self.window = window
        self.cooldown = cooldown
    }
    
    func evaluate(snapshot: TelemetrySnapshot, context: RuleContext, deviceId: String, sequenceNumber: @escaping () -> Int64) async -> [AgentEvent] {
        guard let networkMetrics = snapshot.networkMetrics else {
            return []
        }
        
        let cooldownKey = "\(id)_cooldown"
        if await context.isInCooldown(key: cooldownKey, cooldown: cooldown) {
            return []
        }
        
        // Track TLS failures in window
        if networkMetrics.tlsFailureCount > 0 {
            await context.addToWindow(key: "\(id)_failures", timestamp: snapshot.timestamp, windowSize: window)
            let failureCountInWindow = await context.getWindowCount(key: "\(id)_failures")
            
            if failureCountInWindow >= failureCount {
                await context.setCooldown(key: cooldownKey, duration: cooldown)
                await context.clearWindow(key: "\(id)_failures")
                
                return [AgentEvent(
                    deviceId: deviceId,
                    timestamp: snapshot.timestamp,
                    category: .security,
                    severity: .error,
                    name: "Repeated TLS Failures Detected",
                    attributes: [
                        "failureCount": .int(failureCountInWindow),
                        "threshold": .int(failureCount),
                        "window": .double(window)
                    ],
                    source: .ruleEngine,
                    sequenceNumber: sequenceNumber()
                )]
            }
        }
        
        return []
    }
}

