// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

struct LibraryImmediateCommitTests {
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Immediate-" + UUID().uuidString)
    }
    private func note(_ book: BookRecord, text: String) -> ReadingNote {
        ReadingNote(bookID: book.id, anchor: PDFSourceAnchor(editionID: book.editionID,
            fileSHA256: book.fileSHA256, quote: "window",
            regions: [PageRegion(pageIndex: 0, x: 72, y: 650, width: 40, height: 16, quote: "window")]), userText: text)
    }
    @Test func returnedCommandAlreadyHasAtomicUnicodeRecordAndOriginal() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LibraryRepository(root: root), data = try originalSample()
        let book = try await repository.importPDF(data, filename: "original.pdf", pageCount: 2)
        let expected = note(book, text: "Original shell draft 日本語 cafe\u{301} 👩🏽‍🚀")
        let result = try repository.saveNoteImmediately(expected)
        let disk = try LibraryRepository.decode(Data(contentsOf: root.appendingPathComponent("library-v1.json")))
        #expect(result.notes == [expected] && disk.notes == [expected])
        #expect(disk.books == result.books && disk.books.first?.id == book.id)
        #expect(try Data(contentsOf: root.appendingPathComponent("Originals/" + book.fileSHA256 + ".pdf")) == data)
    }
    @Test func synchronousAndActorWritersNeverLoseNotesOrProgressAcrossInstances() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let first = LibraryRepository(root: root), second = LibraryRepository(root: root)
        let book = try await first.importPDF(originalSample(), filename: "original.pdf", pageCount: 2)
        let expected = (0..<24).map { note(book, text: "Original concurrent note \($0)") }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, record) in expected.enumerated() {
                group.addTask {
                    if index.isMultiple(of: 2) { _ = try first.saveNoteImmediately(record) }
                    else { try await second.saveNote(record) }
                }
            }
            group.addTask { for index in 0..<24 { try await second.saveProgress(bookID: book.id, pageIndex: index % 2) } }
            try await group.waitForAll()
        }
        let state = try await first.load()
        #expect(Set(state.notes.map(\.id)) == Set(expected.map(\.id)))
        #expect(state.notes.count == 24 && state.books.first?.lastPageIndex == 1)
        for record in expected { #expect(state.notes.first { $0.id == record.id } == record) }
    }
    @Test func pausedCommandCannotWriteAndCorruptFutureFilesRemainExact() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LibraryRepository(root: root)
        let book = try await repository.importPDF(originalSample(), filename: "original.pdf", pageCount: 2)
        let expected = note(book, text: "Original paused note"), file = root.appendingPathComponent("library-v1.json")
        let before = try Data(contentsOf: file)
        let pause = try LocalStoreWriteGate.shared(root: root).beginPause(); try await pause.drain()
        #expect(throws: LocalStoreWriteGateError.paused) { try repository.saveNoteImmediately(expected) }
        #expect(try Data(contentsOf: file) == before); pause.finish()
        for bytes in [Data("{broken".utf8), Data("{\"schemaVersion\":99,\"books\":[],\"notes\":[]}".utf8)] {
            try bytes.write(to: file, options: .atomic)
            #expect(throws: LibraryError.self) { try repository.saveNoteImmediately(expected) }
            #expect(try Data(contentsOf: file) == bytes)
        }
    }
    @Test func immediateCommitRetainsStrictSourceAndCASRevisionChecks() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LibraryRepository(root: root)
        let book = try await repository.importPDF(originalSample(), filename: "original.pdf", pageCount: 2)
        let first = note(book, text: "Original CAS baseline")
        _ = try repository.saveNoteImmediately(first)
        #expect(throws: LibraryError.revisionConflict) { try repository.saveNoteImmediately(first) }
        let next = try await repository.updateNoteBody(expected: first, text: "Original revised body")
        #expect(next.revision == 2 && next.anchor == first.anchor)
        let foreign = BookRecord(title: book.title, fileSHA256: book.fileSHA256, originalFilename: book.originalFilename, pageCount: 2)
        #expect(throws: LibraryError.sourceMismatch) { try repository.saveNoteImmediately(note(foreign, text: "Foreign source")) }
        #expect(try await repository.load().notes == [next])
    }
}
