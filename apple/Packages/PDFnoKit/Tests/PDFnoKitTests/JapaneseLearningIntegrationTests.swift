// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import PDFKit
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

private let japaneseIntegrationKey = "synthetic-japanese-integration-credential"
private func japaneseIntegrationResponse(_ quote: String, invalid: Bool = false) throws -> AIHTTPResponse {
    let first = String(quote.first!), end = first.unicodeScalars.count, suffix = String(quote.dropFirst().prefix(1))
    let data = invalid ? Data("invalid private response".utf8) : try japaneseData(japanesePayload(quote,
        readings: [japaneseReading(first, start: 0, end: end, suffix: suffix, candidates: ["あ"])],
        grammar: [japaneseGrammar(quote, start: 0, end: quote.unicodeScalars.count, prefix: "", suffix: "")]))
    let envelope = try JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": "stop", "message": [
        "role": "assistant", "content": String(decoding: data, as: UTF8.self), "tool_calls": NSNull()]]]])
    return AIHTTPResponse(status: 200, body: envelope)
}
private actor JapaneseIntegrationTransport: AIHTTPTransport {
    private(set) var requests: [URLRequest] = []
    let invalid: Bool
    init(invalid: Bool = false) { self.invalid = invalid }
    func send(_ request: URLRequest) throws -> AIHTTPResponse {
        guard request.value(forHTTPHeaderField: "Authorization") == "Bearer " + japaneseIntegrationKey else { throw AIFailure.credentials }
        requests.append(request)
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        let messages = body["messages"] as! [[String: String]]
        let input = try JSONSerialization.jsonObject(with: Data(messages[1]["content"]!.utf8)) as! [String: String]
        if input["task"] != "japanese-selection-learning" { return AIHTTPResponse(status: 429, body: Data()) }
        return try japaneseIntegrationResponse(input["sourceText"]!, invalid: invalid)
    }
}
private actor JapaneseIntegrationDeferred: AIHTTPTransport {
    private var continuation: CheckedContinuation<AIHTTPResponse, Error>?
    private(set) var calls = 0
    func started() -> Bool { continuation != nil }
    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        calls += 1; return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish(_ quote: String) throws { continuation?.resume(returning: try japaneseIntegrationResponse(quote)); continuation = nil }
}
@Suite(.serialized)
@MainActor
struct JapaneseLearningIntegrationTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Japanese-Integration-" + UUID().uuidString) }
    private func fixture(_ kind: String) throws -> URL { try #require(Bundle.module.url(forResource: "study-sample", withExtension: kind, subdirectory: "Fixtures")) }
    private func selectedPDF(_ library: LibraryModel) async throws -> PDFView {
        await library.load(); await library.importFile(try fixture("pdf"))
        let view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 600)); library.reader.attach(view)
        await Task.yield()
        library.reader.search("window"); library.reader.show(try #require(library.reader.searchMatches.first)); library.reader.captureSelection()
        try #require(library.captureAISource()?.anchor.quote == "window")
        return view // Retain native view while capturing/returning the original selected range.
    }
    private func idle(_ model: JapaneseLearningModel) async throws {
        let deadline = Date().addingTimeInterval(4)
        while model.busy, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(!model.busy)
    }
    @Test func PDFEntryBYOKManualSaveRestartExactReturnAndOldSchemasRemainUntouched() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let session = AppAISession(), transport = JapaneseIntegrationTransport(), library = LibraryModel(root: root, aiSession: session, learningTransport: transport)
        let view = try await selectedPDF(library); defer { view.document = nil }
        #expect(await library.learning.saveConfig(japaneseConfig(mock: false), temporarySecret: japaneseIntegrationKey))
        let source = try #require(library.captureAISource()), anchor: PDFSourceAnchor
        guard case .pdf(let value) = source.anchor else { Issue.record("PDF source required"); return }; anchor = value
        #expect(await library.saveNote(anchor: anchor, text: "Keep original PDF note"))
        let oldResult = AIResult(request: AIRequest(source: source, provider: library.learning.config, kind: .explain), text: "Keep original AI note", fromCache: false)
        try await library.learning.repository.saveNote(AILearningNote(result: oldResult, userText: "Keep original AI user body"))
        let oldPDF = try Data(contentsOf: root.appendingPathComponent("library-v1.json")), oldAI = try Data(contentsOf: root.appendingPathComponent("learning-v1.json"))
        let book = try #require(library.reader.book), original = try await library.repository.readAsset(for: book)
        library.prepareJapaneseLearning(); let model = library.japaneseLearning
        #expect(model.request?.source.anchor.quote == "window" && model.canStart)
        model.start(confirmed: false); #expect(await transport.requests.isEmpty)
        model.userText = " 独立正文\nか\u{3099}👩🏽‍🚀 "; model.start(confirmed: true); try await idle(model)
        let review = try #require(model.review); #expect(review.readings.count == 1 && review.grammar.count == 1)
        #expect(library.japaneseNotes.isEmpty && !FileManager.default.fileExists(atPath: root.appendingPathComponent(JapaneseLearningRepository.filename).path))
        model.readingCorrections[review.readings[0].span.correctionKey] = "ア"
        #expect(await model.save()); let note = try #require(library.japaneseNotes.first)
        #expect(note.userText.utf8.elementsEqual(model.userText.utf8) && note.corrections[0].reading == "ア")
        #expect(try Data(contentsOf: root.appendingPathComponent("library-v1.json")) == oldPDF)
        #expect(try Data(contentsOf: root.appendingPathComponent("learning-v1.json")) == oldAI)
        #expect(try await library.repository.readAsset(for: book) == original)
        let file = try String(contentsOf: root.appendingPathComponent(JapaneseLearningRepository.filename), encoding: .utf8)
        #expect(!file.contains(japaneseIntegrationKey))
        library.prepareJapaneseLearning(); #expect(model.review?.requestID == review.requestID && model.userText == note.userText)
        let restarted = LibraryModel(root: root, aiSession: session, learningTransport: transport)
        await restarted.load(); #expect(!restarted.learning.hasSessionCredential && restarted.japaneseNotes.count == 1)
        await restarted.open(book)
        #expect(await restarted.returnToJapaneseSource(note.review.source))
        #expect(restarted.reader.resolution(of: anchor) == .exact)
        #expect(throws: AIFailure.credentials) { try restarted.learning.japaneseLearningProvider() }
        #expect(await transport.requests.count == 1)
    }
    @Test func factorySharesExistingSelectionCapAndCannotFallbackWithoutCredential() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let session = AppAISession(), transport = JapaneseIntegrationTransport(), learning = AILearningModel(root: root, transport: transport, aiSession: session)
        #expect(throws: AIFailure.unconfigured) { try learning.japaneseLearningProvider() }
        #expect(await learning.saveConfig(japaneseConfig(mock: false), temporarySecret: ""))
        #expect(throws: AIFailure.credentials) { try learning.japaneseLearningProvider() }
        #expect(await transport.requests.isEmpty)
        #expect(await learning.saveConfig(japaneseConfig(mock: false), temporarySecret: japaneseIntegrationKey))
        let source = japaneseSource()
        for _ in 0..<3 {
            let provider = try learning.japaneseLearningProvider()
            _ = try await provider.analyze(JapaneseLearningRequest(source: source, provider: learning.config))
        }
        learning.prepare(source); learning.start(confirmed: true, sourceIsCurrent: { _ in true })
        let deadline = Date().addingTimeInterval(3)
        while learning.busy, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(learning.error == AIFailure.attemptLimit.localizedDescription)
        #expect(await session.selection.attemptsUsed() == 3)
        #expect(await transport.requests.count == 3)
        await learning.clearSessionCredential()
        #expect(throws: AIFailure.credentials) { try learning.japaneseLearningProvider() }
    }
    @Test func nativeSelectionChangeKeyClearAndBookOpenCancelNoncooperativeLateResponses() async throws {
        for action in ["selection", "key", "book", "text"] {
            let root = root(); defer { try? FileManager.default.removeItem(at: root) }
            let session = AppAISession(), transport = JapaneseIntegrationDeferred(), library = LibraryModel(root: root, aiSession: session, learningTransport: transport)
            let view = try await selectedPDF(library); defer { view.document = nil }
            #expect(await library.learning.saveConfig(japaneseConfig(mock: false), temporarySecret: japaneseIntegrationKey))
            library.prepareJapaneseLearning(); let model = library.japaneseLearning, quote = try #require(model.request?.source.anchor.quote)
            model.userText = "Keep cancelled draft"; model.start(confirmed: true)
            let deadline = Date().addingTimeInterval(3)
            while !(await transport.started()), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
            try #require(await transport.started())
            if action == "selection" {
                library.reader.search("small"); library.reader.show(try #require(library.reader.searchMatches.first)); library.reader.captureSelection()
            } else if action == "key" { await library.learning.clearSessionCredential() }
            else if action == "book" { await library.open(try #require(library.reader.book)) }
            else {
                let text = root.appendingPathComponent("original.txt"); try Data("Original isolated text".utf8).write(to: text)
                await library.importFile(text)
            }
            #expect(!model.busy && model.request == nil && model.review == nil)
            try await transport.finish(quote); try await Task.sleep(for: .milliseconds(20))
            #expect(model.review == nil && library.japaneseNotes.isEmpty)
            #expect(await session.selection.attemptsUsed() == 1)
            #expect(!(await model.save()))
        }
    }
    @Test func invalidModelOutputIsReviewableSourceOnlyAndCannotPersist() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let transport = JapaneseIntegrationTransport(invalid: true), library = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: transport)
        let view = try await selectedPDF(library); defer { view.document = nil }
        #expect(await library.learning.saveConfig(japaneseConfig(mock: false), temporarySecret: japaneseIntegrationKey))
        library.prepareJapaneseLearning(); library.japaneseLearning.start(confirmed: true); try await idle(library.japaneseLearning)
        #expect(library.japaneseLearning.review?.status == .unavailable && !library.japaneseLearning.canSave)
        #expect(!(await library.japaneseLearning.save()) && library.japaneseNotes.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(JapaneseLearningRepository.filename).path))
    }
    @Test func actualEPUBCanonicalSelectionRubySaveReturnAndReflowCancel() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let transport = JapaneseIntegrationTransport(), session = AppAISession(), library = LibraryModel(root: root, aiSession: session, learningTransport: transport)
        _ = NSApplication.shared
        await library.load(); await library.importFile(try fixture("epub"))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = library.epub.webView
        defer { library.epub.close(); window.close() }
        let deadline = Date().addingTimeInterval(20)
        while library.epub.busy, Date() < deadline { try await Task.sleep(for: .milliseconds(30)) }
        try #require(library.epub.error == nil && library.epub.progress != nil)
        #expect(await library.epub.command("chapter", index: 1))
        let snapshot = try await library.epub.currentChapterTextSnapshot(), text = try #require(snapshot.text)
        #expect(text.contains("日本語") && !text.contains("にほんご"))
        let range = (text as NSString).range(of: "日本語")
        try #require(range.location != NSNotFound)
        let anchor = EPUBAnchor(editionID: snapshot.editionID, fileSHA256: snapshot.fileSHA256, resourceHref: snapshot.resourceHref,
            spineIndex: snapshot.spineIndex, start: range.location, end: range.location + range.length, quote: "日本語", prefix: "", suffix: "", vertical: snapshot.vertical)
        #expect(await library.epub.command("navigate", anchor: anchor))
        #expect(await library.learning.saveConfig(japaneseConfig(mock: false), temporarySecret: japaneseIntegrationKey))
        library.prepareJapaneseLearning(); let model = library.japaneseLearning
        let captured = try #require(model.request?.source)
        #expect(captured.anchor.quote == "日本語" && captured.bookID == library.epub.book?.id)
        model.userText = "EPUB original independent note"; model.start(confirmed: true); try await idle(model)
        #expect(model.review?.readings.count == 1)
        #expect(await model.save()); let saved = try #require(library.japaneseNotes.first)
        #expect(await library.returnToJapaneseSource(saved.review.source))
        #expect(library.epub.selection?.quote == "日本語")
        library.prepareJapaneseLearning(); model.userText = "Retain same source draft through reflow"
        #expect(await library.epub.command("vertical"))
        #expect(model.request == nil)
        #expect(await library.returnToJapaneseSource(saved.review.source))
        library.prepareJapaneseLearning()
        #expect(model.userText == "Retain same source draft through reflow")
        #expect(!window.isVisible && library.japaneseNotes.count == 1)
    }
    @Test func savedEditionReplacementOrForgedQuoteCannotNavigate() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: JapaneseIntegrationTransport())
        let view = try await selectedPDF(library); defer { view.document = nil }
        let source = try #require(library.captureAISource())
        guard case .pdf(let old) = source.anchor else { return }
        for anchor in [PDFSourceAnchor(editionID: UUID(), fileSHA256: old.fileSHA256, quote: old.quote, regions: old.regions),
            PDFSourceAnchor(editionID: old.editionID, fileSHA256: old.fileSHA256, quote: "forged", regions: old.regions)] {
            let forged = AISourceSnapshot(bookID: source.bookID, readerSessionID: source.readerSessionID, documentVersion: source.documentVersion, anchor: .pdf(anchor))
            #expect(!(await library.returnToJapaneseSource(forged)))
        }
    }
}
#endif
