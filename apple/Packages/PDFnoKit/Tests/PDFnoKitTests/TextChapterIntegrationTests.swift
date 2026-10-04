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

/// Real native owners/stores/bridges, hidden test-host windows and original
/// fixtures only. No application launch, real key or model transport.
@Suite(.serialized) @MainActor
struct TextChapterIntegrationTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Text-Chapter-" + UUID().uuidString) }
    private func publication() throws -> Data {
        try ConversionFixture.zip([
            ("mimetype", Data("application/epub+zip".utf8)),
            ("META-INF/container.xml", Data("<container xmlns='urn:oasis:names:tc:opendocument:xmlns:container' version='1.0'><rootfiles><rootfile full-path='book.opf' media-type='application/oebps-package+xml'/></rootfiles></container>".utf8)),
            ("book.opf", Data("<package xmlns='http://www.idpf.org/2007/opf' version='3.0' unique-identifier='id'><metadata xmlns:dc='http://purl.org/dc/elements/1.1/'><dc:identifier id='id'>urn:uuid:original-integrated</dc:identifier><dc:title>Original integrated</dc:title><dc:language>ja</dc:language></metadata><manifest><item id='nav' href='nav.xhtml' media-type='application/xhtml+xml' properties='nav'/><item id='one' href='one.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='one'/></spine></package>".utf8)),
            ("nav.xhtml", Data("<html xmlns='http://www.w3.org/1999/xhtml' xmlns:epub='http://www.idpf.org/2007/ops'><head><title>Original contents</title></head><body><nav epub:type='toc'><ol><li><a href='one.xhtml'>Original document</a></li></ol></nav></body></html>".utf8)),
            ("one.xhtml", Data("<html xmlns='http://www.w3.org/1999/xhtml'><head><title>Original integrated</title></head><body><p>window 日本語 🌸 café</p><p>Original complete spine sentence.</p></body></html>".utf8))
        ], deflated: false)
    }
    private func window() -> NSWindow {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        return window
    }
    private func waitForEPUB(_ library: LibraryModel, window: NSWindow) async throws {
        let deadline = Date().addingTimeInterval(20)
        while library.epub.busy && Date() < deadline {
            window.contentView = library.epub.webView
            try await Task.sleep(for: .milliseconds(40))
        }
        window.contentView = library.epub.webView
        try #require(library.epub.error == nil && library.epub.progress != nil && !library.epub.busy)
        #expect(!window.isVisible && !window.isKeyWindow)
    }
    private func textFile(_ root: URL) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appendingPathComponent("Original integrated.TXT")
        try Data("Chapter 1\nwindow original text 🌸 café\nChapter 2\nLast original text line".utf8).write(to: file)
        return file
    }
    private func search(_ root: URL, library: LibraryModel) -> LibrarySearchModel {
        let repository = LibrarySearchRepository(root: root)
        let model = LibrarySearchModel(root: root, debounce: .zero, search: { try await repository.search($0) })
        model.observeChanges(in: library); return model
    }

    @Test func chapterLearningBodyEditRefreshesSearchAndReturnsExactSourceFromTextReaderAfterRestart() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession()), bytes = try publication(), window = window()
        defer { library.epub.close(); library.textFormats.deactivate(); window.close() }
        await library.load()
        let book = try await library.epubRepository.importBook(bytes, filename: "Original integrated.epub")
        await library.openEPUB(book); try await waitForEPUB(library, window: window)
        let source = try #require(await EPUBChapterTranslationPlan(snapshot: library.epub.currentChapterTextSnapshot()).sources.first)
        let result = AIResult(request: AIRequest(source: source, provider: DeepSeekSelectionPolicy.configuration(), kind: .translate), text: "Original immutable chapter output", fromCache: false)
        let search = search(root, library: library)
        search.updateQuery("chapteroldunique"); await search.waitForSearch(); #expect(search.response.totalCount == 0)
        #expect(await library.learning.saveChapterResult(result, userText: "chapteroldunique", validateSource: library.validateChapterSource))
        await search.waitForSearch(); #expect(search.response.totalCount == 1)
        let saved = try #require(library.learning.notes.first), snapshot = NoteBodySnapshot.learning(saved)
        library.noteEditing.begin(snapshot); library.noteEditing.setText("chapterprivatedraftunique", for: snapshot)
        search.updateQuery("chapterprivatedraftunique"); await search.waitForSearch(); #expect(search.response.totalCount == 0)
        search.updateQuery("chapteroldunique"); await search.waitForSearch(); #expect(search.response.totalCount == 1)
        library.noteEditing.setText("chapterreplacementunique 日本語🌸 café", for: snapshot)
        await library.saveEditedNote(snapshot); await search.waitForSearch(); #expect(search.response.totalCount == 0)
        search.updateQuery("chapterreplacementunique"); await search.waitForSearch()
        let hit = try #require(search.response.groups.first?.hits.first)
        #expect(hit.entry.target.noteID == saved.id && hit.entry.target.book.format == .epub && hit.entry.quote == source.anchor.quote)
        #expect(library.learning.notes.first?.result == result && library.noteEditing.drafts[snapshot.key] == nil)
        let file = try textFile(root), textBytes = try Data(contentsOf: file)
        await library.importTextFormat(file)
        #expect(library.textFormats.isActive && library.currentAIBookID == nil)
        #expect(!(await library.returnToAISource(source)))
        let textBook = try #require(library.textFormats.reader.book)
        // Mount the actual new WebKit view while the same route used by search
        // opens it, matching the asynchronous native workspace update.
        let open = Task { await library.openSearchTarget(hit.entry.target) }
        let deadline = Date().addingTimeInterval(20)
        while !open.isCancelled && Date() < deadline {
            if library.epub.book?.id == book.id, let view = library.epub.webView {
                window.contentView = view; break
            }
            try await Task.sleep(for: .milliseconds(40))
        }
        #expect(await open.value)
        try await waitForEPUB(library, window: window)
        #expect(!library.textFormats.isActive && library.readingEPUB)
        #expect(await library.validateChapterSource(source))
        #expect(try await library.epubRepository.read(book) == bytes)
        #expect(try await library.textFormats.repository.read(textBook) == textBytes)
        let restarted = LibraryModel(root: root, aiSession: AppAISession()); await restarted.load()
        defer { restarted.epub.close(); restarted.textFormats.deactivate() }
        #expect(restarted.learning.notes.first?.id == saved.id && restarted.learning.notes.first?.result == result)
        #expect(restarted.learning.notes.first?.userText == "chapterreplacementunique 日本語🌸 café")
        let reopenedHit = try #require(await LibrarySearchRepository(root: root).search("chapterreplacementunique").groups.first?.hits.first)
        #expect(reopenedHit.entry.target == hit.entry.target)
        let reopened = Task { await restarted.openSearchTarget(reopenedHit.entry.target) }
        let reopenedDeadline = Date().addingTimeInterval(20)
        while Date() < reopenedDeadline {
            if restarted.epub.book?.id == book.id, let view = restarted.epub.webView {
                window.contentView = view; break
            }
            try await Task.sleep(for: .milliseconds(40))
        }
        #expect(await reopened.value)
        #expect(await restarted.validateChapterSource(source))
        search.stopObservingChanges(); search.cancel()
    }

    @Test func directTextImportAndOpenCancelChapterSecretAndRejectHiddenScopesWithoutSending() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession()), bytes = try publication(), window = window()
        defer { library.epub.close(); library.textFormats.deactivate(); window.close() }
        await library.load()
        let book = try await library.epubRepository.importBook(bytes, filename: "Original integrated.epub"), file = try textFile(root)
        await library.openEPUB(book); try await waitForEPUB(library, window: window)
        await library.prepareChapterTranslation(); #expect(library.chapterTranslation.plan != nil)
        let source = try #require(library.chapterTranslation.plan?.sources.first)
        library.chapterTranslation.temporarySecret = "synthetic-unused-integration-key"
        await library.importTextFormat(file)
        #expect(library.chapterTranslation.temporarySecret.isEmpty && !library.chapterTranslation.busy && !library.chapterTranslation.submitted)
        #expect(library.chapterTranslation.attemptsUsed == 0 && !library.isCurrentAISource(source))
        #expect(!(await library.validateChapterSource(source)) && library.captureAISource() == nil)
        await library.prepareChapterTranslation(); #expect(library.chapterTranslation.plan == nil && library.chapterTranslation.preparationError != nil)
        library.preparePageTranslation(); #expect(library.pageTranslation.plan == nil)
        let textBook = try #require(library.textFormats.reader.book)
        await library.openEPUB(book); try await waitForEPUB(library, window: window)
        await library.prepareChapterTranslation(); #expect(library.chapterTranslation.plan != nil)
        library.chapterTranslation.temporarySecret = "synthetic-unused-integration-key"
        await library.openTextFormat(textBook)
        #expect(library.textFormats.isActive && library.chapterTranslation.temporarySecret.isEmpty)
        #expect(!library.chapterTranslation.submitted && library.chapterTranslation.attemptsUsed == 0)
        #expect(library.capturePDFProgress() == nil && library.currentAIBookID == nil)
        #expect(!(await library.validateChapterSource(source)))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("learning-v1.json").path))
    }

    @Test func savedPDFEditSearchAndCoverRemainIndependentWhileTextNotesAndProgressSurviveRoundTrip() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let data = try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: "pdf", subdirectory: "Fixtures")))
        let library = LibraryModel(root: root, aiSession: AppAISession())
        defer { library.textFormats.deactivate() }
        let book = try await library.repository.importPDF(data, filename: "Original integrated.pdf", pageCount: 2)
        let page = try #require(PDFDocument(data: data)?.page(at: 1)), bounds = page.bounds(for: .mediaBox)
        let quote = try #require(page.selection(for: bounds)?.string)
        let note = ReadingNote(bookID: book.id, anchor: PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: quote,
            regions: [PageRegion(pageIndex: 1, x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height, quote: quote)]), userText: "pdfoldintegrationunique")
        try await library.repository.saveNote(note); await library.load(); await library.open(book)
        let cover = try await library.covers.repository.thumbnail(for: CoverIdentity(book)).record
        let file = try textFile(root), originalText = try Data(contentsOf: file)
        await library.importTextFormat(file)
        let textBook = try #require(library.textFormats.reader.book), doc = try #require(library.textFormats.reader.document)
        let block = try #require(doc.blocks.first { $0.text.hasPrefix("window") })
        let anchor = try #require(doc.anchor(book: textBook, start: block.start, end: block.start + 6))
        #expect(await library.textFormats.saveNote(anchor, text: "Original independent text note"))
        await library.textFormats.saveProgress(anchor)
        let search = search(root, library: library), baseline = NoteBodySnapshot.pdf(note)
        search.updateQuery("pdfoldintegrationunique"); await search.waitForSearch(); #expect(search.response.totalCount == 1)
        let textSession = library.textFormats.reader.readerSessionID
        library.noteEditing.begin(baseline); library.noteEditing.setText("pdfnewintegrationunique", for: baseline)
        await library.saveEditedNote(baseline); await search.waitForSearch(); #expect(search.response.totalCount == 0)
        #expect(library.textFormats.isActive && library.textFormats.reader.readerSessionID == textSession)
        search.updateQuery("pdfnewintegrationunique"); await search.waitForSearch()
        let hit = try #require(search.response.groups.first?.hits.first)
        #expect(await library.openSearchTarget(hit.entry.target))
        #expect(library.reader.pageIndex == 1 && !library.textFormats.isActive)
        await library.openTextFormat(textBook)
        #expect(library.textFormats.reader.progress == anchor && library.textFormats.notes.first?.anchor == anchor)
        #expect(library.textFormats.notes.first?.userText == "Original independent text note")
        #expect(try await library.covers.repository.thumbnail(for: CoverIdentity(book)).record == cover)
        #expect(try await library.repository.readAsset(for: book) == data)
        #expect(try await library.textFormats.repository.read(textBook) == originalText)
        search.stopObservingChanges(); search.cancel()
    }
}
#endif
