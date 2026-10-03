// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFKit
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

@MainActor struct AuditFunctionalTests {
    @Test func latestPDFProgressSurvivesStaleSidebarReopenAndLateSave() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession())
        await library.load()
        let bytes = try originalSample()
        let a = try await library.repository.importPDF(bytes, filename: "a.pdf", pageCount: 2)
        // Original PDFKit-generated second edition, never a user document.
        let second = try #require(PDFDocument(data: bytes)); second.documentAttributes = [PDFDocumentAttribute.titleAttribute: "Second original edition"]
        let b = try await library.repository.importPDF(try #require(second.dataRepresentation()), filename: "b.pdf", pageCount: 2)
        await library.load(); await library.open(a)
        library.reader.go(to: 1)
        let late = try #require(library.capturePDFProgress())
        await library.open(b) // flushes outgoing A without an explicit sidebar reload
        #expect(library.books.first(where: { $0.id == a.id })?.lastPageIndex == 1)
        await library.saveProgress(late)
        #expect(try await library.repository.load().books.first(where: { $0.id == b.id })?.lastPageIndex == 0)
        await library.open(a) // stale caller still has lastPageIndex 0
        #expect(library.reader.pageIndex == 1)
        let earlierPage = try #require(library.capturePDFProgress())
        library.reader.go(to: 0); await library.saveProgress()
        await library.saveProgress(earlierPage) // old event in the same reader cannot undo a newer event
        await library.saveProgress(late) // previous reader session cannot revert the current one
        let restarted = LibraryModel(root: root, aiSession: AppAISession()); await restarted.load(); await restarted.open(a)
        #expect(restarted.reader.pageIndex == 0)
    }
    @Test func realPDFSelectionDraftReturnsAcrossReaderSessionsWithoutRelaxingFence() async throws {
        let bytes = try originalSample(),book = BookRecord(title: "Original", fileSHA256: LibraryRepository.digest(bytes), originalFilename: "original.pdf", pageCount: 2)
        let reader = PDFReaderSession(),view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        try reader.open(data: bytes, book: book); reader.attach(view)
        reader.search("window"); reader.show(try #require(reader.searchMatches.first));reader.captureSelection()
        let anchor = try #require(reader.capturedSelection)
        let first = AISourceSnapshot(bookID: book.id, readerSessionID: reader.readerSessionID, documentVersion: 0, anchor: .pdf(anchor))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let model = AILearningModel(root: root, aiSession: AppAISession())
        model.prepare(first);model.userText = "Unsaved original draft";model.prepare(nil)
        try reader.open(data: bytes, book: book)
        let reopened = AISourceSnapshot(bookID: book.id, readerSessionID: reader.readerSessionID, documentVersion: 0, anchor: .pdf(anchor))
        #expect(first.readerSessionID != reopened.readerSessionID)
        model.prepare(reopened);#expect(model.userText == "Unsaved original draft")
        let foreign = PDFSourceAnchor(editionID: UUID(), fileSHA256: anchor.fileSHA256, quote: anchor.quote, regions: anchor.regions)
        model.prepare(AISourceSnapshot(bookID: book.id, readerSessionID: reader.readerSessionID, documentVersion: 0, anchor: .pdf(foreign)))
        #expect(model.userText.isEmpty)
        model.prepare(first);#expect(model.userText == "Unsaved original draft")
        #expect(reader.resolution(of: foreign) == .needsRebind)
    }
    @Test func forgedAggregateQuoteFailsRealPDFKitAndAIWhileMultilineRemainsValid() throws {
        let bytes = try originalSample(),book = BookRecord(title: "Original", fileSHA256: LibraryRepository.digest(bytes), originalFilename: "original.pdf", pageCount: 2)
        let reader = PDFReaderSession(),view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        try reader.open(data: bytes, book: book);reader.attach(view)
        reader.search("window");reader.show(try #require(reader.searchMatches.first));reader.captureSelection()
        let anchor = try #require(reader.capturedSelection)
        let forged = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: "Unselected text", regions: anchor.regions)
        #expect(reader.resolution(of: forged) == .needsRebind)
        #expect(!AISelectionAnchor.pdf(forged).isValid)
        let document = try #require(reader.document), selection = PDFSelection(document: document)
        for index in 0..<document.pageCount {
            let page = try #require(document.page(at: index))
            selection.add(try #require(page.selection(for: page.bounds(for: .mediaBox))))
        }
        view.setCurrentSelection(selection, animate: false);reader.captureSelection()
        let multiline = try #require(reader.capturedSelection)
        #expect(multiline.regions.count > 2 && multiline.regions.contains(where: { $0.pageIndex == 1 }))
        #expect(multiline.hasConsistentQuote)
        #expect(reader.resolution(of: multiline) == .exact)
        #expect(bytes == (try originalSample()))
    }
    @Test func EPUBDraftIdentitySurvivesReflowAndVerticalChangeButSeparatesOffsets() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let model = AILearningModel(root: root, aiSession: AppAISession()), bookID = UUID(),editionID = UUID()
        func source(_ start: Int, _ version: Int, _ vertical: Bool) -> AISourceSnapshot {
            AISourceSnapshot(bookID: bookID,readerSessionID: UUID(),documentVersion: version,
                anchor: .epub(EPUBAnchor(editionID: editionID,fileSHA256: String(repeating: "a",count: 64),resourceHref: "chapter.xhtml",spineIndex: 0,start: start,end: start+6,quote: "window",prefix: "",suffix: "",vertical: vertical)))
        }
        model.prepare(source(0,1,false));model.userText = "Original EPUB draft";model.prepare(nil)
        model.prepare(source(0,8,true));#expect(model.userText == "Original EPUB draft")
        model.prepare(source(30,8,true));#expect(model.userText.isEmpty)
        model.prepare(source(0,1,false));#expect(model.userText == "Original EPUB draft")
    }
    @Test func inconsistentStoredQuotePreservesManifestAndBackup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let book = BookRecord(title: "Original",fileSHA256: String(repeating: "a",count: 64),originalFilename: "original.pdf",pageCount: 2)
        let forged = PDFSourceAnchor(editionID: book.editionID,fileSHA256: book.fileSHA256,quote: "Unselected text",regions: [PageRegion(pageIndex: 0,x: 1,y: 1,width: 30,height: 10,quote: "window")])
        var state = LibraryState();state.books = [book];state.notes = [ReadingNote(bookID: book.id,anchor: forged)]
        let bytes = try JSONEncoder().encode(state),manifest = root.appendingPathComponent("library-v1.json"),backup = manifest.appendingPathExtension("backup")
        try bytes.write(to: manifest);try Data("Original backup sentinel".utf8).write(to: backup)
        let repository = LibraryRepository(root: root)
        await #expect(throws: LibraryError.unreadableStore) { try await repository.load() }
        await #expect(throws: LibraryError.unreadableStore) { try await repository.saveProgress(bookID: book.id,pageIndex: 1) }
        #expect(try Data(contentsOf: manifest) == bytes)
        #expect(try Data(contentsOf: backup) == Data("Original backup sentinel".utf8))
    }
}
