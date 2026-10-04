// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum ComicArchiveFormat: String, Sendable, CaseIterable { case cbz, cbt, cb7, cbr }
public enum ComicDirection: String, Codable, Sendable, CaseIterable { case leftToRight, rightToLeft }
public enum ComicLayout: String, Codable, Sendable, CaseIterable { case automatic, single, double }
public enum ComicLimits {
    public static let archiveBytes = 100 * 1024 * 1024
    public static let decoderBytes = 64 * 1024 * 1024
    public static let headerBytes = 1024 * 1024
    public static let entries = 2000
    public static let entryBytes = 16 * 1024 * 1024
    public static let expandedBytes = 512 * 1024 * 1024
    public static let imagePixels = 24_000_000
    public static let totalImagePixels = 512_000_000
    public static let imageDimension = 16000
    public static let thumbnailDimension = 2400
}
public enum ComicError: LocalizedError, Sendable {
    case invalidArchive, invalidTAR, invalidNativeArchive, resourceLimit, invalidImage, noPages, invalidStore, sourceMismatch, unavailable, bridge, cancelled
    public var errorDescription: String? {
        switch self {
        case .invalidArchive: "CBZ 无效、路径不安全、校验失败或 ZIP 结构不受支持（加密、分卷、ZIP64）。"
        case .invalidTAR: "CBT 无效或 TAR 结构不受支持；仅接受未压缩 POSIX USTAR 普通文件／目录，不支持 PAX、GNU 扩展、链接、特殊文件、分卷或加密容器。"
        case .invalidNativeArchive: "CB7 / CBR 无效或结构不受支持：CB7 仅 COPY/LZMA/LZMA2、明文头、非 solid；CBR 仅 RAR4/RAR5 STORE。均不支持加密、分卷、自解压、扩展记录或其他解码路线。"
        case .resourceLimit: "漫画超出限额：100 MiB 归档、2000 条目、16 MiB 单项、512 MiB 总解压、24M 像素单图、512M 总像素；原生解码工作内存64 MiB、明文归档头1 MiB。"
        case .invalidImage: "漫画含无效或不支持的图片；当前支持静态 PNG / JPEG。"
        case .noPages: "漫画归档中没有可阅读的 PNG / JPEG 页面。"
        case .invalidStore: "漫画书库无法验证；现有数据不会被覆盖。"
        case .sourceMismatch: "漫画原文件或保存的位置已改变，无法精确恢复。"
        case .unavailable: "当前开放 Mac CBZ / CBT / 有限 CB7 / CBR 阅读；移动漫画阅读尚未开放。"
        case .bridge: "漫画阅读失败或超时，请重新打开。"
        case .cancelled: "漫画打开已取消。"
        }
    }
}
public struct ComicPage: Codable, Sendable, Equatable {
    public let path: String
    public let width: Int
    public let height: Int
    public init(path: String, width: Int, height: Int) { self.path = path; self.width = width; self.height = height }
    public var isValid: Bool {
        EPUBArchive.isSafePath(path) && ["png", "jpg", "jpeg"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) && !path.hasSuffix("/") && width > 0 && height > 0 &&
        width <= ComicLimits.imageDimension && height <= ComicLimits.imageDimension && width * height <= ComicLimits.imagePixels
    }
}
public struct ComicProgress: Codable, Sendable, Equatable {
    public var schemaVersion = 1
    public let editionID: UUID
    public let fileSHA256: String
    public let pageIndex: Int
    public let pagePath: String
    public let direction: ComicDirection
    public let layout: ComicLayout
    public init(editionID: UUID, fileSHA256: String, pageIndex: Int, pagePath: String,
                direction: ComicDirection, layout: ComicLayout) {
        self.editionID = editionID; self.fileSHA256 = fileSHA256; self.pageIndex = pageIndex
        self.pagePath = pagePath; self.direction = direction; self.layout = layout
    }
}
public struct ComicBook: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public let title: String
    public let originalFilename: String
    public let pages: [ComicPage]
    public var progress: ComicProgress?
    public var archiveFormat: ComicArchiveFormat? { ComicArchiveFormat(rawValue: URL(fileURLWithPath: originalFilename).pathExtension.lowercased()) }
    public init(id: UUID = UUID(), editionID: UUID = UUID(), fileSHA256: String, title: String,
                originalFilename: String, pages: [ComicPage]) {
        self.id = id; self.editionID = editionID; self.fileSHA256 = fileSHA256; self.title = title
        self.originalFilename = originalFilename; self.pages = pages
    }
    public func accepts(_ p: ComicProgress) -> Bool {
        p.schemaVersion == 1 && p.editionID == editionID && p.fileSHA256 == fileSHA256 &&
        pages.indices.contains(p.pageIndex) && pages[p.pageIndex].path == p.pagePath
    }
}
/// Deterministic numeric ordering, independent of machine language/locale. Full path, then spelling as a tie break.
public enum ComicPageOrder {
    public static func precedes(_ a: String, _ b: String) -> Bool {
        let x = Array(a.lowercased().utf8), y = Array(b.lowercased().utf8)
        var i = 0, j = 0
        while i < x.count && j < y.count {
            if (48...57).contains(x[i]) && (48...57).contains(y[j]) {
                let si = i, sj = j
                while i < x.count && (48...57).contains(x[i]) { i += 1 }
                while j < y.count && (48...57).contains(y[j]) { j += 1 }
                var ni = si, nj = sj
                while ni < i - 1 && x[ni] == 48 { ni += 1 }
                while nj < j - 1 && y[nj] == 48 { nj += 1 }
                if i - ni != j - nj { return i - ni < j - nj }
                let nx = Array(x[ni..<i]), ny = Array(y[nj..<j])
                if nx != ny { return nx.lexicographicallyPrecedes(ny) }
            } else {
                if x[i] != y[j] { return x[i] < y[j] }
                i += 1; j += 1
            }
        }
        if i != x.count || j != y.count { return i == x.count }
        return a.utf8.lexicographicallyPrecedes(b.utf8)
    }
}
/// Cover and landscape pages stay single. Portrait pages pair without dropping an odd final page.
public enum ComicPagination {
    public static func spread(containing index: Int, pages: [ComicPage], layout: ComicLayout, width: Double, height: Double) -> [Int] {
        guard pages.indices.contains(index) else { return [] }
        let double = layout == .double || (layout == .automatic && width >= 900 && width > height)
        guard double else { return [index] }
        var start = 0
        while start < pages.count {
            let pair = start > 0 && start + 1 < pages.count && pages[start].width < pages[start].height && pages[start + 1].width < pages[start + 1].height
            let indices = pair ? [start, start + 1] : [start]
            if indices.contains(index) { return indices }
            start += indices.count
        }
        return [index]
    }
    public static func visualOrder(_ spread: [Int], direction: ComicDirection) -> [Int] {
        direction == .rightToLeft ? spread.reversed() : spread
    }
}
