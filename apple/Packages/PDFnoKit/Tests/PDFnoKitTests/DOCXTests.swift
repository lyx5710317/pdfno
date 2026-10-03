// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit
import JavaScriptCore
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

struct DOCXTests {
    private func fixture(_ name: String = "study-sample") throws -> Data {
        try Data(contentsOf: #require(Bundle.module.url(forResource: name, withExtension: "docx", subdirectory: "Fixtures/DOCX")))
    }
    private func book(_ data: Data) -> DOCXBook {
        DOCXBook(fileSHA256: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
                 title: "Original DOCX", originalFilename: "study-sample.docx")
    }
    @Test func semanticReadingHeadingInheritanceAndTables() throws {
        let doc = try DOCXParser.parse(fixture())
        #expect(doc.blocks.count == 8)
        #expect(doc.outline.map(\.text) == ["Original DOCX chapter", "Second heading"])
        #expect(doc.outline.map(\.headingLevel) == [1, 2])
        #expect(doc.blocks[1].runs[0].bold)
        #expect(doc.blocks[1].text == "window — 日本語🌸 café & <script>literal</script>")
        #expect(doc.blocks[4].listLevel == 1)
        #expect(doc.blocks[5].table == 0 && doc.blocks[5].row == 0 && doc.blocks[5].cell == 0)
        #expect(doc.blocks[6].cell == 1)
        #expect(doc.blocks[7].text == "Emphasis\tafter tab\nafter break")
        #expect(doc.blocks[7].runs.allSatisfy { $0.italic })
        #expect(doc.text == doc.blocks.map(\.text).joined(separator: "\n"))
        #expect(doc.warnings.contains(where: { $0.contains("Word") }) == false)
        #expect(doc.warnings.contains(where: { $0.contains("原编号") }))
    }
    @Test func storedAndDescriptorZIPsHaveIdenticalCanonicalText() throws {
        let source = try DOCXParser.parse(fixture())
        #expect(try DOCXParser.parse(fixture("stored-sample")) == source)
        #expect(try DOCXParser.parse(fixture("descriptor-sample")) == source)
    }
    @Test(arguments: ["external", "entities", "expansion", "altchunk", "embedded", "macro", "deep", "cycle", "utf16", "traversal", "oversize", "textbudget", "paragraphbudget", "bad-crc", "local-mismatch", "encrypted"])
    func hostileOrOutOfProfileDocumentsFailBeforeRendering(name: String) throws {
        let data = try fixture(name)
        #expect(throws: DOCXError.self) { try DOCXParser.parse(data) }
    }
    @Test func centralSizesCRCAndSymlinksCannotBypassValidation() throws {
        let original = try fixture(), central = try #require(original.range(of: Data([0x50, 0x4b, 0x01, 0x02]))?.lowerBound)
        var symlink = original; symlink[central + 38 + 3] = 0xa0
        #expect(throws: DOCXError.self) { try DOCXParser.parse(symlink) }
        var wrongSize = original
        // Lie consistently in local and central sizes; actual deflate output still rejects it.
        wrongSize[22] &+= 1; wrongSize[central + 24] &+= 1
        #expect(throws: DOCXError.self) { try DOCXParser.parse(wrongSize) }
        var corrupt = original; corrupt[60] ^= 0x40
        #expect(throws: DOCXError.self) { try DOCXParser.parse(corrupt) }
        #expect(throws: DOCXError.self) { try DOCXParser.parse(Data(repeating: 0, count: 20 * 1024 * 1024 + 1)) }
        for count in 0..<22 { #expect(throws: DOCXError.self) { try DOCXParser.parse(original.prefix(count)) } }
    }
    @Test func exactUTF16RepeatedQuotesAndCrossParagraphSelections() throws {
        let data = try fixture(), doc = try DOCXParser.parse(data), book = book(data)
        let first = try #require(doc.anchor(book: book, start: doc.blocks[1].start, end: doc.blocks[1].start + 6))
        let second = try #require(doc.anchor(book: book, start: doc.blocks[2].start, end: doc.blocks[2].start + 6))
        #expect(first.quote == "window" && second.quote == "window")
        #expect(first.blockID != second.blockID && first.start != second.start)
        #expect(doc.resolves(first) && doc.resolves(second))
        let range = try #require(doc.blocks[1].text.range(of: "🌸"))
        let emoji = doc.blocks[1].start + doc.blocks[1].text[..<range.lowerBound].utf16.count
        #expect(doc.anchor(book: book, start: emoji + 1, end: emoji + 2) == nil)
        let flower = try #require(doc.anchor(book: book, start: emoji, end: emoji + 2))
        #expect(flower.quote == "🌸" && doc.resolves(flower))
        let crossing = try #require(doc.anchor(book: book, start: doc.blocks[1].end - 9, end: doc.blocks[2].start + 6))
        #expect(crossing.quote.contains("\nwindow") && doc.resolves(crossing))
        let wrong = DOCXAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, blockID: first.blockID,
                               start: first.start, end: first.end, quote: "Window", prefix: first.prefix, suffix: first.suffix)
        #expect(!doc.resolves(wrong))
        let composedRange = try #require(doc.blocks[1].text.range(of: "café"))
        let start = doc.blocks[1].start + doc.blocks[1].text[..<composedRange.lowerBound].utf16.count
        let exact = try #require(doc.anchor(book: book, start: start, end: start + 5))
        let canonicalEquivalent = DOCXAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, blockID: exact.blockID,
                                             start: exact.start, end: exact.end, quote: "café", prefix: exact.prefix, suffix: exact.suffix)
        #expect(exact.quote.utf16.count == 5 && doc.resolves(exact))
        #expect(!doc.resolves(canonicalEquivalent))
    }
    @Test func contextSurrogatesAndChangedExtractionVersionsFailClosed() throws {
        let data = try fixture(), book = book(data)
        let text = String(repeating: "🌸", count: 100)
        let doc = DOCXDocument(blocks: [DOCXBlock(id: 0, runs: [DOCXRun(text)], start: 0)])
        let anchor = try #require(doc.anchor(book: book, start: 70, end: 72))
        #expect(doc.resolves(anchor))
        #expect(anchor.prefix.utf16.count == 64 && anchor.suffix.utf16.count == 64)
        var changed = anchor; changed.extractionVersion = "future"
        #expect(!changed.isValid && !doc.resolves(changed))
        let wrongContext = DOCXAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, blockID: 0,
                                     start: 70, end: 72, quote: "🌸", prefix: "changed", suffix: anchor.suffix)
        #expect(!doc.resolves(wrongContext))
    }
    @Test func generatedHTMLNeverPassesSourceMarkupOrURLsToWebKit() throws {
        let doc = try DOCXParser.parse(fixture()), token = UUID()
        let html = DOCXHTML.render(doc, sessionID: token)
        #expect(html.contains("&lt;script&gt;literal&lt;/script&gt;"))
        #expect(!html.contains("<script>literal"))
        #expect(html.components(separatedBy: "<script ").count == 2)
        #expect(html.contains("default-src 'none'") && html.contains("connect-src 'none'"))
        #expect(html.contains("<strong>window</strong>") && html.contains("<table><tbody><tr><td>"))
        #expect(html.contains("data-start='\(doc.blocks[2].start)'"))
        #expect(!html.contains("href=") && !html.contains("src=") && !html.contains("<iframe"))
        let script = try #require(html.range(of: "<script nonce=\"\(token.uuidString)\">"))
        let source = String(html[script.upperBound..<html.range(of: "</script>")!.lowerBound])
        let context = try #require(JSContext())
        // Parse trusted bridge JavaScript without creating a window or running app/UI tests.
        _ = context.evaluateScript("new Function(" + String(decoding: try JSONEncoder().encode(source), as: UTF8.self) + ")")
        #expect(context.exception == nil)
        let texts = String(decoding: try JSONEncoder().encode(doc.blocks.map(\.text)), as: UTF8.self)
        _ = context.evaluateScript("""
        var bridgeMessages=[];
        var document={querySelectorAll:()=>\(texts).map(textContent=>({textContent})),addEventListener:()=>{}};
        var window={webkit:{messageHandlers:{docx:{postMessage:m=>bridgeMessages.push(m)}}},addEventListener:()=>{}};
        """)
        _ = context.evaluateScript(source)
        #expect(context.exception == nil)
        #expect(context.evaluateScript("canonical")?.toString()?.utf16.elementsEqual(doc.text.utf16) == true)
        #expect(context.evaluateScript("bridgeMessages[0].action")?.toString() == "ready")
        #expect(context.evaluateScript("bridgeMessages[0].session")?.toString() == token.uuidString)
        let literal = "\"'&<img src='https://example.invalid' onerror='alert(1)'>"
        #expect(DOCXHTML.escape("\r\n") == "&#13;\n")
        let escaped = DOCXHTML.escape(literal)
        #expect(!escaped.contains("<") && escaped.contains("&quot;") && escaped.contains("&#39;"))
    }
    @Test func isolatedRepositoryRetainsOriginalDeduplicatesAndReopensNotes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-DOCX-Test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = DOCXRepository(root: root), data = try fixture()
        let book = try await repository.importBook(data, filename: "original.docx")
        let same = try await repository.importBook(data, filename: "renamed.docx")
        #expect(book.id == same.id)
        let doc = try await repository.document(book)
        let anchor = try #require(doc.anchor(book: book, start: doc.blocks[1].start, end: doc.blocks[1].start + 6))
        let note = DOCXNote(bookID: book.id, anchor: anchor, userText: "Original observation")
        try await repository.saveNote(note); try await repository.saveProgress(anchor, bookID: book.id)
        let reopened = DOCXRepository(root: root), state = try await reopened.load()
        #expect(state.notes == [note] && state.books.first?.progress == anchor)
        #expect(try await reopened.read(book) == data)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("docx-v1.json.backup").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("library-v1.json").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("epub-v1.json").path))
        let wrong = DOCXAnchor(editionID: UUID(), fileSHA256: book.fileSHA256, blockID: anchor.blockID,
                               start: anchor.start, end: anchor.end, quote: anchor.quote, prefix: anchor.prefix, suffix: anchor.suffix)
        await #expect(throws: DOCXError.self) { try await reopened.saveProgress(wrong, bookID: book.id) }
        let forged = DOCXAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, blockID: anchor.blockID,
                                start: anchor.start, end: anchor.end, quote: "forged", prefix: anchor.prefix, suffix: anchor.suffix)
        await #expect(throws: DOCXError.self) { try await reopened.saveNote(DOCXNote(bookID: book.id, anchor: forged)) }
        try Data("tampered original".utf8).write(to: root.appendingPathComponent("Originals/" + book.fileSHA256 + ".docx"))
        await #expect(throws: DOCXError.self) { try await reopened.read(book) }
        #expect(try await reopened.load().notes == [note])
    }
    @Test func corruptOrFutureStoreNeverGetsOverwrittenAndDOCIsNotClaimed() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-DOCX-Test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let bytes = Data("{\"schemaVersion\":99,\"books\":[],\"notes\":[]}".utf8)
        let manifest = root.appendingPathComponent("docx-v1.json"); try bytes.write(to: manifest)
        let repo = DOCXRepository(root: root), data = try fixture()
        await #expect(throws: DOCXError.self) { try await repo.importBook(data, filename: "sample.docx") }
        #expect(try Data(contentsOf: manifest) == bytes)
        await #expect(throws: DOCXError.legacyDOC) { try await repo.importBook(data, filename: "legacy.doc") }
        #expect(throws: DOCXError.self) { try DOCXRepository.decode(Data("{\"schemaVersion\":1,\"books\":[],\"notes\":[],\"unknown\":1}".utf8)) }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Originals").path))
    }
    @Test func boundedFileReadRejectsOversizedSource() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-DOCX-Bounds-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try Data(repeating: 0x41, count: 100).write(to: url)
        #expect(throws: DOCXError.self) { try DOCXRepository.boundedRead(url, limit: 99) }
        #expect(try DOCXRepository.boundedRead(url, limit: 100).count == 100)
    }
}
