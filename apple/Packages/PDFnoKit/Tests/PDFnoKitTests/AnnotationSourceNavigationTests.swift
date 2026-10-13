// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import WebKit
import Testing
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

@Suite(.serialized) @MainActor struct AnnotationSourceNavigationTests {
    @Test func EPUBSourceReturnWaitsForActualReaderResizeWithoutLosingExactAnchor() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Annotation-Ready-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession())
        await library.load(); await library.openEPUBSample()
        let reader = library.epub, web = try #require(reader.webView)
        NSApplication.shared.setActivationPolicy(.prohibited)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 720, height: 520), styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = web
        web.frame = NSRect(x: 0, y: 0, width: 720, height: 520)
        defer { reader.close(); window.close() }
        let deadline = Date().addingTimeInterval(20)
        while reader.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(!reader.busy)
        // Use the engine's real canonical progress anchor, not a whole-spine
        // translation extraction (the long original fixture exceeds that cap).
        let anchor = try #require(reader.progress), bookID = try #require(reader.book?.id)
        try #require(!anchor.quote.isEmpty && reader.book?.accepts(anchor) == true)
        let record = AnchoredAnnotation(bookID: bookID, anchor: .epub(anchor), kind: .note)
        let model = AnnotationModel(root: root); await model.bind(.epub(reader))
        // Delay only this original hidden reader's actual resize command.
        // No selection, saved record, response or readiness state is fabricated.
        _ = try await web.callAsyncJavaScript("""
            const original = window.PDFno.command;
            window.PDFno.command = async function(message) {
                if (message.command === 'resize') await new Promise(resolve => setTimeout(resolve, 120));
                return await original(message);
            };
            return true;
            """, arguments: [:], in: nil, contentWorld: .page)
        let resizing = Task { await reader.command("resize") }
        await Task.yield(); try #require(reader.busy)
        await model.navigate(record)
        #expect(await resizing.value)
        #expect(model.status == "已定位原文" && model.error == nil)
        #expect(reader.selection?.quote == anchor.quote && reader.selection?.start == anchor.start && reader.selection?.end == anchor.end)
        #expect(!window.isVisible && !window.isKeyWindow)
        #expect(try await model.repository.load().notes.isEmpty)
    }
}
#endif
