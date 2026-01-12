//
//  ConfigManager.swift
//  EFB Agent
//
//  Configuration manager with MDM, local, and remote config support
//

import Foundation
import Combine

enum ConfigSignatureStatus: String, Codable {
    case valid
    case invalid
    case notPresent
    case unknown
}

enum ConfigSource: String, Codable {
    case `default`
    case mdm
    case remoteSigned
}

/// Configuration manager with MDM, local, and remote config support
class ConfigManager: ObservableObject {
    @Published var config: AgentConfig
    @Published var configSignatureStatus: ConfigSignatureStatus = .notPresent
    @Published var lastConfigUpdateTime: Date? = nil
    
    private let bundleConfig: AgentConfig
    private var cancellables = Set<AnyCancellable>()
    private var configSourceMap: [String: ConfigSource] = [:]
    
    init(config: AgentConfig? = nil) {
        // Load default config from bundle
        self.bundleConfig = Self.loadDefaultConfig()
        self.config = config ?? bundleConfig
        
        // Apply MDM overrides if present
        applyMDMConfig()
        
        // Optionally fetch remote config
        if self.config.enableRemoteConfig {
            fetchRemoteConfig()
        }
    }
    
    private static func loadDefaultConfig() -> AgentConfig {
        guard let url = Bundle.main.url(forResource: "default-config", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(AgentConfig.self, from: data) else {
            return AgentConfig.default
        }
        return config
    }
    
    func getConfigSource(for key: String) -> ConfigSource {
        return configSourceMap[key] ?? .default
    }
    
    private func applyMDMConfig() {
        // Check for Managed App Configuration from MDM
        guard let managedConfig = UserDefaults.standard.dictionary(forKey: "com.apple.configuration.managed") else {
            markAllAsDefault()
            return
        }
        
        var updatedConfig = config
        configSourceMap.removeAll()
        
        if let samplingRate = managedConfig["samplingRate"] as? Double {
            updatedConfig.samplingRate = samplingRate
            configSourceMap["samplingRate"] = .mdm
        }
        if let uploadInterval = managedConfig["uploadInterval"] as? TimeInterval {
            updatedConfig.uploadInterval = uploadInterval
            configSourceMap["uploadInterval"] = .mdm
        }
        if let allowedHosts = managedConfig["allowedHosts"] as? [String] {
            updatedConfig.allowedHosts = allowedHosts
            configSourceMap["allowedHosts"] = .mdm
        }
        if let quietMode = managedConfig["quietMode"] as? Bool {
            updatedConfig.quietMode = quietMode
            configSourceMap["quietMode"] = .mdm
        }
        if let debugMode = managedConfig["debugMode"] as? Bool {
            updatedConfig.debugMode = debugMode
            configSourceMap["debugMode"] = .mdm
        }
        if let testMode = managedConfig["testMode"] as? Bool {
            updatedConfig.testMode = testMode
            configSourceMap["testMode"] = .mdm
        }
        
        // Update rule thresholds
        if let cpuThreshold = managedConfig["cpuThreshold"] as? Double {
            updatedConfig.ruleThresholds.cpuThreshold = cpuThreshold
            configSourceMap["cpuThreshold"] = .mdm
        }
        if let memoryThreshold = managedConfig["memoryThreshold"] as? Int64 {
            updatedConfig.ruleThresholds.memoryThreshold = memoryThreshold
            configSourceMap["memoryThreshold"] = .mdm
        }
        
        self.config = updatedConfig
        markUnchangedAsDefault()
    }
    
    private func markAllAsDefault() {
        configSourceMap["samplingRate"] = .default
        configSourceMap["uploadInterval"] = .default
        configSourceMap["allowedHosts"] = .default
        configSourceMap["quietMode"] = .default
        configSourceMap["debugMode"] = .default
        configSourceMap["testMode"] = .default
        configSourceMap["cpuThreshold"] = .default
        configSourceMap["memoryThreshold"] = .default
    }
    
    private func markUnchangedAsDefault() {
        // Any keys not in map are default
    }
    
    private func fetchRemoteConfig() {
        guard let url = URL(string: config.remoteConfigURL ?? "") else { return }
        
        URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: RemoteConfigResponse.self, decoder: JSONDecoder())
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        print("Failed to fetch remote config: \(error)")
                    }
                },
                receiveValue: { [weak self] response in
                    guard let self = self else { return }
                    if let verified = self.verifyAndApplyRemoteConfig(response) {
                        DispatchQueue.main.async {
                            self.config = verified
                        }
                    }
                }
            )
            .store(in: &cancellables)
    }
    
    private func verifyAndApplyRemoteConfig(_ response: RemoteConfigResponse) -> AgentConfig? {
        // Verify signature if present
        if let signature = response.signature {
            guard SignedConfigVerifier.verify(config: response.config, signature: signature) else {
                print("Remote config signature verification failed")
                DispatchQueue.main.async {
                    self.configSignatureStatus = .invalid
                }
                return nil
            }
            DispatchQueue.main.async {
                self.configSignatureStatus = .valid
            }
        } else {
            DispatchQueue.main.async {
                self.configSignatureStatus = .notPresent
            }
        }
        
        // Merge with current config
        var merged = config
        merged.merge(with: response.config)
        lastConfigUpdateTime = Date()
        
        // Mark merged values as remote
        configSourceMap["samplingRate"] = .remoteSigned
        configSourceMap["uploadInterval"] = .remoteSigned
        
        return merged
    }
}

