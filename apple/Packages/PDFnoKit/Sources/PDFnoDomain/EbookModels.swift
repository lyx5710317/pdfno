// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum EbookFormat: String, Codable, CaseIterable, Hashable, Sendable { case mobi, azw, azw3, fb2 }
public enum EbookContentKind: String, Codable, Sendable { case mobi6, kf8, fb2 }
public enum EbookError: LocalizedError {
    case invalidDocument, resourceLimit, invalidStore, sourceMismatch, unsupportedContent, drm, bridge, cancelled
    public var errorDescription: String? {
        switch self {
        case .invalidDocument: "电子书结构无效或格式与原始字节不符。"
        case .resourceLimit: "电子书超过限额：8 MiB 原件、1000 条记录/章节、4 MiB 解压正文、10000 段落。"
        case .invalidStore: "电子书书库无法验证；现有数据不会被覆盖。"
        case .sourceMismatch: "电子书原件或原文锚点无法精确恢复。"
        case .unsupportedContent: "当前支持无 DRM MOBI6/KF8 与 UTF-8 FB2；HUFF/CDIC、混合格式、字体与图片暂不支持。"
        case .drm: "加密或 DRM 电子书不支持；不会解除保护。"
        case .bridge: "电子书阅读失败或超时，请重新打开。"
        case .cancelled: "电子书请求已取消。"
        }
    }
}

