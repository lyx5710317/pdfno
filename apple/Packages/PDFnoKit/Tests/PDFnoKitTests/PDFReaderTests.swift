// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFKit
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

@MainActor
struct PDFReaderTests {
    @Test func actualPDFKitReadSearchSelectionHighlightAndReopen() throws {
        let data = try originalSample()
        let book = BookRecord(title: "sample", fileSHA256: LibraryRepository.digest(data), originalFilename: "sample.pdf", pageCount: 2)
        let session = PDFReaderSession()
        try session.open(data: data, book: book)
        let view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 800))
        session.attach(view)
        #expect(session.document?.pageCount == 2)
        #expect(session.outline.map(\.pageIndex) == [0,1])
        session.search("window")
        let match = try #require(session.searchMatches.first)
        #expect(match.string == "window")
        session.show(match); session.captureSelection()
        let anchor = try #require(session.capturedSelection)
        #expect(anchor.quote == "window")
        #expect(session.resolution(of: anchor) == .exact)
        let note = ReadingNote(bookID: book.id, anchor: anchor, userText: "a thought")
        session.project([note])
        #expect(session.document?.page(at: 0)?.annotations.count == 1)
        session.project([note])
        #expect(session.document?.page(at: 0)?.annotations.count == 1)
        session.go(to: 1)
        #expect(session.pageIndex == 1)
        #expect(session.navigate(to: anchor) == .exact)
        #expect(session.pageIndex == 0)
        // JSON round trip + new PDFDocument, not view coordinates or in-memory selection.
        let restored = try JSONDecoder().decode(ReadingNote.self, from: JSONEncoder().encode(note))
        try session.open(data: data, book: book)
        #expect(session.document?.page(at: 0)?.annotations.isEmpty == true)
        #expect(session.resolution(of: restored.anchor) == .exact)
        session.project([restored])
        #expect(session.document?.page(at: 0)?.annotations.count == 1)
        #expect(data == (try originalSample()))
        let foreign = PDFSourceAnchor(editionID: UUID(), fileSHA256: book.fileSHA256, quote: anchor.quote, regions: anchor.regions)
        #expect(session.navigate(to: foreign) == .needsRebind)
    }
    @Test func invalidPDFIsRejectedAndEmptySearchIsSafe() throws {
        let session = PDFReaderSession()
        session.search("")
        #expect(session.searchMatches.isEmpty)
        let book = BookRecord(title: "bad", fileSHA256: String(repeating: "a", count: 64), originalFilename: "bad.pdf", pageCount: 2)
        #expect(throws: ReaderError.self) { try session.open(data: Data("invalid".utf8), book: book) }
    }
}
