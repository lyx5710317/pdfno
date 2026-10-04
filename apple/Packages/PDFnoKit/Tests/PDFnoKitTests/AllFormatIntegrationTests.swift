// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders
@testable import PDFnoUI

/// Original containers in one UUID library; unattached WebKit only, never an NSWindow or user app.
@Suite(.serialized) @MainActor struct AllFormatIntegrationTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-AllFormats-" + UUID().uuidString) }
    private func sample(_ ext: String = "pdf", directory: String = "Fixtures") throws -> Data {
        try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: ext, subdirectory: directory)))
    }
    private func files(_ root: URL) throws -> [String: Data] {
        guard let paths = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return [:] }
        var result: [String: Data] = [:]
        for case let file as URL in paths where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            result[String(file.path.dropFirst(root.path.count + 1))] = try Data(contentsOf: file)
        }
        return result
    }
    private func comicBooks(_ root: URL) async throws -> [ComicBook] {
        let store = ComicRepository(root: root)
        var books: [ComicBook] = []
        for (format, bytes) in [(ComicArchiveFormat.cbz, try ComicFixture.book()), (.cbt, try CBTFixture.book()),
                                (.cb7, try NativeComicFixture.load("original-lzma2.cb7")), (.cbr, try NativeComicFixture.load("original-rar5.cbr"))] {
            books.append(try await store.importBook(bytes, filename: "Original shared container." + format.rawValue))
        }
        return books
    }
    private func close(_ library: LibraryModel) {
        library.epub.close(); library.comic.close(); library.docx.deactivate(); library.textFormats.deactivate(); library.ebook.deactivate()
    }

    @Test func mixedCatalogShowsAllTenUnsupportedFormatsAndPreservesSupportedPreviewBytes() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let pdfs = LibraryRepository(root: root), pdf = try await pdfs.importPDF(sample(), filename: "Original PDF.pdf", pageCount: 2)
        let note = ReadingNote(bookID: pdf.id, anchor: PDFSourceAnchor(editionID: pdf.editionID, fileSHA256: pdf.fileSHA256,
            quote: "window", regions: [PageRegion(pageIndex: 0, x: 72, y: 650, width: 40, height: 16, quote: "window")]), userText: "Original saved body か\u{3099}😀")
        try await pdfs.saveNote(note)
        let comics = try await comicBooks(root), covers = CoverRepository(root: root)
        for comic in comics { #expect(try await covers.thumbnail(for: CoverIdentity(comic)).record.identity == CoverIdentity(comic)) }
        let texts = TextFormatRepository(root: root)
        _ = try await texts.importBook(Data("Chapter 1\nOriginal supported text".utf8), filename: "Original text.txt")
        for (format, bytes) in [(TextFileFormat.xhtml, Data(OriginalWebArchiveFixtures.xhtml.utf8)),
                                (.mhtml, OriginalWebArchiveFixtures.mhtml), (.xml, Data(OriginalWebArchiveFixtures.xml.utf8))] {
            _ = try await texts.importBook(bytes, filename: "Original web." + format.rawValue)
        }
        for format in EbookFormat.allCases {
            _ = try await EbookRepository(root: root).importBook(sample(format.rawValue, directory: "Fixtures/Ebooks"), filename: "Original ebook." + format.rawValue)
        }
        let before = try files(root), repository = BooknoLibraryPreviewRepository(root: root)
        let catalog = try await repository.catalogSnapshot()
        #expect(catalog.choices.count == 3 && catalog.unsupported.count == 10)
        #expect(Set(catalog.unsupported.map(\.format)) == ["CBT", "CB7", "CBR", "XHTML", "MHTML", "XML", "MOBI", "AZW", "AZW3", "FB2"])
        let unsupported = Set(catalog.unsupported.map(\.format)).sorted().joined(separator: "／")
        await #expect(throws: BooknoPreviewError.unsupportedFormat(unsupported)) { try await repository.catalog() }
        let material = try await repository.materialize(catalog.choices, includeSavedNotes: true, includeCovers: true)
        #expect(material.payloads.count == 4 && material.assets.count == 1)
        let exported = try #require(material.payloads.compactMap { if case .note(let n) = $0 { return n }; return nil }.first)
        #expect(exported.source.format == .pdf && exported.source.anchor == .pdf(note.anchor))
        #expect(exported.userText.utf8.elementsEqual(note.userText.utf8))
        let cb7 = try #require(comics.first { $0.archiveFormat == .cb7 })
        let forged = BooknoPreviewChoice(book: BooknoBookDTO(bookUUID: cb7.id,
            edition: BooknoEditionDTO(id: cb7.editionID, format: .cbz, sourceFileSHA256: cb7.fileSHA256), title: cb7.title))
        await #expect(throws: BooknoPreviewError.sourceMismatch) { try await repository.materialize([forged], includeSavedNotes: true, includeCovers: true) }
        let model = BooknoPreviewModel(repository: repository)
        await model.refresh()
        #expect(!model.enabled && model.choices.count == 3 && model.unsupportedBooks.count == 10)
        model.enabled = true; model.selectedIDs = [catalog.unsupported[0].id]; await model.prepare()
        #expect(model.batch == nil && model.error != nil)
        model.selectedIDs = [catalog.choices[0].id]; await model.prepare()
        #expect(model.batch != nil && model.error == nil)
        model.close(); #expect(model.choices.isEmpty && model.unsupportedBooks.isEmpty && model.batch == nil)
        #expect(try files(root) == before)
    }

    @Test func comicSearchMetadataCoverAndSourceRoutingRetainEachRealContainer() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let comics = try await comicBooks(root), search = LibrarySearchRepository(root: root)
        let initial = try await search.search("Original shared container")
        #expect(initial.books.count == 4 && Set(initial.books.map { $0.identity.format }) == [.comic, .cbt, .cb7, .cbr])
        let cb7 = try #require(comics.first { $0.archiveFormat == .cb7 })
        let identity = LocalBookIdentity(format: .cb7, bookID: cb7.id, editionID: cb7.editionID, fileSHA256: cb7.fileSHA256)
        let before = try files(root)
        try await LocalBookMetadataRepository(root: root).save(book: identity, title: "Original changed7 identity", author: "Original author", expectedRevision: 0)
        let after = try files(root)
        #expect(before.allSatisfy { after[$0.key] == $0.value })
        let hit = try #require(await search.search("changed7").groups.first?.hits.first)
        #expect(hit.entry.book.identity == identity && hit.entry.book.metadataRevision == 1)
        #expect(hit.entry.book.identity.format.coverFormat == CoverIdentity(cb7).format)
        #expect(throws: BooknoPreviewError.unsupportedFormat("CB7")) { try BooknoExportAdapter.book(hit.entry.book) }
        let catalog = try await BooknoLibraryPreviewRepository(root: root).catalogSnapshot()
        #expect(catalog.unsupported.first { $0.bookID == cb7.id }?.title == "Original changed7 identity")
        let library = LibraryModel(root: root, aiSession: AppAISession()); defer { close(library) }
        await library.load()
        #expect(await library.openSearchTarget(hit.entry.target))
        #expect(library.comic.book?.archiveFormat == .cb7 && library.comic.webView?.window == nil)
        let view = try #require(library.comic.webView)
        let wrong = LocalBookIdentity(format: .comic, bookID: cb7.id, editionID: cb7.editionID, fileSHA256: cb7.fileSHA256)
        #expect(!(await library.openSearchTarget(LibrarySearchTarget(book: wrong, kind: .book))))
        #expect(library.comic.webView === view && library.comic.book?.id == cb7.id)
        for book in comics { #expect(try await ComicRepository(root: root).read(book).format == book.archiveFormat) }
    }

    @Test func nativeWebEbookAndCompressedComicRoutesKeepNotesProgressAndUnsupportedBooknoSourcesDistinct() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession()); defer { close(library) }
        await library.load()
        let url = try #require(Bundle.module.url(forResource: "study-sample", withExtension: "mobi", subdirectory: "Fixtures/Ebooks"))
        await library.importFile(url)
        try #require(library.error == nil && library.ebook.isActive)
        #expect(library.ebook.reader.webView?.window == nil)
        let ebook = try #require(library.ebook.reader.book), document = try #require(library.ebook.reader.document)
        let anchor = try #require(document.anchor(book: ebook, start: 0, end: 1))
        #expect(await library.ebook.saveNote(anchor, text: "Original ebook source body"))
        #expect(await library.ebook.reader.navigate(to: anchor)); await library.saveProgress()
        var saved: [(TextFormatBook, TextFormatNote, TextFormatAnchor, Data)] = []
        for (format, bytes) in [(TextFileFormat.xhtml, Data(OriginalWebArchiveFixtures.xhtml.utf8)),
                                (.mhtml, OriginalWebArchiveFixtures.mhtml), (.xml, Data(OriginalWebArchiveFixtures.xml.utf8))] {
            let input = root.appendingPathComponent("Original mixed web." + format.rawValue)
            try bytes.write(to: input)
            await library.importFile(input)
            try #require(library.error == nil && library.textFormats.isActive && !library.ebook.isActive && !library.readingComic)
            #expect(library.textFormats.reader.webView?.window == nil && library.captureAISource() == nil)
            let book = try #require(library.textFormats.reader.book), doc = try #require(library.textFormats.reader.document)
            let block = try #require(doc.blocks.first { $0.text.hasPrefix("window") })
            let source = try #require(doc.anchor(book: book, start: block.start, end: block.start + 6))
            #expect(await library.textFormats.saveNote(source, text: "Original independent web body"))
            #expect(await library.textFormats.reader.navigate(to: source)); await library.saveProgress()
            let note = try #require(library.textFormats.notes.first)
            #expect(throws: BooknoPreviewError.unsupportedFormat(format.label)) { try BooknoExportAdapter.note(note, book: book) }
            // Reading position and the six-character quoted highlight are distinct saved values.
            let first = try #require(doc.blocks.first), scalar = try #require(first.text.unicodeScalars.first)
            let checkpoint = try #require(doc.anchor(book: book, start: first.start, end: first.start + (scalar.value > 0xffff ? 2 : 1)))
            #expect(await library.textFormats.reader.navigate(blockID: first.id)); await library.saveProgress()
            await library.openEbook(ebook)
            #expect(try await library.textFormats.repository.load().books.first { $0.id == book.id }?.progress == checkpoint)
            saved.append((book, note, checkpoint, bytes))
            #expect(library.error == nil && library.ebook.isActive && !library.textFormats.isActive)
            #expect(library.ebook.reader.progress == anchor && library.ebook.notes.first?.anchor == anchor && library.captureAISource() == nil)
        }
        let comicInput = root.appendingPathComponent("Original mixed compressed.cb7"), comicBytes = try NativeComicFixture.load("original-lzma2.cb7")
        try comicBytes.write(to: comicInput); await library.importFile(comicInput)
        try #require(library.error == nil && library.readingComic && !library.ebook.isActive && !library.textFormats.isActive)
        #expect(library.comic.book?.archiveFormat == .cb7 && library.comic.webView?.window == nil)
        let restarted = LibraryModel(root: root, aiSession: AppAISession()); defer { close(restarted) }
        await restarted.load(); await restarted.openEbook(ebook)
        #expect(restarted.ebook.reader.progress == anchor && restarted.ebook.notes.first?.userText == "Original ebook source body")
        #expect(try await restarted.ebook.repository.read(ebook) == Data(contentsOf: url))
        for (book, note, checkpoint, bytes) in saved {
            await restarted.openTextFormat(book)
            #expect(restarted.textFormats.isActive && !restarted.ebook.isActive && restarted.textFormats.reader.progress == checkpoint)
            #expect(restarted.textFormats.notes.first?.anchor == note.anchor && note.anchor.quote == "window")
            #expect(try await restarted.textFormats.repository.read(book) == bytes)
        }
        #expect(try await library.comicRepository.read(#require(library.comicBooks.first)).data == comicBytes)
    }
}
#endif
