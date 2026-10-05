// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit
import PDFnoDomain

public struct TextFormatState: Codable, Sendable {
    public var schemaVersion = 1
    public var books: [TextFormatBook] = []
    public var notes: [TextFormatNote] = []
    public init() {}
}
/// Isolated manifest: never migrates/rewrites PDF or EPUB records.
public actor TextFormatRepository {
    public let root: URL
    public init(root: URL) { self.root = root }
    private var manifest: URL { root.appendingPathComponent("text-formats-v1.json") }
    private var rendered: [UUID: TextFormatDocument] = [:]
    private func asset(_ book: TextFormatBook) -> URL {
        root.appendingPathComponent("Originals").appendingPathComponent(book.fileSHA256 + "." + book.format.rawValue)
    }
    public static func boundedRead(_ url: URL, limit: Int = 4 * 1024 * 1024) throws -> Data {
        do { return try BoundedFileReader.read(url, limit: limit) }
        catch is CancellationError { throw CancellationError() }
        catch { throw TextFormatError.resourceLimit }
    }
    public func load() throws -> TextFormatState {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return TextFormatState() }
        return try Self.decode(Self.boundedRead(manifest, limit: 10 * 1024 * 1024))
    }
    public static func decode(_ data: Data) throws -> TextFormatState {
        guard data.count <= 10 * 1024 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: ["schemaVersion", "books", "notes"]),
              let books = object["books"] as? [[String: Any]], let notes = object["notes"] as? [[String: Any]] else { throw TextFormatError.invalidStore }
        func anchorKeys(_ value: Any?) -> Bool {
            guard let a = value as? [String: Any] else { return false }
            return Set(a.keys).isSubset(of: ["schemaVersion", "extractionVersion", "editionID", "fileSHA256", "blockID", "start", "end", "quote", "prefix", "suffix"])
        }
        guard books.allSatisfy({
            Set($0.keys).isSubset(of: ["id", "editionID", "fileSHA256", "title", "originalFilename", "format", "progress"]) &&
            ($0["progress"] == nil || anchorKeys($0["progress"]))
        }), notes.allSatisfy({
            Set($0.keys).isSubset(of: ["id", "bookID", "anchor", "userText"]) && anchorKeys($0["anchor"])
        }), let state = try? JSONDecoder().decode(TextFormatState.self, from: data), state.schemaVersion == 1,
              state.books.count <= 10000, state.notes.count <= 10000,
              Set(state.books.map(\.id)).count == state.books.count,
              Set(state.books.map(\.editionID)).count == state.books.count,
              Set(state.books.map { $0.fileSHA256 + ":" + $0.format.rawValue }).count == state.books.count,
              Set(state.notes.map(\.id)).count == state.notes.count,
              state.books.allSatisfy({
                  TextFormatBook.validHash($0.fileSHA256) && !$0.title.isEmpty && $0.title.utf8.count <= 4096 &&
                  $0.originalFilename.utf8.count <= 1024 && URL(fileURLWithPath: $0.originalFilename).lastPathComponent == $0.originalFilename &&
                  TextFileFormat.from(filename: $0.originalFilename) == $0.format && ($0.progress == nil || $0.accepts($0.progress!))
              }), state.notes.allSatisfy({ note in
                  note.userText.utf8.count <= 16000 && state.books.contains { $0.id == note.bookID && $0.accepts(note.anchor) }
              }) else { throw TextFormatError.invalidStore }
        return state
    }
    private func commit(_ state: TextFormatState) throws {
        let data = try JSONEncoder().encode(state); _ = try Self.decode(data)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: manifest.path) {
            let previous = try Self.boundedRead(manifest, limit: 10 * 1024 * 1024); _ = try Self.decode(previous)
            try previous.write(to: manifest.appendingPathExtension("backup"), options: .atomic)
        }
        try data.write(to: manifest, options: .atomic)
    }
    public func importFile(_ url: URL) throws -> TextFormatBook {
        guard TextFileFormat.from(filename: url.lastPathComponent) != nil else { throw TextFormatError.unsupportedContent }
        return try importBook(Self.boundedRead(url), filename: url.lastPathComponent)
    }
    public func importBook(_ data: Data, filename: String) throws -> TextFormatBook {
        let storeWrite = try LocalStoreWriteGate.shared(root: root).beginWrite()
        defer { storeWrite.finish() }

        guard let format = TextFileFormat.from(filename: filename) else { throw TextFormatError.unsupportedContent }
        _ = try TextFileDecoder.decode(data, format: format)
        var state = try load(); let hash = Self.hash(data)
        if let book = state.books.first(where: { $0.fileSHA256 == hash && $0.format == format }) { _ = try read(book); return book }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let title = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
        let book = TextFormatBook(fileSHA256: hash, title: title.isEmpty ? "TextFormat" : title, originalFilename: name, format: format)
        state.books.append(book); _ = try Self.decode(JSONEncoder().encode(state))
        let url = asset(book)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            guard Self.hash(try Self.boundedRead(url)) == hash else { throw TextFormatError.sourceMismatch }
        } else { try data.write(to: url, options: .atomic) }
        try commit(state); return book
    }
    public func read(_ book: TextFormatBook) throws -> Data {
        guard TextFormatBook.validHash(book.fileSHA256), (try load()).books.contains(where: {
            $0.id == book.id && $0.editionID == book.editionID && $0.fileSHA256 == book.fileSHA256 && $0.format == book.format
        }) else { throw TextFormatError.sourceMismatch }
        let data = try Self.boundedRead(asset(book))
        guard Self.hash(data) == book.fileSHA256 else { throw TextFormatError.sourceMismatch }
        return data
    }
    /// The canonical document must come from the trusted, identity-checked Kookit text reader.
    /// Rendered offsets are separate from original file byte positions.
    public func bindRenderedDocument(_ document: TextFormatDocument, book: TextFormatBook) throws {
        _ = try read(book)
        guard document.isValid else { throw TextFormatError.sourceMismatch }
        rendered = [book.id: document]
    }
    public func document(_ book: TextFormatBook) throws -> TextFormatDocument {
        _ = try read(book)
        guard let document = rendered[book.id] else { throw TextFormatError.sourceMismatch }
        return document
    }
    private func verify(_ anchor: TextFormatAnchor, book: TextFormatBook) throws {
        guard book.accepts(anchor), try document(book).resolves(anchor) else { throw TextFormatError.sourceMismatch }
    }
    public func saveNote(_ note: TextFormatNote) throws {
        let storeWrite = try LocalStoreWriteGate.shared(root: root).beginWrite()
        defer { storeWrite.finish() }

        var state = try load()
        guard note.userText.utf8.count <= 16000, !state.notes.contains(where: { $0.id == note.id }),
              let book = state.books.first(where: { $0.id == note.bookID }) else { throw TextFormatError.sourceMismatch }
        try verify(note.anchor, book: book); state.notes.append(note); try commit(state)
    }
    /// Body-only compare-and-set against the saved snapshot. Reopening a reader is unnecessary.
    /// Never recreate or normalize a source anchor while editing a saved body.
    public func updateNoteBody(expected: TextFormatNote, text: String) throws -> TextFormatNote {
        let storeWrite = try LocalStoreWriteGate.shared(root: root).beginWrite()
        defer { storeWrite.finish() }

        try Task.checkCancellation()
        guard text.utf8.count <= 16000 else { throw NoteBodyEditError.tooLong }
        var state = try load()
        guard let index = state.notes.firstIndex(where: { $0.id == expected.id && $0.bookID == expected.bookID }) else { throw NoteBodyEditError.conflict }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let current = state.notes[index]
        guard try encoder.encode(current) == encoder.encode(expected) else { throw NoteBodyEditError.conflict }
        guard !current.userText.utf8.elementsEqual(text.utf8) else { return current }
        let next = TextFormatNote(id: current.id, bookID: current.bookID, anchor: current.anchor, userText: text)
        state.notes[index] = next
        try Task.checkCancellation(); try commit(state); return next
    }
    public func saveProgress(_ anchor: TextFormatAnchor, bookID: UUID) throws {
        let storeWrite = try LocalStoreWriteGate.shared(root: root).beginWrite()
        defer { storeWrite.finish() }

        var state = try load()
        guard let index = state.books.firstIndex(where: { $0.id == bookID }) else { throw TextFormatError.sourceMismatch }
        try verify(anchor, book: state.books[index])
        guard state.books[index].progress != anchor else { return }
        state.books[index].progress = anchor; try commit(state)
    }
    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
