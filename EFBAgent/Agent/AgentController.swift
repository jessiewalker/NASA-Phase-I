//
//  AgentController.swift
//  EFB Agent
//
//  Main agent orchestration controller
//

import Foundation
import Combine
import os.log
import UIKit

@MainActor
class AgentController: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var lastSnapshotTime: Date?
    @Published var lastUploadTime: Date?
    @Published var pendingEventsCount: Int = 0
    @Published var lastError: String?
    @Published var recentEvents: [AgentEvent] = []
    @Published var startTime: Date?
    @Published var lastRuleEvaluationTime: Date?
    @Published var currentConnectivity: TelemetrySnapshot.ConnectivitySummary?
    
    // Enhanced state tracking
    @Published var lastUploadAttemptTime: Date?
    @Published var lastSuccessfulUploadTime: Date?
    @Published var nextScheduledSnapshotTime: Date?
    @Published var nextUploadAttemptTime: Date?
    @Published var pendingEventBytes: Int64 = 0
    @Published var localStoreSizeBytes: Int64 = 0
    @Published var configSignatureStatus: ConfigSignatureStatus = .unknown
    
    // Real-time metrics series for sparklines (60 samples = 60 seconds at 1 Hz)
    @Published var cpuSeries: [Double] = [] // Normalized 0.0-1.0
    @Published var memSeries: [Double] = [] // MB used
    
    // Real-time metrics panel data (ring buffer)
    @Published var metricsSamples: [MetricsSample] = []
    @Published var metricsPaused: Bool = false
    private var metricsRingBuffer = MetricsRingBuffer(capacity: 60)
    private var metricsTimer: Timer?
    private var metricsSamplingInterval: TimeInterval = 1.0
    
    // Computed properties
    var uptime: TimeInterval {
        guard let startTime = startTime else { return 0 }
        return Date().timeIntervalSince(startTime)
    }
    
    var rulesetVersion: String {
        return "1.0"
    }
    
    var configVersion: String {
        return "1.0"
    }
    
    private(set) var store: EventStore?
    
    private let configManager: ConfigManager
    private var eventLogger: EventLogger!
    private var ruleEngine: RuleEngine!
    private var uploader: Uploader!
    private var systemCollector: SystemCollector!
    private var networkCollector: NetworkCollector!
    private var metricKitCollector: MetricsCollecting?
    
    private var cancellables = Set<AnyCancellable>()
    private var snapshotTask: Task<Void, Never>?
    private var uploadTask: Task<Void, Never>?
    private var sparklineTimer: Timer?
    private var currentSnapshot: TelemetrySnapshot?
    private let logger = Logger(subsystem: "com.efbagent", category: "AgentController")
    
    let deviceId: String
    
    init(configManager: ConfigManager) {
        self.configManager = configManager
        self.deviceId = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        self.configSignatureStatus = configManager.configSignatureStatus
        
        setupComponents()
        setupObservers()
        
        // Initial store metrics update
        Task {
            await updateStoreMetrics()
        }
        
        // Observe config signature status changes
        configManager.$configSignatureStatus
            .assign(to: &$configSignatureStatus)
    }
    
    private func setupComponents() {
        do {
            let store = try EventStore()
            self.store = store
            eventLogger = EventLogger(store: store)
            
            let uploadClient: Uploading = MockUploadEndpoint()
            uploader = Uploader(store: store, uploadClient: uploadClient, config: configManager.config)
            
            ruleEngine = RuleEngine(deviceId: deviceId)
            setupRules()
            
            systemCollector = SystemCollector(deviceId: deviceId, config: configManager.config)
            networkCollector = NetworkCollector(deviceId: deviceId)
            
            if #available(iOS 13.0, *) {
                let isSimulated = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
                metricKitCollector = MetricKitCollector(deviceId: deviceId, simulated: isSimulated)
            }
        } catch {
            logger.error("Failed to setup components: \(error.localizedDescription)")
            lastError = error.localizedDescription
        }
    }
    
    private func setupRules() {
        let config = configManager.config
        let thresholds = config.ruleThresholds
        
        Task {
            await ruleEngine.addRule(HighCpuUsageRule(
                threshold: thresholds.cpuThreshold,
                consecutiveLimit: 3,
                cooldown: 300
            ))
            
            await ruleEngine.addRule(MemoryPressureRule(
                threshold: thresholds.memoryThreshold,
                duration: 60,
                cooldown: 300
            ))
            
            await ruleEngine.addRule(ConnectivityFlapRule(
                changesPerMinute: thresholds.connectivityFlapThreshold,
                cooldown: 300
            ))
            
            await ruleEngine.addRule(RepeatedTLSFailureRule(
                failureCount: thresholds.tlsFailureThreshold,
                window: thresholds.tlsFailureWindow,
                cooldown: 300
            ))
            
            await ruleEngine.addRule(NetworkDestinationAllowlistRule(
                allowedHosts: config.allowedHosts,
                minimumHits: 5,
                cooldown: 300
            ))
            
            await ruleEngine.setQuietMode(config.quietMode)
        }
    }
    
    private func setupObservers() {
        configManager.$config
            .sink { [weak self] config in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    await self.ruleEngine.setQuietMode(config.quietMode)
                }
            }
            .store(in: &cancellables)
        
        networkCollector.eventsPublisher
            .sink { [weak self] event in
                Task { @MainActor [weak self] in
                    try? await self?.eventLogger.log(event)
                    self?.addToRecentEvents(event)
                }
            }
            .store(in: &cancellables)
        
        networkCollector.connectivityPublisher
            .sink { [weak self] connectivity in
                Task { @MainActor [weak self] in
                    self?.currentConnectivity = connectivity
                }
            }
            .store(in: &cancellables)
    }
    
    func start() {
        guard !isRunning else { return }
        
        isRunning = true
        startTime = Date()
        lastError = nil
        
        systemCollector.start()
        networkCollector.start()
        metricKitCollector?.start()
        
        startSnapshotCollection()
        startSparklineSampling()
        startMetricsCollection()
        
        Task {
            await uploader.start()
        }
        
        if #available(iOS 13.0, *) {
            metricKitCollector?.eventsPublisher
                .sink { [weak self] event in
                    Task { @MainActor [weak self] in
                        try? await self?.eventLogger.log(event)
                        self?.addToRecentEvents(event)
                    }
                }
                .store(in: &cancellables)
        }
    }
    
    func stop() {
        guard isRunning else { return }
        
        isRunning = false
        startTime = nil
        
        systemCollector.stop()
        networkCollector.stop()
        metricKitCollector?.stop()
        
        snapshotTask?.cancel()
        snapshotTask = nil
        
        sparklineTimer?.invalidate()
        sparklineTimer = nil
        
        metricsTimer?.invalidate()
        metricsTimer = nil
        
        Task {
            await uploader.stop()
        }
    }
    
    private func startSnapshotCollection() {
        snapshotTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            while !Task.isCancelled {
                do {
                    var snapshot = self.systemCollector.collectTelemetrySnapshot()
                    
                    let connectivity = self.networkCollector.getCurrentConnectivity()
                    let networkMetrics = self.networkCollector.getNetworkMetrics()
                    
                    snapshot = TelemetrySnapshot(
                        timestamp: snapshot.timestamp,
                        cpuLoad: snapshot.cpuLoad,
                        memoryUsed: snapshot.memoryUsed,
                        memoryAvailable: snapshot.memoryAvailable,
                        thermalState: snapshot.thermalState,
                        batteryState: snapshot.batteryState,
                        connectivity: connectivity,
                        networkMetrics: networkMetrics
                    )
                    
                    // Store current snapshot for sparkline sampling
                    self.currentSnapshot = snapshot
                    self.lastSnapshotTime = snapshot.timestamp
                    
                    self.lastRuleEvaluationTime = Date()
                    let events = await self.ruleEngine.evaluate(snapshot: snapshot)
                    
                    self.currentConnectivity = connectivity
                    
                    for event in events {
                        try await self.eventLogger.log(event)
                        self.addToRecentEvents(event)
                    }
                    
                    if let store = self.store {
                        self.pendingEventsCount = try await store.countPending()
                        self.pendingEventBytes = try await store.estimatePendingBytes()
                        self.localStoreSizeBytes = try await store.getStoreSize()
                    }
                    
                    let samplingRate = self.configManager.config.samplingRate
                    self.nextScheduledSnapshotTime = Date().addingTimeInterval(samplingRate)
                    let uploadInterval = self.configManager.config.uploadInterval
                    self.nextUploadAttemptTime = (self.lastUploadAttemptTime ?? Date()).addingTimeInterval(uploadInterval)
                    
                    try await Task.sleep(nanoseconds: UInt64(samplingRate * 1_000_000_000))
                } catch {
                    self.logger.error("Snapshot collection error: \(error.localizedDescription)")
                    self.lastError = error.localizedDescription
                }
            }
        }
    }
    
    private func addToRecentEvents(_ event: AgentEvent) {
        let now = Date()
        if let lastEvent = recentEvents.first,
           lastEvent.name == event.name,
           lastEvent.source == event.source,
           abs(now.timeIntervalSince(event.timestamp)) < 2.0 {
            return
        }
        
        recentEvents.insert(event, at: 0)
        if recentEvents.count > 200 {
            recentEvents = Array(recentEvents.prefix(200))
        }
    }
    
    func updatePendingCount() async {
        await updateStoreMetrics()
    }
    
    func triggerUpload() async {
        lastUploadAttemptTime = Date()
        do {
            try await uploader.uploadNow()
            lastSuccessfulUploadTime = Date()
            lastUploadTime = Date()
            await updateStoreMetrics()
        } catch {
            lastError = error.localizedDescription
            logger.error("Upload failed: \(error.localizedDescription)")
        }
    }
    
    func updateStoreMetrics() async {
        guard let store = store else { return }
        do {
            pendingEventsCount = try await store.countPending()
            pendingEventBytes = try await store.estimatePendingBytes()
            localStoreSizeBytes = try await store.getStoreSize()
        } catch {
            logger.error("Failed to update store metrics: \(error.localizedDescription)")
        }
    }
    
    func clearUploadedEvents() async {
        #if DEBUG
        guard let store = store else { return }
        do {
            try await store.deleteUploadedEvents()
            await updateStoreMetrics()
        } catch {
            logger.error("Failed to clear uploaded events: \(error.localizedDescription)")
        }
        #endif
    }
    
    func clearPendingEvents() async {
        #if DEBUG
        guard let store = store else { return }
        do {
            let batch = try await store.fetchBatch(limit: 10000)
            let ids = batch.map { $0.eventId }
            try await store.markUploaded(ids: ids)
            await updateStoreMetrics()
        } catch {
            logger.error("Failed to clear pending events: \(error.localizedDescription)")
        }
        #endif
    }
    
    func clearRecentEvents() {
        #if DEBUG
        recentEvents.removeAll()
        #endif
    }
    
    private func startSparklineSampling() {
        // Sample metrics at 1 Hz for sparklines (independent of snapshot cadence)
        sparklineTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Sample from current snapshot, or use fallback values
                if let snapshot = self.currentSnapshot {
                    // CPU: normalized 0.0-1.0
                    let cpu = max(0.0, min(1.0, snapshot.cpuLoad))
                    self.cpuSeries.append(cpu)
                    
                    // Memory: convert bytes to MB
                    let memMB = Double(snapshot.memoryUsed) / 1_000_000.0
                    self.memSeries.append(memMB)
                } else {
                    // Fallback: sample from current system collector
                    let snapshot = self.systemCollector.collectTelemetrySnapshot()
                    let cpu = max(0.0, min(1.0, snapshot.cpuLoad))
                    self.cpuSeries.append(cpu)
                    let memMB = Double(snapshot.memoryUsed) / 1_000_000.0
                    self.memSeries.append(memMB)
                }
                
                // Keep only last 60 samples (60 seconds of history)
                if self.cpuSeries.count > 60 {
                    self.cpuSeries.removeFirst()
                }
                if self.memSeries.count > 60 {
                    self.memSeries.removeFirst()
                }
            }
        }
    }
    
    func canUpload() -> Bool {
        guard let conn = currentConnectivity else { return false }
        let isConnected = conn.isConnected && !conn.isConstrained
        
        if configManager.config.uploadEndpoint == nil {
            return isConnected
        }
        
        return isConnected && configManager.config.uploadSigningSecret != nil
    }
    
    // MARK: - Real-Time Metrics Collection
    
    private func startMetricsCollection() {
        metricsTimer = Timer.scheduledTimer(withTimeInterval: metricsSamplingInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, !self.metricsPaused else { return }
                
                // Sample from current snapshot
                var cpuPercent = 0.0
                var memoryMB = 0.0
                var netTxKBps: Double? = nil
                var netRxKBps: Double? = nil
                
                if let snapshot = self.currentSnapshot {
                    cpuPercent = snapshot.cpuLoad * 100.0
                    memoryMB = Double(snapshot.memoryUsed) / 1_000_000.0
                } else {
                    // Fallback: sample from system collector
                    let snapshot = self.systemCollector.collectTelemetrySnapshot()
                    cpuPercent = snapshot.cpuLoad * 100.0
                    memoryMB = Double(snapshot.memoryUsed) / 1_000_000.0
                }
                
                // Get network throughput
                let throughput = self.networkCollector.getNetworkThroughput()
                netTxKBps = throughput.txKBps
                netRxKBps = throughput.rxKBps
                
                let sample = MetricsSample(
                    timestamp: Date(),
                    cpuPercent: cpuPercent,
                    memoryMB: memoryMB,
                    netTxKBps: netTxKBps,
                    netRxKBps: netRxKBps
                )
                
                // Append to ring buffer
                await self.metricsRingBuffer.append(sample)
                
                // Update published array (for UI)
                let allSamples = await self.metricsRingBuffer.getAll()
                self.metricsSamples = allSamples
            }
        }
    }
    
    func pauseMetrics() {
        metricsPaused = true
    }
    
    func resumeMetrics() {
        metricsPaused = false
    }
    
    func resetMetricsWindow() async {
        await metricsRingBuffer.reset()
        metricsSamples = []
    }
}

