// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Only saved manifests are indexed. Draft journals, live generation, originals and credentials are not read.
public actor RecordSearchRepository {
    private let text: TextFormatRepository
    private let ebook: EbookRepository
    private let gate: LocalStoreWriteGate
    private let english: EnglishLearningRepository
    private let japanese: JapaneseLearningRepository
    private let pdf: LibraryRepository
    private let epub: EPUBRepository
    private let docx: DOCXRepository
    private let annotations: AnnotationRepository
    public init(root: URL) {
        annotations = AnnotationRepository(root: root); docx = DOCXRepository(root: root)
        gate = .shared(root: root); english = EnglishLearningRepository(root: root)
        text = TextFormatRepository(root: root); ebook = EbookRepository(root: root)
        japanese = JapaneseLearningRepository(root: root); pdf = LibraryRepository(root: root); epub = EPUBRepository(root: root)
    }
    public func search(_ query: String, limit: Int = LibrarySearchIndex.resultLimit) async throws -> RecordSearchResponse {
        let epoch = gate.snapshot.epoch
        guard gate.snapshot.phase == .writable else { throw LibrarySearchFailure.store }
        let tokens = try LibrarySearchIndex.tokens(query); try Task.checkCancellation()
        let t = try await text.load(); try Task.checkCancellation()
        let e = try await ebook.load(); try Task.checkCancellation()
        let j = try await japanese.load(); try Task.checkCancellation()
        let en = try await english.load(); try Task.checkCancellation()
        let p = try await pdf.load(); try Task.checkCancellation()
        let u = try await epub.load(); try Task.checkCancellation()
        let d = try await docx.load(); try Task.checkCancellation()
        let a = try await annotations.load(); try Task.checkCancellation()
        guard gate.snapshot.phase == .writable, gate.snapshot.epoch == epoch else { throw LibrarySearchFailure.store }
        let task = Task.detached { try Self.build(tokens, text: t, ebook: e, japanese: j, english: en, pdf: p, epub: u, docx: d, annotations: a, limit: limit) }
        let result = try await withTaskCancellationHandler(operation: { try await task.value }, onCancel: { task.cancel() })
        guard gate.snapshot.phase == .writable, gate.snapshot.epoch == epoch else { throw LibrarySearchFailure.store }
        return result
    }
    private static func identity(_ b: TextFormatBook) -> RecordBookIdentity {
        RecordBookIdentity(format: .text(b.format), bookID: b.id, editionID: b.editionID, fileSHA256: b.fileSHA256)
    }
    private static func identity(_ b: EbookBook) -> RecordBookIdentity {
        RecordBookIdentity(format: .ebook(b.format), bookID: b.id, editionID: b.editionID, fileSHA256: b.fileSHA256)
    }
    private static func build(_ tokens: [String], text: TextFormatState, ebook: EbookState, japanese: JapaneseLearningState, english: EnglishLearningState,
                              pdf: LibraryState, epub: EPUBState, docx: DOCXState, annotations: AnnotationState, limit: Int) throws -> RecordSearchResponse {
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
        for n in english.notes {
            try Task.checkCancellation()
            let source = n.review.source, isPDF: Bool
            switch source.anchor { case .pdf: isPDF = true; case .epub: isPDF = false; default: continue }
            let id = RecordBookIdentity(format: isPDF ? .pdf : .epub, bookID: source.bookID,
                editionID: source.anchor.editionID, fileSHA256: source.anchor.fileSHA256)
            let title: String?
            if isPDF { title = pdfBooks[source.bookID].flatMap { $0.editionID == id.editionID && $0.fileSHA256 == id.fileSHA256 ? $0.title : nil } }
            else { title = epubBooks[source.bookID].flatMap { $0.editionID == id.editionID && $0.fileSHA256 == id.fileSHA256 ? $0.title : nil } }
            var fields = [n.review.translationZh ?? ""]
            for component in n.review.components { fields.append(component.role.labelZh); fields.append(component.explanationZh) }
            for grammar in n.review.grammar { fields.append(grammar.aspect.labelZh); fields.append(grammar.explanationZh) }
            fields.append(contentsOf: n.review.warnings)
            entries.append(RecordSearchEntry(target: RecordSearchTarget(book: id, kind: .english, noteID: n.id),
                title: title ?? "来源书籍不在书库", userText: n.userText, quote: source.anchor.quote,
                generatedText: fields.joined(separator: "\n"), location: source.anchor.locationLabel, sourceAvailable: title != nil))
        }
        // Explicitly saved AI is indexed in LibrarySearchRepository. Manual annotations
        // get their own namespace, including when a historical note reuses the UUID.
        for note in annotations.notes where note.origin == .manual {
            try Task.checkCancellation()
            let format: RecordSourceFormat, title: String?, location: String
            switch note.anchor {
            case .pdf(let anchor): format = .pdf; location = "第 \(anchor.regions.first.map { $0.pageIndex + 1 } ?? 1) 页"
                title = pdfBooks[note.bookID].flatMap { $0.editionID == anchor.editionID && $0.fileSHA256 == anchor.fileSHA256 ? $0.title : nil }
            case .epub(let anchor): format = .epub; location = "第 \(anchor.spineIndex + 1) 章"
                title = epubBooks[note.bookID].flatMap { $0.accepts(anchor) ? $0.title : nil }
            case .text(let anchor):
                guard let book = textBooks[note.bookID] else { continue }
                format = .text(book.format); location = "段落 \(anchor.blockID + 1)"; title = book.accepts(anchor) ? book.title : nil
            case .ebook(let anchor): format = .ebook(anchor.format); location = "段落 \(anchor.blockID + 1)"
                title = ebookBooks[note.bookID].flatMap { $0.accepts(anchor) ? $0.title : nil }
            case .docx(let anchor): format = .docx; location = "段落 \(anchor.blockID + 1)"
                title = docx.books.first(where: { $0.id == note.bookID && $0.accepts(anchor) })?.title
            }
            let identity = RecordBookIdentity(format: format, bookID: note.bookID, editionID: note.anchor.editionID, fileSHA256: note.anchor.fileSHA256)
            entries.append(RecordSearchEntry(target: RecordSearchTarget(book: identity, kind: .annotation, noteID: note.id),
                title: title ?? "来源书籍不在书库", userText: note.userText, quote: note.anchor.quote, location: location, sourceAvailable: title != nil))
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
        let manual: AnchoredAnnotation?
        if target.kind == .annotation {
            guard let note = try await annotations.load().notes.first(where: { $0.id == target.noteID && $0.origin == .manual }),
                  note.bookID == target.book.bookID, note.anchor.editionID == target.book.editionID,
                  note.anchor.fileSHA256 == target.book.fileSHA256 else { throw LibrarySearchFailure.source }
            manual = note
        } else { manual = nil }
        switch target.book.format {
        case .text(let format):
            let state = try await text.load()
            guard let b = state.books.first(where: { Self.identity($0) == target.book && $0.format == format }) else { throw LibrarySearchFailure.source }
            if target.kind == .book, target.noteID == nil { return .text(b, nil) }
            if let manual {
                guard case .text(let anchor) = manual.anchor, b.accepts(anchor) else { throw LibrarySearchFailure.source }
                return .text(b, anchor)
            }
            guard target.kind == .note, let n = state.notes.first(where: { $0.id == target.noteID && $0.bookID == b.id }), b.accepts(n.anchor) else { throw LibrarySearchFailure.source }
            return .text(b, n.anchor)
        case .ebook(let format):
            let state = try await ebook.load()
            guard let b = state.books.first(where: { Self.identity($0) == target.book && $0.format == format }) else { throw LibrarySearchFailure.source }
            if target.kind == .book, target.noteID == nil { return .ebook(b, nil) }
            if let manual {
                guard case .ebook(let anchor) = manual.anchor, b.accepts(anchor) else { throw LibrarySearchFailure.source }
                return .ebook(b, anchor)
            }
            guard target.kind == .note, let n = state.notes.first(where: { $0.id == target.noteID && $0.bookID == b.id }), b.accepts(n.anchor) else { throw LibrarySearchFailure.source }
            return .ebook(b, n.anchor)
        case .docx:
            guard let manual, case .docx(let anchor) = manual.anchor,
                  let book = try await docx.load().books.first(where: { $0.id == manual.bookID && $0.accepts(anchor) }) else { throw LibrarySearchFailure.source }
            return .docx(book, anchor)
        case .pdf, .epub:
            let source: AISourceSnapshot
            switch target.kind {
            case .annotation:
                guard let manual else { throw LibrarySearchFailure.source }
                let anchor: AISelectionAnchor
                switch manual.anchor { case .pdf(let value): anchor = .pdf(value); case .epub(let value): anchor = .epub(value); default: throw LibrarySearchFailure.source }
                source = AISourceSnapshot(bookID: manual.bookID, readerSessionID: manual.id, documentVersion: 0, anchor: anchor)
            case .japanese:
                guard let n = try await japanese.load().notes.first(where: { $0.id == target.noteID }) else { throw LibrarySearchFailure.source }
                source = n.review.source
            case .english:
                guard let n = try await english.load().notes.first(where: { $0.id == target.noteID }) else { throw LibrarySearchFailure.source }
                source = n.review.source
            default: throw LibrarySearchFailure.source
            }
            guard source.isValid, source.bookID == target.book.bookID, source.anchor.editionID == target.book.editionID,
                  source.anchor.fileSHA256 == target.book.fileSHA256 else { throw LibrarySearchFailure.source }
            switch (target.book.format, source.anchor) {
            case (.pdf, .pdf):
                guard try await pdf.load().books.contains(where: { $0.id == source.bookID && $0.editionID == target.book.editionID && $0.fileSHA256 == target.book.fileSHA256 }) else { throw LibrarySearchFailure.source }
            case (.epub, .epub(let a)):
                guard try await epub.load().books.contains(where: { $0.id == source.bookID && $0.accepts(a) }) else { throw LibrarySearchFailure.source }
            default: throw LibrarySearchFailure.source
            }
            if target.kind == .annotation { return .annotation(source) }
            return target.kind == .english ? .english(source) : .japanese(source)
        }
    }
}

/// One request combines the existing index and admitted record types, with one display budget.
/// A failure in either store family fails the request, allowing the UI to clear all stale hits.
public actor SavedRecordSearchRepository {
    private let gate: LocalStoreWriteGate
    private let legacy: LibrarySearchRepository
    private let records: RecordSearchRepository
    public init(root: URL) { gate = .shared(root: root); legacy = LibrarySearchRepository(root: root); records = RecordSearchRepository(root: root) }
    public func search(_ query: String) async throws -> SavedRecordSearchResponse {
        let epoch = gate.snapshot.epoch
        guard gate.snapshot.phase == .writable else { throw LibrarySearchFailure.store }
        let old = try await legacy.search(query); try Task.checkCancellation()
        let displayed = old.groups.reduce(0) { $0 + $1.hits.count }
        let newer = try await records.search(query, limit: LibrarySearchIndex.resultLimit - displayed)
        try Task.checkCancellation()
        guard gate.snapshot.phase == .writable, gate.snapshot.epoch == epoch else { throw LibrarySearchFailure.store }
        return SavedRecordSearchResponse(legacy: old, records: newer)
    }
}
