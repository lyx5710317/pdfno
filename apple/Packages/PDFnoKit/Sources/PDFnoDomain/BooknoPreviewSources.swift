// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Exchange namespaces do not enable unsupported native cover formats.
public enum BooknoFormat: String, Codable, Sendable, CaseIterable {
    case pdf, epub, cbz, docx, txt, markdown, html
    public init(_ format: CoverFormat) {
        switch format { case .pdf: self = .pdf; case .epub: self = .epub; case .cbz: self = .cbz; case .docx: self = .docx }
    }
    public init(_ format: TextFileFormat) {
        switch format { case .txt: self = .txt; case .markdown: self = .markdown; case .html: self = .html }
    }
    public var coverFormat: CoverFormat? {
        switch self { case .pdf: .pdf; case .epub: .epub; case .cbz: .cbz; case .docx: .docx; case .txt, .markdown, .html: nil }
    }
    public var supportsNotes: Bool { self != .cbz && self != .docx }
}

/// Flat case labels keep the existing preview-v1 PDF/EPUB golden wire bytes.
/// Text has its own canonical block locator; it never masquerades as EPUB or AI.
public enum BooknoSourceAnchor: Codable, Sendable, Equatable {
    case pdf(PDFSourceAnchor), epub(EPUBAnchor), pdfPage(PDFPageTextAnchor), epubChapter(EPUBAnchor), text(TextFormatAnchor)
    public init(_ anchor: AISelectionAnchor) {
        switch anchor {
        case .pdf(let a): self = .pdf(a)
        case .epub(let a): self = .epub(a)
        case .pdfPage(let a): self = .pdfPage(a)
        case .epubChapter(let a): self = .epubChapter(a)
        }
    }
    public var nativeAIAnchor: AISelectionAnchor? {
        switch self {
        case .pdf(let a): .pdf(a)
        case .epub(let a): .epub(a)
        case .pdfPage(let a): .pdfPage(a)
        case .epubChapter(let a): .epubChapter(a)
        case .text: nil
        }
    }
    public var quote: String { if case .text(let a) = self { a.quote } else { nativeAIAnchor!.quote } }
    public var editionID: UUID { if case .text(let a) = self { a.editionID } else { nativeAIAnchor!.editionID } }
    public var fileSHA256: String { if case .text(let a) = self { a.fileSHA256 } else { nativeAIAnchor!.fileSHA256 } }
    public var isValid: Bool { if case .text(let a) = self { a.isValid } else { nativeAIAnchor!.isValid } }
}

public struct BooknoPreviewChoice: Sendable, Equatable, Identifiable {
    public let book: BooknoBookDTO
    public var id: String { book.externalID }
    public init(book: BooknoBookDTO) { self.book = book }
}

/// Explicitly selected saved content and existing cover bytes, held in memory only.
public struct BooknoPreviewMaterial: Sendable {
    public let payloads: [BooknoPayload]
    public let assets: [BooknoCoverAssetDTO]
    public let assetBytes: [String: Data]
    public let notices: [String]
    public init(payloads: [BooknoPayload], assets: [BooknoCoverAssetDTO] = [], assetBytes: [String: Data] = [:], notices: [String] = []) {
        self.payloads = payloads; self.assets = assets; self.assetBytes = assetBytes; self.notices = notices
    }
}
