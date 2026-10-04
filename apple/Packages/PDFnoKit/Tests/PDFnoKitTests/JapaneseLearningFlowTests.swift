// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
@testable import PDFnoServices
@testable import PDFnoUI

@MainActor private final class JapaneseScopeFlag { var current = true }

private let japaneseSyntheticKey = "synthetic-japanese-offline-only"
private actor JapaneseFakeCredentials: AICredentialStore {
    private(set) var reads = 0
    func read(_ reference: UUID) -> String? { reads += 1; return japaneseSyntheticKey }
    func put(_ value: String, reference: UUID) {}
    func remove(_ reference: UUID) {}
}
private func japaneseEnvelope(_ content: String, finish: String = "stop", role: String = "assistant", tool: Any = NSNull()) throws -> Data {
    try JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": finish,
        "message": ["role": role, "content": content, "tool_calls": tool, "function_call": NSNull()]]]])
}
private actor JapaneseHTTPStub: AIHTTPTransport {
    private(set) var requests: [URLRequest] = []
    let status: Int
    let body: Data?
    init(status: Int = 200, body: Data? = nil) { self.status = status; self.body = body }
    func send(_ request: URLRequest) throws -> AIHTTPResponse {
        requests.append(request)
        if let body { return AIHTTPResponse(status: status, body: body) }
        let http = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = http["messages"] as! [[String: String]]
        let input = try JSONSerialization.jsonObject(with: Data(messages[1]["content"]!.utf8)) as! [String: String]
        let payload = try japaneseData(japanesePayload(input["sourceText"]!, readings: [japaneseReading()], grammar: [japaneseGrammar()]))
        return AIHTTPResponse(status: status, body: try japaneseEnvelope(String(decoding: payload, as: UTF8.self)))
    }
}
private actor JapanesePayloadStub: JapaneseLearningProvider {
    nonisolated let mode = AIProviderMode.mock
    private(set) var calls = 0
    let invalid: Bool
    init(invalid: Bool = false) { self.invalid = invalid }
    func attemptsUsed() -> Int { 0 }
    func analyze(_ request: JapaneseLearningRequest) throws -> Data {
        calls += 1
        if invalid { return Data("PRIVATE-INVALID-OUTPUT".utf8) }
        return try japaneseData(japanesePayload(request.source.anchor.quote, readings: [japaneseReading()], grammar: [japaneseGrammar()]))
    }
}
private actor JapaneseDeferredStub: JapaneseLearningProvider {
    nonisolated let mode = AIProviderMode.mock
    private var continuation: CheckedContinuation<Data, Error>?
    private(set) var calls = 0
    func attemptsUsed() -> Int { 0 }
    func started() -> Bool { continuation != nil }
    func analyze(_ request: JapaneseLearningRequest) async throws -> Data {
        calls += 1
        return try await withCheckedThrowingContinuation { continuation = $0 } // Deliberately ignores cancellation.
    }
    func finish(_ quote: String) throws {
        let payload = try japaneseData(japanesePayload(quote, readings: [japaneseReading()]))
        continuation?.resume(returning: payload); continuation = nil
    }
}
private func waitForJapaneseStart(_ provider: JapaneseDeferredStub) async throws {
    let deadline = Date().addingTimeInterval(3)
    while !(await provider.started()), Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
    try #require(await provider.started())
}
@MainActor private func waitForJapaneseIdle(_ model: JapaneseLearningModel) async throws {
    let deadline = Date().addingTimeInterval(3)
    while model.busy, Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
    try #require(!model.busy)
}

