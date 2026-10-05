// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Only saved manifests are indexed. Draft journals, live generation, originals and credentials are not read.
public actor RecordSearchRepository {
    private let text: TextFormatRepository
    private let ebook: EbookRepository
    private let japanese: JapaneseLearningRepository
    private let pdf: LibraryRepository
    private let epub: EPUBRepository
    public init(root: URL) {
        text = TextFormatRepository(root: root); ebook = EbookRepository(root: root)
        japanese = JapaneseLearningRepository(root: root); pdf = LibraryRepository(root: root); epub = EPUBRepository(root: root)
    }
    public func search(_ query: String, limit: Int = LibrarySearchIndex.resultLimit) async throws -> RecordSearchResponse {
        let tokens = try LibrarySearchIndex.tokens(query); try Task.checkCancellation()
        let t = try await text.load(); try Task.checkCancellation()
        let e = try await ebook.load(); try Task.checkCancellation()
        let j = try await japanese.load(); try Task.checkCancellation()
        let p = try await pdf.load(); try Task.checkCancellation()
        let u = try await epub.load(); try Task.checkCancellation()
        let task = Task.detached { try Self.build(tokens, text: t, ebook: e, japanese: j, pdf: p, epub: u, limit: limit) }
        return try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
    }
    private static func identity(_ b: TextFormatBook) -> RecordBookIdentity {
        RecordBookIdentity(format: .text(b.format), bookID: b.id, editionID: b.editionID, fileSHA256: b.fileSHA256)
    }
    private static func identity(_ b: EbookBook) -> RecordBookIdentity {
        RecordBookIdentity(format: .ebook(b.format), bookID: b.id, editionID: b.editionID, fileSHA256: b.fileSHA256)
    }
    private static func build(_ tokens: [String], text: TextFormatState, ebook: EbookState, japanese: JapaneseLearningState,
                              pdf: LibraryState, epub: EPUBState, limit: Int) throws -> RecordSearchResponse {
        guard !tokens.isEmpty else { return RecordSearchResponse() }
        var entries: [RecordSearchEntry] = []
        for b in text.books {
            try Task.checkCancellation()
            entries.append(RecordSearchEntry(target: RecordSearchTarget(book: identity(b), kind: .book), title: b.title))
        }
        for b in ebook.books {
            try Task.checkCancellation()
            entries.append(RecordSearchEntry(target: RecordSearchTarget(book: identity(b), kind: .book), title: b.title))
        }
        let textBooks = Dictionary(uniqueKeysWithValues: text.books.map { ($0.id, $0) })
        let ebookBooks = Dictionary(uniqueKeysWithValues: ebook.books.map { ($0.id, $0) })
        for n in text.notes {
            try Task.checkCancellation(); guard let b = textBooks[n.bookID] else { continue }
            entries.append(RecordSearchEntry(target: RecordSearchTarget(book: identity(b), kind: .note, noteID: n.id),
                title: b.title, userText: n.userText, quote: n.anchor.quote, location: "段落 \(n.anchor.blockID + 1)"))
        }
        for n in ebook.notes {
            try Task.checkCancellation(); guard let b = ebookBooks[n.bookID] else { continue }
            entries.append(RecordSearchEntry(target: RecordSearchTarget(book: identity(b), kind: .note, noteID: n.id),
                title: b.title, userText: n.userText, quote: n.anchor.quote, location: "段落 \(n.anchor.blockID + 1)"))
        }
        let pdfBooks = Dictionary(uniqueKeysWithValues: pdf.books.map { ($0.id, $0) })
        let epubBooks = Dictionary(uniqueKeysWithValues: epub.books.map { ($0.id, $0) })
        for n in japanese.notes {
            try Task.checkCancellation()
            let source = n.review.source, isPDF: Bool
            switch source.anchor { case .pdf: isPDF = true; case .epub: isPDF = false; default: continue }
            let id = RecordBookIdentity(format: isPDF ? .pdf : .epub, bookID: source.bookID,
                editionID: source.anchor.editionID, fileSHA256: source.anchor.fileSHA256)
            let title: String?
            if isPDF { title = pdfBooks[source.bookID].flatMap { $0.editionID == id.editionID && $0.fileSHA256 == id.fileSHA256 ? $0.title : nil } }
            else { title = epubBooks[source.bookID].flatMap { $0.editionID == id.editionID && $0.fileSHA256 == id.fileSHA256 ? $0.title : nil } }
            var generatedFields: [String] = [n.review.translationZh ?? ""]
            for reading in n.review.readings {
                generatedFields.append(contentsOf: reading.candidates)
                generatedFields.append(reading.explanationZh)
            }
            for grammar in n.review.grammar {
                generatedFields.append(grammar.labelZh)
                generatedFields.append(grammar.explanationZh)
            }
            for component in n.review.components { generatedFields.append(component.explanationZh) }
            generatedFields.append(contentsOf: n.review.warnings)
            let generated = generatedFields.joined(separator: "\n")
            entries.append(RecordSearchEntry(target: RecordSearchTarget(book: id, kind: .japanese, noteID: n.id),
                title: title ?? "来源书籍不在书库", userText: n.userText, quote: source.anchor.quote, generatedText: generated,
                correctionsText: n.corrections.map { $0.reading }.joined(separator: "\n"), location: source.anchor.locationLabel, sourceAvailable: title != nil))
        }
        var hits: [RecordSearchHit] = [], count = 0
        for entry in entries.sorted(by: { $0.id < $1.id }) {
            try Task.checkCancellation()
            guard LibrarySearchIndex.matches(tokens, fields: entry.fields) else { continue }
            count += 1
            guard hits.count < max(0, limit) else { continue }
            let field = entry.fields.first { f in tokens.contains { LibrarySearchIndex.folded(f).range(of: $0, options: .literal) != nil } } ?? ""
            hits.append(RecordSearchHit(entry: entry, preview: LibrarySearchIndex.excerpt(field, tokens: tokens)))
        }
        return RecordSearchResponse(hits: hits, totalCount: count)
    }
    /// Activation re-reads current records and validates exact persisted identity, never a preview string.
    public func resolve(_ target: RecordSearchTarget) async throws -> ResolvedRecordSearchSource {
        try Task.checkCancellation()
        switch target.book.format {
        case .text(let format):
            let state = try await text.load()
            guard let b = state.books.first(where: { Self.identity($0) == target.book && $0.format == format }) else { throw LibrarySearchFailure.source }
            if target.kind == .book, target.noteID == nil { return .text(b, nil) }
            guard target.kind == .note, let n = state.notes.first(where: { $0.id == target.noteID && $0.bookID == b.id }), b.accepts(n.anchor) else { throw LibrarySearchFailure.source }
            return .text(b, n.anchor)
        case .ebook(let format):
            let state = try await ebook.load()
            guard let b = state.books.first(where: { Self.identity($0) == target.book && $0.format == format }) else { throw LibrarySearchFailure.source }
            if target.kind == .book, target.noteID == nil { return .ebook(b, nil) }
            guard target.kind == .note, let n = state.notes.first(where: { $0.id == target.noteID && $0.bookID == b.id }), b.accepts(n.anchor) else { throw LibrarySearchFailure.source }
            return .ebook(b, n.anchor)
        case .pdf, .epub:
            guard target.kind == .japanese, let n = try await japanese.load().notes.first(where: { $0.id == target.noteID }) else { throw LibrarySearchFailure.source }
            let source = n.review.source
            guard source.isValid, source.bookID == target.book.bookID, source.anchor.editionID == target.book.editionID,
                  source.anchor.fileSHA256 == target.book.fileSHA256 else { throw LibrarySearchFailure.source }
            switch (target.book.format, source.anchor) {
            case (.pdf, .pdf):
                guard try await pdf.load().books.contains(where: { $0.id == source.bookID && $0.editionID == target.book.editionID && $0.fileSHA256 == target.book.fileSHA256 }) else { throw LibrarySearchFailure.source }
            case (.epub, .epub(let a)):
                guard try await epub.load().books.contains(where: { $0.id == source.bookID && $0.accepts(a) }) else { throw LibrarySearchFailure.source }
            default: throw LibrarySearchFailure.source
            }
            return .japanese(source)
        }
    }
}

/// One request combines the existing index and admitted record types, with one display budget.
/// A failure in either store family fails the request, allowing the UI to clear all stale hits.
public actor SavedRecordSearchRepository {
    private let legacy: LibrarySearchRepository
    private let records: RecordSearchRepository
    public init(root: URL) { legacy = LibrarySearchRepository(root: root); records = RecordSearchRepository(root: root) }
    public func search(_ query: String) async throws -> SavedRecordSearchResponse {
        let old = try await legacy.search(query); try Task.checkCancellation()
        let displayed = old.groups.reduce(0) { $0 + $1.hits.count }
        let newer = try await records.search(query, limit: LibrarySearchIndex.resultLimit - displayed)
        try Task.checkCancellation()
        return SavedRecordSearchResponse(legacy: old, records: newer)
    }
}
