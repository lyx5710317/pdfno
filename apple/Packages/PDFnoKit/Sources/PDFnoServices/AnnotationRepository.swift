// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public struct AnnotationState: Codable, Sendable {
    public var schemaVersion = 1
    public var notes: [AnchoredAnnotation] = []
    public init() {}
}
/// An additive sidecar. Loading an older library never rewrites its notes or AI files.
public actor AnnotationRepository {
    public static let filename = "annotations-v1.json"
    public let root: URL
    public init(root: URL) { self.root = root }
    public func load() throws -> AnnotationState {
        let file = root.appendingPathComponent(Self.filename)
        guard FileManager.default.fileExists(atPath: file.path) else { return AnnotationState() }
        return try Self.decode(BoundedFileReader.read(file, limit: 10 * 1024 * 1024))
    }
    public static func decode(_ bytes: Data) throws -> AnnotationState {
        guard bytes.count <= 10 * 1024 * 1024, JapaneseLearningJSON.hasUniqueKeysForStore(bytes),
              let object = try JSONSerialization.jsonObject(with: bytes) as? [String: Any],
              let number = object["schemaVersion"] as? NSNumber, String(cString: number.objCType) != "c", number.intValue == 1,
              let state = try? JSONDecoder().decode(AnnotationState.self, from: bytes), state.notes.count <= 10000,
              state.notes.allSatisfy({ $0.isValid && $0.revision > 0 }), Set(state.notes.map(\.id)).count == state.notes.count else { throw LibraryError.unreadableStore }
        func sameKeys(_ a: Any, _ b: Any) -> Bool {
            if let a = a as? [String: Any], let b = b as? [String: Any] { return Set(a.keys) == Set(b.keys) && a.allSatisfy { k,v in b[k].map { sameKeys(v,$0) } == true } }
            if let a = a as? [Any], let b = b as? [Any] { return a.count == b.count && zip(a,b).allSatisfy { sameKeys($0,$1) } }
            return !(a is [String: Any]) && !(b is [String: Any]) && !(a is [Any]) && !(b is [Any])
        }
        guard sameKeys(object, try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))) else { throw LibraryError.unreadableStore }
        return state
    }
    public func save(expected: AnchoredAnnotation, text: String) throws -> AnchoredAnnotation {
        let operation = try LocalStoreWriteGate.shared(root: root).beginWrite(); defer { operation.finish() }
        let lock = AnnotationTransactions.shared.lock(for: root); lock.lock(); defer { lock.unlock() }
        guard expected.isValid, text.utf16.count <= 16000 else { throw NoteBodyEditError.tooLong }
        var state = try load(), saved = expected
        if let index = state.notes.firstIndex(where: { $0.id == expected.id }) {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            guard try encoder.encode(state.notes[index]) == encoder.encode(expected) else { throw NoteBodyEditError.conflict }
            saved.userText = text; saved.revision += 1; saved.updatedAt = Date(); state.notes[index] = saved
        } else {
            guard expected.revision == 0, !state.notes.contains(where: { $0.bookID == expected.bookID && ($0.origin == .manual && expected.origin == .manual ? $0.anchor.isSameSource(as: expected.anchor) : $0.origin == expected.origin && $0.sourceRecordID == expected.sourceRecordID) }) else { throw NoteBodyEditError.conflict }
            saved.userText = text; saved.revision = 1; saved.updatedAt = Date(); state.notes.append(saved)
        }
        try commit(state); return saved
    }
    public func mark(bookID: UUID, anchor: AnnotationAnchor, kind: AnnotationKind) throws -> AnchoredAnnotation {
        let operation = try LocalStoreWriteGate.shared(root: root).beginWrite(); defer { operation.finish() }
        let lock = AnnotationTransactions.shared.lock(for: root); lock.lock(); defer { lock.unlock() }
        guard anchor.isValid else { throw LibraryError.sourceMismatch }
        var state = try load()
        if let index = state.notes.firstIndex(where: { $0.bookID == bookID && $0.origin == .manual && $0.anchor.isSameSource(as: anchor) }) {
            // Explicitly changing a mark type retains its ID, excerpt and comment.
            if kind != .note && state.notes[index].kind != kind {
                state.notes[index].kind = kind; state.notes[index].revision += 1; state.notes[index].updatedAt = Date(); try commit(state)
            }
            return state.notes[index]
        }
        var mark = AnchoredAnnotation(bookID: bookID, anchor: anchor, kind: kind); mark.revision = 1
        state.notes.append(mark); try commit(state); return mark
    }
    /// An immutable generated result and a separately editable comment, added only by user action.
    public func addAIResult(_ result: AIResult, comment: String, commitFence: EnglishLearningSourceCommitFence? = nil) throws -> AnchoredAnnotation {
        let operation = try LocalStoreWriteGate.shared(root: root).beginWrite(); defer { operation.finish() }
        let lock = AnnotationTransactions.shared.lock(for: root); lock.lock(); defer { lock.unlock() }
        let anchor: AnnotationAnchor
        switch result.source.anchor { case .pdf(let value): anchor = .pdf(value); case .epub(let value): anchor = .epub(value); default: throw LibraryError.sourceMismatch }
        var record=AnchoredAnnotation(bookID: result.source.bookID,anchor: anchor,kind: .note,userText: comment,origin: .explicitlySavedAI,sourceRecordID: result.requestID,aiResult: result)
        guard record.isValid else { throw LibraryError.sourceMismatch }
        var state=try load()
        if let existing=state.notes.first(where: { $0.origin == .explicitlySavedAI && $0.sourceRecordID == result.requestID }) {
            guard existing.aiResult == result && existing.bookID == record.bookID else { throw NoteBodyEditError.conflict }
            return existing
        }
        record.revision=1;state.notes.append(record)
        if let commitFence { try commitFence.withValidatedCommit(root: root,source: result.source) { try commit(state) } }
        else { try commit(state) }
        return record
    }
    private func commit(_ state: AnnotationState) throws {
        let file = root.appendingPathComponent(Self.filename); _ = try load()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys]; let bytes = try encoder.encode(state); _ = try Self.decode(bytes)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: file.path) { try BoundedFileReader.read(file, limit: 10 * 1024 * 1024).write(to: file.appendingPathExtension("backup"), options: .atomic) }
        try bytes.write(to: file, options: .atomic)
    }
}

private final class AnnotationTransactions: @unchecked Sendable {
    static let shared=AnnotationTransactions()
    private let registry=NSLock()
    private var locks: [URL:NSRecursiveLock]=[:]
    func lock(for root: URL) -> NSRecursiveLock {
        registry.lock();defer { registry.unlock() }
        let key=root.standardizedFileURL.resolvingSymlinksInPath()
        if let lock=locks[key] { return lock }
        let lock=NSRecursiveLock();locks[key]=lock;return lock
    }
}
