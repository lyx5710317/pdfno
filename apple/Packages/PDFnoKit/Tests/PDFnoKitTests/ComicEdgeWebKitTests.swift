// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import WebKit
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders
@Suite(.serialized) @MainActor struct ComicEdgeWebKitTests {
    @Test func actualImageWrapperAcceptsEdgesButInteractiveTargetsRemainExcluded() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Comic-Edge-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let data=try ComicFixture.zip((1...3).map { ComicFixture.Entry(name: "page-\($0).png",data: try ComicFixture.png(width: 120,height: 200)) })
        let repo=ComicRepository(root: root),book=try await repo.importBook(data,filename: "Original edge.cbz"),session=ComicReaderSession()
        try await session.open(archive: try await repo.read(book),book: book)
        let window=NSWindow(contentRect: NSRect(x: 0,y: 0,width: 720,height: 520),styleMask: [],backing: .buffered,defer: false)
        window.isReleasedWhenClosed=false;window.contentView=session.webView;session.webView?.frame=NSRect(x: 0,y: 0,width: 720,height: 520)
        defer { session.close();window.close() }
        let end=Date().addingTimeInterval(20);while session.busy && Date()<end { try await Task.sleep(for: .milliseconds(50)) }
        #expect(session.error==nil && session.visibleIndices==[0]);let web=try #require(session.webView)
        let edge=try await web.callAsyncJavaScript("return window.PDFnoComic.canTurnAt(5,250) && window.PDFnoComic.canTurnAt(715,250) && window.PDFnoComic.canTurnAt(360,250);",arguments: [:],in: nil,contentWorld: .page) as? Bool
        #expect(edge==true)
        let blocked=try await web.callAsyncJavaScript("const d=document.querySelector('iframe').contentDocument,b=d.createElement('button');b.style.cssText='position:fixed;top:0;left:0;width:40px;height:520px';d.body.appendChild(b);return !window.PDFnoComic.canTurnAt(5,250);",arguments: [:],in: nil,contentWorld: .page) as? Bool
        #expect(blocked==true && !window.isVisible && !window.isKeyWindow)
    }
}
#endif
