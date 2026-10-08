// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import WebKit
import Testing
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

/// Checks the actual native viewport against the inspector, not just layout arithmetic.
@Suite(.serialized) @MainActor
struct ReaderViewportRegressionTests {
    @Test func PDFInspectorDoesNotCoverNativeBodyAndPreservesSourceAndDraft() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let data = try originalSample(), session = PDFReaderSession(), state = ViewportState()
        try session.open(data: data, book: BookRecord(title: "Original viewport", fileSHA256: LibraryRepository.digest(data), originalFilename: "original.pdf", pageCount: 2))
        let host = NSHostingView(rootView: ViewportHost(state: state) { PDFCanvas(session: session) })
        let window = mount(host)
        defer { window.close() }
        await settle(host)
        session.search("window"); session.show(try #require(session.searchMatches.first)); session.captureSelection()
        let native = try #require(session.view), document = try #require(session.document)
        let source = try #require(session.capturedSelection), identity = session.readerSessionID
        for width in [CGFloat(720), 1280, 720] {
            for scheme in [ColorScheme.light, .dark] {
                state.scheme = scheme; state.width = width; state.panels.show(.notes)
                window.setContentSize(NSSize(width: width, height: 520)); await settle(host)
                checkViewport(native, state: state, host: host, window: window)
                #expect(session.view === native && session.document === document && session.readerSessionID == identity)
                #expect(session.capturedSelection == source && session.resolution(of: source) == .exact)
                #expect(session.pageIndex == 0 && session.book?.pageCount == 2)
                #expect(state.draft.utf8.elementsEqual(ViewportState.originalDraft.utf8))
                state.panels.notes = false; await settle(host)
                #expect(native.convert(native.bounds, to: host).width > 650)
            }
        }
        #expect(data == (try originalSample()))
    }

    @Test func EPUBReflowKeepsActualDOMSelectionAndUncoveredViewport() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let data = try publication(), session = EPUBReaderSession(), state = ViewportState()
        let book = EPUBBook(fileSHA256: LibraryRepository.digest(data), title: "Original viewport", originalFilename: "original.epub")
        try await session.open(data: data, book: book, notes: [])
        let host = NSHostingView(rootView: ViewportHost(state: state) { EPUBCanvas(session: session) })
        let window = mount(host)
        defer { session.close(); window.close() }
        let deadline = Date().addingTimeInterval(20)
        while (session.busy || session.progress == nil) && Date() < deadline { await settle(host) }
        try #require(session.error == nil && session.progress != nil)
        let web = try #require(session.webView), identity = session.readerSessionID
        _ = try await web.callAsyncJavaScript("""
          const d=document.querySelector('iframe').contentDocument, p=d.querySelector('p'), r=d.createRange();
          r.setStart(p.firstChild,0);r.setEnd(p.firstChild,6);
          d.getSelection().removeAllRanges();d.getSelection().addRange(r);return 'selected';
          """, arguments: [:], in: nil, contentWorld: .page)
        let selectedDeadline = Date().addingTimeInterval(3)
        while session.selection == nil && Date() < selectedDeadline { await settle(host) }
        let source = try #require(session.selection)
        #expect(source.quote == "window")
        for width in [CGFloat(720), 1280, 720] {
            for scheme in [ColorScheme.light, .dark] {
                state.scheme = scheme; state.width = width; state.panels.show(.notes)
                window.setContentSize(NSSize(width: width, height: 520)); await settle(host)
                checkViewport(web, state: state, host: host, window: window)
                #expect(session.webView === web && session.readerSessionID == identity && session.book?.id == book.id)
                #expect(session.selection == source && session.spineIndex == 0 && session.position.contains("第 1 页"))
                let quote = try await web.callAsyncJavaScript("return document.querySelector('iframe').contentDocument.getSelection().toString();", arguments: [:], in: nil, contentWorld: .page) as? String
                #expect(quote == source.quote)
                #expect(state.draft.utf8.elementsEqual(ViewportState.originalDraft.utf8))
                state.panels.notes = false; await settle(host)
                #expect(session.selection == source)
            }
        }
        #expect(data == (try publication()))
    }

    private func checkViewport<V: View>(_ native: NSView, state: ViewportState, host: NSHostingView<V>, window: NSWindow) {
        let reader = native.convert(native.bounds, to: host), inspector = state.inspector.convert(state.inspector.bounds, to: host)
        #expect(reader.width >= 420 && reader.height > 200)
        #expect(inspector.width >= 210 && inspector.height > 200)
        #expect(reader.maxX <= inspector.minX + 0.5)
        #expect(!reader.intersects(inspector))
        #expect(!window.isVisible && !window.isKeyWindow)
    }
    private func mount<V: View>(_ host: NSHostingView<V>) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520), styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host; return window
    }
    private func settle<V: View>(_ host: NSHostingView<V>) async {
        host.layoutSubtreeIfNeeded(); try? await Task.sleep(for: .milliseconds(800)); host.layoutSubtreeIfNeeded()
    }
    private func publication() throws -> Data {
        try ConversionFixture.zip([
            ("mimetype", Data("application/epub+zip".utf8)),
            ("META-INF/container.xml", Data("<container xmlns='urn:oasis:names:tc:opendocument:xmlns:container'><rootfiles><rootfile full-path='book.opf' media-type='application/oebps-package+xml'/></rootfiles></container>".utf8)),
            ("book.opf", Data("<package xmlns='http://www.idpf.org/2007/opf' version='3.0' unique-identifier='id'><metadata xmlns:dc='http://purl.org/dc/elements/1.1/'><dc:identifier id='id'>original-viewport</dc:identifier><dc:title>Original viewport</dc:title><dc:language>en</dc:language></metadata><manifest><item id='one' href='one.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='one'/></spine></package>".utf8)),
            ("one.xhtml", Data("<html xmlns='http://www.w3.org/1999/xhtml'><head><title>Original viewport</title></head><body><p>window · Original reading paragraph 日本語 café 🌸.</p><p>Original second paragraph keeps its source.</p></body></html>".utf8))
        ], deflated: false)
    }
}
@MainActor private final class ViewportState: ObservableObject {
    static let originalDraft = "Original unsaved 日本語 cafe\u{301} 👩🏽‍🚀"
    @Published var panels = PDFnoReaderPanels()
    @Published var width: CGFloat = 720
    @Published var scheme = ColorScheme.light
    @Published var draft = originalDraft
    let inspector = NSView()
}
private struct ViewportInspector: NSViewRepresentable {
    let view: NSView
    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ view: NSView, context: Context) {}
}
private struct ViewportHost<Reader: View>: View {
    @ObservedObject var state: ViewportState
    @ViewBuilder let reader: () -> Reader
    var body: some View {
        PDFnoProfessionalReaderChrome(title: "Original viewport", format: "LOCAL") { Text("1 / 2") } actions: { Text("A") } content: {
            PDFnoReaderShell(panels: state.panels, profile: .professional, reader: reader) { Text("Original contents") } notes: {
                ViewportInspector(view: state.inspector).overlay(alignment: .top) { TextField("Original draft", text: $state.draft) }
            }
        }.frame(width: state.width, height: 520).preferredColorScheme(state.scheme)
    }
}
#endif
