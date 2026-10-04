// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Read saved native manifests and explicitly selected existing covers. No original book bytes,
/// draft journal, credentials, generation, export files or receiver/network access.
/// The learning-note manifest also holds provider settings; only its saved notes are mapped.
public actor BooknoLibraryPreviewRepository {
    public static let maximumSelectedBooks = 20
    public static let maximumCoverBytes = 20 * 1024 * 1024
    private let root: URL
    public init(root: URL) { self.root = root }
    public func catalog() async throws -> [BooknoPreviewChoice] {
        let pdf = try await LibraryRepository(root: root).load().books
        let epub = try await EPUBRepository(root: root).load().books
        let docx = try await DOCXRepository(root: root).load().books
        let comics = try await ComicRepository(root: root).load().books
        let metadata = try await LocalBookMetadataRepository(root: root).load().records
        let overrides = Dictionary(uniqueKeysWithValues: metadata.map { ($0.id, $0) })
        var native: [LibrarySearchBook] = []
        func add(_ format: LocalBookFormat, _ id: UUID, _ edition: UUID, _ hash: String, _ title: String) {
            let identity = LocalBookIdentity(format: format, bookID: id, editionID: edition, fileSHA256: hash)
            let saved = overrides[identity.id].flatMap { $0.book == identity ? $0 : nil }
            native.append(LibrarySearchBook(identity: identity, title: saved?.title ?? title,
                author: saved?.author ?? "", metadataRevision: saved?.revision ?? 0))
        }
        for b in pdf { add(.pdf, b.id, b.editionID, b.fileSHA256, b.title) }
        for b in epub { add(.epub, b.id, b.editionID, b.fileSHA256, b.title) }
        for b in docx { add(.docx, b.id, b.editionID, b.fileSHA256, b.title) }
        for b in comics { add(.comic, b.id, b.editionID, b.fileSHA256, b.title) }
        let texts = try await TextFormatRepository(root: root).load().books
        var choices = try native.map { BooknoPreviewChoice(book: try BooknoExportAdapter.book($0).0) }
        choices += try texts.map { BooknoPreviewChoice(book: try BooknoExportAdapter.book($0)) }
        guard Set(choices.map(\.id)).count == choices.count else { throw BooknoPreviewError.invalidContract }
        return choices.sorted { $0.book.title == $1.book.title ? $0.id < $1.id : $0.book.title.utf8.lexicographicallyPrecedes($1.book.title.utf8) }
    }
    public func materialize(_ selected: [BooknoPreviewChoice], includeSavedNotes: Bool, includeCovers: Bool) async throws -> BooknoPreviewMaterial {
        guard !selected.isEmpty, selected.count <= Self.maximumSelectedBooks,
              Set(selected.map(\.id)).count == selected.count else { throw BooknoPreviewError.selectionLimit }
        let current = Dictionary(uniqueKeysWithValues: try await catalog().map { ($0.id, $0) })
        let formats = Set(selected.map { $0.book.edition.format })
        let pdfNotes = includeSavedNotes && formats.contains(.pdf) ? try await LibraryRepository(root: root).load().notes : []
        let epubNotes = includeSavedNotes && formats.contains(.epub) ? try await EPUBRepository(root: root).load().notes : []
        let learning = includeSavedNotes && !formats.isDisjoint(with: [.pdf, .epub]) ? try await AILearningRepository(root: root).load().notes : []
        let text = try await TextFormatRepository(root: root).load()
        let covers = CoverRepository(root: root)
        var payloads: [BooknoPayload] = [], assets: [String: BooknoCoverAssetDTO] = [:], bytes: [String: Data] = [:], notices: [String] = []
        for chosen in selected {
            try Task.checkCancellation()
            guard let fresh = current[chosen.id], fresh.book.edition == chosen.book.edition else { throw BooknoPreviewError.sourceMismatch }
            var book = fresh.book
            if includeCovers {
                if let format = book.edition.format.coverFormat {
                    let identity = CoverIdentity(bookID: book.bookUUID, editionID: book.edition.id,
                        fileSHA256: book.edition.sourceFileSHA256, format: format)
                    if let snapshot = try await covers.readOnlySnapshot(for: identity) {
                        let mapped = try BooknoExportAdapter.addingCover(to: book, record: snapshot.record); book = mapped.0
                        if let asset = mapped.1 {
                            guard let png = snapshot.png else { throw BooknoPreviewError.assetMissing }
                            try BooknoExchangeCodec.validateAsset(png, declaration: asset)
                            if let previous = assets[asset.assetID], previous != asset { throw BooknoPreviewError.assetInvalid }
                            assets[asset.assetID] = asset; bytes[asset.assetID] = png
                            guard bytes.values.reduce(0, { $0 + $1.count }) <= Self.maximumCoverBytes else { throw BooknoPreviewError.selectionLimit }
                        }
                    } else { notices.append(book.title + "：没有此版本的已保存封面，本次不生成封面。") }
                } else { notices.append(book.title + "：文本格式封面尚未支持，本次只预览书目。") }
            }
            payloads.append(.book(book))
            if includeSavedNotes {
                switch book.edition.format {
                case .pdf:
                    payloads += try pdfNotes.filter { $0.bookID == book.bookUUID }.map { .note(try BooknoExportAdapter.note(.pdf($0), book: book)) }
                case .epub:
                    payloads += try epubNotes.filter { $0.bookID == book.bookUUID }.map { .note(try BooknoExportAdapter.note(.epub($0), book: book)) }
                case .txt, .markdown, .html:
                    guard let original = text.books.first(where: { $0.id == book.bookUUID }),
                          BooknoFormat(original.format) == book.edition.format,
                          original.editionID == book.edition.id, original.fileSHA256 == book.edition.sourceFileSHA256 else { throw BooknoPreviewError.sourceMismatch }
                    payloads += try text.notes.filter { $0.bookID == original.id }.map { .note(try BooknoExportAdapter.note($0, book: original)) }
                case .cbz, .docx: notices.append(book.title + "：本次仅书目与既存封面，未包含漫画／Word 笔记。")
                }
                for note in learning where note.result.source.bookID == book.bookUUID {
                    let format: BooknoFormat
                    switch note.result.source.anchor { case .pdf, .pdfPage: format = .pdf; case .epub, .epubChapter: format = .epub }
                    if format == book.edition.format { payloads.append(.note(try BooknoExportAdapter.note(.learning(note), book: book))) }
                }
            }
            guard payloads.count <= 1000 else { throw BooknoPreviewError.selectionLimit }
        }
        return BooknoPreviewMaterial(payloads: payloads, assets: assets.values.sorted { $0.assetID < $1.assetID }, assetBytes: bytes, notices: notices)
    }
}
