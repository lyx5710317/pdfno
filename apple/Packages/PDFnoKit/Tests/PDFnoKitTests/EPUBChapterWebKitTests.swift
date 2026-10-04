// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import WebKit
import Testing
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

@Suite(.serialized)
struct EPUBChapterWebKitTests {
    private func publication(_ body: String) throws -> Data {
        try ConversionFixture.zip([
            ("mimetype", Data("application/epub+zip".utf8)),
            ("META-INF/container.xml", Data("<container xmlns='urn:oasis:names:tc:opendocument:xmlns:container'><rootfiles><rootfile full-path='book.opf' media-type='application/oebps-package+xml'/></rootfiles></container>".utf8)),
            ("book.opf", Data("<package xmlns='http://www.idpf.org/2007/opf' version='3.0' unique-identifier='id'><metadata xmlns:dc='http://purl.org/dc/elements/1.1/'><dc:identifier id='id'>original-chapter-fixture</dc:identifier><dc:title>Original chapter fixture</dc:title><dc:language>en</dc:language></metadata><manifest><item id='nav' href='nav.xhtml' properties='nav' media-type='application/xhtml+xml'/><item id='one' href='one.xhtml' media-type='application/xhtml+xml'/><item id='two' href='two.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='one'/><itemref idref='two'/></spine></package>".utf8)),
            ("nav.xhtml", Data("<html xmlns='http://www.w3.org/1999/xhtml' xmlns:epub='http://www.idpf.org/2007/ops'><head><title>Original contents</title></head><body><nav epub:type='toc'><ol><li><a href='one.xhtml#first'>Logical chapter A</a></li><li><a href='one.xhtml#second'>Logical chapter B</a></li><li><a href='two.xhtml'>Other resource</a></li></ol></nav></body></html>".utf8)),
            ("one.xhtml", Data("<html xmlns='http://www.w3.org/1999/xhtml'><head><title>First resource</title></head><body>\(body)</body></html>".utf8)),
            ("two.xhtml", Data("<html xmlns='http://www.w3.org/1999/xhtml'><head><title>Other</title></head><body><p>Original other spine resource</p></body></html>".utf8))
        ], deflated: false)
    }
    @MainActor private func mount(_ session: EPUBReaderSession, data: Data, book: EPUBBook) async throws -> NSWindow {
        _ = NSApplication.shared
        try await session.open(data: data, book: book, notes: [])
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = session.webView
        let deadline = Date().addingTimeInterval(20)
        while session.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(40)) }
        try #require(session.error == nil && session.progress != nil)
        #expect(!window.isVisible)
        return window
    }
    @Test @MainActor func snapshotIncludesAllLogicalTOCSectionsRubyBasesAndEveryPageWithoutNavigation() async throws {
        // Existing epub-canonical-utf16-1 includes the title Kookit relocates into the body.
        let text = "First resource" + "Before logical chapters." + "Logical A" + String(repeating: "Original garden paragraph. ", count: 25) + "Logical B" + "日本語 🌸 café" + "Original final sentence."
        let data = try publication("<p>Before logical chapters.</p><h1 id='first'>Logical A</h1><p>" + String(repeating: "Original garden paragraph. ", count: 25) + "</p><h1 id='second'>Logical B</h1><p><ruby>日本語<rt>にほんご</rt><rp>(</rp></ruby> 🌸 café</p><p>Original final sentence.</p>")
        let session = EPUBReaderSession(), book = EPUBBook(fileSHA256: LibraryRepository.digest(data), title: "Original", originalFilename: "original.epub")
        let window = try await mount(session, data: data, book: book)
        defer { session.close(); window.close() }
        #expect(session.outline.filter { $0.index == 0 }.count == 2)
        let version = session.documentVersion, initialPosition = session.position
        let snapshot = try await session.currentChapterTextSnapshot(), plan = try EPUBChapterTranslationPlan(snapshot: snapshot)
        #expect(snapshot.text?.unicodeScalars.elementsEqual(text.unicodeScalars) == true)
        #expect(snapshot.utf16Count == text.utf16.count && snapshot.spineIndex == 0 && snapshot.chapterCount == 2 && snapshot.resourceHref == "one.xhtml")
        #expect(!snapshot.text!.contains("にほんご") && plan.sources.count == 2)
        #expect(session.documentVersion == version && session.position == initialPosition)
        #expect(await session.command("next"))
        let paged = try await session.currentChapterTextSnapshot()
        #expect(paged.text?.unicodeScalars.elementsEqual(text.unicodeScalars) == true)
        guard case .epubChapter(let anchor) = plan.sources.last!.anchor else { Issue.record("Chapter anchor missing"); return }
        #expect(await session.validateChapterAnchor(anchor))
        #expect(await session.command("navigate", anchor: anchor))
        // A successful source return acknowledges the real DOM range before it
        // returns; event delivery while the reader was busy cannot erase it.
        #expect(session.selection?.quote.utf8.elementsEqual(anchor.quote.utf8) == true)
        #expect(session.selection?.start == anchor.start && session.selection?.end == anchor.end)
        // Raw WebKit selection.toString includes rendered ruby and block separators;
        // the trusted parent maps that range back to exact canonical offsets.
        let deadline = Date().addingTimeInterval(3)
        while session.selection == nil && Date() < deadline { try await Task.sleep(for: .milliseconds(40)) }
        #expect(session.selection?.quote.unicodeScalars.elementsEqual(anchor.quote.unicodeScalars) == true)
        #expect(data == (try publication("<p>Before logical chapters.</p><h1 id='first'>Logical A</h1><p>" + String(repeating: "Original garden paragraph. ", count: 25) + "</p><h1 id='second'>Logical B</h1><p><ruby>日本語<rt>にほんご</rt><rp>(</rp></ruby> 🌸 café</p><p>Original final sentence.</p>")))
    }
    @Test @MainActor func sourceReturnRejectsReplyQuoteThatDiffersFromActualRequestedRange() async throws {
        let data = try publication("<p>Original source return か\u{3099}🌸.</p>"), session = EPUBReaderSession()
        let book = EPUBBook(fileSHA256: LibraryRepository.digest(data), title: "Original source return", originalFilename: "original.epub")
        let window = try await mount(session, data: data, book: book)
        defer { session.close(); window.close() }
        let plan = try EPUBChapterTranslationPlan(snapshot: await session.currentChapterTextSnapshot())
        guard case .epubChapter(let anchor) = plan.sources[0].anchor else { Issue.record("Chapter anchor missing"); return }
        #expect(await session.command("navigate", anchor: anchor))
        #expect(session.selection?.quote.utf8.elementsEqual(anchor.quote.utf8) == true)
        let view = try #require(session.webView)
        // Only this original offscreen test host changes the reply. The actual
        // engine still performs navigation; a forged same-length quote must fail.
        let installed = try await view.callAsyncJavaScript("""
          const original = window.PDFno.command;
          window.PDFno.command = async message => {
            const reply = JSON.parse(await original(message));
            if (message.command === 'navigate') {
              const selected = reply.payload.navigationSelection;
              selected.quote = 'x'.repeat(selected.end - selected.start);
            }
            return JSON.stringify(reply);
          };
          return 'installed';
          """, arguments: [:], in: nil, contentWorld: .page)
        #expect(installed as? String == "installed")
        #expect(!(await session.command("navigate", anchor: anchor)))
        #expect(session.error == EPUBError.sourceMismatch.localizedDescription)
    }
    @Test @MainActor func oversizedBridgeReturnsActualCountAndNoExcerptAndRejectsBeforeAnyPlan() async throws {
        let body = String(repeating: "Original long paragraph. ", count: 500)
        let data = try publication("<p>" + body + "</p>"), session = EPUBReaderSession()
        let book = EPUBBook(fileSHA256: LibraryRepository.digest(data), title: "Original long", originalFilename: "original.epub")
        let window = try await mount(session, data: data, book: book)
        defer { session.close(); window.close() }
        let snapshot = try await session.currentChapterTextSnapshot()
        #expect(snapshot.utf16Count == "First resource".utf16.count + body.utf16.count && snapshot.text == nil)
        #expect(throws: EPUBChapterTranslationFailure.chapterLimit) { try EPUBChapterTranslationPlan(snapshot: snapshot) }
        #expect(session.book?.id == book.id && session.webView != nil && !session.busy)
    }
    @Test @MainActor func nativeLibrarySaveReopenSourceReturnAndScopeChangeCancelPreserveSuccessfulOutput() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Chapter-Library-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession()); await library.load()
        let data = try publication("<p id='first'>Original first part 🌸 café.</p><p id='second'>Original last part.</p>")
        let book = try await library.epubRepository.importBook(data, filename: "original.epub")
        library.readingEPUB = true
        let window = try await mount(library.epub, data: data, book: book)
        defer { library.epub.close(); window.close() }
        let source = try await EPUBChapterTranslationPlan(snapshot: library.epub.currentChapterTextSnapshot()).sources[0]
        #expect(library.isCurrentAISource(source))
        let result = AIResult(request: AIRequest(source: source, provider: DeepSeekSelectionPolicy.configuration(), kind: .translate), text: "Original offline native chapter output", fromCache: false)
        #expect(await library.learning.saveChapterResult(result, userText: "Original chapter draft", validateSource: library.validateChapterSource))
        #expect(library.learning.notes.count == 1)
        #expect(await library.epub.command("chapter", index: 1))
        #expect(!library.isCurrentAISource(source))
        #expect(!(await library.validateChapterSource(source)))
        #expect(await library.returnToAISource(source))
        #expect(await library.validateChapterSource(source)) // Validates original quote after documentVersion changes.
        let restarted = LibraryModel(root: root, aiSession: AppAISession()); await restarted.load(); restarted.readingEPUB = true
        let other = try await mount(restarted.epub, data: data, book: book)
        defer { restarted.epub.close(); other.close() }
        let saved = try #require(restarted.learning.notes.first)
        #expect(saved.result == result && saved.userText == "Original chapter draft")
        #expect(await restarted.returnToAISource(saved.result.source))
        guard case .epubChapter(let anchor) = source.anchor else { Issue.record("Chapter anchor missing"); return }
        let wrong = EPUBAnchor(editionID: anchor.editionID, fileSHA256: anchor.fileSHA256, resourceHref: anchor.resourceHref,
            spineIndex: anchor.spineIndex, start: anchor.start, end: anchor.end, quote: String(repeating: "x", count: anchor.quote.utf16.count), prefix: anchor.prefix, suffix: anchor.suffix, vertical: anchor.vertical)
        #expect(!(await restarted.epub.validateChapterAnchor(wrong)))
        // Scope invalidation is wired to the library owner even with the sheet closed.
        library.chapterTranslation.prepare(try await library.epub.currentChapterTextSnapshot())
        library.chapterTranslation.temporarySecret = "synthetic-unused-key"
        #expect(await library.epub.command("chapter", index: 1))
        #expect(library.chapterTranslation.temporarySecret.isEmpty)
    }
}
#endif
