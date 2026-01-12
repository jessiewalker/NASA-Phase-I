//
//  Redactor.swift
//  EFB Agent
//
//  Sensitive data redaction from event attributes
//

import Foundation

struct Redactor {
    private static let allowedKeys: Set<String> = [
        "cpuLoad", "memoryUsed", "threshold", "duration", "interface",
        "expensive", "constrained", "destination", "hitCount", "allowedHosts",
        "failureCount", "window", "changesPerMinute", "simulated", "responseTime",
        "requestCount"
    ]
    
    private static let forbiddenPatterns: [String] = [
        "password", "token", "secret", "key", "auth", "credential"
    ]
    
    static func redact(_ attributes: [String: CodableValue]) -> [String: CodableValue] {
        var redacted: [String: CodableValue] = [:]
        
        for (key, value) in attributes {
            // Check if key is explicitly allowed
            if allowedKeys.contains(key) {
                redacted[key] = value
                continue
            }
            
            // Check if key contains forbidden patterns
            let lowerKey = key.lowercased()
            if forbiddenPatterns.contains(where: { lowerKey.contains($0) }) {
                continue // Skip this key
            }
            
            // Allow the key
            redacted[key] = value
        }
        
        return redacted
    }
}

