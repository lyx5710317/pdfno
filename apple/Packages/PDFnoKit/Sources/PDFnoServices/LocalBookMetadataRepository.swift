// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public struct LocalBookMetadataState: Codable, Sendable {
    public var schemaVersion = 1
    public var records: [LocalBookMetadata] = []
    public init() {}
}
/// New optional sidecar: old manifests and originals are never migrated or rewritten.
public actor LocalBookMetadataRepository {
    private let root: URL
    private var manifest: URL { root.appendingPathComponent("book-metadata-v1.json") }
    public init(root: URL) { self.root = root }
    public func load() throws -> LocalBookMetadataState {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return LocalBookMetadataState() }
        return try Self.decode(BoundedFileReader.read(manifest, limit: 10 * 1024 * 1024))
    }
    public static func decode(_ data: Data) throws -> LocalBookMetadataState {
        guard data.count <= 10 * 1024 * 1024,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["schemaVersion", "records"], object["schemaVersion"] as? Int == 1,
              let records = object["records"] as? [[String: Any]], records.allSatisfy({ record in
                  Set(record.keys) == ["book", "title", "author", "revision"] &&
                  (record["book"] as? [String: Any]).map { Set($0.keys) == ["format", "bookID", "editionID", "fileSHA256"] } == true
              }), let state = try? JSONDecoder().decode(LocalBookMetadataState.self, from: data),
              state.records.count <= 10000, state.records.allSatisfy(\.isValid),
              Set(state.records.map(\.id)).count == state.records.count else { throw LibrarySearchFailure.store }
        return state
    }
    public func save(book: LocalBookIdentity, title: String, author: String, expectedRevision: Int) throws {
        var state = try load()
        let index = state.records.firstIndex { $0.id == book.id }
        guard expectedRevision >= 0, expectedRevision < Int.max - 1,
              (index.map { state.records[$0].revision } ?? 0) == expectedRevision,
              index.map({ state.records[$0].book == book }) ?? true else { throw LibrarySearchFailure.metadataConflict }
        let next = LocalBookMetadata(book: book, title: title, author: author, revision: expectedRevision + 1)
        guard next.isValid else { throw LibrarySearchFailure.store }
        if let index { state.records[index] = next } else { state.records.append(next) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let bytes = try encoder.encode(state); _ = try Self.decode(bytes)
        // Preserve corrupt/future files and last valid backup, even after a cached edit.
        _ = try load()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: manifest.path) {
            let previous = try BoundedFileReader.read(manifest, limit: 10 * 1024 * 1024); _ = try Self.decode(previous)
            try previous.write(to: manifest.appendingPathExtension("backup"), options: .atomic)
        }
        try bytes.write(to: manifest, options: .atomic)
    }
}
