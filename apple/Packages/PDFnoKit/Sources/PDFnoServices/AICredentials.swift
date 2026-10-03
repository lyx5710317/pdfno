// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Security
import LocalAuthentication
import PDFnoDomain

public protocol AICredentialStore: Sendable {
    func read(_ reference: UUID) async throws -> String?
    func put(_ value: String, reference: UUID) async throws
    func remove(_ reference: UUID) async throws
}
public enum CredentialValidation {
    public static func valid(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 4096 && !value.unicodeScalars.contains { $0.value <= 32 || $0.value == 127 }
    }
}
public actor SessionCredentialStore: AICredentialStore {
    private var values: [UUID: String] = [:]
    public init() {}
    public func read(_ reference: UUID) -> String? { values[reference] }
    public func put(_ value: String, reference: UUID) throws {
        guard CredentialValidation.valid(value) else { throw AIFailure.credentials }; values[reference] = value
    }
    public func remove(_ reference: UUID) { values.removeValue(forKey: reference) }
}
/// Exact-item operations only. The UI does not activate persistent credentials in this slice.
public protocol ExactKeychainClient: Sendable {
    func read(service: String, account: String) throws -> Data?
    func put(_ bytes: Data, service: String, account: String) throws
    func remove(service: String, account: String) throws
}
public struct SecurityKeychainClient: ExactKeychainClient {
    public init() {}
    public static func query(service: String, account: String) -> [String: Any] {
        let context = LAContext(); context.interactionNotAllowed = true
        return [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false,
         kSecUseAuthenticationContext as String: context]
    }
    public func read(service: String, account: String) throws -> Data? {
        var query = Self.query(service: service, account: account)
        query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else { throw AIFailure.credentials }; return data
    }
    public func put(_ bytes: Data, service: String, account: String) throws {
        let query = Self.query(service: service, account: account)
        let attributes = [kSecValueData as String: bytes, kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly] as [String: Any]
        var inserted = query; inserted.merge(attributes) { _, new in new }
        let status = SecItemAdd(inserted as CFDictionary, nil)
        if status == errSecDuplicateItem {
            guard SecItemUpdate(query as CFDictionary, attributes as CFDictionary) == errSecSuccess else { throw AIFailure.credentials }
        } else if status != errSecSuccess { throw AIFailure.credentials }
    }
    public func remove(service: String, account: String) throws {
        let status = SecItemDelete(Self.query(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw AIFailure.credentials }
    }
}
public actor KeychainCredentialStore: AICredentialStore {
    public static let service = "org.pdfno.byok.v1"
    private let client: any ExactKeychainClient
    public init(client: any ExactKeychainClient = SecurityKeychainClient()) { self.client = client }
    public func read(_ reference: UUID) throws -> String? {
        guard let data = try client.read(service: Self.service, account: reference.uuidString) else { return nil }
        guard let value = String(data: data, encoding: .utf8), CredentialValidation.valid(value) else { throw AIFailure.credentials }; return value
    }
    public func put(_ value: String, reference: UUID) throws {
        guard CredentialValidation.valid(value) else { throw AIFailure.credentials }
        try client.put(Data(value.utf8), service: Self.service, account: reference.uuidString)
    }
    public func remove(_ reference: UUID) throws { try client.remove(service: Self.service, account: reference.uuidString) }
}
