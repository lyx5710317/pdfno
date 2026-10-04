// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import CryptoKit
import WebKit
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders
@testable import PDFnoUI

/// Original in-code fixtures, unattached WebKit only; no visible application or user data.
@Suite(.serialized)
struct TextFormatBridgeTests {
    private func book(_ data: Data, _ format: TextFileFormat) -> TextFormatBook {
        TextFormatBook(fileSHA256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), title: "Original text fixture", originalFilename: "original." + (format == .markdown ? "md" : format.rawValue), format: format)
    }
    @Test @MainActor func actualKookitAllThreeFormatsSelectionAndReopen() async throws {
        let app = NSApplication.shared; app.setActivationPolicy(.prohibited)
        let before = app.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count
        let samples: [(TextFileFormat,String)] = [
            (.txt,"Chapter 1\r\nwindow 🌸 café <script>literal</script>\r\nChapter 2\r\nwindow second"),
            (.markdown,"# Chapter 1\n\n**window** 🌸 café [ordinary link](https://example.invalid)\n\n## Chapter 2\n\nwindow second\n\n<script>window.sourceExecuted=true</script>\n<img src='https://example.invalid/private' alt='Original image'>"),
            (.html,"<!doctype html><html><head><meta charset='utf-8'><script>window.sourceExecuted=true</script></head><body><h1>Chapter 1</h1><p onclick='window.sourceExecuted=true'><b>window</b> 🌸 café <a href='file:///private'>ordinary link</a></p><h2>Chapter 2</h2><p>window second</p><iframe src='https://example.invalid'></iframe><img src='pdfno-text://app/private' alt='Original image'><style>@import 'https://example.invalid';</style></body></html>")
        ]
        for (format, source) in samples {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Text-Bridge-" + UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            let repo = TextFormatRepository(root: root), data = Data(source.utf8)
            let book = try await repo.importBook(data, filename: format == .markdown ? "Original.MD" : "Original." + format.rawValue)
            let reader = TextFormatReaderSession(); defer { reader.close() }
            try await reader.open(data: data, book: book, notes: [])
            let doc = try #require(reader.document), web = try #require(reader.webView)
            #expect(reader.ready && web.window == nil)
            #expect(doc.outline.map(\.text) == ["Chapter 1","Chapter 2"])
            #expect(doc.outline.map(\.headingLevel) == (format == .txt ? [1,1] : [1,2]))
            if format == .txt { #expect(doc.text.contains("<script>literal</script>")) }
            else { #expect(!doc.text.contains("sourceExecuted")) }
            let safe = try await web.evaluateJavaScript("!window.sourceExecuted && !document.querySelector('main').querySelector('[href],[src],[onclick],script,iframe,object,style,img') && performance.getEntriesByType('resource').every(x=>x.name==='pdfno-text://app/engine.js')")
            #expect(safe as? Bool == true)
            _ = try await web.evaluateJavaScript("const p=document.getElementById('b1');const w=document.createTreeWalker(p,NodeFilter.SHOW_TEXT);const t=w.nextNode();const r=document.createRange();r.setStart(t,0);r.setEnd(t,6);getSelection().removeAllRanges();getSelection().addRange(r);true")
            let anchor = try #require(await reader.captureSelection())
            #expect(anchor.quote == "window" && doc.resolves(anchor))
            try await repo.bindRenderedDocument(doc, book: book)
            let note = TextFormatNote(bookID: book.id, anchor: anchor, userText: "Original persisted observation")
            try await repo.saveNote(note); try await repo.saveProgress(anchor, bookID: book.id)
            #expect(await reader.navigate(to: anchor))
            web.frame = NSRect(x: 0, y: 0, width: 430, height: 600)
            #expect(await reader.navigate(to: anchor))
            reader.close()
            let store = TextFormatRepository(root: root), state = try await store.load()
            let current = try #require(state.books.first)
            try await reader.open(data: try await store.read(current), book: current, notes: state.notes)
            #expect(reader.progress == anchor && reader.document?.resolves(anchor) == true)
            try await store.bindRenderedDocument(try #require(reader.document), book: current)
            #expect(try await store.document(current).resolves(anchor))
            #expect(try await store.read(current) == data && state.notes == [note])
            reader.close(); #expect(await reader.captureSelection() == nil && !reader.ready)
        }
        #expect(app.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count == before)
    }
    @Test @MainActor func unchapteredLiteralTXTAndCloseFenceAndStructureBudgets() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let reader = TextFormatReaderSession(); defer { reader.close() }
        let source = "Original <img src='https://example.invalid'> & 🌸\n\nSecond line"
        let data = Data(source.utf8)
        try await reader.open(data: data, book: book(data,.txt), notes: [])
        #expect(reader.document?.text == source && reader.document?.outline.isEmpty == true)
        reader.close()
        let opening = Task { @MainActor in try await reader.open(data: data, book: book(data,.txt), notes: []) }
        while reader.book == nil { await Task.yield() }
        reader.close()
        do { try await opening.value; Issue.record("Closed text generation reopened") }
        catch TextFormatError.cancelled { }
        #expect(reader.book == nil && reader.webView == nil && !reader.ready)
        for (format, source) in [(TextFileFormat.txt,String(repeating: "Original\n",count:10001)),(.html,String(repeating:"<div>",count:66)+"Original"+String(repeating:"</div>",count:66))] {
            let bytes = Data(source.utf8)
            do { try await reader.open(data: bytes,book: book(bytes,format),notes: []); Issue.record("Out of profile text rendered") }
            catch { #expect(!reader.ready && reader.document == nil && reader.webView == nil) }
        }
    }
    @Test @MainActor func routedLibraryNeverUsesHiddenPDFOrEPUBForAI() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Text-Library-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories:true)
        let file = root.appendingPathComponent("Original.HTML")
        try Data("<h1>Original title</h1><p>window original text</p>".utf8).write(to:file)
        let model = LibraryModel(root:root,aiSession:AppAISession())
        await model.load(); await model.importFile(file)
        #expect(model.textFormats.isActive && model.textFormats.books.count == 1)
        #expect(model.currentAIBookID == nil && model.captureAISource() == nil && model.capturePDFProgress() == nil)
        model.preparePageTranslation(); #expect(model.pageTranslation.plan == nil)
        let book = try #require(model.textFormats.reader.book), doc = try #require(model.textFormats.reader.document)
        let anchor = try #require(doc.anchor(book:book,start:doc.blocks[1].start,end:doc.blocks[1].start+6))
        #expect(await model.textFormats.saveNote(anchor,text:"Original local note"))
        await model.textFormats.saveProgress(anchor)
        await model.openSample()
        #expect(!model.textFormats.isActive && model.reader.book != nil)
        await model.openTextFormat(book)
        #expect(model.textFormats.isActive && model.textFormats.reader.progress == anchor && model.textFormats.notes.count == 1)
        model.textFormats.deactivate()
    }
}
#endif
