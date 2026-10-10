// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

@Suite(.serialized) @MainActor struct ReaderNoteRefinementTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Note-Refinement-"+UUID().uuidString) }
    private func record() -> AnchoredAnnotation {
        let anchor=PDFSourceAnchor(editionID: UUID(),fileSHA256: String(repeating: "a",count: 64),quote: "Original window",regions: [PageRegion(pageIndex: 0,x: 10,y: 20,width: 150,height: 18,quote: "Original window")])
        return AnchoredAnnotation(bookID: UUID(),anchor: .pdf(anchor),kind: .note)
    }
    @Test func cancelNewNoteLeavesNoEmptyRecordOrDraft() async throws {
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let model=AnnotationModel(root: r),note=record(),snapshot=AnnotationBodySnapshot(note)
        model.begin(note);model.editor.setText("本次正文",for: snapshot);model.cancel(note)
        #expect(model.editing==nil && model.editor.drafts.isEmpty)
        #expect(try await model.repository.load().notes.isEmpty)
        #expect(try SavedBodyDraftJournal<AnnotationBodySnapshot>(root: r).load().isEmpty)
    }
    @Test func repeatedOpenCancelAndDonePreserveSavedBodyAndAnchor() async throws {
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let model=AnnotationModel(root: r),note=record()
        let saved=try await model.repository.save(expected: note,text: "原有正文 e\u{301} 👩🏽‍🚀")
        let snapshot=AnnotationBodySnapshot(saved)
        model.begin(saved);model.editor.setText("不要保存",for: snapshot);model.begin(saved);model.cancel(saved)
        #expect(try await model.repository.load().notes == [saved])
        #expect(model.editor.drafts.isEmpty && model.editing==nil)
        model.begin(saved);model.editor.setText("完成后的正文",for: snapshot);await model.save(saved)
        let updated=try #require(try await model.repository.load().notes.first)
        #expect(updated.userText=="完成后的正文" && updated.anchor==saved.anchor && updated.id==saved.id)
        #expect(model.editing==nil && model.editor.drafts.isEmpty)
        model.begin(updated);#expect(model.editor.drafts[AnnotationBodySnapshot(updated).key]?.text==updated.userText)
        model.cancel(updated);#expect(try await model.repository.load().notes == [updated])
    }
    @Test func cancelResumedDraftDiscardsOnlyThisSessionAndKeepsOtherDrafts() async throws {
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let first=AnnotationModel(root: r),note=record(),other=record(),snapshot=AnnotationBodySnapshot(note)
        first.begin(note);first.editor.setText("先前保留的草稿",for: snapshot)
        first.editing=nil;first.begin(other);first.editor.setText("另一本书的草稿",for: AnnotationBodySnapshot(other));first.editing=nil
        let reopened=AnnotationModel(root: r)
        reopened.begin(note);reopened.editor.setText("本次取消的修改",for: snapshot);reopened.begin(note);reopened.cancel(note)
        #expect(reopened.editing==nil && reopened.editor.drafts[snapshot.key]?.text=="先前保留的草稿")
        let journal=try SavedBodyDraftJournal<AnnotationBodySnapshot>(root: r).load()
        #expect(journal.count==2 && journal.first(where: { $0.baseline.key==snapshot.key })?.text=="先前保留的草稿")
        #expect(reopened.editor.drafts[AnnotationBodySnapshot(other).key]?.text=="另一本书的草稿")
        #expect(try await reopened.repository.load().notes.isEmpty)
    }
    @Test func allProfessionalInspectorsUseDirectoryWidthAndNeverOverflow() {
        for width in stride(from: CGFloat(0),through: 1280,by: 8) {
            let nav=PDFnoReaderPlacement(width: width,navigation: true,notes: false,preferred: .navigation,profile: .professional)
            let notes=PDFnoReaderPlacement(width: width,navigation: false,notes: true,preferred: .notes,profile: .professional)
            #expect(nav.navigationWidth==notes.notesWidth && nav.overlay==notes.overlay)
            #expect(nav.navigationWidth<=width && notes.notesWidth<=width)
            #expect(nav.canvasWidth>=0 && notes.canvasWidth>=0)
        }
        #expect(PDFnoReaderPlacement(width: 1280,navigation: false,notes: true,preferred: .notes,profile: .professional).notesWidth==210)
    }
    @Test func borderlessEditorKeepsNativeDelegateSelectionAndSavingFence() throws {
        let coordinator=NativeNoteBodyInput.Coordinator(text: .constant("便签正文"))
        let scroll=AnnotationCommentInput.makeEditor(coordinator: coordinator,identifier: "refinement-note",enabled: true,borderless: true)
        let input=try #require(scroll.documentView as? NSTextView)
        #expect(scroll.borderType == .noBorder && !scroll.drawsBackground && !input.drawsBackground)
        #expect(input.isEditable && input.isSelectable && input.allowsUndo && input.delegate === coordinator)
        coordinator.update(input,text: .constant("便签正文"),enabled: false)
        #expect(!coordinator.textView(input,shouldChangeTextIn: NSRange(location: 0,length: 0),replacementString: "不得修改"))
        NativeNoteBodyInput.dismantleNSView(scroll,coordinator: coordinator)
    }
    @Test func noteFitsNarrowHiddenHostsInBothThemesAndTitlebarPreservesButtonGap() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let model=AnnotationModel(root: r),note=record();model.begin(note)
        for width in [CGFloat(320),480] {
            for scheme in [ColorScheme.light,.dark] {
                let host=NSHostingView(rootView: AnnotationEditor(model: model,baseline: note).frame(width: width,height: 400).preferredColorScheme(scheme))
                let window=NSWindow(contentRect: NSRect(x: 0,y: 0,width: width,height: 400),styleMask: [.titled,.closable,.miniaturizable,.resizable],backing: .buffered,defer: false)
                window.isReleasedWhenClosed=false;window.contentView=host
                host.layoutSubtreeIfNeeded();try await Task.sleep(for: .milliseconds(100));host.layoutSubtreeIfNeeded()
                #expect(host.fittingSize.width<=width && !window.isVisible && !window.isKeyWindow)
                let available=MacDocumentWindowToolbar.Coordinator.availableWidth(window: window,requested: width)
                let zoom=try #require(window.standardWindowButton(.zoomButton))
                #expect(width-available>=zoom.convert(zoom.bounds,to: nil).maxX+12)
                #expect(available>=0 && available<=width && width-available<120)
                window.close()
            }
        }
        #expect(model.editing?.id==note.id && model.editor.drafts[AnnotationBodySnapshot(note).key]?.text=="")
    }
    @Test func AIResultAndBookmarksFitUnifiedInspectorInBothThemes() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let r=root();defer { try? FileManager.default.removeItem(at: r) }
        let library=LibraryModel(root: r,learningTransport: OfflineSelectionUITestTransport()),note=record()
        guard case .pdf(let anchor)=note.anchor else { return }
        let source=AISourceSnapshot(bookID: note.bookID,readerSessionID: UUID(),documentVersion: 0,anchor: .pdf(anchor))
        library.learning.prepare(source)
        let result=AIResult(request: AIRequest(source: source,provider: library.learning.config,kind: .summarize),text: "原创结果 " + String(repeating: "日本語 cafe\u{301} 👩🏽‍🚀 ",count: 15),fromCache: false)
        library.learning.result=result;library.learning.userText="独立评论"
        for scheme in [ColorScheme.light,.dark] {
            let host=NSHostingView(rootView: AILearningWorkspace(library: library,learning: library.learning,embedded: true,close: {}).frame(width: 210,height: 620).preferredColorScheme(scheme))
            let w=NSWindow(contentRect: NSRect(x: 0,y: 0,width: 210,height: 620),styleMask: [],backing: .buffered,defer: false)
            w.isReleasedWhenClosed=false;w.contentView=host
            host.layoutSubtreeIfNeeded();try await Task.sleep(for: .milliseconds(120));host.layoutSubtreeIfNeeded()
            #expect(host.fittingSize.width<=210 && !w.isVisible && !w.isKeyWindow)
            #expect(library.learning.result==result && library.learning.userText=="独立评论")
            w.close()
            let bookmarkHost=NSHostingView(rootView: BookmarkList(model: library.bookmarks,close: {},closeIdentifier: "refinement-close-bookmarks").frame(width: 210,height: 500).preferredColorScheme(scheme))
            let b=NSWindow(contentRect: NSRect(x: 0,y: 0,width: 210,height: 500),styleMask: [],backing: .buffered,defer: false)
            b.isReleasedWhenClosed=false;b.contentView=bookmarkHost
            bookmarkHost.layoutSubtreeIfNeeded();try await Task.sleep(for: .milliseconds(100));bookmarkHost.layoutSubtreeIfNeeded()
            #expect(bookmarkHost.fittingSize.width<=210 && !b.isVisible && !b.isKeyWindow)
            b.close()
        }
        #expect(try await library.annotations.repository.load().notes.isEmpty)
    }
}
#endif
