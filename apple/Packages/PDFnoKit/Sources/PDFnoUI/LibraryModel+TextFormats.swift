// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFnoDomain
extension LibraryModel {
    func importTextFormat(_ url: URL) async {
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        guard canImport, !isBusy else { return }; isBusy = true; defer { isBusy = false }
        await saveProgress()
        do {
            try await textFormats.importFile(url)
            epub.close(); comic.close(); docx.deactivate(); readingEPUB = false; readingComic = false
            status = "文本已保存到本地 · 原文件未改写"
        } catch { self.error = error.localizedDescription }
    }
    func openTextFormat(_ book: TextFormatBook) async {
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        guard !isBusy else { return }; isBusy = true; defer { isBusy = false }
        await saveProgress()
        do {
            try await textFormats.open(book)
            epub.close(); comic.close(); docx.deactivate(); readingEPUB = false; readingComic = false
        } catch { self.error = error.localizedDescription }
    }
}
#endif
