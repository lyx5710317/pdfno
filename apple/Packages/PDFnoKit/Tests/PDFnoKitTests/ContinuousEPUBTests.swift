// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import WebKit
import Testing
import PDFnoDomain
import PDFnoReaders
import PDFnoServices

@Suite(.serialized) @MainActor struct ContinuousEPUBTests {
    @Test func realWebKitScrollsAcrossMountedChaptersAndReopensTheSameSource() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let data = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/study-sample.epub"))
        var book = EPUBBook(fileSHA256: LibraryRepository.digest(data), title: "Original continuous fixture", originalFilename: "original.epub")
        let session = EPUBReaderSession()
        try await session.open(data: data, book: book, notes: [])
        let host = NSHostingView(rootView: EPUBCanvas(session: session))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520), styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { session.close(); window.close() }
        try await ready(session, host: host)
        let web = try #require(session.webView)
        let count = try await web.callAsyncJavaScript("return document.querySelector('iframe').contentDocument.querySelectorAll('[data-pdfno-spine]').length;", arguments: [:], in: nil, contentWorld: .page) as? Int
        #expect(count == 2)
        _ = try await web.callAsyncJavaScript("const d=document.querySelector('iframe').contentDocument, second=d.querySelector('[data-pdfno-spine=\"1\"]'); document.getElementById('page-area').scrollTo(0,second.offsetTop+120); return true;", arguments: [:], in: nil, contentWorld: .page)
        let deadline = Date().addingTimeInterval(4)
        while session.spineIndex != 1 && Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
        #expect(session.spineIndex == 1 && session.position.contains("第 2 章"))
        let source = try #require(session.progress); #expect(source.resourceHref.contains("japanese.xhtml"))
        book.progress = source
        session.close(); try await session.open(data: data, book: book, notes: [])
        try await ready(session, host: host)
        #expect(session.spineIndex == 1 && session.progress?.resourceHref == source.resourceHref)
        #expect(session.webView !== web)
        #expect(!window.isVisible && !window.isKeyWindow)
    }
    @Test func realWebKitOrientationToggleKeepsTheCanonicalChapter() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let data = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/study-sample.epub"))
        let session = EPUBReaderSession(), book = EPUBBook(fileSHA256: LibraryRepository.digest(data), title: "Original orientation fixture", originalFilename: "original.epub")
        try await session.open(data: data, book: book, notes: [])
        let host = NSHostingView(rootView: EPUBCanvas(session: session))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520), styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { session.close(); window.close() }
        try await ready(session, host: host)
        let original = try #require(session.progress)
        #expect(await session.command("vertical")); #expect(session.vertical && session.spineIndex == original.spineIndex)
        let web = try #require(session.webView)
        let verticalMode = try await web.callAsyncJavaScript("const d=document.querySelector('iframe').contentDocument;return d.defaultView.getComputedStyle(d.documentElement).writingMode;", arguments: [:], in: nil, contentWorld: .page) as? String
        #expect(verticalMode == "vertical-rl")
        #expect(await session.command("vertical")); #expect(!session.vertical && session.spineIndex == original.spineIndex)
        let horizontalMode = try await web.callAsyncJavaScript("const d=document.querySelector('iframe').contentDocument;return d.defaultView.getComputedStyle(d.documentElement).writingMode;", arguments: [:], in: nil, contentWorld: .page) as? String
        #expect(horizontalMode == "horizontal-tb")
        #expect(session.progress?.resourceHref == original.resourceHref && session.error == nil)
        #expect(!window.isVisible && !window.isKeyWindow)
    }
    private func ready<V: View>(_ session: EPUBReaderSession, host: NSHostingView<V>) async throws {
        let deadline = Date().addingTimeInterval(22)
        while (session.busy || session.progress == nil) && Date() < deadline {
            host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(50))
        }
        try #require(!session.busy && session.error == nil && session.progress != nil)
    }
}
#endif
