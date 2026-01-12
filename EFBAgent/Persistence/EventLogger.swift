//
//  EventLogger.swift
//  EFB Agent
//
//  Single entry point for event logging
//

import Foundation
import os.log

class EventLogger {
    private let store: EventStoring
    private let logger = Logger(subsystem: "com.efbagent", category: "EventLogger")
    
    init(store: EventStoring) {
        self.store = store
    }
    
    func log(_ event: AgentEvent) async throws {
        // Redact sensitive data before storage
        let redactedAttributes = Redactor.redact(event.attributes)
        let redactedEvent = AgentEvent(
            deviceId: event.deviceId,
            timestamp: event.timestamp,
            category: event.category,
            severity: event.severity,
            name: event.name,
            attributes: redactedAttributes,
            source: event.source,
            sequenceNumber: event.sequenceNumber
        )
        
        // Log to OSLog (privacy-aware)
        logger.info("Event: \(event.name, privacy: .public) [\(event.category.rawValue, privacy: .public)]")
        
        // Store encrypted (with redacted attributes)
        try await store.append(redactedEvent)
    }
}

