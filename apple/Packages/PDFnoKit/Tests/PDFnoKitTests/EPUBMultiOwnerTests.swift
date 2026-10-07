// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

private actor EPUBWriterStart {
    let count: Int
    var waiters: [CheckedContinuation<Void, Never>] = []
    init(_ count: Int) { self.count = count }
    func arrive() async {
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
            if waiters.count == count {
                let ready = waiters; waiters.removeAll()
                for waiter in ready { waiter.resume() }
            }
        }
    }
}

struct EPUBMultiOwnerTests {
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-EPUB-Multi-Owner-" + UUID().uuidString)
    }
    private func sample() throws -> Data {
        try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: "epub", subdirectory: "Fixtures")))
    }
    private func secondArchive(_ original: Data) throws -> Data {
        let offset = original.count - 22, comment = Data("Original second fixture archive".utf8)
        try #require(offset >= 0 && original.subdata(in: offset..<(offset + 4)) == Data([0x50, 0x4b, 0x05, 0x06]))
        try #require(original.suffix(2) == Data([0, 0]))
        var next = original; next[next.count - 2] = UInt8(comment.count); next.append(comment)
        _ = try EPUBArchive.validate(next); return next
    }
    private func anchor(_ book: EPUBBook) -> EPUBAnchor {
        EPUBAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, resourceHref: "OEBPS/english.xhtml",
            spineIndex: 0, start: 0, end: 6, quote: "window", prefix: "", suffix: "", vertical: false)
    }

    @Test func independentActorsRetainAllAcknowledgedNotesDuringImportAndProgress() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let p = EPUBRepository(root: root), q = EPUBRepository(root: root), original = try sample()
        let book = try await p.importBook(original, filename: "Original.epub"), point = anchor(book)
        let second = try secondArchive(original)
        let notes = (0..<32).map { EPUBNote(bookID: book.id, anchor: point, userText: "Original acknowledged \($0) 日本語 cafe\u{301}") }
        let start = EPUBWriterStart(notes.count + 2)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (index, note) in notes.enumerated() {
                group.addTask { await start.arrive(); try await (index.isMultiple(of: 2) ? p : q).saveNote(note) }
            }
            group.addTask { await start.arrive(); try await q.saveProgress(point, bookID: book.id) }
            group.addTask { await start.arrive(); _ = try await p.importBook(second, filename: "Original second.epub") }
            try await group.waitForAll()
        }
        let state = try await EPUBRepository(root: root).load()
        #expect(state.notes.count == notes.count && Set(state.notes.map(\.id)) == Set(notes.map(\.id)))
        #expect(state.notes.allSatisfy { actual in notes.contains { $0 == actual && $0.userText.utf8.elementsEqual(actual.userText.utf8) } })
        #expect(state.books.count == 2 && state.books.first { $0.id == book.id }?.progress == point)
        #expect(try await p.read(book) == original)
        let imported = try #require(state.books.first { $0.id != book.id })
        #expect(try await q.read(imported) == second)
        let backup = try EPUBRepository.decode(Data(contentsOf: root.appendingPathComponent("epub-v1.json.backup")))
        #expect(backup.schemaVersion == 1 && !backup.books.isEmpty)
        #expect(LocalStoreWriteGate.shared(root: root).snapshot.activeWrites == 0)
    }

    @Test func sameExpectedNoteCASHasOneWinnerAndDoesNotEraseOtherNotes() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let p = EPUBRepository(root: root), q = EPUBRepository(root: root)
        let book = try await p.importBook(sample(), filename: "Original.epub"), point = anchor(book)
        let baseline = EPUBNote(bookID: book.id, anchor: point, userText: "cafe\u{301}")
        let other = EPUBNote(bookID: book.id, anchor: point, userText: "Original other note")
        try await p.saveNote(baseline); try await q.saveNote(other)
        let start = EPUBWriterStart(2)
        let wins = try await withThrowingTaskGroup(of: Bool.self) { group in
            for (repository, text) in [(p, "Original edit A"), (q, "Original edit B")] {
                group.addTask {
                    await start.arrive()
                    do { _ = try await repository.updateNoteBody(expected: baseline, text: text); return true }
                    catch NoteBodyEditError.conflict { return false }
                }
            }
            var results: [Bool] = []; for try await result in group { results.append(result) }; return results
        }
        #expect(wins.filter { $0 }.count == 1 && wins.filter { !$0 }.count == 1)
        let state = try await p.load(), edited = try #require(state.notes.first { $0.id == baseline.id })
        #expect(state.notes.count == 2 && state.notes.contains(other) && edited.anchor == point)
        #expect(["Original edit A", "Original edit B"].contains(edited.userText))
        var equivalent = edited
        equivalent = EPUBNote(id: edited.id, bookID: edited.bookID, anchor: edited.anchor, userText: edited.userText + "é")
        let unicode = try await q.updateNoteBody(expected: edited, text: equivalent.userText)
        let stale = EPUBNote(id: unicode.id, bookID: unicode.bookID, anchor: unicode.anchor, userText: edited.userText + "e\u{301}")
        await #expect(throws: NoteBodyEditError.conflict) { try await p.updateNoteBody(expected: stale, text: "must not replace scalar source") }
        #expect(try await q.load().notes.contains(unicode))
        _ = try EPUBRepository.decode(Data(contentsOf: root.appendingPathComponent("epub-v1.json.backup")))
    }

    @Test func canonicalRootAliasesCoordinateAndSeparateRootsRemainSeparate() async throws {
        let base = root(); defer { try? FileManager.default.removeItem(at: base) }
        let real = base.appendingPathComponent("real"), alias = base.appendingPathComponent("alias"), isolated = base.appendingPathComponent("separate")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: real)
        let p = EPUBRepository(root: real), q = EPUBRepository(root: alias), separate = EPUBRepository(root: isolated)
        let bytes = try sample(), book = try await p.importBook(bytes, filename: "Original.epub")
        let notes = (0..<24).map { EPUBNote(bookID: book.id, anchor: anchor(book), userText: "Original alias \($0)") }
        let start = EPUBWriterStart(notes.count)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (i, note) in notes.enumerated() { group.addTask { await start.arrive(); try await (i.isMultiple(of: 2) ? p : q).saveNote(note) } }
            try await group.waitForAll()
        }
        let ownBook = try await separate.importBook(bytes, filename: "Original separate.epub")
        let ownNote = EPUBNote(bookID: ownBook.id, anchor: anchor(ownBook), userText: "Original separate root")
        try await separate.saveNote(ownNote)
        #expect(try await q.load().notes.count == 24)
        #expect(try await separate.load().notes == [ownNote])
        #expect(LocalStoreWriteGate.shared(root: real) === LocalStoreWriteGate.shared(root: alias))
    }

    @Test func corruptAndFutureManifestRefuseEveryMutationWithoutReplacingBytes() async throws {
        for bad in [Data("{broken".utf8), Data("{\"schemaVersion\":99,\"books\":[],\"notes\":[]}".utf8)] {
            let root = root(); defer { try? FileManager.default.removeItem(at: root) }
            let p = EPUBRepository(root: root), q = EPUBRepository(root: root), bytes = try sample()
            let book = try await p.importBook(bytes, filename: "Original.epub"), point = anchor(book)
            let note = EPUBNote(bookID: book.id, anchor: point, userText: "Original baseline")
            try await p.saveNote(note)
            let path = root.appendingPathComponent("epub-v1.json"), backup = try Data(contentsOf: path.appendingPathExtension("backup"))
            try bad.write(to: path)
            await #expect(throws: EPUBError.self) { try await p.importBook(bytes, filename: "must not replace.epub") }
            await #expect(throws: EPUBError.self) { try await q.saveProgress(point, bookID: book.id) }
            await #expect(throws: EPUBError.self) { try await p.saveNote(EPUBNote(bookID: book.id, anchor: point, userText: "must not append")) }
            await #expect(throws: EPUBError.self) { try await q.updateNoteBody(expected: note, text: "must not overwrite") }
            #expect(try Data(contentsOf: path) == bad && Data(contentsOf: path.appendingPathExtension("backup")) == backup)
            #expect(try Data(contentsOf: root.appendingPathComponent("Originals/" + book.fileSHA256 + ".epub")) == bytes)
            #expect(LocalStoreWriteGate.shared(root: root).snapshot.activeWrites == 0)
        }
    }

    @Test func transactionLocksPreservePauseDrainAndEpochAdmission() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let p = EPUBRepository(root: root), q = EPUBRepository(root: root), bytes = try sample()
        let book = try await p.importBook(bytes, filename: "Original.epub"), point = anchor(book)
        let note = EPUBNote(bookID: book.id, anchor: point, userText: "Original pending note")
        let gate = LocalStoreWriteGate.shared(root: root), oldEpoch = gate.snapshot.epoch
        let lease = try gate.beginWrite(), pause = try gate.beginPause()
        #expect(gate.snapshot.activeWrites == 1 && gate.snapshot.phase == .draining)
        lease.finish(); try await pause.drain(); try pause.assertReady()
        let before = try Data(contentsOf: root.appendingPathComponent("epub-v1.json"))
        await #expect(throws: LocalStoreWriteGateError.paused) { try await p.saveNote(note) }
        await #expect(throws: LocalStoreWriteGateError.paused) { try await q.saveProgress(point, bookID: book.id) }
        await #expect(throws: LocalStoreWriteGateError.paused) { try await p.importBook(bytes, filename: "paused.epub") }
        await #expect(throws: LocalStoreWriteGateError.paused) { try await q.updateNoteBody(expected: note, text: "paused") }
        #expect(try Data(contentsOf: root.appendingPathComponent("epub-v1.json")) == before)
        pause.finish()
        #expect(throws: LocalStoreWriteGateError.staleEpoch) { try gate.beginWrite(expectedEpoch: oldEpoch) }
        try await q.saveNote(note); try await p.saveProgress(point, bookID: book.id)
        let final = try await q.load()
        #expect(final.notes == [note] && final.books.first?.progress == point)
        #expect(gate.snapshot.activeWrites == 0 && gate.snapshot.phase == .writable)
    }
}
