//
//  SystemCollector.swift
//  EFB Agent
//
//  System metrics collection (CPU, memory, thermal, battery)
//

import Foundation
import Combine
import UIKit

class SystemCollector {
    private let deviceId: String
    private let config: AgentConfig
    private var snapshotTimer: AnyCancellable?
    
    init(deviceId: String, config: AgentConfig) {
        self.deviceId = deviceId
        self.config = config
    }
    
    func start() {
        // Periodic snapshot collection handled by AgentController
        // This collector provides methods to gather current system state
    }
    
    func stop() {
        snapshotTimer?.cancel()
        snapshotTimer = nil
    }
    
    func collectTelemetrySnapshot() -> TelemetrySnapshot {
        let processInfo = ProcessInfo.processInfo
        
        // Get memory usage (approximate)
        // NOTE: iOS doesn't provide direct access to process memory usage.
        // This is an ESTIMATE using physical memory as a proxy.
        // For real memory monitoring, consider using task_info/resident_size (requires entitlements).
        let memoryUsed = Int64(processInfo.physicalMemory) // Total physical memory (ESTIMATED)
        
        // CPU load (ESTIMATED - iOS doesn't provide direct CPU usage)
        // This is a placeholder. For real CPU monitoring, consider using thread CPU time deltas.
        let cpuLoad = 0.3 // ESTIMATED placeholder
        
        // Thermal state
        let thermalState: ThermalState
        switch processInfo.thermalState {
        case .nominal: thermalState = .nominal
        case .fair: thermalState = .fair
        case .serious: thermalState = .serious
        case .critical: thermalState = .critical
        @unknown default: thermalState = .nominal
        }
        
        // Battery state
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryState: BatteryState
        switch UIDevice.current.batteryState {
        case .unplugged: batteryState = .unplugged
        case .charging: batteryState = .charging
        case .full: batteryState = .full
        default: batteryState = .unknown
        }
        
        return TelemetrySnapshot(
            timestamp: Date(),
            cpuLoad: cpuLoad,
            memoryUsed: memoryUsed,
            memoryAvailable: nil,
            thermalState: thermalState,
            batteryState: batteryState,
            connectivity: TelemetrySnapshot.ConnectivitySummary(
                isConnected: true,
                isExpensive: false,
                isConstrained: false,
                interfaceType: nil,
                dnsServers: [],
                lastChangeTime: nil
            ),
            networkMetrics: nil
        )
    }
}

