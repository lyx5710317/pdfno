// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import WebKit
import CryptoKit
import Testing
import PDFnoDomain
import PDFnoReaders

@Suite(.serialized)
struct EPUBWebKitTests {
    @MainActor private func opened(_ filename: String) async throws -> (EPUBReaderSession, NSWindow) {
        _ = NSApplication.shared
        let url = try #require(Bundle.module.url(forResource: filename, withExtension: "epub", subdirectory: "Fixtures"))
        let data = try Data(contentsOf: url), hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return try await opened(data: data, book: EPUBBook(fileSHA256: hash, title: "Original test", originalFilename: filename + ".epub"))
    }
    @MainActor private func opened(data: Data, book: EPUBBook) async throws -> (EPUBReaderSession, NSWindow) {
        let session = EPUBReaderSession()
        try await session.open(data: data, book: book, notes: [])
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = session.webView
        session.webView?.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        let deadline = Date().addingTimeInterval(20)
        while session.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
        guard session.error == nil, session.progress != nil else {
            window.close(); session.close(); throw EPUBError.bridge
        }
        return (session, window)
    }
    private func originalPublication(_ text: String, suffix: String = "xhtml", mime: String = "application/xhtml+xml") throws -> Data {
        let name = "chapter." + suffix
        return try ConversionFixture.zip([
            ("mimetype", Data("application/epub+zip".utf8)),
            ("META-INF/container.xml", Data("<container xmlns=\"urn:oasis:names:tc:opendocument:xmlns:container\"><rootfiles><rootfile full-path=\"book.opf\" media-type=\"application/oebps-package+xml\"/></rootfiles></container>".utf8)),
            ("book.opf", Data("<package xmlns=\"http://www.idpf.org/2007/opf\" version=\"3.0\" unique-identifier=\"id\"><metadata xmlns:dc=\"http://purl.org/dc/elements/1.1/\"><dc:identifier id=\"id\">original-audit</dc:identifier><dc:title>Original audit</dc:title><dc:language>en</dc:language></metadata><manifest><item id=\"chapter\" href=\"\(name)\" media-type=\"\(mime)\"/></manifest><spine><itemref idref=\"chapter\"/></spine></package>".utf8)),
            (name, Data("<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>Original</title></head><body><p>\(text)</p></body></html>".utf8))
        ], deflated: false)
    }
    @Test @MainActor func longParagraphSecondAndThirdPagesRestoreExactVisibleOffsetsAndReopen() async throws {
        let data = try originalPublication(String(repeating: "Original sentence about a garden. ", count: 300))
        var book = EPUBBook(fileSHA256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), title: "Original long paragraph", originalFilename: "original.epub")
        let (session,window) = try await opened(data: data, book: book)
        defer { session.close();window.close() }
        let first = try #require(session.progress)
        #expect(await session.command("next"));let second = try #require(session.progress)
        #expect(session.position.contains("第 2 页") && second.start > first.start)
        #expect(await session.command("next"));let third = try #require(session.progress)
        #expect(session.position.contains("第 3 页") && third.start > second.start)
        #expect(await session.command("navigate",anchor: second));#expect(session.position.contains("第 2 页"))
        #expect(await session.command("navigate",anchor: third));#expect(session.position.contains("第 3 页"))
        #expect(await session.command("resize"));#expect(session.position.contains("第 3 页"))
        window.setContentSize(NSSize(width: 640,height: 480))
        #expect(await session.command("navigate",anchor: third))
        let selected = try await probe(session,"const d=document.querySelector('iframe').contentDocument;return d.getSelection().toString();")
        #expect(selected == third.quote)
        window.setContentSize(NSSize(width: 800,height: 600))
        #expect(await session.command("navigate",anchor: third));#expect(session.position.contains("第 3 页"))
        let verticalStart = EPUBAnchor(editionID: first.editionID,fileSHA256: first.fileSHA256,resourceHref: first.resourceHref,spineIndex: first.spineIndex,start: first.start,end: first.end,quote: first.quote,prefix: first.prefix,suffix: first.suffix,vertical: true)
        #expect(await session.command("navigate",anchor: verticalStart))
        #expect(session.vertical && session.position.contains("第 1 页"))
        #expect(await session.command("next"));let verticalSecond = try #require(session.progress)
        #expect(session.position.contains("第 2 页") && verticalSecond.start > first.start)
        #expect(await session.command("next"));let verticalThird = try #require(session.progress)
        #expect(session.position.contains("第 3 页") && verticalThird.start > verticalSecond.start)
        #expect(await session.command("navigate",anchor: verticalSecond));#expect(session.position.contains("第 2 页"))
        #expect(await session.command("navigate",anchor: verticalThird));#expect(session.position.contains("第 3 页"))
        #expect(await session.command("navigate",anchor: third));#expect(!session.vertical && session.position.contains("第 3 页"))
        book.progress = third
        let (reopened,other) = try await opened(data: data, book: book)
        defer { reopened.close();other.close() }
        #expect(reopened.position.contains("第 3 页"))
        #expect(!window.isVisible && !other.isVisible)
    }
    @Test @MainActor func surrogateBoundaryHasReadableProgressAndUnsupportedMIMERoutesFail() async throws {
        let data = try originalPublication(String(repeating: "A", count: 127) + "🌸 remaining original text café")
        let book = EPUBBook(fileSHA256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), title: "Original Unicode", originalFilename: "original.epub")
        let (session,window) = try await opened(data: data, book: book)
        defer { session.close();window.close() }
        let anchor = try #require(session.progress);#expect(anchor.isValid && anchor.quote.contains("🌸"))
        #expect(await session.command("navigate",anchor: anchor))
        for (suffix,mime) in [("content","application/xhtml+xml"),("svg","image/svg+xml"),("xhtml","image/png")] {
            let hostile = try originalPublication("Original harmless label",suffix: suffix,mime: mime)
            let candidate = EPUBBook(fileSHA256: SHA256.hash(data: hostile).map { String(format: "%02x", $0) }.joined(), title: "Original admission test", originalFilename: "original.epub")
            do { let (accepted,host) = try await opened(data: hostile,book: candidate);accepted.close();host.close();Issue.record("Unsupported MIME/suffix was admitted") }
            catch { #expect(error as? EPUBError == .bridge) }
        }
        for text in ["<span xmlns='https://example.invalid/foreign'>Original namespace test</span>","<?xml-stylesheet href='https://example.invalid/never.css'?>Original processing instruction test"] {
            let hostile = try originalPublication(text)
            let candidate = EPUBBook(fileSHA256: SHA256.hash(data: hostile).map { String(format: "%02x", $0) }.joined(),title: "Original XML policy test",originalFilename: "original.epub")
            do { let (accepted,host) = try await opened(data: hostile,book: candidate);accepted.close();host.close();Issue.record("Unsupported XML policy was admitted") }
            catch { #expect(error as? EPUBError == .bridge) }
        }
    }
    @MainActor private func probe(_ session: EPUBReaderSession, _ source: String) async throws -> String {
        let view = try #require(session.webView)
        return try #require(try await view.callAsyncJavaScript(source, arguments: [:], in: nil, contentWorld: .page) as? String)
    }
    @Test @MainActor func sourceRubyReflowAndStaleRequests() async throws {
        let (session, window) = try await opened("study-sample")
        defer { session.close(); window.close() }
        let first = try #require(session.progress)
        _ = try await probe(session, "const d=document.querySelector('iframe').contentDocument;const p=d.querySelector('p');const r=d.createRange();r.setStart(p.firstChild,0);r.setEnd(p.firstChild,6);d.getSelection().removeAllRanges();d.getSelection().addRange(r);return 'selected';")
        let selectionDeadline = Date().addingTimeInterval(3)
        while session.selection == nil && Date() < selectionDeadline { try await Task.sleep(for: .milliseconds(50)) }
        #expect(session.selection?.quote == "window")
        let selected = try #require(session.selection), book = try #require(session.book)
        #expect(await session.command("notes", notes: [EPUBNote(bookID: book.id, anchor: selected, userText: "Original highlight regression")]))
        let projected = try await probe(session, "const d=document.querySelector('iframe').contentDocument;const h=d.defaultView.CSS?.highlights?.get('pdfno-notes');return JSON.stringify({count:h?.size??d.querySelectorAll('[data-pdfno-overlay]').length,quote:h?[...h][0]?.toString():d.getSelection().toString()});")
        #expect(projected.contains("\"count\":1")); #expect(projected.contains("\"quote\":\"window\""))
        #expect(await session.command("navigate", anchor: selected))
        #expect(await session.command("chapter", index: 1))
        #expect(await session.command("vertical"))
        let ruby = try await probe(session, "const d=document.querySelector('iframe').contentDocument; return JSON.stringify({ruby:d.querySelector('rt')?.textContent,mode:getComputedStyle(d.documentElement).writingMode});")
        #expect(ruby.contains("にほんご")); #expect(ruby.contains("vertical"))
        let japanese = try #require(session.progress)
        #expect(!japanese.quote.contains("にほんご"))
        #expect(await session.command("resize")); #expect(await session.command("navigate", anchor: japanese))
        #expect(await session.command("navigate", anchor: first))
        var wrong = try JSONSerialization.jsonObject(with: JSONEncoder().encode(first)) as! [String: Any]
        wrong["quote"] = "changed"
        let json = String(decoding: try JSONSerialization.data(withJSONObject: wrong), as: UTF8.self)
        // An unknown session cannot navigate even with a well-formed command shape.
        let stale = try await probe(session, "try{await window.PDFno.command({v:1,requestID:'stale',session:'wrong',command:'navigate',documentVersion:0,payload:{anchor:" + json + "}});return 'accepted'}catch{return 'rejected'}")
        #expect(stale == "rejected")
        session.close(); #expect(!(await session.command("next")))
    }
    @Test @MainActor func hostileOriginalContentIsStrippedAndNetworkBlocked() async throws {
        let (session, window) = try await opened("security-sample")
        defer { session.close(); window.close() }
        let result = try await probe(session, "const d=document.querySelector('iframe').contentDocument; return JSON.stringify({scripts:d.querySelectorAll('script,[onload],iframe,object').length,remote:[...d.querySelectorAll('[src],[href]')].some(x=>/https?:|javascript:/.test(x.getAttribute('src')||x.getAttribute('href')||'')),ran:!!d.defaultView.PDFNO_BOOK_SCRIPT,css:d.querySelector('style')?.textContent});")
        #expect(result.contains("\"scripts\":0")); #expect(result.contains("\"remote\":false")); #expect(result.contains("\"ran\":false"))
        let blocked = try await probe(session, "try{await fetch('https://example.invalid/must-never-load');return 'loaded'}catch{return 'blocked'}")
        #expect(blocked == "blocked")
    }
}
#endif
