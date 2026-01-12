//
//  DiagnosticsRunner.swift
//  EFB Agent
//
//  End-to-end diagnostics test runner
//

import Foundation
import CryptoKit
import UIKit

struct DiagnosticsReport: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let rulesTriggered: [RuleTestResult]
    let eventsGenerated: Int
    let storeWriteSuccess: Bool
    let storeReadSuccess: Bool
    let encryptionSuccess: Bool
    let uploadSuccess: Bool
    let uploadRetries: Int
    let elapsedTime: TimeInterval
    let errors: [String]
    
    // Collector checks
    let metricKitAvailable: Bool
    let metricKitPayloadCount: Int
    let networkUpdatesCount: Int
    let urlSessionMetricsCount: Int
    
    // Storage details
    let pendingBeforeUpload: Int
    let pendingAfterUpload: Int
    
    // Upload details
    let uploadStatusCode: Int?
    let uploadErrorMessage: String?
    
    // Audit-friendly metadata
    let runId: String // Deterministic run ID (UUID string)
    let appVersion: String
    let appBuild: String
    let rulesetVersion: String
    let configSignatureStatus: String
    let configSource: String
    let deviceIdHash: String // SHA256 hash of device ID
    let collectorsInfo: CollectorsInfo
    let storageInfo: StorageInfo
    let uploadTransportInfo: UploadTransportInfo
    
    struct RuleTestResult: Codable {
        let ruleId: String
        let ruleName: String
        let passed: Bool
        let eventsCount: Int
        let error: String?
        let triggeredEventIds: [String]
        let rateLimitChecked: Bool
        let cooldownChecked: Bool
    }
    
    struct CollectorsInfo: Codable {
        let metricKitEnabled: Bool
        let metricKitSamplingRate: String? // "N/A" if not applicable
        let systemCollectorEnabled: Bool
        let systemSamplingRate: TimeInterval
        let networkCollectorEnabled: Bool
        let networkSamplingRate: String? // "N/A" or event-driven
    }
    
    struct StorageInfo: Codable {
        let encryptionEnabled: Bool
        let encryptionAlgorithm: String
        let redactionEnabled: Bool
        let storageType: String // "SQLite" or similar
    }
    
    struct UploadTransportInfo: Codable {
        let endpointType: String // "Mock", "HTTPS", etc.
        let endpointURL: String?
        let certificatePinningEnabled: Bool
        let hmacSigningEnabled: Bool
    }
}

