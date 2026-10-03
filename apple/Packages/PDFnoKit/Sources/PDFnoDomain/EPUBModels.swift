// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public struct EPUBAnchor: Codable, Sendable, Equatable {
    public var schemaVersion = 1
    public var extractionVersion = "epub-canonical-utf16-1"
    public let editionID: UUID
    public let fileSHA256: String
    public let resourceHref: String
    public let spineIndex: Int
    public let start: Int
    public let end: Int
    public let quote: String
    public let prefix: String
    public let suffix: String
    public let vertical: Bool
    public init(editionID: UUID, fileSHA256: String, resourceHref: String, spineIndex: Int,
                start: Int, end: Int, quote: String, prefix: String, suffix: String, vertical: Bool) {
        self.editionID = editionID; self.fileSHA256 = fileSHA256; self.resourceHref = resourceHref
        self.spineIndex = spineIndex; self.start = start; self.end = end; self.quote = quote
        self.prefix = prefix; self.suffix = suffix; self.vertical = vertical
    }
    public var isValid: Bool {
        schemaVersion == 1 && extractionVersion == "epub-canonical-utf16-1" &&
        fileSHA256.count == 64 && fileSHA256.allSatisfy { "0123456789abcdef".contains($0) } &&
        EPUBArchive.isSafePath(resourceHref) && (0..<1000).contains(spineIndex) && start >= 0 &&
        end > start && end <= 4 * 1024 * 1024 && end - start == quote.utf16.count &&
        !quote.isEmpty && quote.utf16.count <= 16000 && prefix.utf16.count <= 64 && suffix.utf16.count <= 64
    }
}
public struct EPUBBook: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public let title: String
    public let originalFilename: String
    public var progress: EPUBAnchor?
    public init(id: UUID = UUID(), editionID: UUID = UUID(), fileSHA256: String, title: String, originalFilename: String) {
        self.id = id; self.editionID = editionID; self.fileSHA256 = fileSHA256
        self.title = title; self.originalFilename = originalFilename
    }
    public func accepts(_ anchor: EPUBAnchor) -> Bool {
        anchor.isValid && anchor.editionID == editionID && anchor.fileSHA256 == fileSHA256
    }
}
public struct EPUBNote: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let bookID: UUID
    public let anchor: EPUBAnchor
    public let userText: String
    public init(id: UUID = UUID(), bookID: UUID, anchor: EPUBAnchor, userText: String) {
        self.id = id; self.bookID = bookID; self.anchor = anchor; self.userText = userText
    }
}
public enum EPUBError: LocalizedError {
    case invalidArchive, resourceLimit, invalidStore, sourceMismatch, unavailable, bridge, cancelled
    public var errorDescription: String? {
        switch self {
        case .invalidArchive: "EPUB 归档无效、路径不安全或含当前不支持的加密/ZIP 结构。"
        case .resourceLimit: "EPUB 超出当前资源限额（20 MiB 归档、1000 条目、4 MiB 单项、50 MiB 总解压）。"
        case .invalidStore: "EPUB 书库无法验证；现有数据不会被覆盖。"
        case .sourceMismatch: "原书或引文无法精确恢复；请重新选择原文。"
        case .unavailable: "EPUB 当前仅在 Mac 开放；移动阅读适配尚未验收。"
        case .bridge: "EPUB 阅读请求失败或超时，请重新打开。"
        case .cancelled: "EPUB 请求已取消。"
        }
    }
}

