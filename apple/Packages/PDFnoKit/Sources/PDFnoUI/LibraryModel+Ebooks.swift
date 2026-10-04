// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFnoDomain
extension LibraryModel {
    func importEbook(_ url: URL) async {
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        guard canImport, !isBusy else { return }; isBusy = true; defer { isBusy = false }
        await saveProgress()
        do {
            try await ebook.importFile(url)
            epub.close(); comic.close(); docx.deactivate(); textFormats.deactivate(); readingEPUB = false; readingComic = false
            status = "电子书已保存到本地 · 原件保留"
        } catch { self.error = error.localizedDescription }
    }
    func openEbook(_ book: EbookBook) async {
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        guard !isBusy else { return }; isBusy = true; defer { isBusy = false }
        await saveProgress()
        do {
            try await ebook.open(book)
            epub.close(); comic.close(); docx.deactivate(); textFormats.deactivate(); readingEPUB = false; readingComic = false
        } catch { self.error = error.localizedDescription }
    }
    func openEbookSample(_ format: EbookFormat) async {
        if let root = Bundle.module.url(forResource: "Ebooks", withExtension: nil) {
            await importEbook(root.appendingPathComponent("study-sample." + format.rawValue))
        }
    }
}
#endif
