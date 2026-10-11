// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import Testing
import WebKit
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

@Suite(.serialized) @MainActor struct ReaderConversationViewportTests {
    private final class InspectorState: ObservableObject {
        @Published var panels = PDFnoReaderPanels()
    }
    private struct InspectorHost: View {
        @ObservedObject var library: LibraryModel
        @ObservedObject var state: InspectorState
        var body: some View {
            PDFnoReaderShell(panels: state.panels, profile: .professional) {
                EPUBCanvas(session: library.epub)
            } navigation: { EmptyView() } notes: {
                ReadingSelectionWorkspace(library: library) { state.panels.notes = false }
            }.annotationExperience(library.annotations, reader: .epub(library.epub), aiLibrary: library)
        }
    }
    private func settle<V: View>(_ library: LibraryModel, host: NSHostingView<V>) async throws {
        let deadline = Date().addingTimeInterval(22)
        while (library.epub.busy || library.epub.progress == nil) && Date() < deadline {
            host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(50))
        }
        try #require(!library.epub.busy && library.epub.error == nil && library.epub.progress != nil)
        host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(650))
    }
    private func viewport(_ web: WKWebView) async throws -> [String: Any] {
        try #require(try await web.callAsyncJavaScript("""
        const f=document.querySelector('iframe'),d=f.contentDocument,p=d.querySelector('[data-pdfno-spine="0"] p'),r=d.createRange();
        r.setStart(p.firstChild,0);r.setEnd(p.firstChild,6);
        const glyph=r.getBoundingClientRect(),frame=f.getBoundingClientRect(),area=document.getElementById('page-area').getBoundingClientRect();
        const top=glyph.top+frame.top,bottom=glyph.bottom+frame.top;
        const hit=d.elementFromPoint(glyph.left+Math.min(5,glyph.width/2),glyph.top+glyph.height/2);
        return {source:r.toString(),selected:d.getSelection().toString(),top,bottom,areaTop:area.top,areaBottom:area.bottom,
          scrollTop:document.getElementById('page-area').scrollTop,visible:bottom>area.top && top<area.bottom,
          clickable:hit===p || p.contains(hit)};
        """, arguments: [:], in: nil, contentWorld: .page) as? [String: Any])
    }
    @Test func originalConversationSourceRemainsVisibleAcrossInspectorWidthChanges() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Original-Conversation-Viewport-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, learningTransport: OfflineSelectionUITestTransport())
        await library.load()
        await library.openEPUBSample()
        try #require(library.epub.book != nil && library.error == nil)
        let host = NSHostingView(rootView: EPUBCanvas(session: library.epub))
        let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 1054,height: 740),styleMask: [],backing: .buffered,defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { library.epub.close(); window.close() }
        try await settle(library, host: host)
        let web = try #require(library.epub.webView)
        _ = try await web.callAsyncJavaScript("""
        const d=document.querySelector('iframe').contentDocument,p=d.querySelector('[data-pdfno-spine="0"] p'),r=d.createRange();
        r.setStart(p.firstChild,0);r.setEnd(p.firstChild,6);d.getSelection().removeAllRanges();d.getSelection().addRange(r);return true;
        """, arguments: [:], in: nil, contentWorld: .page)
        _ = try #require(await library.epub.captureSelection())
        let source = try #require(library.captureAISource())
        #expect(source.anchor.quote == "window")
        var config = AIProviderConfig(); config.mode = .mock
        #expect(await library.learning.applyConnection(config, temporarySecret: ""))
        library.conversation.open(.explain, source: source)
        let end = Date().addingTimeInterval(3)
        while library.conversation.busy && Date() < end { try await Task.sleep(for: .milliseconds(10)) }
        let answer = try #require(library.conversation.current?.answers.first)
        #expect(await library.conversation.addToNotes(answer))
        for width in [CGFloat(844),1054,844,1054] {
            let before = try await viewport(web)
            window.setContentSize(NSSize(width: width,height: 740))
            try await settle(library, host: host)
            let after = try await viewport(web)
            print("PDFNO_CONVERSATION_VIEWPORT width=\(width) before=\(before) after=\(after)")
            #expect(after["source"] as? String == "window")
            #expect(after["selected"] as? String == "window")
            #expect(after["visible"] as? Bool == true)
            #expect(library.epub.selection.map { $0.quote == "window" } == true)
            #expect(!window.isVisible && !window.isKeyWindow)
        }
    }
    @Test func actualLearningInspectorRemovalKeepsSelectedParagraphClickableAfterNativeFocus() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Original-Inspector-Focus-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, learningTransport: OfflineSelectionUITestTransport())
        await library.load(); await library.openEPUBSample()
        try #require(library.epub.book != nil && library.error == nil)
        let state = InspectorState(), host = NSHostingView(rootView: InspectorHost(library: library, state: state))
        let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 1100,height: 740),styleMask: [],backing: .buffered,defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { library.epub.close(); window.close() }
        try await settle(library, host: host)
        let web = try #require(library.epub.webView)
        _ = try await web.callAsyncJavaScript("""
        const d=document.querySelector('iframe').contentDocument,p=d.querySelector('[data-pdfno-spine="0"] p'),r=d.createRange();
        r.setStart(p.firstChild,0);r.setEnd(p.firstChild,6);d.getSelection().removeAllRanges();d.getSelection().addRange(r);return true;
        """, arguments: [:], in: nil, contentWorld: .page)
        _ = try #require(await library.epub.captureSelection())
        let source = try #require(library.captureAISource())
        var config = AIProviderConfig(); config.mode = .mock
        #expect(await library.learning.applyConnection(config, temporarySecret: ""))
        library.conversation.open(.explain, source: source)
        var deadline = Date().addingTimeInterval(3)
        while library.conversation.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        let answer = try #require(library.conversation.current?.answers.first)
        #expect(await library.conversation.addToNotes(answer))
        state.panels.show(.notes, profile: .professional)
        try await settle(library, host: host)
        func descendants(_ view: NSView) -> [NSView] { view.subviews.flatMap { [$0] + descendants($0) } }
        let controls = descendants(host)
        let input = try #require(controls.first { view in
            (view as? NSTextField).map { $0.isEditable } == true || (view as? NSTextView).map { $0.isEditable } == true
        })
        #expect(window.makeFirstResponder(input))
        library.conversation.setDraft("Original follow-up about this source"); library.conversation.sendFollowup()
        deadline = Date().addingTimeInterval(3)
        while library.conversation.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try await settle(library, host: host)
        #expect(library.conversation.current?.answers.count == 2)
        let before = try await viewport(web)
        state.panels.notes = false
        try await settle(library, host: host)
        let after = try await viewport(web)
        print("PDFNO_REAL_INSPECTOR_FOCUS before=\(before) after=\(after) responder=\(window.firstResponder.map { String(reflecting: type(of: $0)) } ?? "nil")")
        #expect(after["visible"] as? Bool == true && after["clickable"] as? Bool == true)
        #expect(after["selected"] as? String == "window")
        #expect(library.conversation.current?.answers.count == 2 && library.isCurrentAISource(source))
        #expect(!window.isVisible && !window.isKeyWindow)
    }
}
#endif
