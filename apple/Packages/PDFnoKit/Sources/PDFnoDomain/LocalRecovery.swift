// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum LocalRecoveryError: LocalizedError, Sendable {
    case invalidPackage, invalidPath, unsupportedStore(String), integrity, conflict, writerNotPaused, pendingTransaction, limit
    public var errorDescription: String? {
        switch self {
        case .invalidPackage: "备份或回收站记录无法验证；现有数据已保留。"
        case .invalidPath: "只接受受管目录中的普通文件；已拒绝链接或不安全路径。"
        case .unsupportedStore(let name): "尚未审核的数据文件：\(name)。请升级或注册对应适配器。"
        case .integrity: "数据或资产校验失败；没有覆盖现有书库。"
        case .conflict: "数据已经变化或目标已存在；请重新预检，不会覆盖新编辑。"
        case .writerNotPaused: "恢复操作需要先暂停所有书库写入和学习任务。"
        case .pendingTransaction: "存在未完成操作；请先恢复事务，再开启书库写入。"
        case .limit: "数据超过本地恢复模块的条目或体积限额。"
        }
    }
}
public struct LocalRecoveryBook: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public let format: String
    public let title: String
    public let manifest: String
    public init(id: UUID, editionID: UUID, fileSHA256: String, format: String, title: String, manifest: String) {
        self.id = id; self.editionID = editionID; self.fileSHA256 = fileSHA256
        self.format = format; self.title = title; self.manifest = manifest
    }
    public var originalPath: String { "Originals/" + fileSHA256 + "." + format }
}
public enum LocalRecoveryTarget: Codable, Sendable, Equatable {
    case book(LocalRecoveryBook)
    case note(manifest: String, id: UUID)
}
public struct LocalRecoveryFragment: Codable, Sendable, Equatable {
    public let manifest: String
    public let collection: String
    public let records: [Data]
    public init(manifest: String, collection: String, records: [Data]) {
        self.manifest = manifest; self.collection = collection; self.records = records
    }
}
public struct LocalRecoveryAsset: Codable, Sendable, Equatable {
    public let originalPath: String
    public let retainedPath: String
    public let byteLength: Int
    public let sha256: String
    public init(originalPath: String, retainedPath: String, byteLength: Int, sha256: String) {
        self.originalPath = originalPath; self.retainedPath = retainedPath; self.byteLength = byteLength; self.sha256 = sha256
    }
}
public struct LocalRecoveryTombstone: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let target: LocalRecoveryTarget
    public let createdAt: Date
    public var restored: Bool
    public let fragments: [LocalRecoveryFragment]
    public let assets: [LocalRecoveryAsset]

    public init(id: UUID = UUID(), target: LocalRecoveryTarget, createdAt: Date = Date(), restored: Bool = false,
                fragments: [LocalRecoveryFragment], assets: [LocalRecoveryAsset]) {
        self.id = id; self.target = target; self.createdAt = createdAt; self.restored = restored
        self.fragments = fragments; self.assets = assets
    }
}
public struct LocalRecoveryState: Codable, Sendable {
    public let schemaVersion: Int
    public var tombstones: [LocalRecoveryTombstone]
    public init(tombstones: [LocalRecoveryTombstone] = []) { schemaVersion = 1; self.tombstones = tombstones }
}
public struct LocalRecoveryInventoryEntry: Codable, Sendable, Equatable {
    public let path: String
    public let byteLength: Int
    public let sha256: String
    public init(path: String, byteLength: Int, sha256: String) { self.path = path; self.byteLength = byteLength; self.sha256 = sha256 }
}
public struct LocalRecoveryInventory: Codable, Sendable {
    public let schemaVersion: Int
    public let format: String
    public let id: UUID
    public let createdAt: Date
    public let adapters: [String]
    public let entries: [LocalRecoveryInventoryEntry]
    public let totalBytes: Int
    public let omittedDrafts: [String]
    public init(adapters: [String], entries: [LocalRecoveryInventoryEntry], omittedDrafts: [String] = []) {
        schemaVersion = 1; format = "pdfno-directory-backup-1"; id = UUID(); createdAt = Date()
        self.adapters = adapters; self.entries = entries; self.omittedDrafts = omittedDrafts; totalBytes = entries.reduce(0) { $0 + $1.byteLength }
    }
}
public struct LocalRecoveryPreview: Sendable {
    public let inventory: LocalRecoveryInventory
    public let inventorySHA256: String
    public let books: [LocalRecoveryBook]
    public let savedRecordCount: Int
    public let tombstoneCount: Int
    public let omittedDrafts: [String]
    public let restoreMode = "仅恢复到新的空目录；不合并、不覆盖现有书库"

    public init(inventory: LocalRecoveryInventory, inventorySHA256: String, books: [LocalRecoveryBook], savedRecordCount: Int, tombstoneCount: Int, omittedDrafts: [String]) {
        self.inventory = inventory; self.inventorySHA256 = inventorySHA256; self.books = books
        self.savedRecordCount = savedRecordCount; self.tombstoneCount = tombstoneCount; self.omittedDrafts = omittedDrafts
    }
}
/// The host creates this ONLY after it has drained every repository writer, stopped
/// reader progress/AI saves, and blocked draft saves. Keep the pause until reload or
/// recovery finishes. This attestation does not itself suspend existing repositories.
public struct LocalRecoveryWritePermit: Sendable {
    public let root: URL
    public let writerEpoch: UUID
    public init(pausedRoot: URL, writerEpoch: UUID) { root = pausedRoot.standardizedFileURL; self.writerEpoch = writerEpoch }
}
public struct LocalRecoveryReceipt: Sendable {
    public let id: UUID
    public let paths: [String]
    public let disposition: String

    public init(id: UUID, paths: [String], disposition: String) { self.id = id; self.paths = paths; self.disposition = disposition }
}
public enum LocalRecoveryLimits {
    public static let manifestBytes = 5 * 1024 * 1024
    public static let assetBytes = 200 * 1024 * 1024
    public static let totalBytes = 256 * 1024 * 1024
    public static let entries = 20_000
    public static let tombstones = 1000
}
public struct LocalRecoveryChangePreview: Sendable {
    public let target: LocalRecoveryTarget
    public let tombstoneID: UUID?
    public let snapshotSHA256: String
    public let savedRecords: Int
    public let retainedAssets: Int
    public init(target: LocalRecoveryTarget, tombstoneID: UUID?, snapshotSHA256: String, savedRecords: Int, retainedAssets: Int) {
        self.target = target; self.tombstoneID = tombstoneID; self.snapshotSHA256 = snapshotSHA256
        self.savedRecords = savedRecords; self.retainedAssets = retainedAssets
    }
}
