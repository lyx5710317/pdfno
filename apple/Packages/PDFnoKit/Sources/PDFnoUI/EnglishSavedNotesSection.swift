// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

struct EnglishSavedNotesSection: View {
    @ObservedObject var library: LibraryModel
    let bookID: UUID?
    let returned: () -> Void
    @State private var returnError: String?
    var body: some View {
        Section("英语学习笔记 · 已保存到本地") {
            if let error = library.englishStoreError { PDFnoStatusMessage(text: error, kind: .error) }
            if let returnError { PDFnoStatusMessage(text: returnError, kind: .error, identifier: "english-saved-return-error") }
            ForEach(library.englishNotes.filter { $0.review.source.bookID == bookID }) { note in
                VStack(alignment: .leading, spacing: PDFnoDesign.Space.small) {
                    Text(verbatim: note.review.source.anchor.quote).textSelection(.enabled).accessibilityIdentifier("english-saved-source")
                    Text(note.review.source.anchor.locationLabel).foregroundStyle(.secondary)
                    Text(note.review.provider.mode == .mock ? "本地固定语料演示 · 非真实语言判断" : "模型建议 · 需人工核对")
                    if let translation = note.review.translationZh { Text(verbatim: translation).accessibilityIdentifier("english-saved-translation") }
                    EnglishSentenceComponentsView(review: note.review)
                    ForEach(note.review.grammar) { item in
                        Text(verbatim: item.span.quote + " · " + item.aspect.labelZh + "\n" + item.explanationZh)
                            .accessibilityIdentifier("english-saved-grammar")
                    }
                    ForEach(Array(note.review.warnings.enumerated()), id: \.offset) { _, warning in
                        Text(verbatim: warning).foregroundStyle(.orange)
                    }
                    if !note.userText.isEmpty { Text(verbatim: note.userText).accessibilityIdentifier("english-saved-user-note") }
                    RecordBodyEditor(editor: library.recordEditing.editor, note: .english(note), identifier: "english-note") {
                        await library.recordEditing.save(.english(note))
                    } reload: { await library.recordEditing.reload(.english(note)) }
                    Button("英语笔记 · 回到原文") { Task {
                        returnError = nil
                        if await library.returnToEnglishSource(note.review.source) { returned() }
                        else { returnError = "原书版本或定位范围无法核对，未跳转；已保存记录仍可审阅。" }
                    } }.accessibilityIdentifier("english-saved-return")
                }
            }
        }.task { await library.loadEnglishLearningNotes() }
        .onChange(of: bookID) { _, _ in returnError = nil }
    }
}
#endif
