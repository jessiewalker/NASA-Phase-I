//
//  NetworkCollector.swift
//  EFB Agent
//
//  Network connectivity and URLSession metrics collection
//

import Foundation
import Combine
import Network

protocol NetworkCollecting {
    var eventsPublisher: AnyPublisher<AgentEvent, Never> { get }
    var connectivityPublisher: AnyPublisher<TelemetrySnapshot.ConnectivitySummary, Never> { get }
    func start()
    func stop()
    func getCurrentConnectivity() -> TelemetrySnapshot.ConnectivitySummary
    func getNetworkMetrics() -> TelemetrySnapshot.NetworkMetricsSummary?
    func getNetworkThroughput() -> (txKBps: Double, rxKBps: Double)
}

class NetworkCollector: NSObject, NetworkCollecting, URLSessionTaskDelegate {
    let eventsPublisher: AnyPublisher<AgentEvent, Never>
    let connectivityPublisher: AnyPublisher<TelemetrySnapshot.ConnectivitySummary, Never>
    
    private let eventsSubject = PassthroughSubject<AgentEvent, Never>()
    private let connectivitySubject = CurrentValueSubject<TelemetrySnapshot.ConnectivitySummary, Never>(
        TelemetrySnapshot.ConnectivitySummary(isConnected: false, isExpensive: false, isConstrained: false, interfaceType: nil, dnsServers: [], lastChangeTime: Date())
    )
    private var lastConnectivityState: Bool = false
    
    private let deviceId: String
    private var sequenceNumber: Int64 = 0
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.efbagent.network.monitor")
    
    // URLSession metrics tracking
    private var urlSession: URLSession!
    private var taskMetrics: [URLSessionTaskMetrics] = []
    private var requestCount = 0
    private var successCount = 0
    private var failureCount = 0
    private var tlsFailureCount = 0
    private var recentDestinations: Set<String> = []
    private let metricsLock = NSLock()
    
    // Network throughput tracking (for real-time metrics)
    private var lastSampleTime: Date = Date()
    private var cumulativeTxBytes: Int64 = 0
    private var cumulativeRxBytes: Int64 = 0
    private var lastReportedTxBytes: Int64 = 0
    private var lastReportedRxBytes: Int64 = 0
    
    init(deviceId: String) {
        self.deviceId = deviceId
        self.eventsPublisher = eventsSubject.eraseToAnyPublisher()
        self.connectivityPublisher = connectivitySubject.eraseToAnyPublisher()
        
        super.init()
        
        // Setup URLSession with custom delegate for metrics
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        self.urlSession = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue())
    }
    
    func start() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        pathMonitor.start(queue: monitorQueue)
    }
    
    func stop() {
        pathMonitor.cancel()
    }
    
    private func handlePathUpdate(_ path: NWPath) {
        let isConnected = path.status == .satisfied
        let changeTime = isConnected != lastConnectivityState ? Date() : connectivitySubject.value.lastChangeTime
        
        let summary = TelemetrySnapshot.ConnectivitySummary(
            isConnected: isConnected,
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            interfaceType: Self.interfaceTypeString(path),
            dnsServers: [],
            lastChangeTime: changeTime
        )
        
        let previous = connectivitySubject.value
        lastConnectivityState = isConnected
        connectivitySubject.send(summary)
        
        // Emit connectivity changed event
        if previous.isConnected != summary.isConnected {
            let event = AgentEvent(
                deviceId: deviceId,
                category: .connectivity,
                severity: summary.isConnected ? .info : .warning,
                name: summary.isConnected ? "Connectivity Restored" : "Connectivity Lost",
                attributes: [
                    "interface": .string(summary.interfaceType ?? "unknown"),
                    "expensive": .bool(summary.isExpensive),
                    "constrained": .bool(summary.isConstrained)
                ],
                source: .networkCollector,
                sequenceNumber: nextSequenceNumber()
            )
            eventsSubject.send(event)
        }
    }
    
    private static func interfaceTypeString(_ path: NWPath) -> String? {
        if path.usesInterfaceType(.wifi) { return "WiFi" }
        if path.usesInterfaceType(.cellular) { return "Cellular" }
        return nil
    }
    
    func getCurrentConnectivity() -> TelemetrySnapshot.ConnectivitySummary {
        return connectivitySubject.value
    }
    
    func getNetworkMetrics() -> TelemetrySnapshot.NetworkMetricsSummary? {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        guard requestCount > 0 else { return nil }
        
        let avgResponseTime = taskMetrics.compactMap { metrics -> TimeInterval? in
            guard let transaction = metrics.transactionMetrics.first else { return nil }
            return transaction.responseEndDate?.timeIntervalSince(transaction.requestStartDate ?? Date())
        }.reduce(0.0, +) / Double(taskMetrics.count)
        
        return TelemetrySnapshot.NetworkMetricsSummary(
            totalRequests: requestCount,
            successCount: successCount,
            failureCount: failureCount,
            avgResponseTime: avgResponseTime,
            tlsFailureCount: tlsFailureCount,
            recentDestinations: Array(recentDestinations)
        )
    }
    
    // Get current network throughput (Tx/Rx KBps)
    func getNetworkThroughput() -> (txKBps: Double, rxKBps: Double) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        let now = Date()
        let timeDelta = now.timeIntervalSince(lastSampleTime)
        
        guard timeDelta > 0.5 else { // Need at least 0.5s for meaningful rate
            return (0, 0)
        }
        
        // Update cumulative bytes from task metrics (only count new metrics since last sample)
        // Note: This is an approximation - we're tracking bytes from URLSession metrics
        // which only includes HTTP requests made by the app, not all network traffic
        var currentTxBytes: Int64 = 0
        var currentRxBytes: Int64 = 0
        
        for metrics in taskMetrics {
            if let transaction = metrics.transactionMetrics.first {
                currentTxBytes += Int64(transaction.countOfRequestHeaderBytesSent + transaction.countOfRequestBodyBytesSent)
                currentRxBytes += Int64(transaction.countOfResponseHeaderBytesReceived + transaction.countOfResponseBodyBytesReceived)
            }
        }
        
        // Calculate rate from delta
        let txDelta = Double(currentTxBytes - lastReportedTxBytes) / 1024.0 // KB
        let rxDelta = Double(currentRxBytes - lastReportedRxBytes) / 1024.0 // KB
        
        let txKBps = max(0, txDelta / timeDelta)
        let rxKBps = max(0, rxDelta / timeDelta)
        
        lastSampleTime = now
        lastReportedTxBytes = currentTxBytes
        lastReportedRxBytes = currentRxBytes
        
        return (txKBps, rxKBps)
    }
    
    // MARK: - URLSessionTaskDelegate
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        metricsLock.lock()
        defer { metricsLock.unlock() }
        
        requestCount += 1
        
        if let error = error {
            failureCount += 1
            if (error as NSError).code == NSURLErrorSecureConnectionFailed {
                tlsFailureCount += 1
            }
        } else {
            successCount += 1
        }
        
        if let host = task.currentRequest?.url?.host {
            recentDestinations.insert(host)
            // Keep only last 50 destinations
            if recentDestinations.count > 50 {
                recentDestinations.removeFirst()
            }
        }
    }
    
    private func nextSequenceNumber() -> Int64 {
        sequenceNumber += 1
        return sequenceNumber
    }
}

