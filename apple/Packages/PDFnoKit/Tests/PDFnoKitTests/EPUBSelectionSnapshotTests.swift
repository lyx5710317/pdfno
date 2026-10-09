// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

@Suite(.serialized) @MainActor struct EPUBSelectionSnapshotTests {
    @Test func readonlyChapterPreviewKeepsActualSelectedRangeAndReaderIdentity() async throws {
        let body = "window 原创阅读 日本語 café"
        let data = try ConversionFixture.zip([
            ("mimetype", Data("application/epub+zip".utf8)),
            ("META-INF/container.xml", Data("<container xmlns='urn:oasis:names:tc:opendocument:xmlns:container'><rootfiles><rootfile full-path='book.opf' media-type='application/oebps-package+xml'/></rootfiles></container>".utf8)),
            ("book.opf", Data("<package xmlns='http://www.idpf.org/2007/opf' version='3.0' unique-identifier='id'><metadata xmlns:dc='http://purl.org/dc/elements/1.1/'><dc:identifier id='id'>original-readonly-selection</dc:identifier><dc:title>Original selection</dc:title><dc:language>en</dc:language></metadata><manifest><item id='one' href='one.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='one'/></spine></package>".utf8)),
            ("one.xhtml", Data("<html xmlns='http://www.w3.org/1999/xhtml'><head><title>Original</title></head><body><p>\(body)</p></body></html>".utf8))
        ], deflated: false)
        _ = NSApplication.shared
        let session = EPUBReaderSession(), book = EPUBBook(fileSHA256: LibraryRepository.digest(data), title: "Original", originalFilename: "original.epub")
        try await session.open(data: data, book: book, notes: [])
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = session.webView
        defer { session.close(); window.close() }
        let deadline = Date().addingTimeInterval(20)
        while session.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(40)) }
        try #require(session.error == nil && session.progress != nil)
        let snapshot = try await session.currentChapterTextSnapshot()
        let plan = try EPUBChapterTranslationPlan(snapshot: snapshot)
        guard case .epubChapter(let anchor) = try #require(plan.sources.first).anchor else { Issue.record("Missing canonical source"); return }
        #expect(await session.command("navigate", anchor: anchor))
        let selected = try #require(session.selection), identity = session.readerSessionID, version = session.documentVersion
        // Reproduce native menu focus collapsing the live DOM range while the
        // immutable native source is still retained. The reply must validate
        // and acknowledge the rebound actual range, without navigation.
        _ = try await session.webView?.callAsyncJavaScript("document.querySelector('iframe').contentDocument.getSelection().removeAllRanges(); return true", arguments: [:], in: nil, in: .page)
        for _ in 0..<3 {
            let preview = try await session.currentChapterTextSnapshot()
            #expect(preview.text == snapshot.text && preview.resourceHref == "one.xhtml")
            #expect(session.selection == selected && session.readerSessionID == identity && session.documentVersion == version)
        }
        #expect(!window.isVisible)
    }
}
#endif
