// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

func englishStorageRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-English-Synthetic-" + UUID().uuidString) }
func englishStorageNote(id: UUID = UUID(), text: String = " 独立学习正文\ne\u{301} 👩🏽‍🚀 ") throws -> EnglishLearningNote {
    try EnglishLearningNote(id: id, review: englishReview(), userText: text)
}
func englishStoreObject(_ note: EnglishLearningNote) throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(EnglishLearningState(notes: [note]))) as? [String: Any])
}
struct EnglishLearningRepositoryTests {
    @Test func strictRestartPreservesSourceHashUserBytesAndUnrelatedStores() async throws {
        let root = englishStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let names = ["library-v1.json", "epub-v1.json", "learning-v1.json", "japanese-learning-v1.json", "original.pdf"]
        let sentinel = Data("self-authored untouched sentinel".utf8)
        for name in names { try sentinel.write(to: root.appendingPathComponent(name)) }
        let repository = EnglishLearningRepository(root: root), note = try englishStorageNote()
        #expect(try await repository.load().notes.isEmpty)
        try await repository.saveNote(note)
        let saved = try #require(await EnglishLearningRepository(root: root).load().notes.first)
        #expect(saved == note && saved.userText.utf8.elementsEqual(note.userText.utf8))
        #expect(saved.review.sourceTextSHA256 == EnglishLearningPolicy.textHash(saved.review.source.anchor.quote))
        for name in names { #expect(try Data(contentsOf: root.appendingPathComponent(name)) == sentinel) }
    }
    @Test func backupsAndIdempotenceCannotOverwriteDifferentUserBody() async throws {
        let root = englishStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = EnglishLearningRepository(root: root), a = try englishStorageNote(), b = try englishStorageNote()
        let path = root.appendingPathComponent(EnglishLearningRepository.filename), backup = path.appendingPathExtension("backup")
        try await repository.saveNote(a); let first = try Data(contentsOf: path)
        try await repository.saveNote(b); let latest = try Data(contentsOf: path)
        #expect(try Data(contentsOf: backup) == first)
        try await repository.saveNote(b)
        #expect(try Data(contentsOf: path) == latest && Data(contentsOf: backup) == first)
        let conflict = try EnglishLearningNote(id: a.id, review: a.review, userText: "different")
        await #expect(throws: AIFailure.stale) { try await repository.saveNote(conflict) }
        let replay = try EnglishLearningNote(review: a.review, userText: a.userText)
        await #expect(throws: AIFailure.stale) { try await repository.saveNote(replay) }
        #expect(try Data(contentsOf: path) == latest)
    }
    @Test func compareAndSwapEditsOnlyBodyAndProtectsStaleWriter() async throws {
        let root = englishStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = EnglishLearningRepository(root: root), note = try englishStorageNote(text: "é")
        try await repository.saveNote(note)
        let next = try await repository.updateNoteBody(expected: note, text: "e\u{301}")
        #expect(next.review == note.review && next.id == note.id && next.userText.utf8.elementsEqual("e\u{301}".utf8))
        await #expect(throws: NoteBodyEditError.conflict) { try await repository.updateNoteBody(expected: note, text: "stale edit") }
        #expect(try await repository.load().notes[0] == next)
        await #expect(throws: NoteBodyEditError.tooLong) { try await repository.updateNoteBody(expected: next, text: String(repeating: "x", count: 16001)) }
    }
    @Test func twoRepositoryActorsSerializeWithoutLostNotes() async throws {
        let root = englishStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let a = EnglishLearningRepository(root: root), b = EnglishLearningRepository(root: root)
        let one = try englishStorageNote(), two = try englishStorageNote()
        async let first: Void = a.saveNote(one)
        async let second: Void = b.saveNote(two)
        _ = try await (first, second)
        #expect(Set(try await a.load().notes.map(\.id)) == Set([one.id, two.id]))
    }
    @Test func corruptFutureAndOversizeStoresRejectWritesWithoutChangingBytes() async throws {
        var future = try englishStoreObject(englishStorageNote()); future["schemaVersion"] = 2
        for bad in [Data("corrupt".utf8), try englishData(future), Data(repeating: 32, count: EnglishLearningRepository.maxBytes + 1)] {
            let root = englishStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let path = root.appendingPathComponent(EnglishLearningRepository.filename); try bad.write(to: path)
            let repository = EnglishLearningRepository(root: root)
            do { _ = try await repository.load(); Issue.record("Invalid manifest loaded") } catch {}
            do { try await repository.saveNote(englishStorageNote()); Issue.record("Invalid manifest overwritten") } catch {}
            #expect(try Data(contentsOf: path) == bad)
            #expect(!FileManager.default.fileExists(atPath: path.appendingPathExtension("backup").path))
        }
    }
    @Test func decodedNestedFieldsHashContextAndTypesAreRevalidated() throws {
        let original = try englishStoreObject(englishStorageNote())
        for mode in 0..<12 {
            var store = original, notes = store["notes"] as! [[String: Any]], note = notes[0], review = note["review"] as! [String: Any]
            switch mode {
            case 0: store["schemaVersion"] = true
            case 1: store["unknown"] = 1
            case 2: note["secret"] = "untrusted field"
            case 3: review["promptVersion"] = "future"
            case 4: review["sourceTextSHA256"] = String(repeating: "0", count: 64)
            case 5: review["status"] = "unavailable"
            case 6:
                var source = review["source"] as! [String: Any]; source["newField"] = 1; review["source"] = source
            case 7:
                var config = review["provider"] as! [String: Any]; config["generation"] = true; review["provider"] = config
            default:
                var rows = review["components"] as! [[String: Any]], row = rows[0], span = row["span"] as! [String: Any]
                if mode == 8 { span["prefix"] = "wrong adjacent context" }
                if mode == 9 { span["unknown"] = "new" }
                if mode == 10 { span["start"] = true }
                if mode == 11 { row["inferred"] = true }
                row["span"] = span; rows[0] = row; review["components"] = rows
            }
            note["review"] = review; notes[0] = note; store["notes"] = notes
            #expect(throws: AIFailure.store) { try EnglishLearningRepository.decode(englishData(store)) }
        }
    }
    @Test func duplicateNoteReviewAndEscapedJSONIDsAreRefused() throws {
        let note = try englishStorageNote()
        #expect(throws: AIFailure.store) { try EnglishLearningRepository.decode(JSONEncoder().encode(EnglishLearningState(notes: [note, note]))) }
        let sameReview = try EnglishLearningNote(review: note.review, userText: "other")
        #expect(throws: AIFailure.store) { try EnglishLearningRepository.decode(JSONEncoder().encode(EnglishLearningState(notes: [note, sameReview]))) }
        let data = try JSONEncoder().encode(EnglishLearningState(notes: [note])), text = String(decoding: data, as: UTF8.self)
        #expect(throws: AIFailure.store) { try EnglishLearningRepository.decode(Data((text.dropLast() + ",\"schema\\u0056ersion\":1}").utf8)) }
    }
    @Test func failedBackupPreservesManifestAndNoSuccessIsInvented() async throws {
        let root = englishStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = EnglishLearningRepository(root: root); try await repository.saveNote(englishStorageNote())
        let path = root.appendingPathComponent(EnglishLearningRepository.filename), before = try Data(contentsOf: path)
        try FileManager.default.createDirectory(at: path.appendingPathExtension("backup"), withIntermediateDirectories: false)
        do { try await repository.saveNote(englishStorageNote()); Issue.record("Obstructed backup succeeded") } catch {}
        #expect(try Data(contentsOf: path) == before)
        #expect(try await repository.load().notes.count == 1)
    }
    @Test func unavailableReviewCannotCreateManifest() async throws {
        let root = englishStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let review = EnglishLearningValidator.validate(Data("invalid".utf8), request: englishRequest())
        let note = try EnglishLearningNote(review: review, userText: "draft")
        #expect(!note.isPersistable)
        await #expect(throws: AIFailure.output) { try await EnglishLearningRepository(root: root).saveNote(note) }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(EnglishLearningRepository.filename).path))
    }
    @Test func canonicalEquivalentBodyReplayIsNotIdempotent() async throws {
        let root = englishStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = EnglishLearningRepository(root: root), a = try englishStorageNote(text: "é")
        try await repository.saveNote(a)
        let b = try EnglishLearningNote(id: a.id, review: a.review, userText: "e\u{301}")
        await #expect(throws: AIFailure.stale) { try await repository.saveNote(b) }
        #expect(try await repository.load().notes[0].userText.utf8.elementsEqual("é".utf8))
    }
}
