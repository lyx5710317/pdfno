// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if DEBUG && os(macOS)
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

private func diagnosticSource() -> AISourceSnapshot {
    .init(bookID: UUID(), readerSessionID: UUID(), documentVersion: 0,
        anchor: .pdf(.init(editionID: UUID(), fileSHA256: String(repeating: "a", count: 64), quote: "window",
            regions: [.init(pageIndex: 0, x: 1, y: 1, width: 20, height: 10, quote: "window")])))
}
@MainActor private func diagnosticIdle(_ busy: () -> Bool) async throws {
    let clock = ContinuousClock(), deadline = clock.now + .seconds(3)
    while busy(), clock.now < deadline { try await Task.sleep(for: .milliseconds(5)) }
    #expect(!busy(), "The wholly intercepted fixture must finish without a GUI or network")
}
private func diagnosticCredential(_ exact: Bool) -> String {
    exact ? "synthetic-reading-ui-credential" : "altered-synthetic-reading-ui-credential"
}

/// Exercise the actual strict UI transport, rather than a more permissive unit-test double.
/// This isolates a credentials failure from changes to the legacy request/response contracts.
struct OfflineUITestTransportTests {
    @Test(arguments: [true, false]) @MainActor
    func legacyDeepSeekTranslationWithExactAndAlteredFixtureCredential(exact: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Transport-Diagnostic-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = AppAISession()
        let model = AILearningModel(root: root, transport: OfflineSelectionUITestTransport(), offlineTransport: true, aiSession: session)
        model.config = DeepSeekSelectionPolicy.configuration()
        #expect(await model.saveConfig(model.config, temporarySecret: diagnosticCredential(exact)))
        model.prepare(diagnosticSource())
        model.start(confirmed: true, sourceIsCurrent: { _ in true })
        try await diagnosticIdle { model.busy }
        if exact {
            #expect(model.error == nil)
            #expect(model.result?.text.contains("离线 DeepSeek UI 替身") == true)
            #expect(model.result?.paragraphExplanation == nil)
        } else {
            #expect(model.error == AIFailure.credentials.localizedDescription)
            #expect(model.result == nil)
        }
        #expect(await session.selection.attemptsUsed() == 1)
        #expect(model.notes.isEmpty, "Neither credential branch may save automatically")
    }

    @Test(arguments: [true, false]) @MainActor
    func legacyBYOKTranslationWithExactAndAlteredFixtureCredential(exact: Bool) async throws {
        let session = AppAISession()
        let model = BYOKSettingsModel(transport: OfflineSelectionUITestTransport(), aiSession: session)
        var config = DeepSeekSelectionPolicy.configuration()
        config.endpoint = "https://joint-ui.example/v1"; config.model = "original-ui-model"
        model.draft = config; model.temporarySecret = diagnosticCredential(exact)
        #expect(await model.apply())
        await model.prepareSelection(diagnosticSource(), kind: .translate)
        model.start(confirmed: true, sourceIsCurrent: { _ in true })
        try await diagnosticIdle { model.busy }
        if exact {
            #expect(model.error == nil)
            #expect(model.result?.text.contains("离线 DeepSeek UI 替身") == true)
            #expect(model.result?.paragraphExplanation == nil)
        } else {
            #expect(model.error == AIFailure.credentials.localizedDescription)
            #expect(model.result == nil)
        }
        #expect(await session.selection.attemptsUsed() == 1)
    }

    @Test(arguments: [true, false]) @MainActor
    func japaneseReviewWithExactAndAlteredFixtureCredential(exact: Bool) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Transport-Diagnostic-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let session = AppAISession()
        let learning = AILearningModel(root: root, transport: OfflineSelectionUITestTransport(), offlineTransport: true, aiSession: session)
        learning.config = DeepSeekSelectionPolicy.configuration()
        #expect(await learning.saveConfig(learning.config, temporarySecret: diagnosticCredential(exact)))
        let model = JapaneseLearningModel(provider: try learning.japaneseLearningProvider(), sourceIsCurrent: { _, _ in true })
        model.prepare(.init(source: diagnosticSource(), provider: learning.config))
        model.start(confirmed: true)
        try await diagnosticIdle { model.busy }
        if exact {
            #expect(model.error == nil && model.review != nil)
        } else {
            #expect(model.error == AIFailure.credentials.localizedDescription)
            #expect(model.review == nil)
        }
        #expect(await session.selection.attemptsUsed() == 1)
        #expect(learning.notes.isEmpty)
    }
}
#endif
