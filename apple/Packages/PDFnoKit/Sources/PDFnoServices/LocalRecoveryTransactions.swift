// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

struct RecoveryMutation { let path: String; let before: Data?; let after: Data? }
struct RecoveryJournalEntry: Codable {
    let path: String
    let beforeSHA256: String?
    let afterSHA256: String?
}
struct RecoveryJournal: Codable {
    let schemaVersion: Int
    let id: UUID
    var phase: String
    let entries: [RecoveryJournalEntry]
}
enum RecoveryFaultPoint: Sendable { case prepared, installed(Int), beforeCommit, committed, packageStaged, packageCopied(Int), beforePackageInstall, packageInstalled }
struct RecoverySimulatedInterruption: Error {}
struct RecoveryTransactionEngine {
    let root: URL
    let registry: RecoveryRegistry
    let fault: @Sendable (RecoveryFaultPoint) throws -> Void
    static let directory = "LocalRecovery/Transactions"
    func validatePath(_ path: String) throws {
        let name = path.hasSuffix(".backup") ? String(path.dropLast(7)) : path
        guard RecoveryFiles.safePath(path), registry.adapters[name] != nil || path == RecoveryFiles.stateName || RecoveryFiles.assetPath(path) else { throw LocalRecoveryError.invalidPath }
    }
    func journals() throws -> [(String, RecoveryJournal)] {
        let folder = try RecoveryFiles.checked(root, Self.directory, allowMissing: true)
        guard FileManager.default.fileExists(atPath: folder.path) else { return [] }
        var result: [(String, RecoveryJournal)] = []
        for child in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            guard let id = UUID(uuidString: child.lastPathComponent) else { throw LocalRecoveryError.invalidPackage }
            let prefix = Self.directory + "/" + child.lastPathComponent
            _ = try RecoveryFiles.checked(root, prefix)
            guard let data = try RecoveryFiles.optional(root, prefix + "/journal.json") else { continue } // no journal => no source writes ever began
            let object = try RecoveryRegistry.object(data)
            guard Set(object.keys) == ["schemaVersion", "id", "phase", "entries"], let entries = object["entries"] as? [[String: Any]],
                  entries.allSatisfy({ Set($0.keys).isSubset(of: ["path", "beforeSHA256", "afterSHA256"]) }) else { throw LocalRecoveryError.invalidPackage }
            let journal = try JSONDecoder().decode(RecoveryJournal.self, from: data)
            guard journal.id == id, ["prepared", "committed", "rolledBack"].contains(journal.phase),
                  journal.entries.count <= LocalRecoveryLimits.entries, Set(journal.entries.map(\.path)).count == journal.entries.count else { throw LocalRecoveryError.invalidPackage }
            for entry in journal.entries {
                try validatePath(entry.path)
                guard entry.afterSHA256.map(LibraryRepository.isDigest) == true, entry.beforeSHA256.map(LibraryRepository.isDigest) ?? true else { throw LocalRecoveryError.integrity }
            }
            result.append((prefix, journal))
        }
        return result.sorted { $0.0 < $1.0 }
    }
    func ensureSettled() throws {
        guard try !journals().contains(where: { $0.1.phase == "prepared" }) else { throw LocalRecoveryError.pendingTransaction }
    }
    func commit(_ mutations: [RecoveryMutation]) throws -> LocalRecoveryReceipt {
        try ensureSettled(); try Task.checkCancellation()
        let mutations = mutations.filter { $0.before != $0.after }.sorted { $0.path < $1.path }
        guard !mutations.isEmpty, mutations.count <= LocalRecoveryLimits.entries, Set(mutations.map(\.path)).count == mutations.count else { throw LocalRecoveryError.conflict }
        for mutation in mutations {
            try validatePath(mutation.path)
            guard try RecoveryFiles.optional(root, mutation.path) == mutation.before else { throw LocalRecoveryError.conflict }
        }
        let id = UUID(), prefix = Self.directory + "/" + id.uuidString
        var journal = RecoveryJournal(schemaVersion: 1, id: id, phase: "prepared", entries: mutations.map {
            .init(path: $0.path, beforeSHA256: $0.before.map(LibraryRepository.digest), afterSHA256: $0.after.map(LibraryRepository.digest))
        })
        var stagedBytes = 0
        for (index, mutation) in mutations.enumerated() {
            try Task.checkCancellation()
            for (kind, bytes) in [("before", mutation.before), ("after", mutation.after)] {
                if let bytes {
                    guard bytes.count <= LocalRecoveryLimits.totalBytes - stagedBytes else { throw LocalRecoveryError.limit }
                    stagedBytes += bytes.count
                    try RecoveryFiles.write(bytes, root: root, path: prefix + "/" + kind + "/" + String(index))
                    guard try RecoveryFiles.read(root, prefix + "/" + kind + "/" + String(index), uncancelled: true) == bytes else { throw LocalRecoveryError.integrity }
                }
            }
        }
        try write(journal, prefix: prefix)
        do {
            try fault(.prepared)
            for (index, mutation) in mutations.enumerated() {
                try Task.checkCancellation()
                guard try RecoveryFiles.optional(root, mutation.path) == mutation.before else { throw LocalRecoveryError.conflict }
                try install(mutation.after, path: mutation.path)
                try fault(.installed(index))
            }
            // All paths must still match, including ones installed earlier.
            for mutation in mutations { guard try RecoveryFiles.optional(root, mutation.path) == mutation.after else { throw LocalRecoveryError.conflict } }
            try Task.checkCancellation(); try fault(.beforeCommit)
            journal.phase = "committed"; try write(journal, prefix: prefix)
        } catch is RecoverySimulatedInterruption { throw RecoverySimulatedInterruption() }
        catch {
            // Rollback does not consult cancellation: a cancelled operation still restores preimages.
            try rollback(journal, prefix: prefix)
            throw error
        }
        try fault(.committed) // crash after this point is a committed operation, never rollback
        return .init(id: id, paths: mutations.map(\.path), disposition: "committed")
    }
    func staged(_ prefix: String, _ kind: String, _ index: Int, _ hash: String?) throws -> Data? {
        guard let hash else { return nil }
        guard LibraryRepository.isDigest(hash) else { throw LocalRecoveryError.integrity }
        // BoundedFileReader checks task cancellation. Recovery runs from a fresh host task.
        let data = try RecoveryFiles.read(root, prefix + "/" + kind + "/" + String(index), uncancelled: true)
        guard LibraryRepository.digest(data) == hash else { throw LocalRecoveryError.integrity }; return data
    }
    func rollback(_ journal: RecoveryJournal, prefix: String) throws {
        var planned: [(RecoveryJournalEntry, Data?)] = []
        for (index, entry) in journal.entries.enumerated() {
            let before = try staged(prefix, "before", index, entry.beforeSHA256)
            let after = try staged(prefix, "after", index, entry.afterSHA256)
            let current = try RecoveryFiles.optional(root, entry.path, uncancelled: true)
            guard current == before || current == after else { throw LocalRecoveryError.conflict }
            planned.append((entry, before))
        }
        for (entry, before) in planned.reversed() {
            let current = try RecoveryFiles.optional(root, entry.path, uncancelled: true)
            guard current.map(LibraryRepository.digest) == entry.beforeSHA256 || current.map(LibraryRepository.digest) == entry.afterSHA256 else { throw LocalRecoveryError.conflict }
            try install(before, path: entry.path)
        }
        var finished = journal; finished.phase = "rolledBack"; try write(finished, prefix: prefix)
    }
    func recover() throws -> [LocalRecoveryReceipt] {
        var receipts: [LocalRecoveryReceipt] = []
        for (prefix, journal) in try journals() {
            if journal.phase == "prepared" {
                try rollback(journal, prefix: prefix)
                receipts.append(.init(id: journal.id, paths: journal.entries.map(\.path), disposition: "rolledBack"))
            } else if journal.phase == "committed" {
                // Later ordinary saves may differ; the durable receipt records a historical commit.
                receipts.append(.init(id: journal.id, paths: journal.entries.map(\.path), disposition: "committed"))
            }
        }
        return receipts
    }
    private func install(_ data: Data?, path: String) throws {
        if let data { try RecoveryFiles.write(data, root: root, path: path) }
        else if let _ = try RecoveryFiles.optional(root, path, uncancelled: true) { try FileManager.default.removeItem(at: RecoveryFiles.checked(root, path)) }
    }
    private func write(_ journal: RecoveryJournal, prefix: String) throws {
        let bytes = try JSONEncoder().encode(journal)
        guard bytes.count <= LocalRecoveryLimits.manifestBytes else { throw LocalRecoveryError.limit }
        try RecoveryFiles.write(bytes, root: root, path: prefix + "/journal.json")
    }
}
