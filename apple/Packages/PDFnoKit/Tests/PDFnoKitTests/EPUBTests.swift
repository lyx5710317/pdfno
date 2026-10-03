// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

struct EPUBTests {
    private func sample() throws -> Data {
        try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: "epub", subdirectory: "Fixtures")))
    }
    @Test func originalArchiveAndTraversalChecks() throws {
        let data = try sample(); let paths = try EPUBArchive.validate(data)
        #expect(paths.count == 6)
        for path in ["../book", "/book", "a/../book", "C:book", "a\\book", "a/%2e%2e/book", "a//book", "\u{0}book"] {
            #expect(!EPUBArchive.isSafePath(path))
        }
        var corrupt = data
        // Local name disagreement must fail before any JSZip path normalisation.
        corrupt[30] = UInt8(ascii: "/")
        #expect(throws: EPUBError.self) { try EPUBArchive.validate(corrupt) }
        #expect(throws: EPUBError.self) { try EPUBArchive.validate(Data(repeating: 0, count: 20 * 1024 * 1024 + 1)) }
    }
    @Test func centralBudgetCannotLieAboutLocalSize() throws {
        var data = try sample()
        let signature = Data([0x50,0x4b,0x01,0x02]); let offset = try #require(data.range(of: signature)?.lowerBound)
        // Central uncompressed size > 4 MiB, including when the local size stays small.
        data[offset + 24] = 1; data[offset + 25] = 0; data[offset + 26] = 0x40; data[offset + 27] = 0
        #expect(throws: EPUBError.self) { try EPUBArchive.validate(data) }
    }
    @Test func isolatedEPUBPersistenceAndEditionRefusal() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-EPUB-Test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = EPUBRepository(root: root), data = try sample()
        let book = try await repository.importBook(data, filename: "original.epub")
        let same = try await repository.importBook(data, filename: "other.epub")
        #expect(book.id == same.id)
        let anchor = EPUBAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, resourceHref: "OEBPS/english.xhtml",
                                spineIndex: 0, start: 0, end: 6, quote: "window", prefix: "", suffix: " sample", vertical: false)
        try await repository.saveNote(EPUBNote(bookID: book.id, anchor: anchor, userText: "Original note"))
        try await repository.saveProgress(anchor, bookID: book.id)
        let reopened = EPUBRepository(root: root), state = try await reopened.load()
        #expect(state.notes.first?.anchor == anchor); #expect(state.books.first?.progress == anchor)
        #expect(try await reopened.read(book) == data)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("library-v1.json").path))
        let wrong = EPUBAnchor(editionID: UUID(), fileSHA256: book.fileSHA256, resourceHref: anchor.resourceHref,
                               spineIndex: 0, start: 0, end: 6, quote: "window", prefix: "", suffix: "", vertical: false)
        await #expect(throws: EPUBError.self) { try await reopened.saveProgress(wrong, bookID: book.id) }
        var future = state; future.schemaVersion = 2
        #expect(throws: EPUBError.self) { try EPUBRepository.decode(JSONEncoder().encode(future)) }
    }
    @Test func unicodeAnchorUsesUTF16AndRejectsChangedQuote() {
        let hash = String(repeating: "a", count: 64)
        let text = "日本語🌸café"
        let anchor = EPUBAnchor(editionID: UUID(), fileSHA256: hash, resourceHref: "ja.xhtml", spineIndex: 1,
                                start: 10, end: 10 + text.utf16.count, quote: text, prefix: "", suffix: "", vertical: true)
        #expect(anchor.isValid)
        let invalid = EPUBAnchor(editionID: anchor.editionID, fileSHA256: hash, resourceHref: "ja.xhtml", spineIndex: 1,
                                 start: 10, end: 11, quote: text, prefix: "", suffix: "", vertical: true)
        #expect(!invalid.isValid)
    }
}
