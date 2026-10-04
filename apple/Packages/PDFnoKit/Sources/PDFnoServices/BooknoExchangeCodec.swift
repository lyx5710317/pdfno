// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import ImageIO
import UniformTypeIdentifiers
import PDFnoDomain

public enum BooknoExchangeCodec {
    public static let maximumBatchBytes = 4 * 1024 * 1024
    public static let maximumAssetBytes = 10 * 1024 * 1024 // proposed, not a Bookno limit
    public static func canonical<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(value)
    }
    public static func hash<T: Encodable>(_ value: T) throws -> String { LibraryRepository.digest(try canonical(value)) }
    /// Diagnostic native revisions are not exchange revisions or semantic content.
    public static func contentHash(_ payload: BooknoPayload) throws -> String {
        let semantic: BooknoPayload
        switch payload {
        case .book(let b): semantic = .book(BooknoBookDTO(bookUUID: b.bookUUID, edition: b.edition, title: b.title,
            authors: b.authors, coverAssetID: b.coverAssetID, coverOrigin: b.coverOrigin))
        case .note(let n): semantic = .note(BooknoNoteDTO(noteUUID: n.noteUUID, annotationKind: n.annotationKind,
            userText: n.userText, source: n.source, aiAttachments: n.aiAttachments))
        }
        struct Content: Encodable { let version = "swift-json-verbatim-1"; let payload: BooknoPayload }
        return try hash(Content(payload: semantic))
    }
    public static func encode(_ batch: BooknoPreviewBatch) throws -> Data {
        try validate(batch); let data = try canonical(batch)
        guard data.count <= maximumBatchBytes else { throw BooknoPreviewError.invalidContract }; return data
    }
    /// A strict preview reader refuses unknown fields at every depth, including native anchors.
    /// Nothing on disk is migrated or rewritten by this function.
    public static func decode(_ data: Data) throws -> BooknoPreviewBatch {
        guard data.count <= maximumBatchBytes else { throw BooknoPreviewError.invalidContract }
        do {
            let batch = try JSONDecoder().decode(BooknoPreviewBatch.self, from: data)
            let incoming = try JSONSerialization.jsonObject(with: data)
            let recognized = try JSONSerialization.jsonObject(with: canonical(batch))
            func sameShape(_ lhs: Any, _ rhs: Any) -> Bool {
                if let a = lhs as? [String: Any], let b = rhs as? [String: Any] {
                    return Set(a.keys) == Set(b.keys) && a.allSatisfy { sameShape($0.value, b[$0.key]!) }
                }
                if let a = lhs as? [Any], let b = rhs as? [Any] {
                    return a.count == b.count && zip(a, b).allSatisfy { sameShape($0, $1) }
                }
                return !(lhs is [String: Any]) && !(rhs is [String: Any]) && !(lhs is [Any]) && !(rhs is [Any])
            }
            guard sameShape(incoming, recognized) else { throw BooknoPreviewError.invalidContract }
            try validate(batch); return batch
        } catch { throw BooknoPreviewError.invalidContract }
    }
    public static func validate(_ batch: BooknoPreviewBatch) throws {
        guard batch.protocolName == "pdfno-bookno-exchange-preview", batch.schemaVersion == 1,
              batch.canonicalizationVersion == "swift-json-verbatim-1", batch.sourceNamespace == "pdfno", batch.mode == .preview,
              batch.cursor.sequence > 0, batch.cursor.sequence < Int.max,
              batch.mutations.count <= 1000, batch.assets.count <= 1000, batch.tombstones.count <= 1000,
              Set(batch.mutations.map { $0.payload.externalID }).count == batch.mutations.count,
              Set(batch.assets.map(\.assetID)).count == batch.assets.count,
              Set(batch.tombstones.map(\.externalID)).count == batch.tombstones.count else { throw BooknoPreviewError.invalidContract }
        let ids = Set(batch.mutations.map { $0.payload.externalID })
        guard batch.tombstones.allSatisfy({ !ids.contains($0.externalID) && validExternalID($0.externalID, kind: $0.kind)
            && $0.lastKnownRevision >= 0 && $0.lastKnownRevision < Int.max }) else { throw BooknoPreviewError.invalidContract }
        for m in batch.mutations {
            guard m.baseRevision >= 0, m.revision > m.baseRevision, m.revision < Int.max,
                  LibraryRepository.isDigest(m.contentHash), try contentHash(m.payload) == m.contentHash else { throw BooknoPreviewError.invalidContract }
            try validate(m.payload)
        }
        let references = Set(batch.mutations.compactMap { if case .book(let b) = $0.payload { return b.coverAssetID }; return nil })
        guard references == Set(batch.assets.map(\.assetID)) else { throw BooknoPreviewError.assetMissing }
        for asset in batch.assets {
            try validate(asset)
        }
        // Encoding bounds in-memory callers too, not just JSON readers.
        guard try canonical(batch).count <= maximumBatchBytes else { throw BooknoPreviewError.invalidContract }
    }
    static func validExternalID(_ id: String, kind: BooknoEntityKind) -> Bool {
        let parts = id.split(separator: ":", omittingEmptySubsequences: false)
        let count = kind == .book ? 4 : 5
        guard parts.count == count, parts[0] == "pdfno", parts[1] == Substring(kind.rawValue),
              CoverFormat(rawValue: String(parts[2])) != nil, let uuid = UUID(uuidString: String(parts.last!)),
              parts.last! == Substring(uuid.uuidString.lowercased()) else { return false }
        return kind == .book || BooknoAnnotationKind(rawValue: String(parts[3])) != nil
    }
    static func validate(_ payload: BooknoPayload) throws {
        switch payload {
        case .book(let b):
            guard b.externalID == BooknoIdentity.book(b.bookUUID, format: b.edition.format),
                  LibraryRepository.isDigest(b.edition.sourceFileSHA256), !b.title.isEmpty, b.title.utf8.count <= 4096,
                  b.authors.count <= 32, b.authors.allSatisfy({ $0.utf8.count <= 4096 }),
                  b.coverSourceRevision.map({ $0 > 0 && $0 < Int.max }) ?? true,
                  b.coverAssetID.map({ $0.hasPrefix("sha256:") && LibraryRepository.isDigest(String($0.dropFirst(7))) }) ?? true,
                  (b.coverOrigin == nil ? b.coverAssetID == nil && b.coverSourceRevision == nil : b.coverSourceRevision != nil),
                  (b.coverOrigin == .placeholder ? b.coverAssetID == nil : b.coverOrigin == nil || b.coverAssetID != nil),
                  b.coverOrigin != .pdfFirstPage || b.edition.format == .pdf,
                  b.coverOrigin != .epubEmbedded || b.edition.format == .epub,
                  b.coverOrigin != .cbzFirstImage || b.edition.format == .cbz else { throw BooknoPreviewError.invalidContract }
        case .note(let n):
            guard n.externalID == BooknoIdentity.note(n.noteUUID, format: n.source.format, kind: n.annotationKind),
                  n.externalBookID == BooknoIdentity.book(n.source.bookUUID, format: n.source.format),
                  n.source.textNormalizationVersion == "native-verbatim-1", n.source.anchor.isValid,
                  n.quote.utf8.elementsEqual(n.source.anchor.quote.utf8), n.quote.utf8.count <= 200_000,
                  n.userText.utf8.count <= 200_000, n.localEditRevision.map({ $0 > 0 && $0 < Int.max }) ?? true,
                  n.aiAttachments.count <= 8, n.aiAttachments.allSatisfy({ $0.author == "ai" && !$0.promptVersion.isEmpty
                    && $0.promptVersion.utf8.count <= 128 && $0.text.utf8.count <= 200_000 }),
                  n.annotationKind == .learning || n.aiAttachments.isEmpty else { throw BooknoPreviewError.invalidContract }
            switch n.source.anchor {
            case .pdf: guard n.source.format == .pdf, n.source.offsetUnit == .pdfUserSpace else { throw BooknoPreviewError.sourceMismatch }
            case .pdfPage: guard n.source.format == .pdf, n.source.offsetUnit == .utf16CodeUnit else { throw BooknoPreviewError.sourceMismatch }
            case .epub: guard n.source.format == .epub, n.source.offsetUnit == .utf16CodeUnit else { throw BooknoPreviewError.sourceMismatch }
            }
        }
    }
    static func sourceMatches(_ note: BooknoNoteDTO, book: BooknoBookDTO) -> Bool {
        note.externalBookID == book.externalID && note.source.bookUUID == book.bookUUID &&
        note.source.format == book.edition.format && note.source.anchor.editionID == book.edition.id &&
        note.source.anchor.fileSHA256 == book.edition.sourceFileSHA256
    }
    private static func validate(_ asset: BooknoCoverAssetDTO) throws {
        guard LibraryRepository.isDigest(asset.sha256), asset.assetID == "sha256:" + asset.sha256,
              ["image/png", "image/jpeg"].contains(asset.mimeType), asset.byteLength > 0, asset.byteLength <= maximumAssetBytes,
              asset.width > 0, asset.height > 0, asset.width <= 4096, asset.height <= 4096 else { throw BooknoPreviewError.assetInvalid }
    }
    public static func validateAsset(_ bytes: Data, declaration: BooknoCoverAssetDTO) throws {
        try validate(declaration)
        guard bytes.count == declaration.byteLength, bytes.count <= maximumAssetBytes,
              LibraryRepository.digest(bytes) == declaration.sha256,
              let image = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              CGImageSourceGetCount(image) == 1, CGImageSourceGetStatus(image) == .statusComplete,
              let type = CGImageSourceGetType(image),
              (type as String) == (declaration.mimeType == "image/png" ? UTType.png.identifier : UTType.jpeg.identifier),
              let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any],
              properties[kCGImagePropertyPixelWidth] as? Int == declaration.width,
              properties[kCGImagePropertyPixelHeight] as? Int == declaration.height,
              CGImageSourceCreateImageAtIndex(image, 0, [kCGImageSourceShouldCache: false] as CFDictionary) != nil,
              CGImageSourceGetStatusAtIndex(image, 0) == .statusComplete else { throw BooknoPreviewError.assetInvalid }
    }
}

