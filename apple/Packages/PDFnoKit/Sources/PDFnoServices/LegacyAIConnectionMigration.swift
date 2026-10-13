// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public struct LegacyAIConnectionSnapshot: Sendable, Equatable {
    public let configuration: AIProviderConfig
    public let hasSessionCredential: Bool
}
/// A migration-only capsule for a pre-existing in-memory configuration.
/// It has no editable settings, provider factory, request API, disk or Keychain access.
public actor LegacyAIConnectionSession {
    private let configuration: AIProviderConfig
    private var secret: String?
    public init(configuration: AIProviderConfig, temporarySecret: String) throws {
        _ = try ConfiguredAPISelectionPolicy.finalURL(configuration)
        guard temporarySecret.isEmpty || CredentialValidation.valid(temporarySecret) else { throw AIFailure.credentials }
        self.configuration = configuration; secret = temporarySecret.isEmpty ? nil : temporarySecret
    }
    public func snapshot() -> LegacyAIConnectionSnapshot {
        .init(configuration: configuration, hasSessionCredential: secret != nil)
    }
    public func clearCredential() { secret = nil }
    /// Called only after migration/conflict choice; never exposes the value to UI or disk.
    public func transferCredential(to store: any AICredentialStore, reference: UUID,
                                   expected: AIProviderConfig) async throws {
        guard ReadingSkillIdentity.matches(configuration, expected), let secret, CredentialValidation.valid(secret) else { throw AIFailure.stale }
        try await store.put(secret, reference: reference)
    }
}
