//
//  MemoryPressureRule.swift
//  EFB Agent
//
//  Detects sustained memory pressure
//

import Foundation

struct MemoryPressureRule: Rule {
    let id = "memory_pressure"
    let name = "Memory Pressure"
    
    let threshold: Int64 // bytes
    let duration: TimeInterval // seconds above threshold
    let cooldown: TimeInterval
    
    init(threshold: Int64 = 1_000_000_000, duration: TimeInterval = 60, cooldown: TimeInterval = 300) {
        self.threshold = threshold
        self.duration = duration
        self.cooldown = cooldown
    }
    
    func evaluate(snapshot: TelemetrySnapshot, context: RuleContext, deviceId: String, sequenceNumber: @escaping () -> Int64) async -> [AgentEvent] {
        let cooldownKey = "\(id)_cooldown"
        if await context.isInCooldown(key: cooldownKey, cooldown: cooldown) {
            return []
        }
        
        if snapshot.memoryUsed >= threshold {
            await context.addToWindow(key: "\(id)_window", timestamp: snapshot.timestamp, windowSize: duration)
            let windowCount = await context.getWindowCount(key: "\(id)_window")
            
            // Check if we've exceeded threshold for duration
            if Double(windowCount) * 30.0 >= duration { // Assuming 30s sampling rate
                await context.setCooldown(key: cooldownKey, duration: cooldown)
                await context.clearWindow(key: "\(id)_window")
                
                return [AgentEvent(
                    deviceId: deviceId,
                    timestamp: snapshot.timestamp,
                    category: .performance,
                    severity: .warning,
                    name: "Memory Pressure Detected",
                    attributes: [
                        "memoryUsed": .int64(snapshot.memoryUsed),
                        "threshold": .int64(threshold),
                        "duration": .double(duration)
                    ],
                    source: .ruleEngine,
                    sequenceNumber: sequenceNumber()
                )]
            }
        } else {
            await context.clearWindow(key: "\(id)_window")
        }
        
        return []
    }
}

