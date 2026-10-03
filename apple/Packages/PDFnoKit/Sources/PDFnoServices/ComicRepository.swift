// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit
import PDFnoDomain

public struct ComicState: Codable, Sendable {
    public var schemaVersion = 1
    public var books: [ComicBook] = []
    public init() {}
}
public actor ComicRepository {
    public let root: URL
    public init(root: URL) { self.root = root }
    private var manifest: URL { root.appendingPathComponent("comics-v1.json") }
    private func asset(_ book: ComicBook) -> URL { root.appendingPathComponent("Originals").appendingPathComponent(book.fileSHA256 + ".cbz") }
    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public func load() throws -> ComicState {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return ComicState() }
        return try Self.decode(BoundedFileReader.read(manifest, limit: 10 * 1024 * 1024))
    }
    public static func decode(_ data: Data) throws -> ComicState {
        guard data.count <= 10 * 1024 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["schemaVersion", "books"], let books = object["books"] as? [[String: Any]],
              books.allSatisfy({ b in
                  Set(b.keys).isSubset(of: ["id", "editionID", "fileSHA256", "title", "originalFilename", "pages", "progress"]) &&
                  (b["pages"] as? [[String: Any]])?.allSatisfy { Set($0.keys) == ["path", "width", "height"] } == true &&
                  (b["progress"] == nil || (b["progress"] as? [String: Any]).map {
                      Set($0.keys) == ["schemaVersion", "editionID", "fileSHA256", "pageIndex", "pagePath", "direction", "layout"]
                  } == true)
              }),
              let state = try? JSONDecoder().decode(ComicState.self, from: data), state.schemaVersion == 1,
              state.books.count <= 10000, Set(state.books.map(\.id)).count == state.books.count,
              Set(state.books.map(\.fileSHA256)).count == state.books.count,
              state.books.allSatisfy({ b in
                  b.fileSHA256.count == 64 && b.fileSHA256.allSatisfy { "0123456789abcdef".contains($0) } &&
                  !b.title.isEmpty && b.title.utf8.count <= 4096 && b.originalFilename.utf8.count <= 1024 &&
                  !b.pages.isEmpty && b.pages.count <= ComicLimits.entries && b.pages.allSatisfy(\.isValid) &&
                  b.pages.reduce(0, { $0 + $1.width * $1.height }) <= ComicLimits.totalImagePixels &&
                  Set(b.pages.map { $0.path.precomposedStringWithCanonicalMapping.lowercased() }).count == b.pages.count &&
                  b.pages.map(\.path) == b.pages.map(\.path).sorted(by: ComicPageOrder.precedes) &&
                  (b.progress == nil || b.accepts(b.progress!))
              }) else { throw ComicError.invalidStore }
        return state
    }
    private func commit(_ state: ComicState) throws {
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
    public func importBook(_ data: Data, filename: String) throws -> ComicBook {
        guard URL(fileURLWithPath: filename).pathExtension.lowercased() == "cbz" else { throw ComicError.unavailable }
        var state = try load()
        let archive = try CBZArchive(data: data), hash = Self.hash(data)
        if let existing = state.books.first(where: { $0.fileSHA256 == hash }) { return existing }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let book = ComicBook(fileSHA256: hash, title: URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent,
                             originalFilename: name, pages: archive.pages)
        var next = state; next.books.append(book)
        _ = try Self.decode(JSONEncoder().encode(next))
        let url = asset(book); try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic); state = next; try commit(state)
        return book
    }
    public func read(_ book: ComicBook) throws -> CBZArchive {
        guard (try load()).books.contains(where: { $0.id == book.id && $0.editionID == book.editionID && $0.fileSHA256 == book.fileSHA256 }) else { throw ComicError.sourceMismatch }
        let url = asset(book), info = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard info.isRegularFile == true, let size = info.fileSize, size <= ComicLimits.archiveBytes else { throw ComicError.resourceLimit }
        let data = try CBZArchive.readFile(url)
        guard Self.hash(data) == book.fileSHA256 else { throw ComicError.sourceMismatch }
        let archive = try CBZArchive(data: data)
        guard archive.pages == book.pages else { throw ComicError.sourceMismatch }; return archive
    }
    public func saveProgress(_ progress: ComicProgress, bookID: UUID) throws {
        var state = try load()
        guard let i = state.books.firstIndex(where: { $0.id == bookID && $0.accepts(progress) }) else { throw ComicError.sourceMismatch }
        guard state.books[i].progress != progress else { return }
        state.books[i].progress = progress; try commit(state)
    }
}