/// Pure adapter: callers provide explicitly selected saved values, never a Library path.
public enum BooknoExportAdapter {
    public static func book(_ book: LibrarySearchBook, cover: CoverRecord? = nil) throws -> (BooknoBookDTO, BooknoCoverAssetDTO?) {
        let format: CoverFormat
        switch book.identity.format { case .pdf: format = .pdf; case .epub: format = .epub; case .comic: format = .cbz; case .docx: format = .docx }
        let identity = CoverIdentity(bookID: book.identity.bookID, editionID: book.identity.editionID,
                                     fileSHA256: book.identity.fileSHA256, format: format)
        guard book.identity.isValid, cover.map({ $0.identity == identity }) ?? true else { throw BooknoPreviewError.sourceMismatch }
        let asset = try cover.flatMap { c -> BooknoCoverAssetDTO? in
            if c.origin == .placeholder {
                guard c.imageSHA256 == nil, c.byteLength == 0, c.width == 0, c.height == 0 else { throw BooknoPreviewError.assetInvalid }; return nil
            }
            guard let hash = c.imageSHA256, let mime = c.mimeType else { throw BooknoPreviewError.assetInvalid }
            return BooknoCoverAssetDTO(sha256: hash, mimeType: mime, byteLength: c.byteLength, width: c.width, height: c.height)
        }
        let dto = BooknoBookDTO(bookUUID: book.identity.bookID,
            edition: BooknoEditionDTO(id: book.identity.editionID, format: format, sourceFileSHA256: book.identity.fileSHA256),
            title: book.title, authors: book.author.isEmpty ? [] : [book.author], coverAssetID: asset?.assetID,
            coverOrigin: cover?.origin, coverSourceRevision: cover?.revision)
        try BooknoExchangeCodec.validate(.book(dto)); return (dto, asset)
    }
    public static func note(_ snapshot: NoteBodySnapshot, book: BooknoBookDTO) throws -> BooknoNoteDTO {
        let source: BooknoSourceDTO, id: UUID, body: String, revision: Int?, kind: BooknoAnnotationKind, ai: [BooknoAIAttachmentDTO]
        switch snapshot {
        case .pdf(let n): source = BooknoSourceDTO(bookUUID: n.bookID, format: .pdf, anchor: .pdf(n.anchor))
            id = n.id; body = n.userText; revision = n.revision; kind = .highlight; ai = []
        case .epub(let n): source = BooknoSourceDTO(bookUUID: n.bookID, format: .epub, anchor: .epub(n.anchor))
            id = n.id; body = n.userText; revision = nil; kind = .highlight; ai = []
        case .learning(let n):
            let format: CoverFormat
            switch n.result.source.anchor { case .pdf, .pdfPage: format = .pdf; case .epub: format = .epub }
            source = BooknoSourceDTO(bookUUID: n.result.source.bookID, format: format, anchor: n.result.source.anchor)
            id = n.id; body = n.userText; revision = nil; kind = .learning
            ai = [BooknoAIAttachmentDTO(kind: n.result.kind, text: n.result.text, promptVersion: n.result.promptVersion)]
        }
        let dto = BooknoNoteDTO(noteUUID: id, annotationKind: kind, userText: body, source: source, localEditRevision: revision, aiAttachments: ai)
        try BooknoExchangeCodec.validate(.note(dto))
        guard BooknoExchangeCodec.sourceMatches(dto, book: book) else { throw BooknoPreviewError.sourceMismatch }; return dto
    }
}
