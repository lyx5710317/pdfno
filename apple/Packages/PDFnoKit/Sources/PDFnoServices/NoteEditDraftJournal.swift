// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public typealias NoteEditDraft = SavedBodyDraft<NoteBodySnapshot>
public typealias NoteEditDraftJournal = SavedBodyDraftJournal<NoteBodySnapshot>
public typealias RecordEditDraft = SavedBodyDraft<RecordBodySnapshot>

public struct SavedBodyDraft<Snapshot: SavedBodySnapshot>: Codable, Sendable {
    public let baseline: Snapshot
    public var text: String
    public init(baseline: Snapshot, text: String) { self.baseline = baseline; self.text = text }
}

/// Small synchronous checkpoints keep keystrokes ordered without delayed tasks
/// overwriting newer drafts. Only this companion file is affected; a malformed
/// or future journal is refused and never replaced. Saved-note schemas are v1.
public struct SavedBodyDraftJournal<Snapshot: SavedBodySnapshot>: Sendable {
    private let url: URL
    private struct State: Codable { let schemaVersion: Int; let drafts: [SavedBodyDraft<Snapshot>] }
    public init(root: URL, filename: String? = nil) { url = root.appendingPathComponent(filename ?? Snapshot.draftFilename) }
    public func load() throws -> [SavedBodyDraft<Snapshot>] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try Self.decode(BoundedFileReader.read(url, limit: 10 * 1024 * 1024))
    }
    private static func decode(_ bytes: Data) throws -> [SavedBodyDraft<Snapshot>] {
        guard let object = try? JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              Set(object.keys) == Set(["schemaVersion", "drafts"]), object["schemaVersion"] as? Int == 1,
              let rows = object["drafts"] as? [[String: Any]],
              rows.allSatisfy({ Set($0.keys) == Set(["baseline", "text"]) }),
              let state = try? JSONDecoder().decode(State.self, from: bytes), state.schemaVersion == 1,
              state.drafts.count <= 100,
              Set(state.drafts.map { $0.baseline.key }).count == state.drafts.count,
              state.drafts.allSatisfy({ $0.text.utf8.count <= 256_000 }) else { throw NoteBodyEditError.draftStore }
        // Reject unknown nested fields too, rather than decoding and dropping
        // data from a journal written by an incompatible implementation.
        func sameKeys(_ a: Any, _ b: Any) -> Bool {
            if let a = a as? [String: Any], let b = b as? [String: Any] {
                return Set(a.keys) == Set(b.keys) && a.allSatisfy { key, value in b[key].map { sameKeys(value, $0) } == true }
            }
            if let a = a as? [Any], let b = b as? [Any] {
                return a.count == b.count && zip(a, b).allSatisfy { sameKeys($0, $1) }
            }
            return !(a is [String: Any]) && !(b is [String: Any]) && !(a is [Any]) && !(b is [Any])
        }
        let roundTrip = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
        guard sameKeys(object, roundTrip) else { throw NoteBodyEditError.draftStore }
        return state.drafts
    }
    public func save(_ drafts: [SavedBodyDraft<Snapshot>]) throws {
        let storeWrite = try LocalStoreWriteGate.shared(root: url.deletingLastPathComponent()).beginWrite()
        defer { storeWrite.finish() }

        _ = try load()
        let data = try JSONEncoder().encode(State(schemaVersion: 1, drafts: drafts.sorted { $0.baseline.key < $1.baseline.key }))
        guard data.count <= 10 * 1024 * 1024 else { throw NoteBodyEditError.draftStore }
        _ = try Self.decode(data)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
