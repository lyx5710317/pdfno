// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

private let chapterFakeKey = "synthetic-reading-ui-credential"
private func chapterInput(_ request: URLRequest) throws -> String {
    let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
    let messages = body["messages"] as! [[String: String]]
    let data = try JSONSerialization.jsonObject(with: Data(messages[1]["content"]!.utf8)) as! [String: String]
    return data["sourceText"]!
}
private func chapterEnvelope(_ quote: String, finish: String = "stop", mismatch: Bool = false) throws -> AIHTTPResponse {
    let data = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "sourceQuote": mismatch ? "Forged quote" : quote, "text": "[Original offline chapter fixture] translated segment"])
    return AIHTTPResponse(status: 200, body: try JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": finish,
        "message": ["role": "assistant", "content": String(decoding: data, as: UTF8.self)]]]]))
}
private actor ChapterTransport: AIHTTPTransport {
    private(set) var requests: [URLRequest] = []
    let failAt: Int?; let finish: String; let mismatch: Bool
    init(failAt: Int? = nil, finish: String = "stop", mismatch: Bool = false) { self.failAt = failAt; self.finish = finish; self.mismatch = mismatch }
    func send(_ request: URLRequest) throws -> AIHTTPResponse {
        requests.append(request)
        if requests.count == failAt { return AIHTTPResponse(status: 402, body: Data("unsafe-original-error".utf8)) }
        return try chapterEnvelope(chapterInput(request), finish: finish, mismatch: mismatch)
    }
}
private actor ChapterDeferred: AIHTTPTransport {
    private var pending: CheckedContinuation<AIHTTPResponse, Error>?
    private var quote = ""
    private(set) var count = 0
    let waitAt: Int
    init(waitAt: Int = 1) { self.waitAt = waitAt }
    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        count += 1; quote = try chapterInput(request)
        if count != waitAt { return try chapterEnvelope(quote) }
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func started() -> Bool { pending != nil }
    func finish() throws { pending?.resume(returning: try chapterEnvelope(quote)); pending = nil }
}
@MainActor private final class ChapterCurrentScope { var valid = true }
struct EPUBChapterTranslationTests {
    private func snapshot(_ text: String, count: Int? = nil, omitted: Bool = false) -> EPUBChapterTextSnapshot {
        EPUBChapterTextSnapshot(bookID: UUID(), readerSessionID: UUID(), documentVersion: 2, editionID: UUID(),
            fileSHA256: String(repeating: "a", count: 64), resourceHref: "OEBPS/chapter.xhtml", spineIndex: 0, chapterCount: 2,
            utf16Count: count ?? text.utf16.count, text: omitted ? nil : text, vertical: true)
    }
    @MainActor private func settle(_ model: EPUBChapterTranslationModel) async throws {
        let deadline = Date().addingTimeInterval(5)
        while model.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(!model.busy)
        // The async cleanup releases batch ownership after the visible terminal state.
        try await Task.sleep(for: .milliseconds(20))
    }
    private func wait(_ transport: ChapterDeferred) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !(await transport.started()) && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(await transport.started())
    }
    @Test func fullSpinePlanPreservesWhitespaceScalarsGraphemesAndNativeAnchorContext() throws {
        let text = "  Original heading\n" + String(repeating: "🌸 cafe\u{301} 家族👨‍👩‍👧‍👦\n", count: 80) + " final line  "
        let original = snapshot(text), plan = try EPUBChapterTranslationPlan(snapshot: original)
        #expect(plan.sources.count > 1 && plan.sources.count <= 6)
        #expect(plan.sources.map { $0.anchor.quote }.joined().unicodeScalars.elementsEqual(text.unicodeScalars))
        #expect(plan.maxOutputTokens == plan.sources.count * 1024 && plan.maxDurationSeconds == plan.sources.count * 30)
        var offset = 0
        for source in plan.sources {
            guard case .epubChapter(let anchor) = source.anchor else { Issue.record("Expected EPUB chapter anchor"); return }
            #expect(source.isValid && anchor.start == offset && anchor.quote.utf16.count <= 500 && anchor.vertical)
            #expect(anchor.prefix.utf16.count <= 64 && anchor.suffix.utf16.count <= 64)
            #expect(anchor.resourceHref == original.resourceHref && source.documentVersion == 2)
            offset = anchor.end
        }
        #expect(offset == original.utf16Count && original.scopeLabel.contains("0–"))
        #expect(try EPUBChapterTranslationPlan(snapshot: snapshot(String(repeating: "a", count: 3000))).sources.count == 6)
    }
    @Test func emptyOversizedOmittedMalformedAndHugeGraphemeRefuseCompletePlan() throws {
        #expect(throws: EPUBChapterTranslationFailure.noText) { try EPUBChapterTranslationPlan(snapshot: snapshot(" \n")) }
        #expect(throws: EPUBChapterTranslationFailure.chapterLimit) { try EPUBChapterTranslationPlan(snapshot: snapshot("", count: 3001, omitted: true)) }
        #expect(throws: EPUBChapterTranslationFailure.invalidSource) { try EPUBChapterTranslationPlan(snapshot: snapshot("tiny excerpt", count: 3000)) }
        #expect(throws: EPUBChapterTranslationFailure.invalidSource) { try EPUBChapterTranslationPlan(snapshot: snapshot("", count: 3, omitted: true)) }
        #expect(throws: EPUBChapterTranslationFailure.segmentLimit) { try EPUBChapterTranslationPlan(snapshot: snapshot("e" + String(repeating: "\u{301}", count: 501))) }
        let malformed = EPUBChapterTextSnapshot(bookID: UUID(), readerSessionID: UUID(), documentVersion: 0, editionID: UUID(),
            fileSHA256: String(repeating: "a", count: 64), resourceHref: "../unsafe.xhtml", spineIndex: 3, chapterCount: 2, utf16Count: 1, text: "x", vertical: false)
        #expect(throws: EPUBChapterTranslationFailure.invalidSource) { try EPUBChapterTranslationPlan(snapshot: malformed) }
    }
    @Test @MainActor func consentAndFixedScopePrecedeAnySendAndWireContainsOnlyCompleteTextTask() async throws {
        let transport = ChapterTransport(), model = EPUBChapterTranslationModel(transport: transport, aiSession: AppAISession())
        let original = snapshot(String(repeating: "Original reading garden sentence. ", count: 36))
        model.prepare(original); model.temporarySecret = chapterFakeKey
        model.start(confirmed: false, sourceIsCurrent: { _ in true }); #expect(!model.busy); #expect(await transport.requests.isEmpty)
        model.start(confirmed: true, sourceIsCurrent: { _ in false }); #expect(!model.busy); #expect(await transport.requests.isEmpty)
        model.start(confirmed: true, sourceIsCurrent: { _ in true }); #expect(model.temporarySecret.isEmpty)
        try await settle(model)
        let requests = await transport.requests
        #expect(model.segments.allSatisfy { $0.result != nil } && requests.count == model.plan?.sources.count && model.attemptsUsed == requests.count)
        var sent = ""
        for request in requests {
            #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + chapterFakeKey)
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            #expect(body["max_tokens"] as? Int == 1024 && body["stream"] as? Bool == false)
            #expect(body["thinking"] as? [String: String] == ["type": "disabled"])
            let messages = body["messages"] as! [[String: String]]
            #expect(messages[0]["content"]!.contains("every part") && messages[0]["content"]!.contains("spine document"))
            #expect(!messages[0]["content"]!.contains("three short sentences"))
            let payload = try JSONSerialization.jsonObject(with: Data(messages[1]["content"]!.utf8)) as! [String: String]
            #expect(Set(payload.keys) == Set(["sourceText", "task"]) && payload["task"] == "translate")
            let bodyText = String(decoding: request.httpBody!, as: UTF8.self)
            #expect(!bodyText.contains(chapterFakeKey) && !bodyText.contains(original.bookID.uuidString) && !bodyText.contains(original.resourceHref))
            sent += payload["sourceText"]!
        }
        #expect(sent.unicodeScalars.elementsEqual(original.text!.unicodeScalars))
        model.temporarySecret = chapterFakeKey; model.start(confirmed: true, sourceIsCurrent: { _ in true })
        #expect(await transport.requests.count == requests.count) // No retry on the submitted plan.
    }
    @Test @MainActor func partialFailureRetainsSuccessfulSegmentsDraftAndExplicitNoteWithoutSecret() async throws {
        let transport = ChapterTransport(failAt: 2), model = EPUBChapterTranslationModel(transport: transport, aiSession: AppAISession())
        model.prepare(snapshot(String(repeating: "x", count: 1201))); model.temporarySecret = chapterFakeKey
        model.start(confirmed: true, sourceIsCurrent: { _ in true }); try await settle(model)
        #expect(await transport.requests.count == 2 && model.attemptsUsed == 2)
        #expect(model.segments[0].result != nil && model.segments[1].failure == .quota && model.segments[2].result == nil)
        #expect(model.status.contains("未完成") && !model.error!.contains("unsafe-original-error"))
        model.segments[0].userText = "Original independent user chapter note"
        let result = try #require(model.segments[0].result)
        model.cancel(); model.prepare(snapshot("Original next chapter"))
        #expect(model.retainedBatches.count == 1 && model.retainedBatches[0].segments[0].userText == "Original independent user chapter note")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Chapter-Notes-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let learning = AILearningModel(root: root, transport: transport, aiSession: AppAISession())
        #expect(learning.notes.isEmpty)
        #expect(!(await learning.saveChapterResult(result, userText: "stale", validateSource: { _ in false })))
        #expect(await learning.saveChapterResult(result, userText: model.retainedBatches[0].segments[0].userText, validateSource: { _ in true }))
        #expect(await learning.saveChapterResult(result, userText: "No overwrite", validateSource: { _ in true }))
        let bytes = try Data(contentsOf: root.appendingPathComponent("learning-v1.json"))
        let state = try AILearningRepository.decode(bytes)
        #expect(state.notes.count == 1 && state.notes[0].result == result && state.notes[0].userText == "Original independent user chapter note")
        #expect(!String(decoding: bytes, as: UTF8.self).contains(chapterFakeKey))
        let restarted = AILearningModel(root: root, transport: transport, aiSession: AppAISession()); await restarted.load()
        #expect(restarted.notes == state.notes && !restarted.hasSessionCredential)
        #expect(EPUBChapterTranslationModel(transport: transport, aiSession: AppAISession()).temporarySecret.isEmpty)
    }
    @Test @MainActor func timeoutCancelAndChangedScopeKeepFirstSuccessRejectNoncooperativeLateOutput() async throws {
        for mode in ["cancel", "timeout", "stale", "switch"] {
            let transport = ChapterDeferred(waitAt: 2), scope = ChapterCurrentScope()
            let model = EPUBChapterTranslationModel(transport: transport, timeoutSeconds: mode == "timeout" ? 0.05 : 30, aiSession: AppAISession())
            model.prepare(snapshot(String(repeating: "x", count: 1201))); model.temporarySecret = chapterFakeKey
            model.start(confirmed: true, sourceIsCurrent: { _ in scope.valid }); try await wait(transport)
            try #require(model.segments[0].result != nil)
            if mode == "cancel" { model.cancel() }
            else if mode == "timeout" { try await settle(model) }
            else if mode == "switch" { model.prepare(snapshot("New book and chapter source")) }
            else { scope.valid = false }
            try await transport.finish(); try await settle(model)
            if mode == "switch" {
                #expect(model.retainedBatches.count == 1 && model.retainedBatches[0].segments[0].result != nil)
                #expect(model.segments.allSatisfy { $0.result == nil })
            } else {
                #expect(model.segments[0].result != nil && model.segments.dropFirst().allSatisfy { $0.result == nil })
                #expect(model.error == (mode == "cancel" ? AIFailure.cancelled : mode == "timeout" ? .timeout : .stale).localizedDescription)
            }
            #expect(await transport.count == 2 && model.attemptsUsed == 2 && model.temporarySecret.isEmpty)
        }
    }
    @Test @MainActor func truncationAndForgedQuoteRejectAndNeverAutomaticallyRetry() async throws {
        for mismatch in [false, true] {
            let transport = ChapterTransport(finish: mismatch ? "stop" : "length", mismatch: mismatch)
            let model = EPUBChapterTranslationModel(transport: transport, aiSession: AppAISession())
            model.prepare(snapshot(String(repeating: "x", count: 1001))); model.temporarySecret = chapterFakeKey
            model.start(confirmed: true, sourceIsCurrent: { _ in true }); try await settle(model)
            #expect(await transport.requests.count == 1 && model.segments.allSatisfy { $0.result == nil })
            #expect(model.segments[0].failure == (mismatch ? .output : .truncated))
            model.temporarySecret = chapterFakeKey; model.start(confirmed: true, sourceIsCurrent: { _ in true })
            #expect(await transport.requests.count == 1)
        }
    }
    @Test @MainActor func wholePlanRemainingBudgetAndConcurrentWindowClaimRefuseBeforeFirstSend() async throws {
        let session = AppAISession(), firstTransport = ChapterDeferred(), secondTransport = ChapterTransport()
        let first = EPUBChapterTranslationModel(transport: firstTransport, aiSession: session)
        let second = EPUBChapterTranslationModel(transport: secondTransport, aiSession: session)
        first.prepare(snapshot(String(repeating: "a", count: 1501))); first.temporarySecret = chapterFakeKey
        first.start(confirmed: true, sourceIsCurrent: { _ in true }); try await wait(firstTransport)
        second.prepare(snapshot(String(repeating: "b", count: 1001))); second.temporarySecret = chapterFakeKey
        second.start(confirmed: true, sourceIsCurrent: { _ in true }); try await settle(second)
        #expect(await secondTransport.requests.isEmpty && second.error == EPUBChapterTranslationFailure.budget.localizedDescription)
        try await firstTransport.finish(); try await settle(first)
        #expect(first.attemptsUsed == 4); #expect(await session.chapter.attemptsUsed() == 4)
        let third = EPUBChapterTranslationModel(transport: secondTransport, aiSession: session)
        third.prepare(snapshot(String(repeating: "c", count: 1001))); third.temporarySecret = chapterFakeKey
        third.start(confirmed: true, sourceIsCurrent: { _ in true }); try await settle(third)
        #expect(await secondTransport.requests.isEmpty && third.error == EPUBChapterTranslationFailure.budget.localizedDescription)
        #expect(await session.selection.attemptsUsed() == 0); #expect(await session.page.attemptsUsed() == 0); #expect(await session.probe.attemptsUsed() == 0)
    }
    @Test @MainActor func recreatedChapterModelsKeepSixAttemptProcessCapAndNeverCarryKeys() async throws {
        let session = AppAISession(), transport = ChapterTransport()
        for _ in 0..<9 {
            let model = EPUBChapterTranslationModel(transport: transport, aiSession: session)
            #expect(model.temporarySecret.isEmpty)
            model.prepare(snapshot("Original short chapter")); model.temporarySecret = chapterFakeKey
            model.start(confirmed: true, sourceIsCurrent: { _ in true }); try await settle(model); model.cancel()
        }
        #expect(await transport.requests.count == 6)
        #expect(await session.chapter.attemptsUsed() == 6)
    }
    @Test func chapterPromptAndSelectionCacheStoreRemainTypedAndForgedVersionsReject() async throws {
        let source = try EPUBChapterTranslationPlan(snapshot: snapshot("Original source")).sources[0]
        let config = DeepSeekSelectionPolicy.configuration(), request = AIRequest(source: source, provider: config, kind: .translate)
        #expect(request.promptVersion == EPUBChapterTranslationPolicy.promptVersion)
        guard case .epubChapter(let anchor) = source.anchor else { Issue.record("Chapter anchor missing"); return }
        let selection = AISourceSnapshot(bookID: source.bookID, readerSessionID: source.readerSessionID, documentVersion: source.documentVersion, anchor: .epub(anchor))
        #expect(try AIJobCoordinator.fingerprint(request) != AIJobCoordinator.fingerprint(AIRequest(source: selection, provider: config, kind: .translate)))
        let result = AIResult(request: request, text: "Original offline translation", fromCache: false)
        var state = AILearningState(); state.notes = [AILearningNote(result: result, userText: "")]
        let bytes = try JSONEncoder().encode(state); #expect(try AILearningRepository.decode(bytes).notes.count == 1)
        let forged = String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: EPUBChapterTranslationPolicy.promptVersion, with: DeepSeekSelectionPolicy.promptVersion)
        #expect(throws: AIFailure.store) { try AILearningRepository.decode(Data(forged.utf8)) }
        let secretField = String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":1,\"secret\":\"fake\"")
        #expect(throws: AIFailure.store) { try AILearningRepository.decode(Data(secretField.utf8)) }
        let credentials = SessionCredentialStore(), ref = UUID(), transport = ChapterTransport()
        try await credentials.put(chapterFakeKey, reference: ref)
        let provider = DeepSeekSelectionProvider(transport: transport, credentials: credentials, credentialReference: ref, budget: DeepSeekSelectionBudget(maxAttempts: 6))
        do { _ = try await provider.analyze(request); Issue.record("Unclaimed batch admitted") } catch { #expect(error as? AIFailure == .configuration) }
        #expect(await transport.requests.isEmpty)
    }
    @Test @MainActor func canonicallyEquivalentScalarChangesArchiveRatherThanReuseOldOutput() async throws {
        let transport = ChapterTransport(), model = EPUBChapterTranslationModel(transport: transport, aiSession: AppAISession())
        let old = snapshot("e\u{301}\u{323}")
        let new = EPUBChapterTextSnapshot(bookID: old.bookID, readerSessionID: old.readerSessionID, documentVersion: old.documentVersion,
            editionID: old.editionID, fileSHA256: old.fileSHA256, resourceHref: old.resourceHref, spineIndex: old.spineIndex,
            chapterCount: old.chapterCount, utf16Count: old.utf16Count, text: "e\u{323}\u{301}", vertical: old.vertical)
        #expect(old.text == new.text && !old.text!.unicodeScalars.elementsEqual(new.text!.unicodeScalars))
        model.prepare(old); model.temporarySecret = chapterFakeKey; model.start(confirmed: true, sourceIsCurrent: { _ in true }); try await settle(model)
        model.prepare(new)
        #expect(model.retainedBatches.count == 1 && model.segments.allSatisfy { $0.result == nil })
        #expect(model.plan?.snapshot.text?.unicodeScalars.elementsEqual(new.text!.unicodeScalars) == true)
    }
}
