//
//  MockUploadEndpoint.swift
//  EFB Agent
//
//  Mock upload endpoint for testing
//

import Foundation

final class MockUploadEndpoint: Uploading {
    private let queue = DispatchQueue(label: "com.efbagent.mockupload")
    private var shouldFail: Bool = false
    private var failureRate: Double = 0.0 // 0.0 to 1.0
    private var uploadedIds: [UUID] = []
    
    init(shouldFail: Bool = false, failureRate: Double = 0.0) {
        self.shouldFail = shouldFail
        self.failureRate = failureRate
    }
    
    func upload(_ events: [AgentEvent]) async throws -> [UUID] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        return try await withCheckedThrowingContinuation { continuation in
            queue.async {
                // Simulate failures based on rate
                if self.shouldFail || Double.random(in: 0...1) < self.failureRate {
                    continuation.resume(throwing: MockUploadError.simulatedFailure)
                    return
                }
                
                let ids = events.map { $0.eventId }
                self.uploadedIds.append(contentsOf: ids)
                continuation.resume(returning: ids)
            }
        }
    }
    
    func getUploadedIds() -> [UUID] {
        return queue.sync {
            return uploadedIds
        }
    }
    
    func reset() {
        queue.sync {
            uploadedIds.removeAll()
            shouldFail = false
            failureRate = 0.0
        }
    }
    
    enum MockUploadError: Error {
        case simulatedFailure
    }
}

