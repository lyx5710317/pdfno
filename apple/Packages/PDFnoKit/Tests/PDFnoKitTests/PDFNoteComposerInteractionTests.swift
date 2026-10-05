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
        func oldInput(in root: NSView) -> NSTextView? {
            if let text = root as? NSTextView, text.accessibilityIdentifier() == "note-input" { return text }
            for child in root.subviews { if let found = oldInput(in: child) { return found } }
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
        func identifier(_ object: NSObject) -> String? {
            // The public getter also works for AX bridge objects that do not
            // declare protocol conformance or forward the legacy attribute.
            let getter = #selector(NSAccessibilityProtocol.accessibilityIdentifier)
            guard object.responds(to: getter) else { return nil }
            return object.perform(getter)?.takeUnretainedValue() as? String
        }
        try await settle()
        let originalInput = try #require(oldInput(in: host)), native = try #require(session.view)
        print("Synthetic original List AX exposes native editor: \(axObjects(in: host).contains { $0 === originalInput })")
        session.search("window"); session.show(try #require(session.searchMatches.first)); session.captureSelection()
        let anchor = try #require(session.capturedSelection), document = try #require(session.document), identity = session.readerSessionID
        state.composerInsideList = false; try await settle()
        func exposedEditor() throws -> NSObject {
            let fields = axObjects(in: host).filter {
                let role = $0.accessibilityAttributeValue(.role) as? String
                return role == NSAccessibility.Role.textField.rawValue || role == NSAccessibility.Role.textArea.rawValue
            }
            #expect(fields.count == 1)
            let field = try #require(fields.first)
            #expect(field.accessibilityAttributeValue(.enabled) as? Bool == true)
            #expect(identifier(field) == "note-input")
            return field
        }
        func value(_ field: NSObject) throws -> String {
            try #require(field.accessibilityAttributeValue(.value) as? String)
        }
        func verifyHit(_ field: NSObject) throws {
            let origin = try #require(field.accessibilityAttributeValue(.position) as? NSValue).pointValue
            let size = try #require(field.accessibilityAttributeValue(.size) as? NSValue).sizeValue
            let frame = NSRect(origin: origin, size: size)
            #expect(!frame.isEmpty)
            let point = NSPoint(x: frame.midX, y: frame.midY)
            let inHost = host.convert(window.convertPoint(fromScreen: point), from: nil)
            #expect(host.bounds.contains(inHost))
            let hit = try #require(window.accessibilityHitTest(point) as? NSObject)
            #expect(hit.accessibilityAttributeValue(.role) as? String == field.accessibilityAttributeValue(.role) as? String)
            #expect(identifier(hit) == "note-input")
            #expect(hit === field)
            #expect(try value(hit) == value(field))
        }
        let editor = try exposedEditor()
        #expect(try value(editor).utf8.elementsEqual(state.draft.utf8))
        try verifyHit(editor)
        #expect(session.view === native && session.document === document && session.readerSessionID == identity)
        #expect(session.capturedSelection == anchor && session.resolution(of: anchor) == .exact)
        let originalDraft = "Original hosting draft 日本語 cafe\u{301} 👩🏽‍🚀"
        #expect(state.draft.utf8.elementsEqual(originalDraft.utf8))
        state.draft = ""; try await settle()
        let emptyEditor = try exposedEditor()
        #expect(try value(emptyEditor).isEmpty)
        try verifyHit(emptyEditor)
        state.draft = originalDraft; state.panels.notes = false; try await settle()
        state.panels.notes = true; try await settle()
        let reopened = try exposedEditor()
        #expect(try value(reopened).utf8.elementsEqual(originalDraft.utf8))
        try verifyHit(reopened)
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
                        Divider(); List { Section("已保存 · 本地") { Text("这本书还没有笔记") } }.accessibilityIdentifier("pdf-notes-list")
                    }.font(PDFnoDesign.TypeStyle.body)
                }
            }
        }
    }
}
#endif
