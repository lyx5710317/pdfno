// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// These saved records keep their existing manifests and immutable source/result fields.
/// A separate draft journal prevents newer cases from making old editor journals unreadable.
public enum RecordBodySnapshot: SavedBodySnapshot {
    case text(TextFormatNote), ebook(EbookNote), japanese(JapaneseLearningNote)
    public static let draftFilename = "record-edit-drafts-v1.json"
    public var bookID: UUID {
        switch self { case .text(let n): n.bookID; case .ebook(let n): n.bookID; case .japanese(let n): n.review.source.bookID }
    }
    public var noteID: UUID {
        switch self { case .text(let n): n.id; case .ebook(let n): n.id; case .japanese(let n): n.id }
    }
    public var key: String {
        let kind: String
        switch self { case .text: kind = "text"; case .ebook: kind = "ebook"; case .japanese: kind = "japanese" }
        return kind + ":" + bookID.uuidString + ":" + noteID.uuidString
    }
    public var userText: String {
        switch self { case .text(let n): n.userText; case .ebook(let n): n.userText; case .japanese(let n): n.userText }
    }
    public func accepts(_ text: String) -> Bool {
        switch self { case .text, .ebook: text.utf8.count <= 16_000; case .japanese: text.utf16.count <= 16_000 }
    }
    public var limitDescription: String {
        switch self { case .text, .ebook: "正文上限为 16,000 个 UTF-8 字节。"; case .japanese: "正文上限为 16,000 个 UTF-16 单位。" }
    }
}
