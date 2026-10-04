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
    private func manifest(_ format: ComicArchiveFormat) -> URL {
        root.appendingPathComponent(format == .cbz ? "comics-v1.json" : "comics-" + format.rawValue + "-v1.json")
    }
    private func asset(_ book: ComicBook) -> URL { root.appendingPathComponent("Originals").appendingPathComponent(book.fileSHA256 + "." + (book.archiveFormat?.rawValue ?? "invalid")) }
    private static func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public func load() throws -> ComicState {
        var state = ComicState()
        for format in ComicArchiveFormat.allCases { state.books += try load(format).books }
        guard Set(state.books.map(\.id)).count == state.books.count,
              Set(state.books.map(\.fileSHA256)).count == state.books.count else { throw ComicError.invalidStore }
        return state
    }
    private func load(_ format: ComicArchiveFormat) throws -> ComicState {
        let url = manifest(format)
        guard FileManager.default.fileExists(atPath: url.path) else { return ComicState() }
        return try Self.decode(BoundedFileReader.read(url, limit: 10 * 1024 * 1024), format: format)
    }
    public static func decode(_ data: Data, format: ComicArchiveFormat = .cbz) throws -> ComicState {
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
                  b.archiveFormat == format && b.fileSHA256.count == 64 && b.fileSHA256.allSatisfy { "0123456789abcdef".contains($0) } &&
                  !b.title.isEmpty && b.title.utf8.count <= 4096 && b.originalFilename.utf8.count <= 1024 &&
                  !b.pages.isEmpty && b.pages.count <= ComicLimits.entries && b.pages.allSatisfy(\.isValid) &&
                  b.pages.reduce(0, { $0 + $1.width * $1.height }) <= ComicLimits.totalImagePixels &&
                  Set(b.pages.map { $0.path.precomposedStringWithCanonicalMapping.lowercased() }).count == b.pages.count &&
                  b.pages.map(\.path) == b.pages.map(\.path).sorted(by: ComicPageOrder.precedes) &&
                  (b.progress == nil || b.accepts(b.progress!))
              }) else { throw ComicError.invalidStore }
        return state
    }
    private func commit(_ state: ComicState, format: ComicArchiveFormat) throws {
        _ = try load()
        let manifest = manifest(format)
        let bytes = try JSONEncoder().encode(state); _ = try Self.decode(bytes, format: format)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: manifest.path) {
            let previous = try BoundedFileReader.read(manifest, limit: 10 * 1024 * 1024)
            _ = try Self.decode(previous, format: format)
            try previous.write(to: manifest.appendingPathExtension("backup"), options: .atomic)
        }
        try bytes.write(to: manifest, options: .atomic)
    }
    public func importBook(_ data: Data, filename: String) throws -> ComicBook {
        guard let format = ComicArchiveFormat(rawValue: URL(fileURLWithPath: filename).pathExtension.lowercased()) else { throw ComicError.unavailable }
        let combined = try load()
        var state = try load(format)
        let archive = try ComicArchive(data: data, format: format), hash = Self.hash(data)
        if let existing = combined.books.first(where: { $0.fileSHA256 == hash }) { return existing }
        let name = URL(fileURLWithPath: filename).lastPathComponent
        let book = ComicBook(fileSHA256: hash, title: URL(fileURLWithPath: name).deletingPathExtension().lastPathComponent,
                             originalFilename: name, pages: archive.pages)
        var next = state; next.books.append(book)
        _ = try Self.decode(JSONEncoder().encode(next), format: format)
        let url = asset(book); try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: url.path) {
            let info = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard info.isRegularFile == true, info.isSymbolicLink != true,
                  try BoundedFileReader.read(url, limit: ComicLimits.archiveBytes) == data else { throw ComicError.sourceMismatch }
        } else { try data.write(to: url, options: .withoutOverwriting) }
        state = next; try commit(state, format: format)
        return book
    }
    public func read(_ book: ComicBook) throws -> ComicArchive {
        guard let format = book.archiveFormat else { throw ComicError.sourceMismatch }
        guard (try load()).books.contains(where: { $0.id == book.id && $0.editionID == book.editionID && $0.fileSHA256 == book.fileSHA256 }) else { throw ComicError.sourceMismatch }
        let url = asset(book), info = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard info.isRegularFile == true, let size = info.fileSize, size <= ComicLimits.archiveBytes else { throw ComicError.resourceLimit }
        let data = try CBZArchive.readFile(url)
        guard Self.hash(data) == book.fileSHA256 else { throw ComicError.sourceMismatch }
        let archive = try ComicArchive(data: data, format: format)
        guard archive.pages == book.pages else { throw ComicError.sourceMismatch }; return archive
    }
    public func saveProgress(_ progress: ComicProgress, bookID: UUID) throws {
        let combined = try load()
        guard let book = combined.books.first(where: { $0.id == bookID && $0.accepts(progress) }),
              let format = book.archiveFormat else { throw ComicError.sourceMismatch }
        var state = try load(format)
        guard let i = state.books.firstIndex(where: { $0.id == bookID && $0.accepts(progress) }) else { throw ComicError.sourceMismatch }
        guard state.books[i].progress != progress else { return }
        state.books[i].progress = progress; try commit(state, format: format)
    }
}
