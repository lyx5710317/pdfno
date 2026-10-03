// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain
import PDFnoServices

extension LibraryModel {
    func closeComic() {
        learning.cancel()
        #if os(macOS)
        comic.close()
        #endif
        readingComic = false
    }
    func importComic(_ url: URL) async {
        learning.cancel()
        #if os(macOS)
        guard canImport, !isBusy else { return }
        guard url.pathExtension.lowercased() == "cbz" else { error = ComicError.unavailable.localizedDescription; return }
        isBusy = true; defer { isBusy = false }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let info = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard info.isRegularFile == true, let size = info.fileSize, size <= ComicLimits.archiveBytes else { throw ComicError.resourceLimit }
            let data = try await Task.detached { try CBZArchive.readFile(url) }.value
            let book = try await comicRepository.importBook(data, filename: url.lastPathComponent)
            let archive = try await comicRepository.read(book)
            await load(); try await comic.open(archive: archive, book: book)
            epub.close(); readingEPUB = false; readingComic = true
            status = "漫画已保存到本地 · 原文件未改写"
        } catch { self.error = error.localizedDescription }
        #else
        error = ComicError.unavailable.localizedDescription
        #endif
    }
    func openComic(_ book: ComicBook) async {
        learning.cancel()
        #if os(macOS)
        guard !isBusy else { return }; isBusy = true; defer { isBusy = false }
        do {
            let state = try await comicRepository.load()
            guard let current = state.books.first(where: { $0.id == book.id }) else { throw ComicError.sourceMismatch }
            let archive = try await comicRepository.read(current)
            try await comic.open(archive: archive, book: current)
            epub.close(); readingEPUB = false; readingComic = true
        } catch { self.error = error.localizedDescription }
        #else
        error = ComicError.unavailable.localizedDescription
        #endif
    }
}