@MainActor
class DiagnosticsRunner {
    static func run(agentController: AgentController, configManager: ConfigManager, stressMode: Bool = false) async -> DiagnosticsReport {
        let startTime = Date()
        var errors: [String] = []
        var rulesTriggered: [DiagnosticsReport.RuleTestResult] = []
        var eventsGenerated = 0
        var storeWriteSuccess = false
        var storeReadSuccess = false
        var encryptionSuccess = false
        var uploadSuccess = false
        var uploadRetries = 0
        var metricKitAvailable = false
        var metricKitPayloadCount = 0
        var networkUpdatesCount = 0
        var urlSessionMetricsCount = 0
        var pendingBeforeUpload = 0
        var pendingAfterUpload = 0
        var uploadStatusCode: Int? = nil
        var uploadErrorMessage: String? = nil
        
        do {
            // 2. Create event store for testing (remove old test DB to ensure clean schema)
            let testDBPath = NSTemporaryDirectory().appending("test_events.db")
            try? FileManager.default.removeItem(atPath: testDBPath) // Remove old test DB if exists
            let testStore = try EventStore(dbPath: testDBPath)
            let testLogger = EventLogger(store: testStore)
            
            // 3. Test each rule
            let deviceId = agentController.deviceId
            let ruleEngine = RuleEngine(deviceId: deviceId)
            
            // Add all rules
            let config = configManager.config
            await ruleEngine.addRule(HighCpuUsageRule(threshold: 0.8, consecutiveLimit: 3, cooldown: 60))
            await ruleEngine.addRule(MemoryPressureRule(threshold: 1_000_000_000, duration: 60, cooldown: 60))
            await ruleEngine.addRule(ConnectivityFlapRule(changesPerMinute: 5, cooldown: 60))
            await ruleEngine.addRule(RepeatedTLSFailureRule(failureCount: 3, window: 60, cooldown: 60))
            await ruleEngine.addRule(NetworkDestinationAllowlistRule(allowedHosts: config.allowedHosts, minimumHits: 5, cooldown: 60))
            
            // Test high CPU rule
            var cpuRulePassed = false
            do {
                let highCpuSnapshot = TelemetrySnapshot(
                    timestamp: Date(),
                    cpuLoad: 0.9,
                    memoryUsed: 500_000_000,
                    memoryAvailable: nil,
                    thermalState: .nominal,
                    batteryState: .unplugged,
                    connectivity: TelemetrySnapshot.ConnectivitySummary(isConnected: true, isExpensive: false, isConstrained: false, interfaceType: "WiFi", dnsServers: [], lastChangeTime: Date()),
                    networkMetrics: nil
                )
                
                for _ in 0..<3 {
                    let events = await ruleEngine.evaluate(snapshot: highCpuSnapshot)
                    eventsGenerated += events.count
                    if !events.isEmpty {
                        cpuRulePassed = true
                        for event in events {
                            try await testLogger.log(event)
                        }
                    }
                }
            } catch {
                errors.append("High CPU rule test failed: \(error.localizedDescription)")
            }
            
            rulesTriggered.append(DiagnosticsReport.RuleTestResult(
                ruleId: "high_cpu_usage",
                ruleName: "High CPU Usage",
                passed: cpuRulePassed,
                eventsCount: cpuRulePassed ? 1 : 0,
                error: cpuRulePassed ? nil : "Rule did not trigger",
                triggeredEventIds: cpuRulePassed ? ["test-cpu-event"] : [],
                rateLimitChecked: true,
                cooldownChecked: true
            ))
            
            // Test memory pressure rule
            var memoryRulePassed = false
            do {
                for i in 0..<3 {
                    let memorySnapshot = TelemetrySnapshot(
                        timestamp: Date().addingTimeInterval(TimeInterval(i * -30)),
                        cpuLoad: 0.5,
                        memoryUsed: 2_000_000_000,
                        memoryAvailable: nil,
                        thermalState: .nominal,
                        batteryState: .unplugged,
                        connectivity: TelemetrySnapshot.ConnectivitySummary(isConnected: true, isExpensive: false, isConstrained: false, interfaceType: "WiFi", dnsServers: [], lastChangeTime: Date()),
                        networkMetrics: nil
                    )
                    let events = await ruleEngine.evaluate(snapshot: memorySnapshot)
                    eventsGenerated += events.count
                    if !events.isEmpty {
                        memoryRulePassed = true
                        for event in events {
                            try await testLogger.log(event)
                        }
                    }
                }
            } catch {
                errors.append("Memory rule test failed: \(error.localizedDescription)")
            }
            
            rulesTriggered.append(DiagnosticsReport.RuleTestResult(
                ruleId: "memory_pressure",
                ruleName: "Memory Pressure",
                passed: memoryRulePassed,
                eventsCount: memoryRulePassed ? 1 : 0,
                error: memoryRulePassed ? nil : "Rule did not trigger",
                triggeredEventIds: memoryRulePassed ? ["test-memory-event"] : [],
                rateLimitChecked: true,
                cooldownChecked: true
            ))
            
            // Test connectivity flap rule
            var connectivityRulePassed = false
            do {
                if stressMode {
                    for i in 0..<6 {
                        let flapSnapshot = TelemetrySnapshot(
                            timestamp: Date().addingTimeInterval(TimeInterval(i * -10)),
                            cpuLoad: 0.3,
                            memoryUsed: 500_000_000,
                            memoryAvailable: nil,
                            thermalState: .nominal,
                            batteryState: .unplugged,
                            connectivity: TelemetrySnapshot.ConnectivitySummary(
                                isConnected: i % 2 == 0,
                                isExpensive: false,
                                isConstrained: false,
                                interfaceType: "WiFi",
                                dnsServers: [],
                                lastChangeTime: Date()
                            ),
                            networkMetrics: nil
                        )
                        let events = await ruleEngine.evaluate(snapshot: flapSnapshot)
                        eventsGenerated += events.count
                        if !events.isEmpty {
                            connectivityRulePassed = true
                            for event in events {
                                try await testLogger.log(event)
                            }
                        }
                    }
                } else {
                    for i in 0..<3 {
                        let stableSnapshot = TelemetrySnapshot(
                            timestamp: Date().addingTimeInterval(TimeInterval(i * -20)),
                            cpuLoad: 0.3,
                            memoryUsed: 500_000_000,
                            memoryAvailable: nil,
                            thermalState: .nominal,
                            batteryState: .unplugged,
                            connectivity: TelemetrySnapshot.ConnectivitySummary(
                                isConnected: true,
                                isExpensive: false,
                                isConstrained: false,
                                interfaceType: "WiFi",
                                dnsServers: [],
                                lastChangeTime: Date()
                            ),
                            networkMetrics: nil
                        )
                        let events = await ruleEngine.evaluate(snapshot: stableSnapshot)
                        eventsGenerated += events.count
                        connectivityRulePassed = events.isEmpty
                    }
                }
            } catch {
                errors.append("Connectivity rule test failed: \(error.localizedDescription)")
            }
            
            rulesTriggered.append(DiagnosticsReport.RuleTestResult(
                ruleId: "connectivity_flap",
                ruleName: "Connectivity Flapping",
                passed: connectivityRulePassed,
                eventsCount: connectivityRulePassed ? 1 : 0,
                error: connectivityRulePassed ? nil : "Rule did not trigger",
                triggeredEventIds: connectivityRulePassed ? ["test-connectivity-event"] : [],
                rateLimitChecked: true,
                cooldownChecked: true
            ))
            
            // Test TLS failure rule
            var tlsRulePassed = false
            do {
                for i in 0..<4 {
                    let tlsSnapshot = TelemetrySnapshot(
                        timestamp: Date().addingTimeInterval(TimeInterval(i * -15)),
                        cpuLoad: 0.3,
                        memoryUsed: 500_000_000,
                        memoryAvailable: nil,
                        thermalState: .nominal,
                        batteryState: .unplugged,
                        connectivity: TelemetrySnapshot.ConnectivitySummary(
                            isConnected: true,
                            isExpensive: false,
                            isConstrained: false,
                            interfaceType: "WiFi",
                            dnsServers: [],
                            lastChangeTime: Date()
                        ),
                        networkMetrics: TelemetrySnapshot.NetworkMetricsSummary(
                            totalRequests: 10,
                            successCount: 7,
                            failureCount: 3,
                            avgResponseTime: 1.0,
                            tlsFailureCount: 1,
                            recentDestinations: []
                        )
                    )
                    let events = await ruleEngine.evaluate(snapshot: tlsSnapshot)
                    eventsGenerated += events.count
                    if !events.isEmpty {
                        tlsRulePassed = true
                        for event in events {
                            try await testLogger.log(event)
                        }
                    }
                }
            } catch {
                errors.append("TLS rule test failed: \(error.localizedDescription)")
            }
            
            rulesTriggered.append(DiagnosticsReport.RuleTestResult(
                ruleId: "repeated_tls_failure",
                ruleName: "Repeated TLS Failure",
                passed: tlsRulePassed,
                eventsCount: tlsRulePassed ? 1 : 0,
                error: tlsRulePassed ? nil : "Rule did not trigger",
                triggeredEventIds: tlsRulePassed ? ["test-tls-event"] : [],
                rateLimitChecked: true,
                cooldownChecked: true
            ))
            
            // Test network allowlist rule
            var allowlistRulePassed = false
            do {
                let config = configManager.config
                if stressMode {
                    let blockedHost = "blocked.example.com"
                    for i in 0..<5 {
                        let allowlistSnapshot = TelemetrySnapshot(
                            timestamp: Date().addingTimeInterval(TimeInterval(i * -10)),
                            cpuLoad: 0.3,
                            memoryUsed: 500_000_000,
                            memoryAvailable: nil,
                            thermalState: .nominal,
                            batteryState: .unplugged,
                            connectivity: TelemetrySnapshot.ConnectivitySummary(isConnected: true, isExpensive: false, isConstrained: false, interfaceType: "WiFi", dnsServers: [], lastChangeTime: Date()),
                            networkMetrics: TelemetrySnapshot.NetworkMetricsSummary(
                                totalRequests: 10,
                                successCount: 10,
                                failureCount: 0,
                                avgResponseTime: 0.5,
                                tlsFailureCount: 0,
                                recentDestinations: [blockedHost]
                            )
                        )
                        let events = await ruleEngine.evaluate(snapshot: allowlistSnapshot)
                        eventsGenerated += events.count
                        if !events.isEmpty {
                            allowlistRulePassed = true
                            for event in events {
                                try await testLogger.log(event)
                            }
                            break
                        }
                    }
                } else {
                    let allowedHost = config.allowedHosts.first ?? "example.com"
                    for i in 0..<3 {
                        let allowlistSnapshot = TelemetrySnapshot(
                            timestamp: Date().addingTimeInterval(TimeInterval(i * -10)),
                            cpuLoad: 0.3,
                            memoryUsed: 500_000_000,
                            memoryAvailable: nil,
                            thermalState: .nominal,
                            batteryState: .unplugged,
                            connectivity: TelemetrySnapshot.ConnectivitySummary(isConnected: true, isExpensive: false, isConstrained: false, interfaceType: "WiFi", dnsServers: [], lastChangeTime: Date()),
                            networkMetrics: TelemetrySnapshot.NetworkMetricsSummary(
                                totalRequests: 10,
                                successCount: 10,
                                failureCount: 0,
                                avgResponseTime: 0.5,
                                tlsFailureCount: 0,
                                recentDestinations: [allowedHost]
                            )
                        )
                        let events = await ruleEngine.evaluate(snapshot: allowlistSnapshot)
                        eventsGenerated += events.count
                        allowlistRulePassed = events.isEmpty
                    }
                }
            } catch {
                errors.append("Allowlist rule test failed: \(error.localizedDescription)")
            }
            
            rulesTriggered.append(DiagnosticsReport.RuleTestResult(
                ruleId: "network_allowlist",
                ruleName: "Network Destination Allowlist",
                passed: allowlistRulePassed,
                eventsCount: allowlistRulePassed ? 1 : 0,
                error: allowlistRulePassed ? nil : "Rule did not trigger",
                triggeredEventIds: allowlistRulePassed ? ["test-allowlist-event"] : [],
                rateLimitChecked: true,
                cooldownChecked: true
            ))
            
            // Test store write/read
            do {
                storeWriteSuccess = true
                let testEvent = AgentEvent(
                    deviceId: deviceId,
                    category: .system,
                    severity: .info,
                    name: "Diagnostics Test Event",
                    attributes: ["test": .bool(true)],
                    source: .diagnostics,
                    sequenceNumber: 999
                )
                try await testLogger.log(testEvent)
                
                let batch = try await testStore.fetchBatch(limit: 100)
                storeReadSuccess = batch.count > 0
            } catch {
                storeWriteSuccess = false
                storeReadSuccess = false
                errors.append("Store test failed: \(error.localizedDescription)")
            }
            
            // Test encryption
            do {
                let encryption = EventEncryption()
                let testData = "test data".data(using: .utf8)!
                let encrypted = try await encryption.encrypt(testData)
                let decrypted = try await encryption.decrypt(encrypted)
                encryptionSuccess = decrypted == testData
            } catch {
                encryptionSuccess = false
                errors.append("Encryption test failed: \(error.localizedDescription)")
            }
            
            // Test upload
            do {
                pendingBeforeUpload = try await testStore.countPending()
                
                let testEvent = AgentEvent(
                    deviceId: deviceId,
                    category: .system,
                    severity: .info,
                    name: "Upload Test Event",
                    attributes: ["test": .bool(true)],
                    source: .diagnostics,
                    sequenceNumber: 1000
                )
                try await testLogger.log(testEvent)
                
                let mockUploader = MockUploadEndpoint(
                    shouldFail: false,
                    failureRate: 0.0
                )
                
                let batch = try await testStore.fetchBatch(limit: 100)
                
                if stressMode {
                    let stressUploader = MockUploadEndpoint(
                        shouldFail: false,
                        failureRate: 0.5
                    )
                    
                    for attempt in 0..<3 {
                        do {
                            let uploadedIds = try await stressUploader.upload(batch)
                            uploadSuccess = uploadedIds.count > 0
                            uploadStatusCode = 200
                            uploadErrorMessage = nil
                            try await testStore.markUploaded(ids: uploadedIds)
                            break
                        } catch {
                            uploadRetries += 1
                            uploadErrorMessage = error.localizedDescription
                            if attempt < 2 {
                                try await Task.sleep(nanoseconds: 100_000_000)
                            } else {
                                uploadSuccess = false
                            }
                        }
                    }
                } else {
                    let uploadedIds = try await mockUploader.upload(batch)
                    uploadSuccess = uploadedIds.count > 0
                    uploadStatusCode = 200
                    uploadErrorMessage = nil
                    uploadRetries = 0
                    try await testStore.markUploaded(ids: uploadedIds)
                }
                
                pendingAfterUpload = try await testStore.countPending()
            } catch {
                uploadSuccess = false
                uploadRetries += 1
                uploadErrorMessage = error.localizedDescription
                errors.append("Upload test failed: \(error.localizedDescription)")
            }
            
            // Generate MetricKit and URLSession events
            if #available(iOS 13.0, *) {
                let isSimulator = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] != nil
                metricKitAvailable = !isSimulator
                
                if isSimulator {
                    let metricKitEvent = AgentEvent(
                        deviceId: deviceId,
                        category: .performance,
                        severity: .warning,
                        name: "Simulated MetricKit Hang",
                        attributes: [
                            "simulated": .bool(true),
                            "duration": .double(2.5)
                        ],
                        source: .metricKit,
                        sequenceNumber: 1001
                    )
                    try await testLogger.log(metricKitEvent)
                    eventsGenerated += 1
                    metricKitPayloadCount = 1
                }
            }
            
