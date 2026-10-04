// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum CoverFormat: String, Codable, Sendable { case pdf, epub, cbz, docx }
/// Stable source identity, independent of title, progress, UI and future transport.
public struct CoverIdentity: Codable, Hashable, Sendable {
    public let bookID: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public let format: CoverFormat
    public init(bookID: UUID, editionID: UUID, fileSHA256: String, format: CoverFormat) {
        self.bookID = bookID; self.editionID = editionID; self.fileSHA256 = fileSHA256; self.format = format
    }
    public init(_ book: BookRecord) { self.init(bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256, format: .pdf) }
    public init(_ book: EPUBBook) { self.init(bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256, format: .epub) }
    public init(_ book: ComicBook) { self.init(bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256, format: .cbz) }
    public init(_ book: DOCXBook) { self.init(bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256, format: .docx) }
}
public enum CoverOrigin: String, Codable, Sendable { case pdfFirstPage, epubEmbedded, cbzFirstImage, placeholder, userImage }
/// Asset hash + dimensions + provenance/revision can be transported by a future Bookno adapter.
/// No absolute filename, bookmark, executable data, remote URL or backend identity is persisted.
public struct CoverRecord: Codable, Equatable, Sendable {
    public let identity: CoverIdentity
    public let origin: CoverOrigin
    public let resourcePath: String?
    public let imageSHA256: String?
    public let mimeType: String?
    public let byteLength: Int
    public let width: Int
    public let height: Int
    public let revision: Int
    public let updatedAt: Date
    public let extractorVersion: String
    public var userEdited: Bool { origin == .userImage }
    public init(identity: CoverIdentity, origin: CoverOrigin, resourcePath: String? = nil,
                imageSHA256: String?, byteLength: Int, width: Int, height: Int, revision: Int, updatedAt: Date = Date(), extractorVersion: String) {
        self.identity = identity; self.origin = origin; self.resourcePath = resourcePath; self.imageSHA256 = imageSHA256
        self.mimeType = imageSHA256 == nil ? nil : "image/png"; self.byteLength = byteLength
        self.width = width; self.height = height; self.revision = revision; self.updatedAt = updatedAt; self.extractorVersion = extractorVersion
    }
}
public enum CoverLimits {
    public static let inputBytes = 12 * 1024 * 1024
    public static let inputPixels = 32_000_000
    public static let inputDimension = 16_000
    public static let assetDimension = 1200
    public static let thumbnailDimension = 512
    public static let memoryBytes = 16 * 1024 * 1024
    public static let diskCacheBytes = 64 * 1024 * 1024
}
public enum CoverError: LocalizedError, Sendable {
    case invalidImage, resourceLimit, invalidStore, unsupportedSchema, sourceMismatch, invalidEPUB
    public var errorDescription: String? {
        switch self {
        case .invalidImage: "请选择可读的单帧 PNG、JPEG、HEIC 或 TIFF 图片。"
        case .resourceLimit: "封面超过限额：12 MiB、3200 万像素或单边 16000 像素。"
        case .invalidStore: "封面记录无法验证；现有数据不会被覆盖。"
        case .unsupportedSchema: "封面记录来自更新版本；请升级应用。"
        case .sourceMismatch: "封面来源与原书不一致，请重新打开书库。"
        case .invalidEPUB: "EPUB 内置封面无法读取；可选择本地图片。"
        }
    }
}
