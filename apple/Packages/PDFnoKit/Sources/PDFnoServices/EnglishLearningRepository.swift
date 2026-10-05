// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public struct EnglishLearningState: Codable, Sendable {
    public let schemaVersion: Int
    public var notes: [EnglishLearningNote]
    public init(notes: [EnglishLearningNote] = []) { schemaVersion = 1; self.notes = notes }
}
/// Separate manifest: existing PDF/EPUB/learning stores and schemas are never rewritten here.
public actor EnglishLearningRepository {
    public static let filename = "english-learning-v1.json"
    public static let maxBytes = 5 * 1024 * 1024
    private let root: URL
    public init(root: URL) { self.root = root.standardizedFileURL.resolvingSymlinksInPath() }
    public func load() async throws -> EnglishLearningState { try await EnglishLearningFileGate.shared.load(root: root) }
    public func saveNote(_ note: EnglishLearningNote) async throws { try await EnglishLearningFileGate.shared.save(note, root: root) }
    public func updateNoteBody(expected: EnglishLearningNote, text: String) async throws -> EnglishLearningNote {
        try await EnglishLearningFileGate.shared.updateBody(expected: expected, text: text, root: root)
    }
    public static func decode(_ data: Data) throws -> EnglishLearningState {
        guard data.count <= maxBytes, JapaneseLearningJSON.hasUniqueKeysForStore(data),
              let value = try? JSONSerialization.jsonObject(with: data),
              let state = value as? [String: Any], Set(state.keys) == Set(["schemaVersion", "notes"]),
              EnglishLearningValidator.integer(state["schemaVersion"]) == 1,
              let notes = state["notes"] as? [Any], notes.count <= 1000,
              let decoded = try? JSONDecoder().decode(EnglishLearningState.self, from: data),
              decoded.schemaVersion == 1, Set(decoded.notes.map(\.id)).count == decoded.notes.count,
              Set(decoded.notes.map { $0.review.requestID }).count == decoded.notes.count,
              decoded.notes.allSatisfy(\.isPersistable) else { throw AIFailure.store }
        // Compare the complete tree with the typed representation: reject unknown fields at
        // every depth, wrong container types, missing required data, and null/type substitution.
        let encoded = try JSONEncoder().encode(decoded)
        let expected = try JSONSerialization.jsonObject(with: encoded)
        guard strictTree(value, expected) else { throw AIFailure.store }
        return decoded
    }
    private static func strictTree(_ raw: Any, _ typed: Any) -> Bool {
        if let expected = typed as? [String: Any] {
            guard let actual = raw as? [String: Any], Set(actual.keys) == Set(expected.keys) else { return false }
            return expected.allSatisfy { key, value in strictTree(actual[key]!, value) }
        }
        if let expected = typed as? [Any] {
            guard let actual = raw as? [Any], actual.count == expected.count else { return false }
            return zip(actual, expected).allSatisfy { strictTree($0, $1) }
        }
        if let expected = typed as? String {
            guard let actual = raw as? String else { return false }; return actual.utf8.elementsEqual(expected.utf8)
        }
        if let expected = typed as? NSNumber {
            guard let actual = raw as? NSNumber else { return false }
            let expectedType = String(cString: expected.objCType), actualType = String(cString: actual.objCType)
            let booleans = ["c", "B"]
            guard booleans.contains(expectedType) == booleans.contains(actualType) else { return false }
            if !booleans.contains(expectedType), EnglishLearningValidator.integer(expected) != nil {
                guard EnglishLearningValidator.integer(actual) != nil else { return false }
            }
            return actual == expected
        }
        return raw is NSNull && typed is NSNull
    }
}
/// Serial synchronous transactions across all same-process windows/repository instances.
/// Atomic files/validated backup protect failures; cross-process/disaster recovery is not claimed.
private actor EnglishLearningFileGate {
    static let shared = EnglishLearningFileGate()
    func load(root: URL) throws -> EnglishLearningState {
        let path = root.appendingPathComponent(EnglishLearningRepository.filename)
        guard FileManager.default.fileExists(atPath: path.path) else { return EnglishLearningState() }
        return try EnglishLearningRepository.decode(BoundedFileReader.read(path, limit: EnglishLearningRepository.maxBytes))
    }
    func updateBody(expected: EnglishLearningNote, text: String, root: URL) throws -> EnglishLearningNote {
        try Task.checkCancellation()
        guard text.utf16.count <= 16000 else { throw NoteBodyEditError.tooLong }
        var state = try load(root: root)
        guard let index = state.notes.firstIndex(where: { $0.id == expected.id }) else { throw NoteBodyEditError.conflict }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let current = state.notes[index]
        guard try encoder.encode(current) == encoder.encode(expected) else { throw NoteBodyEditError.conflict }
        guard !current.userText.utf8.elementsEqual(text.utf8) else { return current }
        let next = try EnglishLearningNote(id: current.id, review: current.review, userText: text)
        state.notes[index] = next
        try commit(state, root: root); return next
    }
    private func commit(_ state: EnglishLearningState, root: URL) throws {
        let path = root.appendingPathComponent(EnglishLearningRepository.filename)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state); _ = try EnglishLearningRepository.decode(data)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: path.path) {
            let previous = try BoundedFileReader.read(path, limit: EnglishLearningRepository.maxBytes)
            _ = try EnglishLearningRepository.decode(previous)
            try previous.write(to: path.appendingPathExtension("backup"), options: .atomic)
        }
        try Task.checkCancellation()
        try data.write(to: path, options: .atomic)
    }
    func save(_ note: EnglishLearningNote, root: URL) throws {
        try Task.checkCancellation()
        guard note.isPersistable else { throw AIFailure.output }
        var state = try load(root: root)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let old = state.notes.first(where: { $0.id == note.id }) {
            guard try encoder.encode(old) == encoder.encode(note) else { throw AIFailure.stale }
            return // Same stable new-note ID and exact bytes: acknowledged without rewriting.
        }
        guard state.notes.count < 1000, !state.notes.contains(where: { $0.review.requestID == note.review.requestID }) else { throw AIFailure.stale }
        state.notes.append(note)
        try commit(state, root: root)
    }
}
