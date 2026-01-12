//
//  Uploading.swift
//  EFB Agent
//
//  Protocol for event upload clients
//

import Foundation

protocol Uploading: Sendable {
    func upload(_ events: [AgentEvent]) async throws -> [UUID]
}

