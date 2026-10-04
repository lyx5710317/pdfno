// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// In-memory dry-run ledger. No automatic disk writes or network adapter.
/// A production durable outbox/multi-device exporter must preserve publication history.
public struct BooknoOfflinePreview: Sendable {
    public var mode: BooknoPreviewMode
    public let receiverID: UUID
    public let epoch: UUID
    private var sequence = 0
    private var latest: [String: BooknoMutation] = [:]
    private var lastRequestHash: String?
    public private(set) var lastBatch: BooknoPreviewBatch?
    public init(mode: BooknoPreviewMode = .disabled, receiverID: UUID = UUID(), epoch: UUID = UUID()) {
        self.mode = mode; self.receiverID = receiverID; self.epoch = epoch
    }
    /// All selected parent books are included; unchanged entities keep their original revision.
    /// The batch itself remains immutable and is reused for an unknown-result retry.
    public mutating func stage(_ payloads: [BooknoPayload], assets: [BooknoCoverAssetDTO] = [],
                               tombstones: [BooknoTombstoneDTO] = []) throws -> BooknoPreviewBatch {
        guard mode == .preview else { throw BooknoPreviewError.disabled }
        guard Set(payloads.map(\.externalID)).count == payloads.count else { throw BooknoPreviewError.invalidContract }
        var next = latest, mutations: [BooknoMutation] = []
        for payload in payloads.sorted(by: { $0.externalID < $1.externalID }) {
            try BooknoExchangeCodec.validate(payload)
            let hash = try BooknoExchangeCodec.contentHash(payload), previous = latest[payload.externalID]
            let mutation: BooknoMutation
            if let previous, previous.contentHash == hash {
                mutation = BooknoMutation(revision: previous.revision, baseRevision: previous.baseRevision, contentHash: hash, payload: payload)
            } else {
                let base = previous?.revision ?? 0
                guard base < Int.max - 1 else { throw BooknoPreviewError.revisionOverflow }
                mutation = BooknoMutation(revision: base + 1, baseRevision: base, contentHash: hash, payload: payload)
            }
            next[payload.externalID] = mutation; mutations.append(mutation)
        }
        struct Request: Encodable { let mutations: [BooknoMutation]; let assets: [BooknoCoverAssetDTO]; let tombstones: [BooknoTombstoneDTO] }
        let orderedAssets = assets.sorted { $0.assetID < $1.assetID }, orderedTombstones = tombstones.sorted { $0.externalID < $1.externalID }
        let requestHash = try BooknoExchangeCodec.hash(Request(mutations: mutations, assets: orderedAssets, tombstones: orderedTombstones))
        if requestHash == lastRequestHash, let lastBatch { return lastBatch }
        guard sequence < Int.max - 1 else { throw BooknoPreviewError.revisionOverflow }
        let batch = BooknoPreviewBatch(receiverID: receiverID, cursor: BooknoCursor(epoch: epoch, sequence: sequence + 1),
                                      mutations: mutations, assets: orderedAssets, tombstones: orderedTombstones)
        try BooknoExchangeCodec.validate(batch)
        latest = next; sequence += 1; lastRequestHash = requestHash; lastBatch = batch; return batch
    }
}

