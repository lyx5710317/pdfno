// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// First slice translates exactly one spine resource, not a logical TOC subsection.
public enum EPUBChapterTranslationPolicy {
    public static let maxChapterUTF16 = 3000
    public static let maxSegments = 6
    public static let maxSessionRequests = 6
    public static let promptVersion = "deepseek-epub-chapter-1"
}
public enum EPUBChapterTranslationFailure: LocalizedError, Sendable {
    case noText, chapterLimit, segmentLimit, invalidSource, budget
    public var errorDescription: String? {
        switch self {
        case .noText: "当前 spine 文档没有可提取正文；不上传图片或执行 OCR。"
        case .chapterLimit: "完整 spine 文档超过 3000 UTF-16 单位；已拒绝整章发送，不会静默截断。请关闭并在原文选择较小范围，使用选文 AI。"
        case .segmentLimit: "完整文档需要超过 6 个分段，或含无法安全分割的字符；已拒绝整章发送。请改用选文 AI。"
        case .invalidSource: "章节完整范围或来源无法验证；请重新打开原文。"
        case .budget: "剩余章节请求额度不足以覆盖全部分段，或另一个章节批次正在发送；本次不会发送任何分段。每次应用会话最多 6 次，失败和取消也计入，无自动重试。"
        }
    }
}
/// Canonical text from the existing Kookit document (rt/rp excluded).
/// Includes the source title when Kookit relocates it into the body; no extraction-version change.
/// An oversized resource carries its true count and no text, never a truncated excerpt.
public struct EPUBChapterTextSnapshot: Sendable, Equatable {
    public let bookID: UUID
    public let readerSessionID: UUID
    public let documentVersion: Int
    public let editionID: UUID
    public let fileSHA256: String
    public let resourceHref: String
    public let spineIndex: Int
    public let chapterCount: Int
    public let utf16Count: Int
    public let text: String?
    public let vertical: Bool
    public init(bookID: UUID, readerSessionID: UUID, documentVersion: Int, editionID: UUID, fileSHA256: String,
                resourceHref: String, spineIndex: Int, chapterCount: Int, utf16Count: Int, text: String?, vertical: Bool) {
        self.bookID = bookID; self.readerSessionID = readerSessionID; self.documentVersion = documentVersion
        self.editionID = editionID; self.fileSHA256 = fileSHA256; self.resourceHref = resourceHref
        self.spineIndex = spineIndex; self.chapterCount = chapterCount; self.utf16Count = utf16Count
        self.text = text; self.vertical = vertical
    }
    public var hasValidMetadata: Bool {
        documentVersion >= 0 && (1...1000).contains(chapterCount) && (0..<chapterCount).contains(spineIndex) &&
        (0...4 * 1024 * 1024).contains(utf16Count) && EPUBArchive.isSafePath(resourceHref) &&
        fileSHA256.count == 64 && fileSHA256.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
    public var scopeLabel: String {
        "spine 文档 \(spineIndex + 1) / \(chapterCount) · \(resourceHref) · 完整原文 UTF-16 0–\(utf16Count) · \(utf16Count) UTF-16 单位"
    }
}
public struct EPUBChapterTranslationPlan: Sendable, Equatable {
    public let snapshot: EPUBChapterTextSnapshot
    public let sources: [AISourceSnapshot]
    public init(snapshot: EPUBChapterTextSnapshot) throws {
        guard snapshot.hasValidMetadata else { throw EPUBChapterTranslationFailure.invalidSource }
        guard snapshot.utf16Count <= EPUBChapterTranslationPolicy.maxChapterUTF16 else { throw EPUBChapterTranslationFailure.chapterLimit }
        guard let text = snapshot.text, text.utf16.count == snapshot.utf16Count else { throw EPUBChapterTranslationFailure.invalidSource }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw EPUBChapterTranslationFailure.noText }
        // Greedy Character boundaries keep the complete text inside six requests whenever possible.
        // No trimming, Unicode normalisation, or inferred paragraph separators.
        var cursor = text.startIndex, offset = 0, sources: [AISourceSnapshot] = []
        let units = Array(text.utf16)
        var boundaries = [0], position = 0
        for character in text { position += String(character).utf16.count; boundaries.append(position) }
        while cursor < text.endIndex {
            var end = cursor, length = 0
            while end < text.endIndex {
                let size = String(text[end]).utf16.count
                guard length + size <= DeepSeekSelectionPolicy.maxSourceUTF16 else { break }
                length += size; end = text.index(after: end)
            }
            guard end > cursor else { throw EPUBChapterTranslationFailure.segmentLimit }
            let finish = offset + length
            let before = boundaries.first(where: { $0 >= max(0, offset - 64) }) ?? offset
            let after = boundaries.last(where: { $0 <= min(units.count, finish + 64) }) ?? finish
            let anchor = EPUBAnchor(editionID: snapshot.editionID, fileSHA256: snapshot.fileSHA256,
                resourceHref: snapshot.resourceHref, spineIndex: snapshot.spineIndex, start: offset, end: finish,
                quote: String(text[cursor..<end]), prefix: String(decoding: units[before..<offset], as: UTF16.self),
                suffix: String(decoding: units[finish..<after], as: UTF16.self), vertical: snapshot.vertical)
            let source = AISourceSnapshot(bookID: snapshot.bookID, readerSessionID: snapshot.readerSessionID,
                documentVersion: snapshot.documentVersion, anchor: .epubChapter(anchor))
            guard source.isValid else { throw EPUBChapterTranslationFailure.invalidSource }
            sources.append(source)
            guard sources.count <= EPUBChapterTranslationPolicy.maxSegments else { throw EPUBChapterTranslationFailure.segmentLimit }
            cursor = end; offset = finish
        }
        guard sources.map({ $0.anchor.quote }).joined().unicodeScalars.elementsEqual(text.unicodeScalars) else { throw EPUBChapterTranslationFailure.invalidSource }
        self.snapshot = snapshot; self.sources = sources
    }
    public var maxOutputTokens: Int { sources.count * DeepSeekSelectionPolicy.maxOutputTokens }
    public var maxDurationSeconds: Int { sources.count * 30 }
}
