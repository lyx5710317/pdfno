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
        let session = EPUBReaderSession(), book = EPUBBook(fileSHA256: hash, title: "Original test", originalFilename: filename + ".epub")
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
