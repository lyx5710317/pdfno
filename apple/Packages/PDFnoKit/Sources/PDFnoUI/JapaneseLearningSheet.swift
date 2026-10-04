// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

struct JapaneseLearningSheet: View {
    @ObservedObject var library: LibraryModel
    @Environment(\.dismiss) private var dismiss
    private var fixtureColorScheme: ColorScheme? {
        #if DEBUG
        guard library.learning.offlineTransport,
              let token = ProcessInfo.processInfo.environment["PDFNO_UI_TEST_SESSION"], UUID(uuidString: token) != nil else { return nil }
        switch ProcessInfo.processInfo.environment["PDFNO_UI_TEST_JAPANESE_APPEARANCE"] {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
        #else
        return nil
        #endif
    }
    var body: some View {
        NavigationStack {
            JapaneseLearningWorkspace(learning: library.japaneseLearning, returnToSource: { source in
                Task { if await library.returnToJapaneseSource(source) { dismiss() } }
            })
            .toolbar {
                ToolbarItem { Button("重新固定当前选文") { library.prepareJapaneseLearning() }.accessibilityIdentifier("japanese-learning-recapture") }
                ToolbarItem { Button("完成（取消未完成请求）") { library.japaneseLearning.cancel(); dismiss() }.accessibilityIdentifier("japanese-learning-close") }
            }
            .overlay(alignment: .top) {
                if library.learning.offlineTransport {
                    VStack(spacing: 2) {
                        Text("离线 transport 替身 · 不发送真实 API").font(.caption).accessibilityIdentifier("japanese-offline-fixture")
                        #if DEBUG
                        JapaneseLearningUIAppearanceMarker()
                        #endif
                    }
                }
            }
        }.frame(minWidth: 440, minHeight: 600).preferredColorScheme(fixtureColorScheme)
        .onDisappear { library.japaneseLearning.cancel() }
    }
}
#if DEBUG
/// Shows the real SwiftUI environment used by the isolated fixture; no production override.
private struct JapaneseLearningUIAppearanceMarker: View {
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        Text(colorScheme == .dark ? "隔离 UI 外观：深色" : "隔离 UI 外观：浅色")
            .font(.caption).accessibilityIdentifier("japanese-fixture-appearance")
    }
}
#endif
struct JapaneseSavedNotesSection: View {
    @ObservedObject var library: LibraryModel
    let bookID: UUID?
    let returned: () -> Void
    @State private var returnError: String?
    var body: some View {
        Section("日语学习笔记 · 已保存到本地") {
            if let error = library.japaneseStoreError { Text(error).foregroundStyle(.red) }
            if let returnError { Text(returnError).foregroundStyle(.red).accessibilityIdentifier("japanese-saved-return-error") }
            ForEach(library.japaneseNotes.filter { $0.review.source.bookID == bookID }) { note in
                VStack(alignment: .leading, spacing: 8) {
                    Text(verbatim: note.review.source.anchor.quote).textSelection(.enabled).accessibilityIdentifier("japanese-saved-source")
                    Text(note.review.source.anchor.locationLabel).foregroundStyle(.secondary)
                    Text(note.review.provider.mode == .mock ? "本地 mock 演示 · 非真实语言判断" : "模型建议 · 需人工核对")
                    if let translation = note.review.translationZh { Text(verbatim: translation).accessibilityIdentifier("japanese-saved-translation") }
                    JapaneseSentenceComponentsView(review: note.review)
                    ForEach(note.review.readings) { item in
                        Text(verbatim: item.span.quote + " → " + item.candidates.joined(separator: " / "))
                        if item.ambiguous { Text("读音有歧义 · 候选尚未确定").foregroundStyle(.orange) }
                    }
                    ForEach(note.review.grammar) { item in
                        Text(verbatim: item.span.quote + " · " + item.labelZh + "\n" + item.explanationZh)
                            .accessibilityIdentifier("japanese-saved-grammar")
                    }
                    ForEach(Array(note.corrections.enumerated()), id: \.offset) { _, correction in
                        Text(verbatim: "用户修正：" + correction.span.quote + " → " + correction.reading)
                    }
                    ForEach(Array(note.review.warnings.enumerated()), id: \.offset) { _, warning in
                        Text(verbatim: warning).foregroundStyle(.orange)
                    }
                    if !note.userText.isEmpty { Text(verbatim: note.userText).accessibilityIdentifier("japanese-saved-user-note") }
                    Button("日语笔记 · 回到原文") { Task {
                        returnError = nil
                        if await library.returnToJapaneseSource(note.review.source) { returned() }
                        else { returnError = "原书版本或定位范围无法核对，未跳转；已保存记录仍可审阅。" }
                    } }
                        .accessibilityIdentifier("japanese-saved-return")
                }
            }
        }.task { await library.loadJapaneseLearningNotes() }
        .onChange(of: bookID) { _, _ in returnError = nil }
    }
}
#endif
