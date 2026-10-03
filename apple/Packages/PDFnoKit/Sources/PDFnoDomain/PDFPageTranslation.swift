// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum PDFPageTranslationPolicy {
    public static let maxPageUTF16 = 3000
    public static let maxSegments = 6
    public static let maxSessionRequests = 6
    public static let promptVersion = "deepseek-pdf-page-1"
}
public enum PDFPageTranslationFailure: LocalizedError, Sendable {
    case noText, copyingRestricted, pageLimit, segmentLimit, invalidSource, budget
    public var errorDescription: String? {
        switch self {
        case .noText: "本页没有可提取文本；扫描页需要 OCR，本首片不实现 OCR，也不会上传图片。"
        case .copyingRestricted: "此 PDF 不允许提取文字；无法发起当前页翻译。"
        case .pageLimit: "完整页面超过 3000 UTF-16 单位预算；本次拒绝整页翻译，不会截断后声称已译完整页面。"
        case .segmentLimit: "完整页面分段超过 6 次请求预算；本次拒绝发送。请使用选文功能处理较小范围。"
        case .invalidSource: "页面来源无法校验；请重新打开当前页。"
        case .budget: "剩余整页请求额度不足以覆盖全部分段；本次不会发送任何分段。每次应用会话最多 6 次，失败和取消也计入。"
        }
    }
}
/// A physical page text snapshot; no fabricated selection geometry or layout claims.
public struct PDFPageTextSnapshot: Sendable, Equatable {
    public let bookID: UUID
    public let readerSessionID: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public let pageIndex: Int
    public let text: String
    public init(bookID: UUID, readerSessionID: UUID, editionID: UUID, fileSHA256: String, pageIndex: Int, text: String) {
        self.bookID = bookID; self.readerSessionID = readerSessionID; self.editionID = editionID
        self.fileSHA256 = fileSHA256; self.pageIndex = pageIndex; self.text = text
    }
}
/// Offsets are UTF-16, checked at Character boundaries; the complete original page is retained locally.
public struct PDFPageTextAnchor: Codable, Sendable, Equatable {
    public let schemaVersion: Int
    public let extractionVersion: String
    public let editionID: UUID
    public let fileSHA256: String
    public let pageIndex: Int
    public let pageText: String
    public let start: Int
    public let end: Int
    public let quote: String
    public init(snapshot: PDFPageTextSnapshot, start: Int, end: Int, quote: String) {
        schemaVersion = 1; extractionVersion = "pdfkit-page-text-1"
        editionID = snapshot.editionID; fileSHA256 = snapshot.fileSHA256; pageIndex = snapshot.pageIndex
        pageText = snapshot.text; self.start = start; self.end = end; self.quote = quote
    }
    public var isValid: Bool {
        guard schemaVersion == 1, extractionVersion == "pdfkit-page-text-1", pageIndex >= 0,
              fileSHA256.count == 64, fileSHA256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              pageText.utf16.count <= PDFPageTranslationPolicy.maxPageUTF16,
              start >= 0, end > start, end <= pageText.utf16.count,
              quote.utf16.count == end - start, quote.utf16.count <= DeepSeekSelectionPolicy.maxSourceUTF16 else { return false }
        var offsets = Set([0]), count = 0
        for character in pageText { count += String(character).utf16.count; offsets.insert(count) }
        guard offsets.contains(start), offsets.contains(end) else { return false }
        let actual = String(decoding: Array(pageText.utf16)[start..<end], as: UTF16.self)
        return actual.unicodeScalars.elementsEqual(quote.unicodeScalars)
    }
}
public struct PDFPageTranslationPlan: Sendable, Equatable {
    public let snapshot: PDFPageTextSnapshot
    public let sources: [AISourceSnapshot]
    public init(snapshot: PDFPageTextSnapshot) throws {
        guard snapshot.pageIndex >= 0 else { throw PDFPageTranslationFailure.invalidSource }
        guard !snapshot.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PDFPageTranslationFailure.noText }
        guard snapshot.text.utf16.count <= PDFPageTranslationPolicy.maxPageUTF16 else { throw PDFPageTranslationFailure.pageLimit }
        let text = snapshot.text
        var cursor = text.startIndex, offset = 0, sources: [AISourceSnapshot] = []
        while cursor < text.endIndex {
            var end = cursor, units = 0
            var preferred: String.Index?, preferredUnits = 0
            while end < text.endIndex {
                let character = text[end], size = String(character).utf16.count
                guard units + size <= DeepSeekSelectionPolicy.maxSourceUTF16 else { break }
                units += size; end = text.index(after: end)
                if character.isWhitespace || ".!?。！？".contains(character) { preferred = end; preferredUnits = units }
            }
            guard end > cursor else { throw PDFPageTranslationFailure.segmentLimit } // A huge grapheme cannot be split safely.
            if end < text.endIndex, let preferred, preferredUnits >= DeepSeekSelectionPolicy.maxSourceUTF16 / 2 {
                end = preferred; units = preferredUnits
            }
            let anchor = PDFPageTextAnchor(snapshot: snapshot, start: offset, end: offset + units, quote: String(text[cursor..<end]))
            guard anchor.isValid else { throw PDFPageTranslationFailure.invalidSource }
            sources.append(AISourceSnapshot(bookID: snapshot.bookID, readerSessionID: snapshot.readerSessionID, documentVersion: 0, anchor: .pdfPage(anchor)))
            guard sources.count <= PDFPageTranslationPolicy.maxSegments else { throw PDFPageTranslationFailure.segmentLimit }
            cursor = end; offset += units
        }
        guard sources.map({ $0.anchor.quote }).joined().unicodeScalars.elementsEqual(text.unicodeScalars) else { throw PDFPageTranslationFailure.invalidSource }
        self.snapshot = snapshot; self.sources = sources
    }
    public var maxOutputTokens: Int { sources.count * DeepSeekSelectionPolicy.maxOutputTokens }
    public var maxDurationSeconds: Int { sources.count * 30 }
}
