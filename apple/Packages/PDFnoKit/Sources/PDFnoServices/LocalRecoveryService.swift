// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Darwin
import PDFnoDomain

/// Single-process operations; the host MUST pause/drain all existing repository
/// writers before it grants a permit. Readers remain closed until reload completes.
public actor LocalRecoveryService {
    public let root: URL
    private let registry: RecoveryRegistry
    private let fault: @Sendable (RecoveryFaultPoint) throws -> Void
    public init(root: URL, additionalAdapters: [LocalRecoveryAdditionalAdapter] = []) throws {
        self.root = root.standardizedFileURL; registry = try RecoveryRegistry(additional: additionalAdapters); fault = { _ in }
    }
    init(root: URL, additionalAdapters: [LocalRecoveryAdditionalAdapter] = [], fault: @escaping @Sendable (RecoveryFaultPoint) throws -> Void) throws {
        self.root = root.standardizedFileURL; registry = try RecoveryRegistry(additional: additionalAdapters); self.fault = fault
    }
    private var engine: RecoveryTransactionEngine { .init(root: root, registry: registry, fault: fault) }
    private func require(_ permit: LocalRecoveryWritePermit) throws {
        guard permit.root.standardizedFileURL == root else { throw LocalRecoveryError.writerNotPaused }
        _ = try RecoveryFiles.checked(root)
    }
    public func recoverPendingTransactions(permit: LocalRecoveryWritePermit) throws -> [LocalRecoveryReceipt] {
        try require(permit); return try engine.recover()
    }
    public func books() throws -> [LocalRecoveryBook] { try engine.ensureSettled(); return try RecoveryFiles.capture(root, registry: registry).books }
    public func tombstones() throws -> [LocalRecoveryTombstone] { try engine.ensureSettled(); return try RecoveryFiles.capture(root, registry: registry).state.tombstones }
    private func fingerprint(_ snapshot: RecoverySnapshot) throws -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return LibraryRepository.digest(try encoder.encode(snapshot.entries))
    }
    private func deletion(_ target: LocalRecoveryTarget, snapshot: RecoverySnapshot) throws -> ([LocalRecoveryFragment], [LocalRecoveryAsset]) {
        var fragments: [LocalRecoveryFragment] = [], assets: [LocalRecoveryAsset] = []
        var matched = false
        if case .book(let expected) = target { guard snapshot.books.contains(expected) else { throw LocalRecoveryError.conflict } }
        for name in registry.adapters.keys.sorted() {
            guard let bytes = snapshot.files[name] else { continue }
            let object = try registry.decode(name, bytes), adapter = registry.adapters[name]!
            let extra = try adapter.extraAssociations?(bytes)
            for collection in adapter.collections {
                let rows = object[collection] as! [[String: Any]]
                var selected: [[String: Any]] = []
                for row in rows {
                    let id = try RecoveryRegistry.id(row), includes: Bool
                    switch target {
                    case .book(let book):
                        if collection == "books" { includes = name == book.manifest && id == book.id }
                        else {
                            let link = try extra?.first { $0.recordID == id } ?? RecoveryRegistry.association(row)
                            includes = link.bookID == book.id && link.editionID == book.editionID && link.fileSHA256 == book.fileSHA256
                        }
                    case .note(let manifest, let noteID): includes = name == manifest && collection == "notes" && id == noteID
                    }
                    if includes { selected.append(row); matched = true }
                }
                if !selected.isEmpty {
                    fragments.append(.init(manifest: name, collection: collection, records: try selected.map { try RecoveryRegistry.encode($0) }))
                    if name == "covers-v1.json" {
                        for row in selected { if let hash = row["imageSHA256"] as? String { try asset("Covers/Assets/" + hash + ".png") } }
                    }
                }
            }
        }
        func asset(_ path: String) throws {
            guard let data = snapshot.files[path] else { throw LocalRecoveryError.integrity }
            if assets.contains(where: { $0.originalPath == path }) { return }
            assets.append(.init(originalPath: path, retainedPath: "LocalRecovery/Assets/" + URL(fileURLWithPath: path).lastPathComponent,
                                byteLength: data.count, sha256: LibraryRepository.digest(data)))
        }
        if case .book(let book) = target { try asset(book.originalPath) }
        guard matched else { throw LocalRecoveryError.conflict }
        return (fragments, assets)
    }
    public func previewMoveToTrash(_ target: LocalRecoveryTarget) throws -> LocalRecoveryChangePreview {
        try engine.ensureSettled(); let snapshot = try RecoveryFiles.capture(root, registry: registry)
        let (fragments, assets) = try deletion(target, snapshot: snapshot)
        return .init(target: target, tombstoneID: nil, snapshotSHA256: try fingerprint(snapshot),
                     savedRecords: fragments.filter { $0.collection == "notes" }.reduce(0) { $0 + $1.records.count }, retainedAssets: assets.count)
    }
    public func moveToTrash(_ preview: LocalRecoveryChangePreview, permit: LocalRecoveryWritePermit) throws -> LocalRecoveryReceipt {
        try require(permit); try engine.ensureSettled()
        let snapshot = try RecoveryFiles.capture(root, registry: registry)
        guard preview.tombstoneID == nil, try fingerprint(snapshot) == preview.snapshotSHA256 else { throw LocalRecoveryError.conflict }
        let (fragments, assets) = try deletion(preview.target, snapshot: snapshot)
        var next = snapshot.files, state = snapshot.state
        guard state.tombstones.count < LocalRecoveryLimits.tombstones else { throw LocalRecoveryError.limit }
        for fragment in fragments {
            // All fragments are staged together; an intermediate book removal can
            // temporarily leave notes without a parent until the final validation.
            var object = try RecoveryRegistry.object(next[fragment.manifest]!)
            let ids = Set(try fragment.records.map { try RecoveryRegistry.id(JSONSerialization.jsonObject(with: $0) as! [String: Any]) })
            object[fragment.collection] = (object[fragment.collection] as! [[String: Any]]).filter { !ids.contains((try? RecoveryRegistry.id($0)) ?? UUID()) }
            next[fragment.manifest] = try RecoveryRegistry.encode(object)
        }
        for asset in assets {
            if let existing = next[asset.retainedPath] { guard LibraryRepository.digest(existing) == asset.sha256 else { throw LocalRecoveryError.conflict } }
            else { next[asset.retainedPath] = snapshot.files[asset.originalPath]! }
        }
        state.tombstones.append(.init(target: preview.target, fragments: fragments, assets: assets))
        next[RecoveryFiles.stateName] = try JSONEncoder().encode(state)
        _ = try RecoveryFiles.validate(next, registry: registry)
        return try commitChanges(from: snapshot.files, to: next)
    }
    public func previewRestoreTombstone(_ id: UUID) throws -> LocalRecoveryChangePreview {
        try engine.ensureSettled(); let snapshot = try RecoveryFiles.capture(root, registry: registry)
        guard let tombstone = snapshot.state.tombstones.first(where: { $0.id == id }) else { throw LocalRecoveryError.conflict }
        _ = try restoration(tombstone, snapshot: snapshot)
        return .init(target: tombstone.target, tombstoneID: id, snapshotSHA256: try fingerprint(snapshot),
                     savedRecords: tombstone.fragments.filter { $0.collection == "notes" }.reduce(0) { $0 + $1.records.count }, retainedAssets: tombstone.assets.count)
    }
    private func restoration(_ tombstone: LocalRecoveryTombstone, snapshot: RecoverySnapshot) throws -> [String: Data] {
        if tombstone.restored { return snapshot.files } // stable receipt; does not overwrite later edits
        var next = snapshot.files, state = snapshot.state
        for fragment in tombstone.fragments {
            let adapter = registry.adapters[fragment.manifest]!
            var object = try next[fragment.manifest].map { try registry.decode(fragment.manifest, $0) } ?? RecoveryFiles.empty(adapter)
            var rows = object[fragment.collection] as! [[String: Any]]
            for data in fragment.records {
                let row = try JSONSerialization.jsonObject(with: data) as! [String: Any], id = try RecoveryRegistry.id(row)
                if let current = rows.first(where: { (try? RecoveryRegistry.id($0)) == id }) {
                    guard try RecoveryRegistry.encode(current) == data else { throw LocalRecoveryError.conflict }
                } else { rows.append(row) }
            }
            object[fragment.collection] = rows; next[fragment.manifest] = try RecoveryRegistry.encode(object)
        }
        for asset in tombstone.assets {
            let bytes = snapshot.files[asset.retainedPath]!
            if let current = next[asset.originalPath] { guard current == bytes else { throw LocalRecoveryError.conflict } }
            else { next[asset.originalPath] = bytes }
        }
        let index = state.tombstones.firstIndex { $0.id == tombstone.id }!; state.tombstones[index].restored = true
        next[RecoveryFiles.stateName] = try JSONEncoder().encode(state)
        _ = try RecoveryFiles.validate(next, registry: registry)
        return next
    }
    public func restoreTombstone(_ preview: LocalRecoveryChangePreview, permit: LocalRecoveryWritePermit) throws -> LocalRecoveryReceipt {
        try require(permit); try engine.ensureSettled(); let snapshot = try RecoveryFiles.capture(root, registry: registry)
        guard try fingerprint(snapshot) == preview.snapshotSHA256, let id = preview.tombstoneID,
              let tombstone = snapshot.state.tombstones.first(where: { $0.id == id }), tombstone.target == preview.target else { throw LocalRecoveryError.conflict }
        if tombstone.restored { return .init(id: id, paths: [], disposition: "alreadyRestored") }
        return try commitChanges(from: snapshot.files, to: restoration(tombstone, snapshot: snapshot))
    }
    private func commitChanges(from old: [String: Data], to next: [String: Data]) throws -> LocalRecoveryReceipt {
        try engine.commit(Set(old.keys).union(next.keys).map { .init(path: $0, before: old[$0], after: next[$0]) })
    }
    public func exportBackup(to destination: URL, permit: LocalRecoveryWritePermit) throws -> LocalRecoveryPreview {
        try require(permit); try engine.ensureSettled(); let snapshot = try RecoveryFiles.capture(root, registry: registry)
        let inventory = LocalRecoveryInventory(adapters: registry.adapters.keys.sorted(), entries: snapshot.entries, omittedDrafts: snapshot.omittedDrafts.sorted())
        let bytes = try JSONEncoder().encode(inventory), stage = try staging(for: destination)
        defer { try? FileManager.default.removeItem(at: stage) }
        try FileManager.default.createDirectory(at: stage.appendingPathComponent("Payload"), withIntermediateDirectories: false)
        try fault(.packageStaged)
        for (index, path) in snapshot.files.keys.sorted().enumerated() {
            try Task.checkCancellation(); try RecoveryFiles.write(snapshot.files[path]!, root: stage, path: "Payload/" + path)
            try fault(.packageCopied(index))
        }
        try RecoveryFiles.write(bytes, root: stage, path: "inventory-v1.json")
        let preview = try verifyBackup(at: stage)
        // Recheck the complete snapshot, including file additions/removals, after copy.
        guard try fingerprint(RecoveryFiles.capture(root, registry: registry)) == fingerprint(snapshot) else { throw LocalRecoveryError.conflict }
        try fault(.beforePackageInstall); try Task.checkCancellation(); try exclusiveMove(stage, to: destination)
        try fault(.packageInstalled)
        return preview
    }
    public func verifyBackup(at package: URL) throws -> LocalRecoveryPreview {
        let (inventory, bytes, snapshot) = try packageSnapshot(package)
        return .init(inventory: inventory, inventorySHA256: LibraryRepository.digest(bytes), books: snapshot.books,
                     savedRecordCount: snapshot.savedRecords, tombstoneCount: snapshot.state.tombstones.count, omittedDrafts: inventory.omittedDrafts)
    }
    private func packageSnapshot(_ package: URL) throws -> (LocalRecoveryInventory, Data, RecoverySnapshot) {
        _ = try RecoveryFiles.checked(package)
        let names = try FileManager.default.contentsOfDirectory(atPath: package.path)
        guard Set(names) == ["inventory-v1.json", "Payload"] else { throw LocalRecoveryError.invalidPackage }
        let bytes = try RecoveryFiles.read(package, "inventory-v1.json", limit: LocalRecoveryLimits.manifestBytes)
        let object = try RecoveryRegistry.object(bytes)
        guard Set(object.keys) == ["schemaVersion", "format", "id", "createdAt", "adapters", "entries", "totalBytes", "omittedDrafts"],
              let rows = object["entries"] as? [[String: Any]], rows.allSatisfy({ Set($0.keys) == ["path", "byteLength", "sha256"] }) else { throw LocalRecoveryError.invalidPackage }
        let inventory = try JSONDecoder().decode(LocalRecoveryInventory.self, from: bytes)
        let packageRegistry = try registry.backupRegistry(forDeclaredAdapters: inventory.adapters)
        guard inventory.format == "pdfno-directory-backup-1", inventory.createdAt.timeIntervalSince1970.isFinite,
              inventory.omittedDrafts.allSatisfy({ RecoveryFiles.drafts.contains($0) || RecoveryFiles.drafts.map({ $0 + ".backup" }).contains($0) }),
              Set(inventory.omittedDrafts).count == inventory.omittedDrafts.count,
              inventory.entries.count <= LocalRecoveryLimits.entries, inventory.totalBytes >= 0,
              inventory.totalBytes <= LocalRecoveryLimits.totalBytes, Set(inventory.entries.map(\.path)).count == inventory.entries.count else { throw LocalRecoveryError.invalidPackage }
        var files: [String: Data] = [:], total = 0
        for entry in inventory.entries {
            guard RecoveryFiles.safePath(entry.path), entry.byteLength >= 0, entry.byteLength <= LocalRecoveryLimits.assetBytes,
                  LibraryRepository.isDigest(entry.sha256), entry.byteLength <= LocalRecoveryLimits.totalBytes - total else { throw LocalRecoveryError.invalidPackage }
            let data = try RecoveryFiles.read(package, "Payload/" + entry.path, limit: entry.byteLength)
            guard data.count == entry.byteLength, LibraryRepository.digest(data) == entry.sha256 else { throw LocalRecoveryError.integrity }
            total += data.count; files[entry.path] = data
        }
        guard total == inventory.totalBytes else { throw LocalRecoveryError.integrity }
        let payload = try RecoveryFiles.checked(package, "Payload")
        let actual = try RecoveryFiles.capture(payload, registry: packageRegistry)
        guard actual.files == files, actual.omittedDrafts.isEmpty else { throw LocalRecoveryError.invalidPackage }
        return (inventory, bytes, actual)
    }
    /// The preview pins the inventory. Reverification pins every asset and rejects a
    /// changed package. Destination must not exist; installation is one exclusive rename.
    public func restoreBackup(at package: URL, preview: LocalRecoveryPreview, to destination: URL,
                              permit: LocalRecoveryWritePermit) throws -> LocalRecoveryReceipt {
        try require(permit); try engine.ensureSettled()
        let (inventory, bytes, snapshot) = try packageSnapshot(package)
        guard LibraryRepository.digest(bytes) == preview.inventorySHA256, inventory.id == preview.inventory.id else { throw LocalRecoveryError.conflict }
        let stage = try staging(for: destination)
        defer { try? FileManager.default.removeItem(at: stage) }
        try fault(.packageStaged)
        for (index, path) in snapshot.files.keys.sorted().enumerated() {
            try Task.checkCancellation(); try RecoveryFiles.write(snapshot.files[path]!, root: stage, path: path)
            try fault(.packageCopied(index))
        }
        let installed = try RecoveryFiles.capture(stage, registry: registry)
        guard installed.files == snapshot.files else { throw LocalRecoveryError.integrity }
        try fault(.beforePackageInstall); try Task.checkCancellation(); try exclusiveMove(stage, to: destination)
        try fault(.packageInstalled)
        return .init(id: inventory.id, paths: inventory.entries.map(\.path), disposition: "restoredToNewRoot")
    }
    private func staging(for destination: URL) throws -> URL {
        let target = try RecoveryFiles.checked(destination, allowMissing: true)
        guard !FileManager.default.fileExists(atPath: target.path), target.path != root.path,
              !target.standardizedFileURL.path.hasPrefix(try RecoveryFiles.checked(root).path + "/") else { throw LocalRecoveryError.conflict }
        _ = try RecoveryFiles.checked(target.deletingLastPathComponent())
        let stage = target.deletingLastPathComponent().appendingPathComponent(".pdfno-stage-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: stage, withIntermediateDirectories: false)
        return stage
    }
    private func exclusiveMove(_ stage: URL, to destination: URL) throws {
        let target = try RecoveryFiles.checked(destination, allowMissing: true)
        let result = stage.withUnsafeFileSystemRepresentation { source in target.withUnsafeFileSystemRepresentation { destination in
            Darwin.renamex_np(source!, destination!, UInt32(RENAME_EXCL))
        } }
        guard result == 0 else { throw LocalRecoveryError.conflict }
    }
}