public struct BooknoConfirmedRevision: Sendable, Equatable {
    public let revision: Int
    public let contentHash: String
}
/// Separate from "staged" or "mock attempted". Invalid/late/stale receipts never invent a confirmation.
public struct BooknoConfirmationTracker: Sendable {
    public let receiverID: UUID
    public let epoch: UUID
    public private(set) var confirmedSequence = 0
    public private(set) var confirmed: [String: BooknoConfirmedRevision] = [:]
    private var registered: [Int: BooknoPreviewBatch] = [:]
    private var completed = Set<Int>()
    public init(receiverID: UUID, epoch: UUID) { self.receiverID = receiverID; self.epoch = epoch }
    public mutating func register(_ batch: BooknoPreviewBatch) throws {
        try BooknoExchangeCodec.validate(batch)
        guard batch.receiverID == receiverID, batch.cursor.epoch == epoch, registered.count < 1000 || registered[batch.cursor.sequence] != nil else {
            throw BooknoPreviewError.receiptMismatch
        }
        if let prior = registered[batch.cursor.sequence], try BooknoExchangeCodec.hash(prior) != BooknoExchangeCodec.hash(batch) {
            throw BooknoPreviewError.receiptMismatch
        }
        registered[batch.cursor.sequence] = batch
    }
    public mutating func acknowledge(_ receipt: BooknoMockReceipt) throws {
        guard let batch = registered[receipt.cursor.sequence], receipt.receiverID == receiverID, receipt.cursor.epoch == epoch,
              receipt.batchID == batch.batchID, receipt.batchHash == (try BooknoExchangeCodec.hash(batch)),
              receipt.items.count == batch.mutations.count,
              Set(receipt.items.map(\.externalID)).count == receipt.items.count,
              Set(receipt.verifiedAssetIDs).isSubset(of: Set(batch.assets.map(\.assetID))),
              Set(receipt.verifiedAssetIDs).count == receipt.verifiedAssetIDs.count,
              Set(receipt.deletionPreviewIDs) == Set(batch.tombstones.map(\.externalID)),
              receipt.deletionPreviewIDs.count == batch.tombstones.count else { throw BooknoPreviewError.receiptMismatch }
        let allConfirmed = receipt.items.allSatisfy { $0.status == .applied || $0.status == .unchanged }
        // The mock commits a batch atomically; a mixed applied/conflict receipt is contradictory.
        if !allConfirmed && receipt.items.contains(where: { $0.status == .applied }) { throw BooknoPreviewError.receiptMismatch }
        if allConfirmed && Set(receipt.verifiedAssetIDs) != Set(batch.assets.map(\.assetID)) { throw BooknoPreviewError.receiptMismatch }
        var next = confirmed
        for mutation in batch.mutations {
            guard let item = receipt.items.first(where: { $0.externalID == mutation.payload.externalID }),
                  item.revision == mutation.revision, item.contentHash == mutation.contentHash else { throw BooknoPreviewError.receiptMismatch }
            guard item.status == .applied || item.status == .unchanged else { continue }
            if case .book(let book) = mutation.payload, let cover = book.coverAssetID,
               !receipt.verifiedAssetIDs.contains(cover) { throw BooknoPreviewError.receiptMismatch }
            if let prior = next[item.externalID] {
                if prior.revision > item.revision { continue }
                guard prior.revision != item.revision || prior.contentHash == item.contentHash else { throw BooknoPreviewError.receiptMismatch }
            }
            next[item.externalID] = BooknoConfirmedRevision(revision: item.revision, contentHash: item.contentHash)
        }
        confirmed = next
        if allConfirmed { completed.insert(receipt.cursor.sequence) }
        while completed.contains(confirmedSequence + 1) { confirmedSequence += 1 }
    }
}

public enum BooknoFieldDecision: Sendable, Equatable { case takeSource, keepLocal, conflict }
public enum BooknoConflictPolicy {
    /// Byte comparison avoids Swift String's canonical-equivalence collapsing distinct source spellings.
    public static func decide(baseline: Data?, local: Data?, incoming: Data?) -> BooknoFieldDecision {
        if local == incoming { return .keepLocal }
        if local == baseline { return .takeSource }
        if incoming == baseline { return .keepLocal }
        return .conflict
    }
}

