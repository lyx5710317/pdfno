// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI

struct ReadingTranslationWorkspace: View {
    private enum Scope: String, CaseIterable {
        case page = "当前 PDF 物理页", spine = "当前 EPUB spine 内容单元"
    }
    @ObservedObject var library: LibraryModel
    @State private var scope: Scope
    @State private var prepared = false
    init(library: LibraryModel) {
        self.library = library; _scope = State(initialValue: library.readingEPUB ? .spine : .page)
    }
    var body: some View {
        VStack(spacing: 0) {
            Picker("翻译范围", selection: $scope) {
                Text(Scope.page.rawValue).tag(Scope.page).disabled(library.readingEPUB)
                Text(Scope.spine.rawValue).tag(Scope.spine).disabled(!library.readingEPUB)
            }.padding(12).accessibilityIdentifier("reading-translation-scope")
            Divider()
            if !prepared { ProgressView("正在读取范围…") }
            else if scope == .page {
                PDFPageTranslationWorkspace(library: library, translation: library.pageTranslation, learning: library.learning)
            } else {
                EPUBChapterTranslationWorkspace(library: library, translation: library.chapterTranslation, learning: library.learning)
            }
        }.frame(minWidth: 480, idealWidth: 780, minHeight: 520)
            .task {
                if library.readingEPUB { await library.prepareChapterTranslation() }
                else { library.preparePageTranslation() }
                prepared = true
            }
    }
}
#endif
