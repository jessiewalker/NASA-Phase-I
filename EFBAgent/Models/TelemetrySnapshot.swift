//
//  TelemetrySnapshot.swift
//  EFB Agent
//
//  Point-in-time telemetry data collection
//

import Foundation

struct TelemetrySnapshot: Codable, Sendable {
    let timestamp: Date
    let cpuLoad: Double // 0.0-1.0
    let memoryUsed: Int64 // bytes
    let memoryAvailable: Int64? // bytes
    let thermalState: ThermalState
    let batteryState: BatteryState
    let connectivity: ConnectivitySummary
    let networkMetrics: NetworkMetricsSummary?
    
    struct ConnectivitySummary: Codable, Sendable {
        let isConnected: Bool
        let isExpensive: Bool
        let isConstrained: Bool
        let interfaceType: String? // WiFi, Cellular, etc.
        let dnsServers: [String]
        let lastChangeTime: Date?
    }
    
    struct NetworkMetricsSummary: Codable, Sendable {
        let totalRequests: Int
        let successCount: Int
        let failureCount: Int
        let avgResponseTime: Double // seconds
        let tlsFailureCount: Int
        let recentDestinations: [String] // hostnames
    }
}

enum ThermalState: String, Codable, Sendable {
    case nominal
    case fair
    case serious
    case critical
}

enum BatteryState: String, Codable, Sendable {
    case unplugged
    case charging
    case full
    case unknown
}

