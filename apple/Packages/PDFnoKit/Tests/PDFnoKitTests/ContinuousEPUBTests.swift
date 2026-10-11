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
        let data = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/ReadingModes/original-vertical-continuous.epub"))
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
    @Test func verticalPagesRemainVerticalAndScrollAcrossChaptersWithRestart() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let data = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/ReadingModes/original-vertical-continuous.epub"))
        var book = EPUBBook(fileSHA256: LibraryRepository.digest(data), title: "Original vertical fixture", originalFilename: "original.epub")
        let session = EPUBReaderSession(); try await session.open(data: data, book: book, notes: [])
        let host = NSHostingView(rootView: EPUBCanvas(session: session))
        let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 720,height: 520),styleMask: [],backing: .buffered,defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { session.close(); window.close() }
        try await ready(session, host: host)
        #expect(await session.command("vertical"))
        let web = try #require(session.webView)
        let proof = try await web.callAsyncJavaScript("""
          const f=document.querySelector('iframe'),d=f.contentDocument,root=d.querySelector('[data-pdfno-spine]'),n=root.querySelector('p').firstChild;
          function glyph(start){const r=d.createRange();r.setStart(n,start);r.setEnd(n,start+1);return r.getBoundingClientRect();}
          const a=glyph(0),b=glyph(1),last=d.createRange();last.selectNodeContents(root.lastElementChild);
          return d.querySelectorAll('[data-pdfno-spine]').length===2 && d.defaultView.getComputedStyle(root).writingMode==='vertical-rl' && Math.abs(a.left-b.left)<1 && b.top>a.top && last.getBoundingClientRect().top>1500 && root.scrollWidth<=720 && parseFloat(f.style.height)===d.body.scrollHeight;
          """, arguments: [:], in: nil, contentWorld: .page) as? Bool
        #expect(proof == true)
        _ = try await web.callAsyncJavaScript("document.getElementById('page-area').scrollBy(0,1200);return true;", arguments: [:], in: nil, contentWorld: .page)
        try await Task.sleep(for: .milliseconds(350))
        #expect(session.vertical && session.position.contains("第 3 页"))
        _ = try await web.callAsyncJavaScript("const d=document.querySelector('iframe').contentDocument;document.getElementById('page-area').scrollTo(0,d.querySelector('[data-pdfno-chapter=\"1\"]').offsetTop+1000);return true;", arguments: [:], in: nil, contentWorld: .page)
        try await Task.sleep(for: .milliseconds(350))
        let chapterDeadline = Date().addingTimeInterval(4)
        while session.spineIndex != 1 && Date() < chapterDeadline { try await Task.sleep(for: .milliseconds(50)) }
        #expect(session.vertical && session.spineIndex == 1)
        let saved = try #require(session.progress); #expect(saved.vertical && saved.resourceHref.contains("japanese.xhtml"))
        book.progress = saved;session.close();try await session.open(data: data,book: book,notes: [])
        try await ready(session,host: host)
        #expect(session.vertical && session.spineIndex == 1 && session.progress?.resourceHref == saved.resourceHref)
        let reopened = try #require(session.webView)
        let visible = try await reopened.callAsyncJavaScript("""
          const d=document.querySelector('iframe').contentDocument,root=d.querySelector('[data-pdfno-spine="1"]'),walker=d.createTreeWalker(root,NodeFilter.SHOW_TEXT,{acceptNode:n=>n.parentElement.closest('rt,rp,script,style,noscript')?NodeFilter.FILTER_REJECT:NodeFilter.FILTER_ACCEPT});let start=0;
          while(walker.nextNode()){const n=walker.currentNode;if(start+n.length>offset){const r=d.createRange();r.setStart(n,offset-start);r.setEnd(n,Math.min(n.length,offset-start+1));const g=r.getBoundingClientRect(),area=document.getElementById('page-area');return g.bottom>area.scrollTop && g.top<area.scrollTop+area.clientHeight;}start+=n.length;}return false;
          """, arguments: ["offset": saved.start], in: nil, contentWorld: .page) as? Bool
        #expect(visible == true && !window.isVisible && !window.isKeyWindow)
    }
    @Test func verticalSelectionNotesDirectoryAndReflowKeepCanonicalSource() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let data = try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/ReadingModes/original-vertical-continuous.epub"))
        let book = EPUBBook(fileSHA256: LibraryRepository.digest(data),title: "Original vertical selection",originalFilename: "original.epub"),session = EPUBReaderSession()
        try await session.open(data: data,book: book,notes: [])
        let host = NSHostingView(rootView: EPUBCanvas(session: session))
        let window = NSWindow(contentRect: NSRect(x: 0,y: 0,width: 720,height: 520),styleMask: [],backing: .buffered,defer: false)
        window.isReleasedWhenClosed = false;window.contentView = host
        defer { session.close();window.close() };try await ready(session,host: host)
        #expect(await session.command("vertical"))
        #expect(await session.jump(to: try #require(session.outline.last)))
        #expect(session.vertical && session.spineIndex == 1)
        let web = try #require(session.webView)
        _ = try await web.callAsyncJavaScript("""
          const d=document.querySelector('iframe').contentDocument,p=d.querySelectorAll('[data-pdfno-spine="1"] p')[1],r=d.createRange();r.setStart(p.firstChild,0);r.setEnd(p.firstChild,4);d.getSelection().removeAllRanges();d.getSelection().addRange(r);return true;
          """,arguments: [:],in: nil,contentWorld: .page)
        try await Task.sleep(for: .milliseconds(350))
        let source = try #require(session.selection);#expect(source.vertical && source.spineIndex == 1 && book.accepts(source))
        let note = EPUBNote(bookID: book.id,anchor: source,userText: "Original offline vertical note")
        #expect(await session.command("notes",notes: [note]));#expect(session.selection == source)
        for width in [CGFloat(1280),720] {
            window.setContentSize(NSSize(width: width,height: 520));host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(350))
            #expect(await session.command("resize"));#expect(session.selection == source && session.vertical)
            let exactHeight = try await web.callAsyncJavaScript("const f=document.querySelector('iframe');return parseFloat(f.style.height)===f.contentDocument.body.scrollHeight;",arguments: [:],in: nil,contentWorld: .page) as? Bool
            #expect(exactHeight == true)
        }
        #expect(await session.command("vertical"));#expect(!session.vertical && session.selection?.quote == source.quote && session.selection?.start == source.start)
        #expect(await session.command("vertical"));#expect(session.vertical && session.selection == source)
        #expect(await session.command("chapter",index: 0));#expect(session.vertical && session.spineIndex == 0)
        #expect(await session.command("navigate",anchor: note.anchor));#expect(session.selection == source && session.spineIndex == 1 && session.error == nil)
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
