// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import PDFKit
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders
@testable import PDFnoUI

/// Intercepts every send; deliberately noncooperative cancellation tests the host fence.
private actor FourSliceTransport: AIHTTPTransport {
    let deferred: Bool
    private var pending: CheckedContinuation<AIHTTPResponse, Error>?
    private var pendingQuote = ""
    private(set) var calls = 0
    private(set) var receivers: [URL] = []
    init(deferred: Bool = false) { self.deferred = deferred }
    func started() -> Bool { pending != nil }
    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        let data = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let messages = try #require(body["messages"] as? [[String: String]])
        let message = try #require(messages.last?["content"])
        let payload = try #require(try JSONSerialization.jsonObject(with: Data(message.utf8)) as? [String: String])
        let quote = try #require(payload["sourceText"])
        calls += 1; receivers.append(try #require(request.url))
        if deferred {
            pendingQuote = quote
            return try await withCheckedThrowingContinuation { pending = $0 }
        }
        return try reply(quote)
    }
    func finish() throws { pending?.resume(returning: try reply(pendingQuote)); pending = nil }
    private func reply(_ quote: String) throws -> AIHTTPResponse {
        let content = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "sourceQuote": quote, "text": "Original intercepted answer 日本語"])
        return AIHTTPResponse(status: 200, body: try JSONSerialization.data(withJSONObject: ["choices": [[
            "finish_reason": "stop", "message": ["role": "assistant", "content": String(decoding: content, as: UTF8.self), "tool_calls": NSNull()]]]]))
    }
}

