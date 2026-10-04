// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public enum LibrarySearchIndex {
    public static let resultLimit = 300
    /// Fixed locale, case folding and canonical equivalence only. Never mutate source anchors.
    public static func folded(_ value: String) -> String {
        value.precomposedStringWithCanonicalMapping.folding(options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX")).precomposedStringWithCanonicalMapping
    }
    public static func tokens(_ query: String) throws -> [String] {
        guard query.utf16.count <= 1024 else { throw LibrarySearchFailure.queryLimit }
        return folded(query).split(whereSeparator: { $0.isWhitespace }).map(String.init)
    }
    public static func matches(_ tokens: [String], fields: [String]) -> Bool {
        let normalized = fields.map(folded)
        return tokens.allSatisfy { token in normalized.contains { $0.range(of: token, options: .literal) != nil } }
    }
    public static func search(_ query: String, books: [LibrarySearchBook], entries: [LibrarySearchEntry], limit: Int = resultLimit) throws -> LibrarySearchResponse {
        try Task.checkCancellation()
        guard query.utf16.count <= 1024 else { throw LibrarySearchFailure.queryLimit }
        let tokens = try tokens(query)
        let sortedBooks = books.sorted { a, b in
            let x = folded(a.title), y = folded(b.title)
            return x == y ? a.id < b.id : x.utf8.lexicographicallyPrecedes(y.utf8)
        }
        guard !tokens.isEmpty else { return LibrarySearchResponse(books: sortedBooks, groups: [], totalCount: 0) }
        var groups: [String: LibrarySearchGroup] = [:], count = 0
        // Stable order and a global display limit; continue counting without retaining all hits.
        let sorted = entries.sorted { $0.id < $1.id }
        for entry in sorted {
            try Task.checkCancellation()
            let fields = entry.target.kind == .book ? [entry.book.title, entry.book.author] : [entry.userText, entry.quote, entry.generatedText]
            guard matches(tokens, fields: fields) else { continue }
            count += 1
            guard count <= max(0, limit) else { continue }
            let preview = fields.first(where: { field in tokens.contains { folded(field).range(of: $0, options: .literal) != nil } }) ?? fields.first ?? ""
            let hit = LibrarySearchHit(entry: entry, preview: excerpt(preview, tokens: tokens))
            if groups[entry.book.id] == nil { groups[entry.book.id] = LibrarySearchGroup(book: entry.book, hits: []) }
            groups[entry.book.id]?.hits.append(hit)
        }
        try Task.checkCancellation()
        let bookOrder = Dictionary(uniqueKeysWithValues: sortedBooks.enumerated().map { ($0.element.id, $0.offset) })
        let result = groups.values.sorted { a, b in
            let x = bookOrder[a.id] ?? Int.max, y = bookOrder[b.id] ?? Int.max
            return x == y ? a.id < b.id : x < y
        }
        return LibrarySearchResponse(books: sortedBooks, groups: result, totalCount: count)
    }
    public static func excerpt(_ text: String, tokens: [String]) -> String {
        let range = tokens.compactMap { text.range(of: $0, options: [.caseInsensitive], locale: Locale(identifier: "en_US_POSIX")) }.first
        // Foundation can find a scalar inside an emoji sequence. Align previews to Character boundaries.
        let matchStart = range.map { value in text.indices.last(where: { $0 <= value.lowerBound }) ?? text.startIndex }
        let start = matchStart.map { text.index($0, offsetBy: -40, limitedBy: text.startIndex) ?? text.startIndex } ?? text.startIndex
        let end = text.index(start, offsetBy: 180, limitedBy: text.endIndex) ?? text.endIndex
        return (start > text.startIndex ? "…" : "") + String(text[start..<end]) + (end < text.endIndex ? "…" : "")
    }
}

