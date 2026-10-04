// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders
@testable import PDFnoUI

/// Real offscreen WebKit acceptance to run on isolated CI; no user app/process/documents.
@Suite(.serialized)
struct EbookReaderTests {
    @Test(arguments: EbookFormat.allCases) @MainActor
    func actualKookitSourceNotesAndProgressReopen(format: EbookFormat) async throws {
        _ = NSApplication.shared
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Ebook-WebKit-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = try #require(Bundle.module.url(forResource: "study-sample", withExtension: format.rawValue, subdirectory: "Fixtures/Ebooks"))
        let original = try Data(contentsOf: url), model = EbookLibraryModel(root: root)
        defer { model.deactivate() }
        try await model.importFile(url)
        let book = try #require(model.reader.book), doc = try #require(model.reader.document), web = try #require(model.reader.webView)
        #expect(book.format == format && model.isActive && model.reader.ready && doc.isValid)
        #expect(doc.outline.count >= 2 && doc.text.contains("😀") && doc.text.contains("e\u{301}"))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = web
        defer { window.close() }
        let selected = try await web.evaluateJavaScript("""
        const p=document.querySelectorAll('[data-block]')[1];
        const w=document.createTreeWalker(p,NodeFilter.SHOW_TEXT);const n=w.nextNode();
        const r=document.createRange();r.setStart(n,0);r.setEnd(n,Math.min(4,n.length));
        getSelection().removeAllRanges();getSelection().addRange(r);window.pdfnoEbook.captureSelection();
        """)
        #expect(selected != nil)
        let anchor = try #require(await model.reader.captureSelection())
        #expect(book.accepts(anchor) && doc.resolves(anchor))
        #expect(await model.saveNote(anchor, text: "Original WebKit note"))
        let last = try #require(doc.navigationBlocks.last)
        #expect(await model.reader.navigate(blockID: last.id))
        let progress = try #require(model.reader.progress); await model.saveProgress(progress)
        let restored = EbookLibraryModel(root: root); defer { restored.deactivate() }
        try await restored.load(); try await restored.open(try #require(restored.books.first))
        #expect(restored.reader.progress == progress && restored.notes.first?.anchor == anchor)
        #expect(await restored.reader.navigate(to: anchor))
        #expect(try await restored.repository.read(book) == original)
        #expect(!window.isVisible)
    }
    @Test @MainActor func activeEbookRefusesHiddenPDFSources() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Ebook-Route-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root); await library.load()
        let url = try #require(Bundle.module.url(forResource: "study-sample", withExtension: "fb2", subdirectory: "Fixtures/Ebooks"))
        await library.importFile(url)
        defer { library.ebook.deactivate() }
        #expect(library.error == nil && library.ebook.isActive)
        #expect(library.capturePDFProgress() == nil && library.captureAISource() == nil && library.currentAIBookID == nil)
    }
}
#endif
