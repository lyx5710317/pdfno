// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Original text and wholly intercepted transports. No URLSession, Keychain or real service.
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

private func conversationSource(_ text: String = "Maya reads beside a quiet window.") -> AISourceSnapshot {
    .init(bookID: UUID(),readerSessionID: UUID(),documentVersion: 0,anchor: .pdf(.init(editionID: UUID(),fileSHA256: String(repeating: "a",count: 64),quote: text,
        regions: [.init(pageIndex: 0,x: 1,y: 1,width: 30,height: 10,quote: text)])))
}
private func conversationConfig(_ remote: Bool = false) -> AIProviderConfig {
    var c = AIProviderConfig(); c.mode = remote ? .openAICompatible : .mock; c.label = "Original fixture"
    c.model = "synthetic-conversation-only"; c.endpoint = remote ? "https://fixture.invalid/v1" : ""; return c
}
private func conversationEnvelope(quote: String, text: String = "Original synthetic answer", finish: String = "stop", tool: Bool = false, content: String? = nil) throws -> AIHTTPResponse {
    let payload = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1,"sourceQuote": quote,"text": text])
    var message: [String: Any] = ["role": "assistant","content": content ?? String(decoding: payload,as: UTF8.self)]
    if tool { message["tool_calls"] = [["id": "rejected-tool"]] }
    return .init(status: 200,body: try JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": finish,"message": message]]]))
}
private actor ConversationCredentials: AICredentialStore {
    private(set) var reads = 0
    func read(_ reference: UUID) -> String? { reads += 1; return "original-synthetic-credential-never-live" }
    func put(_ value: String,reference: UUID) {}
    func remove(_ reference: UUID) {}
}
private actor ConversationHTTP: AIHTTPTransport {
    private(set) var requests: [URLRequest] = []
    let response: AIHTTPResponse?
    init(response: AIHTTPResponse? = nil) { self.response = response }
    func send(_ request: URLRequest) throws -> AIHTTPResponse {
        requests.append(request)
        if let response { return response }
        let bytes = try #require(request.httpBody)
        let wire = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let messages = try #require(wire["messages"] as? [[String: String]])
        let content = try #require(messages.last?["content"])
        let input = try #require(JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any])
        let quote = try #require(input["sourceText"] as? String)
        return try conversationEnvelope(quote: quote)
    }
}
private actor DeferredConversation: ReadingConversationProvider {
    private var continuation: CheckedContinuation<String, Error>?
    func answer(_ plan: ReadingConversationPlan) async throws -> String { try await withCheckedThrowingContinuation { continuation = $0 } }
    func started() -> Bool { continuation != nil }
    func finish() { continuation?.resume(returning: "Original late response"); continuation = nil }
}
private actor ConversationGate {
    var current = true
    func invalidate() { current = false }
    func check() -> Bool { current }
}
struct ReadingConversationTests {
    private func consent(_ p: ReadingConversationPlan) -> ReadingSkillConsent { .init(taskID: p.requestID,planFingerprint: p.fingerprint) }
    @Test func fiveCompiledSkillsHaveDistinctInstructionsAndRegisteredSelectionBudgets() throws {
        #expect(Set(ReadingConversationTask.allCases.map(\.skillID)).count == 5)
        #expect(Set(ReadingConversationTask.allCases.map(\.instruction)).count == 5)
        for task in ReadingConversationTask.allCases {
            let plan = try ReadingConversationPlan(conversationID: UUID(),task: task,source: conversationSource(),provider: conversationConfig(),question: task.initialQuestion)
            let manifest = try ReadingSkillRegistry.builtin.manifest(for: task.skillID)
            #expect(manifest.scope == .selection && manifest.tools.isEmpty && manifest.extraContext.isEmpty && !manifest.automaticSave)
            #expect(plan.maxOutputTokens == manifest.budget.maxOutputTokensPerRequest && plan.receiverURL == nil)
        }
    }
    @Test func contextCannotCrossDocumentSessionOrConversationAndNeverSilentlyTruncates() throws {
        let source = conversationSource(), id = UUID(), c = conversationConfig()
        let user = try ReadingConversationTurn(role: .user,text: "Original first question",conversationID: id,source: source)
        let assistant = try ReadingConversationTurn(role: .assistant,text: "Original first answer",conversationID: id,source: source)
        let p = try ReadingConversationPlan(conversationID: id,task: .explain,source: source,provider: c,history: [user,assistant],question: "Why?")
        #expect(p.history.count == 2)
        #expect(throws: ReadingSkillFailure.input) { try ReadingConversationPlan(conversationID: UUID(),task: .explain,source: source,provider: c,history: p.history,question: "Why?") }
        #expect(throws: ReadingSkillFailure.input) { try ReadingConversationPlan(conversationID: id,task: .explain,source: conversationSource(),provider: c,history: p.history,question: "Why?") }
        #expect(throws: ReadingSkillFailure.input) { try ReadingConversationPlan(conversationID: id,task: .explain,source: source,provider: c,history: [assistant,user],question: "Why?") }
        #expect(throws: ReadingSkillFailure.input) { try ReadingConversationPlan(conversationID: id,task: .explain,source: source,provider: c,question: String(repeating: "x",count: 1501)) }
        #expect(throws: AIFailure.remoteInputLimit) { try ReadingConversationPlan(conversationID: id,task: .explain,source: conversationSource(String(repeating: "x",count: 501)),provider: c,question: "Why?") }
        let long = try ReadingConversationTurn(role: .assistant,text: String(repeating: "x",count: 10001),conversationID: id,source: source)
        #expect(throws: ReadingSkillFailure.input) { try ReadingConversationPlan(conversationID: id,task: .explain,source: source,provider: c,history: [user,long],question: "Why?") }
    }
    @Test func changedContextAndStaleSourceRejectBeforeCredentialsOrTransport() async throws {
        let source = conversationSource(), id = UUID(), config = conversationConfig(true)
        let plan = try ReadingConversationPlan(conversationID: id,task: .translate,source: source,provider: config,question: "Original question")
        let changed = try ReadingConversationPlan(requestID: plan.requestID,conversationID: id,answerID: plan.answerID,task: .translate,source: source,provider: config,question: "Changed question")
        let credentials = ConversationCredentials(), http = ConversationHTTP(), budget = DeepSeekSelectionBudget()
        let provider = ReadingConversationHTTPProvider(transport: http,credentials: credentials,reference: UUID(),budget: budget), coordinator = ReadingConversationCoordinator()
        await #expect(throws: AIFailure.consent) { try await coordinator.run(changed,consent: consent(plan),provider: provider,current: { _,_ in true }) }
        await #expect(throws: AIFailure.stale) { try await coordinator.run(plan,consent: consent(plan),provider: provider,current: { _,_ in false }) }
        #expect(await credentials.reads == 0); #expect(await http.requests.isEmpty)
        #expect(await budget.attemptsUsed() == 0)
    }
    @Test func eachSkillActuallyDispatchesItsPromptWithOnlyFixedSelectionAndExplicitThread() async throws {
        for task in ReadingConversationTask.allCases {
            let source = conversationSource(), id = UUID(), credentials = ConversationCredentials(), http = ConversationHTTP()
            let history = try [ReadingConversationTurn(role: .user,text: "Prior question",conversationID: id,source: source),
                ReadingConversationTurn(role: .assistant,text: "Prior answer",conversationID: id,source: source)]
            let plan = try ReadingConversationPlan(conversationID: id,task: task,source: source,provider: conversationConfig(true),history: history,question: "Follow-up")
            let provider = ReadingConversationHTTPProvider(transport: http,credentials: credentials,reference: UUID(),budget: DeepSeekSelectionBudget())
            let result = try await ReadingConversationCoordinator().run(plan,consent: consent(plan),provider: provider,current: { _,_ in true })
            #expect(result.conversation?.task == task && result.requestID == plan.answerID && result.isValidAnnotationResult)
            let request = try #require(await http.requests.first), body = try #require(request.httpBody)
            let wire = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any]), messages = try #require(wire["messages"] as? [[String: String]])
            #expect(messages.count == 4 && messages[0]["content"]?.contains(task.instruction) == true)
            #expect(messages.map { $0["role"]! } == ["system","user","assistant","user"])
            #expect(wire["tools"] == nil && wire["stream"] as? Bool == false && wire["max_tokens"] as? Int == 1024)
            #expect(request.url?.absoluteString == "https://fixture.invalid/v1/chat/completions" && !request.httpShouldHandleCookies)
            let content = try #require(messages.last?["content"])
            let input = try #require(JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any])
            #expect(input["sourceText"] as? String == source.anchor.quote && input["question"] as? String == "Follow-up")
            #expect(input["bookID"] == nil && input["readerSessionID"] == nil)
        }
    }
    @Test func toolsWrongQuotesTruncationDuplicatePayloadKeysAndAuthenticationRemainRejected() async throws {
        let plan = try ReadingConversationPlan(conversationID: UUID(),task: .english,source: conversationSource("window"),provider: conversationConfig(true),question: "Explain")
        let cases: [(AIHTTPResponse,AIFailure)] = [
            (try conversationEnvelope(quote: "different"),.output), (try conversationEnvelope(quote: "window",tool: true),.output),
            (try conversationEnvelope(quote: "window",finish: "length"),.truncated),
            (try conversationEnvelope(quote: "window",content: "{\"schemaVersion\":1,\"sourceQuote\":\"wrong\",\"sourceQuote\":\"window\",\"text\":\"answer\"}"),.output),
            (.init(status: 401,body: Data("must-not-display-private-provider-error".utf8)),.authentication)]
        for (response,error) in cases {
            let provider = ReadingConversationHTTPProvider(transport: ConversationHTTP(response: response),credentials: ConversationCredentials(),reference: UUID(),budget: DeepSeekSelectionBudget())
            await #expect(throws: error) { try await provider.answer(plan) }
        }
    }
    @Test func cancellationTimeoutAndStaleCompletionRejectUncooperativeLateResponses() async throws {
        let plan = try ReadingConversationPlan(conversationID: UUID(),task: .explain,source: conversationSource(),provider: conversationConfig(),question: "Original question",timeoutSeconds: 0.2)
        let provider = DeferredConversation(), coordinator = ReadingConversationCoordinator()
        let operation = Task { try await coordinator.run(plan,consent: consent(plan),provider: provider,current: { _,_ in true }) }
        for _ in 0..<50 { if await provider.started() { break }; try await Task.sleep(for: .milliseconds(10)) }
        #expect(await provider.started()); operation.cancel()
        await #expect(throws: AIFailure.cancelled) { try await operation.value }; await provider.finish()
        let timeoutProvider = DeferredConversation()
        await #expect(throws: AIFailure.timeout) { try await coordinator.run(plan,consent: consent(plan),provider: timeoutProvider,current: { _,_ in true }) }
        await timeoutProvider.finish()
        let gate = ConversationGate(), late = DeferredConversation()
        let stale = Task { try await coordinator.run(plan,consent: consent(plan),provider: late,current: { _,_ in await gate.check() }) }
        for _ in 0..<50 { if await late.started() { break }; try await Task.sleep(for: .milliseconds(10)) }
        await gate.invalidate(); await late.finish()
        await #expect(throws: AIFailure.stale) { try await stale.value }
    }
    @Test func legacyJSONRemainsReadableAndEveryExplicitSavedAnswerKeepsTaskAndStableDedupeID() async throws {
        let old = AIResult(request: AIRequest(source: conversationSource(),provider: conversationConfig(),kind: .translate),text: "Original old translation",fromCache: false)
        let encoded = try JSONEncoder().encode(old), json = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        let decodedOld = try JSONDecoder().decode(AIResult.self,from: encoded)
        #expect(json["conversation"] == nil && decodedOld == old)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Original-Conversation-Notes-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = AnnotationRepository(root: root)
        for task in ReadingConversationTask.allCases {
            let plan = try ReadingConversationPlan(conversationID: UUID(),task: task,source: conversationSource(),provider: conversationConfig(),question: task.initialQuestion)
            let result = try plan.result("Original answer " + task.rawValue)
            #expect(try await repository.load().notes.count == ReadingConversationTask.allCases.firstIndex(of: task))
            let saved = try await repository.addAIResult(result,comment: "Original user note"), duplicate = try await repository.addAIResult(result,comment: "ignored duplicate")
            #expect(saved.id == duplicate.id && saved.aiResult == result && saved.displayTitle == "AI " + task.title)
            #expect((try JSONDecoder().decode(AIResult.self,from: JSONEncoder().encode(result))).conversation?.task == task)
        }
        #expect(try await repository.load().notes.count == 5)
    }
    @Test func connectionProbeNeedsConsentAndSendsOnlyFixedBooklessSentence() async throws {
        let credentials = ConversationCredentials(), http = ConversationHTTP(), budget = DeepSeekSelectionBudget(), probe = ReadingConnectionProbe(), config = conversationConfig(true)
        await #expect(throws: AIFailure.consent) { try await probe.run(configuration: config,credentials: credentials,reference: UUID(),transport: http,budget: budget,confirmed: false,current: { _ in true }) }
        #expect(await credentials.reads == 0); #expect(await http.requests.isEmpty)
        _ = try await probe.run(configuration: config,credentials: credentials,reference: UUID(),transport: http,budget: budget,confirmed: true,current: { _ in true })
        let request = try #require(await http.requests.first), bytes = try #require(request.httpBody)
        let wire = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let messages = try #require(wire["messages"] as? [[String: String]])
        let content = try #require(messages.last?["content"])
        let input = try #require(JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: Any])
        #expect(messages.count == 2 && wire["max_tokens"] as? Int == 128 && input["sourceText"] as? String == ReadingConnectionProbe.sentence)
        let used = await budget.attemptsUsed()
        #expect(input["history"] == nil && input["bookID"] == nil && used == 1)
    }
    @Test func localMockCanExposeARealGeneratingStopAndManualRetryLifecycleWithoutTransport() async throws {
        let plan = try ReadingConversationPlan(conversationID: UUID(),task: .explain,source: conversationSource(),provider: conversationConfig(),question: "Original question")
        let coordinator = ReadingConversationCoordinator(), provider = LocalReadingConversationProvider(delaySeconds: 0.2)
        let stopped = Task { try await coordinator.run(plan,consent: consent(plan),provider: provider,current: { _,_ in true }) }
        try await Task.sleep(for: .milliseconds(50)); stopped.cancel()
        await #expect(throws: AIFailure.cancelled) { try await stopped.value }
        let retried = try await coordinator.run(plan,consent: consent(plan),provider: provider,current: { _,_ in true })
        #expect(retried.text.hasPrefix("本地 mock") && retried.conversation?.question == "Original question")
    }
}
