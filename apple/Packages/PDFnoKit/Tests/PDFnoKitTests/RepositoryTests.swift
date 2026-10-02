// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

func originalSample() throws -> Data {
    try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: "pdf", subdirectory: "Fixtures")))
}
struct RepositoryTests {
    @Test func importDeduplicatesAndProgressSurvivesReload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = LibraryRepository(root: root), data = try originalSample()
        let book = try await repository.importPDF(data, filename: "sample.pdf", pageCount: 2)
        let duplicate = try await repository.importPDF(data, filename: "another.pdf", pageCount: 2)
        #expect(book.id == duplicate.id)
        try await repository.saveProgress(bookID: book.id, pageIndex: 1)
        let reloaded = LibraryRepository(root: root)
        #expect(try await reloaded.load().books.count == 1)
        #expect(try await reloaded.load().books.first?.lastPageIndex == 1)
        #expect(try await reloaded.readAsset(for: book) == data)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("library-v1.json.backup").path))
    }
    @Test func corruptAndFutureStoresArePreservedWithoutWrites() async throws {
        for bytes in [Data("{broken".utf8), Data("{\"schemaVersion\":99,\"books\":[],\"notes\":[]}".utf8)] {
            let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let url = root.appendingPathComponent("library-v1.json")
            try bytes.write(to: url)
            let repository = LibraryRepository(root: root)
            do { _ = try await repository.importPDF(originalSample(), filename: "sample.pdf", pageCount: 2); Issue.record("Corrupt/future store was overwritten") }
            catch { #expect(error is LibraryError) }
            #expect(try Data(contentsOf: url) == bytes)
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Originals").path))
        }
    }
    @Test func notesRoundTripRejectStaleRevisionsAndSourceSubstitution() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = LibraryRepository(root: root)
        let book = try await repository.importPDF(originalSample(), filename: "sample.pdf", pageCount: 2)
        let anchor = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: "window",
                                    regions: [PageRegion(pageIndex: 0, x: 72, y: 650, width: 40, height: 16, quote: "window")])
        var note = ReadingNote(bookID: book.id, anchor: anchor, userText: "original")
        try await repository.saveNote(note)
        do { try await repository.saveNote(note); Issue.record("Stale note was accepted") } catch { #expect(error is LibraryError) }
        note.revision = 2; note.userText = "revised"
        try await repository.saveNote(note)
        #expect(try await repository.load().notes.first?.userText == "revised")
        let bad = PDFSourceAnchor(editionID: UUID(), fileSHA256: book.fileSHA256, quote: "window", regions: anchor.regions)
        do { try await repository.saveNote(ReadingNote(bookID: book.id, anchor: bad)); Issue.record("Foreign edition accepted") } catch { #expect(error is LibraryError) }
        let asset = await repository.assetURL(for: book)
        try Data("changed".utf8).write(to: asset)
        do { _ = try await repository.readAsset(for: book); Issue.record("Changed PDF accepted") } catch { #expect(error is LibraryError) }
    }
    @Test func duplicateIdentifiersAndSecretTopLevelFieldsAreRejected() throws {
        let book = BookRecord(title: "sample", fileSHA256: String(repeating: "a", count: 64), originalFilename: "sample.pdf", pageCount: 2)
        var state = LibraryState(); state.books = [book,book]
        #expect(throws: LibraryError.self) { try LibraryRepository.decode(JSONEncoder().encode(state)) }
        #expect(throws: LibraryError.self) {
            try LibraryRepository.decode(Data("{\"schemaVersion\":1,\"books\":[],\"notes\":[],\"apiKey\":\"fake-test-only\"}".utf8))
        }
        state.books = [book]
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var rows = try #require(object["books"] as? [[String: Any]])
        rows[0]["apiKey"] = "fake-test-only"; object["books"] = rows
        #expect(throws: LibraryError.self) { try LibraryRepository.decode(JSONSerialization.data(withJSONObject: object)) }
    }
}
