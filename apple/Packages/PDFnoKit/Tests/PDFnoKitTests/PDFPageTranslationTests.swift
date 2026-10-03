// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFKit
import Testing
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

private let pageFakeKey = "synthetic-reading-ui-credential"
private func pageEnvelope(quote: String, finish: String = "stop") throws -> Data {
    let payload = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "sourceQuote": quote, "text": "[Original offline page fixture] translated segment"])
    return try JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": finish,
        "message": ["role": "assistant", "content": String(decoding: payload, as: UTF8.self)]]]])
}
private actor PageTransport: AIHTTPTransport {
    private(set) var requests: [URLRequest] = []
    let failAt: Int?
    let finish: String
    init(failAt: Int? = nil, finish: String = "stop") { self.failAt = failAt; self.finish = finish }
    func send(_ request: URLRequest) throws -> AIHTTPResponse {
        requests.append(request)
        if requests.count == failAt { return AIHTTPResponse(status: 402, body: Data("unsafe-synthetic-response".utf8)) }
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = body["messages"] as! [[String: String]]
        let payload = try JSONSerialization.jsonObject(with: Data(messages[1]["content"]!.utf8)) as! [String: String]
        return AIHTTPResponse(status: 200, body: try pageEnvelope(quote: payload["sourceText"]!, finish: finish))
    }
}
private actor PageDeferred: AIHTTPTransport {
    private var pending: CheckedContinuation<AIHTTPResponse, Error>?
    private var quote = ""
    private(set) var count = 0
    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        count += 1
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = body["messages"] as! [[String: String]]
        let payload = try JSONSerialization.jsonObject(with: Data(messages[1]["content"]!.utf8)) as! [String: String]
        quote = payload["sourceText"]!
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func started() -> Bool { pending != nil }
    func finish() throws { pending?.resume(returning: AIHTTPResponse(status: 200, body: try pageEnvelope(quote: quote))); pending = nil }
}
struct PDFPageTranslationTests {
    private func snapshot(_ text: String, page: Int = 0) -> PDFPageTextSnapshot {
        PDFPageTextSnapshot(bookID: UUID(), readerSessionID: UUID(), editionID: UUID(), fileSHA256: String(repeating: "a", count: 64), pageIndex: page, text: text)
    }
    @MainActor private func settle(_ model: PDFPageTranslationModel) async throws {
        let deadline = Date().addingTimeInterval(3)
        while model.busy, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(!model.busy)
    }
    @Test func fullPagePlanPreservesEveryScalarAndGraphemeWithout500UnitTruncation() throws {
        let text = String(repeating: "An original sentence about a garden. ", count: 25) + String(repeating: "🌸 cafe\u{301} 家族👨‍👩‍👧‍👦\n", count: 30)
        let plan = try PDFPageTranslationPlan(snapshot: snapshot(text, page: 4))
        #expect(plan.sources.count > 1 && plan.sources.count <= 6)
        #expect(plan.sources.map { $0.anchor.quote }.joined().unicodeScalars.elementsEqual(text.unicodeScalars))
        #expect(plan.sources.allSatisfy { $0.isValid && $0.anchor.quote.utf16.count <= 500 })
        var offset = 0
        for source in plan.sources {
            guard case .pdfPage(let anchor) = source.anchor else { Issue.record("Expected a physical page anchor"); return }
            #expect(anchor.start == offset && anchor.pageText == text && anchor.pageIndex == 4)
            offset = anchor.end
            #expect(source.anchor.locationLabel.contains("第 5 页"))
        }
        #expect(offset == text.utf16.count && plan.maxOutputTokens == 1024 * plan.sources.count)
        #expect(try PDFPageTranslationPlan(snapshot: snapshot(String(repeating: "a", count: 3000))).sources.count == 6)
    }
    @Test func emptyOversizeExcessSegmentsHugeGraphemeAndForgedOffsetsRefuseBeforeSending() throws {
        #expect(throws: PDFPageTranslationFailure.self) { try PDFPageTranslationPlan(snapshot: snapshot(" \n")) }
        #expect(throws: PDFPageTranslationFailure.self) { try PDFPageTranslationPlan(snapshot: snapshot(String(repeating: "a", count: 3001))) }
        // Preferred sentence boundaries can need seven requests even below the source cap.
        #expect(throws: PDFPageTranslationFailure.self) { try PDFPageTranslationPlan(snapshot: snapshot(String(repeating: String(repeating: "x", count: 259) + " ", count: 10))) }
        #expect(throws: PDFPageTranslationFailure.self) { try PDFPageTranslationPlan(snapshot: snapshot("e" + String(repeating: "\u{301}", count: 501))) }
        let page = snapshot("🌸 cafe\u{301}")
        #expect(!PDFPageTextAnchor(snapshot: page, start: 1, end: 2, quote: "x").isValid)
        #expect(!PDFPageTextAnchor(snapshot: page, start: 0, end: 2, quote: "xx").isValid)
        let decomposed = snapshot("cafe\u{301}")
        #expect(!PDFPageTextAnchor(snapshot: decomposed, start: 0, end: 5, quote: "caféx").isValid)
    }
    @Test @MainActor func actualPDFKitEntirePageSnapshotScanRefusalAndSourceReturnLeaveBytesUnchanged() throws {
        let data = try originalSample(), session = PDFReaderSession()
        let book = BookRecord(title: "Original", fileSHA256: LibraryRepository.digest(data), originalFilename: "original.pdf", pageCount: 2)
        try session.open(data: data, book: book)
        let page = try session.currentPageTextSnapshot(), plan = try PDFPageTranslationPlan(snapshot: page)
        #expect(page.text.unicodeScalars.elementsEqual(try #require(session.document?.page(at: 0)?.string).unicodeScalars))
        #expect(page.text.contains("window") && page.text.contains("1 / 2"))
        guard case .pdfPage(let anchor) = plan.sources[0].anchor else { Issue.record("Expected page anchor"); return }
        session.go(to: 1); #expect(session.navigate(to: anchor) == .exact && session.pageIndex == 0)
        try session.open(data: data, book: book)
        #expect(session.readerSessionID != page.readerSessionID && session.resolution(of: anchor) == .exact)
        #expect(data == (try originalSample()))
        #if DEBUG
        let blank = try #require(OriginalPageTranslationUITestPDF.data(mode: "blank"))
        let scanBook = BookRecord(title: "Original blank", fileSHA256: LibraryRepository.digest(blank), originalFilename: "blank.pdf", pageCount: 1)
        try session.open(data: blank, book: scanBook)
        #expect(throws: PDFPageTranslationFailure.self) { try session.currentPageTextSnapshot() }
        #expect(PDFPageTranslationFailure.noText.localizedDescription.contains("OCR"))
        let multi = try #require(OriginalPageTranslationUITestPDF.data(mode: "multi"))
        let multiBook = BookRecord(title: "Original multi", fileSHA256: LibraryRepository.digest(multi), originalFilename: "multi.pdf", pageCount: 1)
        try session.open(data: multi, book: multiBook)
        let multiPlan = try PDFPageTranslationPlan(snapshot: session.currentPageTextSnapshot())
        #expect(multiPlan.sources.count == 3 && multiPlan.snapshot.text.contains("line 18:"))
        #endif
    }
    @Test @MainActor func explicitWholePlanSendAndManualExistingLearningNoteSaveNeverPersistKey() async throws {
        let transport = PageTransport(), model = PDFPageTranslationModel(transport: transport)
        let page = snapshot(String(repeating: "Original garden sentence. ", count: 48)), plan = try PDFPageTranslationPlan(snapshot: page)
        model.prepare(page); model.temporarySecret = pageFakeKey
        model.start(confirmed: false, sourceIsCurrent: { _ in true })
        #expect(!model.busy); #expect(await transport.requests.isEmpty)
        model.start(confirmed: true, sourceIsCurrent: { _ in false })
        #expect(!model.busy); #expect(await transport.requests.isEmpty)
        model.start(confirmed: true, sourceIsCurrent: { _ in true }); #expect(model.temporarySecret.isEmpty)
        try await settle(model)
        #expect(model.segments.allSatisfy { $0.result != nil } && model.attemptsUsed == plan.sources.count)
        let requests = await transport.requests
        var sent = ""
        for request in requests {
            #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions")
            #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + pageFakeKey)
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            #expect(body["max_tokens"] as? Int == 1024 && body["thinking"] as? [String: String] == ["type": "disabled"])
            let messages = body["messages"] as! [[String: String]]
            #expect(messages[0]["content"]!.contains("every part") && !messages[0]["content"]!.contains("three short sentences"))
            let payload = try JSONSerialization.jsonObject(with: Data(messages[1]["content"]!.utf8)) as! [String: String]
            #expect(Set(payload.keys) == Set(["sourceText", "task"]) && payload["task"] == "translate")
            sent += payload["sourceText"]!
            #expect(!String(decoding: request.httpBody!, as: UTF8.self).contains(pageFakeKey))
        }
        #expect(sent.unicodeScalars.elementsEqual(page.text.unicodeScalars))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Page-Notes-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let learning = AILearningModel(root: root, transport: transport)
        #expect(learning.notes.isEmpty)
        let result = try #require(model.segments.first?.result)
        #expect(result.promptVersion == PDFPageTranslationPolicy.promptVersion)
        #expect(await learning.savePageResult(result, userText: "Original user page note", sourceIsCurrent: { _ in true }))
        #expect(await learning.savePageResult(result, userText: "Do not duplicate", sourceIsCurrent: { _ in true }))
        let restarted = AILearningModel(root: root, transport: transport); await restarted.load()
        #expect(restarted.notes.count == 1 && restarted.notes[0].userText == "Original user page note")
        #expect(restarted.notes[0].result.source == result.source && !restarted.hasSessionCredential)
        let bytes = try Data(contentsOf: root.appendingPathComponent("learning-v1.json"))
        #expect(!String(decoding: bytes, as: UTF8.self).contains(pageFakeKey))
        let restartedPage = PDFPageTranslationModel(transport: transport)
        #expect(restartedPage.temporarySecret.isEmpty)
    }
    @Test @MainActor func canonicallyEquivalentChangedScalarSequenceDoesNotRetainOldPageResults() async throws {
        let transport = PageTransport(), model = PDFPageTranslationModel(transport: transport)
        let old = snapshot("e\u{301}\u{323}")
        let new = PDFPageTextSnapshot(bookID: old.bookID, readerSessionID: old.readerSessionID, editionID: old.editionID,
            fileSHA256: old.fileSHA256, pageIndex: old.pageIndex, text: "e\u{323}\u{301}")
        #expect(old.text == new.text && !old.text.unicodeScalars.elementsEqual(new.text.unicodeScalars))
        model.prepare(old); model.temporarySecret = pageFakeKey
        model.start(confirmed: true, sourceIsCurrent: { _ in true }); try await settle(model)
        #expect(model.segments[0].result != nil)
        model.prepare(new)
        #expect(model.segments.allSatisfy { $0.result == nil })
        #expect(model.plan?.snapshot.text.unicodeScalars.elementsEqual(new.text.unicodeScalars) == true)
        #expect(model.attemptsUsed == 1); #expect(await transport.requests.count == 1)
    }
    @Test @MainActor func failureAndTruncationKeepSuccessfulSegmentsAndStopUnsentRemainder() async throws {
        let page = snapshot(String(repeating: "Original sentence. ", count: 70))
        let transport = PageTransport(failAt: 2), model = PDFPageTranslationModel(transport: transport)
        model.prepare(page); model.temporarySecret = pageFakeKey; model.start(confirmed: true, sourceIsCurrent: { _ in true })
        try await settle(model)
        #expect(await transport.requests.count == 2 && model.attemptsUsed == 2)
        #expect(model.segments[0].result != nil && model.segments[1].failure == .quota && model.segments[2].result == nil)
        #expect(model.status.contains("未完成") && !model.error!.contains("unsafe-synthetic-response"))
        model.temporarySecret = pageFakeKey; model.start(confirmed: true, sourceIsCurrent: { _ in true })
        #expect(await transport.requests.count == 2) // The UI and model prohibit re-sending completed segments.
        let truncatedTransport = PageTransport(finish: "length"), truncated = PDFPageTranslationModel(transport: truncatedTransport)
        truncated.prepare(page); truncated.temporarySecret = pageFakeKey; truncated.start(confirmed: true, sourceIsCurrent: { _ in true })
        try await settle(truncated)
        #expect(await truncatedTransport.requests.count == 1 && truncated.segments[0].failure == .truncated)
        #expect(truncated.segments.allSatisfy { $0.result == nil })
    }
    @Test @MainActor func remainingBudgetRefusesWholePlanAndCloseDoesNotResetAttempts() async throws {
        // Each explicit attempt fails before success; no automatic loop is present in the model.
        let transport = PageTransport(finish: "length"), model = PDFPageTranslationModel(transport: transport)
        model.prepare(snapshot("Original small text."))
        for _ in 0..<5 {
            model.temporarySecret = pageFakeKey; model.start(confirmed: true, sourceIsCurrent: { _ in true }); try await settle(model); model.cancel()
        }
        #expect(model.attemptsUsed == 5)
        model.prepare(snapshot(String(repeating: "a", count: 501))); model.temporarySecret = pageFakeKey
        model.start(confirmed: true, sourceIsCurrent: { _ in true })
        #expect(!model.busy && model.error == PDFPageTranslationFailure.budget.localizedDescription)
        #expect(await transport.requests.count == 5)
        model.prepare(snapshot(String(repeating: "a", count: 3001))); model.temporarySecret = pageFakeKey
        model.start(confirmed: true, sourceIsCurrent: { _ in true })
        #expect(model.plan == nil && model.preparationError == PDFPageTranslationFailure.pageLimit.localizedDescription)
        #expect(await transport.requests.count == 5)
    }
    @Test @MainActor func cancellationTimeoutAndChangedSourceDiscardUncooperativeLateResponse() async throws {
        for mode in ["cancel", "timeout", "stale"] {
            let transport = PageDeferred(), model = PDFPageTranslationModel(transport: transport, timeoutSeconds: mode == "timeout" ? 0.05 : 30)
            model.prepare(snapshot(String(repeating: "x", count: 1001))); model.temporarySecret = pageFakeKey
            var current = true
            model.start(confirmed: true, sourceIsCurrent: { _ in current })
            let deadline = Date().addingTimeInterval(3)
            while !(await transport.started()), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
            #expect(await transport.started())
            if mode == "cancel" { model.cancel() }
            else if mode == "timeout" { try await settle(model) }
            else { current = false }
            try await transport.finish(); try await settle(model); try await Task.sleep(for: .milliseconds(20))
            #expect(model.segments.allSatisfy { $0.result == nil } && model.temporarySecret.isEmpty)
            #expect(await transport.count == 1 && model.attemptsUsed == 1)
            #expect(model.error == (mode == "cancel" ? AIFailure.cancelled : mode == "timeout" ? .timeout : .stale).localizedDescription)
        }
    }
    @Test func pagePromptAndSelectionFingerprintRemainSeparateAndStoreRejectsForgedPageVersion() async throws {
        let page = snapshot("Original text"), source = try PDFPageTranslationPlan(snapshot: page).sources[0]
        let request = AIRequest(source: source, provider: DeepSeekSelectionPolicy.configuration(), kind: .translate)
        #expect(request.promptVersion == PDFPageTranslationPolicy.promptVersion)
        let result = AIResult(request: request, text: "Original synthetic translation", fromCache: false)
        var state = AILearningState(); state.notes = [AILearningNote(result: result, userText: "")]
        let bytes = try JSONEncoder().encode(state)
        #expect(try AILearningRepository.decode(bytes).notes.count == 1)
        let forged = String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: PDFPageTranslationPolicy.promptVersion, with: DeepSeekSelectionPolicy.promptVersion)
        #expect(throws: AIFailure.store) { try AILearningRepository.decode(Data(forged.utf8)) }
        let malformed = String(decoding: bytes, as: UTF8.self).replacingOccurrences(of: "pdfkit-page-text-1", with: "pdfkit-selection-1")
        #expect(throws: AIFailure.store) { try AILearningRepository.decode(Data(malformed.utf8)) }
    }
}
