// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFKit
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

struct LibrarySearchTests {
    private func book(_ title: String = "Original 中文日本語 Café", format: LocalBookFormat = .pdf, id: UUID = UUID()) -> LibrarySearchBook {
        LibrarySearchBook(identity: LocalBookIdentity(format: format, bookID: id, editionID: UUID(), fileSHA256: String(repeating: "a", count: 64)), title: title, author: "Original Author 山川")
    }
    @Test func titleAuthorCaseChineseJapaneseAndCanonicalUnicode() throws {
        let b = book(), entries = [LibrarySearchEntry(book: b, kind: .book)]
        for query in ["original", "AUTHOR", "中文", "日本語", "山川", "cafe\u{301}", "CAFÉ", "original 山川"] {
            #expect(try LibrarySearchIndex.search(query, books: [b], entries: entries).totalCount == 1)
        }
        #expect(try LibrarySearchIndex.search("cafe", books: [b], entries: entries).totalCount == 0)
        #expect(try LibrarySearchIndex.search("不存在", books: [b], entries: entries).groups.isEmpty)
    }
    @Test func noteAndSavedAIFieldsAreSeparateFromCatalogAndRemainOriginal() throws {
        let b = book("Catalog title"), n = LibrarySearchEntry(book: b, kind: .note, noteID: UUID(), userText: "My original thought 日記", quote: "A cafe\u{301} 🌸👩🏽‍💻 sentence")
        let ai = LibrarySearchEntry(book: b, kind: .learning, noteID: UUID(), userText: "Remember 复习", quote: "日本語原文", generatedText: "Saved synthetic explanation")
        let entries = [LibrarySearchEntry(book: b, kind: .book), n, ai]
        for query in ["日記", "CAFÉ", "🌸", "👩🏽‍💻", "original thought"] { #expect(try LibrarySearchIndex.search(query, books: [b], entries: entries).groups.first?.hits.first?.entry == n) }
        for query in ["复习", "原文", "SYNTHETIC"] { #expect(try LibrarySearchIndex.search(query, books: [b], entries: entries).groups.first?.hits.first?.entry == ai) }
        let result = try LibrarySearchIndex.search("CAFÉ", books: [b], entries: entries)
        #expect(result.groups[0].hits[0].entry.quote.unicodeScalars.elementsEqual(n.quote.unicodeScalars))
        #expect(try LibrarySearchIndex.search("Catalog", books: [b], entries: entries).totalCount == 1)
    }
    @Test func emptyQueryDoesNotEnumerateNotesAndLongQueryRefuses() throws {
        let b = book(), e = [LibrarySearchEntry(book: b, kind: .note, noteID: UUID(), userText: "original")]
        for query in ["", " \n\t ", "\u{3000}"] { let r = try LibrarySearchIndex.search(query, books: [b], entries: e); #expect(r.totalCount == 0 && r.groups.isEmpty && r.books.count == 1) }
        #expect(throws: LibrarySearchFailure.queryLimit) { try LibrarySearchIndex.search(String(repeating: "🌸", count: 513), books: [b], entries: e) }
    }
    @Test func groupingNamespacesSameUUIDAcrossFormatsAndEditions() throws {
        let id = UUID(), a = book("Original Alpha", id: id), b = book("Original Beta", format: .epub, id: id)
        let old = LibrarySearchBook(identity: LocalBookIdentity(format: .pdf, bookID: id, editionID: UUID(), fileSHA256: String(repeating: "b", count: 64)), title: "Orphan", sourceAvailable: false)
        let noteID = UUID(), entries = [a,b,old].map { LibrarySearchEntry(book: $0, kind: .learning, noteID: noteID, userText: "original") }
        let r = try LibrarySearchIndex.search("original", books: [b,a], entries: entries)
        #expect(r.groups.count == 3 && Set(r.groups.flatMap(\.hits).map(\.id)).count == 3)
        #expect(r.groups[0].book == a && r.groups[1].book == b && r.groups[2].book == old)
    }
    @Test func resultCapCountsAllMatchesAndOrderingIsDeterministic() throws {
        let b = book(), entries = (0..<310).map { _ in LibrarySearchEntry(book: b, kind: .note, noteID: UUID(), userText: "Original") }
        let first = try LibrarySearchIndex.search("original", books: [b], entries: entries)
        let second = try LibrarySearchIndex.search("original", books: [b], entries: entries.reversed())
        #expect(first.totalCount == 310 && first.groups.flatMap(\.hits).count == 300)
        #expect(first == second)
    }
    @Test func previewFindsTailWithoutSplittingGraphemeClusters() throws {
        let b = book(), text = String(repeating: "🌸", count: 400) + " Original 中文 cafe\u{301} 👩🏽‍💻"
        let e = LibrarySearchEntry(book: b, kind: .note, noteID: UUID(), userText: text)
        let preview = try #require(LibrarySearchIndex.search("中文", books: [b], entries: [e]).groups.first?.hits.first?.preview)
        #expect(preview.hasPrefix("…") && preview.contains("中文") && preview.contains("👩🏽‍💻"))
        let scalarPreview = try #require(LibrarySearchIndex.search("🏽", books: [b], entries: [e]).groups.first?.hits.first?.preview)
        #expect(scalarPreview.contains("👩🏽‍💻"))
    }
    @Test func cancellationStopsIndexWork() async {
        let b = book(), entry = LibrarySearchEntry(book: b, kind: .book)
        let gate = SearchGate()
        let task = Task.detached { _ = await gate.search("cancel"); return try LibrarySearchIndex.search("original", books: [b], entries: [entry]) }
        await gate.waitStarted("cancel"); task.cancel(); await gate.finish("cancel", count: 0)
        do { _ = try await task.value; Issue.record("Cancelled index work must throw") } catch { #expect(error is CancellationError) }
    }
    @Test func metadataRoundTripRevisionBackupAndNoLegacyRewrite() async throws {
        let root = freshRoot(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let legacy = root.appendingPathComponent("library-v1.json"), legacyBytes = Data("Original unrelated sentinel".utf8)
        try legacyBytes.write(to: legacy)
        let repository = LocalBookMetadataRepository(root: root), b = book().identity
        #expect(try await repository.load().records.isEmpty)
        try await repository.save(book: b, title: "Original title", author: "Original 作者", expectedRevision: 0)
        let first = try Data(contentsOf: root.appendingPathComponent("book-metadata-v1.json"))
        try await repository.save(book: b, title: "Edited title", author: "New Author", expectedRevision: 1)
        #expect(try await repository.load().records.first?.revision == 2)
        #expect(try Data(contentsOf: root.appendingPathComponent("book-metadata-v1.json.backup")) == first)
        do { try await repository.save(book: b, title: "Late title", author: "", expectedRevision: 1); Issue.record("Late edit must fail") } catch { #expect(error as? LibrarySearchFailure == .metadataConflict) }
        #expect(try Data(contentsOf: legacy) == legacyBytes)
    }
    @Test func futureOrUnknownMetadataIsPreservedWithBackupOnSaveRefusal() async throws {
        let root = freshRoot(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("book-metadata-v1.json"), backup = url.appendingPathExtension("backup"), bytes = Data("{\"schemaVersion\":2,\"records\":[]}".utf8), sentinel = Data("Original previous backup".utf8)
        try bytes.write(to: url); try sentinel.write(to: backup)
        do { try await LocalBookMetadataRepository(root: root).save(book: book().identity, title: "Original", author: "", expectedRevision: 0); Issue.record("Future metadata must fail") } catch {}
        #expect(try Data(contentsOf: url) == bytes && Data(contentsOf: backup) == sentinel)
        let unknown = Data("{\"schemaVersion\":1,\"records\":[],\"future\":true}".utf8)
        #expect(throws: LibrarySearchFailure.store) { try LocalBookMetadataRepository.decode(unknown) }
    }
    @Test func repositoryRebuildFindsAddedEditedRemovedNotesAndSavedAIWithoutDiskIndex() async throws {
        let root = freshRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LibraryRepository(root: root)
        let b = try await repository.importPDF(originalPDF(), filename: "Original Catalog.pdf", pageCount: 2)
        let anchor = fakeAnchor(b, quote: "Original 引文 cafe\u{301} 🌸")
        let note = ReadingNote(bookID: b.id, anchor: anchor, userText: "first original thought")
        let search = LibrarySearchRepository(root: root)
        #expect(try await search.search("thought").totalCount == 0)
        try await repository.saveNote(note)
        #expect(try await search.search("THOUGHT").totalCount == 1)
        var edit = note; edit.userText = "second edited 意見"; edit.revision += 1
        try await repository.saveNote(edit)
        #expect(try await search.search("first").totalCount == 0)
        #expect(try await search.search("意見").groups.first?.hits.first?.entry.target.noteID == note.id)
        var config = AIProviderConfig(); config.mode = .mock; config.label = "Original local fixture"; config.model = "synthetic"
        let source = AISourceSnapshot(bookID: b.id, readerSessionID: UUID(), documentVersion: 0, anchor: .pdf(anchor))
        let result = AIResult(request: AIRequest(source: source, provider: config, kind: .explain), text: "Saved synthetic 学習", fromCache: false)
        let learning = AILearningRepository(root: root), saved = AILearningNote(result: result, userText: "Independent user body")
        try await learning.saveNote(saved)
        #expect(try await search.search("学習").groups.first?.hits.first?.entry.target.noteID == saved.id)
        #expect(try await search.search("user body").totalCount == 1)
        let before = try Data(contentsOf: root.appendingPathComponent("learning-v1.json"))
        var state = try await repository.load(); state.notes = []
        try JSONEncoder().encode(state).write(to: root.appendingPathComponent("library-v1.json"), options: .atomic)
        #expect(try await search.search("意見").totalCount == 0)
        #expect(try Data(contentsOf: root.appendingPathComponent("learning-v1.json")) == before)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("search-index.json").path))
    }
    @Test func repositoryIncludesAllFormatMetadataNotesAndOrphanAI() async throws {
        let root = freshRoot(); defer { try? FileManager.default.removeItem(at: root) }; try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let hash = String(repeating: "a", count: 64), shared = UUID()
        let e = EPUBBook(id: shared, fileSHA256: hash, title: "Original EPUB", originalFilename: "original.epub")
        let ea = EPUBAnchor(editionID: e.editionID, fileSHA256: hash, resourceHref: "chapter.xhtml", spineIndex: 0, start: 0, end: 3, quote: "日本語", prefix: "", suffix: "", vertical: true)
        var es = EPUBState(); es.books = [e]; es.notes = [EPUBNote(bookID: e.id, anchor: ea, userText: "Original EPUB 日記")]
        try JSONEncoder().encode(es).write(to: root.appendingPathComponent("epub-v1.json"))
        let d = DOCXBook(id: shared, fileSHA256: hash, title: "Original DOCX", originalFilename: "original.docx")
        let da = DOCXAnchor(editionID: d.editionID, fileSHA256: hash, blockID: 0, start: 0, end: 2, quote: "中文", prefix: "", suffix: "")
        var ds = DOCXState(); ds.books = [d]; ds.notes = [DOCXNote(bookID: d.id, anchor: da, userText: "Original DOCX 日記")]
        try JSONEncoder().encode(ds).write(to: root.appendingPathComponent("docx-mammoth-v1.json"))
        var cs = ComicState(); cs.books = [ComicBook(id: shared, fileSHA256: hash, title: "Original CBZ", originalFilename: "original.cbz", pages: [ComicPage(path: "1.png", width: 12, height: 20)])]
        try JSONEncoder().encode(cs).write(to: root.appendingPathComponent("comics-v1.json"))
        let identity = LocalBookIdentity(format: .epub, bookID: e.id, editionID: e.editionID, fileSHA256: hash)
        try await LocalBookMetadataRepository(root: root).save(book: identity, title: "Local catalog title", author: "原创作者 山川", expectedRevision: 0)
        let search = LibrarySearchRepository(root: root)
        #expect(try await search.search("作者").groups.first?.book.identity == identity)
        #expect(try await search.search("catalog").totalCount == 1)
        #expect(try await search.search("日記").groups.count == 2)
        #expect(try await search.search("中文").groups.first?.book.identity.format == .docx)
        #expect(try await search.search("CBZ").groups.first?.book.identity.format == .comic)
        var config = AIProviderConfig(); config.mode = .mock
        let orphan = AISourceSnapshot(bookID: UUID(), readerSessionID: UUID(), documentVersion: 0, anchor: .epub(ea))
        try await AILearningRepository(root: root).saveNote(AILearningNote(result: AIResult(request: AIRequest(source: orphan, provider: config, kind: .explain), text: "Orphan synthetic memory", fromCache: false), userText: ""))
        let r = try await search.search("orphan")
        #expect(r.groups.first?.book.sourceAvailable == false && r.totalCount == 1)
    }
    @Test func invalidLearningStoreFailsRebuildWithoutPartialResultsOrWrites() async throws {
        let root = freshRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let pdf = LibraryRepository(root: root); _ = try await pdf.importPDF(originalPDF(), filename: "Original.pdf", pageCount: 2)
        let manifest = root.appendingPathComponent("learning-v1.json"), bytes = Data("Original malformed learning fixture".utf8)
        try bytes.write(to: manifest)
        do { _ = try await LibrarySearchRepository(root: root).search("Original"); Issue.record("Invalid store cannot return partial search") } catch {}
        #expect(try Data(contentsOf: manifest) == bytes)
    }
    private func freshRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Search-" + UUID().uuidString) }
    private func originalPDF() throws -> Data { try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: "pdf", subdirectory: "Fixtures"))) }
    private func fakeAnchor(_ b: BookRecord, quote: String) -> PDFSourceAnchor {
        PDFSourceAnchor(editionID: b.editionID, fileSHA256: b.fileSHA256, quote: quote, regions: [PageRegion(pageIndex: 0, x: 1, y: 1, width: 100, height: 12, quote: quote)])
    }
}

private actor SearchGate {
    private var pending: [String: CheckedContinuation<LibrarySearchResponse, Never>] = [:]
    private var started: [String: CheckedContinuation<Void, Never>] = [:]
    func search(_ query: String) async -> LibrarySearchResponse {
        await withCheckedContinuation { continuation in pending[query] = continuation; started.removeValue(forKey: query)?.resume() }
    }
    func waitStarted(_ query: String) async {
        if pending[query] != nil { return }
        await withCheckedContinuation { started[query] = $0 }
    }
    func finish(_ query: String, count: Int) { pending.removeValue(forKey: query)?.resume(returning: LibrarySearchResponse(books: [], groups: [], totalCount: count)) }
}
@MainActor struct LibrarySearchModelTests {
    @Test func lateBackendCannotReplaceNewQueryOrEmptyState() async {
        let gate = SearchGate(), root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let model = LibrarySearchModel(root: root, debounce: .zero, search: { await gate.search($0) })
        model.updateQuery("old"); await gate.waitStarted("old")
        model.updateQuery("new"); await gate.waitStarted("new"); await gate.finish("new", count: 2); await model.waitForSearch()
        #expect(model.response.totalCount == 2 && model.phase == .results)
        await gate.finish("old", count: 99)
        for _ in 0..<50 { await Task.yield() }
        #expect(model.response.totalCount == 2)
        model.updateQuery("late"); await gate.waitStarted("late")
        model.updateQuery(""); #expect(model.response.totalCount == 0 && model.phase == .idle)
        await gate.waitStarted(""); await gate.finish("", count: 0); await model.waitForSearch(); await gate.finish("late", count: 88)
        for _ in 0..<50 { await Task.yield() }
        #expect(model.response.totalCount == 0 && model.phase == .idle)
    }
    @Test func explicitCancelClearsHitsAndDiscardsIgnoringCancellationBackend() async {
        let gate = SearchGate(), root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let model = LibrarySearchModel(root: root, debounce: .zero, search: { await gate.search($0) })
        model.updateQuery("original"); await gate.waitStarted("original"); model.cancel(); await gate.finish("original", count: 77)
        for _ in 0..<50 { await Task.yield() }
        #expect(model.phase == .cancelled && model.response.groups.isEmpty && model.response.totalCount == 0)
    }
    @Test func refreshRebuildsAfterRepositoryEditAndFailedReadClearsOldHits() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Search-Model-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = LibraryRepository(root: root), bytes = try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: "pdf", subdirectory: "Fixtures")))
        let b = try await repo.importPDF(bytes, filename: "Original.pdf", pageCount: 2), search = LibrarySearchRepository(root: root)
        let model = LibrarySearchModel(root: root, debounce: .zero, search: { try await search.search($0) })
        model.updateQuery("作者"); await model.waitForSearch(); #expect(model.response.totalCount == 0)
        let selected = try #require(model.response.books.first)
        #expect(await model.saveMetadata(selected, title: "Original", author: "原创作者"))
        #expect(model.response.totalCount == 1)
        var state = try await repo.load(); state.books[0].title = "Renamed"
        try JSONEncoder().encode(state).write(to: root.appendingPathComponent("library-v1.json"))
        model.refresh(); await model.waitForSearch(); #expect(model.response.totalCount == 1)
        try Data("invalid".utf8).write(to: root.appendingPathComponent("learning-v1.json"))
        model.refresh(); await model.waitForSearch(); #expect(model.phase == .failed && model.response.groups.isEmpty)
        #expect(model.error == LibrarySearchFailure.store.localizedDescription)
        #expect(b.fileSHA256 == LibraryRepository.digest(bytes))
    }
    @Test func realPDFNoteAndPersistedAIReopenDifferentBookToExactPageWithoutMutation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Search-Route-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession()); await library.load()
        let bytes = try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: "pdf", subdirectory: "Fixtures")))
        let a = try await library.repository.importPDF(bytes, filename: "Original A.pdf", pageCount: 2)
        let document = try #require(PDFDocument(data: bytes)), page = try #require(document.page(at: 1)), bounds = page.bounds(for: .mediaBox)
        let quote = try #require(page.selection(for: bounds)?.string)
        let anchor = PDFSourceAnchor(editionID: a.editionID, fileSHA256: a.fileSHA256, quote: quote, regions: [PageRegion(pageIndex: 1, x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height, quote: quote)])
        let note = ReadingNote(bookID: a.id, anchor: anchor, userText: "Original cross-book route")
        try await library.repository.saveNote(note)
        document.documentAttributes = [PDFDocumentAttribute.titleAttribute: "Original B edition"]
        let b = try await library.repository.importPDF(#require(document.dataRepresentation()), filename: "Original B.pdf", pageCount: 2)
        await library.load(); await library.open(b)
        let target = try #require(try await LibrarySearchRepository(root: root).search("cross-book").groups.first?.hits.first?.entry.target)
        #expect(await library.openSearchTarget(target))
        #expect(library.reader.book?.id == a.id && library.reader.pageIndex == 1)
        #expect(try await library.repository.readAsset(for: a) == bytes)
        var config = AIProviderConfig(); config.mode = .mock
        let source = AISourceSnapshot(bookID: a.id, readerSessionID: UUID(), documentVersion: 0, anchor: .pdf(anchor))
        let learning = AILearningNote(result: AIResult(request: AIRequest(source: source, provider: config, kind: .explain), text: "Original stored AI navigation", fromCache: false), userText: "")
        try await AILearningRepository(root: root).saveNote(learning); await library.open(b)
        let ai = try #require(try await LibrarySearchRepository(root: root).search("AI navigation").groups.first?.hits.first?.entry.target)
        #expect(await library.openSearchTarget(ai))
        #expect(library.reader.book?.id == a.id && library.reader.pageIndex == 1)
        await library.open(b)
        let missing = LibrarySearchTarget(book: target.book, kind: .note, noteID: UUID())
        #expect(!(await library.openSearchTarget(missing)))
        #expect(library.reader.book?.id == b.id)
        let mismatch = LibrarySearchTarget(book: LocalBookIdentity(format: .pdf, bookID: a.id, editionID: UUID(), fileSHA256: a.fileSHA256), kind: .note, noteID: note.id)
        #expect(!(await library.openSearchTarget(mismatch)))
        #expect(library.reader.book?.id == b.id)
    }
}
