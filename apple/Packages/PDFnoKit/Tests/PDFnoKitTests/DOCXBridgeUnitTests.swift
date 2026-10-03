// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import CryptoKit
import WebKit
import Testing
import PDFnoDomain
import PDFnoReaders

/// A separate unit-test process and unattached WKWebView only. No explicit NSWindow construction, visible window,
/// application launch, screen capture, accessibility automation or real library.
@Suite(.serialized)
struct DOCXBridgeUnitTests {
    @Test @MainActor func closeCancelsAnOpeningGenerationBeforeItCanReactivate() async throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        let visibleBefore = application.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count
        let url = try #require(Bundle.module.url(forResource: "mammoth-sample", withExtension: "docx", subdirectory: "Fixtures/DOCX"))
        let data = try Data(contentsOf: url)
        let book = DOCXBook(fileSHA256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), title: "Cancelled original fixture", originalFilename: "mammoth-sample.docx")
        let reader = DOCXReaderSession(); defer { reader.close() }
        let opening = Task { @MainActor in try await reader.open(data: data, book: book, notes: []) }
        // The request publishes its identity before native preflight/engine readiness can suspend it.
        let deadline = Date().addingTimeInterval(5)
        while reader.book == nil && Date() < deadline { await Task.yield() }
        _ = try #require(reader.book)
        reader.close()
        do { try await opening.value; Issue.record("A closed generation reopened the reader") }
        catch DOCXError.cancelled { }
        catch { Issue.record("Unexpected close result: \(error)") }
        #expect(reader.book == nil && reader.webView == nil && reader.document == nil && !reader.ready)
        #expect(application.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count == visibleBefore)
        #expect(application.activationPolicy() == .prohibited)
    }
    @Test @MainActor func offscreenActualMammothBootstrapSelectionAndReturn() async throws {
        let application = NSApplication.shared
        application.setActivationPolicy(.prohibited)
        let visibleBefore = application.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count
        let url = try #require(Bundle.module.url(forResource: "hyperlink-sample", withExtension: "docx", subdirectory: "Fixtures/DOCX"))
        let data = try Data(contentsOf: url)
        let book = DOCXBook(fileSHA256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), title: "Original offscreen unit fixture", originalFilename: "hyperlink-sample.docx")
        let reader = DOCXReaderSession(); defer { reader.close() }
        try await reader.open(data: data, book: book, notes: [])
        #expect(application.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count == visibleBefore)
        #expect(application.activationPolicy() == .prohibited)
        #expect(reader.ready && reader.error == nil)
        let document = try #require(reader.document), web = try #require(reader.webView)
        #expect(web.window == nil)
        print("DOCX offscreen unit: unattached WKWebView; visible/key/main windows =", application.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count, "; activation prohibited")
        #expect(document.outline.map(\.headingLevel) == [1,2])
        #expect(document.text.contains("Ordinary hyperlink label"))
        let safe = try await web.evaluateJavaScript("!document.querySelector('main').querySelector('[href],[src],[onload],script,iframe,object') && performance.getEntriesByType('resource').every(x=>x.name==='pdfno-docx://app/engine.js')")
        #expect(safe as? Bool == true)
        _ = try await web.evaluateJavaScript("const p=document.getElementById('b1');const t=p.querySelector('strong').firstChild;const r=document.createRange();r.setStart(t,0);r.setEnd(t,6);getSelection().removeAllRanges();getSelection().addRange(r);document.dispatchEvent(new Event('selectionchange'));true")
        let deadline = Date().addingTimeInterval(5)
        while reader.selection == nil && Date() < deadline { try await Task.sleep(for: .milliseconds(20)) }
        let anchor = try #require(reader.selection)
        #expect(anchor.quote == "window" && document.resolves(anchor))
        #expect(await reader.captureSelection() == anchor)
        // The unattached fixture has no document focus. Simulate the DOM's
        // collapse on native toolbar blur, preserving the actual prior range.
        _ = try await web.evaluateJavaScript("getSelection().removeAllRanges();document.dispatchEvent(new Event('selectionchange'));true")
        #expect(await reader.captureSelection() == anchor)
        // A deliberate deselection in a focused document must clear the range.
        _ = try await web.evaluateJavaScript("Object.defineProperty(document,'hasFocus',{configurable:true,value:()=>true});document.dispatchEvent(new Event('selectionchange'));true")
        #expect(await reader.captureSelection() == nil)
        #expect(await reader.navigate(to: anchor))
        reader.project([DOCXNote(bookID: book.id, anchor: anchor, userText: "Original isolated note")])
        let token = reader.readerSessionID
        reader.close()
        let staleReturn = await reader.navigate(to: anchor)
        #expect(reader.readerSessionID != token && !staleReturn)
        #expect(await reader.captureSelection() == nil)
        #expect(application.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count == visibleBefore)
        #expect(application.activationPolicy() == .prohibited)
    }
}
#endif
