// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit
import PDFnoDomain

public struct DOCXState: Codable, Sendable {
    public var schemaVersion = 1
    public var books: [DOCXBook] = []
    public var notes: [DOCXNote] = []
    public init() {}
}
/// Isolated manifest: never migrates/rewrites PDF or EPUB records.
public actor DOCXRepository {
    public let root: URL
    public init(root: URL) { self.root = root }
    private var manifest: URL { root.appendingPathComponent("docx-v1.json") }
    private func asset(_ book: DOCXBook) -> URL {
        root.appendingPathComponent("Originals").appendingPathComponent(book.fileSHA256 + ".docx")
    }
    public static func boundedRead(_ url: URL, limit: Int = 20 * 1024 * 1024) throws -> Data {
        let info = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard info.isRegularFile == true, let size = info.fileSize, size <= limit else { throw DOCXError.resourceLimit }
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        let data = try handle.read(upToCount: limit + 1) ?? Data()
        guard data.count <= limit else { throw DOCXError.resourceLimit }; return data
    }
    public func load() throws -> DOCXState {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return DOCXState() }
        return try Self.decode(Self.boundedRead(manifest, limit: 10 * 1024 * 1024))
    }
    public static func decode(_ data: Data) throws -> DOCXState {
        guard data.count <= 10 * 1024 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: ["schemaVersion", "books", "notes"]),
              let books = object["books"] as? [[String: Any]], let notes = object["notes"] as? [[String: Any]] else { throw DOCXError.invalidStore }
        func anchorKeys(_ value: Any?) -> Bool {
            guard let a = value as? [String: Any] else { return false }
            return Set(a.keys).isSubset(of: ["schemaVersion", "extractionVersion", "editionID", "fileSHA256", "blockID", "start", "end", "quote", "prefix", "suffix"])
        }
        guard books.allSatisfy({
            Set($0.keys).isSubset(of: ["id", "editionID", "fileSHA256", "title", "originalFilename", "progress"]) &&
            ($0["progress"] == nil || anchorKeys($0["progress"]))
        }), notes.allSatisfy({
            Set($0.keys).isSubset(of: ["id", "bookID", "anchor", "userText"]) && anchorKeys($0["anchor"])
        }), let state = try? JSONDecoder().decode(DOCXState.self, from: data), state.schemaVersion == 1,
              state.books.count <= 10000, state.notes.count <= 10000,
              Set(state.books.map(\.id)).count == state.books.count,
              Set(state.books.map(\.editionID)).count == state.books.count,
              Set(state.books.map(\.fileSHA256)).count == state.books.count,
              Set(state.notes.map(\.id)).count == state.notes.count,
              state.books.allSatisfy({
                  DOCXBook.validHash($0.fileSHA256) && !$0.title.isEmpty && $0.title.utf8.count <= 4096 &&
                  $0.originalFilename.utf8.count <= 1024 && URL(fileURLWithPath: $0.originalFilename).lastPathComponent == $0.originalFilename &&
                  $0.originalFilename.lowercased().hasSuffix(".docx") && ($0.progress == nil || $0.accepts($0.progress!))
              }), state.notes.allSatisfy({ note in
                  note.userText.utf8.count <= 16000 && state.books.contains { $0.id == note.bookID && $0.accepts(note.anchor) }
              }) else { throw DOCXError.invalidStore }
        return state
    }
    private func commit(_ state: DOCXState) throws {
        let data = try JSONEncoder().encode(state); _ = try Self.decode(data)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: manifest.path) {
            let previous = try Self.boundedRead(manifest, limit: 10 * 1024 * 1024); _ = try Self.decode(previous)
            try previous.write(to: manifest.appendingPathExtension("backup"), options: .atomic)
        }
        try data.write(to: manifest, options: .atomic)
    }
    public func importFile(_ url: URL) throws -> DOCXBook {
        let ext = url.pathExtension.lowercased()
        guard ext != "doc" else { throw DOCXError.legacyDOC }
        guard ext == "docx" else { throw DOCXError.unsupportedContent }
        return try importBook(Self.boundedRead(url), filename: url.lastPathComponent)
    }
    public func importBook(_ data: Data, filename: String) throws -> DOCXBook {
        guard URL(fileURLWithPath: filename).pathExtension.lowercased() != "doc" else { throw DOCXError.legacyDOC }
        guard URL(fileURLWithPath: filename).pathExtension.lowercased() == "docx" else { throw DOCXError.unsupportedContent }
        _ = try DOCXParser.parse(data)
        var state = try load(); let hash = Self.hash(data)
        if let book = state.books.first(where: { $0.fileSHA256 == hash }) { _ = try read(book); return book }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let title = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
        let book = DOCXBook(fileSHA256: hash, title: title.isEmpty ? "DOCX" : title, originalFilename: name)
        state.books.append(book); _ = try Self.decode(JSONEncoder().encode(state))
        let url = asset(book)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            guard Self.hash(try Self.boundedRead(url)) == hash else { throw DOCXError.sourceMismatch }
        } else { try data.write(to: url, options: .atomic) }
        try commit(state); return book
    }
    public func read(_ book: DOCXBook) throws -> Data {
        guard DOCXBook.validHash(book.fileSHA256), (try load()).books.contains(where: {
            $0.id == book.id && $0.editionID == book.editionID && $0.fileSHA256 == book.fileSHA256
        }) else { throw DOCXError.sourceMismatch }
        let data = try Self.boundedRead(asset(book))
        guard Self.hash(data) == book.fileSHA256 else { throw DOCXError.sourceMismatch }
        return data
    }
    public func document(_ book: DOCXBook) throws -> DOCXDocument { try DOCXParser.parse(read(book)) }
    private func verify(_ anchor: DOCXAnchor, book: DOCXBook) throws {
        guard book.accepts(anchor), try document(book).resolves(anchor) else { throw DOCXError.sourceMismatch }
    }
    public func saveNote(_ note: DOCXNote) throws {
        var state = try load()
        guard note.userText.utf8.count <= 16000, !state.notes.contains(where: { $0.id == note.id }),
              let book = state.books.first(where: { $0.id == note.bookID }) else { throw DOCXError.sourceMismatch }
        try verify(note.anchor, book: book); state.notes.append(note); try commit(state)
    }
    public func saveProgress(_ anchor: DOCXAnchor, bookID: UUID) throws {
        var state = try load()
        guard let index = state.books.firstIndex(where: { $0.id == bookID }) else { throw DOCXError.sourceMismatch }
        try verify(anchor, book: state.books[index])
        guard state.books[index].progress != anchor else { return }
        state.books[index].progress = anchor; try commit(state)
    }
    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
