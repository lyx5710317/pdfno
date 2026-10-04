// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// The edit baseline is a saved note, never the reader's transient selection.
/// Existing manifests and note schemas remain unchanged.
public enum NoteBodySnapshot: Codable, Equatable, Sendable {
    case pdf(ReadingNote), epub(EPUBNote), learning(AILearningNote)
    public var bookID: UUID {
        switch self { case .pdf(let n): n.bookID; case .epub(let n): n.bookID; case .learning(let n): n.result.source.bookID }
    }
    public var noteID: UUID {
        switch self { case .pdf(let n): n.id; case .epub(let n): n.id; case .learning(let n): n.id }
    }
    public var key: String {
        let kind: String
        switch self { case .pdf: kind = "pdf"; case .epub: kind = "epub"; case .learning: kind = "learning" }
        return kind + ":" + bookID.uuidString + ":" + noteID.uuidString
    }
    public var userText: String {
        switch self { case .pdf(let n): n.userText; case .epub(let n): n.userText; case .learning(let n): n.userText }
    }
    public func accepts(_ text: String) -> Bool {
        // Empty and whitespace-only bodies are deliberate edits. Do not trim,
        // normalize Unicode, remove the highlight or replace AI/source text.
        switch self {
        case .pdf: text.count <= 50_000
        case .epub: text.utf8.count <= 16_000
        case .learning: text.utf16.count <= 16_000
        }
    }
    public var limitDescription: String {
        switch self {
        case .pdf: "正文上限为 50,000 个字符。"
        case .epub: "正文上限为 16,000 个 UTF-8 字节。"
        case .learning: "正文上限为 16,000 个 UTF-16 单位。"
        }
    }
}

public enum NoteBodyEditError: LocalizedError {
    case conflict, tooLong, draftStore
    public var errorDescription: String? {
        switch self {
        case .conflict: "笔记已变化；草稿保留。重新载入已保存正文后，再编辑并保存。"
        case .tooLong: "正文超过此类笔记的保存上限；草稿保留。"
        case .draftStore: "编辑草稿无法持久化；当前会话的正文保留。"
        }
    }
}
