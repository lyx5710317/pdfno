// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public struct BookRecord: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let editionID: UUID
    public var title: String
    public let fileSHA256: String
    public let originalFilename: String
    public let pageCount: Int
    public let importedAt: Date
    public var lastPageIndex: Int
    public init(id: UUID = UUID(), editionID: UUID = UUID(), title: String, fileSHA256: String,
                originalFilename: String, pageCount: Int, importedAt: Date = Date(), lastPageIndex: Int = 0) {
        self.id = id; self.editionID = editionID; self.title = title; self.fileSHA256 = fileSHA256
        self.originalFilename = originalFilename; self.pageCount = pageCount
        self.importedAt = importedAt; self.lastPageIndex = lastPageIndex
    }
}

public struct PageRegion: Codable, Sendable, Equatable {
    public let pageIndex: Int
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let quote: String
    public init(pageIndex: Int, x: Double, y: Double, width: Double, height: Double, quote: String) {
        self.pageIndex = pageIndex; self.x = x; self.y = y; self.width = width; self.height = height
        self.quote = quote
    }
}

public struct PDFSourceAnchor: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let editionID: UUID
    public let fileSHA256: String
    public let quote: String
    public let regions: [PageRegion] // PDF user-space, one region per selected line/page
    public let extractionVersion: String
    public init(editionID: UUID, fileSHA256: String, quote: String, regions: [PageRegion]) {
        schemaVersion = 1; self.editionID = editionID; self.fileSHA256 = fileSHA256
        self.quote = quote; self.regions = regions; extractionVersion = "pdfkit-selection-1"
    }
}

public struct ReadingNote: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let bookID: UUID
    public let anchor: PDFSourceAnchor
    public var userText: String
    public var revision: Int // local-store only; not a cloud/global revision
    public let createdAt: Date
    public var updatedAt: Date
    public init(id: UUID = UUID(), bookID: UUID, anchor: PDFSourceAnchor, userText: String = "",
                revision: Int = 1, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id; self.bookID = bookID; self.anchor = anchor; self.userText = userText
        self.revision = revision; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public enum AnchorResolution: String, Sendable { case exact, needsRebind, sourceMissing }

public struct ReaderCapability: Sendable, Equatable {
    public let available: Bool
    public let reason: String?
    public init(available: Bool, reason: String? = nil) { self.available = available; self.reason = reason }
}

/// Legacy minimal locator value. The current canonical EPUB anchor is EPUBAnchor.
public struct EPUBLocator: Codable, Sendable, Equatable {
    public let resourceHref: String
    public let spineIndex: Int
    public let validatedCFI: String?
    public let quote: String
}
public enum FeatureAvailability {
    #if os(macOS)
    public static let epub = ReaderCapability(available: true, reason: "Mac 重排 EPUB 切片；完整资源覆盖待验收")
    #else
    public static let epub = ReaderCapability(available: false, reason: "移动 EPUB 阅读尚未验收")
    #endif
    #if os(macOS)
    public static let ai = ReaderCapability(available: true, reason: "仅本地 mock 选文闭环／配置预览；真实远程请求未启用")
    #else
    public static let ai = ReaderCapability(available: false, reason: "移动选文 AI 尚未适配")
    #endif
    public static let cloud = ReaderCapability(available: false, reason: "iCloud 容器未配置")
    public static let bookno = ReaderCapability(available: false, reason: "Bookno API 尚未接入")
    public static let conversion = ReaderCapability(available: false, reason: "格式转换尚未实现")
}
