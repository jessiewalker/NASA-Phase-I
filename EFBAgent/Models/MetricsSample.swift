//
//  MetricsSample.swift
//  EFB Agent
//
//  Time-series metric sample for real-time monitoring
//

import Foundation

struct MetricsSample: Identifiable, Codable, Sendable {
    let id: UUID
    let timestamp: Date
    let cpuPercent: Double
    let memoryMB: Double
    let netTxKBps: Double?
    let netRxKBps: Double?
    
    init(
        timestamp: Date = Date(),
        cpuPercent: Double,
        memoryMB: Double,
        netTxKBps: Double? = nil,
        netRxKBps: Double? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.cpuPercent = cpuPercent
        self.memoryMB = memoryMB
        self.netTxKBps = netTxKBps
        self.netRxKBps = netRxKBps
    }
}

// Ring buffer for efficient storage of last N samples
actor MetricsRingBuffer {
    private var samples: [MetricsSample]
    private let capacity: Int
    private var writeIndex: Int = 0
    private var isFull: Bool = false
    
    init(capacity: Int = 60) {
        self.capacity = capacity
        self.samples = []
        self.samples.reserveCapacity(capacity)
    }
    
    func append(_ sample: MetricsSample) {
        if isFull {
            samples[writeIndex] = sample
            writeIndex = (writeIndex + 1) % capacity
        } else {
            samples.append(sample)
            if samples.count >= capacity {
                isFull = true
            }
        }
    }
    
    func getAll() -> [MetricsSample] {
        if isFull {
            // Return samples in chronological order
            let beforeWrap = Array(samples[writeIndex..<capacity])
            let afterWrap = Array(samples[0..<writeIndex])
            return afterWrap + beforeWrap
        } else {
            return samples
        }
    }
    
    func getLatest() -> MetricsSample? {
        if isFull {
            return samples[(writeIndex + capacity - 1) % capacity]
        } else {
            return samples.last
        }
    }
    
    func reset() {
        samples.removeAll(keepingCapacity: true)
        writeIndex = 0
        isFull = false
    }
    
    func count() -> Int {
        return samples.count
    }
}

