//
//  Uploader.swift
//  EFB Agent
//
//  Periodic batch uploader with exponential backoff and backpressure
//

import Foundation
import Combine

actor Uploader {
    private let store: EventStoring
    private let uploadClient: Uploading
    private let config: AgentConfig
    private var uploadTask: Task<Void, Never>?
    private var backoffDelay: TimeInterval = 1.0
    private let maxBackoff: TimeInterval = 300.0
    private let jitterRange: TimeInterval = 5.0
    
    init(store: EventStoring, uploadClient: Uploading, config: AgentConfig) {
        self.store = store
        self.uploadClient = uploadClient
        self.config = config
    }
    
    func start() {
        guard uploadTask == nil else { return }
        
        uploadTask = Task {
            while !Task.isCancelled {
                do {
                    try await performUpload()
                    backoffDelay = 1.0 // Reset on success
                    try await Task.sleep(nanoseconds: UInt64(config.uploadInterval * 1_000_000_000))
                } catch {
                    // Exponential backoff with jitter
                    let jitter = TimeInterval.random(in: 0...jitterRange)
                    let delay = min(backoffDelay + jitter, maxBackoff)
                    backoffDelay *= 2.0
                    
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
    }
    
    func stop() {
        uploadTask?.cancel()
        uploadTask = nil
    }
    
    func uploadNow() async throws {
        try await performUpload()
    }
    
    private func performUpload() async throws {
        // Check backpressure
        let pendingCount = try await store.countPending()
        if pendingCount > config.maxPendingEvents {
            throw UploadError.backpressureExceeded(pendingCount)
        }
        
        // Fetch batch
        let batch = try await store.fetchBatch(limit: 100)
        guard !batch.isEmpty else {
            return // Nothing to upload
        }
        
        // Upload
        let uploadedIds = try await uploadClient.upload(batch)
        
        // Mark as uploaded
        try await store.markUploaded(ids: uploadedIds)
    }
    
    enum UploadError: Error {
        case backpressureExceeded(Int)
    }
}

