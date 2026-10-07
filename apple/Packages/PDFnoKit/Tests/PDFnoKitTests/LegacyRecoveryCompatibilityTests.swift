// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
@testable import PDFnoServices

/// Frozen packages exported by 88ff6d6's real service from its synthetic storage
/// fixtures. These are not rendering fixtures, personal libraries or backups.
private struct LegacyBackupFixture {
    let parent: URL, root: URL, package: URL
    let english: Bool
    init(english: Bool = false) throws {
        self.english = english
        parent = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Legacy-Original-" + UUID().uuidString).resolvingSymlinksInPath()
        root = parent.appendingPathComponent("existing")
        package = parent.appendingPathComponent("package")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let fixtures = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let original = fixtures.appendingPathComponent("LocalRecoveryLegacy88FF/" + (english ? "with-english" : "standard"))
        try FileManager.default.copyItem(at: original, to: package)
        try FileManager.default.copyItem(at: package.appendingPathComponent("Payload"), to: root)
    }
    var permit: LocalRecoveryWritePermit { .init(pausedRoot: root, writerEpoch: UUID()) }
    func service() throws -> LocalRecoveryService {
        try LocalRecoveryService(root: root, additionalAdapters: english ? [.englishLearning()] : [])
    }
    func cleanup() { try? FileManager.default.removeItem(at: parent) }
    func bytes(_ directory: URL) throws -> [String: Data] {
        let root = directory.resolvingSymlinksInPath().standardizedFileURL
        let enumerator = try #require(FileManager.default.enumerator(atPath: root.path))
        var result: [String: Data] = [:]
        for case let relative as String in enumerator {
            let path = root.appendingPathComponent(relative)
            if try path.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
                result[relative] = try Data(contentsOf: path)
            }
        }
        return result
    }
    func inventory() throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: package.appendingPathComponent("inventory-v1.json"))) as! [String: Any]
    }
    func writeInventory(_ object: [String: Any]) throws {
        try RecoveryFiles.write(RecoveryRegistry.encode(object), root: package, path: "inventory-v1.json")
    }
    /// Recompute all lengths/hashes so rejection tests exercise store/path/profile
    /// validation rather than accidentally stopping at stale inventory metadata.
    func replacePayload(_ data: Data, path: String) throws {
        try RecoveryFiles.write(data, root: package, path: "Payload/" + path)
        var object = try inventory(), entries = object["entries"] as! [[String: Any]]
        entries.removeAll { $0["path"] as? String == path }
        entries.append(["path": path, "byteLength": data.count, "sha256": LibraryRepository.digest(data)])
        object["entries"] = entries
        object["totalBytes"] = entries.reduce(0) { $0 + ($1["byteLength"] as! Int) }
        try writeInventory(object)
    }
}

struct LegacyRecoveryCompatibilityTests {
    @Test(arguments: [false, true])
    func legacy88FFBackupRestoresExactPayloadWithoutInventingProvenance(_ english: Bool) async throws {
        let f = try LegacyBackupFixture(english: english); defer { f.cleanup() }
        let originalPackage = try f.bytes(f.package), original = try f.bytes(f.root), service = try f.service()
        let preview = try await service.verifyBackup(at: f.package)
        #expect(preview.inventory.adapters.count == (english ? 14 : 13))
        #expect(!preview.inventory.adapters.contains("bundled-examples-v1.json"))
        #expect(preview.books.count == 16 && preview.tombstoneCount == 1)
        let destination = f.parent.appendingPathComponent("restored")
        _ = try await service.restoreBackup(at: f.package, preview: preview, to: destination, permit: f.permit)
        // Includes all original IDs, editions, hashes, Unicode notes, progress,
        // metadata, old tombstone and original/retained bytes, not just counts.
        #expect(try f.bytes(destination) == original)
        #expect(try await BundledExampleRepository(root: destination).load().records.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: destination.appendingPathComponent("bundled-examples-v1.json").path))
        let recovered = try LocalRecoveryService(root: destination, additionalAdapters: english ? [.englishLearning()] : [])
        #expect(try await recovered.books() == preview.books)
        let currentPackage = f.parent.appendingPathComponent("reexported-current")
        let current = try await recovered.exportBackup(to: currentPackage, permit: .init(pausedRoot: destination, writerEpoch: UUID()))
        #expect(current.inventory.adapters.contains("bundled-examples-v1.json"))
        #expect(try f.bytes(currentPackage.appendingPathComponent("Payload")) == original)
        #expect(try f.bytes(f.root) == original && f.bytes(f.package) == originalPackage)
    }

    @Test(arguments: [false, true])
    func currentProvenanceBackupRoundTripAndTrashRemainExact(_ english: Bool) async throws {
        let f = try LegacyBackupFixture(english: english); defer { f.cleanup() }
        let service = try f.service(), book = try #require(try await service.books().first { $0.format == "pdf" })
        let identity = BundledExampleIdentity(format: "pdf", bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256)
        let examples = BundledExampleRepository(root: f.root)
        let records = try await examples.registerNewImport(identity, resource: "study-sample.pdf", existingBookIDs: [], newImport: true, bundledSHA256: book.fileSHA256)
        let before = try f.bytes(f.root), currentPackage = f.parent.appendingPathComponent("current")
        let preview = try await service.exportBackup(to: currentPackage, permit: f.permit)
        #expect(preview.inventory.adapters.count == (english ? 15 : 14))
        let destination = f.parent.appendingPathComponent("restored-current")
        _ = try await service.restoreBackup(at: currentPackage, preview: preview, to: destination, permit: f.permit)
        #expect(try f.bytes(destination) == before)
        #expect(try await BundledExampleRepository(root: destination).load().records == records.records)
        _ = try await service.moveToTrash(service.previewMoveToTrash(.book(book)), permit: f.permit)
        #expect(try await examples.load().records.isEmpty)
        let tombstone = try #require(try await service.tombstones().first { $0.target == .book(book) })
        _ = try await service.restoreTombstone(service.previewRestoreTombstone(tombstone.id), permit: f.permit)
        #expect(try await examples.load().records == records.records)
        #expect(try RecoveryFiles.read(f.root, book.manifest) == before[book.manifest])
        #expect(try RecoveryFiles.read(f.root, book.originalPath) == before[book.originalPath])
    }

