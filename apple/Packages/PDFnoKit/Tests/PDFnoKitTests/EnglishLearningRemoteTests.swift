// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoUI

private let englishSyntheticKey = "synthetic-english-offline-only"
private actor EnglishFakeCredentials: AICredentialStore {
    let value: String?
    private(set) var reads = 0
    init(_ value: String? = englishSyntheticKey) { self.value = value }
    func read(_ reference: UUID) -> String? { reads += 1; return value }
    func put(_ value: String, reference: UUID) {}
    func remove(_ reference: UUID) {}
}
private actor EnglishDeferredCredentials: AICredentialStore {
    private var continuation: CheckedContinuation<String?, Error>?
    func started() -> Bool { continuation != nil }
    func read(_ reference: UUID) async throws -> String? { try await withCheckedThrowingContinuation { continuation = $0 } }
    func put(_ value: String, reference: UUID) {}
    func remove(_ reference: UUID) {}
    func finish() { continuation?.resume(returning: englishSyntheticKey); continuation = nil }
}
private actor EnglishHTTPStub: AIHTTPTransport {
    private(set) var requests: [URLRequest] = []
    let status: Int
    let body: Data?
    init(status: Int = 200, body: Data? = nil) { self.status = status; self.body = body }
    func send(_ request: URLRequest) throws -> AIHTTPResponse {
        requests.append(request)
        if let body { return AIHTTPResponse(status: status, body: body) }
        let requestBody = try #require(request.httpBody)
        let http = try #require(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
        let messages = try #require(http["messages"] as? [[String: String]])
        let content = try #require(messages.last?["content"])
        let input = try #require(JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: String])
        let payload = try EnglishLearningMockCorpus.payload(for: #require(input["sourceText"]))
        let envelope: [String: Any] = ["id": "synthetic-response", "object": "chat.completion", "created": 1,
            "model": DeepSeekSelectionPolicy.model, "choices": [["index": 0, "finish_reason": "stop", "logprobs": NSNull(),
                "message": ["role": "assistant", "content": String(decoding: payload, as: UTF8.self)]]],
            "usage": ["prompt_tokens": 100, "completion_tokens": 500, "total_tokens": 600,
                "prompt_cache_hit_tokens": 0, "prompt_cache_miss_tokens": 100]]
        return AIHTTPResponse(status: status, body: try englishData(envelope))
    }
}
private actor EnglishDeferredHTTP: AIHTTPTransport {
    private var continuation: CheckedContinuation<AIHTTPResponse, Error>?
    private(set) var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        requests.append(request)
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish() { continuation?.resume(returning: AIHTTPResponse(status: 429, body: Data())); continuation = nil }
}
private func englishRemoteRequest(_ text: String = "Maya reads a book.", timeout: Double = 30) -> EnglishLearningRequest {
    EnglishLearningRequest(source: englishSource(text), provider: DeepSeekSelectionPolicy.configuration(), timeoutSeconds: timeout)
}
private func englishWaitForHTTP(_ transport: EnglishDeferredHTTP) async throws {
    for _ in 0..<200 { if await !transport.requests.isEmpty { return }; try await Task.sleep(for: .milliseconds(5)) }
    Issue.record("Intercepted HTTP was not reached")
}
struct EnglishLearningRemoteTests {
    @Test func realAdapterSerializesExactEnglishRequestIntoInterceptedTransport() async throws {
        let session = AppAISession(), credentials = EnglishFakeCredentials(), transport = EnglishHTTPStub()
        let adapter = DeepSeekEnglishLearningProvider(transport: transport, credentials: credentials, credentialReference: UUID(), aiSession: session)
        let request = englishRemoteRequest(), data = try await adapter.analyze(request)
        let review = EnglishLearningValidator.validate(data, request: request)
        #expect(review.isPersistable && review.components.count == 3 && review.grammar.first?.aspect == .tense)
        let http = try #require(await transport.requests.first)
        #expect(http.url?.absoluteString == "https://api.deepseek.com/chat/completions" && http.httpMethod == "POST")
        #expect(http.timeoutInterval == 30 && !http.httpShouldHandleCookies && http.cachePolicy == .reloadIgnoringLocalAndRemoteCacheData)
        #expect(http.value(forHTTPHeaderField: "Authorization") == "Bearer " + englishSyntheticKey)
        let requestBody = try #require(http.httpBody)
        let body = try #require(JSONSerialization.jsonObject(with: requestBody) as? [String: Any])
        #expect(Set(body.keys) == ["model", "stream", "max_tokens", "thinking", "response_format", "messages"])
        #expect(body["model"] as? String == DeepSeekSelectionPolicy.model && body["max_tokens"] as? Int == 1024 && body["stream"] as? Bool == false)
        #expect(body["thinking"] as? [String: String] == ["type": "disabled"] && body["response_format"] as? [String: String] == ["type": "json_object"])
        let messages = try #require(body["messages"] as? [[String: String]])
        #expect(messages.count == 2 && messages[0]["content"] == EnglishLearningPrompt.system)
        let content = try #require(messages[1]["content"])
        let input = try #require(JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: String])
        #expect(Set(input.keys) == ["sourceText", "task"] && input["sourceText"]?.utf8.elementsEqual(request.source.anchor.quote.utf8) == true)
        let wire = String(decoding: try #require(http.httpBody), as: UTF8.self)
        for excluded in [englishSyntheticKey, request.source.bookID.uuidString, "OUTSIDE-FIXED-SELECTION", "OUTSIDE-SUFFIX", "OEBPS/original.xhtml"] { #expect(!wire.contains(excluded)) }
        #expect(await adapter.attemptsUsed() == 1)
    }
    @Test func invalidEndpointInputAndTimeoutNeverReadCredentialsReserveOrSend() async throws {
        let session = AppAISession(), credentials = EnglishFakeCredentials(), transport = EnglishHTTPStub()
        let adapter = DeepSeekEnglishLearningProvider(transport: transport, credentials: credentials, credentialReference: UUID(), aiSession: session)
        let original = englishRemoteRequest()
        for endpoint in ["https://other.invalid", "https://api.deepseek.com:8443", "https://user@api.deepseek.com", "http://api.deepseek.com", "https://api.deepseek.com/beta"] {
            var config = original.provider; config.endpoint = endpoint
            await #expect(throws: AIFailure.configuration) { try await adapter.analyze(EnglishLearningRequest(source: original.source, provider: config)) }
        }
        await #expect(throws: AIFailure.remoteInputLimit) { try await adapter.analyze(englishRemoteRequest(String(repeating: "a", count: 501))) }
        await #expect(throws: AIFailure.configuration) { try await adapter.analyze(englishRemoteRequest(timeout: 31)) }
        #expect(await credentials.reads == 0)
        #expect(await transport.requests.isEmpty)
        #expect(await session.selection.attemptsUsed() == 0)
    }
    @Test func missingOrInvalidSyntheticCredentialsNeverUseBudgetOrNetwork() async throws {
        for key in [nil, "", "contains\nnewline"] as [String?] {
            let session = AppAISession(), transport = EnglishHTTPStub()
            let adapter = DeepSeekEnglishLearningProvider(transport: transport, credentials: EnglishFakeCredentials(key), credentialReference: UUID(), aiSession: session)
            await #expect(throws: AIFailure.credentials) { try await adapter.analyze(englishRemoteRequest()) }
            #expect(await session.selection.attemptsUsed() == 0)
            #expect(await transport.requests.isEmpty)
        }
    }
    @Test func cancelledCredentialReadNeverReservesOrSubmits() async throws {
        let session = AppAISession(), credentials = EnglishDeferredCredentials(), transport = EnglishHTTPStub()
        let adapter = DeepSeekEnglishLearningProvider(transport: transport, credentials: credentials, credentialReference: UUID(), aiSession: session)
        let task = Task { try await adapter.analyze(englishRemoteRequest()) }
        for _ in 0..<200 { if await credentials.started() { break }; try await Task.sleep(for: .milliseconds(5)) }
        try #require(await credentials.started()); task.cancel(); await credentials.finish()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await transport.requests.isEmpty)
        #expect(await session.selection.attemptsUsed() == 0)
    }
    @Test func EnglishJapaneseAndTranslationShareSameThreeAttemptsAcrossRecreatedProviders() async throws {
        let session = AppAISession(), credentials = EnglishFakeCredentials(), transport = EnglishHTTPStub(status: 429), reference = UUID()
        let request = englishRemoteRequest()
        let english = DeepSeekEnglishLearningProvider(transport: transport, credentials: credentials, credentialReference: reference, aiSession: session)
        let japanese = DeepSeekJapaneseLearningProvider(transport: transport, credentials: credentials, credentialReference: reference, aiSession: session)
        let translation = DeepSeekSelectionProvider(transport: transport, credentials: credentials, credentialReference: reference, budget: session.selection)
        await #expect(throws: AIFailure.rateLimit) { try await english.analyze(request) }
        await #expect(throws: AIFailure.rateLimit) { try await japanese.analyze(JapaneseLearningRequest(source: request.source, provider: request.provider)) }
        await #expect(throws: AIFailure.rateLimit) { try await translation.analyze(AIRequest(source: request.source, provider: request.provider, kind: .translate)) }
        let recreated = DeepSeekEnglishLearningProvider(transport: transport, credentials: credentials, credentialReference: reference, aiSession: session)
        await #expect(throws: AIFailure.attemptLimit) { try await recreated.analyze(request) }
        #expect(await transport.requests.count == 3)
        #expect(await session.selection.attemptsUsed() == 3)
        #expect(await session.probe.attemptsUsed() == 0)
        #expect(await session.page.attemptsUsed() == 0)
        #expect(await session.chapter.attemptsUsed() == 0)
    }
    @Test func cancelledInterceptedHTTPStillConsumesSharedAttemptAndLateReplyIsDiscarded() async throws {
        let session = AppAISession(), transport = EnglishDeferredHTTP(), coordinator = EnglishLearningCoordinator()
        let provider = DeepSeekEnglishLearningProvider(transport: transport, credentials: EnglishFakeCredentials(), credentialReference: UUID(), aiSession: session)
        let request = englishRemoteRequest(), consent = AIConsent(requestID: request.id, scopeFingerprint: try EnglishLearningCoordinator.fingerprint(request))
        let task = Task { try await coordinator.run(request, consent: consent, provider: provider) }
        try await englishWaitForHTTP(transport); task.cancel()
        await #expect(throws: AIFailure.cancelled) { try await task.value }
        #expect(await session.selection.attemptsUsed() == 1)
        await transport.finish()
        #expect(await transport.requests.count == 1)
    }
    @Test func interceptedRemoteTimeoutIsBoundedAndCannotResetSharedBudget() async throws {
        let session = AppAISession(), transport = EnglishDeferredHTTP(), coordinator = EnglishLearningCoordinator()
        let provider = DeepSeekEnglishLearningProvider(transport: transport, credentials: EnglishFakeCredentials(), credentialReference: UUID(), aiSession: session)
        let request = englishRemoteRequest(timeout: 0.04), consent = AIConsent(requestID: request.id, scopeFingerprint: try EnglishLearningCoordinator.fingerprint(request))
        let task = Task { try await coordinator.run(request, consent: consent, provider: provider) }
        try await englishWaitForHTTP(transport)
        await #expect(throws: AIFailure.timeout) { try await task.value }
        await transport.finish()
        #expect(await provider.attemptsUsed() == 1)
        #expect(await transport.requests.count == 1)
    }
    @Test @MainActor func realAdapterRequiresManualConsentAndNeverPersistsSyntheticCredential() async throws {
        let session = AppAISession(), transport = EnglishHTTPStub(), credentials = EnglishFakeCredentials(), root = englishStorageRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = EnglishLearningRepository(root: root)
        let provider = DeepSeekEnglishLearningProvider(transport: transport, credentials: credentials, credentialReference: UUID(), aiSession: session)
        let model = EnglishLearningModel(provider: provider, sourceIsCurrent: { _, _ in true }, saveReviewedNote: { try await repository.saveNote($0) })
        model.prepare(englishRemoteRequest()); model.start(confirmed: false)
        #expect(await transport.requests.isEmpty)
        #expect(await credentials.reads == 0)
        model.start(confirmed: true)
        for _ in 0..<200 { if !model.busy { break }; try await Task.sleep(for: .milliseconds(5)) }
        #expect(model.review?.isPersistable == true && model.attemptsUsed == 1 && !model.saved)
        #expect(try await repository.load().notes.isEmpty)
        #expect(await model.save())
        let manifest = try String(contentsOf: root.appendingPathComponent(EnglishLearningRepository.filename), encoding: .utf8)
        #expect(!manifest.contains(englishSyntheticKey) && !manifest.contains("Authorization") && !manifest.contains("credentialReference"))
    }
}
