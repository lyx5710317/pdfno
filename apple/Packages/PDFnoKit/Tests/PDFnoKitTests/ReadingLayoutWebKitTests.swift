// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import CryptoKit
import Foundation
import Testing
import WebKit
import PDFnoDomain
import PDFnoReaders
import PDFnoServices

@Suite(.serialized) @MainActor struct ReadingLayoutWebKitTests {
    private func host(_ web: WKWebView,width: CGFloat = 640,height: CGFloat = 400) -> NSWindow {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let window=NSWindow(contentRect: NSRect(x: 0,y: 0,width: width,height: height),styleMask: [.titled],backing: .buffered,defer: false)
        window.isReleasedWhenClosed=false;window.contentView=web;web.frame=NSRect(x: 0,y: 0,width: width,height: height);return window
    }
    private func probe(_ web: WKWebView,_ source: String) async throws -> [String: Any] {
        try #require(try await web.callAsyncJavaScript(source,arguments: [:],in: nil,contentWorld: .page) as? [String: Any])
    }
    @Test func measuredTextPagesFontAndScrollPreserveExactSourceAndAnnotations() async throws {
        let source="第一章\n"+String(repeating: "日本語の原文を読み直します。🌸 café 次の文章です。 ",count: 120)+"\n第二章\n続きの本文です。"
        let data=Data(source.utf8),book=TextFormatBook(fileSHA256: SHA256.hash(data: data).map { String(format: "%02x",$0) }.joined(),title: "Original layout test",originalFilename: "original.txt",format: .txt)
        let reader=TextFormatReaderSession();try await reader.open(data: data,book: book,notes: [])
        let web=try #require(reader.webView),doc=try #require(reader.document),window=host(web)
        defer { reader.close();window.close() }
        let start=try #require(doc.blocks.first(where: { $0.text.utf16.count>500 })).start
        let anchor=try #require(doc.anchor(book: book,start: start,end: start+3))
        #expect(await reader.navigate(to: anchor))
        let items:[[String: Any]]=[["anchor":try JSONSerialization.jsonObject(with: JSONEncoder().encode(anchor)),"kind":"highlight"]]
        _=try await web.callAsyncJavaScript(AnnotationDOM.semantic,arguments: ["items":items],in: nil,contentWorld: .page)
        for mode in [ReadingPageMode.single,.double,.scroll] {
            #expect(await reader.applyReadingLayout(ReadingLayout(fontSize: 24,mode: mode)))
            #expect(reader.readingLayout.mode==mode && reader.progress==anchor && doc.resolves(anchor))
            let state=try await probe(web,"""
            const pages=[...document.querySelectorAll('[data-pdfno-page]')].filter(p=>p.getBoundingClientRect().width>0);
            const notes=window.CSS?.highlights?.get('pdfnoAnnotations');
            return {state:window.pdfnoText.reflowState(),visible:pages.length,font:getComputedStyle(document.querySelector('p')??document.querySelector('main')).fontSize,quote:notes?[...notes][0]?.toString():null,source:canonical};
            """)
            #expect(state["source"] as? String==doc.text)
            #expect(state["font"] as? String=="24px" && state["quote"] as? String==anchor.quote)
            #expect(state["visible"] as? Int==(mode == .scroll ? 0:mode == .single ? 1:2))
            if mode != .scroll {
                #expect(reader.hasNextPage)
                #expect(await reader.turnPage(next: true))
                let next=try #require(reader.progress);#expect(next.start>anchor.start)
                #expect(await reader.turnPage(next: false))
                #expect(await reader.navigate(to: anchor))
            }
        }
        #expect(await reader.applyReadingLayout(ReadingLayout(fontSize: 28,mode: .double,vertical: true)))
        #expect(reader.readingLayout.vertical && reader.progress==anchor)
        let vertical=try await probe(web,"const p=document.querySelector('[data-pdfno-page]');return {writing:getComputedStyle(p).writingMode,visible:[...document.querySelectorAll('[data-pdfno-page]')].filter(p=>p.getBoundingClientRect().width>0).length,source:canonical};")
        #expect(vertical["writing"] as? String=="vertical-rl" && vertical["visible"] as? Int==2 && vertical["source"] as? String==doc.text)
        window.setContentSize(NSSize(width: 320,height: 400));try await Task.sleep(for: .milliseconds(200))
        #expect(await reader.navigate(to: anchor))
        var reopened=book;reopened.progress=anchor
        reader.close();try await reader.open(data: data,book: reopened,notes: [])
        #expect(reader.progress==anchor && reader.readingLayout.fontSize==28 && reader.readingLayout.mode == .double)
        #expect(!window.isVisible && !window.isKeyWindow)
    }
    @Test(arguments: EbookFormat.allCases) func validatedEbookFormatsActuallyReflowAndKeepRuby(format: EbookFormat) async throws {
        let url=try #require(Bundle.module.url(forResource: "study-sample",withExtension: format.rawValue,subdirectory: "Fixtures/Ebooks")),data=try Data(contentsOf: url)
        let root=FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Aa-Ebook-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo=EbookRepository(root: root),book=try await repo.importBook(data,filename: "original."+format.rawValue),reader=EbookReaderSession()
        try await reader.open(data: data,book: book,notes: [])
        let web=try #require(reader.webView),window=host(web,width: 380,height: 340),doc=try #require(reader.document)
        defer { reader.close();window.close() }
        #expect(reader.readingCapability==ReadingFormatCapability.ebook(format))
        let block=try #require(doc.navigationBlocks.last),anchor=try #require(doc.anchor(book: book,start: block.start,end: block.start+1))
        let originalRuby=try await probe(web,"return {ruby:[...document.querySelectorAll('rt')].map(x=>x.textContent)};")
        #expect(await reader.navigate(to: anchor))
        for mode in ReadingPageMode.allCases {
            #expect(await reader.applyReadingLayout(ReadingLayout(fontSize: 26,mode: mode)))
            #expect(reader.progress==anchor && doc.resolves(anchor))
            let state=try await probe(web,"return {source:canonical,state:window.pdfnoEbook.reflowState(),ruby:[...document.querySelectorAll('rt')].map(x=>x.textContent)};")
            #expect(state["source"] as? String==doc.text)
            #expect(state["ruby"] as? [String]==originalRuby["ruby"] as? [String])
        }
        #expect(try await repo.read(book)==data && !window.isVisible)
    }
    @Test(arguments: TextFileFormat.allCases) func sixValidatedTextFormatsReflowAndRejectEnglishVertical(format: TextFileFormat) async throws {
        let prose=String(repeating: "An original English paragraph with a garden, a window and café 🌸. ",count: 45)
        let body="<h1>Chapter 1</h1><p>"+prose+"</p><h1>Chapter 2</h1><p>Second original source.</p>"
        let html="<html xmlns=\"http://www.w3.org/1999/xhtml\"><head><title>Original</title></head><body>"+body+"</body></html>"
        let source: String
        switch format {
        case .txt: source="Chapter 1\n"+prose+"\nChapter 2\nSecond original source."
        case .markdown: source="# Chapter 1\n\n"+prose+"\n\n# Chapter 2\n\nSecond original source."
        case .html,.xhtml: source=html
        case .xml: source="<?xml version=\"1.0\" encoding=\"UTF-8\"?><document><h1>Chapter 1</h1><p>"+prose+"</p><h2>Chapter 2</h2><p>Second original source.</p></document>"
        case .mhtml: source="MIME-Version: 1.0\r\nContent-Type: multipart/related; boundary=aa-original\r\n\r\n--aa-original\r\nContent-Type: text/html; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\n\r\n"+Data(html.utf8).base64EncodedString()+"\r\n--aa-original--\r\n"
        }
        let data=Data(source.utf8),book=TextFormatBook(fileSHA256: SHA256.hash(data: data).map { String(format: "%02x",$0) }.joined(),title: "Original text format",originalFilename: "original."+format.rawValue,format: format)
        let reader=TextFormatReaderSession();try await reader.open(data: data,book: book,notes: [])
        let web=try #require(reader.webView),doc=try #require(reader.document),window=host(web,width: 440,height: 340)
        defer { reader.close();window.close() }
        #expect(reader.readingCapability == .flowingText(format) && !reader.writingLanguage.permitsVerticalReflow)
        let block=try #require(doc.blocks.first(where: { $0.text.utf16.count>500 })),anchor=try #require(doc.anchor(book: book,start: block.start,end: block.start+2))
        #expect(await reader.navigate(to: anchor))
        for mode in ReadingPageMode.allCases {
            #expect(await reader.applyReadingLayout(ReadingLayout(fontSize: 24,mode: mode,vertical: true)))
            #expect(reader.progress==anchor && reader.readingLayout.mode==mode && !reader.readingLayout.vertical)
            let value=try await probe(web,"return {source:canonical,visible:[...document.querySelectorAll('[data-pdfno-page]')].filter(p=>p.getBoundingClientRect().width>0).length};")
            #expect(value["source"] as? String==doc.text)
            #expect(value["visible"] as? Int==(mode == .scroll ? 0:mode == .single ? 1:2))
            if mode != .scroll { #expect(await reader.turnPage(next: true));#expect(reader.progress?.start ?? 0 > anchor.start);#expect(await reader.navigate(to: anchor)) }
        }
        #expect(!(await reader.applyReadingLayout(ReadingLayout(fontSize: 40))))
        #expect(reader.progress==anchor && !window.isVisible)
    }
}
#endif
