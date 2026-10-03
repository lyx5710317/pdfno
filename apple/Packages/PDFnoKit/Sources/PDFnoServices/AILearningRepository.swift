// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public struct AILearningState: Codable, Sendable {
    public var schemaVersion = 1
    public var config = AIProviderConfig()
    public var notes: [AILearningNote] = []
    public init() {}
}
public actor AILearningRepository {
    private let root: URL
    private var manifest: URL { root.appendingPathComponent("learning-v1.json") }
    public init(root: URL) { self.root = root }
    public func load() throws -> AILearningState {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return AILearningState() }
        return try Self.decode(Data(contentsOf: manifest))
    }
    public static func decode(_ data: Data) throws -> AILearningState {
        guard data.count <= 5 * 1024 * 1024, let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == Set(["schemaVersion", "config", "notes"]), object["schemaVersion"] as? Int == 1 else { throw AIFailure.store }
        func configValid(_ value: Any?) -> Bool {
            guard let value = value as? [String: Any] else { return false }
            return Set(value.keys) == Set(["id", "generation", "mode", "label", "endpoint", "model"])
        }
        guard configValid(object["config"]), let notes = object["notes"] as? [[String: Any]], notes.allSatisfy({ note in
            guard Set(note.keys) == Set(["id", "result", "userText"]), let result = note["result"] as? [String: Any],
                  Set(result.keys) == Set(["requestID", "source", "provider", "kind", "text", "promptVersion", "fromCache"]),
                  configValid(result["provider"]), let source = result["source"] as? [String: Any],
                  Set(source.keys) == Set(["bookID", "readerSessionID", "documentVersion", "anchor"]),
                  let anchor = source["anchor"] as? [String: Any], anchor.count == 1,
                  let type = anchor.keys.first, ["pdf", "epub"].contains(type), let payload = anchor[type] as? [String: Any],
                  Set(payload.keys) == Set(["_0"]), let value = payload["_0"] as? [String: Any] else { return false }
            if type == "epub" { return Set(value.keys) == Set(["schemaVersion", "extractionVersion", "editionID", "fileSHA256", "resourceHref", "spineIndex", "start", "end", "quote", "prefix", "suffix", "vertical"]) }
            guard Set(value.keys) == Set(["schemaVersion", "editionID", "fileSHA256", "quote", "regions", "extractionVersion"]), let regions = value["regions"] as? [[String: Any]] else { return false }
            return regions.allSatisfy { Set($0.keys) == Set(["pageIndex", "x", "y", "width", "height", "quote"]) }
        }), let state = try? JSONDecoder().decode(AILearningState.self, from: data), state.config.isValid,
              state.notes.count <= 1000, Set(state.notes.map(\.id)).count == state.notes.count,
              Set(state.notes.map { $0.result.requestID }).count == state.notes.count,
              state.notes.allSatisfy({ valid($0) }) else { throw AIFailure.store }
        return state
    }
    private static func valid(_ note: AILearningNote) -> Bool {
        note.result.source.isValid && note.result.provider.isValid && note.result.provider.mode != .unconfigured &&
        ["selection-1", DeepSeekSelectionPolicy.promptVersion].contains(note.result.promptVersion) && !note.result.text.isEmpty && note.result.text.utf16.count <= 16000 && note.userText.utf16.count <= 16000
    }
    private func commit(_ state: AILearningState) throws {
        _ = try load()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state); _ = try Self.decode(data)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: manifest.path) { try Data(contentsOf: manifest).write(to: manifest.appendingPathExtension("backup"), options: .atomic) }
        try data.write(to: manifest, options: .atomic)
    }
    public func saveConfig(_ config: AIProviderConfig) throws -> AIProviderConfig {
        guard config.isValid else { throw AIFailure.configuration }
        var state = try load(), next = config
        next.id = state.config.id; next.generation = state.config.generation + 1
        state.config = next; try commit(state); return next
    }
    public func saveNote(_ note: AILearningNote) throws {
        guard Self.valid(note) else { throw AIFailure.output }
        var state = try load()
        guard !state.notes.contains(where: { $0.id == note.id || $0.result.requestID == note.result.requestID }) else { throw AIFailure.stale }
        state.notes.append(note); try commit(state)
    }
}
