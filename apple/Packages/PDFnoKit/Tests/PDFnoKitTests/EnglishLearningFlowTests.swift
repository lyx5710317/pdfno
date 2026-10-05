// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoUI

private actor EnglishCountingProvider: EnglishLearningProvider {
    nonisolated let mode = AIProviderMode.mock
    private(set) var calls = 0
    func analyze(_ request: EnglishLearningRequest) async throws -> Data {
        calls += 1; return try EnglishLearningMockCorpus.payload(for: request.source.anchor.quote)
    }
}
private actor EnglishLateProvider: EnglishLearningProvider {
    nonisolated let mode = AIProviderMode.mock
    private var continuation: CheckedContinuation<Data, Error>?
    private(set) var calls = 0
    private var text = ""
    func analyze(_ request: EnglishLearningRequest) async throws -> Data {
        calls += 1; text = request.source.anchor.quote
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish() throws {
        guard let value = continuation else { return }
        continuation = nil; value.resume(returning: try EnglishLearningMockCorpus.payload(for: text))
    }
}
private actor EnglishFakeTransport: EnglishLearningOfflineTransport {
    let response: AIHTTPResponse
    private(set) var bodies: [Data] = []
    init(_ response: AIHTTPResponse) { self.response = response }
    func send(_ body: Data) -> AIHTTPResponse { bodies.append(body); return response }
}
private func englishEnvelope(_ content: Data, reason: String = "stop") throws -> Data {
    try englishData(["choices": [["index": 0, "finish_reason": reason,
        "message": ["role": "assistant", "content": String(decoding: content, as: UTF8.self)]]]])
}
private func englishWaitForCall(_ provider: EnglishLateProvider) async throws {
    for _ in 0..<200 { if await provider.calls > 0 { return }; try await Task.sleep(for: .milliseconds(5)) }
    Issue.record("Synthetic provider was never called")
}
@MainActor private func englishWaitForCompletion(_ model: EnglishLearningModel) async throws {
    for _ in 0..<200 { if !model.busy { return }; try await Task.sleep(for: .milliseconds(5)) }
    Issue.record("Synthetic analysis did not complete")
}
struct EnglishLearningFlowTests {
    @Test func envelopeRequiresOneCompleteAssistantAndRejectsTruncationToolsUnknownTypes() throws {
        let payload = try EnglishLearningMockCorpus.payload(for: "Maya reads a book.")
        #expect(try EnglishLearningResponseDecoder.decode(AIHTTPResponse(status: 200, body: englishEnvelope(payload))) == payload)
        #expect(throws: AIFailure.truncated) { try EnglishLearningResponseDecoder.decode(AIHTTPResponse(status: 200, body: englishEnvelope(payload, reason: "length"))) }
        let original = try JSONSerialization.jsonObject(with: englishEnvelope(payload)) as! [String: Any]
        for mode in 0..<12 {
            var root = original, choices = root["choices"] as! [[String: Any]], choice = choices[0], message = choice["message"] as! [String: Any]
            switch mode {
            case 0: root["unknown"] = 1
            case 1: root["created"] = true
            case 2: choice["index"] = false
            case 3: choice["finish_reason"] = "tool_calls"
            case 4: message["role"] = "user"
            case 5: message["tool_calls"] = []
            case 6: message["function_call"] = ["name": "doSomething"]
            case 7: message["refusal"] = "refused"
            case 8: message["content"] = 1
            case 9: message["unknown"] = "x"
            case 10: root["usage"] = ["completion_tokens": true]
            default: root["model"] = ["unexpected": "container"]
            }
            choice["message"] = message; choices[0] = choice; root["choices"] = choices
            #expect(throws: AIFailure.output) { try EnglishLearningResponseDecoder.decode(AIHTTPResponse(status: 200, body: englishData(root))) }
        }
        var root = original; root["choices"] = Array(repeating: (original["choices"] as! [[String: Any]])[0], count: 2)
        #expect(throws: AIFailure.output) { try EnglishLearningResponseDecoder.decode(AIHTTPResponse(status: 200, body: englishData(root))) }
        root = original; root["usage"] = ["completion_tokens": 1025]
        #expect(throws: AIFailure.truncated) { try EnglishLearningResponseDecoder.decode(AIHTTPResponse(status: 200, body: englishData(root))) }
    }
    @Test func envelopeDuplicateKeysBodyBoundsAndHTTPFailuresAreSafe() throws {
        let original = try englishEnvelope(EnglishLearningMockCorpus.payload(for: "Maya reads a book.")), text = String(decoding: original, as: UTF8.self)
        for bad in [Data((text.dropLast() + ",\"choices\":[]}").utf8), Data(original.dropLast()), Data(repeating: 32, count: 65537)] {
            #expect(throws: AIFailure.output) { try EnglishLearningResponseDecoder.decode(AIHTTPResponse(status: 200, body: bad)) }
        }
        for (status, failure) in [(302, AIFailure.redirect), (401, .authentication), (402, .quota), (403, .authentication), (429, .rateLimit), (500, .server)] {
            #expect(throws: failure) { try EnglishLearningResponseDecoder.decode(AIHTTPResponse(status: status, body: Data("untrusted error body".utf8))) }
        }
    }
    @Test func interceptedWireContainsOnlySelectionTaskAndSameLimits() async throws {
        let request = englishRequest(), payload = try EnglishLearningMockCorpus.payload(for: request.source.anchor.quote)
        let transport = EnglishFakeTransport(AIHTTPResponse(status: 200, body: try englishEnvelope(payload)))
        let provider = OfflineEnvelopeEnglishLearningProvider(transport: transport)
        #expect(try await provider.analyze(request) == payload)
        let bodies = await transport.bodies, body = try #require(bodies.first)
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(Set(json.keys) == ["sourceText", "task", "max_tokens", "stream"])
        #expect(json["sourceText"] as? String == request.source.anchor.quote && json["max_tokens"] as? Int == 1024 && json["stream"] as? Bool == false)
        let text = String(decoding: body, as: UTF8.self)
        #expect(!text.contains(request.source.bookID.uuidString) && !text.contains("OUTSIDE") && !text.contains("Authorization"))
        #expect(bodies.count == 1)
        let input = try EnglishLearningPrompt.userContent(for: request)
        let user = try #require(JSONSerialization.jsonObject(with: input) as? [String: Any])
        #expect(Set(user.keys) == ["sourceText", "task"] && user["sourceText"] as? String == request.source.anchor.quote)
        #expect(EnglishLearningPrompt.system.contains("passive agent") && EnglishLearningPrompt.system.contains("pronoun antecedent") && EnglishLearningPrompt.system.contains("1024"))
    }
    @Test func consentBindsPurposeSourceProviderGenerationAndDeadline() async throws {
        let request = englishRequest(), coordinator = EnglishLearningCoordinator(), provider = EnglishCountingProvider()
        let valid = AIConsent(requestID: request.id, scopeFingerprint: try EnglishLearningCoordinator.fingerprint(request))
        await #expect(throws: AIFailure.consent) { try await coordinator.run(request, consent: AIConsent(requestID: request.id, scopeFingerprint: "wrong"), provider: provider) }
        #expect(await provider.calls == 0)
        #expect(try await coordinator.run(request, consent: valid, provider: provider).source == request.source)
        var config = request.provider; config.generation += 1
        let next = EnglishLearningRequest(id: request.id, source: request.source, provider: config)
        #expect(try EnglishLearningCoordinator.fingerprint(next) != valid.scopeFingerprint)
        let timeout = EnglishLearningRequest(id: request.id, source: request.source, provider: request.provider, timeoutSeconds: 1)
        #expect(try EnglishLearningCoordinator.fingerprint(timeout) != valid.scopeFingerprint)
        #expect(try EnglishLearningCoordinator.fingerprint(request) != JapaneseLearningCoordinator.fingerprint(JapaneseLearningRequest(id: request.id, source: request.source, provider: request.provider)))
    }
    @Test func timeoutDoesNotWaitForNoncooperativeProviderAndLateReplyIsFenced() async throws {
        let request = englishRequest(timeout: 0.04), provider = EnglishLateProvider(), coordinator = EnglishLearningCoordinator()
        let consent = AIConsent(requestID: request.id, scopeFingerprint: try EnglishLearningCoordinator.fingerprint(request))
        let task = Task { try await coordinator.run(request, consent: consent, provider: provider) }
        try await englishWaitForCall(provider)
        await #expect(throws: AIFailure.timeout) { try await task.value }
        try await provider.finish()
        let next = englishRequest()
        let review = try await coordinator.run(next, consent: AIConsent(requestID: next.id, scopeFingerprint: EnglishLearningCoordinator.fingerprint(next)), provider: LocalMockEnglishLearningProvider())
        #expect(review.requestID == next.id && review.isPersistable)
    }
    @Test func cancellationCompletesBeforeLateProviderAndNeverRetries() async throws {
        let request = englishRequest(), provider = EnglishLateProvider(), coordinator = EnglishLearningCoordinator()
        let consent = AIConsent(requestID: request.id, scopeFingerprint: try EnglishLearningCoordinator.fingerprint(request))
        let task = Task { try await coordinator.run(request, consent: consent, provider: provider) }
        try await englishWaitForCall(provider); task.cancel()
        await #expect(throws: AIFailure.cancelled) { try await task.value }
        try await provider.finish(); #expect(await provider.calls == 1)
    }
    @Test @MainActor func prepareNoConsentAndNoSaveCallbackCauseNoSendOrWrite() async throws {
        let provider = EnglishCountingProvider(), model = EnglishLearningModel(provider: provider, sourceIsCurrent: { _, _ in true })
        model.prepare(englishRequest()); model.userText = "draft"; model.start(confirmed: false)
        #expect(await provider.calls == 0 && model.review == nil && !model.canSave)
        model.start(confirmed: true); try await englishWaitForCompletion(model)
        #expect(await provider.calls == 1 && model.review?.isPersistable == true && !model.canSave)
        #expect(await model.save() == false && !model.saved && model.userText == "draft")
    }
    @Test @MainActor func modelSwitchBookOrServiceGenerationDropsLateResultsAndRestoresDrafts() async throws {
        let provider = EnglishLateProvider(), first = englishRequest()
        let model = EnglishLearningModel(provider: provider, sourceIsCurrent: { _, _ in true })
        model.prepare(first); model.userText = "first source draft"; model.start(confirmed: true)
        try await englishWaitForCall(provider)
        let second = englishRequest("Close the door.")
        model.prepare(second, provider: LocalMockEnglishLearningProvider())
        try await provider.finish(); try await Task.sleep(for: .milliseconds(10))
        #expect(model.review == nil && model.request?.source.bookID == second.source.bookID && model.userText.isEmpty)
        model.userText = "second source draft"
        var config = first.provider; config.generation += 1
        let changed = EnglishLearningRequest(source: first.source, provider: config)
        model.prepare(changed)
        #expect(model.userText == "first source draft" && model.review == nil && !model.busy)
        let revision = model.confirmationRevision
        model.prepare(changed, provider: LocalMockEnglishLearningProvider())
        #expect(model.confirmationRevision != revision)
    }
    @Test @MainActor func staleSourceBlocksStartSaveAndSourceReturn() async throws {
        var current = true, writes = 0
        let provider = EnglishCountingProvider(), model = EnglishLearningModel(provider: provider, sourceIsCurrent: { _, _ in current }, saveReviewedNote: { _ in writes += 1 })
        model.prepare(englishRequest()); model.start(confirmed: true); try await englishWaitForCompletion(model)
        current = false
        #expect(await model.save() == false && writes == 0 && model.currentSourceForReturn() == nil)
        model.start(confirmed: true)
        #expect(await provider.calls == 1 && model.error == AIFailure.stale.localizedDescription)
    }
    @Test @MainActor func sourceInvalidatedDuringAnalysisIsRefusedWithoutPrepareCallback() async throws {
        var current = true, writes = 0
        let provider = EnglishLateProvider()
        let model = EnglishLearningModel(provider: provider, sourceIsCurrent: { _, _ in current }, saveReviewedNote: { _ in writes += 1 })
        model.prepare(englishRequest()); model.start(confirmed: true); try await englishWaitForCall(provider)
        current = false; try await provider.finish(); try await englishWaitForCompletion(model)
        #expect(model.review == nil && !model.canSave && !model.saved && writes == 0)
        #expect(model.error == AIFailure.stale.localizedDescription)
    }
    @Test @MainActor func failedSaveKeepsDraftAndStableIDThenExplicitRetryPersistsOnce() async throws {
        let root = englishStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = EnglishLearningRepository(root: root)
        var fail = true, ids: [UUID] = []
        let model = EnglishLearningModel(provider: LocalMockEnglishLearningProvider(), sourceIsCurrent: { _, _ in true }, saveReviewedNote: { note in
            ids.append(note.id); if fail { throw AIFailure.store }; try await repository.saveNote(note)
        })
        model.prepare(englishRequest()); model.userText = " e\u{301} 👩🏽‍🚀 draft "; model.start(confirmed: true)
        try await englishWaitForCompletion(model)
        #expect(try await repository.load().notes.isEmpty)
        #expect(await model.save() == false && !model.saved && model.canSave && model.userText == " e\u{301} 👩🏽‍🚀 draft ")
        fail = false
        #expect(await model.save() && model.saved && ids.count == 2 && ids[0] == ids[1])
        let saved = try #require(await repository.load().notes.first)
        #expect(saved.userText.utf8.elementsEqual(model.userText.utf8) && saved.review == model.review)
        #expect(await model.save() == false)
        #expect(try await repository.load().notes.count == 1)
    }
    @Test @MainActor func reanalysisKeepsUserBodyAndProducesNewImmutableReview() async throws {
        let model = EnglishLearningModel(provider: LocalMockEnglishLearningProvider(), sourceIsCurrent: { _, _ in true })
        model.prepare(englishRequest()); model.userText = "user correction: inspect this inference"
        model.start(confirmed: true); try await englishWaitForCompletion(model); let first = try #require(model.review)
        model.start(confirmed: true); try await englishWaitForCompletion(model)
        #expect(model.userText == "user correction: inspect this inference" && model.review?.requestID != first.requestID)
        #expect(model.review?.source == first.source && model.review?.sourceTextSHA256 == first.sourceTextSHA256)
    }
}