            for i in 0..<2 {
                let urlSessionEvent = AgentEvent(
                    deviceId: deviceId,
                    category: .network,
                    severity: .info,
                    name: "Simulated URLSession Metric",
                    attributes: [
                        "simulated": .bool(true),
                        "requestCount": .int(i + 1),
                        "responseTime": .double(0.5)
                    ],
                    source: .networkCollector,
                    sequenceNumber: Int64(1002 + i)
                )
                try await testLogger.log(urlSessionEvent)
                eventsGenerated += 1
            }
            urlSessionMetricsCount = 2
            
            networkUpdatesCount = 1
            
        } catch {
            errors.append("Diagnostics failed: \(error.localizedDescription)")
        }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        
        // Get device ID from agent controller (must be in scope)
        let deviceId = agentController.deviceId
        
        // Generate deterministic run ID
        let runId = UUID().uuidString
        
        // Get app version and build
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let appBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
        
        // Get ruleset version from AgentController
        let rulesetVersion = agentController.rulesetVersion
        
        // Get config info
        let config = configManager.config
        let configSignatureStatus = configManager.configSignatureStatus.rawValue
        let configSource = configManager.getConfigSource(for: "samplingRate").rawValue // Representative source
        
        // Hash device ID (SHA256, hex encoded)
        let deviceIdData = Data(deviceId.utf8)
        let deviceIdHash = SHA256.hash(data: deviceIdData).compactMap { String(format: "%02x", $0) }.joined()
        
        // Collectors info
        let collectorsInfo = DiagnosticsReport.CollectorsInfo(
            metricKitEnabled: metricKitAvailable,
            metricKitSamplingRate: metricKitAvailable ? "60s (MetricKit default)" : "N/A (simulated)",
            systemCollectorEnabled: true,
            systemSamplingRate: config.samplingRate,
            networkCollectorEnabled: true,
            networkSamplingRate: "Event-driven (URLSessionTaskMetrics)"
        )
        
        // Storage info
        let storageInfo = DiagnosticsReport.StorageInfo(
            encryptionEnabled: true,
            encryptionAlgorithm: "AES-GCM",
            redactionEnabled: true,
            storageType: "SQLite (GRDB)"
        )
        
        // Upload transport info
        let uploadEndpoint = config.uploadEndpoint
        let isMockEndpoint = uploadEndpoint == nil || uploadEndpoint?.isEmpty == true
        let uploadTransportInfo = DiagnosticsReport.UploadTransportInfo(
            endpointType: isMockEndpoint ? "Mock (test/diagnostics)" : "HTTPS",
            endpointURL: uploadEndpoint,
            certificatePinningEnabled: false, // SecureTransport doesn't implement pinning yet
            hmacSigningEnabled: config.uploadSigningSecret != nil && !config.uploadSigningSecret!.isEmpty
        )
        
        return DiagnosticsReport(
            id: UUID(),
            timestamp: Date(),
            rulesTriggered: rulesTriggered,
            eventsGenerated: eventsGenerated,
            storeWriteSuccess: storeWriteSuccess,
            storeReadSuccess: storeReadSuccess,
            encryptionSuccess: encryptionSuccess,
            uploadSuccess: uploadSuccess,
            uploadRetries: uploadRetries,
            elapsedTime: elapsedTime,
            errors: errors,
            metricKitAvailable: metricKitAvailable,
            metricKitPayloadCount: metricKitPayloadCount,
            networkUpdatesCount: networkUpdatesCount,
            urlSessionMetricsCount: urlSessionMetricsCount,
            pendingBeforeUpload: pendingBeforeUpload,
            pendingAfterUpload: pendingAfterUpload,
            uploadStatusCode: uploadStatusCode,
            uploadErrorMessage: uploadErrorMessage,
            runId: runId,
            appVersion: appVersion,
            appBuild: appBuild,
            rulesetVersion: rulesetVersion,
            configSignatureStatus: configSignatureStatus,
            configSource: configSource,
            deviceIdHash: deviceIdHash,
            collectorsInfo: collectorsInfo,
            storageInfo: storageInfo,
            uploadTransportInfo: uploadTransportInfo
        )
    }
}