/// No extraction. Check original central AND local names before JSZip can normalise them.
public enum EPUBArchive {
    public static func isSafePath(_ path: String) -> Bool {
        guard !path.isEmpty, path.utf8.count <= 1024, !path.hasPrefix("/"),
              !path.contains("\\"), !path.contains(":"), !path.contains("%"),
              !path.unicodeScalars.contains(where: { $0.value < 32 || $0.value == 127 }) else { return false }
        let parts = path.split(separator: "/", omittingEmptySubsequences: false)
        return parts.enumerated().allSatisfy { index, part in
            part != "." && part != ".." && (!part.isEmpty || index == parts.count - 1)
        }
    }
    public static func validate(_ data: Data) throws -> [String] {
        guard data.count <= 20 * 1024 * 1024 else { throw EPUBError.resourceLimit }
        let b = Array(data)
        guard b.count >= 22 else { throw EPUBError.invalidArchive }
        func u16(_ p: Int) -> Int { Int(b[p]) | Int(b[p + 1]) << 8 }
        func u32(_ p: Int) -> Int { u16(p) | u16(p + 2) << 16 }
        guard let end = stride(from: b.count - 22, through: max(0, b.count - 65557), by: -1).first(where: {
            u32($0) == 0x06054b50 && $0 + 22 + u16($0 + 20) == b.count
        }), u16(end + 4) == 0, u16(end + 6) == 0, u16(end + 8) == u16(end + 10) else { throw EPUBError.invalidArchive }
        let count = u16(end + 10), centralSize = u32(end + 12), centralStart = u32(end + 16)
        guard count > 0, count <= 1000 else { throw EPUBError.resourceLimit }
        guard centralStart >= 0, centralSize >= 0, centralStart + centralSize == end else { throw EPUBError.invalidArchive }
        var p = centralStart, total = 0, paths: [String] = [], normalised = Set<String>(), ranges: [Range<Int>] = []
        for _ in 0..<count {
            guard p + 46 <= end, u32(p) == 0x02014b50 else { throw EPUBError.invalidArchive }
            let flags = u16(p + 8), method = u16(p + 10), compressed = u32(p + 20), expanded = u32(p + 24)
            let n = u16(p + 28), extra = u16(p + 30), comment = u16(p + 32), local = u32(p + 42)
            guard p + 46 + n + extra + comment <= end, n > 0, flags & ~0x0808 == 0,
                  method == 0 || method == 8, u16(p + 34) == 0,
                  (u32(p + 38) >> 16) & 0xf000 != 0xa000,
                  let name = String(bytes: b[(p + 46)..<(p + 46 + n)], encoding: .utf8), isSafePath(name),
                  normalised.insert(name.precomposedStringWithCanonicalMapping).inserted,
                  name != "META-INF/encryption.xml", !name.lowercased().hasSuffix(".js") else { throw EPUBError.invalidArchive }
            guard expanded <= 4 * 1024 * 1024, compressed <= data.count else { throw EPUBError.resourceLimit }
            total += expanded; guard total <= 50 * 1024 * 1024 else { throw EPUBError.resourceLimit }
            guard local + 30 <= centralStart, u32(local) == 0x04034b50,
                  u16(local + 6) == flags, u16(local + 8) == method, u16(local + 26) == n else { throw EPUBError.invalidArchive }
            let payload = local + 30 + n + u16(local + 28)
            guard payload <= centralStart, payload + compressed <= centralStart,
                  Array(b[(local + 30)..<(local + 30 + n)]) == Array(b[(p + 46)..<(p + 46 + n)]),
                  flags & 8 != 0 || (u32(local + 18) == compressed && u32(local + 22) == expanded) else { throw EPUBError.invalidArchive }
            let range = local..<(payload + compressed)
            guard !ranges.contains(where: { $0.overlaps(range) }) else { throw EPUBError.invalidArchive }
            ranges.append(range)
            if name == "mimetype" {
                guard method == 0, String(bytes: b[payload..<(payload + compressed)], encoding: .utf8) == "application/epub+zip" else { throw EPUBError.invalidArchive }
            }
            paths.append(name); p += 46 + n + extra + comment
        }
        guard p == end, paths.contains("mimetype"), paths.contains("META-INF/container.xml") else { throw EPUBError.invalidArchive }
        return paths
    }
}
