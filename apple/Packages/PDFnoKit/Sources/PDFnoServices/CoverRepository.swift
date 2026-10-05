// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CoreFoundation
import PDFnoDomain

public struct CoverThumbnail: Sendable {
    public let record: CoverRecord
    public let png: Data?
}
public struct CoverStoredSnapshot: Sendable {
    public let record: CoverRecord
    public let png: Data?
}
private struct CoverState: Codable {
    var schemaVersion = 1
    var records: [CoverRecord] = []
}
/// Serial background work bounds concurrent raster allocations. No framework object leaves the actor.
/// Cover state is independent of PDF/EPUB/CBZ/DOCX note manifests and never writes Originals.
public actor CoverRepository {
    public static let extractorVersion = "local-cover-1"
    private let root: URL
    private var memory: [String: (CoverThumbnail, Int)] = [:]
    private var recent: [String] = []
    public init(root: URL) { self.root = root }
    private var folder: URL { root.appendingPathComponent("Covers", isDirectory: true) }
    private var assets: URL { folder.appendingPathComponent("Assets", isDirectory: true) }
    private var cache: URL { folder.appendingPathComponent("Thumbnails", isDirectory: true) }
    private var manifest: URL { root.appendingPathComponent("covers-v1.json") }
    private func asset(_ hash: String) -> URL { assets.appendingPathComponent(hash + ".png") }
    private static func valid(_ r: CoverRecord) -> Bool {
        guard LibraryRepository.isDigest(r.identity.fileSHA256), r.revision > 0, r.revision < Int.max,
              !r.extractorVersion.isEmpty, r.extractorVersion.utf8.count <= 128,
              r.updatedAt.timeIntervalSince1970.isFinite else { return false }
        switch r.origin {
        case .placeholder: guard r.imageSHA256 == nil, r.mimeType == nil, r.byteLength == 0, r.width == 0, r.height == 0, r.resourcePath == nil else { return false }
        case .userImage: guard r.resourcePath == nil else { return false }
        case .pdfFirstPage: guard r.identity.format == .pdf, r.resourcePath == nil else { return false }
        case .epubEmbedded: guard r.identity.format == .epub, r.resourcePath.map(EPUBArchive.isSafePath) == true else { return false }
        case .cb7FirstImage: guard r.identity.format == .cb7, r.resourcePath.map(EPUBArchive.isSafePath) == true else { return false }
        case .cbrFirstImage: guard r.identity.format == .cbr, r.resourcePath.map(EPUBArchive.isSafePath) == true else { return false }
        case .cbtFirstImage: guard r.identity.format == .cbt, r.resourcePath.map(EPUBArchive.isSafePath) == true else { return false }
        case .cbzFirstImage: guard r.identity.format == .cbz, r.resourcePath.map(EPUBArchive.isSafePath) == true else { return false }
        }
        if r.origin != .placeholder {
            guard r.imageSHA256.map(LibraryRepository.isDigest) == true, r.mimeType == "image/png",
                  r.byteLength > 0, r.byteLength <= CoverLimits.inputBytes, r.width > 0, r.height > 0,
                  max(r.width, r.height) <= CoverLimits.assetDimension else { return false }
        }
        return true
    }
    private func load() throws -> CoverState {
        guard FileManager.default.fileExists(atPath: manifest.path) else { return CoverState() }
        return try Self.decode(BoundedFileReader.read(manifest, limit: 10 * 1024 * 1024))
    }
    private static func decode(_ data: Data) throws -> CoverState {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(object.keys) == ["schemaVersion", "records"],
              let version = object["schemaVersion"] as? Int,
              CFGetTypeID(object["schemaVersion"] as CFTypeRef) != CFBooleanGetTypeID() else { throw CoverError.invalidStore }
        guard version == 1 else { throw CoverError.unsupportedSchema }
        guard let records = object["records"] as? [[String: Any]], records.allSatisfy({ r in
            Set(r.keys).isSubset(of: ["identity", "origin", "resourcePath", "imageSHA256", "mimeType", "byteLength", "width", "height", "revision", "updatedAt", "extractorVersion"]) &&
            (r["identity"] as? [String: Any]).map { Set($0.keys) == ["bookID", "editionID", "fileSHA256", "format"] } == true
        }), let state = try? JSONDecoder().decode(CoverState.self, from: data), state.records.count <= 10000,
              Set(state.records.map { $0.identity.bookID }).count == state.records.count,
              state.records.allSatisfy(valid) else { throw CoverError.invalidStore }
        return state
    }
    public func record(for identity: CoverIdentity) throws -> CoverRecord? {
        try load().records.first { $0.identity == identity }
    }
    /// Existing original cover asset only: no generation, rebinding, cache or disk writes.
    public func readOnlySnapshot(for identity: CoverIdentity) throws -> CoverStoredSnapshot? {
        try Task.checkCancellation()
        guard let record = try record(for: identity) else { return nil }
        guard let hash = record.imageSHA256 else { return CoverStoredSnapshot(record: record, png: nil) }
        let bytes = try BoundedFileReader.read(asset(hash), limit: CoverLimits.inputBytes)
        guard LibraryRepository.digest(bytes) == hash, bytes.count == record.byteLength else { throw CoverError.invalidImage }
        return CoverStoredSnapshot(record: record, png: bytes)
    }
    private func save(_ record: CoverRecord, raster: CoverRaster?) throws {
        var state = try load()
        guard Self.valid(record) else { throw CoverError.invalidStore }
        if let index = state.records.firstIndex(where: { $0.identity.bookID == record.identity.bookID }) { state.records[index] = record }
        else { state.records.append(record) }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        let bytes = try encoder.encode(state); _ = try Self.decode(bytes)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        if let raster, let hash = record.imageSHA256 {
            try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
            try raster.png.write(to: asset(hash), options: .atomic)
        }
        if FileManager.default.fileExists(atPath: manifest.path) {
            let prior = try BoundedFileReader.read(manifest, limit: 10 * 1024 * 1024); _ = try Self.decode(prior)
            try prior.write(to: manifest.appendingPathExtension("backup"), options: .atomic)
        }
        try bytes.write(to: manifest, options: .atomic)
        let stale = memory.filter { $0.value.0.record.identity.bookID == record.identity.bookID }.map(\.key)
        for key in stale { memory.removeValue(forKey: key); recent.removeAll { $0 == key } }
        // Only unreferenced files owned by this module are discarded; current and backup assets remain recoverable.
        var retained = Set(state.records.compactMap(\.imageSHA256))
        if let previous = try? BoundedFileReader.read(manifest.appendingPathExtension("backup"), limit: 10 * 1024 * 1024), let prior = try? Self.decode(previous) {
            retained.formUnion(prior.records.compactMap(\.imageSHA256))
        }
        for url in (try? FileManager.default.contentsOfDirectory(at: assets, includingPropertiesForKeys: nil)) ?? [] {
            let hash = url.deletingPathExtension().lastPathComponent
            if url.pathExtension == "png", LibraryRepository.isDigest(hash), !retained.contains(hash) { try? FileManager.default.removeItem(at: url) }
        }
    }
    private func original(_ identity: CoverIdentity) throws -> Data {
        guard LibraryRepository.isDigest(identity.fileSHA256) else { throw CoverError.sourceMismatch }
        let limit: Int
        switch identity.format { case .pdf: limit = 200 * 1024 * 1024; case .cbz, .cbt, .cb7, .cbr: limit = ComicLimits.archiveBytes; case .epub, .docx: limit = 20 * 1024 * 1024 }
        let url = root.appendingPathComponent("Originals").appendingPathComponent(identity.fileSHA256 + "." + identity.format.rawValue)
        let data = try BoundedFileReader.read(url, limit: limit)
        guard LibraryRepository.digest(data) == identity.fileSHA256 else { throw CoverError.sourceMismatch }; return data
    }
    private func generate(_ identity: CoverIdentity, revision: Int) throws -> (CoverRecord, CoverRaster?) {
        let data = try original(identity)
        let origin: CoverOrigin, path: String?, raster: CoverRaster?
        switch identity.format {
        case .pdf: origin = .pdfFirstPage; path = nil; raster = try CoverRaster.pdf(data)
        case .epub:
            // No declared/supported cover is a stable placeholder. Source-read/hash failures above still propagate.
            if let result = try? EPUBCoverExtractor.extract(data), let image = try? CoverRaster.image(result.0, maximum: CoverLimits.thumbnailDimension) {
                origin = .epubEmbedded; path = result.1; raster = image
            } else { origin = .placeholder; path = nil; raster = nil }
        case .cbz:
            let archive = try CBZArchive(data: data)
            guard let first = archive.pages.first, let entry = archive.entries.first(where: { $0.path == first.path }) else { throw CoverError.sourceMismatch }
            origin = .cbzFirstImage; path = first.path
            raster = try CoverRaster.image(CBZArchive.expand(entry, from: data), maximum: CoverLimits.thumbnailDimension, byteLimit: ComicLimits.entryBytes)
        case .cbt:
            let archive = try CBTArchive(data: data)
            guard let first = archive.pages.first, let entry = archive.entries.first(where: { $0.path == first.path }) else { throw CoverError.sourceMismatch }
            origin = .cbtFirstImage; path = first.path
            raster = try CoverRaster.image(data.subdata(in: entry.payload), maximum: CoverLimits.thumbnailDimension, byteLimit: ComicLimits.entryBytes)
        case .cb7, .cbr:
            guard let format = ComicArchiveFormat(rawValue: identity.format.rawValue) else { throw CoverError.invalidImage }
            let archive = try NativeComicArchive(data: data, format: format)
            guard let first = archive.pages.first else { throw CoverError.sourceMismatch }
            origin = format == .cb7 ? .cb7FirstImage : .cbrFirstImage; path = first.path
            raster = try CoverRaster.image(archive.pagePNG(at: 0), maximum: CoverLimits.thumbnailDimension, byteLimit: ComicLimits.entryBytes)
        case .docx: origin = .placeholder; path = nil; raster = nil
        }
        try Task.checkCancellation()
        let record = CoverRecord(identity: identity, origin: origin, resourcePath: path,
            imageSHA256: raster.map { LibraryRepository.digest($0.png) }, byteLength: raster?.png.count ?? 0, width: raster?.width ?? 0, height: raster?.height ?? 0,
            revision: revision, extractorVersion: Self.extractorVersion)
        return (record, raster)
    }
    public func replace(_ identity: CoverIdentity, withLocalImage url: URL) throws -> CoverRecord {
        let storeWrite = try LocalStoreWriteGate.shared(root: root).beginWrite()
        defer { storeWrite.finish() }

        let state = try load(); _ = try original(identity)
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try BoundedFileReader.read(url, limit: CoverLimits.inputBytes)
        let raster = try CoverRaster.image(data, maximum: CoverLimits.assetDimension)
        let previous = state.records.first { $0.identity.bookID == identity.bookID }
        let record = CoverRecord(identity: identity, origin: .userImage, imageSHA256: LibraryRepository.digest(raster.png), byteLength: raster.png.count,
            width: raster.width, height: raster.height, revision: (previous?.revision ?? 0) + 1, extractorVersion: Self.extractorVersion)
        try Task.checkCancellation(); try save(record, raster: raster); return record
    }
    /// Explicit restore rebuilds the automatic cover even when extractor/source have not changed.
    public func restoreAutomatic(_ identity: CoverIdentity) throws -> CoverRecord {
        let storeWrite = try LocalStoreWriteGate.shared(root: root).beginWrite()
        defer { storeWrite.finish() }

        let old = try load().records.first { $0.identity.bookID == identity.bookID }
        let (record, raster) = try generate(identity, revision: (old?.revision ?? 0) + 1)
        try save(record, raster: raster); return record
    }
    public func thumbnail(for identity: CoverIdentity) throws -> CoverThumbnail {
        let storeWrite = try LocalStoreWriteGate.shared(root: root).beginWrite()
        defer { storeWrite.finish() }

        try Task.checkCancellation()
        let existing = try load().records.first { $0.identity.bookID == identity.bookID }
        var record = existing?.identity == identity ? existing : nil
        // A user's chosen book cover survives a new source edition. Automatic covers are source-specific.
        if record == nil, let existing, existing.userEdited {
            _ = try original(identity)
            let rebound = CoverRecord(identity: identity, origin: .userImage, imageSHA256: existing.imageSHA256,
                byteLength: existing.byteLength, width: existing.width, height: existing.height,
                revision: existing.revision + 1, extractorVersion: existing.extractorVersion)
            try save(rebound, raster: nil); record = rebound
        }
        if record == nil || (record?.userEdited == false && record?.extractorVersion != Self.extractorVersion) {
            record = try restoreAutomatic(identity)
        }
        guard var current = record else { throw CoverError.invalidStore }
        guard let hash = current.imageSHA256 else { return CoverThumbnail(record: current, png: nil) }
        let key = hash + "-512-1"
        if let value = memory[key], value.0.record == current {
            recent.removeAll { $0 == key }; recent.append(key); return value.0
        }
        let assetBytes: Data
        do {
            assetBytes = try BoundedFileReader.read(asset(hash), limit: CoverLimits.inputBytes)
            guard LibraryRepository.digest(assetBytes) == hash else { throw CoverError.invalidImage }
        } catch {
            if current.userEdited { throw CoverError.invalidImage }
            current = try restoreAutomatic(identity)
            return try thumbnail(for: current.identity)
        }
        let url = cache.appendingPathComponent(key + ".png")
        let raster: CoverRaster
        if let data = try? BoundedFileReader.read(url, limit: CoverLimits.inputBytes),
           let cached = try? CoverRaster.image(data, maximum: CoverLimits.thumbnailDimension),
           cached.width <= CoverLimits.thumbnailDimension, cached.height <= CoverLimits.thumbnailDimension {
            raster = cached
            try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: url.path)
        } else {
            raster = try CoverRaster.image(assetBytes, maximum: CoverLimits.thumbnailDimension)
            try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
            try raster.png.write(to: url, options: .atomic)
            trimDiskCache()
        }
        let result = CoverThumbnail(record: current, png: raster.png)
        let cost = max(raster.png.count, raster.width * raster.height * 4)
        memory[key] = (result, cost); recent.removeAll { $0 == key }; recent.append(key)
        while memory.values.reduce(0, { $0 + $1.1 }) > CoverLimits.memoryBytes, let first = recent.first {
            recent.removeFirst(); memory.removeValue(forKey: first)
        }
        return result
    }
    private func trimDiskCache() {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]
        let files = ((try? FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: Array(keys))) ?? []).compactMap { url -> (URL, Int, Date)? in
            let hash = String(url.lastPathComponent.prefix(64))
            guard LibraryRepository.isDigest(hash), url.lastPathComponent == hash + "-512-1.png",
                  let values = try? url.resourceValues(forKeys: keys), values.isRegularFile == true else { return nil }
            return (url, values.fileSize ?? 0, values.contentModificationDate ?? .distantPast)
        }.sorted { $0.2 < $1.2 }
        var total = files.reduce(0) { $0 + $1.1 }
        for file in files where total > CoverLimits.diskCacheBytes { try? FileManager.default.removeItem(at: file.0); total -= file.1 }
    }
    public func clearMemoryCache() { memory.removeAll(); recent.removeAll() }
}
