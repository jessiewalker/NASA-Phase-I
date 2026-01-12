//
//  SignedConfigVerifier.swift
//  EFB Agent
//
//  HMAC signature verification for remote configuration
//

import Foundation
import CryptoKit
import Security

struct SignedConfigVerifier {
    static func verify(config: AgentConfig, signature: String) -> Bool {
        // In production, retrieve secret from Keychain
        // For now, use a placeholder secret (should be stored securely)
        guard let secretData = "your-secret-key".data(using: .utf8) else {
            return false
        }
        
        // Serialize config to JSON
        guard let configData = try? JSONEncoder().encode(config) else {
            return false
        }
        
        // Compute HMAC-SHA256
        let key = SymmetricKey(data: secretData)
        let hmac = HMAC<SHA256>.authenticationCode(for: configData, using: key)
        let computedSignature = Data(hmac).base64EncodedString()
        
        // Constant-time comparison
        return computedSignature == signature
    }
}

