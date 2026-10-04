// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

extension LibraryModel {
    /// Fresh source identity and native canonical resolution are required before switching readers.
    /// The host calls this only for an explicit result activation.
    func openRecordSearchTarget(_ target: RecordSearchTarget) async -> Bool {
        guard !isBusy, !Task.isCancelled else { return false }
        let initialScope = recordSearchReaderScope()
        let repository = RecordSearchRepository(root: await self.repository.root)
        do {
            let resolved = try await repository.resolve(target)
            switch resolved {
            case .text(let book, let anchor):
                if let anchor {
                    let verifier = TextFormatReaderSession(); defer { verifier.close() }
                    try await verifier.open(data: try await textFormats.repository.read(book), book: book, notes: [])
                    guard verifier.document?.resolves(anchor) == true else { return false }
                }
                try Task.checkCancellation()
                guard !isBusy, recordSearchReaderScope() == initialScope else { return false }
                await openTextFormat(book)
                guard textFormats.isActive, textFormats.reader.book?.id == book.id, textFormats.reader.book?.editionID == book.editionID,
                      textFormats.reader.ready, !Task.isCancelled else { return false }
                if anchor == nil { return true }
                let activeScope = recordSearchReaderScope()
                guard case .text(let freshBook, let freshAnchor) = try await repository.resolve(target), freshBook.id == book.id,
                      let freshAnchor, freshAnchor == anchor, recordSearchReaderScope() == activeScope, !Task.isCancelled else { return false }
                return await textFormats.reader.navigate(to: freshAnchor)
            case .ebook(let book, let anchor):
                if let anchor {
                    let verifier = EbookReaderSession(); defer { verifier.close() }
                    try await verifier.open(data: try await ebook.repository.read(book), book: book, notes: [])
                    guard verifier.document?.resolves(anchor) == true else { return false }
                }
                try Task.checkCancellation()
                guard !isBusy, recordSearchReaderScope() == initialScope else { return false }
                await openEbook(book)
                guard ebook.isActive, ebook.reader.book?.id == book.id, ebook.reader.book?.editionID == book.editionID,
                      ebook.reader.ready, !Task.isCancelled else { return false }
                if anchor == nil { return true }
                let activeScope = recordSearchReaderScope()
                guard case .ebook(let freshBook, let freshAnchor) = try await repository.resolve(target), freshBook.id == book.id,
                      let freshAnchor, freshAnchor == anchor, recordSearchReaderScope() == activeScope, !Task.isCancelled else { return false }
                return await ebook.reader.navigate(to: freshAnchor)
            case .japanese(let source):
                let format: LocalBookFormat
                switch source.anchor {
                case .pdf(let anchor):
                    let state = try await self.repository.load()
                    guard let book = state.books.first(where: { $0.id == source.bookID }) else { return false }
                    let verifier = PDFReaderSession()
                    try verifier.open(data: try await self.repository.readAsset(for: book), book: book)
                    guard verifier.resolution(of: anchor) == .exact else { return false }
                    format = .pdf
                case .epub: format = .epub
                default: return false
                }
                let bookTarget = LibrarySearchTarget(book: LocalBookIdentity(format: format, bookID: target.book.bookID,
                    editionID: target.book.editionID, fileSHA256: target.book.fileSHA256), kind: .book)
                guard !isBusy, recordSearchReaderScope() == initialScope, !Task.isCancelled else { return false }
                guard await openSearchTarget(bookTarget) else { return false }
                if format == .epub {
                    let session = epub.readerSessionID, deadline = Date().addingTimeInterval(20)
                    while epub.busy {
                        guard sameRecordEPUB(target.book, session: session), !Task.isCancelled, Date() < deadline else { return false }
                        try await Task.sleep(for: .milliseconds(40))
                    }
                    guard sameRecordEPUB(target.book, session: session), epub.error == nil, epub.webView != nil else { return false }
                }
                let activeScope = recordSearchReaderScope()
                guard !Task.isCancelled, case .japanese(let fresh) = try await repository.resolve(target) else { return false }
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                guard try encoder.encode(fresh) == encoder.encode(source), recordSearchReaderScope() == activeScope, !Task.isCancelled else { return false }
                return await returnToJapaneseSource(fresh)
            }
        } catch { return false }
    }
    private func recordSearchReaderScope() -> String {
        let sessions = [reader.readerSessionID, epub.readerSessionID, docx.reader.readerSessionID,
         textFormats.reader.readerSessionID, ebook.reader.readerSessionID].map(\.uuidString).joined(separator: ":")
        let comicView = comic.webView.map { String(describing: ObjectIdentifier($0)) } ?? "none"
        return sessions + ":" + comicView + ":" + String(readingComic)
    }
    private func sameRecordEPUB(_ book: RecordBookIdentity, session: UUID) -> Bool {
        readingEPUB && !readingComic && !docx.isActive && !textFormats.isActive && !ebook.isActive &&
        epub.readerSessionID == session && epub.book?.id == book.bookID && epub.book?.editionID == book.editionID && epub.book?.fileSHA256 == book.fileSHA256
    }
}
#endif
