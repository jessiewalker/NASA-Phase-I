//
//  Rule.swift
//  EFB Agent
//
//  Detection rule protocol
//

import Foundation

protocol Rule: Sendable {
    var id: String { get }
    var name: String { get }
    
    func evaluate(
        snapshot: TelemetrySnapshot,
        context: RuleContext,
        deviceId: String,
        sequenceNumber: @escaping () -> Int64
    ) async -> [AgentEvent]
}

