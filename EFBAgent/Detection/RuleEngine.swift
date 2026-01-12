//
//  RuleEngine.swift
//  EFB Agent
//
//  Rule evaluation engine with rate limiting and cooldowns
//

import Foundation

actor RuleContext {
    private var windows: [String: [(timestamp: Date, windowSize: TimeInterval)]] = [:]
    private var cooldowns: [String: Date] = [:]
    
    func addToWindow(key: String, timestamp: Date, windowSize: TimeInterval) {
        if windows[key] == nil {
            windows[key] = []
        }
        windows[key]?.append((timestamp: timestamp, windowSize: windowSize))
        
        // Clean old entries outside window
        let cutoff = timestamp.addingTimeInterval(-windowSize)
        windows[key]?.removeAll { $0.timestamp < cutoff }
    }
    
    func getWindowCount(key: String) -> Int {
        return windows[key]?.count ?? 0
    }
    
    func clearWindow(key: String) {
        windows[key] = nil
    }
    
    func setCooldown(key: String, duration: TimeInterval) {
        cooldowns[key] = Date().addingTimeInterval(duration)
    }
    
    func isInCooldown(key: String, cooldown: TimeInterval) -> Bool {
        guard let cooldownEnd = cooldowns[key] else { return false }
        if Date() >= cooldownEnd {
            cooldowns[key] = nil
            return false
        }
        return true
    }
}

actor RuleEngine {
    private var rules: [Rule] = []
    private let context = RuleContext()
    private let deviceId: String
    private var sequenceNumber: Int64 = 0
    private var quietMode = false
    
    init(deviceId: String) {
        self.deviceId = deviceId
    }
    
    func addRule(_ rule: Rule) {
        rules.append(rule)
    }
    
    func setQuietMode(_ enabled: Bool) {
        quietMode = enabled
    }
    
    func evaluate(snapshot: TelemetrySnapshot) async -> [AgentEvent] {
        guard !quietMode else { return [] }
        
        var allEvents: [AgentEvent] = []
        
        for rule in rules {
            let seqNum = await getNextSequenceNumber()
            let events = await rule.evaluate(
                snapshot: snapshot,
                context: context,
                deviceId: deviceId,
                sequenceNumber: { seqNum }
            )
            allEvents.append(contentsOf: events)
        }
        
        return allEvents
    }
    
    private func getNextSequenceNumber() async -> Int64 {
        sequenceNumber += 1
        return sequenceNumber
    }
}

