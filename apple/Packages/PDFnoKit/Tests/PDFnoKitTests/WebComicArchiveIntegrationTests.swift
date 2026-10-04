// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

/// Same temporary library across both slices. No NSWindow or application launch.
@Suite(.serialized)
struct WebComicArchiveIntegrationTests {
    @Test @MainActor func sharedLibraryPreservesCanonicalNotesProgressOriginalsAndContainerCovers() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-WebComic-Integration-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let comics = ComicRepository(root: root), text = TextFormatRepository(root: root), covers = CoverRepository(root: root)
        let zip = try ComicFixture.book(), tar = try CBTFixture.book()
        let cbz = try await comics.importBook(zip, filename: "Same title.cbz")
        let cbt = try await comics.importBook(tar, filename: "Same title.CBT")
        #expect(cbz.id != cbt.id && cbz.editionID != cbt.editionID && cbz.archiveFormat == .cbz && cbt.archiveFormat == .cbt)
        let cbzCover = try await covers.thumbnail(for: CoverIdentity(cbz))
        let cbtCover = try await covers.thumbnail(for: CoverIdentity(cbt))
        #expect(cbzCover.record.identity == CoverIdentity(cbz) && cbzCover.record.origin == .cbzFirstImage)
        #expect(cbtCover.record.identity == CoverIdentity(cbt) && cbtCover.record.origin == .cbtFirstImage)
        // Same first-page pixels share a raster cache key, but never another book's cover record.
        #expect(cbzCover.record.imageSHA256 == cbtCover.record.imageSHA256)
        #expect(try await covers.thumbnail(for: CoverIdentity(cbz)).record == cbzCover.record)
        var saved: [(TextFormatBook, Data, TextFormatNote)] = []
        for (format, bytes) in [(TextFileFormat.xhtml, Data(OriginalWebArchiveFixtures.xhtml.utf8)),
                                (.mhtml, OriginalWebArchiveFixtures.mhtml), (.xml, Data(OriginalWebArchiveFixtures.xml.utf8))] {
            let book = try await text.importBook(bytes, filename: "Same title." + format.rawValue)
            let reader = TextFormatReaderSession(); defer { reader.close() }
            try await reader.open(data: bytes, book: book, notes: [])
            #expect(reader.webView?.window == nil)
            let document = try #require(reader.document)
            try await text.bindRenderedDocument(document, book: book)
            let first = document.blocks[1].start
            let anchor = try #require(document.anchor(book: book, start: first, end: first + 6))
            let note = TextFormatNote(bookID: book.id, anchor: anchor, userText: "Original " + format.label + " observation")
            try await text.saveNote(note); try await text.saveProgress(anchor, bookID: book.id)
            #expect(anchor.quote == "window")
            #expect(await reader.navigate(to: anchor))
            saved.append((book, bytes, note)); reader.close()
        }
        let textManifest = root.appendingPathComponent("text-formats-v1.json")
        let textBefore = try Data(contentsOf: textManifest)
        let cbzManifest = root.appendingPathComponent("comics-v1.json"), cbzBefore = try Data(contentsOf: cbzManifest)
        let cbtProgress = ComicProgress(editionID: cbt.editionID, fileSHA256: cbt.fileSHA256, pageIndex: 2,
            pagePath: cbt.pages[2].path, direction: .rightToLeft, layout: .double)
        try await comics.saveProgress(cbtProgress, bookID: cbt.id)
        #expect(try Data(contentsOf: cbzManifest) == cbzBefore)
        #expect(try Data(contentsOf: textManifest) == textBefore)
        let custom = root.appendingPathComponent("Original local cover.png")
        try ComicFixture.png(width: 17, height: 25).write(to: custom)
        let edited = try await covers.replace(CoverIdentity(cbt), withLocalImage: custom)
        #expect(edited.origin == .userImage && edited.identity.format == .cbt)
        #expect(try await covers.record(for: CoverIdentity(cbz)) == cbzCover.record)
        #expect(try Data(contentsOf: textManifest) == textBefore)
        let restored = try await covers.restoreAutomatic(CoverIdentity(cbt))
        #expect(restored.origin == .cbtFirstImage && restored.resourcePath == cbt.pages[0].path)
        #expect(try await covers.thumbnail(for: CoverIdentity(cbz)).record == cbzCover.record)
        #expect(try Data(contentsOf: textManifest) == textBefore)
        let reloaded = try await TextFormatRepository(root: root).load()
        #expect(reloaded.books.count == 3 && reloaded.notes == saved.map { $0.2 })
        #expect(Set(reloaded.books.map(\.editionID)).isDisjoint(with: [cbz.editionID, cbt.editionID]))
        for (book, original, note) in saved {
            let store = TextFormatRepository(root: root)
            let current = try #require(reloaded.books.first { $0.id == book.id })
            #expect(current.progress == note.anchor && current.format == book.format)
            #expect(try await store.read(current) == original)
            let reader = TextFormatReaderSession(); defer { reader.close() }
            try await reader.open(data: try await store.read(current), book: current, notes: reloaded.notes)
            #expect(reader.progress == note.anchor)
            #expect(await reader.navigate(to: note.anchor))
            reader.close()
        }
        let comicState = try await ComicRepository(root: root).load()
        #expect(comicState.books.first { $0.id == cbt.id }?.progress == cbtProgress)
        #expect(comicState.books.first { $0.id == cbz.id }?.progress == nil)
        #expect(try await comics.read(cbt).data == tar)
        #expect(try await comics.read(cbz).data == zip)
        #expect(try await covers.record(for: CoverIdentity(cbz)) == cbzCover.record)
        #expect(try await covers.record(for: CoverIdentity(cbt)) == restored)
        #expect(try Data(contentsOf: cbzManifest) == cbzBefore)
        for name in ["library-v1.json", "epub-v1.json", "docx-mammoth-v1.json", "learning-v1.json"] {
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path))
        }
    }
    @Test func crossFormatPositionsRefuseWithoutChangingEitherManifest() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-WebComic-Foreign-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let comics = ComicRepository(root: root), text = TextFormatRepository(root: root)
        let cbz = try await comics.importBook(ComicFixture.book(), filename: "Original.cbz")
        let cbt = try await comics.importBook(CBTFixture.book(), filename: "Original.cbt")
        let xml = try await text.importBook(Data(OriginalWebArchiveFixtures.xml.utf8), filename: "Original.xml")
        let cbtBefore = try Data(contentsOf: root.appendingPathComponent("comics-cbt-v1.json"))
        let cbzBefore = try Data(contentsOf: root.appendingPathComponent("comics-v1.json"))
        let textBefore = try Data(contentsOf: root.appendingPathComponent("text-formats-v1.json"))
        let position = ComicProgress(editionID: cbz.editionID, fileSHA256: cbz.fileSHA256, pageIndex: 0,
            pagePath: cbz.pages[0].path, direction: .leftToRight, layout: .single)
        await #expect(throws: ComicError.sourceMismatch) { try await comics.saveProgress(position, bookID: cbt.id) }
        let foreign = TextFormatAnchor(editionID: cbt.editionID, fileSHA256: cbt.fileSHA256, blockID: 0,
            start: 0, end: 6, quote: "window", prefix: "", suffix: "")
        await #expect(throws: TextFormatError.sourceMismatch) { try await text.saveNote(TextFormatNote(bookID: xml.id, anchor: foreign)) }
        await #expect(throws: TextFormatError.sourceMismatch) { try await text.saveProgress(foreign, bookID: xml.id) }
        #expect(try Data(contentsOf: root.appendingPathComponent("comics-cbt-v1.json")) == cbtBefore)
        #expect(try Data(contentsOf: root.appendingPathComponent("comics-v1.json")) == cbzBefore)
        #expect(try Data(contentsOf: root.appendingPathComponent("text-formats-v1.json")) == textBefore)
    }
}
#endif
