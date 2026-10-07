// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit
import PDFnoDomain

public struct EPUBState: Codable, Sendable {
    public var schemaVersion = 1
    public var books: [EPUBBook] = []
    public var notes: [EPUBNote] = []
    public init() {}
}
/// A separate versioned manifest preserves the existing PDF schema and originals.
public actor EPUBRepository {
    public let root: URL
    public init(root: URL) { self.root = root }
    private var manifest: URL { root.appendingPathComponent("epub-v1.json") }
    private func url(_ book: EPUBBook) -> URL { root.appendingPathComponent("Originals").appendingPathComponent(book.fileSHA256 + ".epub") }
    public func load() throws -> EPUBState {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return EPUBState() }
        return try Self.decode(BoundedFileReader.read(manifest, limit: 10 * 1024 * 1024))
    }
    public static func decode(_ data: Data) throws -> EPUBState {
        guard data.count <= 10 * 1024 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: ["schemaVersion", "books", "notes"]),
              let books = object["books"] as? [[String: Any]], let notes = object["notes"] as? [[String: Any]] else { throw EPUBError.invalidStore }
        func anchorKeys(_ anchor: [String: Any]) -> Bool {
            Set(anchor.keys).isSubset(of: ["schemaVersion", "extractionVersion", "editionID", "fileSHA256", "resourceHref", "spineIndex", "start", "end", "quote", "prefix", "suffix", "vertical"])
        }
        guard books.allSatisfy({ book in
            Set(book.keys).isSubset(of: ["id", "editionID", "fileSHA256", "title", "originalFilename", "progress"]) &&
            (book["progress"] == nil || (book["progress"] as? [String: Any]).map(anchorKeys) == true)
        }), notes.allSatisfy({ note in
            Set(note.keys).isSubset(of: ["id", "bookID", "anchor", "userText"]) && (note["anchor"] as? [String: Any]).map(anchorKeys) == true
        }),
              let state = try? JSONDecoder().decode(EPUBState.self, from: data), state.schemaVersion == 1,
              state.books.count <= 10000, state.notes.count <= 10000,
              Set(state.books.map(\.id)).count == state.books.count,
              Set(state.books.map(\.fileSHA256)).count == state.books.count,
              Set(state.notes.map(\.id)).count == state.notes.count,
              state.books.allSatisfy({ book in
                  book.fileSHA256.count == 64 && book.fileSHA256.allSatisfy { "0123456789abcdef".contains($0) } &&
                  book.title.utf8.count <= 4096 && book.originalFilename.utf8.count <= 1024 &&
                  (book.progress == nil || book.accepts(book.progress!))
              }), state.notes.allSatisfy({ note in
                  note.userText.utf8.count <= 16000 && state.books.contains { $0.id == note.bookID && $0.accepts(note.anchor) }
              }) else { throw EPUBError.invalidStore }
        return state
    }
    private func commit(_ state: EPUBState) throws {
        _ = try load()
        let bytes = try JSONEncoder().encode(state); _ = try Self.decode(bytes)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: manifest.path) {
            let previous = try BoundedFileReader.read(manifest, limit: 10 * 1024 * 1024)
            _ = try Self.decode(previous)
            try previous.write(to: manifest.appendingPathExtension("backup"), options: .atomic)
        }
        try bytes.write(to: manifest, options: .atomic)
    }
    public func importBook(_ data: Data, filename: String) throws -> EPUBBook {
        try importBookWithStatus(data, filename: filename).book
    }
    public func importBookWithStatus(_ data: Data, filename: String) throws -> LocalImportResult<EPUBBook> {
        let storeWrite = try LocalStoreWriteGate.shared(root: root).beginWrite()
        defer { storeWrite.finish() }
        let transaction = EPUBManifestTransactions.shared.lock(for: root)
        transaction.lock(); defer { transaction.unlock() }

        _ = try EPUBArchive.validate(data)
        var state = try load(); let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if let existing = state.books.first(where: { $0.fileSHA256 == hash }) { return .init(book: existing, created: false) }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let book = EPUBBook(fileSHA256: hash, title: URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent, originalFilename: name)
        let asset = url(book); try FileManager.default.createDirectory(at: asset.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: asset, options: .atomic); state.books.append(book); try commit(state); return .init(book: book, created: true)
    }
    public func read(_ book: EPUBBook) throws -> Data {
        guard (try load()).books.contains(where: { $0.id == book.id && $0.fileSHA256 == book.fileSHA256 }) else { throw EPUBError.sourceMismatch }
        let data = try BoundedFileReader.read(url(book), limit: 20 * 1024 * 1024)
        guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == book.fileSHA256 else { throw EPUBError.sourceMismatch }
        _ = try EPUBArchive.validate(data); return data
    }
    public func saveProgress(_ anchor: EPUBAnchor, bookID: UUID) throws {
        let storeWrite = try LocalStoreWriteGate.shared(root: root).beginWrite()
        defer { storeWrite.finish() }
        let transaction = EPUBManifestTransactions.shared.lock(for: root)
        transaction.lock(); defer { transaction.unlock() }

        var state = try load()
        guard let index = state.books.firstIndex(where: { $0.id == bookID && $0.accepts(anchor) }) else { throw EPUBError.sourceMismatch }
        guard state.books[index].progress != anchor else { return }
        state.books[index].progress = anchor; try commit(state)
    }
    /// Legacy EPUB notes have no revision field; the saved snapshot is the
    /// compare-and-set baseline, preserving compatibility with schema 1.
    public func updateNoteBody(expected: EPUBNote, text: String) throws -> EPUBNote {
        let storeWrite = try LocalStoreWriteGate.shared(root: root).beginWrite()
        defer { storeWrite.finish() }
        let transaction = EPUBManifestTransactions.shared.lock(for: root)
        transaction.lock(); defer { transaction.unlock() }

        guard NoteBodySnapshot.epub(expected).accepts(text) else { throw NoteBodyEditError.tooLong }
        var state = try load()
        guard let index = state.notes.firstIndex(where: { $0.id == expected.id && $0.bookID == expected.bookID }),
              state.notes[index] == expected,
              state.notes[index].userText.utf8.elementsEqual(expected.userText.utf8) else { throw NoteBodyEditError.conflict }
        let old = state.notes[index]
        guard !old.userText.utf8.elementsEqual(text.utf8) else { return old }
        let next = EPUBNote(id: old.id, bookID: old.bookID, anchor: old.anchor, userText: text)
        state.notes[index] = next; try commit(state); return next
    }
    public func saveNote(_ note: EPUBNote) throws {
        let storeWrite = try LocalStoreWriteGate.shared(root: root).beginWrite()
        defer { storeWrite.finish() }
        let transaction = EPUBManifestTransactions.shared.lock(for: root)
        transaction.lock(); defer { transaction.unlock() }

        var state = try load()
        guard note.userText.utf8.count <= 16000, !state.notes.contains(where: { $0.id == note.id }),
              state.books.contains(where: { $0.id == note.bookID && $0.accepts(note.anchor) }) else { throw EPUBError.sourceMismatch }
        state.notes.append(note); try commit(state)
    }
}

/// Same-process read/check/write transactions, separate from maintenance admission.
/// Every EPUB manifest mutation holds this synchronous lock through its commit.
private final class EPUBManifestTransactions: @unchecked Sendable {
    static let shared = EPUBManifestTransactions()
    private let registry = NSLock()
    private var locks: [String: NSRecursiveLock] = [:]
    func lock(for root: URL) -> NSRecursiveLock {
        let path = root.standardizedFileURL.resolvingSymlinksInPath().path
        registry.lock(); defer { registry.unlock() }
        if let lock = locks[path] { return lock }
        let lock = NSRecursiveLock(); locks[path] = lock; return lock
    }
}
