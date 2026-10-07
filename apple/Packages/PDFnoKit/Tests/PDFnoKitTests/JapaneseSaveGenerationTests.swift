// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoUI

private actor JapaneseSavePayload: JapaneseLearningProvider {
    nonisolated let mode = AIProviderMode.mock
    func attemptsUsed() -> Int { 0 }
    func analyze(_ request: JapaneseLearningRequest) throws -> Data {
        try japaneseData(japanesePayload(request.source.anchor.quote, readings: [japaneseReading()], grammar: [japaneseGrammar()]))
    }
}
@MainActor private final class JapaneseSaveGate {
    var notes: [JapaneseLearningNote] = []
    var pending: CheckedContinuation<Void, Error>?
    func save(_ note: JapaneseLearningNote) async throws {
        notes.append(note)
        try await withCheckedThrowingContinuation { pending = $0 }
    }
    func finish(_ outcome: String) {
        let continuation = pending; pending = nil
        if outcome == "success" { continuation?.resume() }
        else if outcome == "cancelled" { continuation?.resume(throwing: CancellationError()) }
        else { continuation?.resume(throwing: AIFailure.store) }
    }
}
@MainActor private func saveReview(_ model: JapaneseLearningModel, request: JapaneseLearningRequest) async throws {
    model.prepare(request); model.start(confirmed: true)
    let deadline = Date().addingTimeInterval(3)
    while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
    try #require(model.review != nil && !model.busy && model.canSave)
}
@MainActor private func pendingJapaneseSave(_ gate: JapaneseSaveGate) async throws {
    let deadline = Date().addingTimeInterval(3)
    while gate.pending == nil && Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
    try #require(gate.pending != nil)
}

@MainActor
struct JapaneseSaveGenerationTests {
    @Test(arguments: ["success", "failure", "cancelled"])
    func lateCompletionDoesNotPublishIntoTheNewSourcesDraftOrError(outcome: String) async throws {
        let gate = JapaneseSaveGate()
        let model = JapaneseLearningModel(provider: JapaneseSavePayload(), sourceIsCurrent: { _, _ in true }, saveReviewedNote: gate.save)
        let a = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        try await saveReview(model, request: a)
        model.userText = "Original A captured"
        let pending = Task { await model.save() }; try await pendingJapaneseSave(gate)
        #expect(model.saving && !model.canStart && !model.canSave)
        #expect(await model.save() == false && gate.notes.count == 1)
        let b = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        model.prepare(b); model.userText = "Original B 日本語 cafe\u{301}"; model.readingCorrections = ["B-only": "ネコ"]
        let scope = model.confirmationScope, revision = model.confirmationRevision, status = model.status
        if outcome == "cancelled" { pending.cancel() }
        gate.finish(outcome)
        #expect(await pending.value == (outcome == "success"))
        #expect(model.request?.source == b.source && model.request?.provider == b.provider)
        #expect(model.confirmationScope == scope && model.confirmationRevision == revision && model.status == status)
        #expect(model.userText.utf8.elementsEqual("Original B 日本語 cafe\u{301}".utf8) && model.readingCorrections == ["B-only": "ネコ"])
        #expect(model.error == nil)
        #expect(model.error == nil && model.review == nil && !model.saved && !model.busy && !model.saving && model.canStart)
        #expect(gate.notes.count == 1 && gate.notes[0].review.source == a.source && gate.notes[0].userText == "Original A captured")
        model.start(confirmed: true)
        let deadline = Date().addingTimeInterval(3)
        while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(model.review?.source == b.source && model.canSave)
    }

    @Test(arguments: ["close", "configuration"])
    func lateFailureAfterCloseOrConfigurationChangeKeepsThePreparedState(event: String) async throws {
        let gate = JapaneseSaveGate()
        let model = JapaneseLearningModel(provider: JapaneseSavePayload(), sourceIsCurrent: { _, _ in true }, saveReviewedNote: gate.save)
        let a = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        try await saveReview(model, request: a)
        let pending = Task { await model.save() }; try await pendingJapaneseSave(gate)
        if event == "close" { model.prepare(nil) }
        else {
            var config = a.provider; config.generation += 1
            model.prepare(JapaneseLearningRequest(source: a.source, provider: config), provider: JapaneseSavePayload())
        }
        model.userText = "Original replacement draft"
        let expectedSource = model.request?.source, expectedProvider = model.request?.provider
        let scope = model.confirmationScope, revision = model.confirmationRevision, status = model.status
        gate.finish("failure")
        #expect(await pending.value == false)
        #expect(model.request?.source == expectedSource && model.request?.provider == expectedProvider)
        #expect(model.confirmationScope == scope && model.confirmationRevision == revision && model.status == status)
        #expect(model.error == nil)
        #expect(model.error == nil && model.userText == "Original replacement draft" && !model.saving && !model.saved)
        let next = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        try await saveReview(model, request: next)
        #expect(model.canSave && model.review?.source == next.source)
    }

    @Test func currentSourceFailureStillReportsAndSingleFlightAllowsAnExplicitSaveRetry() async throws {
        let gate = JapaneseSaveGate()
        let model = JapaneseLearningModel(provider: JapaneseSavePayload(), sourceIsCurrent: { _, _ in true }, saveReviewedNote: gate.save)
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        try await saveReview(model, request: request)
        model.userText = "Original current draft"
        let first = Task { await model.save() }; try await pendingJapaneseSave(gate)
        #expect(await model.save() == false && gate.notes.count == 1)
        gate.finish("failure")
        #expect(await first.value == false && model.error == AIFailure.store.localizedDescription)
        #expect(model.userText == "Original current draft" && !model.saving && model.canSave && !model.saved)
        let retry = Task { await model.save() }; try await pendingJapaneseSave(gate)
        #expect(gate.notes.count == 2 && gate.notes[0].id == gate.notes[1].id)
        #expect(gate.notes.allSatisfy { $0.review.source == request.source && $0.userText == "Original current draft" })
        gate.finish("success")
        #expect(await retry.value && model.saved && !model.saving && model.error == nil && !model.canSave)
    }
}