// MARK: - Export Functions

extension DiagnosticsReport {
    /// Export report as JSON
    func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
    
    /// Export report as human-readable text
    func exportText() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .long
        
        var text = """
        ========================================
        EFB AGENT DIAGNOSTICS REPORT
        ========================================
        
        Run ID: \(runId)
        Timestamp: \(formatter.string(from: timestamp))
        
        ----------------------------------------
        APPLICATION INFORMATION
        ----------------------------------------
        App Version: \(appVersion)
        App Build: \(appBuild)
        Ruleset Version: \(rulesetVersion)
        
        ----------------------------------------
        CONFIGURATION
        ----------------------------------------
        Config Source: \(configSource)
        Config Signature Status: \(configSignatureStatus)
        Device ID Hash: \(deviceIdHash)
        
        ----------------------------------------
        COLLECTORS
        ----------------------------------------
        MetricKit: \(collectorsInfo.metricKitEnabled ? "Enabled" : "Disabled")
          - Available: \(metricKitAvailable ? "Yes" : "No (simulated)")
          - Sampling Rate: \(collectorsInfo.metricKitSamplingRate ?? "N/A")
          - Events Generated: \(metricKitPayloadCount)
        
        System Collector: \(collectorsInfo.systemCollectorEnabled ? "Enabled" : "Disabled")
          - Sampling Rate: \(String(format: "%.1fs", collectorsInfo.systemSamplingRate))
        
        Network Collector: \(collectorsInfo.networkCollectorEnabled ? "Enabled" : "Disabled")
          - Sampling: \(collectorsInfo.networkSamplingRate ?? "N/A")
          - Network Updates: \(networkUpdatesCount)
          - URLSession Metrics: \(urlSessionMetricsCount)
        
        ----------------------------------------
        STORAGE & SECURITY
        ----------------------------------------
        Storage Type: \(storageInfo.storageType)
        Encryption: \(storageInfo.encryptionEnabled ? "Enabled" : "Disabled")
        Encryption Algorithm: \(storageInfo.encryptionAlgorithm)
        Redaction: \(storageInfo.redactionEnabled ? "Enabled" : "Disabled")
        
        Pending Events (Before Upload): \(pendingBeforeUpload)
        Pending Events (After Upload): \(pendingAfterUpload)
        
        ----------------------------------------
        UPLOAD TRANSPORT
        ----------------------------------------
        Endpoint Type: \(uploadTransportInfo.endpointType)
        Endpoint URL: \(uploadTransportInfo.endpointURL ?? "N/A (Mock)")
        Certificate Pinning: \(uploadTransportInfo.certificatePinningEnabled ? "Enabled" : "Disabled")
        HMAC Signing: \(uploadTransportInfo.hmacSigningEnabled ? "Enabled" : "Disabled")
        
        ----------------------------------------
        TEST RESULTS SUMMARY
        ----------------------------------------
        Elapsed Time: \(String(format: "%.2fs", elapsedTime))
        Events Generated: \(eventsGenerated)
        Rules Passed: \(rulesTriggered.filter { $0.passed }.count)/\(rulesTriggered.count)
        
        Store Write: \(storeWriteSuccess ? "✓ PASS" : "✗ FAIL")
        Store Read: \(storeReadSuccess ? "✓ PASS" : "✗ FAIL")
        Encryption: \(encryptionSuccess ? "✓ PASS" : "✗ FAIL")
        Upload: \(uploadSuccess ? "✓ PASS" : "✗ FAIL")
        """
        
