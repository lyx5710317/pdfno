// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Proposed wire contract only. No endpoint, credential, original bytes or local path.
public enum BooknoPreviewMode: String, Codable, Sendable { case disabled, preview }
public enum BooknoEntityKind: String, Codable, Sendable { case book, note }
public enum BooknoOffsetUnit: String, Codable, Sendable { case utf16CodeUnit, pdfUserSpace }
public enum BooknoAnnotationKind: String, Codable, Sendable { case highlight, learning }

public enum BooknoIdentity {
    public static func book(_ id: UUID, format: BooknoFormat) -> String {
        "pdfno:book:" + format.rawValue + ":" + id.uuidString.lowercased()
    }
    public static func note(_ id: UUID, format: BooknoFormat, kind: BooknoAnnotationKind = .highlight) -> String {
        "pdfno:note:" + format.rawValue + ":" + kind.rawValue + ":" + id.uuidString.lowercased()
    }
}

public struct BooknoEditionDTO: Codable, Sendable, Equatable {
    public let id: UUID
    public let format: BooknoFormat
    public let sourceFileSHA256: String
    public init(id: UUID, format: BooknoFormat, sourceFileSHA256: String) {
        self.id = id; self.format = format; self.sourceFileSHA256 = sourceFileSHA256
    }
}

public struct BooknoBookDTO: Codable, Sendable, Equatable {
    public let externalID: String
    public let bookUUID: UUID
    public let edition: BooknoEditionDTO
    public let title: String
    public let authors: [String]
    public let coverAssetID: String?
    public let coverOrigin: CoverOrigin?
    public let coverSourceRevision: Int?
    public let metadataSourceRevision: Int?
    public init(bookUUID: UUID, edition: BooknoEditionDTO, title: String, authors: [String] = [],
                coverAssetID: String? = nil, coverOrigin: CoverOrigin? = nil, coverSourceRevision: Int? = nil,
                metadataSourceRevision: Int? = nil) {
        self.externalID = BooknoIdentity.book(bookUUID, format: edition.format); self.bookUUID = bookUUID
        self.edition = edition; self.title = title; self.authors = authors; self.coverAssetID = coverAssetID
        self.coverOrigin = coverOrigin; self.coverSourceRevision = coverSourceRevision
        self.metadataSourceRevision = metadataSourceRevision
    }
}

/// Native locator is preserved, including extraction version and UTF-16 offsets.
/// This is a typed operation reference, not a registered deep link or URL containing note text.
public struct BooknoSourceDTO: Codable, Sendable, Equatable {
    public let bookUUID: UUID
    public let format: BooknoFormat
    public let offsetUnit: BooknoOffsetUnit
    public let textNormalizationVersion: String
    public let anchor: BooknoSourceAnchor
    public init(bookUUID: UUID, format: BooknoFormat, anchor: AISelectionAnchor) {
        self.bookUUID = bookUUID; self.format = format; self.anchor = BooknoSourceAnchor(anchor)
        switch anchor { case .pdf: offsetUnit = .pdfUserSpace; case .epub, .pdfPage, .epubChapter: offsetUnit = .utf16CodeUnit }
        textNormalizationVersion = "native-verbatim-1"
    }
    public init(bookUUID: UUID, format: BooknoFormat, textAnchor: TextFormatAnchor) {
        self.bookUUID = bookUUID; self.format = format; anchor = .text(textAnchor)
        offsetUnit = .utf16CodeUnit; textNormalizationVersion = "native-verbatim-1"
    }
}

public struct BooknoAIAttachmentDTO: Codable, Sendable, Equatable {
    public let author: String
    public let kind: AILearningKind
    public let text: String
    public let promptVersion: String
    public init(kind: AILearningKind, text: String, promptVersion: String) {
        author = "ai"; self.kind = kind; self.text = text; self.promptVersion = promptVersion
    }
}

public struct BooknoNoteDTO: Codable, Sendable, Equatable {
    public let externalID: String
    public let noteUUID: UUID
    public let externalBookID: String
    public let annotationKind: BooknoAnnotationKind
    public let quote: String
    public let userText: String
    public let source: BooknoSourceDTO
    public let localEditRevision: Int?
    public let aiAttachments: [BooknoAIAttachmentDTO]
    // Native stores do not persist a highlight color/style; none is invented here.
    public init(noteUUID: UUID, annotationKind: BooknoAnnotationKind = .highlight,
                userText: String, source: BooknoSourceDTO, localEditRevision: Int? = nil,
                aiAttachments: [BooknoAIAttachmentDTO] = []) {
        externalID = BooknoIdentity.note(noteUUID, format: source.format, kind: annotationKind)
        self.noteUUID = noteUUID; externalBookID = BooknoIdentity.book(source.bookUUID, format: source.format)
        self.annotationKind = annotationKind; quote = source.anchor.quote; self.userText = userText
        self.source = source; self.localEditRevision = localEditRevision; self.aiAttachments = aiAttachments
    }
}

