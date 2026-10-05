// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Original synthetic sources, isolated temporary stores and wholly intercepted HTTP only.
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

private func hostSkillSource(_ quote: String = "Maya reads a book.", version: Int = 0) -> AISourceSnapshot {
    .init(bookID: UUID(), readerSessionID: UUID(), documentVersion: version,
        anchor: .pdf(.init(editionID: UUID(), fileSHA256: String(repeating: "a", count: 64), quote: quote,
            regions: [.init(pageIndex: 0, x: 1, y: 1, width: 20, height: 10, quote: quote)])))
}
private func hostSkillRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("reading-skills-host-" + UUID().uuidString) }
private func hostSkillResponse(_ request: URLRequest) throws -> AIHTTPResponse {
    let body = try #require(request.httpBody)
    let wire = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    let messages = try #require(wire["messages"] as? [[String: String]])
    let content = try #require(messages.last?["content"])
    let input = try #require(JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: String])
    let quote = try #require(input["sourceText"]), task = try #require(input["task"])
    let payload: Data
    if task == "english-selection-learning" { payload = try EnglishLearningMockCorpus.payload(for: quote) }
    else if task == "japanese-selection-learning" {
        payload = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "language": "ja", "sourceQuote": quote,
            "offsetUnit": "unicode-code-point", "translationZh": NSNull(), "readings": [], "grammar": [], "components": [],
            "warnings": ["原创拦截传输，只检查宿主接入，不验证语法质量。"]])
    } else { payload = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "sourceQuote": quote, "text": "原创合成结果 " + task]) }
    let envelope: [String: Any] = ["choices": [["index": 0, "finish_reason": "stop", "message": ["role": "assistant", "content": String(decoding: payload, as: UTF8.self)]]]]
    return .init(status: 200, body: try JSONSerialization.data(withJSONObject: envelope))
}
private actor HostSkillHTTP: AIHTTPTransport {
    private(set) var requests: [URLRequest] = []
    func send(_ request: URLRequest) throws -> AIHTTPResponse { requests.append(request); return try hostSkillResponse(request) }
}
private actor HostSkillDeferredHTTP: AIHTTPTransport {
    private var continuation: CheckedContinuation<AIHTTPResponse, Error>?
    private(set) var requests: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        requests.append(request)
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish() throws {
        let request = try #require(requests.last), response = try hostSkillResponse(request)
        continuation?.resume(returning: response); continuation = nil
    }
    func started() -> Bool { continuation != nil }
}
private actor HostSkillDeferredEnglish: EnglishLearningProvider {
    let mode = AIProviderMode.mock
    private var continuation: CheckedContinuation<Data, Error>?
    private var quote = ""
    func analyze(_ request: EnglishLearningRequest) async throws -> Data {
        quote = request.source.anchor.quote
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func started() -> Bool { continuation != nil }
    func finish() throws { continuation?.resume(returning: try EnglishLearningMockCorpus.payload(for: quote)); continuation = nil }
}
private actor HostSkillDeferredJapanese: JapaneseLearningProvider {
    let mode = AIProviderMode.mock
    private var continuation: CheckedContinuation<Data, Error>?
    private var quote = ""
    func attemptsUsed() -> Int { 0 }
    func analyze(_ request: JapaneseLearningRequest) async throws -> Data {
        quote = request.source.anchor.quote
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func started() -> Bool { continuation != nil }
    func finish() throws {
        let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "language": "ja", "sourceQuote": quote,
            "offsetUnit": "unicode-code-point", "translationZh": NSNull(), "readings": [], "grammar": [], "components": [], "warnings": []])
        continuation?.resume(returning: data); continuation = nil
    }
}
private struct HostSkillMalformedEnglish: EnglishLearningProvider {
    let mode = AIProviderMode.mock
    func analyze(_ request: EnglishLearningRequest) -> Data { Data("PRIVATE-INVALID-ORIGINAL-FIXTURE".utf8) }
}
private struct HostSkillMalformedJapanese: JapaneseLearningProvider {
    let mode = AIProviderMode.mock
    func attemptsUsed() -> Int { 0 }
    func analyze(_ request: JapaneseLearningRequest) -> Data { Data("PRIVATE-INVALID-ORIGINAL-FIXTURE".utf8) }
}
@MainActor private final class HostSkillFence {
    var source: AISourceSnapshot
    var config: AIProviderConfig
    var active = true
    init(source: AISourceSnapshot, config: AIProviderConfig) { self.source = source; self.config = config }
    func sourceIsCurrent(_ source: AISourceSnapshot) -> Bool { active && ReadingSkillIdentity.matches(self.source, source) }
    func isCurrent(_ source: AISourceSnapshot, _ config: AIProviderConfig) -> Bool {
        sourceIsCurrent(source) && ReadingSkillIdentity.matches(self.config, config)
    }
}
@MainActor private func hostSkillWait(_ busy: () -> Bool) async throws {
    for _ in 0..<400 { if !busy() { return }; try await Task.sleep(for: .milliseconds(5)) }
    throw ReadingSkillFailure.result
}
private func hostSkillWaitForHTTP(_ transport: HostSkillDeferredHTTP) async throws {
    for _ in 0..<400 { if await transport.started() { return }; try await Task.sleep(for: .milliseconds(5)) }
    throw ReadingSkillFailure.result
}
private func hostSkillWaitForEnglish(_ provider: HostSkillDeferredEnglish) async throws {
    for _ in 0..<400 { if await provider.started() { return }; try await Task.sleep(for: .milliseconds(5)) }
    throw ReadingSkillFailure.result
}
struct ReadingSkillHostIntegrationTests {
    @Test @MainActor func allFourExistingHostActionsProduceTypedSkillsEnvelopesWithoutNewUIOrSave() async throws {
        let root = hostSkillRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let session = AppAISession(), transport = HostSkillHTTP(), learning = AILearningModel(root: root, transport: transport, aiSession: session)
        var mock = AIProviderConfig(); mock.mode = .mock; mock.label = "原创合成演示"
        #expect(await learning.saveConfig(mock, temporarySecret: ""))
        let source = hostSkillSource(), fence = HostSkillFence(source: source, config: learning.config)
        learning.prepare(source)
        for (kind, id) in [(AILearningKind.translate, ReadingSkillID.translateSelection), (.explain, .explainSelection)] {
            learning.kind = kind; learning.start(confirmed: false, sourceIsCurrent: fence.sourceIsCurrent)
            #expect(!learning.busy && learning.readingSkillPlan == nil)
            learning.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); try await hostSkillWait { learning.busy }
            let envelope = try #require(learning.readingSkillResult), result = try #require(learning.result)
            #expect(envelope.manifest.skillID == id.rawValue && envelope.taskID == result.requestID && envelope.usage == .localSynthetic)
            #expect(envelope.sources[0].bodySHA256 == EnglishLearningPolicy.textHash(source.anchor.quote))
            learning.result = nil // Same action as the existing task Picker.
            #expect(learning.readingSkillResult == nil && learning.readingSkillPlan == nil)
        }
        let jpSource = hostSkillSource("山へ行く。"), jpFence = HostSkillFence(source: jpSource, config: learning.config)
        let japanese = JapaneseLearningModel(provider: try learning.japaneseLearningProvider(), sourceIsCurrent: jpFence.isCurrent)
        japanese.prepare(.init(source: jpSource, provider: learning.config, authorReadings: [.init(span: .init(start: 0, end: 1, quote: "山"), reading: "やま")]))
        japanese.start(confirmed: false); #expect(!japanese.busy && japanese.readingSkillPlan == nil)
        japanese.start(confirmed: true); try await hostSkillWait { japanese.busy }
        #expect(japanese.readingSkillResult?.manifest.skillID == ReadingSkillID.japaneseSelection.rawValue)
        #expect(japanese.review?.authorReadings.first?.reading == "やま" && japanese.readingSkillResult?.validation == .candidatesNeedReview)
        let english = EnglishLearningModel(provider: try learning.englishLearningProvider(), sourceIsCurrent: fence.isCurrent)
        english.prepare(.init(source: source, provider: learning.config)); english.start(confirmed: false)
        #expect(!english.busy && english.readingSkillPlan == nil)
        english.start(confirmed: true); try await hostSkillWait { english.busy }
        #expect(english.readingSkillResult?.manifest.skillID == ReadingSkillID.englishSelection.rawValue && english.review?.components.count == 3)
        #expect(await transport.requests.isEmpty)
        #expect(await session.selection.attemptsUsed() == 0)
        #expect(try await learning.repository.load().notes.isEmpty)
    }
    @Test @MainActor func cancelledQueuedHostsCannotPublishOldPlansIntoANewSource() async throws {
        let root = hostSkillRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let transport = HostSkillHTTP(), session = AppAISession(), text = AILearningModel(root: root, transport: transport, aiSession: session)
        var mock = AIProviderConfig(); mock.mode = .mock; #expect(await text.saveConfig(mock, temporarySecret: ""))
        let source = hostSkillSource(), fence = HostSkillFence(source: source, config: text.config)
        text.prepare(source); text.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); text.prepare(nil)
        let english = EnglishLearningModel(provider: LocalMockEnglishLearningProvider(), sourceIsCurrent: fence.isCurrent)
        english.prepare(.init(source: source, provider: text.config)); english.start(confirmed: true); english.prepare(nil)
        let japanese = JapaneseLearningModel(provider: LocalMockJapaneseLearningProvider(), sourceIsCurrent: fence.isCurrent)
        japanese.prepare(.init(source: source, provider: text.config)); japanese.start(confirmed: true); japanese.prepare(nil)
        for _ in 0..<5 { await Task.yield() }
        #expect(text.readingSkillPlan == nil && text.readingSkillResult == nil && text.source == nil)
        #expect(english.readingSkillPlan == nil && english.readingSkillResult == nil && english.request == nil)
        #expect(japanese.readingSkillPlan == nil && japanese.readingSkillResult == nil && japanese.request == nil)
        #expect(await transport.requests.isEmpty)
        #expect(await session.selection.attemptsUsed() == 0)
    }
    @Test @MainActor func actualTextHostKeepsLegacyMock8000GateAndRemote500Gate() async throws {
        let root = hostSkillRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let transport = HostSkillHTTP(), session = AppAISession(), model = AILearningModel(root: root, transport: transport, aiSession: session)
        var mock = AIProviderConfig(); mock.mode = .mock
        #expect(await model.saveConfig(mock, temporarySecret: ""))
        let source = hostSkillSource(String(repeating: "a", count: 8000)), fence = HostSkillFence(source: source, config: model.config)
        model.prepare(source); model.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); try await hostSkillWait { model.busy }
        #expect(model.readingSkillResult?.sources[0].source.anchor.quote.utf16.count == 8000)
        #expect(model.readingSkillResult?.usage == .localSynthetic)
        model.prepare(hostSkillSource(String(repeating: "a", count: 8001)))
        model.start(confirmed: true, sourceIsCurrent: { _ in true }); #expect(model.error == AIFailure.inputLimit.localizedDescription)
        #expect(await model.saveConfig(DeepSeekSelectionPolicy.configuration(), temporarySecret: "original-synthetic-host-credential"))
        let oversized = hostSkillSource(String(repeating: "a", count: 501)); model.prepare(oversized)
        model.start(confirmed: true, sourceIsCurrent: { _ in true }); #expect(model.error == AIFailure.remoteInputLimit.localizedDescription)
        #expect(await transport.requests.isEmpty)
        #expect(await session.selection.attemptsUsed() == 0)
    }
    @Test @MainActor func actualModelsShareThreeAttemptsAndCacheDoesNotDoubleChargeOrGrantANewPool() async throws {
        let root = hostSkillRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let transport = HostSkillHTTP(), session = AppAISession(), learning = AILearningModel(root: root, transport: transport, aiSession: session)
        #expect(await learning.saveConfig(DeepSeekSelectionPolicy.configuration(), temporarySecret: "original-synthetic-host-credential"))
        let source = hostSkillSource(), fence = HostSkillFence(source: source, config: learning.config)
        learning.prepare(source)
        for cached in [false, true] {
            learning.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); try await hostSkillWait { learning.busy }
            #expect(learning.readingSkillResult?.fromCache == cached && learning.result?.fromCache == cached)
        }
        #expect(await transport.requests.count == 1)
        #expect(await session.selection.attemptsUsed() == 1)
        let english = EnglishLearningModel(provider: try learning.englishLearningProvider(), sourceIsCurrent: fence.isCurrent)
        english.prepare(.init(source: source, provider: learning.config)); english.start(confirmed: true); try await hostSkillWait { english.busy }
        #expect(english.readingSkillResult != nil)
        let jpSource = hostSkillSource("山へ行く。"), jpFence = HostSkillFence(source: jpSource, config: learning.config)
        let japanese = JapaneseLearningModel(provider: try learning.japaneseLearningProvider(), sourceIsCurrent: jpFence.isCurrent)
        japanese.prepare(.init(source: jpSource, provider: learning.config)); japanese.start(confirmed: true); try await hostSkillWait { japanese.busy }
        #expect(japanese.readingSkillResult != nil)
        learning.kind = .explain; learning.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); try await hostSkillWait { learning.busy }
        #expect(learning.error == AIFailure.attemptLimit.localizedDescription && learning.readingSkillResult == nil)
        let byok = BYOKSettingsModel(transport: transport, aiSession: session)
        byok.temporarySecret = "original-synthetic-host-credential"; #expect(await byok.apply())
        await byok.prepareSelection(source, kind: .explain); byok.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); try await hostSkillWait { byok.busy }
        #expect(byok.error == AIFailure.attemptLimit.localizedDescription && byok.readingSkillResult == nil)
        #expect(await transport.requests.count == 3)
        #expect(await session.selection.attemptsUsed() == 3)
        #expect(await session.page.attemptsUsed() == 0)
        #expect(await session.chapter.attemptsUsed() == 0)
        #expect(await session.probe.attemptsUsed() == 0)
    }
    @Test @MainActor func customBYOKExistingActionsRouteWithoutChangingWireConfirmationOrKeyRevocation() async throws {
        let transport = HostSkillHTTP(), session = AppAISession(), byok = BYOKSettingsModel(transport: transport, aiSession: session)
        var config = byok.draft; config.endpoint = "https://original-fixture.invalid/v1"; config.model = "original-synthetic-model"
        byok.draft = config; byok.temporarySecret = "original-synthetic-host-credential"; #expect(await byok.apply())
        let source = hostSkillSource("cafe\u{301} 👩🏽‍💻"), fence = HostSkillFence(source: source, config: byok.draft)
        for (kind, id) in [(AILearningKind.translate, ReadingSkillID.translateSelection), (.explain, .explainSelection)] {
            await byok.prepareSelection(source, kind: kind)
            let before = await transport.requests.count
            byok.start(confirmed: false, sourceIsCurrent: fence.sourceIsCurrent); #expect(!byok.busy)
            #expect(await transport.requests.count == before)
            byok.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); try await hostSkillWait { byok.busy }
            #expect(byok.readingSkillResult?.manifest.skillID == id.rawValue && byok.result != nil)
            #expect(byok.readingSkillPlan?.receiverURL?.absoluteString == "https://original-fixture.invalid/v1/chat/completions")
            let request = try #require(await transport.requests.last), body = try #require(request.httpBody)
            let wire = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
            #expect(wire["stream"] as? Bool == false && wire["max_tokens"] as? Int == 1024)
            let messages = try #require(wire["messages"] as? [[String: String]]), content = try #require(messages.last?["content"])
            let input = try #require(JSONSerialization.jsonObject(with: Data(content.utf8)) as? [String: String])
            #expect(Set(input.keys) == ["sourceText", "task", "targetLanguage"])
            #expect(input["sourceText"]?.utf8.elementsEqual(source.anchor.quote.utf8) == true)
        }
        await byok.clearCredential(); await byok.prepareSelection(source, kind: .explain)
        byok.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); try await hostSkillWait { byok.busy }
        #expect(byok.error == AIFailure.credentials.localizedDescription && byok.readingSkillResult == nil)
        #expect(await transport.requests.count == 2)
        #expect(await session.selection.attemptsUsed() == 2)
    }
    @Test @MainActor func sourceOnlyUnavailableLanguageReviewsPreserveOriginalUIAndCannotSave() async throws {
        var mock = AIProviderConfig(); mock.mode = .mock
        let source = hostSkillSource(), fence = HostSkillFence(source: source, config: mock)
        let en = EnglishLearningModel(provider: HostSkillMalformedEnglish(), sourceIsCurrent: fence.isCurrent, saveReviewedNote: { _ in Issue.record("Unavailable result saved") })
        en.prepare(.init(source: source, provider: mock)); en.start(confirmed: true); try await hostSkillWait { en.busy }
        let jp = JapaneseLearningModel(provider: HostSkillMalformedJapanese(), sourceIsCurrent: fence.isCurrent, saveReviewedNote: { _ in Issue.record("Unavailable result saved") })
        jp.prepare(.init(source: source, provider: mock)); jp.start(confirmed: true); try await hostSkillWait { jp.busy }
        #expect(en.error == nil && en.review?.status == .unavailable && en.readingSkillResult?.validation == .trustedSourceOnly)
        #expect(jp.error == nil && jp.review?.status == .unavailable && jp.readingSkillResult?.validation == .trustedSourceOnly)
        #expect(!en.canSave && !jp.canSave)
        #expect(await en.save() == false)
        #expect(await jp.save() == false)
        #expect(en.review?.warnings.joined().contains("PRIVATE-INVALID") == false && jp.review?.warnings.joined().contains("PRIVATE-INVALID") == false)
        #expect(en.review?.components.isEmpty == true && jp.review?.readings.isEmpty == true)
        #expect(en.review?.source.anchor.quote.utf8.elementsEqual(source.anchor.quote.utf8) == true)
    }
    @Test(arguments: [false, true]) @MainActor func textHostCancellationOrTimeoutNeverPublishesLateSkillEnvelope(timedOut: Bool) async throws {
        let root = hostSkillRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let transport = HostSkillDeferredHTTP(), session = AppAISession()
        let model = AILearningModel(root: root, transport: transport, timeoutSeconds: timedOut ? 0.1 : 30, aiSession: session)
        #expect(await model.saveConfig(DeepSeekSelectionPolicy.configuration(), temporarySecret: "original-synthetic-host-credential"))
        let source = hostSkillSource(), fence = HostSkillFence(source: source, config: model.config)
        model.prepare(source); model.userText = "原始草稿 e\u{301} 👩🏽‍💻"; model.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent)
        try await hostSkillWaitForHTTP(transport)
        if !timedOut { model.cancel() }
        try await hostSkillWait { model.busy }; try await transport.finish()
        try await Task.sleep(for: .milliseconds(30))
        #expect(model.result == nil && model.readingSkillResult == nil)
        #expect(model.error == (timedOut ? AIFailure.timeout : .cancelled).localizedDescription)
        #expect(model.userText.utf8.elementsEqual("原始草稿 e\u{301} 👩🏽‍💻".utf8))
        #expect(await session.selection.attemptsUsed() == 1)
        #expect(await transport.requests.count == 1)
        #expect(try await model.repository.load().notes.isEmpty)
    }
    @Test(arguments: [false, true]) @MainActor func currentSourceOrConfigurationChangingDuringTextRequestBlocksEnvelope(configurationChanges: Bool) async throws {
        let root = hostSkillRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let transport = HostSkillDeferredHTTP(), session = AppAISession(), model = AILearningModel(root: root, transport: transport, aiSession: session)
        #expect(await model.saveConfig(DeepSeekSelectionPolicy.configuration(), temporarySecret: "original-synthetic-host-credential"))
        let source = hostSkillSource(), fence = HostSkillFence(source: source, config: model.config)
        model.prepare(source); model.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); try await hostSkillWaitForHTTP(transport)
        if configurationChanges { model.config.generation += 1 } else { fence.active = false }
        try await transport.finish(); try await hostSkillWait { model.busy }
        #expect(model.result == nil && model.readingSkillResult == nil && model.error == AIFailure.stale.localizedDescription)
        #expect(await session.selection.attemptsUsed() == 1)
    }
    @Test @MainActor func englishProviderReplacementAndReanalysisRetainDraftButDiscardLateSkillEnvelope() async throws {
        var mock = AIProviderConfig(); mock.mode = .mock
        let provider = HostSkillDeferredEnglish(), source = hostSkillSource(), fence = HostSkillFence(source: source, config: mock)
        let model = EnglishLearningModel(provider: provider, sourceIsCurrent: fence.isCurrent)
        let request = EnglishLearningRequest(source: source, provider: mock)
        model.prepare(request); model.userText = "原始草稿 e\u{301}"; model.start(confirmed: true); try await hostSkillWaitForEnglish(provider)
        let previousRevision = model.confirmationRevision
        model.prepare(request, provider: LocalMockEnglishLearningProvider())
        #expect(model.confirmationRevision != previousRevision && !model.busy && model.readingSkillResult == nil)
        try await provider.finish(); try await Task.sleep(for: .milliseconds(30))
        #expect(model.review == nil && model.readingSkillResult == nil && model.userText == "原始草稿 e\u{301}")
        model.start(confirmed: false); #expect(!model.busy && model.review == nil)
        model.start(confirmed: true); try await hostSkillWait { model.busy }
        #expect(model.readingSkillResult?.manifest.skillID == ReadingSkillID.englishSelection.rawValue && model.review?.components.count == 3)
    }
    @Test @MainActor func japaneseSourceReplacementRejectsLateEnvelopeAndRetainsPerSourceDraft() async throws {
        var mock = AIProviderConfig(); mock.mode = .mock
        let source = hostSkillSource("山へ行く。"), fence = HostSkillFence(source: source, config: mock), provider = HostSkillDeferredJapanese()
        let model = JapaneseLearningModel(provider: provider, sourceIsCurrent: fence.isCurrent)
        let original = JapaneseLearningRequest(source: source, provider: mock)
        model.prepare(original); model.userText = "原始日语草稿 e\u{301}"; model.start(confirmed: true)
        for _ in 0..<400 { if await provider.started() { break }; try await Task.sleep(for: .milliseconds(5)) }
        #expect(await provider.started())
        let replacement = hostSkillSource("雪が降る。", version: 1); fence.source = replacement
        model.prepare(.init(source: replacement, provider: mock), provider: LocalMockJapaneseLearningProvider())
        try await provider.finish(); try await Task.sleep(for: .milliseconds(30))
        #expect(model.review == nil && model.readingSkillResult == nil && !model.busy)
        model.start(confirmed: false); #expect(!model.busy && model.review == nil)
        model.start(confirmed: true); try await hostSkillWait { model.busy }
        #expect(model.readingSkillResult?.manifest.skillID == ReadingSkillID.japaneseSelection.rawValue)
        #expect(model.review?.source.documentVersion == 1)
        fence.source = source; model.prepare(original, provider: LocalMockJapaneseLearningProvider())
        #expect(model.userText.utf8.elementsEqual("原始日语草稿 e\u{301}".utf8))
    }
    @Test(arguments: ["dismiss", "receiver", "credential"]) @MainActor func byokRevocationWhileRequestIsInFlightRejectsLateEnvelope(action: String) async throws {
        let transport = HostSkillDeferredHTTP(), session = AppAISession(), byok = BYOKSettingsModel(transport: transport, aiSession: session)
        byok.temporarySecret = "original-synthetic-host-credential"; #expect(await byok.apply())
        let source = hostSkillSource(), fence = HostSkillFence(source: source, config: byok.draft)
        await byok.prepareSelection(source, kind: .translate)
        byok.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); try await hostSkillWaitForHTTP(transport)
        switch action {
        case "dismiss": byok.invalidate()
        case "receiver": byok.draft.endpoint = "https://replacement-original.invalid/v1"
        default: await byok.clearCredential()
        }
        try await transport.finish(); try await Task.sleep(for: .milliseconds(30))
        #expect(!byok.busy && byok.result == nil && byok.readingSkillResult == nil && byok.preview == nil)
        byok.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent)
        #expect(byok.error == AIFailure.consent.localizedDescription)
        #expect(await transport.requests.count == 1)
        #expect(await session.selection.attemptsUsed() == 1)
    }
    @Test @MainActor func textSkillsResultStillSavesNativeNotesWithoutOverwritingEditedBody() async throws {
        let root = hostSkillRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let model = AILearningModel(root: root, transport: HostSkillHTTP(), aiSession: AppAISession())
        var mock = AIProviderConfig(); mock.mode = .mock; #expect(await model.saveConfig(mock, temporarySecret: ""))
        let source = hostSkillSource(), fence = HostSkillFence(source: source, config: model.config)
        model.prepare(source); model.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); try await hostSkillWait { model.busy }
        model.userText = "原始笔记 e\u{301}"; #expect(await model.save(sourceIsCurrent: fence.sourceIsCurrent))
        let original = try #require(try await model.repository.load().notes.first)
        let edited = try await model.repository.updateNoteBody(expected: original, text: "用户编辑 👩🏽‍💻")
        model.start(confirmed: true, sourceIsCurrent: fence.sourceIsCurrent); try await hostSkillWait { model.busy }
        #expect(model.readingSkillResult?.fromCache == true)
        model.userText = "重新生成另存"; #expect(await model.save(sourceIsCurrent: fence.sourceIsCurrent))
        let notes = try await model.repository.load().notes
        #expect(notes.count == 2 && notes.contains(edited))
        #expect(notes.first { $0.id == original.id }?.userText.utf8.elementsEqual("用户编辑 👩🏽‍💻".utf8) == true)
        #expect(notes.allSatisfy { $0.result.source.anchor.quote.utf8.elementsEqual(source.anchor.quote.utf8) })
    }
}
