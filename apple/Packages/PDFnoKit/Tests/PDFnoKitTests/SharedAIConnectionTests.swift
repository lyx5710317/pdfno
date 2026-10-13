// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFKit
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

private actor SharedConnectionNoNetwork: AIHTTPTransport {
    var calls = 0
    func send(_ request: URLRequest) throws -> AIHTTPResponse { calls += 1; throw AIFailure.network }
}
@Suite(.serialized) @MainActor struct SharedAIConnectionTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Shared-Connection-" + UUID().uuidString) }
    private func configuration(_ endpoint: String = "https://original-shared.invalid/v1") -> AIProviderConfig {
        var c = DeepSeekSelectionPolicy.configuration(); c.endpoint = endpoint; c.model = "original-shared-model"; return c
    }

    @Test func tabsToolsAndLegacyTextActionsUseOneAppliedConnectionAndClearTogether() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let transport = SharedConnectionNoNetwork(), catalogue = LibraryModel(root: r, aiSession: AppAISession(), learningTransport: transport)
        let tabs = MacDocumentTabs(catalogue: catalogue, documentFactory: { LibraryModel(root: $0, aiSession: AppAISession(), learningTransport: transport) })
        let a = tabs.makeDocumentModel(), b = tabs.makeDocumentModel()
        #expect(await catalogue.learning.applyConnection(configuration(), temporarySecret: "original-shared-synthetic-key"))
        #expect(a.learning.config == catalogue.learning.config && b.learning.config == catalogue.learning.config)
        #expect(a.learning.hasSessionCredential && b.learning.hasSessionCredential)
        #expect(a.learning.connectionSettingsOwner === catalogue.learning && b.learning.connectionSettingsOwner === catalogue.learning)
        _ = try a.learning.configuredSelectionProvider(); _ = try b.learning.conversationProvider()
        await b.learning.clearSessionCredential()
        #expect(!catalogue.learning.hasSessionCredential && !a.learning.hasSessionCredential && !b.learning.hasSessionCredential)
        #expect(!a.learning.conversationConnectionAvailable && !b.learning.conversationConnectionAvailable)
        #expect(await transport.calls == 0)
        #expect(!String(decoding: try JSONEncoder().encode(await catalogue.learning.repository.load()), as: UTF8.self).contains("original-shared-synthetic-key"))
    }

    @Test func invalidRecipientRevokesEveryBoundTabWithoutReplacingSavedConfigurationOrSending() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let transport = SharedConnectionNoNetwork(), owner = AILearningModel(root: r, transport: transport, aiSession: AppAISession())
        let child = AILearningModel(root: r, transport: transport, aiSession: AppAISession()); child.shareSessionConfiguration(with: owner)
        #expect(await owner.applyConnection(configuration(), temporarySecret: "original-shared-synthetic-key"))
        let applied = owner.config, disk = try Data(contentsOf: r.appendingPathComponent("learning-v1.json"))
        var invalid = applied; invalid.endpoint = "https://different.invalid/?key=never-allowed"
        #expect(await child.applyConnection(invalid, temporarySecret: "") == false)
        #expect(owner.config == applied && child.config == applied)
        #expect(!owner.hasSessionCredential && !child.hasSessionCredential && !child.conversationConnectionAvailable)
        #expect(try Data(contentsOf: r.appendingPathComponent("learning-v1.json")) == disk)
        #expect(await transport.calls == 0)
    }

    @Test func equivalentLegacyMemoryMigratesOnceIntoSharedOwnerWithoutPersistingCredential() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let transport = SharedConnectionNoNetwork(), owner = AILearningModel(root: r, transport: transport, aiSession: AppAISession())
        #expect(await owner.saveConfig(configuration(), temporarySecret: ""))
        let prior = owner.config, legacy = try LegacyAIConnectionSession(configuration: prior, temporarySecret: "original-legacy-migration-only-key")
        await owner.reconcileLegacyConnection(legacy)
        #expect(owner.hasSessionCredential && owner.legacyConnectionConfiguration == nil)
        #expect(owner.config.endpoint == prior.endpoint && owner.config.model == prior.model)
        #expect(!(await legacy.snapshot()).hasSessionCredential)
        let current = owner.config; await owner.reconcileLegacyConnection(legacy)
        #expect(owner.config == current && owner.hasSessionCredential)
        #expect(await transport.calls == 0)
        let disk = try Data(contentsOf: r.appendingPathComponent("learning-v1.json"))
        #expect(!String(decoding: disk, as: UTF8.self).contains("original-legacy-migration-only-key"))
    }

    @Test func legacyConflictCannotOverwriteCurrentConnectionUntilExplicitChoice() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let transport = SharedConnectionNoNetwork(), owner = AILearningModel(root: r, transport: transport, aiSession: AppAISession())
        #expect(await owner.applyConnection(configuration(), temporarySecret: "original-current-key"))
        let applied = owner.config, legacy = try LegacyAIConnectionSession(configuration: configuration("https://original-legacy.invalid/v1"), temporarySecret: "original-legacy-key")
        await owner.reconcileLegacyConnection(legacy)
        #expect(owner.config == applied && owner.hasSessionCredential && !owner.conversationConnectionAvailable)
        #expect(owner.legacyConnectionConfiguration?.endpoint == "https://original-legacy.invalid/v1")
        #expect(await owner.applyConnection(configuration("https://third.invalid/v1"), temporarySecret: "original-third-key") == false)
        #expect(owner.config == applied && owner.hasSessionCredential)
        await owner.chooseLegacyConnection(useLegacy: true)
        #expect(owner.config.endpoint == "https://original-legacy.invalid/v1" && owner.hasSessionCredential)
        let migrated = await legacy.snapshot()
        #expect(owner.legacyConnectionConfiguration == nil && !migrated.hasSessionCredential)
        #expect(await transport.calls == 0)
    }

    @Test func keepingCurrentConnectionDoesNotImportOrReplaceLegacyCredential() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let transport = SharedConnectionNoNetwork(), owner = AILearningModel(root: r, transport: transport, aiSession: AppAISession())
        #expect(await owner.applyConnection(configuration(), temporarySecret: "original-current-key"))
        let applied = owner.config, legacy = try LegacyAIConnectionSession(configuration: configuration("https://original-legacy.invalid/v1"), temporarySecret: "original-legacy-key")
        await owner.reconcileLegacyConnection(legacy); await owner.chooseLegacyConnection(useLegacy: false)
        #expect(owner.config == applied && owner.hasSessionCredential && owner.conversationConnectionAvailable)
        let retained = await legacy.snapshot()
        #expect(owner.legacyConnectionConfiguration == nil && retained.hasSessionCredential)
        #expect(await transport.calls == 0)
    }
}
#endif
