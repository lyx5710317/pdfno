// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain
import PDFnoServices
extension LibraryModel {
    var allLibraryBookIDs: Set<UUID> {
        var ids = Set(books.map(\.id) + epubBooks.map(\.id) + comicBooks.map(\.id))
        #if os(macOS)
        ids.formUnion(docx.books.map(\.id)); ids.formUnion(textFormats.books.map(\.id)); ids.formUnion(ebook.books.map(\.id))
        #endif
        return ids
    }
    var currentExampleIdentity: BundledExampleIdentity? {
        #if os(macOS)
        if ebook.isActive, let b = ebook.reader.book { return .init(format: b.format.rawValue, bookID: b.id, editionID: b.editionID, fileSHA256: b.fileSHA256) }
        if docx.isActive, let b = docx.reader.book { return .init(format: "docx", bookID: b.id, editionID: b.editionID, fileSHA256: b.fileSHA256) }
        if textFormats.isActive || readingComic { return nil }
        if readingEPUB, let b = epub.book { return .init(format: "epub", bookID: b.id, editionID: b.editionID, fileSHA256: b.fileSHA256) }
        #endif
        if let b = reader.book { return .init(format: "pdf", bookID: b.id, editionID: b.editionID, fileSHA256: b.fileSHA256) }
        return nil
    }
    /// Call only for a Bundle.module resource resolved by the explicit example buttons.
    func importBundledExample(_ url: URL) async {
        let before = allLibraryBookIDs
        await importFile(url)
        guard let book = currentExampleIdentity, lastCreatedImport == book, book.format == url.pathExtension.lowercased(),
              !before.contains(book.bookID) else { return }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            bundledExamples = try await BundledExampleRepository(root: repository.root).registerNewImport(
                book, resource: url.lastPathComponent, existingBookIDs: before, newImport: true,
                bundledSHA256: LibraryRepository.digest(data)).records
        } catch { self.error = "示例来源未能记录，书籍保留在我的书库。" }
    }
    func isBundledExample(_ identity: BundledExampleIdentity) -> Bool { bundledExamples.contains { $0.book == identity } }
}