@Suite(.serialized) @MainActor struct FourSliceIntegrationTests {
    private func root() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Four-Slice-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
    private func close(_ library: LibraryModel) {
        library.invalidateBYOKSelection(); library.epub.close(); library.comic.close()
        library.docx.deactivate(); library.textFormats.deactivate(); library.ebook.deactivate()
    }
    private func selectPDF(_ library: LibraryModel) async throws -> PDFView {
        NSApplication.shared.setActivationPolicy(.prohibited)
        await library.load()
        let url = try #require(Bundle.module.url(forResource: "study-sample", withExtension: "pdf", subdirectory: "Fixtures"))
        await library.importFile(url)
        let view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 600)); library.reader.attach(view)
        await Task.yield()
        library.reader.search("window"); library.reader.show(try #require(library.reader.searchMatches.first)); library.reader.captureSelection()
        try #require(library.captureAISource()?.anchor.quote == "window")
        return view
    }
    private func configure(_ library: LibraryModel) async throws {
        var config = AIProviderConfig()
        config.mode = .openAICompatible; config.label = "Original offline recipient"
        config.endpoint = "https://four-slice.example/v1"; config.model = "original-offline-model"
        library.byok.draft = config
        library.byok.temporarySecret = "synthetic-four-slice-only"
        try #require(await library.byok.apply())
        await library.prepareBYOKSelection()
    }
    private func wait(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(4)
        while !(await condition()), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(await condition())
    }
    private func wire<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(value)
    }

    @Test func libraryRetainsRecordAdapterAndPanelChangesKeepPDFSourceAndBothDrafts() async throws {
        let directory = try root(); defer { try? FileManager.default.removeItem(at: directory) }
        let library = LibraryModel(root: directory, aiSession: AppAISession(), learningTransport: FourSliceTransport())
        defer { close(library) }
        let view = try await selectPDF(library); defer { view.document = nil }
        let source = try #require(library.captureAISource()), document = try #require(library.reader.document)
        guard case .pdf(let anchor) = source.anchor else { Issue.record("PDF source required"); return }
        #expect(await library.saveNote(anchor: anchor, text: "Original saved body"))
        let note = try #require(library.notes.first), snapshot = NoteBodySnapshot.pdf(note)
        library.noteEditing.begin(snapshot); library.noteEditing.setText("Unsaved old-body 日本語", for: snapshot)
        let firstAdapter = library.recordEditing
        #expect(firstAdapter === library.recordEditing)
        try await configure(library)
        library.byokUserText = "Unsaved BYOK body cafe\u{301}"
        var panels = PDFnoReaderPanels()
        for width in [CGFloat(1100), 880, 440, 1100] {
            panels.toggle(.navigation, width: width); panels.toggle(.notes, width: width)
            #expect(library.reader.document === document && library.reader.readerSessionID == source.readerSessionID)
            #expect(library.isCurrentBYOKSource(source) && library.byok.preview?.request.source == source)
            #expect(library.noteEditing.drafts[snapshot.key]?.text == "Unsaved old-body 日本語")
            #expect(library.byokUserText == "Unsaved BYOK body cafe\u{301}")
        }
        let restarted = LibraryModel(root: directory, aiSession: AppAISession()); defer { close(restarted) }
        #expect(restarted.noteEditing.drafts[snapshot.key]?.text == "Unsaved old-body 日本語")
        #expect(try await library.repository.load().notes.first?.userText == "Original saved body")
    }

    @Test func wiredBYOKManualSaveSharesBudgetAndPreservesDefaultLearningChainsAndOriginalResult() async throws {
        let directory = try root(); defer { try? FileManager.default.removeItem(at: directory) }
        let app = AppAISession(), transport = FourSliceTransport()
        let library = LibraryModel(root: directory, aiSession: app, learningTransport: transport); defer { close(library) }
        let view = try await selectPDF(library); defer { view.document = nil }
        let defaultConfig = library.learning.config
        try await configure(library)
        let preview = try #require(library.byok.preview)
        #expect(preview.receiverURL.absoluteString == "https://four-slice.example/v1/chat/completions")
        #expect(preview.sourceText == "window")
        library.byok.start(confirmed: true, sourceIsCurrent: library.isCurrentBYOKSource)
        try await wait { !library.byok.busy }
        let result = try #require(library.byok.result)
        #expect(library.learning.config == defaultConfig && library.learning.result == nil)
        #expect(await app.selection.attemptsUsed() == 1)
        #expect(await app.page.attemptsUsed() == 0)
        #expect(await app.chapter.attemptsUsed() == 0)
        #expect(library.japaneseLearning.request == nil && library.pageTranslation.plan == nil && library.chapterTranslation.plan == nil)
        library.byokUserText = "BYOK saved original body"
        #expect(await library.saveBYOKResult())
        let saved = try #require(library.learning.notes.first), beforeResult = try wire(saved.result)
        library.noteEditing.begin(.learning(saved)); library.noteEditing.setText("Edited saved body 🌸", for: .learning(saved))
        await library.saveEditedNote(.learning(saved))
        let edited = try #require(library.learning.notes.first)
        #expect(edited.userText == "Edited saved body 🌸")
        #expect(try wire(edited.result) == beforeResult)
        #expect(try wire(edited.result) == wire(result))
        let search = SavedRecordSearchModel(root: directory); search.updateQuery("Edited saved body")
        await search.waitForSearch()
        #expect(search.response.legacy.totalCount == 1 && search.response.records.totalCount == 0)
        #expect(!String(decoding: try Data(contentsOf: directory.appendingPathComponent("learning-v1.json")), as: UTF8.self).contains("synthetic-four-slice-only"))
    }

    @Test func switchToTextCancelsLateBYOKWithoutResettingBudgetOrOldDraftAndKeyNeverMovesDomains() async throws {
        let directory = try root(); defer { try? FileManager.default.removeItem(at: directory) }
        let transport = FourSliceTransport(deferred: true), app = AppAISession()
        let library = LibraryModel(root: directory, aiSession: app, learningTransport: transport); defer { close(library) }
        let view = try await selectPDF(library); defer { view.document = nil }
        let originalConfig = library.learning.config
        try await configure(library); let source = try #require(library.byokSource)
        library.byokUserText = "Retain late-request user draft"
        library.byok.start(confirmed: true, sourceIsCurrent: library.isCurrentBYOKSource)
        try await wait { await transport.started() }
        let input = directory.appendingPathComponent("Original switch.txt")
        try Data("Original finite text".utf8).write(to: input); await library.importFile(input)
        #expect(library.textFormats.isActive && !library.isCurrentBYOKSource(source))
        #expect(!library.byok.busy && library.byok.preview == nil)
        try await transport.finish(); try await Task.sleep(for: .milliseconds(30))
        #expect(library.byok.result == nil && library.learning.notes.isEmpty)
        #expect(!(await library.saveBYOKResult()))
        #expect(library.byokUserText == "Retain late-request user draft" && library.learning.config == originalConfig)
        library.byok.draft.endpoint = "https://another-four-slice.example/v1"
        await library.byok.load()
        #expect(!library.byok.hasSessionCredential)
        #expect(await app.selection.attemptsUsed() == 1)
        #expect(await transport.calls == 1)
        #expect(await transport.receivers.map(\.host) == ["four-slice.example"])
    }

    @Test func savedTextAndEbookEditingSearchAndExactReturnUseOneLibraryAdapterAcrossSwitches() async throws {
        let directory = try root(); defer { try? FileManager.default.removeItem(at: directory) }
        let library = LibraryModel(root: directory, aiSession: AppAISession()); defer { close(library) }
        await library.load()
        let input = directory.appendingPathComponent("Original parity.txt")
        let bytes = Data("Original text body cafe\u{301} 日本語\n".utf8); try bytes.write(to: input)
        await library.importFile(input)
        let textBook = try #require(library.textFormats.reader.book), textDoc = try #require(library.textFormats.reader.document)
        let textAnchor = try #require(textDoc.anchor(book: textBook, start: 0, end: 8))
        #expect(await library.textFormats.saveNote(textAnchor, text: "Original committed text"))
        let note = try #require(library.textFormats.notes.first), snapshot = RecordBodySnapshot.text(note)
        let editor = library.recordEditing.editor
        editor.begin(snapshot); editor.setText("Uncommitted unique marker", for: snapshot)
        let search = SavedRecordSearchModel(root: directory); search.observeChanges(in: library)
        defer { search.stopObservingChanges(); search.cancel() }
        search.updateQuery("Uncommitted unique marker"); await search.waitForSearch()
        #expect(search.response.totalCount == 0)
        await library.openEbookSample(.mobi)
        let ebookSession = library.ebook.reader.readerSessionID
        #expect(editor.drafts[snapshot.key]?.text == "Uncommitted unique marker")
        await library.recordEditing.save(snapshot); await search.waitForSearch()
        #expect(library.ebook.isActive && library.ebook.reader.readerSessionID == ebookSession)
        let hit = try #require(search.response.records.hits.first)
        #expect(search.response.totalCount == 1 && hit.entry.quote == textAnchor.quote)
        #expect(await library.openRecordSearchTarget(hit.entry.target))
        #expect(library.textFormats.isActive && library.textFormats.reader.book?.id == textBook.id)
        #expect(library.textFormats.reader.document?.resolves(textAnchor) == true)
        #expect(try Data(contentsOf: input) == bytes)
        let restarted = LibraryModel(root: directory, aiSession: AppAISession()); defer { close(restarted) }
        await restarted.load()
        #expect(restarted.textFormats.notes.first?.userText == "Uncommitted unique marker")
        #expect(restarted.recordEditing.editor.drafts.isEmpty)
    }

    @Test func wiredJapaneseBodyEditKeepsGeneratedReviewCorrectionsAndOldAIBodyIndependent() async throws {
        let directory = try root(); defer { try? FileManager.default.removeItem(at: directory) }
        let library = LibraryModel(root: directory, aiSession: AppAISession(), learningTransport: FourSliceTransport()); defer { close(library) }
        let view = try await selectPDF(library); defer { view.document = nil }
        let source = try #require(library.captureAISource())
        let request = JapaneseLearningRequest(source: source, provider: japaneseConfig())
        let review = JapaneseLearningValidator.validate(try japaneseData(japanesePayload("window",
            readings: [japaneseReading("w", start: 0, end: 1, suffix: "in")],
            grammar: [japaneseGrammar("window", start: 0, end: 6, prefix: "", suffix: "")])), request: request)
        let saved = try JapaneseLearningNote(review: review, userText: "Original Japanese body",
            corrections: [JapaneseReadingCorrection(span: review.readings[0].span, reading: "ワ")])
        try await library.japaneseRepository.saveNote(saved); await library.loadJapaneseLearningNotes()
        let before = try wire(saved.review), snapshot = RecordBodySnapshot.japanese(saved)
        library.learning.userText = "Old AI generation draft"
        library.recordEditing.editor.begin(snapshot); library.recordEditing.editor.setText("Edited Japanese body cafe\u{301}", for: snapshot)
        await library.recordEditing.save(snapshot)
        let updated = try #require(library.japaneseNotes.first)
        #expect(try wire(updated.review) == before && updated.corrections == saved.corrections)
        #expect(updated.userText == "Edited Japanese body cafe\u{301}" && library.learning.userText == "Old AI generation draft")
        let search = SavedRecordSearchModel(root: directory); search.updateQuery("Edited Japanese body CAFÉ"); await search.waitForSearch()
        let hit = try #require(search.response.records.hits.first)
        #expect(hit.entry.quote == "window" && hit.entry.generatedText != "")
        #expect(await library.openRecordSearchTarget(hit.entry.target))
        library.reader.captureSelection()
        #expect(library.reader.capturedSelection?.quote == "window")
    }

    @Test func readingPDFExportKeepsActiveSelectionDraftAndOriginalWhileOldTXTHTMLStillWorkAndExistingPDFRefuses() async throws {
        let directory = try root(); defer { try? FileManager.default.removeItem(at: directory) }
        let library = LibraryModel(root: directory, aiSession: AppAISession(), learningTransport: FourSliceTransport()); defer { close(library) }
        let view = try await selectPDF(library); defer { view.document = nil }
        let source = try #require(library.captureAISource()), pdf = try #require(library.reader.book)
        let originalPDF = try await library.repository.readAsset(for: pdf)
        try await configure(library); library.byokUserText = "Retain during conversion"
        let input = directory.appendingPathComponent("Original.docx")
        let fixture = try #require(Bundle.module.url(forResource: "study-sample", withExtension: "docx", subdirectory: "Fixtures/DOCX"))
        let original = try Data(contentsOf: fixture); try original.write(to: input)
        let output = directory.appendingPathComponent("Original-reading.pdf")
        let service = DOCXReadingPDFService(), result = try await service.convert(source: input, destination: output)
        #expect(result.readingPDFReport != nil)
        #expect((PDFDocument(url: output)?.pageCount ?? 0) > 0)
        let installed = try Data(contentsOf: output)
        await #expect(throws: ConversionError.destinationExists) { try await service.convert(source: input, destination: output) }
        #expect(try Data(contentsOf: output) == installed && Data(contentsOf: input) == original)
        #expect(library.isCurrentBYOKSource(source) && library.byokUserText == "Retain during conversion")
        #expect(library.reader.book?.id == pdf.id && library.reader.capturedSelection?.quote == "window")
        #expect(try await library.repository.readAsset(for: pdf) == originalPDF)
        for format in [ConversionFormat.plainText, .html] {
            let url = directory.appendingPathComponent("Original-copy." + format.fileExtension)
            let plain = try await DocumentConversionService().convert(ConversionRequest(source: input, destination: url, output: format))
            #expect(plain.readingPDFReport == nil && plain.byteCount > 0)
        }
    }
}
#endif