public struct EbookRun: Codable, Sendable, Equatable {
    public let text: String
    public let bold: Bool
    public let italic: Bool
    public let ruby: String?
    public init(_ text: String, bold: Bool = false, italic: Bool = false, ruby: String? = nil) {
        self.text = text; self.bold = bold; self.italic = italic; self.ruby = ruby
    }
}
public struct EbookBlock: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let runs: [EbookRun]
    public let headingLevel: Int?
    public let listLevel: Int?
    public let table: Int?
    public let row: Int?
    public let cell: Int?
    public let start: Int
    public let section: Int
    public var text: String { runs.map(\.text).joined() }
    public var end: Int { start + text.utf16.count }
    public init(id: Int, runs: [EbookRun], headingLevel: Int? = nil, listLevel: Int? = nil,
                table: Int? = nil, row: Int? = nil, cell: Int? = nil, start: Int, section: Int = 0) {
        self.id = id; self.runs = runs; self.headingLevel = headingLevel; self.listLevel = listLevel
        self.table = table; self.row = row; self.cell = cell; self.start = start; self.section = section
    }
}
public struct EbookDocument: Codable, Sendable, Equatable {
    public static let extractionVersion = "ebook-kookit-utf16-1"
    public let blocks: [EbookBlock]
    public let warnings: [String]
    public let text: String
    public var outline: [EbookBlock] { blocks.filter { $0.headingLevel != nil && !$0.text.isEmpty } }
    public var navigationBlocks: [EbookBlock] {
        let titled = Set(outline.map(\.section)); var seen = Set<Int>()
        return blocks.filter { $0.headingLevel != nil || (!titled.contains($0.section) && seen.insert($0.section).inserted) }
    }
    public init(blocks: [EbookBlock], warnings: [String] = []) {
        self.blocks = blocks; self.warnings = warnings; text = blocks.map(\.text).joined(separator: "\n")
    }
    private enum CodingKeys: String, CodingKey { case blocks, warnings }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(blocks: try values.decode([EbookBlock].self, forKey: .blocks), warnings: try values.decode([String].self, forKey: .warnings))
        guard isValid else { throw EbookError.bridge }
    }
    public var isValid: Bool {
        guard !blocks.isEmpty, blocks.count <= 10000, text.utf16.count <= 1_000_000,
              warnings.count <= 100, warnings.allSatisfy({ $0.utf16.count <= 1024 }) else { return false }
        var offset = 0, runs = 0
        for (id, block) in blocks.enumerated() {
            guard block.id == id, block.start == offset, block.runs.count <= 10000 && (0..<1000).contains(block.section),
                  block.headingLevel == nil || (1...6).contains(block.headingLevel!),
                  block.listLevel == nil || (0...8).contains(block.listLevel!),
                  block.table == nil || (0..<10000).contains(block.table!),
                  block.row == nil || (0..<10000).contains(block.row!),
                  block.cell == nil || (0..<10000).contains(block.cell!) else { return false }
            runs += block.runs.count
            guard block.runs.allSatisfy({ ($0.ruby?.utf16.count ?? 0) <= 1024 }), runs <= 100000 else { return false }
            offset += block.text.utf16.count + 1
        }
        return blocks.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    /// Scalar-exact offsets; canonical equivalence and split surrogate pairs do not count as a match.
    public func resolves(_ anchor: EbookAnchor) -> Bool {
        guard anchor.isValid, blocks.contains(where: { $0.id == anchor.blockID && $0.section == anchor.section && $0.start <= anchor.start && anchor.start < $0.end }),
              let quote = Self.slice(text, start: anchor.start, end: anchor.end),
              let prefix = Self.slice(text, start: max(0, anchor.start - 64), end: anchor.start, repairBoundary: true),
              let suffix = Self.slice(text, start: anchor.end, end: min(text.utf16.count, anchor.end + 64), repairBoundary: true)
        else { return false }
        return quote.utf16.elementsEqual(anchor.quote.utf16) && prefix.utf16.elementsEqual(anchor.prefix.utf16) && suffix.utf16.elementsEqual(anchor.suffix.utf16)
    }
    public func anchor(book: EbookBook, start: Int, end: Int) -> EbookAnchor? {
        guard let block = blocks.first(where: { $0.start <= start && start < $0.end }),
              let quote = Self.slice(text, start: start, end: end), !quote.isEmpty, quote.utf16.count <= 16000,
              let prefix = Self.slice(text, start: max(0, start - 64), end: start, repairBoundary: true),
              let suffix = Self.slice(text, start: end, end: min(text.utf16.count, end + 64), repairBoundary: true) else { return nil }
        return EbookAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, format: book.format, contentKind: book.contentKind, section: block.section, blockID: block.id,
                          start: start, end: end, quote: quote, prefix: prefix, suffix: suffix)
    }
    private static func slice(_ text: String, start: Int, end: Int, repairBoundary: Bool = false) -> String? {
        guard start >= 0, end >= start, end <= text.utf16.count else { return nil }
        var lower = start, upper = end
        if repairBoundary {
            if (try? UnicodeOffsets.codePointOffset(in: text, utf16Offset: lower)) == nil { lower += 1 }
            if (try? UnicodeOffsets.codePointOffset(in: text, utf16Offset: upper)) == nil { upper -= 1 }
        }
        guard lower <= upper,
              (try? UnicodeOffsets.codePointOffset(in: text, utf16Offset: lower)) != nil,
              (try? UnicodeOffsets.codePointOffset(in: text, utf16Offset: upper)) != nil else { return nil }
        return String(decoding: Array(text.utf16)[lower..<upper], as: UTF16.self)
    }
}
public struct EbookAnchor: Codable, Sendable, Equatable {
    public var schemaVersion = 1
    public var extractionVersion = EbookDocument.extractionVersion
    public let editionID: UUID
    public let fileSHA256: String
    public let format: EbookFormat
    public let contentKind: EbookContentKind
    public let section: Int
    public let blockID: Int
    public let start: Int
    public let end: Int
    public let quote: String
    public let prefix: String
    public let suffix: String
    public init(editionID: UUID, fileSHA256: String, format: EbookFormat, contentKind: EbookContentKind, section: Int, blockID: Int, start: Int, end: Int, quote: String, prefix: String, suffix: String) {
        self.editionID = editionID; self.fileSHA256 = fileSHA256; self.format = format; self.contentKind = contentKind; self.section = section; self.blockID = blockID
        self.start = start; self.end = end; self.quote = quote; self.prefix = prefix; self.suffix = suffix
    }
    public var isValid: Bool {
        schemaVersion == 1 && extractionVersion == EbookDocument.extractionVersion && EbookBook.validHash(fileSHA256) &&
        (0..<1000).contains(section) && (0..<10000).contains(blockID) && start >= 0 && end > start && end <= 1_000_000 &&
        end - start == quote.utf16.count && quote.utf16.count <= 16000 && prefix.utf16.count <= 64 && suffix.utf16.count <= 64
    }
}
public struct EbookBook: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public let format: EbookFormat
    public let contentKind: EbookContentKind
    public let title: String
    public let originalFilename: String
    public var validFormat: Bool {
        format == .fb2 ? contentKind == .fb2 : (format == .azw3 ? contentKind == .kf8 : contentKind != .fb2)
    }
    public var progress: EbookAnchor?
    public init(id: UUID = UUID(), editionID: UUID = UUID(), fileSHA256: String, format: EbookFormat, contentKind: EbookContentKind, title: String, originalFilename: String) {
        self.id = id; self.editionID = editionID; self.fileSHA256 = fileSHA256
        self.format = format; self.contentKind = contentKind; self.title = title; self.originalFilename = originalFilename
    }
    public func accepts(_ anchor: EbookAnchor) -> Bool {
        validFormat && anchor.isValid && anchor.editionID == editionID && anchor.fileSHA256 == fileSHA256 && anchor.format == format && anchor.contentKind == contentKind
    }
    public static func validHash(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
    }
}
public struct EbookNote: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let bookID: UUID
    public let anchor: EbookAnchor
    public let userText: String
    public init(id: UUID = UUID(), bookID: UUID, anchor: EbookAnchor, userText: String = "") {
        self.id = id; self.bookID = bookID; self.anchor = anchor; self.userText = userText
    }
}
