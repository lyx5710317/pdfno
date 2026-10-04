// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum TextFormatError: LocalizedError {
    case resourceLimit, unsupportedContent, encoding, invalidStore, sourceMismatch, unavailable, bridge, cancelled
    public var errorDescription: String? {
        switch self {
        case .resourceLimit: "文本超出限额：4 MiB 原文件、100万 UTF-16 字元、10000 段、10万节点、64 层结构。"
        case .unsupportedContent: "此文件不属于 TXT／Markdown／HTML 首片，或包含不支持的二进制／声明。XML 与 MHTML 尚未支持。"
        case .encoding: "无法可靠解码。请另存为 UTF-8，或带 BOM 的 UTF-16；不会用替换字元猜测编码。HTML 编码声明必须与实际编码一致。"
        case .invalidStore: "文本格式本地书库无法验证；现有记录不会被覆盖。"
        case .sourceMismatch: "文本来源、版本或引文无法精确恢复；原笔记已保留，请重新选择。"
        case .unavailable: "TXT／Markdown／HTML 阅读当前仅在 Mac 开放。"
        case .bridge: "文本转换／阅读失败或超时，请重新打开；此文件可能超出显示结构限制。"
        case .cancelled: "文本阅读已取消。"
        }
    }
}
public enum TextFileFormat: String, Codable, Sendable, CaseIterable {
    case txt, markdown, html
    public var label: String { switch self { case .txt: "TXT"; case .markdown: "Markdown"; case .html: "HTML" } }
    public static func from(filename: String) -> Self? {
        switch URL(fileURLWithPath: filename).pathExtension.lowercased() {
        case "txt": .txt
        case "md", "markdown": .markdown
        case "html", "htm": .html
        default: nil
        }
    }
}
public struct TextFormatRun: Codable, Sendable, Equatable {
    public let text: String
    public let bold: Bool
    public let italic: Bool
    public init(_ text: String, bold: Bool = false, italic: Bool = false) {
        self.text = text; self.bold = bold; self.italic = italic
    }
}
public struct TextFormatBlock: Codable, Sendable, Equatable, Identifiable {
    public let id: Int
    public let runs: [TextFormatRun]
    public let headingLevel: Int?
    public let listLevel: Int?
    public let table: Int?
    public let row: Int?
    public let cell: Int?
    public let start: Int
    public var text: String { runs.map(\.text).joined() }
    public var end: Int { start + text.utf16.count }
    public init(id: Int, runs: [TextFormatRun], headingLevel: Int? = nil, listLevel: Int? = nil,
                table: Int? = nil, row: Int? = nil, cell: Int? = nil, start: Int) {
        self.id = id; self.runs = runs; self.headingLevel = headingLevel; self.listLevel = listLevel
        self.table = table; self.row = row; self.cell = cell; self.start = start
    }
}
public struct TextFormatDocument: Codable, Sendable, Equatable {
    public static let extractionVersion = "kookit-text-marked15-utf16-1"
    public let blocks: [TextFormatBlock]
    public let warnings: [String]
    public let text: String
    public var outline: [TextFormatBlock] { blocks.filter { $0.headingLevel != nil && !$0.text.isEmpty } }
    public init(blocks: [TextFormatBlock], warnings: [String] = []) {
        self.blocks = blocks; self.warnings = warnings; text = blocks.map(\.text).joined(separator: "\n")
    }
    private enum CodingKeys: String, CodingKey { case blocks, warnings }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(blocks: try values.decode([TextFormatBlock].self, forKey: .blocks), warnings: try values.decode([String].self, forKey: .warnings))
        guard isValid else { throw TextFormatError.bridge }
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
    public func resolves(_ anchor: TextFormatAnchor) -> Bool {
        guard anchor.isValid, blocks.contains(where: { $0.id == anchor.blockID && $0.start <= anchor.start && anchor.start < $0.end }),
              let quote = Self.slice(text, start: anchor.start, end: anchor.end),
              let prefix = Self.slice(text, start: max(0, anchor.start - 64), end: anchor.start, repairBoundary: true),
              let suffix = Self.slice(text, start: anchor.end, end: min(text.utf16.count, anchor.end + 64), repairBoundary: true)
        else { return false }
        return quote.utf16.elementsEqual(anchor.quote.utf16) && prefix.utf16.elementsEqual(anchor.prefix.utf16) && suffix.utf16.elementsEqual(anchor.suffix.utf16)
    }
    public func anchor(book: TextFormatBook, start: Int, end: Int) -> TextFormatAnchor? {
        guard let block = blocks.first(where: { $0.start <= start && start < $0.end }),
              let quote = Self.slice(text, start: start, end: end), !quote.isEmpty, quote.utf16.count <= 16000,
              let prefix = Self.slice(text, start: max(0, start - 64), end: start, repairBoundary: true),
              let suffix = Self.slice(text, start: end, end: min(text.utf16.count, end + 64), repairBoundary: true) else { return nil }
        return TextFormatAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, blockID: block.id,
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
public struct TextFormatAnchor: Codable, Sendable, Equatable {
    public var schemaVersion = 1
    public var extractionVersion = TextFormatDocument.extractionVersion
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
        schemaVersion == 1 && extractionVersion == TextFormatDocument.extractionVersion && TextFormatBook.validHash(fileSHA256) &&
        (0..<10000).contains(blockID) && start >= 0 && end > start && end <= 1_000_000 &&
        end - start == quote.utf16.count && quote.utf16.count <= 16000 && prefix.utf16.count <= 64 && suffix.utf16.count <= 64
    }
}
public struct TextFormatBook: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public let title: String
    public let originalFilename: String
    public let format: TextFileFormat
    public var progress: TextFormatAnchor?
    public init(id: UUID = UUID(), editionID: UUID = UUID(), fileSHA256: String, title: String, originalFilename: String, format: TextFileFormat) {
        self.id = id; self.editionID = editionID; self.fileSHA256 = fileSHA256
        self.title = title; self.originalFilename = originalFilename; self.format = format
    }
    public func accepts(_ anchor: TextFormatAnchor) -> Bool {
        anchor.isValid && anchor.editionID == editionID && anchor.fileSHA256 == fileSHA256
    }
    public static func validHash(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { "0123456789abcdef".contains($0) }
    }
}
public struct TextFormatNote: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let bookID: UUID
    public let anchor: TextFormatAnchor
    public let userText: String
    public init(id: UUID = UUID(), bookID: UUID, anchor: TextFormatAnchor, userText: String = "") {
        self.id = id; self.bookID = bookID; self.anchor = anchor; self.userText = userText
    }
}
