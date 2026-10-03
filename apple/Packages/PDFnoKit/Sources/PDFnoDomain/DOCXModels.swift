// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum DOCXError: LocalizedError {
    case invalidArchive, resourceLimit, invalidXML, unsupportedContent, legacyDOC, invalidStore, sourceMismatch, unavailable, bridge, cancelled
    public var errorDescription: String? {
        switch self {
        case .invalidArchive: "DOCX ZIP 无效、校验失败或含不安全路径／加密／不支持的归档结构。"
        case .resourceLimit: "DOCX 超出限额：20 MiB 文件、1000 项、4 MiB 单项、50 MiB 总解压、10000 段、100万 UTF-16 字元。"
        case .invalidXML: "DOCX XML 无效或包含 DTD、实体、异常层级／编码。"
        case .unsupportedContent: "此 DOCX 包含非超链接的外部关系、宏、嵌入对象或暂不支持的内容；请在 Word 中另存为普通 DOCX。"
        case .legacyDOC: "旧版 DOC 尚未支持；请先在 Word 中另存为 DOCX。"
        case .invalidStore: "DOCX 本地书库无法验证；现有记录不会被覆盖。"
        case .sourceMismatch: "DOCX 来源或引文无法精确恢复；原笔记已保留，请重新选择。"
        case .unavailable: "DOCX 语义阅读当前仅在 Mac 开放。"
        case .bridge: "DOCX 转换／阅读失败或超时，请重新打开。"
        case .cancelled: "DOCX 阅读已取消。"
        }
    }
}
public struct DOCXRun: Codable, Sendable, Equatable {
    public let text: String
    public let bold: Bool
    public let italic: Bool
    public init(_ text: String, bold: Bool = false, italic: Bool = false) {
        self.text = text; self.bold = bold; self.italic = italic
    }
}
public struct DOCXBlock: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let runs: [DOCXRun]
    public let headingLevel: Int?
    public let listLevel: Int?
    public let table: Int?
    public let row: Int?
    public let cell: Int?
    public let start: Int
    public var text: String { runs.map(\.text).joined() }
    public var end: Int { start + text.utf16.count }
    public init(id: Int, runs: [DOCXRun], headingLevel: Int? = nil, listLevel: Int? = nil,
                table: Int? = nil, row: Int? = nil, cell: Int? = nil, start: Int) {
        self.id = id; self.runs = runs; self.headingLevel = headingLevel; self.listLevel = listLevel
        self.table = table; self.row = row; self.cell = cell; self.start = start
    }
}
public struct DOCXDocument: Codable, Sendable, Equatable {
    public static let extractionVersion = "docx-mammoth-utf16-1"
    public let blocks: [DOCXBlock]
    public let warnings: [String]
    public let text: String
    public var outline: [DOCXBlock] { blocks.filter { $0.headingLevel != nil && !$0.text.isEmpty } }
    public init(blocks: [DOCXBlock], warnings: [String] = []) {
        self.blocks = blocks; self.warnings = warnings; text = blocks.map(\.text).joined(separator: "\n")
    }
    private enum CodingKeys: String, CodingKey { case blocks, warnings }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(blocks: try values.decode([DOCXBlock].self, forKey: .blocks), warnings: try values.decode([String].self, forKey: .warnings))
        guard isValid else { throw DOCXError.bridge }
    }
    public var isValid: Bool {
        guard !blocks.isEmpty, blocks.count <= 10000, text.utf16.count <= 1_000_000,
              warnings.count <= 100, warnings.allSatisfy({ $0.utf16.count <= 1024 }) else { return false }
        var offset = 0, runs = 0
        for (id, block) in blocks.enumerated() {
            guard block.id == id, block.start == offset, block.runs.count <= 100000,
                  block.headingLevel == nil || (1...6).contains(block.headingLevel!),
                  block.listLevel == nil || (0...8).contains(block.listLevel!),
                  block.table == nil || (0..<10000).contains(block.table!),
                  block.row == nil || (0..<10000).contains(block.row!),
                  block.cell == nil || (0..<10000).contains(block.cell!) else { return false }
            runs += block.runs.count
            guard runs <= 100000 else { return false }
            offset += block.text.utf16.count + 1
        }
        return blocks.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
    /// Scalar-exact offsets; canonical equivalence and split surrogate pairs do not count as a match.
    public func resolves(_ anchor: DOCXAnchor) -> Bool {
        guard anchor.isValid, blocks.contains(where: { $0.id == anchor.blockID && $0.start <= anchor.start && anchor.start < $0.end }),
              let quote = Self.slice(text, start: anchor.start, end: anchor.end),
              let prefix = Self.slice(text, start: max(0, anchor.start - 64), end: anchor.start, repairBoundary: true),
              let suffix = Self.slice(text, start: anchor.end, end: min(text.utf16.count, anchor.end + 64), repairBoundary: true)
        else { return false }
        return quote.utf16.elementsEqual(anchor.quote.utf16) && prefix.utf16.elementsEqual(anchor.prefix.utf16) && suffix.utf16.elementsEqual(anchor.suffix.utf16)
    }
    public func anchor(book: DOCXBook, start: Int, end: Int) -> DOCXAnchor? {
        guard let block = blocks.first(where: { $0.start <= start && start < $0.end }),
              let quote = Self.slice(text, start: start, end: end), !quote.isEmpty, quote.utf16.count <= 16000,
              let prefix = Self.slice(text, start: max(0, start - 64), end: start, repairBoundary: true),
              let suffix = Self.slice(text, start: end, end: min(text.utf16.count, end + 64), repairBoundary: true) else { return nil }
        return DOCXAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, blockID: block.id,
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
public struct DOCXAnchor: Codable, Sendable, Equatable {
    public var schemaVersion = 1
    public var extractionVersion = DOCXDocument.extractionVersion
    public let editionID: UUID
    public let fileSHA256: String
    public let blockID: Int
    public let start: Int
    public let end: Int
    public let quote: String
    public let prefix: String
    public let suffix: String
    public init(editionID: UUID, fileSHA256: String, blockID: Int, start: Int, end: Int, quote: String, prefix: String, suffix: String) {
        self.editionID = editionID; self.fileSHA256 = fileSHA256; self.blockID = blockID
        self.start = start; self.end = end; self.quote = quote; self.prefix = prefix; self.suffix = suffix
    }
    public var isValid: Bool {
        schemaVersion == 1 && extractionVersion == DOCXDocument.extractionVersion && DOCXBook.validHash(fileSHA256) &&
        (0..<10000).contains(blockID) && start >= 0 && end > start && end <= 1_000_000 &&
        end - start == quote.utf16.count && quote.utf16.count <= 16000 && prefix.utf16.count <= 64 && suffix.utf16.count <= 64
    }
}
public struct DOCXBook: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public let title: String
    public let originalFilename: String
    public var progress: DOCXAnchor?
    public init(id: UUID = UUID(), editionID: UUID = UUID(), fileSHA256: String, title: String, originalFilename: String) {
        self.id = id; self.editionID = editionID; self.fileSHA256 = fileSHA256
        self.title = title; self.originalFilename = originalFilename
    }
    public func accepts(_ anchor: DOCXAnchor) -> Bool {
        anchor.isValid && anchor.editionID == editionID && anchor.fileSHA256 == fileSHA256
    }
    public static func validHash(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
    }
}
public struct DOCXNote: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let bookID: UUID
    public let anchor: DOCXAnchor
    public let userText: String
    public init(id: UUID = UUID(), bookID: UUID, anchor: DOCXAnchor, userText: String = "") {
        self.id = id; self.bookID = bookID; self.anchor = anchor; self.userText = userText
    }
}
