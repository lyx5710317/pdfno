// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

struct TextFormatTests {
    @Test func aliasesAndStrictEncodingNeverGuessOrReplace() throws {
        #expect(TextFileFormat.from(filename: "Original.MD") == .markdown)
        #expect(TextFileFormat.from(filename: "Original.Markdown") == .markdown)
        #expect(TextFileFormat.from(filename: "Original.HTM") == .html)
        #expect(TextFileFormat.from(filename: "Original.HTML") == .html)
        for name in ["x.xml","x.mhtml","x.doc","x.rtf"] { #expect(TextFileFormat.from(filename: name) == nil) }
        let source = "Original 🌸 café\r\n日本語"
        #expect(try TextFileDecoder.decode(Data(source.utf8), format: .txt).text.utf16.elementsEqual(source.utf16))
        for little in [true,false] {
            var bytes = Data(little ? [0xff,0xfe] : [0xfe,0xff])
            for u in source.utf16 { bytes.append(contentsOf: little ? [UInt8(u & 255), UInt8(u >> 8)] : [UInt8(u >> 8), UInt8(u & 255)]) }
            let decoded = try TextFileDecoder.decode(bytes, format: .markdown)
            #expect(decoded.text.utf16.elementsEqual(source.utf16))
            #expect(decoded.encoding == (little ? "utf-16le" : "utf-16be"))
        }
        #expect(try TextFileDecoder.decode(Data([0xef,0xbb,0xbf]) + Data(source.utf8), format: .html).text == source)
        for bytes in [Data([0xff]), Data([0xc0,0xaf]), Data([0xff,0xfe,0,0xd8]), Data([0xfe,0xff,0xdc,0]), Data([0xff,0xfe,65]), Data([0,0,0xfe,0xff,0,0,0,65])] {
            #expect(throws: TextFormatError.encoding) { try TextFileDecoder.decode(bytes, format: .txt) }
        }
        #expect(throws: TextFormatError.unsupportedContent) { try TextFileDecoder.decode(Data([65,0,66]), format: .txt) }
        #expect(throws: TextFormatError.resourceLimit) { try TextFileDecoder.decode(Data(repeating: 65, count: 1_000_001), format: .txt) }
        #expect(throws: TextFormatError.resourceLimit) { try TextFileDecoder.decode(Data(repeating: 65, count: 4 * 1024 * 1024 + 1), format: .html) }
        #expect(try TextFileDecoder.decode(Data("<!doctype html><meta charset='UTF-8'><p>Original</p>".utf8), format: .html).encoding == "utf-8")
        #expect(throws: TextFormatError.encoding) { try TextFileDecoder.decode(Data("<meta charset=shift_jis><p>Original</p>".utf8), format: .html) }
        for source in ["<?xml version='1.0'?><p>x</p>","<!DOCTYPE html [<!ENTITY x 'x'>]><p>&x;</p>"] {
            #expect(throws: TextFormatError.unsupportedContent) { try TextFileDecoder.decode(Data(source.utf8), format: .html) }
        }
    }
    @Test func exactCanonicalAnchorsRejectSurrogatesVersionsAndEquivalentUnicode() throws {
        let book = TextFormatBook(fileSHA256: String(repeating: "a", count: 64), title: "Original", originalFilename: "original.md", format: .markdown)
        let text = "window 🌸 café"
        let doc = TextFormatDocument(blocks: [TextFormatBlock(id: 0, runs: [TextFormatRun(text)], headingLevel: 1, start: 0),
            TextFormatBlock(id: 1, runs: [TextFormatRun(text)], start: text.utf16.count+1)])
        let a = try #require(doc.anchor(book: book, start: 0, end: 6))
        let b = try #require(doc.anchor(book: book, start: text.utf16.count+1, end: text.utf16.count+7))
        #expect(doc.resolves(a) && doc.resolves(b) && a.start != b.start)
        #expect(doc.anchor(book: book, start: 8, end: 9) == nil)
        let cross = try #require(doc.anchor(book: book, start: 10, end: text.utf16.count+7))
        #expect(cross.quote.contains("\nwindow") && doc.resolves(cross))
        let exact = try #require(doc.anchor(book: book, start: 10, end: 15))
        let equivalent = TextFormatAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, blockID: 0, start: 10, end: 14, quote: "café", prefix: exact.prefix, suffix: exact.suffix)
        #expect(!doc.resolves(equivalent))
        var future = a; future.extractionVersion = "future"
        #expect(!book.accepts(future) && !doc.resolves(future))
        let html = TextFormatHTML.render(doc, sessionID: UUID(), usesEngine: true)
        #expect(html.contains("pdfno-text://app/engine.js") && html.contains("messageHandlers.textformat"))
        #expect(html.contains("default-src 'none'") && html.contains("connect-src 'none'"))
    }
    @Test func isolatedOriginalNotesProgressAliasesAndCorruptStore() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Text-Service-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = TextFormatRepository(root: root), original = Data("# Original\nwindow 🌸 café\n".utf8)
        let md = try await repo.importBook(original, filename: "original.MD")
        #expect(try await repo.importBook(original, filename: "renamed.markdown").id == md.id)
        let txt = try await repo.importBook(original, filename: "original.txt")
        #expect(md.id != txt.id && md.editionID != txt.editionID)
        #expect(try await repo.read(md) == original)
        let wrongFormat = TextFormatBook(id: md.id, editionID: md.editionID, fileSHA256: md.fileSHA256, title: md.title, originalFilename: "wrong.txt", format: .txt)
        await #expect(throws: TextFormatError.sourceMismatch) { try await repo.read(wrongFormat) }
        let doc = TextFormatDocument(blocks: [TextFormatBlock(id: 0, runs: [TextFormatRun("Original")], headingLevel: 1, start: 0),
            TextFormatBlock(id: 1, runs: [TextFormatRun("window 🌸 café")], start: 9)])
        try await repo.bindRenderedDocument(doc, book: md)
        let anchor = try #require(doc.anchor(book: md, start: 9, end: 15))
        let note = TextFormatNote(bookID: md.id, anchor: anchor, userText: "Original local observation")
        try await repo.saveNote(note); try await repo.saveProgress(anchor, bookID: md.id)
        let reopened = TextFormatRepository(root: root), state = try await reopened.load()
        #expect(state.notes == [note] && state.books.first?.progress == anchor)
        await #expect(throws: TextFormatError.self) { try await reopened.saveNote(TextFormatNote(bookID: md.id, anchor: anchor)) }
        try await reopened.bindRenderedDocument(doc, book: md)
        #expect(try await reopened.document(md).resolves(anchor))
        let wrong = TextFormatAnchor(editionID: md.editionID, fileSHA256: md.fileSHA256, blockID: 1, start: 9, end: 15, quote: "Window", prefix: anchor.prefix, suffix: anchor.suffix)
        await #expect(throws: TextFormatError.self) { try await reopened.saveProgress(wrong, bookID: md.id) }
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("text-formats-v1.json.backup").path))
        for name in ["library-v1.json","epub-v1.json","docx-mammoth-v1.json","learning-v1.json"] { #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path)) }
        let asset = root.appendingPathComponent("Originals/" + md.fileSHA256 + ".markdown")
        try Data("Changed".utf8).write(to: asset)
        await #expect(throws: TextFormatError.self) { try await reopened.read(md) }
        #expect(try await reopened.load().notes == [note])
        let manifest = root.appendingPathComponent("text-formats-v1.json"), future = Data("{\"schemaVersion\":99,\"books\":[],\"notes\":[]}".utf8)
        try future.write(to: manifest)
        await #expect(throws: TextFormatError.self) { try await reopened.importBook(original, filename: "other.txt") }
        #expect(try Data(contentsOf: manifest) == future)
        #expect(throws: TextFormatError.self) { try TextFormatRepository.decode(Data("{\"schemaVersion\":1,\"books\":[],\"notes\":[],\"unknown\":true}".utf8)) }
    }
}
