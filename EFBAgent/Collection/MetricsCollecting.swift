//
//  MetricsCollecting.swift
//  EFB Agent
//
//  Protocol for telemetry collectors
//

import Foundation
import Combine

protocol MetricsCollecting: AnyObject {
    var eventsPublisher: AnyPublisher<AgentEvent, Never> { get }
    func start()
    func stop()
}

