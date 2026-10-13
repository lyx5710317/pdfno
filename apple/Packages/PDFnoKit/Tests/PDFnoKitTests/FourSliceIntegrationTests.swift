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
        library.learning.cancel(); library.epub.close(); library.comic.close()
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

    private func wait(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(4)
        while !(await condition()), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(await condition())
    }
    private func wire<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(value)
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


}
#endif
