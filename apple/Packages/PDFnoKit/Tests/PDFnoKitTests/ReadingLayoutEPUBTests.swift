// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import Foundation
import Testing
import WebKit
import PDFnoDomain
import PDFnoReaders
import PDFnoServices

@Suite(.serialized) @MainActor struct ReadingLayoutEPUBTests {
    private func opened(_ name: String) async throws -> (EPUBReaderSession, NSWindow, Data, EPUBBook) {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "epub", subdirectory: "Fixtures/ReadingModes"))
        let data = try Data(contentsOf: url)
        let book = EPUBBook(fileSHA256: LibraryRepository.digest(data), title: "Original Aa fixture", originalFilename: "original.epub")
        let reader = EPUBReaderSession()
        try await reader.open(data: data, book: book, notes: [])
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = reader.webView
        reader.webView?.frame = NSRect(x: 0, y: 0, width: 640, height: 400)
        let deadline = Date().addingTimeInterval(22)
        while reader.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
        return (reader, window, data, book)
    }
    private func probe(_ reader: EPUBReaderSession) async throws -> [String: Any] {
        let web = try #require(reader.webView)
        return try #require(try await web.callAsyncJavaScript("""
          const d=document.querySelector('iframe').contentDocument;
          const roots=[...d.querySelectorAll('[data-pdfno-spine]')];
          const texts=roots.map(root=>{const w=d.createTreeWalker(root,4,{acceptNode:n=>n.parentElement.closest('rt,rp,script,style,noscript')?2:1});let t='';while(w.nextNode())t+=w.currentNode.data;return t;});
          const pages=[...d.querySelectorAll('[data-pdfno-page]')].filter(p=>p.getBoundingClientRect().width>0);
          const h=d.defaultView.CSS?.highlights?.get('pdfno-annotations');
          return {texts,ruby:[...d.querySelectorAll('rt')].map(x=>x.textContent),visible:pages.length,font:pages[0]?d.defaultView.getComputedStyle(pages[0]).fontSize:null,writing:pages[0]?d.defaultView.getComputedStyle(pages[0]).writingMode:null,annotation:h?[...h].map(x=>x.toString()):[],selected:d.getSelection().toString()};
          """, arguments: [:], in: nil, contentWorld: .page) as? [String: Any])
    }
    @Test func realPagesCrossChaptersAndPreserveRubyAnnotationsBookmarksAndPosition() async throws {
        let (reader, window, data, book) = try await opened("original-aa-japanese")
        defer { reader.close(); window.close() }
        try #require(reader.error == nil && reader.progress != nil)
        #expect(reader.readingLayout.mode == .scroll && reader.readingCapability == .reflowEPUB)
        #expect(reader.writingLanguage.permitsVerticalReflow)
        let source = try #require(reader.progress), before = try await probe(reader)
        #expect(await reader.command("navigate", anchor: source))
        let items = [AnchoredAnnotation(bookID: book.id, anchor: .epub(source), kind: .highlight)]
        await reader.projectAnnotations(items)
        let bookmark = ReadingBookmark(bookID: book.id, location: .epub(source), title: "Original Aa bookmark")
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let bookmarkBytes = try encoder.encode(bookmark)
        for mode in [ReadingPageMode.single, .double, .scroll] {
            #expect(await reader.applyReadingLayout(ReadingLayout(fontSize: 24, mode: mode)))
            #expect(reader.progress == source && reader.selection == source)
            let value = try await probe(reader)
            #expect(value["texts"] as? [String] == before["texts"] as? [String])
            #expect(value["ruby"] as? [String] == before["ruby"] as? [String])
            #expect((value["annotation"] as? [String])?.contains(source.quote) == true)
            #expect(value["visible"] as? Int == (mode == .scroll ? 0 : mode == .single ? 1 : 2))
            if mode != .scroll {
                #expect(value["font"] as? String == "24px")
                #expect(reader.hasNextPage && !reader.hasPreviousPage)
                #expect(await reader.command("next")); #expect(reader.progress?.start ?? 0 > source.start)
                let advanced = reader.progress, position = reader.position
                #expect(await reader.command("resize"))
                #expect(reader.progress == advanced && reader.position == position)
                #expect(await reader.command("previous")); #expect(reader.spineIndex == 0)
                #expect(await reader.command("navigate", anchor: source))
            }
        }
        #expect(await reader.applyReadingLayout(ReadingLayout(fontSize: 26, mode: .double, vertical: true)))
        #expect(reader.progress == source.withVertical(true) && reader.selection == source.withVertical(true))
        let vertical = try await probe(reader)
        #expect(vertical["writing"] as? String == "vertical-rl" && vertical["visible"] as? Int == 2)
        #expect(vertical["texts"] as? [String] == before["texts"] as? [String])
        var turns = 0
        while reader.spineIndex == 0 && reader.hasNextPage && turns < 40 {
            #expect(await reader.command("next")); turns += 1
        }
        #expect(turns > 1 && turns < 40 && reader.spineIndex == 1 && reader.vertical)
        #expect(await reader.command("previous")); #expect(reader.spineIndex == 0 && reader.vertical)
        #expect(await reader.command("next")); #expect(reader.spineIndex == 1)
        #expect(await reader.command("navigate", anchor: source))
        #expect(reader.progress == source && reader.selection == source && !reader.vertical)
        #expect(try encoder.encode(bookmark) == bookmarkBytes)
        #expect(await reader.applyReadingLayout(ReadingLayout(fontSize: 28, mode: .single)))
        window.setContentSize(NSSize(width: 360, height: 400))
        #expect(await reader.command("resize")); #expect(reader.progress == source && reader.selection == source)
        let retained = reader.readingLayout
        var saved = book; saved.progress = source
        reader.close(); try await reader.open(data: data, book: saved, notes: [])
        window.contentView = reader.webView; reader.webView?.frame = NSRect(x: 0, y: 0, width: 360, height: 400)
        let deadline = Date().addingTimeInterval(22)
        while reader.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
        #expect(reader.error == nil && reader.progress == source && reader.readingLayout == retained)
        #expect(!window.isVisible && !window.isKeyWindow)
    }
    @Test func fixedEPUBNeverOptsIntoReflowAndCancelledReaderCannotApplyLayout() async throws {
        let (reader, window, _, _) = try await opened("original-aa-fixed")
        defer { reader.close(); window.close() }
        #expect(reader.error != nil && reader.progress == nil && !reader.readingCapability.allowsAa)
        #expect(!(await reader.applyReadingLayout(ReadingLayout(mode: .single))))
        reader.close()
        #expect(!(await reader.applyReadingLayout(ReadingLayout(mode: .double))))
        #expect(!window.isVisible)
    }
}
#endif
