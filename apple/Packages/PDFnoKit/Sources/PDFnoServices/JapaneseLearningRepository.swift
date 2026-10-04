// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public struct JapaneseLearningState: Codable, Sendable {
    public let schemaVersion: Int
    public var notes: [JapaneseLearningNote]
    public init(notes: [JapaneseLearningNote] = []) { schemaVersion = 1; self.notes = notes }
}
/// Separate manifest: existing PDF/EPUB/learning stores and schemas are never rewritten here.
public actor JapaneseLearningRepository {
    public static let filename = "japanese-learning-v1.json"
    public static let maxBytes = 5 * 1024 * 1024
    private let root: URL
    public init(root: URL) { self.root = root.standardizedFileURL.resolvingSymlinksInPath() }
    public func load() async throws -> JapaneseLearningState { try await JapaneseLearningFileGate.shared.load(root: root) }
    public func saveNote(_ note: JapaneseLearningNote) async throws { try await JapaneseLearningFileGate.shared.save(note, root: root) }
    public func updateNoteBody(expected: JapaneseLearningNote, text: String) async throws -> JapaneseLearningNote {
        try await JapaneseLearningFileGate.shared.updateBody(expected: expected, text: text, root: root)
    }
    public static func decode(_ data: Data) throws -> JapaneseLearningState {
        func object(_ value: Any?, _ required: Set<String>, optional: Set<String> = []) -> [String: Any]? {
            guard let value = value as? [String: Any], required.isSubset(of: Set(value.keys)),
                  Set(value.keys).isSubset(of: required.union(optional)) else { return nil }; return value
        }
        func span(_ value: Any?) -> Bool { object(value, ["start", "end", "quote"]) != nil }
        func source(_ value: Any?) -> Bool {
            guard let value = object(value, ["bookID", "readerSessionID", "documentVersion", "anchor"]),
                  let anchor = value["anchor"] as? [String: Any], anchor.count == 1,
                  let kind = anchor.keys.first, ["pdf", "epub"].contains(kind),
                  let wrapper = object(anchor[kind], ["_0"]) else { return false }
            if kind == "epub" {
                return object(wrapper["_0"], ["schemaVersion", "extractionVersion", "editionID", "fileSHA256", "resourceHref", "spineIndex", "start", "end", "quote", "prefix", "suffix", "vertical"]) != nil
            }
            guard let payload = object(wrapper["_0"], ["schemaVersion", "extractionVersion", "editionID", "fileSHA256", "quote", "regions"]),
                  let regions = payload["regions"] as? [Any] else { return false }
            return regions.allSatisfy { object($0, ["pageIndex", "x", "y", "width", "height", "quote"]) != nil }
        }
        guard data.count <= maxBytes, JapaneseLearningJSON.hasUniqueKeysForStore(data),
              let value = try? JSONSerialization.jsonObject(with: data),
              let state = object(value, ["schemaVersion", "notes"]), let notes = state["notes"] as? [Any], notes.count <= 1000,
              notes.allSatisfy({ raw in
                  guard let note = object(raw, ["id", "review", "userText", "corrections"]),
                        let corrections = note["corrections"] as? [Any], corrections.allSatisfy({
                            guard let correction = object($0, ["span", "reading"]) else { return false }; return span(correction["span"])
                        }),
                        let review = object(note["review"], ["requestID", "source", "provider", "promptVersion", "authorReadings", "readings", "grammar", "warnings", "status"], optional: ["translationZh", "components"]),
                        (review["components"] == nil || (review["components"] as? [Any])?.allSatisfy({ raw in
                            guard let row = object(raw, ["id", "role", "ambiguous", "omitted", "explanationZh"], optional: ["span"]) else { return false }
                            return row["span"] == nil || row["span"] is NSNull || span(row["span"])
                        }) == true),
                        source(review["source"]), object(review["provider"], ["id", "generation", "mode", "label", "endpoint", "model"]) != nil,
                        let author = review["authorReadings"] as? [Any], author.allSatisfy({
                            guard let row = object($0, ["span", "reading"]) else { return false }; return span(row["span"])
                        }),
                        let readings = review["readings"] as? [Any], readings.allSatisfy({
                            guard let row = object($0, ["id", "span", "candidates", "ambiguous", "explanationZh"]) else { return false }; return span(row["span"])
                        }),
                        let grammar = review["grammar"] as? [Any], grammar.allSatisfy({
                            guard let row = object($0, ["id", "span", "labelZh", "explanationZh"]) else { return false }; return span(row["span"])
                        }) else { return false }
                  return true
              }), let decoded = try? JSONDecoder().decode(JapaneseLearningState.self, from: data), decoded.schemaVersion == 1,
              Set(decoded.notes.map(\.id)).count == decoded.notes.count,
              Set(decoded.notes.map { $0.review.requestID }).count == decoded.notes.count,
              decoded.notes.allSatisfy(\.isPersistable) else { throw AIFailure.store }
        return decoded
    }
}
/// Serial synchronous transactions across all same-process windows/repository instances.
/// Atomic files/validated backup protect failures; cross-process/disaster recovery is not claimed.
private actor JapaneseLearningFileGate {
    static let shared = JapaneseLearningFileGate()
    func load(root: URL) throws -> JapaneseLearningState {
        let path = root.appendingPathComponent(JapaneseLearningRepository.filename)
        guard FileManager.default.fileExists(atPath: path.path) else { return JapaneseLearningState() }
        return try JapaneseLearningRepository.decode(BoundedFileReader.read(path, limit: JapaneseLearningRepository.maxBytes))
    }
    func updateBody(expected: JapaneseLearningNote, text: String, root: URL) throws -> JapaneseLearningNote {
        try Task.checkCancellation()
        guard text.utf16.count <= 16000 else { throw NoteBodyEditError.tooLong }
        var state = try load(root: root)
        guard let index = state.notes.firstIndex(where: { $0.id == expected.id }) else { throw NoteBodyEditError.conflict }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let current = state.notes[index]
        guard try encoder.encode(current) == encoder.encode(expected) else { throw NoteBodyEditError.conflict }
        guard !current.userText.utf8.elementsEqual(text.utf8) else { return current }
        let next = try JapaneseLearningNote(id: current.id, review: current.review, userText: text, corrections: current.corrections)
        state.notes[index] = next
        try commit(state, root: root); return next
    }
    private func commit(_ state: JapaneseLearningState, root: URL) throws {
        let path = root.appendingPathComponent(JapaneseLearningRepository.filename)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state); _ = try JapaneseLearningRepository.decode(data)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: path.path) {
            let previous = try BoundedFileReader.read(path, limit: JapaneseLearningRepository.maxBytes)
            _ = try JapaneseLearningRepository.decode(previous)
            try previous.write(to: path.appendingPathExtension("backup"), options: .atomic)
        }
        try Task.checkCancellation()
        try data.write(to: path, options: .atomic)
    }
    func save(_ note: JapaneseLearningNote, root: URL) throws {
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