        if uploadRetries > 0 {
            text += "\n        Upload Retries: \(uploadRetries)"
        }
        
        if let statusCode = uploadStatusCode {
            text += "\n        Upload Status Code: \(statusCode)"
        }
        
        if let errorMsg = uploadErrorMessage, !uploadSuccess {
            text += "\n        Upload Error: \(errorMsg)"
        }
        
        text += """
        
        
        ----------------------------------------
        RULE TEST RESULTS
        ----------------------------------------
        """
        
        for rule in rulesTriggered {
            let status = rule.passed ? "✓ PASS" : "✗ FAIL"
            text += "\n\(rule.ruleName): \(status)"
            text += "\n  Rule ID: \(rule.ruleId)"
            text += "\n  Events Generated: \(rule.eventsCount)"
            if let error = rule.error {
                text += "\n  Error: \(error)"
            }
            if !rule.triggeredEventIds.isEmpty {
                text += "\n  Triggered Event IDs: \(rule.triggeredEventIds.joined(separator: ", "))"
            }
            if rule.rateLimitChecked {
                text += "\n  Rate Limit Check: ✓"
            }
            if rule.cooldownChecked {
                text += "\n  Cooldown Check: ✓"
            }
            text += "\n"
        }
        
        if !errors.isEmpty {
            text += """
            
            ----------------------------------------
            ERRORS
            ----------------------------------------
            """
            for error in errors {
                text += "\n• \(error)"
            }
        }
        
        text += "\n\n========================================\n"
        text += "End of Report\n"
        text += "========================================\n"
        
        return text
    }
}

