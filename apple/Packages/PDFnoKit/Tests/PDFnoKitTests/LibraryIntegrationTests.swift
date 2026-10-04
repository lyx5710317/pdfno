// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import CoreGraphics
import PDFKit
import Testing
import PDFnoDomain
@testable import PDFnoServices
@testable import PDFnoUI

/// Actual committed-collection subscriptions, body editors, cover stores and source resolvers.
/// Fresh UUID roots and original fixtures only; no app launch, credential or transport.
@MainActor struct LibraryIntegrationTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Integration-" + UUID().uuidString) }
    private func sample(_ ext: String = "pdf") throws -> Data {
        try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: ext, subdirectory: "Fixtures")))
    }
    private func pdfFixture(_ root: URL) async throws -> (LibraryModel, BookRecord, ReadingNote, Data) {
        let library = LibraryModel(root: root, aiSession: AppAISession()), bytes = try sample()
        let book = try await library.repository.importPDF(bytes, filename: "Original A.pdf", pageCount: 2)
        let page = try #require(PDFDocument(data: bytes)?.page(at: 1)), bounds = page.bounds(for: .mediaBox)
        let quote = try #require(page.selection(for: bounds)?.string)
        let anchor = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: quote,
            regions: [PageRegion(pageIndex: 1, x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height, quote: quote)])
        let note = ReadingNote(bookID: book.id, anchor: anchor, userText: "previousuniquebody")
        try await library.repository.saveNote(note); await library.load()
        return (library, book, note, bytes)
    }
    private func search(_ root: URL, library: LibraryModel) -> LibrarySearchModel {
        let repository = LibrarySearchRepository(root: root)
        let model = LibrarySearchModel(root: root, debounce: .zero, search: { try await repository.search($0) })
        model.observeChanges(in: library); return model
    }
    private func edit(_ snapshot: NoteBodySnapshot, text: String, library: LibraryModel) async {
        library.noteEditing.begin(snapshot); library.noteEditing.setText(text, for: snapshot)
        await library.saveEditedNote(snapshot)
    }
    @Test func savedPDFEditAutomaticallyRefreshesOpenSearchWithoutReplacingReader() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let (library, book, note, bytes) = try await pdfFixture(root)
        let otherBytes = bytes + Data("\n% Original independent second edition\n".utf8)
        let other = try await library.repository.importPDF(otherBytes, filename: "Original B.pdf", pageCount: 2)
        await library.load(); await library.open(other)
        let session = library.reader.readerSessionID, search = search(root, library: library)
        search.updateQuery("previousuniquebody"); await search.waitForSearch(); #expect(search.response.totalCount == 1)
        let text = "replacementuniquebody 日本語🌸 cafe\u{301}"
        await edit(.pdf(note), text: text, library: library); await search.waitForSearch()
        // No explicit refresh: the exact subscription used by the visible search must fire.
        #expect(search.query == "previousuniquebody" && search.response.totalCount == 0)
        search.updateQuery("replacementuniquebody"); await search.waitForSearch()
        let hit = try #require(search.response.groups.first?.hits.first)
        #expect(hit.entry.target.noteID == note.id && hit.entry.userText.utf8.elementsEqual(text.utf8))
        #expect(hit.entry.quote == note.anchor.quote && hit.entry.target.book.editionID == book.editionID)
        #expect(library.reader.book?.id == other.id && library.reader.readerSessionID == session)
        let saved = try #require(library.notes.first { $0.id == note.id })
        await edit(.pdf(saved), text: "", library: library); await search.waitForSearch()
        #expect(search.response.totalCount == 0)
        search.updateQuery(note.anchor.quote); await search.waitForSearch()
        #expect(search.response.groups.flatMap(\.hits).contains { $0.entry.target.noteID == note.id })
        #expect(library.notes.first?.anchor == note.anchor && library.notes.first?.userText == "")
        #expect(try await library.repository.readAsset(for: book) == bytes)
        search.stopObservingChanges(); search.cancel()
    }
    @Test func savedEPUBAndLearningBodyEditsRefreshSameSearchAndKeepImmutableResult() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession()), bytes = try sample("epub")
        let book = try await library.epubRepository.importBook(bytes, filename: "Original.epub")
        let anchor = EPUBAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, resourceHref: "OEBPS/chapter.xhtml", spineIndex: 0,
            start: 0, end: 6, quote: "window", prefix: "", suffix: "", vertical: false)
        let note = EPUBNote(bookID: book.id, anchor: anchor, userText: "oldepubuniquebody")
        try await library.epubRepository.saveNote(note)
        var config = AIProviderConfig(); config.mode = .mock
        let source = AISourceSnapshot(bookID: book.id, readerSessionID: UUID(), documentVersion: 0, anchor: .epub(anchor))
        let result = AIResult(request: AIRequest(source: source, provider: config, kind: .explain), text: "Original saved synthetic explanation", fromCache: false)
        let learning = AILearningNote(result: result, userText: "oldlearninguniquebody")
        try await library.learning.repository.saveNote(learning); await library.load()
        let search = search(root, library: library)
        search.updateQuery("oldepubuniquebody"); await search.waitForSearch(); #expect(search.response.totalCount == 1)
        await edit(.epub(note), text: "newepubuniquebody 中文🌸", library: library); await search.waitForSearch()
        #expect(search.response.totalCount == 0)
        search.updateQuery("newepubuniquebody"); await search.waitForSearch()
        #expect(search.response.groups.first?.hits.first?.entry.target.noteID == note.id)
        search.updateQuery("oldlearninguniquebody"); await search.waitForSearch(); #expect(search.response.totalCount == 1)
        await edit(.learning(learning), text: "newlearninguniquebody 日本語", library: library); await search.waitForSearch()
        #expect(search.response.totalCount == 0)
        search.updateQuery("newlearninguniquebody"); await search.waitForSearch()
        #expect(search.response.groups.first?.hits.first?.entry.target.noteID == learning.id)
        let saved = try #require(library.learning.notes.first)
        await edit(.learning(saved), text: "", library: library); await search.waitForSearch()
        #expect(search.response.totalCount == 0 && library.learning.notes.first?.result == result)
        search.updateQuery("synthetic explanation"); await search.waitForSearch()
        #expect(search.response.groups.first?.hits.first?.entry.target.noteID == learning.id)
        #expect(library.epubNotes.first?.anchor == anchor && library.learning.notes.first?.result.source == source)
        #expect(try await library.epubRepository.read(book) == bytes)
        search.stopObservingChanges(); search.cancel()
    }
    @Test func persistedAndCancelledEditorDraftNeverEntersSearchAcrossRestart() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let (library, _, note, _) = try await pdfFixture(root), baseline = NoteBodySnapshot.pdf(note)
        let search = search(root, library: library)
        library.noteEditing.begin(baseline); library.noteEditing.setText("privatedraftuniquetoken", for: baseline)
        #expect(try NoteEditDraftJournal(root: root).load().first?.text == "privatedraftuniquetoken")
        search.updateQuery("privatedraftuniquetoken"); await search.waitForSearch(); #expect(search.response.totalCount == 0)
        let restarted = LibraryModel(root: root, aiSession: AppAISession()); await restarted.load()
        #expect(restarted.noteEditing.drafts[baseline.key]?.text == "privatedraftuniquetoken")
        restarted.noteEditing.cancel(baseline)
        #expect(try NoteEditDraftJournal(root: root).load().isEmpty)
        search.refresh(); await search.waitForSearch(); #expect(search.response.totalCount == 0)
        search.updateQuery("previousuniquebody"); await search.waitForSearch(); #expect(search.response.totalCount == 1)
        #expect(try await restarted.repository.load().notes == [note])
        search.stopObservingChanges(); search.cancel()
    }
    @Test func failedSaveKeepsSearchAtCommittedBodyAndRetryPublishesNewBody() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let (library, _, note, _) = try await pdfFixture(root), baseline = NoteBodySnapshot.pdf(note)
        let search = search(root, library: library)
        search.updateQuery("previousuniquebody"); await search.waitForSearch()
        let manifest = root.appendingPathComponent("library-v1.json"), backup = manifest.appendingPathExtension("backup")
        let before = try Data(contentsOf: manifest)
        try FileManager.default.removeItem(at: backup); try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: false)
        await edit(baseline, text: "retryuniquebody", library: library); await search.waitForSearch()
        #expect(search.response.totalCount == 1 && library.notes == [note])
        #expect(library.noteEditing.drafts[baseline.key]?.text == "retryuniquebody")
        #expect(try Data(contentsOf: manifest) == before)
        search.updateQuery("retryuniquebody"); await search.waitForSearch(); #expect(search.response.totalCount == 0)
        try FileManager.default.removeItem(at: backup)
        await library.saveEditedNote(baseline); await search.waitForSearch()
        #expect(search.response.totalCount == 1 && library.noteEditing.drafts[baseline.key] == nil)
        #expect(search.response.groups.first?.hits.first?.entry.quote == note.anchor.quote)
        search.stopObservingChanges(); search.cancel()
    }
    @Test func coverReplacementRestoreMetadataAndRestartPreserveExactEditedNoteRoute() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let (library, book, note, bytes) = try await pdfFixture(root)
        let otherBytes = bytes + Data("\n% Original cover route alternate\n".utf8)
        let other = try await library.repository.importPDF(otherBytes, filename: "Original B.pdf", pageCount: 2)
        await library.load(); await library.open(other)
        let session = library.reader.readerSessionID, identity = CoverIdentity(book), search = search(root, library: library)
        let automatic = try await library.covers.repository.thumbnail(for: identity)
        let context = try #require(CGContext(data: nil, width: 40, height: 60, bitsPerComponent: 8, bytesPerRow: 160,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.3, blue: 0.9, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 40, height: 60))
        let image = root.appendingPathComponent("Original local cover.png"), imageBytes = try CoverRaster.encode(#require(context.makeImage())).png
        try imageBytes.write(to: image); await library.covers.replace(identity, url: image)
        #expect(try await library.covers.repository.record(for: identity)?.origin == .userImage)
        search.updateQuery(""); await search.waitForSearch()
        let catalog = try #require(search.response.books.first { $0.identity.bookID == book.id })
        #expect(await search.saveMetadata(catalog, title: "Original catalog 中文", author: "Original Author"))
        search.updateQuery("routeediteduniquebody"); await search.waitForSearch()
        await edit(.pdf(note), text: "routeediteduniquebody", library: library); await search.waitForSearch()
        let target = try #require(search.response.groups.first?.hits.first?.entry.target)
        #expect(search.response.groups.first?.book.title == "Original catalog 中文")
        #expect(library.reader.book?.id == other.id && library.reader.readerSessionID == session)
        await library.covers.restore(identity)
        let restored = try await library.covers.repository.thumbnail(for: identity)
        #expect(restored.record.identity == automatic.record.identity && restored.record.imageSHA256 == automatic.record.imageSHA256)
        #expect(await library.openSearchTarget(target))
        #expect(library.reader.book?.id == book.id && library.reader.pageIndex == 1 && library.reader.resolution(of: note.anchor) == .exact)
        let restarted = LibraryModel(root: root, aiSession: AppAISession()); await restarted.load(); await restarted.open(other)
        #expect(await restarted.openSearchTarget(target))
        #expect(restarted.reader.book?.id == book.id && restarted.reader.pageIndex == 1)
        #expect(try await restarted.repository.readAsset(for: book) == bytes && Data(contentsOf: image) == imageBytes)
        #expect(try await restarted.repository.load().notes.first?.anchor == note.anchor)
        search.stopObservingChanges(); search.cancel()
    }
}
#endif
