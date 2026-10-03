// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFKit
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
import CoreGraphics
import CoreText

@MainActor struct PDFQuoteConsistencyTests {
    @Test(arguments: ["window", "Reading opens"]) func insertedWordWhitespaceIsRejectedByReaderAIAndStore(query: String) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Quote-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = try originalSample(), repository = LibraryRepository(root: root)
        let book = try await repository.importPDF(bytes, filename: "original.pdf", pageCount: 2)
        let reader = PDFReaderSession(), view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        try reader.open(data: bytes, book: book); reader.attach(view)
        reader.search(query); reader.show(try #require(reader.searchMatches.first)); reader.captureSelection()
        let actual = try #require(reader.capturedSelection)
        #expect(actual.quote == query && actual.regions.count == 1)
        #expect(reader.resolution(of: actual) == .exact)
        try await repository.saveNote(ReadingNote(bookID: book.id, anchor: actual))
        let manifest = root.appendingPathComponent("library-v1.json"), backup = manifest.appendingPathExtension("backup")
        let stored = try Data(contentsOf: manifest), prior = try Data(contentsOf: backup)
        let spaced = actual.quote.map { String($0) }.joined(separator: " ")
        let first = String(actual.quote.prefix(1)), remainder = String(actual.quote.dropFirst())
        var changes: [String] = [spaced,
                       " " + actual.quote, actual.quote + " ", "\n" + actual.quote,
                       first + "\t" + remainder, first + "\u{00A0}" + remainder]
        if actual.quote.contains(" ") {
            changes += [actual.quote.replacingOccurrences(of: " ", with: ""),
                        actual.quote.replacingOccurrences(of: " ", with: "  "),
                        actual.quote.replacingOccurrences(of: " ", with: "\n")]
        }
        for quote in changes {
            let changed = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: quote, regions: actual.regions)
            #expect(!changed.hasConsistentQuote)
            #expect(reader.resolution(of: changed) == .needsRebind)
            #expect(!AISourceSnapshot(bookID: book.id, readerSessionID: reader.readerSessionID, documentVersion: 0, anchor: .pdf(changed)).isValid)
            await #expect(throws: LibraryError.sourceMismatch) { try await repository.saveNote(ReadingNote(bookID: book.id, anchor: changed)) }
            #expect(try Data(contentsOf: manifest) == stored)
            #expect(try Data(contentsOf: backup) == prior)
        }
        #expect(try await repository.readAsset(for: book) == bytes)
    }
    @Test func onlyRegionBoundarySeparatorsVaryWithoutChangingInteriorScalars() {
        func anchor(_ quote: String, _ texts: [String]) -> PDFSourceAnchor {
            PDFSourceAnchor(editionID: UUID(), fileSHA256: String(repeating: "a", count: 64), quote: quote,
                regions: texts.enumerated().map { PageRegion(pageIndex: $0.offset, x: 1, y: 1, width: 100, height: 20, quote: $0.element) })
        }
        let lines = ["one two", "café 🌸", "hyphen-", "ated words"]
        #expect(anchor(lines.joined(separator: "\n"), lines).hasConsistentQuote)
        #expect(anchor(lines.joined(separator: "\r\n"), lines).hasConsistentQuote)
        #expect(anchor(lines.joined(separator: " "), lines).hasConsistentQuote)
        #expect(anchor("one two\ncafé 🌸", ["one two \n", "\tcafé 🌸"]).hasConsistentQuote)
        for changed in ["onetwo\ncafé 🌸\nhyphen-\nated words", "one  two\ncafé 🌸\nhyphen-\nated words",
                        "one two\ncafé 🌸\nhyphen-\nated words", "one two\ncafé 🌸\nhyphen\nated words"] {
            #expect(!anchor(changed, lines).hasConsistentQuote)
        }
        #expect(!anchor(" repeat", ["repeat"]).hasConsistentQuote)
        #expect(!anchor("repeat ", ["repeat"]).hasConsistentQuote)
        #expect(!anchor("repeat", ["repeat", "repeat"]).hasConsistentQuote)
        #expect(anchor("repeat\nrepeat", ["repeat", "repeat"]).hasConsistentQuote)
        #expect(!anchor("window quiet\nquiet window", ["quiet window", "window quiet"]).hasConsistentQuote)
    }
    @Test func malformedStoredWordSpacingPreservesOriginalManifestAndBackup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Quote-Store-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = try originalSample(), repository = LibraryRepository(root: root)
        let book = try await repository.importPDF(bytes, filename: "original.pdf", pageCount: 2)
        let reader = PDFReaderSession(), view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        try reader.open(data: bytes, book: book); reader.attach(view)
        reader.search("window"); reader.show(try #require(reader.searchMatches.first)); reader.captureSelection()
        let actual = try #require(reader.capturedSelection)
        try await repository.saveNote(ReadingNote(bookID: book.id, anchor: actual))
        var state = try await repository.load()
        let changed = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: "w i n d o w", regions: actual.regions)
        state.notes = [ReadingNote(bookID: book.id, anchor: changed)]
        let malformed = try JSONEncoder().encode(state), manifest = root.appendingPathComponent("library-v1.json"), backup = manifest.appendingPathExtension("backup")
        let prior = try Data(contentsOf: backup); try malformed.write(to: manifest)
        await #expect(throws: LibraryError.unreadableStore) { try await repository.load() }
        await #expect(throws: LibraryError.unreadableStore) { try await repository.saveProgress(bookID: book.id, pageIndex: 1) }
        #expect(try Data(contentsOf: manifest) == malformed)
        #expect(try Data(contentsOf: backup) == prior)
        #expect(try await repository.readAsset(for: book) == bytes)
    }
    @Test(arguments: [0, 90, 180, 270]) func actualMultilineUnicodeHyphenationRotationAndCropRemainResolvable(rotation: Int) throws {
        let original = try #require(PDFDocument(data: originalUnicodePDF()))
        for index in 0..<original.pageCount {
            let page = try #require(original.page(at: index))
            page.rotation = rotation; page.setBounds(CGRect(x: 48, y: 96, width: 516, height: 624), for: .cropBox)
        }
        let bytes = try #require(original.dataRepresentation()), book = BookRecord(title: "Original Unicode quote", fileSHA256: LibraryRepository.digest(bytes), originalFilename: "original.pdf", pageCount: 2)
        let reader = PDFReaderSession(), view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
        try reader.open(data: bytes, book: book); reader.attach(view)
        let document = try #require(reader.document), selected = PDFSelection(document: document)
        for index in 0..<document.pageCount {
            let page = try #require(document.page(at: index))
            selected.add(try #require(page.selection(for: page.bounds(for: .cropBox))))
        }
        view.setCurrentSelection(selected, animate: false); reader.captureSelection()
        let actual = try #require(reader.capturedSelection)
        #expect(actual.regions.count > 2 && actual.regions.contains(where: { $0.pageIndex == 1 }))
        #expect(actual.quote.contains("hyphen-") && actual.quote.contains("ated words"))
        #expect(actual.quote.unicodeScalars.contains(where: { $0.value > 127 }))
        #expect(actual.hasConsistentQuote && reader.resolution(of: actual) == .exact)
        let restored = try JSONDecoder().decode(PDFSourceAnchor.self, from: JSONEncoder().encode(actual))
        try reader.open(data: bytes, book: book)
        #expect(reader.resolution(of: restored) == .exact)
        #expect(LibraryRepository.digest(bytes) == book.fileSHA256)
    }
    private func originalUnicodePDF() throws -> Data {
        let data = try #require(CFDataCreateMutable(nil, 0)), consumer = try #require(CGDataConsumer(data: data))
        var bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        let context = try #require(CGContext(consumer: consumer, mediaBox: &bounds, nil))
        let font = CTFontCreateWithName("Helvetica" as CFString, 18, nil)
        for _ in 0..<2 {
            context.beginPDFPage(nil)
            for (index, text) in ["Original one two  window", "café 日本語", "hyphen-", "ated words repeat repeat"].enumerated() {
                context.textPosition = CGPoint(x: 72, y: 680 - index * 32)
                CTLineDraw(CTLineCreateWithAttributedString(NSAttributedString(string: text,
                    attributes: [NSAttributedString.Key(kCTFontAttributeName as String): font])), context)
            }
            context.endPDFPage()
        }
        context.closePDF(); return data as Data
    }
}
