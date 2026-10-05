// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Darwin
import PDFnoDomain

struct RecoverySnapshot {
    var files: [String: Data]
    let books: [LocalRecoveryBook]
    let savedRecords: Int
    let state: LocalRecoveryState
    let omittedDrafts: [String]
    var entries: [LocalRecoveryInventoryEntry] {
        files.keys.sorted().map { .init(path: $0, byteLength: files[$0]!.count, sha256: LibraryRepository.digest(files[$0]!)) }
    }
}
enum RecoveryFiles {
    static let stateName = "local-recovery-v1.json"
    static let drafts = ["note-edit-drafts-v1.json", "record-edit-drafts-v1.json"]
    static let formats: Set<String> = ["pdf", "epub", "cbz", "cbt", "cb7", "cbr", "docx", "txt", "markdown", "html", "xhtml", "mhtml", "xml", "mobi", "azw", "azw3", "fb2"]
    static func safePath(_ value: String) -> Bool {
        let parts = value.split(separator: "/", omittingEmptySubsequences: false)
        return !value.isEmpty && value.utf8.count <= 512 && !value.contains("\\") && !value.contains("\0") &&
            parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." && !$0.contains(":") }
    }
    static func checked(_ root: URL, _ path: String = "", allowMissing: Bool = false) throws -> URL {
        guard root.isFileURL, path.isEmpty || safePath(path) else { throw LocalRecoveryError.invalidPath }
        let url = path.isEmpty ? root.standardizedFileURL : root.standardizedFileURL.appendingPathComponent(path)
        var full = url.standardizedFileURL.path
        // macOS system aliases are canonicalized; custom links are still rejected.
        if full == "/var" || full.hasPrefix("/var/") { full = "/private" + full }
        if full == "/tmp" || full.hasPrefix("/tmp/") { full = "/private" + full }
        var current = URL(fileURLWithPath: "/", isDirectory: true)
        for part in full.split(separator: "/") {
            current.appendPathComponent(String(part))
            var info = stat()
            let result = current.withUnsafeFileSystemRepresentation { Darwin.lstat($0!, &info) }
            if result != 0 {
                if errno == ENOENT && allowMissing { continue }
                throw LocalRecoveryError.invalidPath
            }
            guard (info.st_mode & S_IFMT) != S_IFLNK else { throw LocalRecoveryError.invalidPath }
        }
        return URL(fileURLWithPath: full)
    }
    static func read(_ root: URL, _ path: String, limit: Int = LocalRecoveryLimits.assetBytes, uncancelled: Bool = false) throws -> Data {
        let url = try checked(root, path)
        if uncancelled { return try rollbackRead(url, limit: limit) }
        return try BoundedFileReader.read(url, limit: limit)
    }
    static func optional(_ root: URL, _ path: String, uncancelled: Bool = false) throws -> Data? {
        let url = try checked(root, path, allowMissing: true)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return try read(root, path, uncancelled: uncancelled)
    }
    /// Rollback must finish even when the initiating task was cancelled.
    private static func rollbackRead(_ url: URL, limit: Int) throws -> Data {
        let descriptor = url.withUnsafeFileSystemRepresentation { Darwin.open($0!, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC) }
        guard descriptor >= 0 else { throw LocalRecoveryError.invalidPath }
        defer { Darwin.close(descriptor) }
        var before = stat(), after = stat()
        guard fstat(descriptor, &before) == 0, (before.st_mode & S_IFMT) == S_IFREG,
              before.st_size >= 0, before.st_size <= limit else { throw LocalRecoveryError.limit }
        var bytes = Data(), buffer = [UInt8](repeating: 0, count: 65536)
        while true {
            let requested = min(buffer.count, limit - bytes.count + 1)
            let count = buffer.withUnsafeMutableBytes { Darwin.read(descriptor, $0.baseAddress, requested) }
            if count < 0 { if errno == EINTR { continue }; throw LocalRecoveryError.integrity }
            if count == 0 { break }
            guard count <= limit - bytes.count else { throw LocalRecoveryError.limit }
            bytes.append(contentsOf: buffer.prefix(count))
        }
        guard fstat(descriptor, &after) == 0, before.st_size == after.st_size, bytes.count == after.st_size,
              before.st_mtimespec.tv_sec == after.st_mtimespec.tv_sec, before.st_mtimespec.tv_nsec == after.st_mtimespec.tv_nsec else { throw LocalRecoveryError.integrity }
        return bytes
    }
    static func write(_ data: Data, root: URL, path: String) throws {
        let url = try checked(root, path, allowMissing: true)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        _ = try checked(root, path, allowMissing: true)
        try data.write(to: url, options: .atomic)
    }
    static func capture(_ root: URL, registry: RecoveryRegistry) throws -> RecoverySnapshot {
        _ = try checked(root)
        var files: [String: Data] = [:], drafts: [String] = [], total = 0
        func admit(_ path: String, _ limit: Int) throws {
            let data = try read(root, path, limit: limit)
            guard files.count < LocalRecoveryLimits.entries, data.count <= LocalRecoveryLimits.totalBytes - total else { throw LocalRecoveryError.limit }
            total += data.count; files[path] = data
        }
        for url in try FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) {
            try Task.checkCancellation()
            let name = url.lastPathComponent
            _ = try checked(root, name)
            if registry.adapters[name] != nil || name == stateName { try admit(name, LocalRecoveryLimits.manifestBytes) }
            else if name.hasSuffix(".backup"), registry.adapters[String(name.dropLast(7))] != nil { try admit(name, LocalRecoveryLimits.manifestBytes) }
            else if drafts.contains(name) || Self.drafts.contains(name) || Self.drafts.map({ $0 + ".backup" }).contains(name) { drafts.append(name) }
            else if ["Originals", "Covers", "LocalRecovery"].contains(name) { continue }
            else { throw LocalRecoveryError.unsupportedStore(name) }
        }
        for directory in ["Originals", "Covers/Assets", "LocalRecovery/Assets"] {
            let folder = try checked(root, directory, allowMissing: true)
            guard FileManager.default.fileExists(atPath: folder.path) else { continue }
            for url in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                let path = directory + "/" + url.lastPathComponent
                guard assetPath(path) else { throw LocalRecoveryError.invalidPath }
                try admit(path, directory == "Covers/Assets" ? CoverLimits.inputBytes : LocalRecoveryLimits.assetBytes)
            }
        }
        // Cache is deliberately excluded; unknown content beside the cache is not discarded.
        for directory in ["Covers", "LocalRecovery"] {
            let folder = try checked(root, directory, allowMissing: true)
            guard FileManager.default.fileExists(atPath: folder.path) else { continue }
            for child in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                let allowed = directory == "Covers" ? ["Assets", "Thumbnails"] : ["Assets", "Transactions"]
                guard allowed.contains(child.lastPathComponent) else { throw LocalRecoveryError.unsupportedStore(directory + "/" + child.lastPathComponent) }
                _ = try checked(root, directory + "/" + child.lastPathComponent)
            }
        }
        return try validate(files, registry: registry, drafts: drafts)
    }
    static func assetPath(_ path: String) -> Bool {
        guard safePath(path) else { return false }
        let parts = path.split(separator: "/")
        let file = URL(fileURLWithPath: String(parts.last!)), hash = file.deletingPathExtension().lastPathComponent
        guard LibraryRepository.isDigest(hash) else { return false }
        if parts.count == 2, parts[0] == "Originals" { return formats.contains(file.pathExtension) }
        if parts.count == 3, parts[0] == "Covers", parts[1] == "Assets" { return file.pathExtension == "png" }
        if parts.count == 3, parts[0] == "LocalRecovery", parts[1] == "Assets" { return formats.contains(file.pathExtension) || file.pathExtension == "png" }
        return false
    }
    static func decodeState(_ data: Data?) throws -> LocalRecoveryState {
        guard let data else { return LocalRecoveryState() }
        let object = try RecoveryRegistry.object(data)
        guard Set(object.keys) == ["schemaVersion", "tombstones"], let rows = object["tombstones"] as? [[String: Any]], rows.allSatisfy({
            Set($0.keys) == ["id", "target", "createdAt", "restored", "fragments", "assets"] &&
            ($0["fragments"] as? [[String: Any]])?.allSatisfy({ Set($0.keys) == ["manifest", "collection", "records"] }) == true &&
            ($0["assets"] as? [[String: Any]])?.allSatisfy({ Set($0.keys) == ["originalPath", "retainedPath", "byteLength", "sha256"] }) == true
        }) else { throw LocalRecoveryError.invalidPackage }
        let state = try JSONDecoder().decode(LocalRecoveryState.self, from: data)
        // Codable-associated payloads are checked by byte-preserving canonical topology.
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! NSDictionary
        guard encoded.isEqual(to: object), state.tombstones.count <= LocalRecoveryLimits.tombstones,
              Set(state.tombstones.map(\.id)).count == state.tombstones.count else { throw LocalRecoveryError.invalidPackage }
        return state
    }
    static func validate(_ files: [String: Data], registry: RecoveryRegistry, drafts: [String] = []) throws -> RecoverySnapshot {
        guard files.count <= LocalRecoveryLimits.entries, files.values.reduce(0, { $0 + $1.count }) <= LocalRecoveryLimits.totalBytes else { throw LocalRecoveryError.limit }
        var objects: [String: [String: Any]] = [:], books: [LocalRecoveryBook] = [], recordCount = 0
        for (path, data) in files {
            guard safePath(path) else { throw LocalRecoveryError.invalidPath }
            if assetPath(path) {
                guard data.count <= LocalRecoveryLimits.assetBytes,
                      LibraryRepository.digest(data) == URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent else { throw LocalRecoveryError.integrity }
            } else if path == stateName { continue }
            else {
                let name = path.hasSuffix(".backup") ? String(path.dropLast(7)) : path
                let object = try registry.decode(name, data)
                if path == name { objects[name] = object }
            }
        }
        for (name, object) in objects {
            let adapter = registry.adapters[name]!
            if let format = adapter.format {
                for row in object["books"] as! [[String: Any]] {
                    let identity = try RecoveryRegistry.identity(row), actual = format == "variable" ? (row["format"] as? String ?? "") : format
                    guard formats.contains(actual) else { throw LocalRecoveryError.integrity }
                    let book = LocalRecoveryBook(id: identity.0, editionID: identity.1, fileSHA256: identity.2,
                                                 format: actual, title: row["title"] as? String ?? "", manifest: name)
                    guard files[book.originalPath] != nil else { throw LocalRecoveryError.integrity }
                    books.append(book)
                }
            }
            for collection in adapter.collections where collection != "books" { recordCount += (object[collection] as! [Any]).count }
        }
        guard Set(books.map(\.id)).count == books.count, Set(books.map(\.editionID)).count == books.count else { throw LocalRecoveryError.conflict }
        for (name, object) in objects {
            let adapter = registry.adapters[name]!
            for collection in adapter.collections where collection != "books" {
                let extra = try adapter.extraAssociations?(files[name]!)
                for row in object[collection] as! [[String: Any]] {
                    let id = try RecoveryRegistry.id(row)
                    let link = try extra?.first { $0.recordID == id } ?? RecoveryRegistry.association(row)
                    guard books.contains(where: { $0.id == link.bookID && $0.editionID == link.editionID && $0.fileSHA256 == link.fileSHA256 && (link.format == nil || $0.format == link.format) }) else { throw LocalRecoveryError.integrity }
                    if name == "covers-v1.json", let hash = row["imageSHA256"] as? String {
                        guard let bytes = files["Covers/Assets/" + hash + ".png"], bytes.count == row["byteLength"] as? Int else { throw LocalRecoveryError.integrity }
                        guard bytes.starts(with: Data([137, 80, 78, 71, 13, 10, 26, 10])) else { throw LocalRecoveryError.integrity }
                        let raster = try CoverRaster.image(bytes, maximum: CoverLimits.assetDimension)
                        guard raster.width == row["width"] as? Int, raster.height == row["height"] as? Int else { throw LocalRecoveryError.integrity }
                    }
                }
            }
        }
        let state = try decodeState(files[stateName])
        var historicalBooks = objects
        for tombstone in state.tombstones {
            for fragment in tombstone.fragments where fragment.collection == "books" {
                guard let adapter = registry.adapters[fragment.manifest] else { throw LocalRecoveryError.unsupportedStore(fragment.manifest) }
                var object = historicalBooks[fragment.manifest] ?? empty(adapter)
                var rows = object["books"] as! [[String: Any]]
                for bytes in fragment.records {
                    guard let row = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw LocalRecoveryError.invalidPackage }
                    let id = try RecoveryRegistry.id(row)
                    if !rows.contains(where: { (try? RecoveryRegistry.id($0)) == id }) { rows.append(row) }
                }
                object["books"] = rows; historicalBooks[fragment.manifest] = object
            }
        }
        var historicalIdentities: [(UUID, UUID, String)] = []
        for object in historicalBooks.values {
            for row in object["books"] as? [[String: Any]] ?? [] { historicalIdentities.append(try RecoveryRegistry.identity(row)) }
        }
        for (path, data) in files where path.hasSuffix(".backup") {
            let object = try registry.decode(String(path.dropLast(7)), data)
            for row in object["books"] as? [[String: Any]] ?? [] { historicalIdentities.append(try RecoveryRegistry.identity(row)) }
        }
        // Previous manifests also require their referenced originals to remain present.
        for (path, data) in files where path.hasSuffix(".backup") {
            let name = String(path.dropLast(7)), adapter = registry.adapters[name]!
            if let format = adapter.format {
                let object = try registry.decode(name, data)
                for row in object["books"] as! [[String: Any]] {
                    let identity = try RecoveryRegistry.identity(row), actual = format == "variable" ? (row["format"] as? String ?? "") : format
                    guard files["Originals/" + identity.2 + "." + actual] != nil else { throw LocalRecoveryError.integrity }
                }
            }
            let previous = try registry.decode(name, data), extra = try adapter.extraAssociations?(data)
            for collection in adapter.collections where collection != "books" {
                for row in previous[collection] as! [[String: Any]] {
                    let id = try RecoveryRegistry.id(row), link = try extra?.first { $0.recordID == id } ?? RecoveryRegistry.association(row)
                    guard historicalIdentities.contains(where: { $0.0 == link.bookID && $0.1 == link.editionID && $0.2 == link.fileSHA256 }) else { throw LocalRecoveryError.integrity }
                }
            }
            if name == "covers-v1.json" {
                let object = try registry.decode(name, data)
                for row in object["records"] as! [[String: Any]] {
                    if let hash = row["imageSHA256"] as? String {
                        guard files["Covers/Assets/" + hash + ".png"]?.count == row["byteLength"] as? Int else { throw LocalRecoveryError.integrity }
                    }
                }
            }
        }
        for tombstone in state.tombstones {
            guard tombstone.createdAt.timeIntervalSince1970.isFinite, !tombstone.fragments.isEmpty, tombstone.fragments.count <= 64 else { throw LocalRecoveryError.invalidPackage }
            for asset in tombstone.assets {
                guard assetPath(asset.originalPath), asset.retainedPath == "LocalRecovery/Assets/" + URL(fileURLWithPath: asset.originalPath).lastPathComponent,
                      let bytes = files[asset.retainedPath], bytes.count == asset.byteLength, LibraryRepository.digest(bytes) == asset.sha256 else { throw LocalRecoveryError.integrity }
            }
            var merged = historicalBooks
            // Validate historical fragments against the saved original book row, without
            // treating current edits to a restored record as corruption of its tombstone.
            guard Set(tombstone.fragments.map { $0.manifest + ":" + $0.collection }).count == tombstone.fragments.count, Set(tombstone.assets.map(\.originalPath)).count == tombstone.assets.count else { throw LocalRecoveryError.invalidPackage }
            for fragment in tombstone.fragments {
                guard let adapter = registry.adapters[fragment.manifest], adapter.collections.contains(fragment.collection),
                      !fragment.records.isEmpty, fragment.records.count <= 10000 else { throw LocalRecoveryError.invalidPackage }
                var object = merged[fragment.manifest] ?? empty(adapter)
                var rows = object[fragment.collection] as! [[String: Any]], fragmentIDs: Set<UUID> = []
                for bytes in fragment.records {
                    guard JapaneseLearningJSON.hasUniqueKeysForStore(bytes), let row = try JSONSerialization.jsonObject(with: bytes) as? [String: Any] else { throw LocalRecoveryError.invalidPackage }
                    let id = try RecoveryRegistry.id(row)
                    guard fragmentIDs.insert(id).inserted else { throw LocalRecoveryError.invalidPackage }
                    rows.removeAll { (try? RecoveryRegistry.id($0)) == id }; rows.append(row)
                }
                object[fragment.collection] = rows; merged[fragment.manifest] = object
            }
            for name in Set(tombstone.fragments.map(\.manifest)) { _ = try registry.decode(name, RecoveryRegistry.encode(merged[name]!)) }
            for fragment in tombstone.fragments where fragment.collection != "books" {
                let adapter = registry.adapters[fragment.manifest]!
                let links = try adapter.extraAssociations?(RecoveryRegistry.encode(merged[fragment.manifest]!))
                for data in fragment.records {
                    let row = try JSONSerialization.jsonObject(with: data) as! [String: Any], id = try RecoveryRegistry.id(row)
                    let link = try links?.first { $0.recordID == id } ?? RecoveryRegistry.association(row)
                    if case .book(let book) = tombstone.target {
                        guard link.bookID == book.id, link.editionID == book.editionID, link.fileSHA256 == book.fileSHA256, link.format == nil || link.format == book.format else { throw LocalRecoveryError.integrity }
                    } else {
                        let historicalRows = historicalBooks.values.flatMap { $0["books"] as? [[String: Any]] ?? [] }
                        guard historicalRows.contains(where: { guard let identity = try? RecoveryRegistry.identity($0) else { return false }; return identity.0 == link.bookID && identity.1 == link.editionID && identity.2 == link.fileSHA256 }) else { throw LocalRecoveryError.integrity }
                    }
                }
            }
            if case .note(let name, let id) = tombstone.target {
                guard tombstone.fragments.count == 1, let fragment = tombstone.fragments.first, fragment.manifest == name,
                      fragment.collection == "notes", fragment.records.count == 1,
                      try RecoveryRegistry.id(JSONSerialization.jsonObject(with: fragment.records[0]) as! [String: Any]) == id,
                      tombstone.assets.isEmpty else { throw LocalRecoveryError.integrity }
            }
            if case .book(let book) = tombstone.target {
                guard formats.contains(book.format), registry.adapters[book.manifest]?.format != nil, tombstone.fragments.contains(where: { $0.manifest == book.manifest && $0.collection == "books" && $0.records.contains(where: {
                    guard let row = try? JSONSerialization.jsonObject(with: $0) as? [String: Any], let identity = try? RecoveryRegistry.identity(row) else { return false }
                    return identity.0 == book.id && identity.1 == book.editionID && identity.2 == book.fileSHA256
                }) }), tombstone.assets.contains(where: { $0.originalPath == book.originalPath }) else { throw LocalRecoveryError.integrity }
            }
        }
        return RecoverySnapshot(files: files, books: books.sorted { $0.id.uuidString < $1.id.uuidString }, savedRecords: recordCount, state: state, omittedDrafts: drafts)
    }
    static func empty(_ adapter: RecoveryAdapter) -> [String: Any] {
        var object: [String: Any] = ["schemaVersion": 1]
        for collection in adapter.collections { object[collection] = [[String: Any]]() }
        if adapter.filename == "learning-v1.json" {
            object["config"] = try? JSONSerialization.jsonObject(with: JSONEncoder().encode(AIProviderConfig()))
        }
        return object
    }
}
