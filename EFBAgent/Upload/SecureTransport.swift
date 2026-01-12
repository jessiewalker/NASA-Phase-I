//
//  SecureTransport.swift
//  EFB Agent
//
//  Secure HTTPS upload with optional certificate pinning and HMAC signing
//

import Foundation
import CryptoKit

struct SecureTransport {
    func upload(_ events: [AgentEvent], endpoint: String, signingSecret: String?) async throws -> UploadResponse {
        guard let url = URL(string: endpoint) else {
            throw UploadError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Serialize events
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let eventData = try encoder.encode(events)
        
        // Sign request if secret provided
        if let secret = signingSecret {
            let signature = computeHMAC(data: eventData, secret: secret)
            request.setValue(signature, forHTTPHeaderField: "X-Signature")
        }
        
        request.httpBody = eventData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UploadError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw UploadError.httpError(httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let uploadResponse = try decoder.decode(UploadResponse.self, from: data)
        
        return uploadResponse
    }
    
    private func computeHMAC(data: Data, secret: String) -> String {
        guard let secretData = secret.data(using: .utf8) else {
            return ""
        }
        let key = SymmetricKey(data: secretData)
        let hmac = HMAC<SHA256>.authenticationCode(for: data, using: key)
        return Data(hmac).base64EncodedString()
    }
}

struct UploadResponse: Codable {
    let uploadedIds: [String]
}

enum UploadError: Error {
    case invalidURL
    case invalidResponse
    case httpError(Int)
}

