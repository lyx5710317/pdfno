// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit
import PDFnoDomain

public enum LibraryError: LocalizedError {
    case invalidDocument, fileTooLarge, unreadableStore, unsupportedSchema, revisionConflict, sourceMismatch
    public var errorDescription: String? {
        switch self {
        case .invalidDocument: "文件不是可读的 PDF，或没有页面。"
        case .fileTooLarge: "当前导入上限为 200 MiB，请选择较小文件。"
        case .unreadableStore: "书库数据无法验证。原文件已保留，请恢复备份；不会覆盖现有数据。"
        case .unsupportedSchema: "书库来自更新版本。请升级应用；当前数据不会被覆盖。"
        case .revisionConflict: "笔记已被修改，请重新载入后保存。"
        case .sourceMismatch: "原书或选区已经变化，需要重新定位。"
        }
    }
}

public struct LibraryState: Codable, Sendable {
    public var schemaVersion = 1
    public var books: [BookRecord] = []
    public var notes: [ReadingNote] = []
    public init() {}
}

public actor LibraryRepository {
    public let root: URL
    private let manager = FileManager.default
    public init(root: URL) { self.root = root }
    public static func defaultRoot() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PDFnoNative", isDirectory: true)
    }
    private var manifest: URL { root.appendingPathComponent("library-v1.json") }
    public func assetURL(for book: BookRecord) -> URL {
        root.appendingPathComponent("Originals", isDirectory: true).appendingPathComponent(book.fileSHA256 + ".pdf")
    }
    public func load() throws -> LibraryState {
        guard manager.fileExists(atPath: manifest.path) else { return LibraryState() }
        let data = try Data(contentsOf: manifest)
        return try Self.decode(data)
    }
    public static func decode(_ data: Data) throws -> LibraryState {
        guard data.count <= 10 * 1024 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys).isSubset(of: ["schemaVersion", "books", "notes"]),
              let version = object["schemaVersion"] as? Int else { throw LibraryError.unreadableStore }
        guard version == 1 else { throw LibraryError.unsupportedSchema }
        func keys(_ object: [String: Any], _ allowed: Set<String>) -> Bool { Set(object.keys).isSubset(of: allowed) }
        guard let books = object["books"] as? [[String: Any]], let notes = object["notes"] as? [[String: Any]],
              books.allSatisfy({ keys($0, ["id", "editionID", "title", "fileSHA256", "originalFilename", "pageCount", "importedAt", "lastPageIndex"]) }),
              notes.allSatisfy({ note in
                  guard keys(note, ["id", "bookID", "anchor", "userText", "revision", "createdAt", "updatedAt"]),
                        let anchor = note["anchor"] as? [String: Any],
                        keys(anchor, ["schemaVersion", "editionID", "fileSHA256", "quote", "regions", "extractionVersion"]),
                        let regions = anchor["regions"] as? [[String: Any]] else { return false }
                  return regions.allSatisfy { keys($0, ["pageIndex", "x", "y", "width", "height", "quote"]) }
              }) else { throw LibraryError.unreadableStore }
        guard let state = try? JSONDecoder().decode(LibraryState.self, from: data),
              Set(state.books.map(\.id)).count == state.books.count,
              Set(state.books.map(\.fileSHA256)).count == state.books.count,
              Set(state.notes.map(\.id)).count == state.notes.count,
              state.books.allSatisfy({ isDigest($0.fileSHA256) && $0.pageCount > 0 && $0.lastPageIndex >= 0 && $0.lastPageIndex < $0.pageCount }),
              state.notes.allSatisfy({ note in
                  state.books.contains { $0.id == note.bookID && valid(note, for: $0) }
              }) else { throw LibraryError.unreadableStore }
        return state
    }
    public static func isDigest(_ value: String) -> Bool {
        value.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    public static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    private static func valid(_ note: ReadingNote, for book: BookRecord) -> Bool {
        note.revision > 0 && note.userText.count <= 50_000 && note.anchor.schemaVersion == 1 &&
        note.anchor.editionID == book.editionID && note.anchor.fileSHA256 == book.fileSHA256 &&
        !note.anchor.quote.isEmpty && note.anchor.quote.count <= 50_000 && !note.anchor.regions.isEmpty &&
        note.anchor.regions.count <= 5_000 && note.anchor.regions.allSatisfy {
            (0..<book.pageCount).contains($0.pageIndex) && !$0.quote.isEmpty &&
            [$0.x, $0.y, $0.width, $0.height].allSatisfy(\.isFinite) && $0.width > 0 && $0.height > 0
        }
    }
    private func commit(_ state: LibraryState) throws {
        // Refuse corrupt/future-version overwrite even if the caller cached earlier state.
        _ = try load()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(state)
        _ = try Self.decode(bytes)
        try manager.createDirectory(at: root, withIntermediateDirectories: true)
        if manager.fileExists(atPath: manifest.path) {
            try Data(contentsOf: manifest).write(to: manifest.appendingPathExtension("backup"), options: .atomic)
        }
        try bytes.write(to: manifest, options: .atomic)
    }
    public func importPDF(_ data: Data, filename: String, pageCount: Int) throws -> BookRecord {
        guard data.count <= 200 * 1024 * 1024 else { throw LibraryError.fileTooLarge }
        guard data.starts(with: Data("%PDF-".utf8)), pageCount > 0 else { throw LibraryError.invalidDocument }
        var state = try load()
        let hash = Self.digest(data)
        if let existing = state.books.first(where: { $0.fileSHA256 == hash }) { return existing }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let book = BookRecord(title: URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent,
                              fileSHA256: hash, originalFilename: name, pageCount: pageCount)
        let url = assetURL(for: book)
        try manager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        state.books.append(book)
        try commit(state)
        return book
    }
    public func readAsset(for book: BookRecord) throws -> Data {
        guard Self.isDigest(book.fileSHA256) else { throw LibraryError.sourceMismatch }
        let data = try Data(contentsOf: assetURL(for: book))
        guard Self.digest(data) == book.fileSHA256 else { throw LibraryError.sourceMismatch }
        return data
    }
    public func saveProgress(bookID: UUID, pageIndex: Int) throws {
        var state = try load()
        guard let index = state.books.firstIndex(where: { $0.id == bookID }),
              (0..<state.books[index].pageCount).contains(pageIndex) else { throw LibraryError.sourceMismatch }
        guard state.books[index].lastPageIndex != pageIndex else { return }
        state.books[index].lastPageIndex = pageIndex
        try commit(state)
    }
    public func saveNote(_ note: ReadingNote) throws {
        var state = try load()
        guard let book = state.books.first(where: { $0.id == note.bookID }), Self.valid(note, for: book) else {
            throw LibraryError.sourceMismatch
        }
        if let index = state.notes.firstIndex(where: { $0.id == note.id }) {
            guard note.revision == state.notes[index].revision + 1, note.anchor == state.notes[index].anchor else {
                throw LibraryError.revisionConflict
            }
            state.notes[index] = note
        } else {
            guard note.revision == 1 else { throw LibraryError.revisionConflict }
            state.notes.append(note)
        }
        try commit(state)
    }
}