/// Deliberately a concrete offline mock, with no transport protocol or URLSession implementation.
/// One batch transaction: any upsert conflict blocks all new changes and assets.
public struct BooknoMockReceiver: Sendable {
    private struct Record: Sendable {
        var epoch: UUID
        var revision: Int
        var contentHash: String
        var acceptedSource: BooknoPayload
        var baseline: [String: Data]
        var local: [String: Data]
    }
    public let receiverID: UUID
    private var records: [String: Record] = [:]
    private var assets: [String: BooknoCoverAssetDTO] = [:]
    private var receipts: [UUID: BooknoMockReceipt] = [:]
    public var recordCount: Int { records.count }
    public var assetCount: Int { assets.count }
    public init(receiverID: UUID) { self.receiverID = receiverID }
    public func acceptedSource(_ id: String) -> BooknoPayload? { records[id]?.acceptedSource }
    public func localField(_ id: String, field: String) -> Data? { records[id]?.local[field] }
    /// Test-only simulated receiver editing; values are encoded field snapshots, not a Bookno write.
    public mutating func editLocalField(_ id: String, field: String, encodedValue: Data) throws {
        guard var record = records[id], record.local[field] != nil else { throw BooknoPreviewError.invalidContract }
        record.local[field] = encodedValue; records[id] = record
    }
    private static func fields(_ payload: BooknoPayload) throws -> [String: Data] {
        switch payload {
        case .book(let b):
            struct Cover: Encodable { let assetID: String?; let origin: CoverOrigin? }
            return ["title": try BooknoExchangeCodec.canonical(b.title), "authors": try BooknoExchangeCodec.canonical(b.authors),
                    "edition": try BooknoExchangeCodec.canonical(b.edition),
                    "cover": try BooknoExchangeCodec.canonical(Cover(assetID: b.coverAssetID, origin: b.coverOrigin))]
        case .note(let n):
            return ["userText": try BooknoExchangeCodec.canonical(n.userText), "source": try BooknoExchangeCodec.canonical(n.source),
                    "aiAttachments": try BooknoExchangeCodec.canonical(n.aiAttachments)]
        }
    }
    public mutating func receive(_ batch: BooknoPreviewBatch, assetBytes: [String: Data] = [:],
                                  loseReceiptAfterCommit: Bool = false) throws -> BooknoMockReceipt {
        try BooknoExchangeCodec.validate(batch)
        guard batch.receiverID == receiverID else { throw BooknoPreviewError.invalidContract }
        let batchHash = try BooknoExchangeCodec.hash(batch)
        if let receipt = receipts[batch.batchID] {
            guard receipt.batchHash == batchHash else { throw BooknoPreviewError.batchContentMismatch }; return receipt
        }
        guard Set(assetBytes.keys).isSubset(of: Set(batch.assets.map(\.assetID))) else { throw BooknoPreviewError.assetInvalid }
        var nextAssets = assets
        for asset in batch.assets {
            if let verified = assets[asset.assetID] {
                guard verified == asset else { throw BooknoPreviewError.assetInvalid }
                if let bytes = assetBytes[asset.assetID] { try BooknoExchangeCodec.validateAsset(bytes, declaration: asset) }
            } else {
                guard let bytes = assetBytes[asset.assetID] else { throw BooknoPreviewError.assetMissing }
                try BooknoExchangeCodec.validateAsset(bytes, declaration: asset); nextAssets[asset.assetID] = asset
            }
        }
        var next = records, statuses: [String: BooknoReceiptStatus] = [:]
        // Parents are decided first, independent of sender ordering.
        let ordered = batch.mutations.sorted { $0.payload.kind == .book && $1.payload.kind == .note }
        for mutation in ordered {
            let id = mutation.payload.externalID
            if case .note(let note) = mutation.payload {
                guard let parent = next[note.externalBookID], case .book(let book) = parent.acceptedSource else {
                    statuses[id] = .missingParent; continue
                }
                guard BooknoExchangeCodec.sourceMatches(note, book: book) else { throw BooknoPreviewError.sourceMismatch }
            }
            if let prior = records[id] {
                if prior.epoch != batch.cursor.epoch { statuses[id] = .baseRevisionMismatch; continue }
                if mutation.revision < prior.revision { statuses[id] = .staleRevision; continue }
                if mutation.revision == prior.revision {
                    statuses[id] = mutation.contentHash == prior.contentHash ? .unchanged : .revisionContentMismatch; continue
                }
                if mutation.baseRevision != prior.revision { statuses[id] = .baseRevisionMismatch; continue }
            } else if mutation.baseRevision != 0 { statuses[id] = .baseRevisionMismatch; continue }
            let incoming = try Self.fields(mutation.payload)
            var merged = incoming
            if let prior = records[id] {
                var conflict = false
                for key in incoming.keys {
                    switch BooknoConflictPolicy.decide(baseline: prior.baseline[key], local: prior.local[key], incoming: incoming[key]) {
                    case .takeSource: break
                    case .keepLocal: merged[key] = prior.local[key]
                    case .conflict: conflict = true
                    }
                }
                if conflict { statuses[id] = .localEditDiverged; continue }
            }
            next[id] = Record(epoch: batch.cursor.epoch, revision: mutation.revision, contentHash: mutation.contentHash,
                              acceptedSource: mutation.payload, baseline: incoming, local: merged)
            statuses[id] = .applied
        }
        let canCommit = statuses.values.allSatisfy { $0 == .applied || $0 == .unchanged }
        if canCommit { records = next; assets = nextAssets }
        else { for (id, status) in statuses where status == .applied { statuses[id] = .blockedDependency } }
        let receipt = BooknoMockReceipt(receiverID: receiverID, batchID: batch.batchID, batchHash: batchHash, cursor: batch.cursor,
            items: batch.mutations.map { BooknoReceiptItem(externalID: $0.payload.externalID, revision: $0.revision,
                contentHash: $0.contentHash, status: statuses[$0.payload.externalID] ?? .blockedDependency) },
            verifiedAssetIDs: batch.assets.filter { assets[$0.assetID] != nil }.map(\.assetID),
            deletionPreviewIDs: batch.tombstones.map(\.externalID))
        receipts[batch.batchID] = receipt
        if loseReceiptAfterCommit { throw BooknoPreviewError.mockResultUnknown }; return receipt
    }
}