public struct BooknoCoverAssetDTO: Codable, Sendable, Equatable {
    public let assetID: String
    public let sha256: String
    public let mimeType: String
    public let byteLength: Int
    public let width: Int
    public let height: Int
    public init(sha256: String, mimeType: String, byteLength: Int, width: Int, height: Int) {
        assetID = "sha256:" + sha256; self.sha256 = sha256; self.mimeType = mimeType
        self.byteLength = byteLength; self.width = width; self.height = height
    }
}

/// Informational only in v1: never calls a delete or mutates a receiver record.
public struct BooknoTombstoneDTO: Codable, Sendable, Equatable {
    public let kind: BooknoEntityKind
    public let externalID: String
    public let lastKnownRevision: Int
    public init(kind: BooknoEntityKind, externalID: String, lastKnownRevision: Int) {
        self.kind = kind; self.externalID = externalID; self.lastKnownRevision = lastKnownRevision
    }
}

public enum BooknoPayload: Codable, Sendable, Equatable {
    case book(BooknoBookDTO), note(BooknoNoteDTO)
    public var externalID: String { switch self { case .book(let b): b.externalID; case .note(let n): n.externalID } }
    public var kind: BooknoEntityKind { switch self { case .book: .book; case .note: .note } }
}

public struct BooknoMutation: Codable, Sendable, Equatable {
    public let revision: Int
    public let baseRevision: Int
    public let contentHash: String
    public let payload: BooknoPayload
    public init(revision: Int, baseRevision: Int, contentHash: String, payload: BooknoPayload) {
        self.revision = revision; self.baseRevision = baseRevision; self.contentHash = contentHash; self.payload = payload
    }
}

/// Cursor is scoped to one export owner/epoch and receiver; it is never a global device revision.
public struct BooknoCursor: Codable, Sendable, Equatable {
    public let epoch: UUID
    public let sequence: Int
    public init(epoch: UUID, sequence: Int) { self.epoch = epoch; self.sequence = sequence }
}

public struct BooknoPreviewBatch: Codable, Sendable, Equatable {
    public let protocolName: String
    public let schemaVersion: Int
    public let canonicalizationVersion: String
    public let sourceNamespace: String
    public let mode: BooknoPreviewMode
    public let receiverID: UUID
    public let batchID: UUID
    public let cursor: BooknoCursor
    public let mutations: [BooknoMutation]
    public let assets: [BooknoCoverAssetDTO]
    public let tombstones: [BooknoTombstoneDTO]
    public init(receiverID: UUID, batchID: UUID = UUID(), cursor: BooknoCursor,
                mutations: [BooknoMutation], assets: [BooknoCoverAssetDTO] = [], tombstones: [BooknoTombstoneDTO] = []) {
        protocolName = "pdfno-bookno-exchange-preview"; schemaVersion = 1
        canonicalizationVersion = "swift-json-verbatim-1"; sourceNamespace = "pdfno"; mode = .preview
        self.receiverID = receiverID; self.batchID = batchID; self.cursor = cursor
        self.mutations = mutations; self.assets = assets; self.tombstones = tombstones
    }
}

public enum BooknoReceiptStatus: String, Codable, Sendable {
    case applied, unchanged, staleRevision, revisionContentMismatch, baseRevisionMismatch
    case localEditDiverged, missingParent, blockedDependency, deletionPreviewOnly
}
public struct BooknoReceiptItem: Codable, Sendable, Equatable {
    public let externalID: String
    public let revision: Int
    public let contentHash: String
    public let status: BooknoReceiptStatus
    public init(externalID: String, revision: Int, contentHash: String, status: BooknoReceiptStatus) {
        self.externalID = externalID; self.revision = revision; self.contentHash = contentHash; self.status = status
    }
}
public struct BooknoMockReceipt: Codable, Sendable, Equatable {
    public let receiverID: UUID
    public let batchID: UUID
    public let batchHash: String
    public let cursor: BooknoCursor
    public let items: [BooknoReceiptItem]
    public let verifiedAssetIDs: [String]
    public let deletionPreviewIDs: [String]
    public init(receiverID: UUID, batchID: UUID, batchHash: String, cursor: BooknoCursor,
                items: [BooknoReceiptItem], verifiedAssetIDs: [String], deletionPreviewIDs: [String]) {
        self.receiverID = receiverID; self.batchID = batchID; self.batchHash = batchHash; self.cursor = cursor
        self.items = items; self.verifiedAssetIDs = verifiedAssetIDs; self.deletionPreviewIDs = deletionPreviewIDs
    }
}
public enum BooknoPreviewError: Error, Sendable, Equatable {
    case disabled, invalidContract, sourceMismatch, assetInvalid, assetMissing
    case batchContentMismatch, receiptMismatch, mockResultUnknown, revisionOverflow, selectionLimit
}
