//
//  AgentEvent.swift
//  EFB Agent
//
//  Core event data model
//

import Foundation

struct AgentEvent: Codable, Identifiable, Sendable {
    let eventId: UUID
    let deviceId: String
    let timestamp: Date
    let category: EventCategory
    let severity: EventSeverity
    let name: String
    let attributes: [String: CodableValue]
    let source: EventSource
    let sequenceNumber: Int64
    
    var id: UUID { eventId }
    
    init(
        deviceId: String,
        timestamp: Date = Date(),
        category: EventCategory,
        severity: EventSeverity,
        name: String,
        attributes: [String: CodableValue] = [:],
        source: EventSource,
        sequenceNumber: Int64
    ) {
        self.eventId = UUID()
        self.deviceId = deviceId
        self.timestamp = timestamp
        self.category = category
        self.severity = severity
        self.name = name
        self.attributes = attributes
        self.source = source
        self.sequenceNumber = sequenceNumber
    }
}

enum EventCategory: String, Codable, Sendable, CaseIterable {
    case system
    case performance
    case network
    case security
    case connectivity
    case battery
    case thermal
}

enum EventSeverity: String, Codable, Sendable, CaseIterable {
    case critical
    case error
    case warning
    case info
}

enum EventSource: String, Codable, Sendable {
    case ruleEngine
    case networkCollector
    case metricKit
    case diagnostics
    case systemCollector
}

// Heterogeneous value type for event attributes
enum CodableValue: Codable, Sendable {
    case string(String)
    case int(Int)
    case int64(Int64)
    case double(Double)
    case bool(Bool)
    case array([CodableValue])
    case dictionary([String: CodableValue])
}

