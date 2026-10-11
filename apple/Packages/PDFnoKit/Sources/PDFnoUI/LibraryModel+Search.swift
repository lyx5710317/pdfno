// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

extension LibraryModel {
    /// Resolve IDs from freshly validated stores on activation; search snapshots never bypass source checks.
    @MainActor func openSearchTarget(_ target: LibrarySearchTarget, preservingCurrentReader: Bool = false) async -> Bool {
        guard !isBusy else { return false }
        error = nil
        do {
            var learningSource: AISourceSnapshot?
            if target.kind == .learning || target.kind == .aiAnnotation {
                guard let saved = try await savedAISearchSource(target) else { return false }
                learningSource = saved
            }
            switch target.book.format {
            case .pdf:
                let state = try await repository.load()
                guard let book = state.books.first(where: { $0.id == target.book.bookID }),
                      book.editionID == target.book.editionID, book.fileSHA256 == target.book.fileSHA256 else { return false }
                let anchor: AISelectionAnchor?
                if target.kind == .note {
                    guard let note = state.notes.first(where: { $0.id == target.noteID && $0.bookID == book.id }) else { return false }
                    anchor = .pdf(note.anchor)
                } else { anchor = learningSource?.anchor }
                if let anchor {
                    let verifier = PDFReaderSession()
                    try verifier.open(data: try await repository.readAsset(for: book), book: book)
                    switch anchor {
                    case .pdf(let value): guard verifier.resolution(of: value) == .exact else { return false }
                    case .pdfPage(let value): guard verifier.resolution(of: value) == .exact else { return false }
                    case .epub, .epubChapter: return false
                    }
                }
                if !preservingCurrentReader || displayedDocumentID != book.id { await open(book) }
                guard error == nil, !readingEPUB, !readingComic, !docx.isActive, !textFormats.isActive, !ebook.isActive,
                      reader.book?.editionID == book.editionID, reader.book?.id == book.id else { return false }
                searchDocumentDidOpen?()
                if target.kind == .book { return true }
                if target.kind == .note {
                    guard let note = notes.first(where: { $0.id == target.noteID && $0.bookID == book.id }) else { return false }
                    return reader.navigate(to: note.anchor) == .exact
                }
            case .epub:
                let state = try await epubRepository.load()
                guard let book = state.books.first(where: { $0.id == target.book.bookID }),
                      book.editionID == target.book.editionID, book.fileSHA256 == target.book.fileSHA256 else { return false }
                if target.kind == .note {
                    guard state.notes.contains(where: { $0.id == target.noteID && $0.bookID == book.id && book.accepts($0.anchor) }) else { return false }
                }
                if let learningSource {
                    switch learningSource.anchor {
                    case .epub(let anchor), .epubChapter(let anchor): guard book.accepts(anchor) else { return false }
                    case .pdf, .pdfPage: return false
                    }
                }
                if !preservingCurrentReader || displayedDocumentID != book.id { await openEPUB(book) }
                guard error == nil, readingEPUB, epub.book?.id == book.id, epub.book?.editionID == book.editionID else { return false }
                searchDocumentDidOpen?()
                if target.kind == .book { return true }
                guard await waitForSearchEPUB(book) else { return false }
                if target.kind == .note {
                    let current = try await epubRepository.load()
                    guard let note = current.notes.first(where: { $0.id == target.noteID && $0.bookID == book.id }), book.accepts(note.anchor) else { return false }
                    return await epub.command("navigate", anchor: note.anchor)
                }
            case .docx:
                let state = try await docx.repository.load()
                guard let book = state.books.first(where: { $0.id == target.book.bookID }),
                      book.editionID == target.book.editionID, book.fileSHA256 == target.book.fileSHA256 else { return false }
                guard target.kind == .book || (target.kind == .note && state.notes.contains(where: { $0.id == target.noteID && $0.bookID == book.id && book.accepts($0.anchor) })) else { return false }
                if !preservingCurrentReader || displayedDocumentID != book.id { await openDOCX(book) }
                guard error == nil, docx.isActive, docx.reader.book?.id == book.id, docx.reader.book?.editionID == book.editionID else { return false }
                searchDocumentDidOpen?()
                if target.kind == .book { return true }
                guard target.kind == .note, let note = docx.notes.first(where: { $0.id == target.noteID && $0.bookID == book.id }) else { return false }
                return await docx.reader.navigate(to: note.anchor)
            case .comic, .cbt, .cb7, .cbr:
                guard target.kind == .book else { return false }
                let state = try await comicRepository.load()
                guard let book = state.books.first(where: { $0.id == target.book.bookID }),
                      book.editionID == target.book.editionID, book.fileSHA256 == target.book.fileSHA256,
                      LocalBookFormat(book.archiveFormat ?? .cbz) == target.book.format else { return false }
                if !preservingCurrentReader || displayedDocumentID != book.id { await openComic(book) }
                searchDocumentDidOpen?()
                return error == nil && readingComic && comic.book?.id == book.id && comic.book?.editionID == book.editionID
            }
            guard target.kind == .learning || target.kind == .aiAnnotation,
                  let saved = try await savedAISearchSource(target), saved == learningSource else { return false }
            // Re-read after opening; a deleted/replaced note cannot navigate using a stale hit.
            // Persisted reader-session IDs are never used to select a live document.
            return await returnToAISource(saved)
        } catch { return false }
    }
    private func savedAISearchSource(_ target: LibrarySearchTarget) async throws -> AISourceSnapshot? {
        guard let id = target.noteID else { return nil }
        let source: AISourceSnapshot?
        switch target.kind {
        case .learning:
            let state = try await AILearningRepository(root: await repository.root).load()
            source = state.notes.first(where: { $0.id == id })?.result.source
        case .aiAnnotation:
            let state = try await annotations.repository.load()
            source = state.notes.first(where: { $0.id == id && $0.origin == .explicitlySavedAI })?.aiResult?.source
        default: return nil
        }
        guard let source, source.bookID == target.book.bookID,
              source.anchor.editionID == target.book.editionID,
              source.anchor.fileSHA256 == target.book.fileSHA256 else { return nil }
        switch (target.book.format, source.anchor) {
        case (.pdf, .pdf), (.pdf, .pdfPage), (.epub, .epub), (.epub, .epubChapter): return source
        default: return nil
        }
    }
    /// Opening creates the view before its canonical document is ready. Keep
    /// this captured reader scope while the native workspace mounts WebKit.
    private func waitForSearchEPUB(_ book: EPUBBook) async -> Bool {
        let session = epub.readerSessionID, deadline = Date().addingTimeInterval(20)
        func sameReader() -> Bool {
            readingEPUB && !readingComic && !docx.isActive && !textFormats.isActive && !ebook.isActive &&
            epub.readerSessionID == session && epub.book?.id == book.id &&
            epub.book?.editionID == book.editionID && epub.book?.fileSHA256 == book.fileSHA256
        }
        while epub.busy {
            guard sameReader(), !Task.isCancelled, Date() < deadline else { return false }
            do { try await Task.sleep(for: .milliseconds(40)) }
            catch { return false }
        }
        return sameReader() && !Task.isCancelled && epub.error == nil && epub.webView != nil
    }
}
#endif
