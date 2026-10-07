// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Explicit entry-point provenance; names and content alone never classify a book.
public struct BundledExampleIdentity: Codable, Hashable, Sendable {
    public let format: String
    public let bookID: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public init(format: String, bookID: UUID, editionID: UUID, fileSHA256: String) {
        self.format = format; self.bookID = bookID; self.editionID = editionID; self.fileSHA256 = fileSHA256
    }
    var valid: Bool {
        ["pdf", "epub", "docx", "fb2", "mobi", "azw", "azw3"].contains(format) && LibraryRepository.isDigest(fileSHA256)
    }
}
public struct BundledExampleRecord: Codable, Equatable, Sendable {
    public let book: BundledExampleIdentity
    public let resource: String
}
public struct BundledExampleState: Codable, Sendable {
    public var schemaVersion = 1
    public var records: [BundledExampleRecord] = []
    public init() {}
}
public struct LocalImportResult<Book: Sendable>: Sendable {
    public let book: Book
    public let created: Bool
}
// Shared across repository actors/windows; synchronous critical sections only.
final class LocalImportTransactions: @unchecked Sendable {
    static let shared = LocalImportTransactions()
    private let registry = NSLock()
    private var locks: [String: NSRecursiveLock] = [:]
    func lock(_ root: URL) -> NSRecursiveLock {
        let key = root.standardizedFileURL.resolvingSymlinksInPath().path
        registry.lock(); defer { registry.unlock() }
        if let lock = locks[key] { return lock }
        let lock = NSRecursiveLock(); locks[key] = lock; return lock
    }
}
public enum BundledExampleError: Error { case invalidStore, invalidIdentity }
public actor BundledExampleRepository {
    private let root: URL
    private var manifest: URL { root.appendingPathComponent("bundled-examples-v1.json") }
    public init(root: URL) { self.root = root }
    public func load() throws -> BundledExampleState {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return .init() }
        return try Self.decode(BoundedFileReader.read(manifest, limit: 1024 * 1024))
    }
    public static func decode(_ data: Data) throws -> BundledExampleState {
        guard data.count <= 1024 * 1024, JapaneseLearningJSON.hasUniqueKeysForStore(data),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["schemaVersion", "records"],
              let version = object["schemaVersion"] as? NSNumber,
              String(cString: version.objCType) != "c", version.intValue == 1,
              let rows = object["records"] as? [[String: Any]], rows.count <= 10000,
              rows.allSatisfy({ row in
                  Set(row.keys) == ["book", "resource"] &&
                  (row["book"] as? [String: Any]).map { Set($0.keys) == ["format", "bookID", "editionID", "fileSHA256"] } == true
              }), let state = try? JSONDecoder().decode(BundledExampleState.self, from: data),
              state.records.allSatisfy({ $0.book.valid && $0.resource == "study-sample." + $0.book.format }),
              Set(state.records.map(\.book.bookID)).count == state.records.count else { throw BundledExampleError.invalidStore }
        return state
    }
    /// A deduplicated personal book must keep its existing classification.
    public func registerNewImport(_ book: BundledExampleIdentity, resource: String,
                                  existingBookIDs: Set<UUID>, newImport: Bool, bundledSHA256: String) throws -> BundledExampleState {
        let write = try LocalStoreWriteGate.shared(root: root).beginWrite(); defer { write.finish() }
        let transaction = LocalImportTransactions.shared.lock(root)
        transaction.lock(); defer { transaction.unlock() }
        var state = try load()
        guard book.valid, book.fileSHA256 == bundledSHA256, resource == "study-sample." + book.format else { throw BundledExampleError.invalidIdentity }
        guard newImport, !existingBookIDs.contains(book.bookID) else { return state }
        if state.records.contains(where: { $0.book == book }) { return state }
        guard !state.records.contains(where: { $0.book.bookID == book.bookID }) else { throw BundledExampleError.invalidIdentity }
        state.records.append(.init(book: book, resource: resource))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let bytes = try encoder.encode(state); _ = try Self.decode(bytes)
        // Never replace a corrupt/future store, including after a suspended import.
        _ = try load()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: manifest.path) {
            let previous = try BoundedFileReader.read(manifest, limit: 1024 * 1024); _ = try Self.decode(previous)
            try previous.write(to: manifest.appendingPathExtension("backup"), options: .atomic)
        }
        try bytes.write(to: manifest, options: .atomic)
        return state
    }
}
