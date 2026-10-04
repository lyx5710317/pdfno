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

private actor JointJapaneseDeferredTransport: AIHTTPTransport {
    private var continuation: CheckedContinuation<AIHTTPResponse, Error>?
    private(set) var calls = 0
    func started() -> Bool { continuation != nil }
    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        calls += 1
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish(_ payload: Data) throws {
        let body = try JSONSerialization.data(withJSONObject: ["choices": [["finish_reason": "stop", "message": [
            "role": "assistant", "content": String(decoding: payload, as: UTF8.self), "tool_calls": NSNull()]]]])
        continuation?.resume(returning: AIHTTPResponse(status: 200, body: body)); continuation = nil
    }
}

/// Joint boundaries: real original containers, native PDF selection and unattached WebKit.
/// Synthetic consented transport only; no user app, actual API, sync or NSWindow.
@Suite(.serialized) @MainActor struct FormatsJapaneseIntegrationTests {
    private func payload() throws -> Data {
        try japaneseData(japanesePayload("window", readings: [japaneseReading("w", start: 0, end: 1, suffix: "in")],
            grammar: [japaneseGrammar("window", start: 0, end: 6, prefix: "", suffix: "")]))
    }
    private func selectPDF(_ library: LibraryModel) async throws -> PDFView {
        await library.load()
        let url = try #require(Bundle.module.url(forResource: "study-sample", withExtension: "pdf", subdirectory: "Fixtures"))
        await library.importFile(url)
        let view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 600)); library.reader.attach(view)
        await Task.yield()
        library.reader.search("window"); library.reader.show(try #require(library.reader.searchMatches.first)); library.reader.captureSelection()
        try #require(library.captureAISource()?.anchor.quote == "window")
        return view
    }
    private func note(_ source: AISourceSnapshot) throws -> JapaneseLearningNote {
        let request = JapaneseLearningRequest(source: source, provider: japaneseConfig(mock: false))
        let review = JapaneseLearningValidator.validate(try payload(), request: request)
        let note = try JapaneseLearningNote(review: review, userText: "Original independent Japanese body か\u{3099}😀", corrections: [])
        try #require(note.isPersistable)
        return note
    }
    private func close(_ library: LibraryModel) {
        library.epub.close(); library.comic.close(); library.docx.deactivate(); library.textFormats.deactivate(); library.ebook.deactivate()
    }
    @Test func everyAddedFormatCancelsJapaneseLateOutputAndPreservesExactSavedPDFSource() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        var inputs: [(String, Data)] = []
        for format in EbookFormat.allCases {
            let url = try #require(Bundle.module.url(forResource: "study-sample", withExtension: format.rawValue, subdirectory: "Fixtures/Ebooks"))
            inputs.append((format.rawValue, try Data(contentsOf: url)))
        }
        inputs += [("xhtml", Data(OriginalWebArchiveFixtures.xhtml.utf8)), ("mhtml", OriginalWebArchiveFixtures.mhtml),
            ("xml", Data(OriginalWebArchiveFixtures.xml.utf8)), ("cbz", try ComicFixture.book()), ("cbt", try CBTFixture.book()),
            ("cb7", try NativeComicFixture.load("original-lzma2.cb7")), ("cbr", try NativeComicFixture.load("original-rar5.cbr"))]
        for (format, bytes) in inputs {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Joint-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let transport = JointJapaneseDeferredTransport(), session = AppAISession()
            let library = LibraryModel(root: root, aiSession: session, learningTransport: transport)
            defer { close(library) }
            let view = try await selectPDF(library); defer { view.document = nil }
            let source = try #require(library.captureAISource()), pdf = try #require(library.reader.book)
            let original = try await library.repository.readAsset(for: pdf)
            let saved = try note(source); try await library.japaneseRepository.saveNote(saved); await library.loadJapaneseLearningNotes()
            let path = root.appendingPathComponent(JapaneseLearningRepository.filename), before = try Data(contentsOf: path)
            #expect(await library.learning.saveConfig(japaneseConfig(mock: false), temporarySecret: "synthetic-joint-offline-only"))
            library.prepareJapaneseLearning(); let model = library.japaneseLearning
            model.userText = "Retain cancelled draft"; model.start(confirmed: true)
            let deadline = Date().addingTimeInterval(3)
            while !(await transport.started()), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
            try #require(await transport.started())
            let input = root.appendingPathComponent("Original joint container." + format); try bytes.write(to: input)
            await library.importFile(input)
            try #require(library.error == nil)
            #expect(library.captureAISource() == nil && !library.isCurrentAISource(source))
            #expect(!library.isCurrentJapaneseScope(source, config: library.learning.config))
            #expect(!model.busy && model.request == nil && model.review == nil)
            try await transport.finish(payload()); try await Task.sleep(for: .milliseconds(20))
            #expect(model.review == nil)
            #expect(!(await model.save()))
            #expect(await transport.calls == 1)
            #expect(await session.selection.attemptsUsed() == 1)
            #expect(library.japaneseNotes.map(\.id) == [saved.id])
            #expect(try Data(contentsOf: path) == before)
            // A saved source cannot navigate a hidden PDF beneath another active reader.
            #expect(!(await library.returnToJapaneseSource(saved.review.source)))
            await library.open(pdf); library.reader.attach(view); await Task.yield()
            #expect(await library.returnToJapaneseSource(saved.review.source))
            library.reader.captureSelection()
            #expect(library.reader.book?.id == pdf.id && library.reader.capturedSelection?.quote == "window")
            #expect(try await library.repository.readAsset(for: pdf) == original)
            #expect(try Data(contentsOf: input) == bytes)
            let restarted = LibraryModel(root: root, aiSession: AppAISession()); defer { close(restarted) }
            await restarted.load()
            #expect(restarted.japaneseNotes == [saved] && !restarted.learning.hasSessionCredential)
            #expect(try Data(contentsOf: path) == before)
        }
    }
    @Test func offlineBooknoPreviewExplicitlyExcludesJapaneseRecordsWithoutReadingOrChangingTheirStore() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Joint-Preview-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession()); defer { close(library) }
        let view = try await selectPDF(library); defer { view.document = nil }
        let source = try #require(library.captureAISource())
        guard case .pdf(let anchor) = source.anchor else { Issue.record("Native PDF source required"); return }
        #expect(await library.saveNote(anchor: anchor, text: "Original supported PDF body"))
        let saved = try note(source); try await library.japaneseRepository.saveNote(saved)
        let path = root.appendingPathComponent(JapaneseLearningRepository.filename), before = try Data(contentsOf: path)
        let repository = BooknoLibraryPreviewRepository(root: root), choices = try await repository.catalogSnapshot().choices
        let material = try await repository.materialize(choices, includeSavedNotes: true, includeCovers: false)
        #expect(material.payloads.count == 2 && material.assets.isEmpty)
        let exported = try #require(material.payloads.compactMap { if case .note(let value) = $0 { return value }; return nil }.first)
        #expect(exported.userText == "Original supported PDF body" && exported.source.anchor == .pdf(anchor))
        #expect(material.notices.contains { $0.contains("日语学习记录尚未适配 Bookno，本次不包含。") })
        #expect(try Data(contentsOf: path) == before)
        #expect(try await library.japaneseRepository.load().notes == [saved])
        // Preview must not acquire a dependency on an intentionally excluded schema.
        try Data("Original malformed excluded store".utf8).write(to: path)
        let excluded = try Data(contentsOf: path)
        let again = try await repository.materialize(choices, includeSavedNotes: true, includeCovers: false)
        #expect(again.payloads == material.payloads && again.notices == material.notices)
        #expect(try Data(contentsOf: path) == excluded)
    }
}
#endif
