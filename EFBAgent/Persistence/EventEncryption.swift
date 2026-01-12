//
//  EventEncryption.swift
//  EFB Agent
//
//  AES-GCM encryption for event data at rest
//

import Foundation
import CryptoKit
import Security

actor EventEncryption {
    private var key: SymmetricKey?
    
    init() {
        loadOrGenerateKey()
    }
    
    private func loadOrGenerateKey() {
        let keychainKey = "com.efbagent.encryption.key"
        
        // Try to load from Keychain
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecReturnData as String: true
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecSuccess,
           let keyData = result as? Data {
            key = SymmetricKey(data: keyData)
            return
        }
        
        // Generate new key
        let newKey = SymmetricKey(size: .bits256)
        
        // Store in Keychain
        query = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: keychainKey,
            kSecValueData as String: newKey.withUnsafeBytes { Data($0) }
        ]
        
        SecItemAdd(query as CFDictionary, nil)
        key = newKey
    }
    
    func encrypt(_ data: Data) throws -> Data {
        guard let key = key else {
            throw EncryptionError.noKey
        }
        
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.encryptionFailed
        }
        
        return combined
    }
    
    func decrypt(_ data: Data) throws -> Data {
        guard let key = key else {
            throw EncryptionError.noKey
        }
        
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        let decrypted = try AES.GCM.open(sealedBox, using: key)
        
        return decrypted
    }
    
    enum EncryptionError: Error {
        case noKey
        case encryptionFailed
        case decryptionFailed
    }
}

