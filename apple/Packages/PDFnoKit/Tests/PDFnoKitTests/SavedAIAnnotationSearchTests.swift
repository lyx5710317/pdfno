// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFKit
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

@Suite(.serialized) @MainActor
struct SavedAIAnnotationSearchTests {
    private let sentence = "Reading opens a small window onto a wider world."
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-SavedAISearch-" + UUID().uuidString)
    }
    private func fixture(_ root: URL) async throws -> (BookRecord, AIResult) {
        let url = try #require(Bundle.module.url(forResource: "study-sample", withExtension: "pdf", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url)
        let document = try #require(PDFDocument(data: data))
        let book = try await LibraryRepository(root: root).importPDF(data, filename: "Original Search Fixture.pdf", pageCount: document.pageCount)
        let selection = try #require(document.findString(sentence, withOptions: []).first)
        let regions = selection.selectionsByLine().flatMap { line in
            line.pages.map { page in
                let bounds = line.bounds(for: page)
                return PageRegion(pageIndex: document.index(for: page), x: bounds.minX, y: bounds.minY,
                    width: bounds.width, height: bounds.height, quote: line.string ?? "")
            }
        }
        let anchor = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256,
            quote: try #require(selection.string), regions: regions)
        let source = AISourceSnapshot(bookID: book.id, readerSessionID: UUID(), documentVersion: 0, anchor: .pdf(anchor))
        var config = AIProviderConfig(); config.mode = .mock; config.label = "Original offline search fixture"
        return (book, AIResult(request: AIRequest(source: source, provider: config, kind: .explain),
            text: "Original saved annotation explanation marker", fromCache: false))
    }
    @Test func explicitlySavedAIAnnotationIsFoundByExactQuoteAndGeneratedText() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, result) = try await fixture(directory)
        let repository = AnnotationRepository(root: directory), search = SavedRecordSearchRepository(root: directory)
        #expect(try await search.search(sentence).totalCount == 0)
        #expect(try await repository.load().notes.isEmpty)
        let saved = try await repository.addAIResult(result, comment: "Independent committed comment")
        let file = directory.appendingPathComponent(AnnotationRepository.filename), before = try Data(contentsOf: file)
        for query in [sentence, "window", "explanation marker", "committed comment"] {
            let response = try await search.search(query)
            #expect(response.totalCount == 1)
            let hit = try #require(response.legacy.groups.first?.hits.first)
            #expect(hit.entry.target.kind.rawValue == "aiAnnotation")
            #expect(hit.entry.target.noteID == saved.id && hit.entry.quote == saved.anchor.quote)
            #expect(hit.entry.generatedText == result.displayText && hit.entry.userText == saved.userText)
        }
        #expect(try Data(contentsOf: file) == before)
        #expect(try await AILearningRepository(root: directory).load().notes.isEmpty)
    }

    @Test func conversationSaveRefreshesVisibleSearchButUnsavedAnswersAndDraftsStayOut() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let (book, result) = try await fixture(directory)
        let library = LibraryModel(root: directory, aiSession: AppAISession())
        await library.load(); await library.open(book)
        defer { library.reader.close() }
        let source = AISourceSnapshot(bookID: book.id, readerSessionID: library.reader.readerSessionID,
            documentVersion: 0, anchor: result.source.anchor)
        var config = AIProviderConfig(); config.mode = .mock; config.label = "Original offline conversation"
        #expect(await library.learning.applyConnection(config, temporarySecret: ""))
        library.conversation.open(.explain, source: source)
        for _ in 0..<200 {
            if !library.conversation.busy { break }
            try await Task.sleep(for: .milliseconds(10))
        }
        let answer = try #require(library.conversation.current?.answers.first)
        let search = SavedRecordSearchModel(root: directory), legacy = LibrarySearchModel(root: directory)
        search.observeChanges(in: library); legacy.observeChanges(in: library)
        defer { search.stopObservingChanges(); legacy.stopObservingChanges() }
        search.updateQuery(sentence); legacy.updateQuery(sentence)
        await search.waitForSearch(); await legacy.waitForSearch()
        #expect(search.response.totalCount == 0 && legacy.response.totalCount == 0)
        #expect(try await library.annotations.repository.load().notes.isEmpty)
        #expect(await library.conversation.addToNotes(answer))
        await search.waitForSearch(); await legacy.waitForSearch()
        #expect(search.response.totalCount == 1 && legacy.response.totalCount == 1)
        let saved = try #require(library.annotations.records.first)
        #expect(search.response.legacy.groups.first?.hits.first?.entry.target.noteID == saved.id)
        #expect(saved.aiResult == answer.result)
        library.annotations.begin(saved)
        library.annotations.editor.setText("Original pendingcomment marker", for: AnnotationBodySnapshot(saved))
        search.updateQuery("pendingcomment"); await search.waitForSearch()
        #expect(search.response.totalCount == 0)
        await library.annotations.save(saved); await search.waitForSearch()
        #expect(search.response.totalCount == 1)
        #expect(search.response.legacy.groups.first?.hits.first?.entry.userText == "Original pendingcomment marker")
    }

    @Test func savedResultReopensExactPDFSourceAndRejectsStaleTargetsBeforeSwitching() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let (book, result) = try await fixture(directory), repository = AnnotationRepository(root: directory)
        _ = try await repository.addAIResult(result, comment: "Original return marker")
        let response = try await SavedRecordSearchRepository(root: directory).search("return marker")
        let target = try #require(response.legacy.groups.first?.hits.first?.entry.target)
        let library = LibraryModel(root: directory, aiSession: AppAISession())
        let original = try await library.repository.readAsset(for: book)
        let document = try #require(PDFDocument(data: original))
        document.documentAttributes = [PDFDocumentAttribute.titleAttribute: "Other original edition"]
        let other = try await library.repository.importPDF(#require(document.dataRepresentation()), filename: "Other Original.pdf", pageCount: document.pageCount)
        #expect(other.id != book.id)
        await library.load(); await library.open(other)
        defer { library.reader.close() }
        #expect(await library.openSearchTarget(target))
        #expect(library.reader.book?.id == book.id && library.reader.pageIndex == 0)
        #expect(library.reader.go(to: 1))
        #expect(await library.openSearchTarget(target, preservingCurrentReader: true))
        #expect(library.reader.pageIndex == 0)
        #expect(try await library.repository.readAsset(for: book) == original)
        await library.open(other)
        let session = library.reader.readerSessionID
        let wrongEdition = LocalBookIdentity(format: .pdf, bookID: book.id, editionID: UUID(), fileSHA256: book.fileSHA256)
        let wrongFormat = LocalBookIdentity(format: .epub, bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256)
        for identity in [wrongEdition, wrongFormat] {
            #expect(!(await library.openSearchTarget(LibrarySearchTarget(book: identity, kind: .aiAnnotation, noteID: target.noteID))))
            #expect(library.reader.book?.id == other.id && library.reader.readerSessionID == session)
        }
        try JSONEncoder().encode(AnnotationState()).write(to: directory.appendingPathComponent(AnnotationRepository.filename), options: .atomic)
        #expect(!(await library.openSearchTarget(target)))
        #expect(library.reader.book?.id == other.id && library.reader.readerSessionID == session)
    }

    @Test func epubAnnotationAndOrphanKeepExactSavedIdentity() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let hash = String(repeating: "a", count: 64)
        let book = EPUBBook(fileSHA256: hash, title: "Original EPUB", originalFilename: "original.epub")
        let quote = "Original EPUB window"
        let anchor = EPUBAnchor(editionID: book.editionID, fileSHA256: hash, resourceHref: "chapter.xhtml",
            spineIndex: 0, start: 0, end: quote.utf16.count, quote: quote, prefix: "", suffix: "", vertical: true)
        var state = EPUBState(); state.books = [book]
        let file = directory.appendingPathComponent("epub-v1.json")
        try JSONEncoder().encode(state).write(to: file)
        var config = AIProviderConfig(); config.mode = .mock
        let source = AISourceSnapshot(bookID: book.id, readerSessionID: UUID(), documentVersion: 0, anchor: .epub(anchor))
        let result = AIResult(request: AIRequest(source: source, provider: config, kind: .explain), text: "Original EPUB explanation", fromCache: false)
        let saved = try await AnnotationRepository(root: directory).addAIResult(result, comment: "")
        let search = SavedRecordSearchRepository(root: directory)
        let hit = try #require(try await search.search(quote).legacy.groups.first?.hits.first)
        #expect(hit.entry.target.kind == .aiAnnotation && hit.entry.target.noteID == saved.id)
        #expect(hit.entry.book.sourceAvailable && hit.entry.book.identity.format == .epub)
        state.books = []; try JSONEncoder().encode(state).write(to: file, options: .atomic)
        let orphan = try #require(try await search.search(quote).legacy.groups.first?.hits.first)
        #expect(!orphan.entry.book.sourceAvailable && orphan.entry.target == hit.entry.target)
        #expect(orphan.entry.quote == quote && orphan.entry.generatedText == result.displayText)
    }

    @Test func malformedAnnotationStoreClearsSearchWithoutRewritingOrReturningPartialHits() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let (_, result) = try await fixture(directory)
        _ = try await AnnotationRepository(root: directory).addAIResult(result, comment: "Original")
        let search = SavedRecordSearchModel(root: directory)
        search.updateQuery("Original"); await search.waitForSearch()
        #expect(search.response.totalCount > 0)
        let file = directory.appendingPathComponent(AnnotationRepository.filename)
        let invalid = Data("{\"schemaVersion\":99,\"notes\":[]}".utf8)
        try invalid.write(to: file, options: .atomic)
        search.refresh(); await search.waitForSearch()
        #expect(search.phase == .failed && search.response.totalCount == 0)
        #expect(search.response.legacy.groups.isEmpty && search.response.records.hits.isEmpty)
        #expect(try Data(contentsOf: file) == invalid)
    }

    @Test func collidingLegacyAndAnnotationIDsKeepSeparateResultsAndSourcePages() async throws {
        let directory = root(); defer { try? FileManager.default.removeItem(at: directory) }
        let (book, result) = try await fixture(directory)
        let saved = try await AnnotationRepository(root: directory).addAIResult(result, comment: "Shared original match")
        let repository = LibraryRepository(root: directory)
        let document = try #require(PDFDocument(data: try await repository.readAsset(for: book)))
        let page = try #require(document.page(at: 1)), bounds = page.bounds(for: .mediaBox)
        let quote = try #require(page.selection(for: bounds)?.string)
        let anchor = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: quote,
            regions: [PageRegion(pageIndex: 1, x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height, quote: quote)])
        try await repository.saveNote(ReadingNote(id: saved.id, bookID: book.id, anchor: anchor, userText: "Shared original match"))
        let response = try await SavedRecordSearchRepository(root: directory).search("Shared original match")
        let hits = response.legacy.groups.flatMap(\.hits)
        #expect(response.totalCount == 2 && hits.count == 2 && Set(hits.map(\.id)).count == 2)
        let annotation = try #require(hits.first { $0.entry.target.kind == .aiAnnotation })
        let legacy = try #require(hits.first { $0.entry.target.kind == .note })
        #expect(annotation.entry.target.noteID == legacy.entry.target.noteID)
        let library = LibraryModel(root: directory, aiSession: AppAISession())
        await library.load(); await library.open(book)
        defer { library.reader.close() }
        #expect(await library.openSearchTarget(legacy.entry.target, preservingCurrentReader: true))
        #expect(library.reader.pageIndex == 1)
        #expect(await library.openSearchTarget(annotation.entry.target, preservingCurrentReader: true))
        #expect(library.reader.pageIndex == 0)
    }
}
#endif
