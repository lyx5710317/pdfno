// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Hidden native windows only: no activation, synthetic AI and original fixtures.
#if os(macOS)
import AppKit
import PDFKit
import WebKit
import SwiftUI
import Testing
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

@Suite(.serialized) @MainActor struct AIReadingBookmarkNativeTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Hidden-AI-Bookmark-"+UUID().uuidString) }
    private func window(_ view: NSView) -> NSWindow {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let w=NSWindow(contentRect: NSRect(x: 0,y: 0,width: 720,height: 520),styleMask: [],backing: .buffered,defer: false)
        w.isReleasedWhenClosed=false;w.contentView=view;view.frame=NSRect(x: 0,y: 0,width: 720,height: 520);return w
    }
    private func openPDF(_ model: LibraryModel) async throws -> (BookRecord,NSWindow,AnnotationAnchor) {
        let data=try originalSample(),book=try await model.repository.importPDF(data,filename: "Original.pdf",pageCount: 2)
        try model.reader.open(data: data,book: book)
        let view=PDFView(),w=window(view);model.reader.attach(view)
        view.setCurrentSelection(try #require(model.reader.document?.findString("window",withOptions: []).first),animate: false)
        return (book,w,try #require(await AnnotationReader.pdf(model.reader).capture()))
    }
    private func ready(_ session: EPUBReaderSession) async throws {
        let deadline=Date().addingTimeInterval(22)
        while !AnnotationReader.epub(session).ready && Date()<deadline { session.webView?.layoutSubtreeIfNeeded();try await Task.sleep(for: .milliseconds(50)) }
        try #require(AnnotationReader.epub(session).ready)
    }
    @Test func generatedSummaryStaysTemporaryUntilExplicitAddAndResultIsImmutable() async throws {
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let model=LibraryModel(root: r,aiSession: AppAISession(),learningTransport: OfflineSelectionUITestTransport()),(book,w,anchor)=try await openPDF(model)
        defer { model.reader.close();w.close() }
        var config=AIProviderConfig();config.mode = .mock;config.label="Original mock";model.learning.config=config
        await model.annotations.bind(.pdf(model.reader))
        model.openSelectionAI(.summarize,anchor: anchor,sessionID: model.reader.readerSessionID)
        #expect(model.selectionAIRoute == .conversation && model.learning.kind == .summarize && model.learning.source?.bookID==book.id)
        model.learning.start(confirmed: true,sourceIsCurrent: model.isCurrentAISource)
        let deadline=Date().addingTimeInterval(5)
        while model.learning.busy && Date()<deadline { try await Task.sleep(for: .milliseconds(20)) }
        let result=try #require(model.learning.result)
        #expect(result.kind == .summarize && model.hasUnsavedDocumentLearning)
        #expect(try await model.annotations.repository.load().notes.isEmpty)
        model.learning.userText="初始批注 👩🏽‍🚀"
        #expect(await model.addAIResultToNotes())
        #expect(await model.addAIResultToNotes())
        let saved=try #require(model.annotations.records.first)
        #expect(model.annotations.records.count==1 && saved.aiResult==result && !model.hasUnsavedDocumentLearning)
        model.annotations.begin(saved);model.annotations.editor.setText("重新编辑批注",for: AnnotationBodySnapshot(saved));await model.annotations.save(saved)
        let reopened=try #require(try await AnnotationRepository(root: r).load().notes.first)
        #expect(reopened.userText=="重新编辑批注" && reopened.aiResult==result && reopened.anchor==anchor)
        await model.annotations.navigate(reopened)
        #expect(model.reader.capturedSelection?.quote==anchor.quote && model.annotations.error==nil)
        #expect(!w.isVisible && !w.isKeyWindow)
    }
    @Test func taskDraftsAndFrozenSettingsContextDoNotCrossBooksOrLoseComments() async throws {
        let r=root(),otherRoot=root();defer { try? FileManager.default.removeItem(at: r);try? FileManager.default.removeItem(at: otherRoot) }
        let model=LibraryModel(root: r,learningTransport: OfflineSelectionUITestTransport()),(_,w,anchor)=try await openPDF(model)
        defer { model.reader.close();w.close() }
        model.openSelectionAI(.summarize,anchor: anchor,sessionID: model.reader.readerSessionID)
        model.learning.userText="总结独立草稿"
        let context=try #require(SettingsAIContext.capture(model)),frozen=try #require(context.source)
        model.openSelectionAI(.translate,anchor: anchor,sessionID: model.reader.readerSessionID);model.learning.userText="翻译草稿"
        model.learning.chooseTask(.summarize,source: frozen)
        #expect(model.learning.userText=="总结独立草稿" && context.source==frozen)
        let other=LibraryModel(root: otherRoot,learningTransport: OfflineSelectionUITestTransport()),(otherBook,otherWindow,_)=try await openPDF(other)
        defer { other.reader.close();otherWindow.close() }
        #expect(context.library === model && context.source?.bookID != other.currentAIBookID && other.learning.userText.isEmpty)
        #expect(!other.isCurrentAISource(frozen))
        other.reader.close();try other.reader.open(data: originalSample(),book: otherBook)
        let unselectedView=PDFView();otherWindow.contentView=unselectedView;other.reader.attach(unselectedView)
        #expect(SettingsAIContext.capture(other)?.source==nil)
        model.reader.view?.clearSelection()
        #expect(SettingsAIContext.capture(model)?.source==frozen)
        model.learning.chooseTask(.translate,source: frozen);#expect(model.learning.userText=="翻译草稿")
        #expect(SettingsAIContext.capture(nil)==nil)
    }
    @Test func readonlyNativeResultSupportsSelectingCopyWhileCommentRemainsEditable() throws {
        let coordinator=NativeNoteBodyInput.Coordinator(text: .constant("原创 AI 结果 👩🏽‍🚀")),scroll=NativeNoteBodyInput.makeEditor(coordinator: coordinator,identifier: "original-readonly-result",enabled: false)
        let w=window(scroll);defer { w.close() }
        let input=try #require(scroll.documentView as? NSTextView)
        #expect(!input.isEditable && input.isSelectable)
        input.string="原创 AI 结果 👩🏽‍🚀";input.setSelectedRange(NSRange(location: 0,length: input.string.utf16.count))
        let board=NSPasteboard(name: .init("PDFno-Private-AI-Copy-"+UUID().uuidString));defer { board.releaseGlobally() }
        board.declareTypes(input.writablePasteboardTypes,owner: nil)
        #expect(input.selectedRange().length==input.string.utf16.count)
        #expect(input.writeSelection(to: board,types: input.writablePasteboardTypes))
        #expect(board.string(forType: .string)==input.string)
        let commentCoordinator=NativeNoteBodyInput.Coordinator(text: .constant("批注")),comment=AnnotationCommentInput.makeEditor(coordinator: commentCoordinator,identifier: "original-editable-comment",enabled: true)
        #expect((comment.documentView as? NSTextView)?.isEditable==true)
        withExtendedLifetime((scroll,coordinator,comment,commentCoordinator)) {}
    }
    @Test func PDFCurrentPositionTitleSearchAndNavigationStayInCurrentDocument() async throws {
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let model=LibraryModel(root: r,learningTransport: OfflineSelectionUITestTransport()),(book,w,_)=try await openPDF(model)
        defer { model.reader.close();w.close() }
        #expect(model.reader.jump(to: 1));await model.bookmarks.addCurrent()
        let record=try #require(model.bookmarks.bookRecords.first)
        guard case .pdf(let position)=record.location else { Issue.record("Expected PDF bookmark");return }
        #expect(position.pageIndex==1 && record.bookID==book.id)
        #expect(await model.bookmarks.rename(record,title: "结语 Window"))
        let renamed=try #require(model.bookmarks.matchingTitles("window").first)
        #expect(model.bookmarks.matchingTitles("不存在").isEmpty)
        _=try await model.bookmarks.repository.add(.init(bookID: UUID(),location: record.location,title: "Other Window"));await model.bookmarks.reload()
        #expect(model.bookmarks.matchingTitles("window").count==1)
        #expect(model.reader.jump(to: 0));#expect(await model.bookmarks.navigate(renamed));#expect(model.reader.pageIndex==1)
        await model.bookmarks.delete(renamed);#expect(model.bookmarks.bookRecords.isEmpty && model.bookmarks.records.count==1)
        #expect(!w.isVisible)
    }
    @Test func EPUBBookmarksNavigateAfterHorizontalVerticalReflowAndRestart() async throws {
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let data=try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/Annotations/original-japanese-annotations.epub"))
        let model=LibraryModel(root: r,learningTransport: OfflineSelectionUITestTransport())
        var book=EPUBBook(fileSHA256: LibraryRepository.digest(data),title: "自作資料",originalFilename: "Original.epub")
        model.readingEPUB=true;try await model.epub.open(data: data,book: book,notes: [])
        let w=window(try #require(model.epub.webView));defer { model.epub.close();w.close() }
        try await ready(model.epub);await model.bookmarks.addCurrent()
        let record=try #require(model.bookmarks.bookRecords.first)
        guard case .epub(let position)=record.location else { Issue.record("Expected EPUB bookmark");return }
        #expect(!position.vertical && position.fileSHA256==book.fileSHA256)
        #expect(await model.epub.command("vertical"));#expect(model.epub.vertical)
        #expect(await model.bookmarks.navigate(record))
        #expect(model.epub.selection.map { AnnotationAnchor.epub($0).isSameSource(as: .epub(position)) } == true)
        book.progress=model.epub.progress;model.epub.close();try await model.epub.open(data: data,book: book,notes: []);w.contentView=model.epub.webView
        try await ready(model.epub);#expect(model.epub.vertical)
        await model.bookmarks.reload();#expect(await model.bookmarks.navigate(record))
        #expect(model.epub.selection?.resourceHref==position.resourceHref && model.epub.selection?.start==position.start)
        #expect(await model.epub.command("vertical"));#expect(!model.epub.vertical)
        #expect(await model.bookmarks.navigate(record));#expect(!model.epub.vertical && !w.isVisible)
    }
}
#endif
