// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit
import PDFnoDomain

public struct EbookState: Codable, Sendable {
    public var schemaVersion = 1
    public var books: [EbookBook] = []
    public var notes: [EbookNote] = []
    public init() {}
}
/// Isolated manifest: never migrates/rewrites PDF or EPUB records.
public actor EbookRepository {
    public let root: URL
    public init(root: URL) { self.root = root }
    private var manifest: URL { root.appendingPathComponent("ebook-kookit-v1.json") }
    private var rendered: [UUID: EbookDocument] = [:]
    private func asset(_ book: EbookBook) -> URL {
        root.appendingPathComponent("Originals").appendingPathComponent(book.fileSHA256 + "." + book.format.rawValue)
    }
    public static func boundedRead(_ url: URL, limit: Int = 8 * 1024 * 1024) throws -> Data {
        do { return try BoundedFileReader.read(url, limit: limit) }
        catch is CancellationError { throw CancellationError() }
        catch { throw EbookError.resourceLimit }
    }
    public func load() throws -> EbookState {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return EbookState() }
        return try Self.decode(Self.boundedRead(manifest, limit: 10 * 1024 * 1024))
    }
    public static func decode(_ data: Data) throws -> EbookState {
        guard data.count <= 10 * 1024 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: ["schemaVersion", "books", "notes"]),
              let books = object["books"] as? [[String: Any]], let notes = object["notes"] as? [[String: Any]] else { throw EbookError.invalidStore }
        func anchorKeys(_ value: Any?) -> Bool {
            guard let a = value as? [String: Any] else { return false }
            return Set(a.keys).isSubset(of: ["schemaVersion", "extractionVersion", "editionID", "fileSHA256", "format", "contentKind", "section", "blockID", "start", "end", "quote", "prefix", "suffix"])
        }
        guard books.allSatisfy({
            Set($0.keys).isSubset(of: ["id", "editionID", "fileSHA256", "format", "contentKind", "title", "originalFilename", "progress"]) &&
            ($0["progress"] == nil || anchorKeys($0["progress"]))
        }), notes.allSatisfy({
            Set($0.keys).isSubset(of: ["id", "bookID", "anchor", "userText"]) && anchorKeys($0["anchor"])
        }), let state = try? JSONDecoder().decode(EbookState.self, from: data), state.schemaVersion == 1,
              state.books.count <= 10000, state.notes.count <= 10000,
              Set(state.books.map(\.id)).count == state.books.count,
              Set(state.books.map(\.editionID)).count == state.books.count,
              Set(state.books.map { $0.fileSHA256 + $0.format.rawValue }).count == state.books.count,
              Set(state.notes.map(\.id)).count == state.notes.count,
              state.books.allSatisfy({
                  $0.validFormat && EbookBook.validHash($0.fileSHA256) && !$0.title.isEmpty && $0.title.utf8.count <= 4096 &&
                  $0.originalFilename.utf8.count <= 1024 && URL(fileURLWithPath: $0.originalFilename).lastPathComponent == $0.originalFilename &&
                  URL(fileURLWithPath: $0.originalFilename).pathExtension.lowercased() == $0.format.rawValue && ($0.progress == nil || $0.accepts($0.progress!))
              }), state.notes.allSatisfy({ note in
                  note.userText.utf8.count <= 16000 && state.books.contains { $0.id == note.bookID && $0.accepts(note.anchor) }
              }) else { throw EbookError.invalidStore }
        return state
    }
    private func commit(_ state: EbookState) throws {
        let data = try JSONEncoder().encode(state); _ = try Self.decode(data)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: manifest.path) {
            let previous = try Self.boundedRead(manifest, limit: 10 * 1024 * 1024); _ = try Self.decode(previous)
            try previous.write(to: manifest.appendingPathExtension("backup"), options: .atomic)
        }
        try data.write(to: manifest, options: .atomic)
    }
    public func importFile(_ url: URL) throws -> EbookBook {
        return try importBook(Self.boundedRead(url), filename: url.lastPathComponent)
    }
    public func importBook(_ data: Data, filename: String, candidate: EbookBook? = nil) throws -> EbookBook {
        guard let format = EbookFormat(rawValue: URL(fileURLWithPath: filename).pathExtension.lowercased()) else { throw EbookError.unsupportedContent }
        let kind = try EbookPreflight.validate(data, format: format)
        var state = try load(); let hash = Self.hash(data)
        if let book = state.books.first(where: { $0.fileSHA256 == hash && $0.format == format }) { _ = try read(book); return book }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let title = URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent
        let book = candidate ?? EbookBook(fileSHA256: hash, format: format, contentKind: kind, title: title.isEmpty ? "Ebook" : title, originalFilename: name)
        guard book.fileSHA256 == hash, book.format == format, book.contentKind == kind, book.originalFilename == name else { throw EbookError.sourceMismatch }
        state.books.append(book); _ = try Self.decode(JSONEncoder().encode(state))
        let url = asset(book)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            guard Self.hash(try Self.boundedRead(url)) == hash else { throw EbookError.sourceMismatch }
        } else { try data.write(to: url, options: .atomic) }
        try commit(state); return book
    }
    public func read(_ book: EbookBook) throws -> Data {
        guard EbookBook.validHash(book.fileSHA256), (try load()).books.contains(where: {
            $0.id == book.id && $0.editionID == book.editionID && $0.fileSHA256 == book.fileSHA256 && $0.format == book.format && $0.contentKind == book.contentKind
        }) else { throw EbookError.sourceMismatch }
        let data = try Self.boundedRead(asset(book))
        guard Self.hash(data) == book.fileSHA256 else { throw EbookError.sourceMismatch }
        guard try EbookPreflight.validate(data, format: book.format) == book.contentKind else { throw EbookError.sourceMismatch }
        return data
    }
    /// The canonical document must come from the trusted, identity-checked Kookit reader.
    /// Never silently fall back to the narrower native candidate on reopening.
    public func bindRenderedDocument(_ document: EbookDocument, book: EbookBook) throws {
        _ = try read(book)
        guard document.isValid else { throw EbookError.sourceMismatch }
        rendered = [book.id: document]
    }
    public func document(_ book: EbookBook) throws -> EbookDocument {
        _ = try read(book)
        guard let document = rendered[book.id] else { throw EbookError.sourceMismatch }
        return document
    }
    private func verify(_ anchor: EbookAnchor, book: EbookBook) throws {
        guard book.accepts(anchor), try document(book).resolves(anchor) else { throw EbookError.sourceMismatch }
    }
    public func saveNote(_ note: EbookNote) throws {
        var state = try load()
        guard note.userText.utf8.count <= 16000, !state.notes.contains(where: { $0.id == note.id }),
              let book = state.books.first(where: { $0.id == note.bookID }) else { throw EbookError.sourceMismatch }
        try verify(note.anchor, book: book); state.notes.append(note); try commit(state)
    }
    public func saveProgress(_ anchor: EbookAnchor, bookID: UUID) throws {
        var state = try load()
        guard let index = state.books.firstIndex(where: { $0.id == bookID }) else { throw EbookError.sourceMismatch }
        try verify(anchor, book: state.books[index])
        guard state.books[index].progress != anchor else { return }
        state.books[index].progress = anchor; try commit(state)
    }
    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