@MainActor
struct JapaneseLearningFlowTests {
    @Test func BYOKRequestCapsOnlySourceFakeCredentialsAndStrictCompletion() async throws {
        let credentials = JapaneseFakeCredentials(), transport = JapaneseHTTPStub(), session = AppAISession()
        let adapter = DeepSeekJapaneseLearningProvider(transport: transport, credentials: credentials, credentialReference: UUID(), aiSession: session)
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig(mock: false))
        let data = try await adapter.analyze(request)
        let review = JapaneseLearningValidator.validate(data, request: request)
        #expect(review.readings.count == 1 && review.grammar.count == 1)
        let sent = try #require(await transport.requests.first)
        #expect(sent.url?.absoluteString == "https://api.deepseek.com/chat/completions")
        #expect(sent.timeoutInterval == 30 && sent.httpShouldHandleCookies == false)
        #expect(sent.value(forHTTPHeaderField: "Authorization") == "Bearer " + japaneseSyntheticKey)
        let body = try JSONSerialization.jsonObject(with: sent.httpBody!) as! [String: Any]
        #expect(Set(body.keys) == Set(["model", "stream", "max_tokens", "thinking", "response_format", "messages"]))
        #expect(body["max_tokens"] as? Int == 1024 && body["stream"] as? Bool == false)
        #expect(body["thinking"] as? [String: String] == ["type": "disabled"])
        #expect(body["response_format"] as? [String: String] == ["type": "json_object"])
        let messages = body["messages"] as! [[String: String]]
        let input = try JSONSerialization.jsonObject(with: Data(messages[1]["content"]!.utf8)) as! [String: String]
        #expect(Set(input.keys) == Set(["sourceText", "task"]) && input["sourceText"] == request.source.anchor.quote)
        let wire = String(decoding: sent.httpBody!, as: UTF8.self)
        for excluded in [japaneseSyntheticKey, request.source.bookID.uuidString, "PRIVATE-OUTSIDE-SELECTION", "PRIVATE-SUFFIX", "OEBPS/original.xhtml"] {
            #expect(!wire.contains(excluded))
        }
        #expect(await session.selection.attemptsUsed() == 1)
    }
    @Test func invalidInputConfigOrDeadlineNeverReadCredentialsOrSend() async throws {
        let credentials = JapaneseFakeCredentials(), transport = JapaneseHTTPStub(), session = AppAISession()
        let adapter = DeepSeekJapaneseLearningProvider(transport: transport, credentials: credentials, credentialReference: UUID(), aiSession: session)
        for endpoint in ["https://other.invalid", "https://api.deepseek.com:8443", "https://user@api.deepseek.com", "http://api.deepseek.com", "https://api.deepseek.com/beta"] {
            var config = japaneseConfig(mock: false); config.endpoint = endpoint
            await #expect(throws: AIFailure.configuration) { try await adapter.analyze(JapaneseLearningRequest(source: japaneseSource(), provider: config)) }
        }
        await #expect(throws: AIFailure.remoteInputLimit) { try await adapter.analyze(JapaneseLearningRequest(source: japaneseSource(String(repeating: "猫", count: 501)), provider: japaneseConfig(mock: false))) }
        await #expect(throws: AIFailure.configuration) { try await adapter.analyze(JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig(mock: false), timeoutSeconds: 31)) }
        #expect(await credentials.reads == 0)
        #expect(await transport.requests.isEmpty)
        #expect(await session.selection.attemptsUsed() == 0)
    }
    @Test func JapaneseAndExistingTranslationExplainShareThreeAttemptsAcrossProviders() async throws {
        let session = AppAISession(), transport = JapaneseHTTPStub(status: 429), credentials = JapaneseFakeCredentials(), reference = UUID()
        let source = japaneseSource(), config = japaneseConfig(mock: false)
        let old = DeepSeekSelectionProvider(transport: transport, credentials: credentials, credentialReference: reference, budget: session.selection)
        await #expect(throws: AIFailure.rateLimit) { try await old.analyze(AIRequest(source: source, provider: config, kind: .translate)) }
        for _ in 0..<2 {
            let new = DeepSeekJapaneseLearningProvider(transport: transport, credentials: credentials, credentialReference: reference, aiSession: session)
            await #expect(throws: AIFailure.rateLimit) { try await new.analyze(JapaneseLearningRequest(source: source, provider: config)) }
        }
        let recreated = DeepSeekJapaneseLearningProvider(transport: transport, credentials: credentials, credentialReference: reference, aiSession: session)
        await #expect(throws: AIFailure.attemptLimit) { try await recreated.analyze(JapaneseLearningRequest(source: source, provider: config)) }
        await #expect(throws: AIFailure.attemptLimit) { try await old.analyze(AIRequest(source: source, provider: config, kind: .explain)) }
        #expect(await transport.requests.count == 3)
        #expect(await session.selection.attemptsUsed() == 3)
        #expect(await session.probe.attemptsUsed() == 0)
        #expect(await session.page.attemptsUsed() == 0)
        #expect(await session.chapter.attemptsUsed() == 0)
    }
    @Test func envelopeErrorsNeverBecomeReviewContentOrRetry() throws {
        for (status, error) in [(302, AIFailure.redirect), (401, .authentication), (403, .authentication), (402, .quota), (429, .rateLimit), (500, .server)] {
            #expect(throws: error) { try JapaneseLearningHTTPCodec.decode(AIHTTPResponse(status: status, body: Data("PRIVATE BODY".utf8))) }
        }
        #expect(throws: AIFailure.truncated) { try JapaneseLearningHTTPCodec.decode(AIHTTPResponse(status: 200, body: japaneseEnvelope("{}", finish: "length"))) }
        for body in [try japaneseEnvelope("{}", finish: "tool_calls"), try japaneseEnvelope("{}", role: "user"),
                     try japaneseEnvelope("{}", tool: [["name": "synthetic"]]), Data(repeating: 32, count: 65537)] {
            #expect(throws: AIFailure.output) { try JapaneseLearningHTTPCodec.decode(AIHTTPResponse(status: 200, body: body)) }
        }
    }
    @Test func consentBindsPurposeSourceConfigurationAndLimitsBeforeProvider() async throws {
        let source = japaneseSource(), config = japaneseConfig(), request = JapaneseLearningRequest(source: source, provider: config)
        let scope = try JapaneseLearningCoordinator.fingerprint(request)
        #expect(scope != (try AIJobCoordinator.fingerprint(AIRequest(source: source, provider: config, kind: .explain))))
        var changed = config; changed.generation += 1
        #expect(scope != (try JapaneseLearningCoordinator.fingerprint(JapaneseLearningRequest(source: source, provider: changed))))
        #expect(scope != (try JapaneseLearningCoordinator.fingerprint(JapaneseLearningRequest(source: source, provider: config, timeoutSeconds: 1))))
        let provider = JapanesePayloadStub(), coordinator = JapaneseLearningCoordinator()
        await #expect(throws: AIFailure.consent) { try await coordinator.run(request, consent: AIConsent(requestID: UUID(), scopeFingerprint: scope), provider: provider) }
        await #expect(throws: AIFailure.consent) { try await coordinator.run(request, consent: AIConsent(requestID: request.id, scopeFingerprint: "wrong"), provider: provider) }
        #expect(await provider.calls == 0)
        let review = try await coordinator.run(request, consent: AIConsent(requestID: request.id, scopeFingerprint: scope), provider: provider)
        #expect(review.source == source && review.requestID == request.id)
    }
    @Test func cancelAndTimeoutIgnoreNoncooperativeLateOutputAndNeverCacheIt() async throws {
        for timeout in [false, true] {
            let provider = JapaneseDeferredStub(), coordinator = JapaneseLearningCoordinator()
            let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig(), timeoutSeconds: timeout ? 0.03 : 30)
            let scope = try JapaneseLearningCoordinator.fingerprint(request)
            let job = Task { try await coordinator.run(request, consent: AIConsent(requestID: request.id, scopeFingerprint: scope), provider: provider) }
            try await waitForJapaneseStart(provider)
            if !timeout { await coordinator.cancel(request.id) }
            do { _ = try await job.value; Issue.record("Cancelled/timed out request unexpectedly returned") }
            catch { #expect(error as? AIFailure == (timeout ? .timeout : .cancelled)) }
            try await provider.finish(request.source.anchor.quote)
            let next = JapaneseLearningRequest(source: request.source, provider: request.provider)
            let consent = AIConsent(requestID: next.id, scopeFingerprint: try JapaneseLearningCoordinator.fingerprint(next))
            let retry = Task { try await coordinator.run(next, consent: consent, provider: provider) }
            try await waitForJapaneseStart(provider); try await provider.finish(next.source.anchor.quote)
            #expect(try await retry.value.requestID == next.id)
            #expect(await provider.calls == 2) // No cancelled-output cache and no automatic retry.
        }
    }
    @Test func explicitStartManualSaveAndRegenerationPreserveIndependentDraftCorrections() async throws {
        let provider = JapanesePayloadStub(); var notes: [JapaneseLearningNote] = []
        let model = JapaneseLearningModel(provider: provider, sourceIsCurrent: { _, _ in true }, saveReviewedNote: { notes.append($0) })
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        model.prepare(request); model.userText = " 原笔记\nか\u{3099}👩🏽‍🚀 "
        model.start(confirmed: false); #expect(await provider.calls == 0 && !model.busy)
        model.start(confirmed: true); try await waitForJapaneseIdle(model)
        let review = try #require(model.review); #expect(notes.isEmpty && !model.saved)
        model.readingCorrections[review.readings[0].span.correctionKey] = "ネコ"
        #expect(await model.save() && notes.count == 1)
        #expect(notes[0].userText.utf8.elementsEqual(model.userText.utf8) && notes[0].corrections[0].reading == "ネコ")
        #expect(notes[0].review.readings[0].candidates == ["ねこ"])
        #expect(!(await model.save()) && notes.count == 1)
        var nextConfig = request.provider; nextConfig.generation += 1
        model.prepare(JapaneseLearningRequest(source: request.source, provider: nextConfig))
        #expect(model.userText == " 原笔记\nか\u{3099}👩🏽‍🚀 " && model.readingCorrections[review.readings[0].span.correctionKey] == "ネコ")
        model.start(confirmed: true); try await waitForJapaneseIdle(model)
        #expect(model.review?.requestID != review.requestID && notes.count == 1)
        #expect(model.userText == " 原笔记\nか\u{3099}👩🏽‍🚀 ")
    }
    @Test func staleSourceAtCompletionCannotDisplaySaveOrEmphasize() async throws {
        let provider = JapaneseDeferredStub(), scopeFlag = JapaneseScopeFlag(); var saves = 0
        let model = JapaneseLearningModel(provider: provider, sourceIsCurrent: { _, _ in scopeFlag.current }, saveReviewedNote: { _ in saves += 1 })
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        model.prepare(request); model.userText = "保留草稿"; model.start(confirmed: true)
        try await waitForJapaneseStart(provider); scopeFlag.current = false
        try await provider.finish(request.source.anchor.quote); try await waitForJapaneseIdle(model)
        #expect(model.review == nil && model.error == AIFailure.stale.localizedDescription && model.userText == "保留草稿")
        #expect(!(await model.save()) && saves == 0)
        #expect(model.emphasisSource(for: JapaneseSpan(start: 0, end: 1, quote: "猫")) == nil)
    }
    @Test func bookAndConfigurationChangesCancelLateResultAndIsolateDrafts() async throws {
        for changeConfig in [false, true] {
            let provider = JapaneseDeferredStub(), model = JapaneseLearningModel(provider: provider, sourceIsCurrent: { _, _ in true })
            let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
            model.prepare(request); model.userText = "Original independent draft"; model.start(confirmed: true)
            try await waitForJapaneseStart(provider)
            var config = request.provider; config.generation += 1
            let other = JapaneseLearningRequest(source: changeConfig ? request.source : japaneseSource(), provider: changeConfig ? config : request.provider)
            model.prepare(other)
            #expect(!model.busy && model.review == nil)
            #expect(model.userText == (changeConfig ? "Original independent draft" : ""))
            try await provider.finish(request.source.anchor.quote); try await Task.sleep(for: .milliseconds(10))
            #expect(model.review == nil)
            model.prepare(request); #expect(model.userText == "Original independent draft")
        }
    }
    @Test func invalidOutputDegradesToSourceOnlyReviewAndCannotSave() async throws {
        let provider = JapanesePayloadStub(invalid: true); var saves = 0
        let model = JapaneseLearningModel(provider: provider, sourceIsCurrent: { _, _ in true }, saveReviewedNote: { _ in saves += 1 })
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        model.prepare(request); model.start(confirmed: true); try await waitForJapaneseIdle(model)
        let review = try #require(model.review)
        #expect(review.status == .unavailable && review.source == request.source && review.translationZh == nil)
        #expect(!review.warnings.joined().contains("PRIVATE-INVALID-OUTPUT"))
        #expect(!model.canSave)
        #expect(!(await model.save()) && saves == 0)
    }
    @Test func saveFailureRetainsDraftAndUsesStableNewNoteIdentity() async throws {
        let provider = JapanesePayloadStub(); var ids: [UUID] = []
        let model = JapaneseLearningModel(provider: provider, sourceIsCurrent: { _, _ in true }, saveReviewedNote: { note in
            ids.append(note.id); throw AIFailure.store
        })
        model.prepare(JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig()))
        model.start(confirmed: true); try await waitForJapaneseIdle(model); model.userText = "Do not lose my draft"
        #expect(!(await model.save()))
        #expect(!(await model.save()))
        #expect(ids.count == 2 && ids[0] == ids[1] && !model.saved && model.userText == "Do not lose my draft")
    }
    @Test func explicitMockRemainsOfflineAndUnconnectedStorageDisabled() async throws {
        let provider = LocalMockJapaneseLearningProvider(), model = JapaneseLearningModel(provider: provider, sourceIsCurrent: { _, _ in true })
        model.prepare(JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig()))
        model.start(confirmed: true); try await waitForJapaneseIdle(model)
        #expect(model.review?.readings.isEmpty == true && model.review?.status == .needsReview)
        #expect(model.attemptsUsed == 0 && !model.canSave)
    }
}

