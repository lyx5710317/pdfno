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
    private let file: SavedBodyDraftFile
    private let view = SavedBodyDraftView()
    private struct State: Codable { let schemaVersion: Int; let drafts: [SavedBodyDraft<Snapshot>] }
    public init(root: URL, filename: String? = nil) {
        url = root.appendingPathComponent(filename ?? Snapshot.draftFilename).standardizedFileURL.resolvingSymlinksInPath()
        file = SavedBodyDraftFile.shared(url)
    }
    public func load() throws -> [SavedBodyDraft<Snapshot>] {
        file.lock.lock(); defer { file.lock.unlock() }
        let drafts = try readCurrent(), images = try Self.images(drafts)
        file.observe(images)
        if !view.initialized {
            view.images = images; view.revisions = file.revisions; view.initialized = true
        }
        return drafts
    }
    private func readCurrent() throws -> [SavedBodyDraft<Snapshot>] {
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
    /// Compatibility batch checkpoint: apply only changes since this instance's
    /// initial load/save. Later observation does not resolve a stale version;
    /// use reloadBaseline for an explicit resolution. Foreign keys are retained.
    public func save(_ drafts: [SavedBodyDraft<Snapshot>]) throws {
        let storeWrite = try LocalStoreWriteGate.shared(root: url.deletingLastPathComponent()).beginWrite()
        defer { storeWrite.finish() }
        file.lock.lock(); defer { file.lock.unlock() }

        _ = try Self.bytes(drafts)
        let desired = try Self.images(drafts)
        let current = try readCurrent(), images = try Self.images(current)
        file.observe(images)
        let changed = Set(view.images.keys).union(desired.keys).filter { view.images[$0] != desired[$0] }
        for key in changed { try checkCurrent(key, images: images) }
        var merged = Dictionary(uniqueKeysWithValues: current.map { ($0.baseline.key, $0) })
        let requested = Dictionary(uniqueKeysWithValues: drafts.map { ($0.baseline.key, $0) })
        for key in changed { merged[key] = requested[key] }
        try commit(Array(merged.values), previousImages: images)
        // Keep the caller's view, not the merged foreign state: the next old
        // snapshot must not mistake externally updated rows for its own edits.
        view.images = desired
        for key in changed { view.revisions[key] = file.revisions[key] }
        view.initialized = true
    }
    /// One editor operation, including an explicit deletion, uses this owner's
    /// expected file revision. A stale cancel cannot remove a newer draft.
    public func checkpoint(_ draft: SavedBodyDraft<Snapshot>?, for key: String) throws {
        let storeWrite = try LocalStoreWriteGate.shared(root: url.deletingLastPathComponent()).beginWrite()
        defer { storeWrite.finish() }
        file.lock.lock(); defer { file.lock.unlock() }
        guard draft == nil || draft?.baseline.key == key else { throw NoteBodyEditError.draftStore }
        let current = try readCurrent(), images = try Self.images(current)
        file.observe(images); try checkCurrent(key, images: images)
        var merged = Dictionary(uniqueKeysWithValues: current.map { ($0.baseline.key, $0) })
        merged[key] = draft
        try commit(Array(merged.values), previousImages: images)
        view.images[key] = file.images[key]; view.revisions[key] = file.revisions[key]
        view.initialized = true
    }
    /// Explicit user conflict resolution reloads only this key's expected
    /// version. It neither writes text nor adopts other editors' snapshots.
    public func reloadBaseline(for key: String) throws {
        file.lock.lock(); defer { file.lock.unlock() }
        file.observe(try Self.images(readCurrent()))
        view.images[key] = file.images[key]; view.revisions[key] = file.revisions[key]
        view.initialized = true
    }
    private func checkCurrent(_ key: String, images: [String: Data]) throws {
        guard view.images[key] == images[key], view.revisions[key] == file.revisions[key] else {
            throw NoteBodyEditError.conflict
        }
    }
    private static func images(_ drafts: [SavedBodyDraft<Snapshot>]) throws -> [String: Data] {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try Dictionary(uniqueKeysWithValues: drafts.map { ($0.baseline.key, try encoder.encode($0)) })
    }
    private static func bytes(_ drafts: [SavedBodyDraft<Snapshot>]) throws -> Data {
        let data = try JSONEncoder().encode(State(schemaVersion: 1, drafts: drafts.sorted { $0.baseline.key < $1.baseline.key }))
        guard data.count <= 10 * 1024 * 1024 else { throw NoteBodyEditError.draftStore }
        _ = try Self.decode(data)
        return data
    }
    private func commit(_ drafts: [SavedBodyDraft<Snapshot>], previousImages: [String: Data]) throws {
        let data = try Self.bytes(drafts), images = try Self.images(drafts)
        guard images != previousImages else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        file.observe(images)
    }
}

/// Per-journal caller view; all access is under its shared file's lock. Struct
/// copies are the same owner, while separate initializers create separate views.
private final class SavedBodyDraftView: @unchecked Sendable {
    var initialized = false
    var images: [String: Data] = [:]
    var revisions: [String: UUID] = [:]
}

/// Same-process coordination, not cross-process isolation. Revisions stay out
/// of schema 1 and detect delete/recreate ABA while live owners still exist.
private final class SavedBodyDraftFile: @unchecked Sendable {
    private final class Registry: @unchecked Sendable {
        let lock = NSLock()
        var files: [String: SavedBodyDraftFile] = [:]
    }
    private static let registry = Registry()
    static func shared(_ url: URL) -> SavedBodyDraftFile {
        let path = url.standardizedFileURL.resolvingSymlinksInPath().path
        registry.lock.lock(); defer { registry.lock.unlock() }
        if let file = registry.files[path] { return file }
        let file = SavedBodyDraftFile(); registry.files[path] = file; return file
    }
    let lock = NSLock()
    private(set) var images: [String: Data] = [:]
    private(set) var revisions: [String: UUID] = [:]
    func observe(_ next: [String: Data]) {
        for key in Set(images.keys).union(next.keys) where images[key] != next[key] {
            revisions[key] = next[key] == nil ? nil : UUID()
        }
        images = next
    }
}
