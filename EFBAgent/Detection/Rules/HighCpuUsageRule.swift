//
//  HighCpuUsageRule.swift
//  EFB Agent
//
//  Detects sustained high CPU usage
//

import Foundation

struct HighCpuUsageRule: Rule {
    let id = "high_cpu_usage"
    let name = "High CPU Usage"
    
    let threshold: Double // 0.0-1.0
    let consecutiveLimit: Int
    let cooldown: TimeInterval
    
    init(threshold: Double = 0.8, consecutiveLimit: Int = 3, cooldown: TimeInterval = 300) {
        self.threshold = threshold
        self.consecutiveLimit = consecutiveLimit
        self.cooldown = cooldown
    }
    
    func evaluate(snapshot: TelemetrySnapshot, context: RuleContext, deviceId: String, sequenceNumber: @escaping () -> Int64) async -> [AgentEvent] {
        let cooldownKey = "\(id)_cooldown"
        if await context.isInCooldown(key: cooldownKey, cooldown: cooldown) {
            return []
        }
        
        if snapshot.cpuLoad >= threshold {
            await context.addToWindow(key: "\(id)_consecutive", timestamp: snapshot.timestamp, windowSize: 300)
            let consecutiveCount = await context.getWindowCount(key: "\(id)_consecutive")
            
            if consecutiveCount >= consecutiveLimit {
                await context.setCooldown(key: cooldownKey, duration: cooldown)
                await context.clearWindow(key: "\(id)_consecutive")
                
                return [AgentEvent(
                    deviceId: deviceId,
                    timestamp: snapshot.timestamp,
                    category: .performance,
                    severity: .warning,
                    name: "High CPU Usage Detected",
                    attributes: [
                        "cpuLoad": .double(snapshot.cpuLoad),
                        "threshold": .double(threshold),
                        "consecutiveCount": .int(consecutiveCount)
                    ],
                    source: .ruleEngine,
                    sequenceNumber: sequenceNumber()
                )]
            }
        } else {
            await context.clearWindow(key: "\(id)_consecutive")
        }
        
        return []
    }
}

