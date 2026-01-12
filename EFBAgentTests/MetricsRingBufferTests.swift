//
//  MetricsRingBufferTests.swift
//  EFBAgentTests
//
//  Unit tests for MetricsRingBuffer
//

import XCTest
@testable import EFBAgent

@MainActor
final class MetricsRingBufferTests: XCTestCase {
    
    func testRingBufferCapacity() async {
        let buffer = MetricsRingBuffer(capacity: 60)
        
        // Add exactly 60 samples
        for i in 0..<60 {
            let sample = MetricsSample(
                timestamp: Date().addingTimeInterval(Double(i)),
                cpuPercent: Double(i),
                memoryMB: Double(i * 10)
            )
            await buffer.append(sample)
        }
        
        let all = await buffer.getAll()
        XCTAssertEqual(all.count, 60, "Should have exactly 60 samples")
    }
    
    func testRingBufferOverflow() async {
        let buffer = MetricsRingBuffer(capacity: 5)
        
        // Add 10 samples (should wrap and keep only last 5)
        for i in 0..<10 {
            let sample = MetricsSample(
                timestamp: Date().addingTimeInterval(Double(i)),
                cpuPercent: Double(i),
                memoryMB: Double(i * 10)
            )
            await buffer.append(sample)
        }
        
        let all = await buffer.getAll()
        XCTAssertEqual(all.count, 5, "Should wrap and keep only 5 samples when capacity is exceeded")
        
        // Verify we have the last 5 (samples 5-9)
        let cpuValues = all.map { $0.cpuPercent }
        XCTAssertEqual(Set(cpuValues), Set([5.0, 6.0, 7.0, 8.0, 9.0]), "Should contain the last 5 samples")
    }
    
    func testRingBufferChronologicalOrder() async {
        let buffer = MetricsRingBuffer(capacity: 5)
        
        // Add samples with known timestamps
        let baseDate = Date()
        for i in 0..<7 {
            let sample = MetricsSample(
                timestamp: baseDate.addingTimeInterval(Double(i)),
                cpuPercent: Double(i),
                memoryMB: Double(i * 10)
            )
            await buffer.append(sample)
        }
        
        let all = await buffer.getAll()
        XCTAssertEqual(all.count, 5, "Should have 5 samples after wrapping")
        
        // Verify chronological order (oldest first)
        for i in 0..<all.count - 1 {
            XCTAssertLessThan(all[i].timestamp, all[i + 1].timestamp, "Samples should be in chronological order")
        }
        
        // Verify we have samples 2-6 (oldest 5 of the 7 added)
        let cpuValues = all.map { $0.cpuPercent }
        XCTAssertEqual(cpuValues, [2.0, 3.0, 4.0, 5.0, 6.0], "Should have the oldest 5 samples in order")
    }
    
    func testRingBufferGetLatest() async {
        let buffer = MetricsRingBuffer(capacity: 10)
        
        // Add some samples
        for i in 0..<5 {
            let sample = MetricsSample(
                timestamp: Date().addingTimeInterval(Double(i)),
                cpuPercent: Double(i),
                memoryMB: Double(i * 10)
            )
            await buffer.append(sample)
        }
        
        let latest = await buffer.getLatest()
        XCTAssertNotNil(latest, "Should return latest sample")
        XCTAssertEqual(latest?.cpuPercent, 4.0, "Latest should be the last appended sample")
    }
    
    func testRingBufferReset() async {
        let buffer = MetricsRingBuffer(capacity: 10)
        
        // Add samples
        for i in 0..<5 {
            let sample = MetricsSample(
                timestamp: Date().addingTimeInterval(Double(i)),
                cpuPercent: Double(i),
                memoryMB: Double(i * 10)
            )
            await buffer.append(sample)
        }
        
        XCTAssertEqual(await buffer.count(), 5, "Should have 5 samples")
        
        // Reset
        await buffer.reset()
        
        XCTAssertEqual(await buffer.count(), 0, "Should be empty after reset")
        XCTAssertNil(await buffer.getLatest(), "Latest should be nil after reset")
        
        let all = await buffer.getAll()
        XCTAssertTrue(all.isEmpty, "Should return empty array after reset")
    }
    
    func testRingBufferPauseBehavior() async {
        // This test verifies that pause doesn't affect the buffer itself
        // (pause is handled at the AgentController level)
        let buffer = MetricsRingBuffer(capacity: 60)
        
        // Add samples
        for i in 0..<10 {
            let sample = MetricsSample(
                timestamp: Date().addingTimeInterval(Double(i)),
                cpuPercent: Double(i),
                memoryMB: Double(i * 10)
            )
            await buffer.append(sample)
        }
        
        let countBefore = await buffer.count()
        
        // Simulate pause - buffer still accepts samples, but AgentController won't call append
        // So we test that buffer itself works regardless
        for i in 10..<20 {
            let sample = MetricsSample(
                timestamp: Date().addingTimeInterval(Double(i)),
                cpuPercent: Double(i),
                memoryMB: Double(i * 10)
            )
            await buffer.append(sample)
        }
        
        let countAfter = await buffer.count()
        XCTAssertGreaterThan(countAfter, countBefore, "Buffer should continue accepting samples")
    }
}