/// Read validated typed manifests only. No whole-book extraction, OCR, key, provider or network access.
/// Rebuild each request from current stores; never commit an incomplete/cancelled index to disk.
public actor LibrarySearchRepository {
    private let pdf: LibraryRepository
    private let epub: EPUBRepository
    private let docx: DOCXRepository
    private let comics: ComicRepository
    private let learning: AILearningRepository
    private let metadata: LocalBookMetadataRepository
    public init(root: URL) {
        pdf = LibraryRepository(root: root); epub = EPUBRepository(root: root); docx = DOCXRepository(root: root)
        comics = ComicRepository(root: root); learning = AILearningRepository(root: root); metadata = LocalBookMetadataRepository(root: root)
    }
    public func search(_ query: String) async throws -> LibrarySearchResponse {
        guard query.utf16.count <= 1024 else { throw LibrarySearchFailure.queryLimit }
        try Task.checkCancellation()
        // Actor reads are serial and bounded. New snapshots replace the whole ephemeral index.
        let p = try await pdf.load(); try Task.checkCancellation()
        let e = try await epub.load(); try Task.checkCancellation()
        let d = try await docx.load(); try Task.checkCancellation()
        let c = try await comics.load(); try Task.checkCancellation()
        let l = try await learning.load(); try Task.checkCancellation()
        let m = try await metadata.load(); try Task.checkCancellation()
        let task = Task.detached {
            try Self.build(query, pdf: p, epub: e, docx: d, comics: c, learning: l, metadata: m)
        }
        return try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
    }
    private static func build(_ query: String, pdf: LibraryState, epub: EPUBState, docx: DOCXState, comics: ComicState, learning: AILearningState, metadata: LocalBookMetadataState) throws -> LibrarySearchResponse {
        var books: [LibrarySearchBook] = [], entries: [LibrarySearchEntry] = []
        let overrides = Dictionary(uniqueKeysWithValues: metadata.records.map { ($0.id, $0) })
        func add(_ format: LocalBookFormat, _ id: UUID, _ edition: UUID, _ hash: String, _ title: String) {
            let identity = LocalBookIdentity(format: format, bookID: id, editionID: edition, fileSHA256: hash)
            let value = overrides[identity.id].flatMap { $0.book == identity ? $0 : nil }
            books.append(LibrarySearchBook(identity: identity, title: value?.title ?? title, author: value?.author ?? "", metadataRevision: value?.revision ?? 0))
        }
        for b in pdf.books { try Task.checkCancellation(); add(.pdf, b.id, b.editionID, b.fileSHA256, b.title) }
        for b in epub.books { try Task.checkCancellation(); add(.epub, b.id, b.editionID, b.fileSHA256, b.title) }
        for b in docx.books { try Task.checkCancellation(); add(.docx, b.id, b.editionID, b.fileSHA256, b.title) }
        for b in comics.books { try Task.checkCancellation(); add(LocalBookFormat(b.archiveFormat ?? .cbz), b.id, b.editionID, b.fileSHA256, b.title) }
        let catalog = Dictionary(uniqueKeysWithValues: books.map { ($0.identity.format.rawValue + ":" + $0.identity.bookID.uuidString, $0) })
        func book(_ format: LocalBookFormat, _ id: UUID) -> LibrarySearchBook? { catalog[format.rawValue + ":" + id.uuidString] }
        entries = books.map { LibrarySearchEntry(book: $0, kind: .book) }
        for n in pdf.notes {
            try Task.checkCancellation(); guard let b = book(.pdf, n.bookID) else { continue }
            entries.append(LibrarySearchEntry(book: b, kind: .note, noteID: n.id, userText: n.userText, quote: n.anchor.quote, location: "第 \((n.anchor.regions.first?.pageIndex ?? 0) + 1) 页"))
        }
        for n in epub.notes {
            try Task.checkCancellation(); guard let b = book(.epub, n.bookID) else { continue }
            entries.append(LibrarySearchEntry(book: b, kind: .note, noteID: n.id, userText: n.userText, quote: n.anchor.quote, location: "第 \(n.anchor.spineIndex + 1) 章"))
        }
        for n in docx.notes {
            try Task.checkCancellation(); guard let b = book(.docx, n.bookID) else { continue }
            entries.append(LibrarySearchEntry(book: b, kind: .note, noteID: n.id, userText: n.userText, quote: n.anchor.quote, location: "段落 \(n.anchor.blockID + 1)"))
        }
        for n in learning.notes {
            try Task.checkCancellation()
            let source = n.result.source
            let format: LocalBookFormat
            switch source.anchor { case .epub, .epubChapter: format = .epub; case .pdf, .pdfPage: format = .pdf }
            let identity = LocalBookIdentity(format: format, bookID: source.bookID, editionID: source.anchor.editionID, fileSHA256: source.anchor.fileSHA256)
            let candidate = book(format, source.bookID)
            let b = candidate?.identity == identity ? candidate! : LibrarySearchBook(identity: identity, title: "来源书籍不在书库", sourceAvailable: false)
            entries.append(LibrarySearchEntry(book: b, kind: .learning, noteID: n.id, userText: n.userText, quote: source.anchor.quote, generatedText: n.result.text, location: source.anchor.locationLabel))
        }
        return try LibrarySearchIndex.search(query, books: books, entries: entries)
    }
}
