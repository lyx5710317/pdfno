// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum LocalBookFormat: String, Codable, Sendable, CaseIterable { case pdf = "PDF", epub = "EPUB", docx = "DOCX", comic = "CBZ" }
/// A UUID alone cannot identify a book across the independent format stores.
public struct LocalBookIdentity: Codable, Sendable, Equatable, Hashable, Identifiable {
    public let format: LocalBookFormat
    public let bookID: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public var id: String { format.rawValue + ":" + bookID.uuidString + ":" + editionID.uuidString + ":" + fileSHA256 }
    public init(format: LocalBookFormat, bookID: UUID, editionID: UUID, fileSHA256: String) {
        self.format = format; self.bookID = bookID; self.editionID = editionID; self.fileSHA256 = fileSHA256
    }
    public var isValid: Bool {
        fileSHA256.utf8.count == 64 && fileSHA256.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) }
    }
}
/// Optional local catalog values, in a separate store. No original or note schema changes.
public struct LocalBookMetadata: Codable, Sendable, Equatable, Identifiable {
    public let book: LocalBookIdentity
    public var title: String
    public var author: String
    public var revision: Int
    public var id: String { book.id }
    public init(book: LocalBookIdentity, title: String, author: String, revision: Int = 1) {
        self.book = book; self.title = title; self.author = author; self.revision = revision
    }
    public var isValid: Bool {
        book.isValid && revision > 0 && revision < Int.max &&
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.utf8.count <= 4096 && author.utf8.count <= 4096
    }
}
public struct LibrarySearchBook: Sendable, Equatable, Identifiable {
    public let identity: LocalBookIdentity
    public let title: String
    public let author: String
    public let metadataRevision: Int
    public let sourceAvailable: Bool
    public var id: String { identity.id }
    public init(identity: LocalBookIdentity, title: String, author: String = "", metadataRevision: Int = 0, sourceAvailable: Bool = true) {
        self.identity = identity; self.title = title; self.author = author; self.metadataRevision = metadataRevision; self.sourceAvailable = sourceAvailable
    }
}
public enum LibrarySearchKind: String, Sendable { case book, note, learning }
public struct LibrarySearchTarget: Sendable, Equatable {
    public let book: LocalBookIdentity
    public let kind: LibrarySearchKind
    public let noteID: UUID?
    public init(book: LocalBookIdentity, kind: LibrarySearchKind, noteID: UUID? = nil) { self.book = book; self.kind = kind; self.noteID = noteID }
    public var id: String { book.id + ":" + kind.rawValue + ":" + (noteID?.uuidString ?? "") }
}
public struct LibrarySearchEntry: Sendable, Equatable, Identifiable {
    public let book: LibrarySearchBook
    public let target: LibrarySearchTarget
    public let userText: String
    public let quote: String
    public let generatedText: String
    public let location: String
    public var id: String { target.id }
    public init(book: LibrarySearchBook, kind: LibrarySearchKind, noteID: UUID? = nil, userText: String = "", quote: String = "", generatedText: String = "", location: String = "") {
        self.book = book; target = LibrarySearchTarget(book: book.identity, kind: kind, noteID: noteID)
        self.userText = userText; self.quote = quote; self.generatedText = generatedText; self.location = location
    }
}
public struct LibrarySearchHit: Sendable, Equatable, Identifiable {
    public let entry: LibrarySearchEntry
    public let preview: String
    public var id: String { entry.id }
    public init(entry: LibrarySearchEntry, preview: String) { self.entry = entry; self.preview = preview }
}
public struct LibrarySearchGroup: Sendable, Equatable, Identifiable {
    public let book: LibrarySearchBook
    public var hits: [LibrarySearchHit]
    public var id: String { book.id }
    public init(book: LibrarySearchBook, hits: [LibrarySearchHit]) { self.book = book; self.hits = hits }
}
public struct LibrarySearchResponse: Sendable, Equatable {
    public let books: [LibrarySearchBook]
    public let groups: [LibrarySearchGroup]
    public let totalCount: Int
    public init(books: [LibrarySearchBook], groups: [LibrarySearchGroup], totalCount: Int) { self.books = books; self.groups = groups; self.totalCount = totalCount }
}
public enum LibrarySearchFailure: LocalizedError, Sendable {
    case store, metadataConflict, source, queryLimit
    public var errorDescription: String? {
        switch self {
        case .store: "本地书库或笔记无法验证；搜索已停止，现有文件已保留。"
        case .metadataConflict: "书目信息已改变，请刷新后再保存。"
        case .source: "来源书籍或笔记已改变，无法精确回跳；请刷新结果。旧引文已保留。"
        case .queryLimit: "搜索词过长，请缩短到 1024 UTF-16 单元以内。"
        }
    }
}
