// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import WebKit
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders
@testable import PDFnoUI

/// Unattached WKWebViews only: neither PDFno.app nor desktop UI is launched.
@Suite(.serialized)
struct WebArchiveBridgeTests {
    @Test @MainActor func realKookitHTMLRouteAllThreeFormatsExactNotesProgressAndReopen() async throws {
        let app = NSApplication.shared; app.setActivationPolicy(.prohibited)
        let visibleBefore = app.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count
        for (format, data) in [(TextFileFormat.xhtml, Data(OriginalWebArchiveFixtures.xhtml.utf8)),
                                (.mhtml, OriginalWebArchiveFixtures.mhtml), (.xml, Data(OriginalWebArchiveFixtures.xml.utf8))] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-WebArchive-Bridge-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let repository = TextFormatRepository(root: root)
            let book = try await repository.importBook(data, filename: "Original." + format.rawValue.uppercased())
            let reader = TextFormatReaderSession(); defer { reader.close() }
            try await reader.open(data: data, book: book, notes: [])
            let document = try #require(reader.document), web = try #require(reader.webView)
            #expect(reader.ready && web.window == nil && document.outline.map(\.text) == ["Chapter 1", "Chapter 2"])
            #expect(document.outline.map(\.headingLevel) == [1,2])
            #expect(document.text.contains("日本語🌸 café & literal"))
            #expect(!document.text.contains("sourceExecuted"))
            #expect(document.warnings.contains { $0.contains("归档") || $0.contains("XML") })
            let inert = try await web.evaluateJavaScript("!window.sourceExecuted && !document.querySelector('main').querySelector('[href],[src],[onclick],script,style,iframe,object,img') && performance.getEntriesByType('resource').every(x=>x.name==='pdfno-text://app/engine.js')")
            #expect(inert as? Bool == true)
            _ = try await web.evaluateJavaScript("const p=document.getElementById('b1');const n=document.createTreeWalker(p,NodeFilter.SHOW_TEXT).nextNode();const r=document.createRange();r.setStart(n,0);r.setEnd(n,6);getSelection().removeAllRanges();getSelection().addRange(r);true")
            let anchor = try #require(await reader.captureSelection())
            #expect(anchor.quote == "window" && document.resolves(anchor))
            try await repository.bindRenderedDocument(document, book: book)
            let note = TextFormatNote(bookID: book.id, anchor: anchor, userText: "Original archive observation")
            try await repository.saveNote(note)
            #expect(await reader.navigate(blockID: 2))
            let progress = try #require(reader.progress)
            #expect(progress.blockID == 2 && progress.quote == "C")
            try await repository.saveProgress(progress, bookID: book.id)
            #expect(await reader.navigate(to: anchor))
            web.frame = NSRect(x: 0, y: 0, width: 420, height: 600)
            #expect(await reader.navigate(to: anchor))
            let scalars = document.text as NSString
            let flower = scalars.range(of: "🌸")
            #expect(document.anchor(book: book, start: flower.location + 1, end: flower.location + 2) == nil)
            let cross = try #require(document.anchor(book: book, start: anchor.start, end: document.blocks[2].start + 7))
            #expect(cross.quote.contains("\nChapter") && document.resolves(cross))
            reader.close()
            let store = TextFormatRepository(root: root), state = try await store.load(), current = try #require(state.books.first)
            try await reader.open(data: try await store.read(current), book: current, notes: state.notes)
            #expect(reader.progress == progress && state.notes == [note])
            #expect(await reader.navigate(to: note.anchor))
            #expect(try await store.read(current) == data)
            reader.close(); #expect(await reader.captureSelection() == nil && !reader.ready)
        }
        #expect(app.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count == visibleBefore)
    }
    @Test @MainActor func libraryRoutingUnchapteredContentAndHiddenAIRefusal() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        for (name, bytes) in [("Original.xhtml", Data("<html xmlns='http://www.w3.org/1999/xhtml'><body><p>window unchaptered 🌸</p></body></html>".utf8)),
                              ("Original.mhtml", OriginalWebArchiveFixtures.archive([OriginalWebArchiveFixtures.part(Data("<p>window unchaptered 🌸</p>".utf8))])),
                              ("Original.xml", Data("<document><p>window unchaptered 🌸</p></document>".utf8))] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-WebArchive-Library-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let source = root.appendingPathComponent(name); try bytes.write(to: source)
            let model = LibraryModel(root: root, aiSession: AppAISession())
            await model.load(); await model.importFile(source)
            #expect(model.error == nil && model.textFormats.isActive && model.textFormats.books.count == 1)
            #expect(model.textFormats.reader.document?.outline.isEmpty == true)
            #expect(model.textFormats.reader.document?.text == "window unchaptered 🌸")
            #expect(model.currentAIBookID == nil && model.captureAISource() == nil && model.capturePDFProgress() == nil)
            model.preparePageTranslation(); #expect(model.pageTranslation.plan == nil)
            await model.prepareChapterTranslation(); #expect(model.chapterTranslation.plan == nil)
            let book = try #require(model.textFormats.reader.book), document = try #require(model.textFormats.reader.document)
            let anchor = try #require(document.anchor(book: book, start: 0, end: 6))
            #expect(await model.textFormats.saveNote(anchor, text: "Original note"))
            await model.textFormats.saveProgress(anchor)
            await model.openSample(); #expect(!model.textFormats.isActive && model.reader.book != nil)
            await model.openTextFormat(book)
            #expect(model.textFormats.isActive && model.textFormats.reader.progress == anchor && model.textFormats.notes.count == 1)
            #expect(try Data(contentsOf: source) == bytes)
            model.textFormats.deactivate()
        }
    }
}
#endif