    @Test(arguments: ["unknownAdapter", "duplicateAdapter", "missingCoreAdapter", "differentEnglishConfiguration",
        "duplicateEntry", "traversal", "futureSchema", "booleanSchema", "unknownInventoryField", "corruptAsset",
        "invalidStore", "wrongAssociation", "unknownStore", "listedProvenance", "unlistedProvenance", "provenanceBackup", "provenanceTombstone"])
    func invalidLegacyPackagesAreRejectedWithoutChangingPackageOrExistingLibrary(_ mode: String) async throws {
        let f = try LegacyBackupFixture(); defer { f.cleanup() }
        let service = try f.service(), preview = try await service.verifyBackup(at: f.package)
        let existing = try f.bytes(f.root)
        var object = try f.inventory(), adapters = object["adapters"] as! [String]
        switch mode {
        case "unknownAdapter": adapters[0] = "unknown-v1.json"; object["adapters"] = adapters; try f.writeInventory(object)
        case "duplicateAdapter": adapters.append(adapters[0]); object["adapters"] = adapters; try f.writeInventory(object)
        case "missingCoreAdapter": adapters.removeLast(); object["adapters"] = adapters; try f.writeInventory(object)
        case "differentEnglishConfiguration": adapters.append("english-learning-v1.json"); object["adapters"] = adapters; try f.writeInventory(object)
        case "duplicateEntry": var entries = object["entries"] as! [[String: Any]]; entries.append(entries[0]); object["entries"] = entries; try f.writeInventory(object)
        case "traversal": var entries = object["entries"] as! [[String: Any]]; entries[0]["path"] = "../existing/library-v1.json"; object["entries"] = entries; try f.writeInventory(object)
        case "futureSchema": object["schemaVersion"] = 2; try f.writeInventory(object)
        case "booleanSchema": object["schemaVersion"] = true; try f.writeInventory(object)
        case "unknownInventoryField": object["future"] = 1; try f.writeInventory(object)
        case "corruptAsset":
            let entry = try #require((object["entries"] as! [[String: Any]]).first { ($0["path"] as? String)?.hasPrefix("Originals/") == true })
            try RecoveryFiles.write(Data("broken original bytes".utf8), root: f.package, path: "Payload/" + (entry["path"] as! String))
        case "invalidStore": try f.replacePayload(Data("{broken".utf8), path: "library-v1.json")
        case "wrongAssociation":
            var store = try RecoveryRegistry.object(RecoveryFiles.read(f.root, "library-v1.json")), notes = store["notes"] as! [[String: Any]]
            notes[0]["bookID"] = UUID().uuidString; store["notes"] = notes
            try f.replacePayload(RecoveryRegistry.encode(store), path: "library-v1.json")
        case "unknownStore": try f.replacePayload(Data("{\"schemaVersion\":1,\"records\":[]}".utf8), path: "unknown-v1.json")
        case "listedProvenance", "provenanceBackup":
            try f.replacePayload(Data("{\"schemaVersion\":1,\"records\":[]}".utf8), path: mode == "listedProvenance" ? "bundled-examples-v1.json" : "bundled-examples-v1.json.backup")
        case "unlistedProvenance":
            try RecoveryFiles.write(Data("{\"schemaVersion\":1,\"records\":[]}".utf8), root: f.package, path: "Payload/bundled-examples-v1.json")
        case "provenanceTombstone":
            var state = try RecoveryRegistry.object(RecoveryFiles.read(f.root, "local-recovery-v1.json")), tombstones = state["tombstones"] as! [[String: Any]]
            var fragments = tombstones[0]["fragments"] as! [[String: Any]]
            fragments.append(["manifest": "bundled-examples-v1.json", "collection": "records", "records": [Data("{}".utf8).base64EncodedString()]])
            tombstones[0]["fragments"] = fragments; state["tombstones"] = tombstones
            try f.replacePayload(RecoveryRegistry.encode(state), path: "local-recovery-v1.json")
        default: Issue.record("Unknown mutation"); return
        }
        let damaged = try f.bytes(f.package), destination = f.parent.appendingPathComponent("rejected")
        await #expect(throws: (any Error).self) { try await service.verifyBackup(at: f.package) }
        await #expect(throws: (any Error).self) { try await service.restoreBackup(at: f.package, preview: preview, to: destination, permit: f.permit) }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(try f.bytes(f.package) == damaged)
        #expect(try f.bytes(f.root) == existing)
        #expect(try !FileManager.default.contentsOfDirectory(atPath: f.parent.path).contains { $0.hasPrefix(".pdfno-stage-") })
    }
}
