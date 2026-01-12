//
//  MetricKitCollector.swift
//  EFB Agent
//
//  MetricKit telemetry collection (or simulation in simulator)
//

import Foundation
import Combine
import os.log

#if canImport(MetricKit)
import MetricKit
#endif

@available(iOS 13.0, *)
class MetricKitCollector: NSObject, MetricsCollecting {
    let eventsPublisher: AnyPublisher<AgentEvent, Never>
    private let eventsSubject = PassthroughSubject<AgentEvent, Never>()
    
    private let deviceId: String
    private var sequenceNumber: Int64 = 0
    private let simulated: Bool
    private let logger = Logger(subsystem: "com.efbagent", category: "MetricKitCollector")
    private var cancellables = Set<AnyCancellable>()
    
    init(deviceId: String, simulated: Bool = false) {
        self.deviceId = deviceId
        self.simulated = simulated
        self.eventsPublisher = eventsSubject.eraseToAnyPublisher()
        super.init()
    }
    
    func start() {
        if simulated {
            // Simulate MetricKit events in simulator
            simulateEvents()
        } else {
            #if canImport(MetricKit)
            // Real MetricKit on device
            MXMetricManager.shared.add(self)
            #endif
        }
    }
    
    func stop() {
        if !simulated {
            #if canImport(MetricKit)
            MXMetricManager.shared.remove(self)
            #endif
        }
    }
    
    private func simulateEvents() {
        // Generate occasional simulated events
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.generateSimulatedEvent()
            }
            .store(in: &cancellables)
    }
    
    private func generateSimulatedEvent() {
        let event = AgentEvent(
            deviceId: deviceId,
            category: .performance,
            severity: .warning,
            name: "Simulated MetricKit Hang",
            attributes: [
                "simulated": .bool(true),
                "duration": .double(2.5)
            ],
            source: .metricKit,
            sequenceNumber: nextSequenceNumber()
        )
        eventsSubject.send(event)
    }
    
    private func nextSequenceNumber() -> Int64 {
        sequenceNumber += 1
        return sequenceNumber
    }
    
}

#if canImport(MetricKit)
@available(iOS 13.0, *)
extension MetricKitCollector: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        for payload in payloads {
            // Process CPU metrics
            if let cpuMetrics = payload.cpuMetrics {
                // CPU metrics available for processing
            }
            
            // Generate event for MetricKit payload
            let event = AgentEvent(
                deviceId: deviceId,
                category: .performance,
                severity: .info,
                name: "MetricKit Payload Received",
                attributes: [
                    "timeStampBegin": .double(payload.timeStampBegin.timeIntervalSince1970),
                    "timeStampEnd": .double(payload.timeStampEnd.timeIntervalSince1970)
                ],
                source: .metricKit,
                sequenceNumber: nextSequenceNumber()
            )
            eventsSubject.send(event)
        }
    }
}
#endif

