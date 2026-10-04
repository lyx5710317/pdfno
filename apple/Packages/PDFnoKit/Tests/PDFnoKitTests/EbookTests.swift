// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders
@testable import PDFnoUI

struct EbookTests {
    func fixture(_ format: EbookFormat) throws -> Data {
        try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: format.rawValue, subdirectory: "Fixtures/Ebooks")))
    }
    @Test(arguments: EbookFormat.allCases) func realContainerAdmissionAndOriginalRetention(format: EbookFormat) async throws {
        let data = try fixture(format)
        let kind = try EbookPreflight.validate(data, format: format)
        #expect(kind == (format == .fb2 ? .fb2 : format == .azw3 ? .kf8 : .mobi6))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Ebook-Test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = EbookRepository(root: root), book = try await repo.importBook(data, filename: "original." + format.rawValue)
        #expect(book.format == format && book.contentKind == kind)
        #expect(try await repo.read(book) == data)
        #expect(try await repo.importBook(data, filename: "duplicate." + format.rawValue).id == book.id)
        let doc = EbookDocument(blocks: [EbookBlock(id: 0, runs: [EbookRun("Original 😀 e\u{301} text")], start: 0, section: 0)])
        try await repo.bindRenderedDocument(doc, book: book)
        let anchor = try #require(doc.anchor(book: book, start: 0, end: 8))
        try await repo.saveNote(EbookNote(bookID: book.id, anchor: anchor, userText: "Original observation"))
        try await repo.saveProgress(anchor, bookID: book.id)
        let reopened = EbookRepository(root: root), state = try await reopened.load()
        #expect(state.books[0].progress == anchor && state.notes[0].anchor == anchor)
        #expect(state.notes[0].anchor.format == format && state.notes[0].anchor.contentKind == kind)
        #expect(try await reopened.read(book) == data)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("epub-v1.json").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("library-v1.json").path))
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("ebook-kookit-v1.json.backup").path))
        #expect(throws: EbookError.self) { try EbookPreflight.validate(Data("plain text".utf8), format: format) }
    }
    @Test func drmCompressionOffsetsAndLimitFailClosed() throws {
        let original = try fixture(.mobi)
        let r = Int(original[78]) << 24 | Int(original[79]) << 16 | Int(original[80]) << 8 | Int(original[81])
        var drm = original; drm[r + 13] = 1
        #expect(throws: EbookError.self) { try EbookPreflight.validate(drm, format: .mobi) }
        var huff = original; huff[r] = 0x44; huff[r + 1] = 0x48
        #expect(throws: EbookError.self) { try EbookPreflight.validate(huff, format: .azw) }
        var offsets = original; offsets[86] = 0; offsets[87] = 0; offsets[88] = 0; offsets[89] = 0
        #expect(throws: EbookError.self) { try EbookPreflight.validate(offsets, format: .mobi) }
        #expect(throws: EbookError.self) { try EbookPreflight.validate(original, format: .azw3) }
        #expect(throws: EbookError.self) { try EbookPreflight.validate(try fixture(.fb2), format: .mobi) }
        #expect(throws: EbookError.self) { try EbookPreflight.validate(Data(repeating: 0, count: 8 * 1024 * 1024 + 1), format: .fb2) }
        for count in [0, 1, 77, 78, original.count - 1] {
            #expect(throws: EbookError.self) { try EbookPreflight.validate(original.prefix(count), format: .mobi) }
        }
    }
    @Test func fb2EntitiesDeepXMLAndWrongRootReject() throws {
        let original = String(decoding: try fixture(.fb2), as: UTF8.self)
        for text in [original.replacingOccurrences(of: "<FictionBook", with: "<!DOCTYPE FictionBook [<!ENTITY x SYSTEM 'file:///tmp/pdfno-nothing'>]><FictionBook"), original.replacingOccurrences(of: "FictionBook", with: "NotFB2"), original.replacingOccurrences(of: "utf-8", with: "utf-16"), original.replacingOccurrences(of: "</body>", with: String(repeating: "<section>", count: 100) + "text" + String(repeating: "</section>", count: 100) + "</body>")] {
            #expect(throws: EbookError.self) { try EbookPreflight.validate(Data(text.utf8), format: .fb2) }
        }
    }
    @Test func exactUnicodeFormatAndRubyAnchorContracts() throws {
        let book = EbookBook(fileSHA256: String(repeating: "a", count: 64), format: .mobi, contentKind: .mobi6, title: "Original", originalFilename: "original.mobi")
        let doc = EbookDocument(blocks: [EbookBlock(id: 0, runs: [EbookRun("本", ruby: "ほん"), EbookRun(" 😀 e\u{301} same")], headingLevel: 1, start: 0), EbookBlock(id: 1, runs: [EbookRun("same")], start: 13, section: 1)])
        #expect(doc.text.hasPrefix("本 😀 e\u{301} same") && !doc.text.contains("ほん"))
        #expect(doc.isValid)
        #expect(doc.anchor(book: book, start: 3, end: 4) == nil)
        let anchor = try #require(doc.anchor(book: book, start: 2, end: 4))
        #expect(anchor.quote == "😀" && doc.resolves(anchor) && book.accepts(anchor))
        let wrong = EbookBook(id: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256, format: .azw, contentKind: .mobi6, title: book.title, originalFilename: "original.azw")
        #expect(!wrong.accepts(anchor))
        let html = EbookHTML.render(doc, sessionID: UUID())
        #expect(html.contains("<ruby>本<rt>ほん</rt></ruby>"))
        #expect(html.contains("connect-src 'none'") && html.contains("font-src 'none'"))
    }
    @Test func futureOrUnknownFieldsPreserveStoreAndOriginal() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Ebook-Future-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repo = EbookRepository(root: root), data = try fixture(.mobi)
        _ = try await repo.importBook(data, filename: "original.mobi")
        let path = root.appendingPathComponent("ebook-kookit-v1.json")
        var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any]);object["future"] = true
        let corrupt = try JSONSerialization.data(withJSONObject: object);try corrupt.write(to: path)
        await #expect(throws: EbookError.self) { try await repo.importBook(data, filename: "original.mobi") }
        #expect(try Data(contentsOf: path) == corrupt)
    }
}
