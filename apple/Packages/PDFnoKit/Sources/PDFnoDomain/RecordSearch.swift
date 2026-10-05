// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Local namespaces only; these values enable no cover, conversion or exchange capability.
public enum RecordSourceFormat: Codable, Sendable, Equatable {
    case pdf, epub, text(TextFileFormat), ebook(EbookFormat)
    public var label: String {
        switch self { case .pdf: "PDF"; case .epub: "EPUB"; case .text(let f): f.label; case .ebook(let f): f.rawValue.uppercased() }
    }
    public var namespace: String {
        switch self { case .pdf: "pdf"; case .epub: "epub"; case .text(let f): "text:" + f.rawValue; case .ebook(let f): "ebook:" + f.rawValue }
    }
}
public struct RecordBookIdentity: Sendable, Equatable, Identifiable {
    public let format: RecordSourceFormat
    public let bookID: UUID
    public let editionID: UUID
    public let fileSHA256: String
    public var id: String { format.namespace + ":" + bookID.uuidString + ":" + editionID.uuidString + ":" + fileSHA256 }
    public init(format: RecordSourceFormat, bookID: UUID, editionID: UUID, fileSHA256: String) {
        self.format = format; self.bookID = bookID; self.editionID = editionID; self.fileSHA256 = fileSHA256
    }
}
public enum RecordSearchKind: String, Sendable { case book, note, japanese, english }
public struct RecordSearchTarget: Sendable, Equatable, Identifiable {
    public let book: RecordBookIdentity
    public let kind: RecordSearchKind
    public let noteID: UUID?
    public var id: String { book.id + ":" + kind.rawValue + ":" + (noteID?.uuidString ?? "") }
    public init(book: RecordBookIdentity, kind: RecordSearchKind, noteID: UUID? = nil) {
        self.book = book; self.kind = kind; self.noteID = noteID
    }
}
public struct RecordSearchEntry: Sendable, Equatable, Identifiable {
    public let target: RecordSearchTarget
    public let title: String
    public let userText: String
    public let quote: String
    /// Stored suggestions and user reading corrections are independent of both quote and body.
    public let generatedText: String
    public let correctionsText: String
    public let location: String
    public let sourceAvailable: Bool
    public var id: String { target.id }
    public init(target: RecordSearchTarget, title: String, userText: String = "", quote: String = "",
                generatedText: String = "", correctionsText: String = "", location: String = "", sourceAvailable: Bool = true) {
        self.target = target; self.title = title; self.userText = userText; self.quote = quote
        self.generatedText = generatedText; self.correctionsText = correctionsText; self.location = location; self.sourceAvailable = sourceAvailable
    }
    public var fields: [String] {
        target.kind == .book ? [title] : [userText, quote, generatedText, correctionsText]
    }
}
public struct RecordSearchHit: Sendable, Equatable, Identifiable {
    public let entry: RecordSearchEntry
    public let preview: String
    public var id: String { entry.id }
    public init(entry: RecordSearchEntry, preview: String) { self.entry = entry; self.preview = preview }
}
public protocol SavedSearchResponse: Sendable, Equatable {
    static var emptySearchResponse: Self { get }
    static var loadsCatalogForEmptyQuery: Bool { get }
}
public struct RecordSearchResponse: SavedSearchResponse {
    public static let loadsCatalogForEmptyQuery = false
    public static var emptySearchResponse: Self { Self() }
    public let hits: [RecordSearchHit]
    public let totalCount: Int
    public init(hits: [RecordSearchHit] = [], totalCount: Int = 0) { self.hits = hits; self.totalCount = totalCount }
}
public enum ResolvedRecordSearchSource: Sendable {
    case text(TextFormatBook, TextFormatAnchor?), ebook(EbookBook, EbookAnchor?), japanese(AISourceSnapshot), english(AISourceSnapshot)
}
/// The integration UI can group each typed result by its original identity without inventing format aliases.
public struct SavedRecordSearchResponse: SavedSearchResponse {
    public static let loadsCatalogForEmptyQuery = true
    public static var emptySearchResponse: Self {
        Self(legacy: LibrarySearchResponse(books: [], groups: [], totalCount: 0), records: RecordSearchResponse())
    }
    public let legacy: LibrarySearchResponse
    public let records: RecordSearchResponse
    public var totalCount: Int { legacy.totalCount + records.totalCount }
    public init(legacy: LibrarySearchResponse, records: RecordSearchResponse) { self.legacy = legacy; self.records = records }
}
