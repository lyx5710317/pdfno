// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFKit
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoReaders
#if os(macOS)
import AppKit
@testable import PDFnoUI
#endif

@Suite(.serialized) @MainActor
struct ReaderNavigationTests {
    private func book(_ data: Data, page: Int = 0) -> BookRecord {
        BookRecord(title: "Original navigation fixture", fileSHA256: LibraryRepository.digest(data),
                   originalFilename: "original.pdf", pageCount: 2, lastPageIndex: page)
    }
    private func drainRestoration(_ session: PDFReaderSession) async {
        for _ in 0..<100 { await Task.yield() }
        #expect(!session.isRestoringPosition)
    }
    @Test func persistedPageReopensThroughExistingSchemaAndNewSession() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Navigation-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = try originalSample(), repository = LibraryRepository(root: root)
        let imported = try await repository.importPDF(data, filename: "original.pdf", pageCount: 2)
        try await repository.saveProgress(bookID: imported.id, pageIndex: 1)
        let reopened = LibraryRepository(root: root)
        let saved = try #require(try await reopened.load().books.first)
        let session = PDFReaderSession(), view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 800))
        try session.open(data: try await reopened.readAsset(for: saved), book: saved)
        session.attach(view); await drainRestoration(session)
        #expect(session.pageIndex == 1 && !session.canReturnToPreviousLocation)
        #expect(session.jump(to: 0) && session.returnToPreviousLocation())
        try await reopened.saveProgress(bookID: saved.id, pageIndex: session.pageIndex)
        #expect(try await LibraryRepository(root: root).load().books.first?.lastPageIndex == 1)
        #expect(try await reopened.readAsset(for: saved) == data)
        #expect(try await reopened.load().notes.isEmpty)
    }
    @Test func explicitJumpWinsOverDeferredReopenRestoration() async throws {
        let data = try originalSample(), session = PDFReaderSession()
        try session.open(data: data, book: book(data, page: 1))
        let view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 800))
        session.attach(view)
        #expect(session.isRestoringPosition)
        #expect(session.jump(to: 0))
        await drainRestoration(session)
        #expect(session.pageIndex == 0)
        #expect(session.document?.index(for: try #require(view.currentPage)) == 0)
        #expect(session.returnToPreviousLocation())
        #expect(session.pageIndex == 1 && !session.canReturnToPreviousLocation)
    }
    @Test func savedPageRestoresAndOnlyLatestHostCanChangeProgress() async throws {
        let data = try originalSample(), session = PDFReaderSession()
        try session.open(data: data, book: book(data, page: 1))
        let old = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 800)), latest = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 800))
        session.attach(old); session.attach(latest)
        await drainRestoration(session)
        #expect(session.view === latest && session.pageIndex == 1)
        #expect(session.document?.index(for: try #require(latest.currentPage)) == 1)
        let foreign = PDFDocument(data: data)
        latest.document = foreign
        session.updatePage()
        #expect(session.pageIndex == 1)
        session.close()
        #expect(session.book == nil && !session.canReturnToPreviousLocation)
    }
    @Test func detachedHostAndClosedReaderRejectPendingRestoration() async throws {
        let data = try originalSample(), session = PDFReaderSession(), view = PDFView()
        try session.open(data: data, book: book(data, page: 1)); session.attach(view)
        session.detach(view)
        await drainRestoration(session)
        #expect(session.view == nil && session.pageIndex == 1)
        session.attach(view); session.close()
        await drainRestoration(session)
        #expect(session.book == nil && session.document == nil && session.pageIndex == 0)
        #expect(!session.canReturnToPreviousLocation && !session.returnToPreviousLocation())
    }
    @Test func bookSwitchRejectsOldSearchAndOutlineWithoutChangingNewProgress() async throws {
        let data = try originalSample(), session = PDFReaderSession(), view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 800))
        try session.open(data: data, book: book(data))
        session.attach(view); session.search("window")
        let oldMatch = try #require(session.searchMatches.first), oldOutline = try #require(session.outline.last)
        let oldSessionID = session.readerSessionID
        #expect(session.show(oldMatch)); session.captureSelection()
        #expect(session.capturedSelection != nil)
        try session.open(data: data, book: book(data, page: 1))
        session.captureSelection() // The old canvas is still attached until the next render.
        #expect(session.capturedSelection == nil)
        session.attach(view)
        #expect(!session.show(oldMatch))
        #expect(!session.jump(to: oldOutline))
        #expect(!session.jump(to: 0, in: oldSessionID))
        await drainRestoration(session)
        #expect(session.pageIndex == 1 && !session.canReturnToPreviousLocation)
        #expect(!session.returnToPreviousLocation())
    }
    @Test func searchAndSourceJumpsReturnWithoutClearingImmutableSelection() async throws {
        let data = try originalSample(), session = PDFReaderSession(), view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 800))
        try session.open(data: data, book: book(data, page: 1)); session.attach(view)
        session.search("window")
        #expect(session.show(try #require(session.searchMatches.first)))
        session.captureSelection()
        let anchor = try #require(session.capturedSelection)
        #expect(session.pageIndex == 0 && session.canReturnToPreviousLocation)
        #expect(session.returnToPreviousLocation())
        #expect(session.pageIndex == 1 && session.capturedSelection == anchor)
        #expect(session.navigate(to: anchor) == .exact)
        #expect(session.pageIndex == 0 && session.returnToPreviousLocation())
        #expect(session.pageIndex == 1 && session.capturedSelection == anchor)
        #expect(data == (try originalSample()))
    }
    @Test func invalidJumpsAndProgressDoNotInventLocationsOrHistory() throws {
        let data = try originalSample(), session = PDFReaderSession()
        #expect(!session.go(to: 0) && !session.jump(to: 0) && !session.returnToPreviousLocation())
        try session.open(data: data, book: book(data))
        #expect(!session.jump(to: -1) && !session.jump(to: 2))
        #expect(session.go(to: 1) && !session.canReturnToPreviousLocation)
        #expect(session.jump(to: 1) && !session.canReturnToPreviousLocation)
        #expect(throws: ReaderError.self) { try session.open(data: data, book: book(data, page: 2)) }
        #expect(session.pageIndex == 1)
        let missing = PDFSourceAnchor(editionID: UUID(), fileSHA256: String(repeating: "a", count: 64), quote: "window", regions: [])
        #expect(session.navigate(to: missing) == .needsRebind && !session.canReturnToPreviousLocation)
    }
    @Test func transientHistoryIsBoundedAndFailureRetainsPreviousLocation() {
        var history = ReaderNavigationHistory<Int>()
        for page in 0..<50 { history.record(page, destination: page + 1) }
        #expect(history.locations.count == 32 && history.previous == 49)
        history.returned(to: 48)
        #expect(history.previous == 49)
        history.returned(to: 49)
        #expect(history.previous == 48)
        history.clear(); #expect(history.previous == nil)
    }
    @Test func EPUBCanonicalLocationsRemainSourceBoundAcrossLayoutVersions() throws {
        let edition = UUID(), hash = String(repeating: "a", count: 64)
        let origin = EPUBAnchor(editionID: edition, fileSHA256: hash, resourceHref: "original.xhtml", spineIndex: 0,
            start: 8, end: 14, quote: "window", prefix: "Original ", suffix: " sample", vertical: false)
        let destination = EPUBAnchor(editionID: edition, fileSHA256: hash, resourceHref: "second.xhtml", spineIndex: 1,
            start: 0, end: 6, quote: "second", prefix: "", suffix: " sample", vertical: false)
        let book = EPUBBook(editionID: edition, fileSHA256: hash, title: "Original", originalFilename: "original.epub")
        var history = ReaderNavigationHistory<EPUBAnchor>()
        history.record(origin, destination: destination)
        #expect(book.accepts(try #require(history.previous)))
        #expect(try JSONDecoder().decode(EPUBAnchor.self, from: JSONEncoder().encode(origin)) == origin)
        let changedEdition = EPUBBook(fileSHA256: hash, title: "Changed", originalFilename: "changed.epub")
        #expect(!changedEdition.accepts(origin))
        let sessionID = UUID(), ticket = ReaderLayoutTicket(readerSessionID: sessionID, documentVersion: 3)
        #expect(ticket.matches(sessionID: sessionID, documentVersion: 3))
        #expect(!ticket.matches(sessionID: UUID(), documentVersion: 3))
        #expect(!ticket.matches(sessionID: sessionID, documentVersion: 4))
    }
    #if os(macOS)
    @Test func closedEPUBCannotNavigateAndDoesNotStartAWebView() async {
        let session = EPUBReaderSession()
        #expect(!(await session.returnToPreviousLocation()))
        #expect(!(await session.command("next")))
        let item = EPUBOutlineItem(title: "Original stale chapter", index: 0, readerSessionID: UUID())
        #expect(!(await session.jump(to: item)))
        #expect(session.webView == nil && !session.canReturnToPreviousLocation)
    }
    @Test func shortcutsPreserveTextEditingSheetsAndOtherWindowFocus() {
        for key: UInt16 in [123, 124, 126] {
            #expect(ReaderNavigationShortcutPolicy.command(keyCode: key, modifiers: [.command, .option], isRepeat: false,
                enabled: true, canvasFocused: true, textInput: false, hasSheet: false) != nil)
            for condition in 0..<4 {
                #expect(ReaderNavigationShortcutPolicy.command(keyCode: key, modifiers: [.command, .option], isRepeat: false,
                    enabled: condition != 0, canvasFocused: condition != 1, textInput: condition == 2, hasSheet: condition == 3) == nil)
            }
        }
        for modifiers: NSEvent.ModifierFlags in [[], .command, .option, [.command, .option, .shift], [.command, .option, .control]] {
            #expect(ReaderNavigationShortcutPolicy.command(keyCode: 124, modifiers: modifiers, isRepeat: false,
                enabled: true, canvasFocused: true, textInput: false, hasSheet: false) == nil)
        }
        #expect(ReaderNavigationShortcutPolicy.command(keyCode: 124, modifiers: [.command, .option], isRepeat: true,
            enabled: true, canvasFocused: true, textInput: false, hasSheet: false) == nil)
        #expect(ReaderNavigationShortcutPolicy.command(keyCode: 0, modifiers: [.command, .option], isRepeat: false,
            enabled: true, canvasFocused: true, textInput: false, hasSheet: false) == nil)
        #expect(ReaderNavigationShortcutPolicy.isTextInput(NSTextView()))
        #expect(ReaderNavigationShortcutPolicy.isTextInput(NSTextField()))
        #expect(ReaderNavigationShortcutPolicy.isTextInput(NSSearchField()))
        #expect(!ReaderNavigationShortcutPolicy.isTextInput(PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 800))))
    }
    #endif
}
