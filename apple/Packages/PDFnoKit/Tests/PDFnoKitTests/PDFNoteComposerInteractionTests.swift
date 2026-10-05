// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import Testing
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

@MainActor struct PDFNoteComposerInteractionTests {
    @Test func realHostingComposerExposesEditorAndPreservesNativePDFSourceAndDraft() async throws {
        _ = NSApplication.shared
        let data = try originalSample()
        let book = BookRecord(title: "Original hosting input", fileSHA256: LibraryRepository.digest(data), originalFilename: "original.pdf", pageCount: 2)
        let session = PDFReaderSession(); try session.open(data: data, book: book)
        let state = NoteComposerHostingState(book: book)
        let host = NSHostingView(rootView: NoteComposerHostingFixture(session: session, state: state))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 730, height: 440), styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; defer { window.close() }
        host.frame = NSRect(x: 0, y: 0, width: 730, height: 440)
        func settle() async throws {
            host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(100)); host.displayIfNeeded()
        }
        func input(in root: NSView) -> NSTextView? {
            if let text = root as? NSTextView, text.accessibilityIdentifier() == "note-input" { return text }
            for child in root.subviews { if let found = input(in: child) { return found } }
            return nil
        }
        // SwiftUI AX bridge nodes expose AppKit's public legacy attribute transport
        // rather than protocol conformance. Production does not use this API.
        func axObjects(in root: NSObject) -> [NSObject] {
            var pending = [root], result: [NSObject] = [], seen = Set<ObjectIdentifier>()
            while let object = pending.popLast(), result.count < 2000 {
                guard seen.insert(ObjectIdentifier(object)).inserted else { continue }
                result.append(object)
                if let children = object.accessibilityAttributeValue(.children) as? [NSObject] { pending.append(contentsOf: children) }
            }
            return result
        }
        try await settle()
        let oldInput = try #require(input(in: host)), native = try #require(session.view)
        print("Synthetic original List AX exposes native editor: \(axObjects(in: host).contains { $0 === oldInput })")
        session.search("window"); session.show(try #require(session.searchMatches.first)); session.captureSelection()
        let anchor = try #require(session.capturedSelection), document = try #require(session.document), identity = session.readerSessionID
        state.composerInsideList = false; try await settle()
        let editor = try #require(input(in: host)), exposed = axObjects(in: host)
        #expect(exposed.contains { $0 === editor })
        #expect(exposed.compactMap { $0 as? NSTextView }.filter { $0.accessibilityIdentifier() == "note-input" }.count == 1)
        #expect(editor.accessibilityRole() == .textArea && editor.isEditable)
        let point = host.convert(NSPoint(x: editor.visibleRect.midX, y: editor.visibleRect.midY), from: editor)
        #expect(!editor.visibleRect.isEmpty && host.bounds.contains(point))
        // NSView.hitTest takes a point in its superview's coordinates.
        let hit = try #require(host.hitTest(host.superview?.convert(point, from: host) ?? point))
        #expect(hit === editor || hit.isDescendant(of: editor))
        #expect(session.view === native && session.document === document && session.readerSessionID == identity)
        #expect(session.capturedSelection == anchor && session.resolution(of: anchor) == .exact)
        let originalDraft = "Original hosting draft 日本語 cafe\u{301} 👩🏽‍🚀"
        #expect(state.draft.utf8.elementsEqual(originalDraft.utf8))
        state.draft = ""; try await settle()
        #expect(input(in: host) === editor && editor.string.isEmpty)
        #expect(axObjects(in: host).contains { $0 === editor })
        state.draft = originalDraft; state.panels.notes = false; try await settle()
        state.panels.notes = true; try await settle()
        let reopened = try #require(input(in: host))
        #expect(reopened.string.utf8.elementsEqual(originalDraft.utf8))
        #expect(axObjects(in: host).contains { $0 === reopened })
        #expect(session.view === native && session.document === document && session.readerSessionID == identity)
        #expect(session.capturedSelection == anchor && session.resolution(of: anchor) == .exact)
        #expect(data == (try originalSample()))
    }
}
@MainActor private final class NoteComposerHostingState: ObservableObject {
    @Published var panels = PDFnoReaderPanels()
    @Published var draft = "Original hosting draft 日本語 cafe\u{301} 👩🏽‍🚀"
    @Published var composerInsideList = true
    let anchor: PDFSourceAnchor
    init(book: BookRecord) {
        anchor = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: "window",
            regions: [PageRegion(pageIndex: 0, x: 72, y: 650, width: 40, height: 16, quote: "window")])
        panels.toggle(.notes, width: 730)
    }
}
private struct NoteComposerHostingFixture: View {
    @ObservedObject var session: PDFReaderSession
    @ObservedObject var state: NoteComposerHostingState
    var body: some View {
        PDFnoReaderShell(panels: state.panels) { PDFCanvas(session: session) } navigation: { Text("原创导航") } notes: {
            PDFnoPanel(title: "高亮与笔记", icon: "highlighter", closeIdentifier: "original-host-close", close: {}) {
                if state.composerInsideList {
                    List {
                        Section("当前选区") {
                            PDFnoTextViewport(text: state.anchor.quote)
                            NativeNoteBodyInput(text: $state.draft, identifier: "note-input", enabled: true,
                                label: "写下你的笔记（可选）").frame(height: 96)
                            if !state.draft.isEmpty { PDFnoStatusMessage(text: "草稿未保存 · 关闭面板会保留，保存成功后清空") }
                            Button("保存高亮与笔记") {}.buttonStyle(PDFnoActionStyle(role: .primary)).accessibilityIdentifier("save-note")
                        }
                        Section("已保存 · 本地") { Text("这本书还没有笔记") }
                    }.font(PDFnoDesign.TypeStyle.body).accessibilityIdentifier("pdf-notes-list")
                } else {
                    VStack(spacing: 0) {
                        PDFNoteComposer(anchor: state.anchor, draft: $state.draft, enabled: true) { _, _ in false }
                        Divider(); List { Section("已保存 · 本地") { Text("这本书还没有笔记") } }
                    }.font(PDFnoDesign.TypeStyle.body).accessibilityIdentifier("pdf-notes-list")
                }
            }
        }
    }
}
#endif
