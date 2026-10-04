// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

private func japaneseStorageNote(id: UUID = UUID(), text: String = " 原创独立笔记\nか\u{3099}👩🏽‍🚀 ") throws -> JapaneseLearningNote {
    let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig(mock: false))
    let review = JapaneseLearningValidator.validate(try japaneseData(japanesePayload(request.source.anchor.quote,
        readings: [japaneseReading()], grammar: [japaneseGrammar()])), request: request)
    return try JapaneseLearningNote(id: id, review: review, userText: text,
        corrections: [JapaneseReadingCorrection(span: review.readings[0].span, reading: "ネコ")])
}
private func japaneseStorageRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Japanese-Store-" + UUID().uuidString) }
struct JapaneseLearningRepositoryTests {
    @Test func strictRoundTripLeavesAllLegacyFilesAndOriginalUntouched() async throws {
        let root = japaneseStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let untouched = ["library-v1.json", "epub-v1.json", "learning-v1.json", "original.epub"]
        let sentinel = Data("Original unrelated private sentinel".utf8)
        for name in untouched { try sentinel.write(to: root.appendingPathComponent(name)) }
        let repository = JapaneseLearningRepository(root: root), note = try japaneseStorageNote()
        #expect(try await repository.load().notes.isEmpty)
        try await repository.saveNote(note)
        let restarted = JapaneseLearningRepository(root: root), saved = try #require(await restarted.load().notes.first)
        #expect(saved == note && saved.userText.utf8.elementsEqual(note.userText.utf8))
        #expect(saved.review.promptVersion == JapaneseLearningPolicy.promptVersion && saved.corrections[0].reading == "ネコ")
        for name in untouched { #expect(try Data(contentsOf: root.appendingPathComponent(name)) == sentinel) }
        let wire = try String(contentsOf: root.appendingPathComponent(JapaneseLearningRepository.filename), encoding: .utf8)
        #expect(!wire.contains("Authorization") && !wire.contains("synthetic-japanese-offline-only"))
    }
    @Test func atomicBackupIdempotentCreationAndConflictsNeverOverwrite() async throws {
        let root = japaneseStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = JapaneseLearningRepository(root: root), first = try japaneseStorageNote(), second = try japaneseStorageNote()
        let path = root.appendingPathComponent(JapaneseLearningRepository.filename), backup = path.appendingPathExtension("backup")
        try await repository.saveNote(first); let original = try Data(contentsOf: path)
        try await repository.saveNote(second); let latest = try Data(contentsOf: path)
        #expect(try Data(contentsOf: backup) == original)
        try await repository.saveNote(second)
        #expect(try Data(contentsOf: path) == latest && Data(contentsOf: backup) == original)
        let conflict = try JapaneseLearningNote(id: first.id, review: first.review, userText: "different", corrections: first.corrections)
        await #expect(throws: AIFailure.stale) { try await repository.saveNote(conflict) }
        let replay = try JapaneseLearningNote(review: first.review, userText: first.userText, corrections: first.corrections)
        await #expect(throws: AIFailure.stale) { try await repository.saveNote(replay) }
        #expect(try Data(contentsOf: path) == latest)
    }
    @Test func futureUnknownOrMalformedManifestIsProtectedFromWrites() async throws {
        let first = try japaneseStorageNote(), encoder = JSONEncoder()
        let valid = try JSONSerialization.jsonObject(with: encoder.encode(JapaneseLearningState(notes: [first]))) as! [String: Any]
        for change in [["schemaVersion": 2], ["schemaVersion": true], ["newField": "future"], ["notes": "wrong"]] as [[String: Any]] {
            let root = japaneseStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            var object = valid; object.merge(change) { _, next in next }
            let bad = try japaneseData(object), path = root.appendingPathComponent(JapaneseLearningRepository.filename)
            try bad.write(to: path)
            let repository = JapaneseLearningRepository(root: root)
            await #expect(throws: AIFailure.store) { try await repository.load() }
            await #expect(throws: AIFailure.store) { try await repository.saveNote(japaneseStorageNote()) }
            #expect(try Data(contentsOf: path) == bad)
        }
    }
    @Test func decodedSourceSpanPromptAndNestedUnknownFieldsAreRevalidated() throws {
        let encoder = JSONEncoder(), note = try japaneseStorageNote()
        let valid = try JSONSerialization.jsonObject(with: encoder.encode(JapaneseLearningState(notes: [note]))) as! [String: Any]
        for mode in 0..<5 {
            var object = valid, notes = object["notes"] as! [[String: Any]], record = notes[0], review = record["review"] as! [String: Any]
            if mode == 0 { review["promptVersion"] = "future" }
            if mode == 1 { review["schemaVersion"] = 99 }
            if mode == 2 { review["status"] = "unavailable" }
            if mode == 3 {
                var readings = review["readings"] as! [[String: Any]], span = readings[0]["span"] as! [String: Any]
                span["quote"] = "犬"; readings[0]["span"] = span; review["readings"] = readings
            }
            if mode == 4 {
                var source = review["source"] as! [String: Any]; source["newField"] = "future"; review["source"] = source
            }
            record["review"] = review; notes[0] = record; object["notes"] = notes
            #expect(throws: AIFailure.store) { try JapaneseLearningRepository.decode(japaneseData(object)) }
        }
        let text = String(decoding: try encoder.encode(JapaneseLearningState(notes: [note])), as: UTF8.self)
        #expect(throws: AIFailure.store) { try JapaneseLearningRepository.decode(Data((text.dropLast() + ",\"schemaVersion\":1}").utf8)) }
    }
    @Test func failedBackupLeavesValidManifestAndNoteUnchanged() async throws {
        let root = japaneseStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = JapaneseLearningRepository(root: root), note = try japaneseStorageNote()
        try await repository.saveNote(note)
        let path = root.appendingPathComponent(JapaneseLearningRepository.filename), before = try Data(contentsOf: path)
        try FileManager.default.createDirectory(at: path.appendingPathExtension("backup"), withIntermediateDirectories: false)
        do { try await repository.saveNote(japaneseStorageNote()); Issue.record("Backup obstruction must reject save") } catch {}
        #expect(try Data(contentsOf: path) == before)
        #expect(try await repository.load().notes.count == 1)
    }
    @Test func independentWindowRepositoriesSerializeAppendsWithoutLostNotes() async throws {
        let root = japaneseStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let first = JapaneseLearningRepository(root: root), second = JapaneseLearningRepository(root: root)
        let a = try japaneseStorageNote(), b = try japaneseStorageNote()
        async let one: Void = first.saveNote(a)
        async let two: Void = second.saveNote(b)
        _ = try await (one, two)
        #expect(Set(try await first.load().notes.map(\.id)) == Set([a.id, b.id]))
    }
    @Test func canonicallyEquivalentUserBodyCannotOverwriteSameID() async throws {
        let root = japaneseStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = JapaneseLearningRepository(root: root), first = try japaneseStorageNote(text: "é")
        try await repository.saveNote(first)
        let second = try JapaneseLearningNote(id: first.id, review: first.review, userText: "e\u{301}", corrections: first.corrections)
        #expect(first.userText == second.userText && !first.userText.utf8.elementsEqual(second.userText.utf8))
        await #expect(throws: AIFailure.stale) { try await repository.saveNote(second) }
        #expect(try await repository.load().notes[0].userText.utf8.elementsEqual(first.userText.utf8))
    }
    @Test func invalidOutputNeverCreatesManifest() async throws {
        let root = japaneseStorageRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        let review = JapaneseLearningValidator.validate(Data("invalid".utf8), request: request)
        let note = try JapaneseLearningNote(review: review, userText: "keep source", corrections: [])
        #expect(!note.isPersistable)
        await #expect(throws: AIFailure.output) { try await JapaneseLearningRepository(root: root).saveNote(note) }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(JapaneseLearningRepository.filename).path))
    }
}