private actor JapaneseDeferredHTTP: AIHTTPTransport {
    private var continuation: CheckedContinuation<AIHTTPResponse, Error>?
    private(set) var calls = 0
    func started() -> Bool { continuation != nil }
    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        calls += 1; return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish(_ quote: String) throws {
        let payload = try japaneseData(japanesePayload(quote))
        continuation?.resume(returning: AIHTTPResponse(status: 200, body: try japaneseEnvelope(String(decoding: payload, as: UTF8.self))))
        continuation = nil
    }
}
extension JapaneseLearningFlowTests {
    @Test func cancelledInterceptedHTTPStillConsumesSharedSelectionBudget() async throws {
        let transport = JapaneseDeferredHTTP(), session = AppAISession(), credentials = JapaneseFakeCredentials()
        let adapter = DeepSeekJapaneseLearningProvider(transport: transport, credentials: credentials, credentialReference: UUID(), aiSession: session)
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig(mock: false))
        let model = JapaneseLearningModel(provider: adapter, sourceIsCurrent: { _, _ in true })
        model.prepare(request); model.start(confirmed: true)
        let deadline = Date().addingTimeInterval(3)
        while !(await transport.started()), Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        try #require(await transport.started())
        #expect(await session.selection.attemptsUsed() == 1)
        model.cancel(); try await transport.finish(request.source.anchor.quote)
        try await Task.sleep(for: .milliseconds(15))
        #expect(model.review == nil && !model.busy)
        #expect(await session.selection.attemptsUsed() == 1)
        #expect(await transport.calls == 1)
    }
    @Test func providerReplacementInvalidatesConfirmationAndOldResult() async throws {
        let first = JapanesePayloadStub(), second = JapanesePayloadStub()
        let model = JapaneseLearningModel(provider: first, sourceIsCurrent: { _, _ in true })
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        model.prepare(request); model.start(confirmed: true); try await waitForJapaneseIdle(model)
        let scope = model.confirmationScope, revision = model.confirmationRevision
        model.prepare(request, provider: second)
        #expect(model.confirmationScope == scope && model.confirmationRevision != revision && model.review == nil)
        #expect(await second.calls == 0)
    }
    @Test func visitingManySourcesDoesNotSilentlyDiscardOriginalDraft() async throws {
        let model = JapaneseLearningModel(provider: JapanesePayloadStub(), sourceIsCurrent: { _, _ in true })
        let original = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        model.prepare(original); model.userText = "Original unsaved text"
        for _ in 0..<24 { model.prepare(JapaneseLearningRequest(source: japaneseSource(), provider: original.provider)) }
        model.prepare(original); #expect(model.userText == "Original unsaved text")
    }
    @Test func emphasisRequiresAcceptedSpanAndCurrentSource() async throws {
        let scopeFlag = JapaneseScopeFlag()
        let model = JapaneseLearningModel(provider: JapanesePayloadStub(), sourceIsCurrent: { _, _ in scopeFlag.current })
        model.prepare(JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig()))
        model.start(confirmed: true); try await waitForJapaneseIdle(model)
        let review = try #require(model.review)
        #expect(model.emphasisSource(for: review.readings[0].span) == review.source)
        #expect(model.emphasisSource(for: JapaneseSpan(start: 5, end: 6, quote: "猫")) == nil)
        scopeFlag.current = false
        #expect(model.emphasisSource(for: review.readings[0].span) == nil && model.currentSourceForReturn() == nil)
    }
}