struct AgentConfig: Codable {
    var samplingRate: TimeInterval // seconds between snapshots
    var uploadInterval: TimeInterval // seconds between upload attempts
    var allowedHosts: [String] // hostname allowlist for network rules
    var quietMode: Bool // suppress rule evaluation
    var debugMode: Bool // enable debug logging
    var testMode: Bool // enable test/diagnostics mode
    var enableRemoteConfig: Bool
    var remoteConfigURL: String?
    var maxPendingEvents: Int // backpressure threshold
    var retentionDays: Int
    var ruleThresholds: RuleThresholds
    var uploadEndpoint: String?
    var uploadSigningSecret: String? // Keychain key name
    
    struct RuleThresholds: Codable {
        var cpuThreshold: Double // 0.0-1.0
        var memoryThreshold: Int64 // bytes
        var connectivityFlapThreshold: Int // changes per minute
        var tlsFailureThreshold: Int // count in window
        var tlsFailureWindow: TimeInterval // seconds
    }
    
    static let `default` = AgentConfig(
        samplingRate: 30.0,
        uploadInterval: 300.0,
        allowedHosts: ["example.com"],
        quietMode: false,
        debugMode: false,
        testMode: false,
        enableRemoteConfig: false,
        remoteConfigURL: nil,
        maxPendingEvents: 10000,
        retentionDays: 7,
        ruleThresholds: RuleThresholds(
            cpuThreshold: 0.8,
            memoryThreshold: 1_000_000_000, // 1GB
            connectivityFlapThreshold: 5,
            tlsFailureThreshold: 3,
            tlsFailureWindow: 60.0
        ),
        uploadEndpoint: nil,
        uploadSigningSecret: nil
    )
    
    mutating func merge(with other: AgentConfig) {
        // Merge non-default values
        if other.samplingRate > 0 { samplingRate = other.samplingRate }
        if other.uploadInterval > 0 { uploadInterval = other.uploadInterval }
        if !other.allowedHosts.isEmpty { allowedHosts = other.allowedHosts }
        quietMode = other.quietMode
        debugMode = other.debugMode
        testMode = other.testMode
        if let url = other.remoteConfigURL { remoteConfigURL = url }
        if other.maxPendingEvents > 0 { maxPendingEvents = other.maxPendingEvents }
        if other.retentionDays > 0 { retentionDays = other.retentionDays }
    }
}

struct RemoteConfigResponse: Codable {
    let config: AgentConfig
    let signature: String? // Base64 encoded signature
}

