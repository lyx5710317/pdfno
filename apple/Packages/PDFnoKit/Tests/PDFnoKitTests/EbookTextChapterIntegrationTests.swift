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

/// Actual native routes, original fixtures, invisible test-host windows and UUID stores only.
@Suite(.serialized) @MainActor
struct EbookTextChapterIntegrationTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Ebook-Integration-" + UUID().uuidString) }
    private func fixture(_ format: EbookFormat) throws -> URL {
        try #require(Bundle.module.url(forResource: "study-sample", withExtension: format.rawValue, subdirectory: "Fixtures/Ebooks"))
    }
    private func textFile(_ root: URL) throws -> URL {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("Original ebook integration.TXT")
        try Data("Chapter 1\nOriginal independent text 😀 e\u{301}\nChapter 2\nLast original line".utf8).write(to: url)
        return url
    }
    private func smallEPUB() throws -> Data {
        try ConversionFixture.zip([
            ("mimetype", Data("application/epub+zip".utf8)),
            ("META-INF/container.xml", Data("<container xmlns='urn:oasis:names:tc:opendocument:xmlns:container'><rootfiles><rootfile full-path='book.opf' media-type='application/oebps-package+xml'/></rootfiles></container>".utf8)),
            ("book.opf", Data("<package xmlns='http://www.idpf.org/2007/opf' version='3.0' unique-identifier='id'><metadata xmlns:dc='http://purl.org/dc/elements/1.1/'><dc:identifier id='id'>original-ebook-integration</dc:identifier><dc:title>Original small document</dc:title><dc:language>ja</dc:language></metadata><manifest><item id='nav' href='nav.xhtml' properties='nav' media-type='application/xhtml+xml'/><item id='one' href='one.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='one'/></spine></package>".utf8)),
            ("nav.xhtml", Data("<html xmlns='http://www.w3.org/1999/xhtml' xmlns:epub='http://www.idpf.org/2007/ops'><head><title>Original contents</title></head><body><nav epub:type='toc'><ol><li><a href='one.xhtml'>Original document</a></li></ol></nav></body></html>".utf8)),
            ("one.xhtml", Data("<html xmlns='http://www.w3.org/1999/xhtml'><head><title>Original document</title></head><body><p>Original complete small spine 日本語 😀 é.</p></body></html>".utf8))
        ], deflated: false)
    }
    private func close(_ library: LibraryModel) {
        library.epub.close(); library.docx.deactivate(); library.textFormats.deactivate(); library.ebook.deactivate(); library.comic.close()
    }
    private func openEPUB(_ library: LibraryModel, book: EPUBBook, window: NSWindow) async throws {
        await library.openEPUB(book)
        let deadline = Date().addingTimeInterval(20)
        while library.epub.busy && Date() < deadline {
            window.contentView = library.epub.webView
            try await Task.sleep(for: .milliseconds(40))
        }
        window.contentView = library.epub.webView
        try #require(library.error == nil && library.readingEPUB && library.epub.error == nil && library.epub.progress != nil && !library.epub.busy)
        #expect(!window.isVisible && !window.isKeyWindow)
    }

    @Test(arguments: EbookFormat.allCases)
    func allFourRoutesPreserveDistinctTextAndEbookOriginalNotesAndProgressAfterRestart(format: EbookFormat) async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession()); defer { close(library) }
        await library.load(); let url = try fixture(format), original = try Data(contentsOf: url)
        await library.importFile(url)
        try #require(library.error == nil && library.ebook.isActive && !library.textFormats.isActive)
        let book = try #require(library.ebook.reader.book), doc = try #require(library.ebook.reader.document)
        let block = try #require(doc.navigationBlocks.last), scalar = try #require(block.text.unicodeScalars.first)
        let anchor = try #require(doc.anchor(book: book, start: block.start, end: block.start + (scalar.value > 0xffff ? 2 : 1)))
        #expect(await library.ebook.saveNote(anchor, text: "Original independent ebook note"))
        #expect(await library.ebook.reader.navigate(to: anchor)); await library.saveProgress()
        let file = try textFile(root), textBytes = try Data(contentsOf: file)
        await library.importFile(file)
        try #require(library.error == nil && library.textFormats.isActive && !library.ebook.isActive)
        let textBook = try #require(library.textFormats.reader.book), textDoc = try #require(library.textFormats.reader.document)
        let textBlock = try #require(textDoc.blocks.first { $0.text.hasPrefix("Original independent") })
        let textAnchor = try #require(textDoc.anchor(book: textBook, start: textBlock.start, end: textBlock.start + 8))
        #expect(await library.textFormats.saveNote(textAnchor, text: "Original independent text note"))
        #expect(await library.textFormats.reader.navigate(to: textAnchor)); await library.saveProgress()
        await library.openEbook(book)
        #expect(library.ebook.isActive && !library.textFormats.isActive && !library.readingEPUB && !library.readingComic)
        #expect(library.ebook.reader.progress == anchor && library.ebook.notes.first?.anchor == anchor)
        #expect(library.capturePDFProgress() == nil && library.captureAISource() == nil && library.currentAIBookID == nil)
        let restarted = LibraryModel(root: root, aiSession: AppAISession()); defer { close(restarted) }
        await restarted.load(); await restarted.openEbook(try #require(restarted.ebook.books.first))
        #expect(restarted.ebook.reader.progress == anchor && restarted.ebook.notes.first?.userText == "Original independent ebook note")
        #expect(restarted.ebook.reader.book?.format == format)
        await restarted.openTextFormat(try #require(restarted.textFormats.books.first))
        #expect(restarted.textFormats.isActive && !restarted.ebook.isActive && restarted.textFormats.reader.progress == textAnchor)
        #expect(restarted.textFormats.notes.first?.anchor == textAnchor && restarted.textFormats.notes.first?.userText == "Original independent text note")
        #expect(try await restarted.ebook.repository.read(book) == original)
        #expect(try await restarted.textFormats.repository.read(textBook) == textBytes)
    }

    @Test func directEbookImportAndOpenCancelChapterSecretAndRejectHiddenSourcesWithoutSending() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession()); defer { close(library) }
        await library.load()
        let bytes = try smallEPUB()
        let book = try await library.epubRepository.importBook(bytes, filename: "Original integration.epub")
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; defer { window.close() }
        try await openEPUB(library, book: book, window: window)
        await library.prepareChapterTranslation()
        #expect(library.chapterTranslation.preparationError == nil)
        let source = try #require(library.chapterTranslation.plan?.sources.first)
        library.chapterTranslation.temporarySecret = "synthetic-unused-ebook-integration"
        await library.importEbook(try fixture(.fb2))
        #expect(library.ebook.isActive && library.chapterTranslation.temporarySecret.isEmpty && !library.chapterTranslation.busy)
        #expect(!library.chapterTranslation.submitted && library.chapterTranslation.attemptsUsed == 0)
        #expect(!library.isCurrentAISource(source))
        #expect(!(await library.validateChapterSource(source)))
        #expect(!(await library.returnToAISource(source)))
        await library.prepareChapterTranslation(); library.preparePageTranslation()
        #expect(library.chapterTranslation.plan == nil && library.chapterTranslation.preparationError != nil && library.pageTranslation.plan == nil)
        let ebook = try #require(library.ebook.reader.book)
        library.error = nil; try await openEPUB(library, book: book, window: window)
        await library.prepareChapterTranslation(); try #require(library.chapterTranslation.plan != nil)
        library.chapterTranslation.temporarySecret = "synthetic-unused-ebook-integration"
        await library.openEbook(ebook)
        #expect(library.ebook.isActive && !library.textFormats.isActive && library.chapterTranslation.temporarySecret.isEmpty)
        #expect(!library.chapterTranslation.submitted && library.chapterTranslation.attemptsUsed == 0)
        #expect(library.capturePDFProgress() == nil && library.captureAISource() == nil && library.currentAIBookID == nil)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("learning-v1.json").path))
    }

    @Test func savedPDFBodyEditAndSearchKeepEbookSessionAndSourcesIndependent() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession()); defer { close(library) }
        let data = try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: "pdf", subdirectory: "Fixtures")))
        let book = try await library.repository.importPDF(data, filename: "Original integration.pdf", pageCount: 2)
        let page = try #require(PDFDocument(data: data)?.page(at: 1)), bounds = page.bounds(for: .mediaBox)
        let quote = try #require(page.selection(for: bounds)?.string)
        let note = ReadingNote(bookID: book.id, anchor: PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: quote,
            regions: [PageRegion(pageIndex: 1, x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height, quote: quote)]), userText: "ebookpdfoldunique")
        try await library.repository.saveNote(note); await library.load(); await library.open(book)
        let url = try fixture(.azw3); await library.importFile(url)
        let ebook = try #require(library.ebook.reader.book), doc = try #require(library.ebook.reader.document)
        let anchor = try #require(doc.anchor(book: ebook, start: 0, end: 1))
        #expect(await library.ebook.saveNote(anchor, text: "Original ebook-only note"))
        #expect(await library.ebook.reader.navigate(to: anchor)); await library.saveProgress()
        let session = library.ebook.reader.readerSessionID, baseline = NoteBodySnapshot.pdf(note)
        library.noteEditing.begin(baseline); library.noteEditing.setText("ebookpdfnewunique", for: baseline)
        await library.saveEditedNote(baseline)
        #expect(library.ebook.isActive && library.ebook.reader.readerSessionID == session)
        #expect(library.ebook.reader.progress == anchor && library.ebook.notes.first?.anchor == anchor)
        let search = LibrarySearchRepository(root: root)
        #expect(try await search.search("ebookpdfoldunique").totalCount == 0)
        let hit = try #require(await search.search("ebookpdfnewunique").groups.first?.hits.first)
        #expect(await library.openSearchTarget(hit.entry.target))
        #expect(library.reader.pageIndex == 1 && !library.ebook.isActive && !library.textFormats.isActive)
        await library.openEbook(ebook)
        #expect(library.ebook.reader.progress == anchor && library.ebook.notes.first?.userText == "Original ebook-only note")
        #expect(try await library.ebook.repository.read(ebook) == Data(contentsOf: url))
        #expect(try await library.repository.readAsset(for: book) == data)
    }
}
#endif
