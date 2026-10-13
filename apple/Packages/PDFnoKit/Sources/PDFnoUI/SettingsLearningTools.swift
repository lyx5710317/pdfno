// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

@MainActor struct SettingsAIContext {
    let library: LibraryModel
    let source: AISourceSnapshot?
    static func capture(_ library: LibraryModel?) -> Self? {
        guard let library,let bookID=library.currentAIBookID else { return nil }
        let retained: AISourceSnapshot?
        if library.readingEPUB,let anchor=library.epub.selection {
            retained=AISourceSnapshot(bookID: bookID,readerSessionID: library.epub.readerSessionID,documentVersion: library.epub.documentVersion,anchor: .epub(anchor))
        } else if !library.readingEPUB,let anchor=library.reader.capturedSelection {
            retained=AISourceSnapshot(bookID: bookID,readerSessionID: library.reader.readerSessionID,documentVersion: 0,anchor: .pdf(anchor))
        } else { retained=library.learning.source }
        let candidate=library.captureAISource() ?? retained
        return Self(library: library,source: candidate.flatMap { library.isCurrentAISource($0) ? $0 : nil })
    }
}
struct SettingsLearningTools: View {
    let context: SettingsAIContext?
    var learning: AILearningModel? = nil
    var body: some View {
        if let learning = learning ?? context?.library.learning {
            ReadingToolsPreferencesView(tools: learning.tools)
        } else { Text("请从书库设置打开 AI工具。") }
    }
}
private struct ReadingToolsPreferencesView: View {
    @ObservedObject var tools: AIReadingToolsPreferences
    var body: some View {
        PDFnoSettingsCard("日语学习",symbol: "character.ja") {
            Toggle("启用日语学习",isOn: Binding(get: { tools.japanese },set: { tools.set(.japanese,enabled: $0) }))
                .accessibilityIdentifier("settings-japanese-learning")
            Text("选文对话与假名、语法审阅。共用全局配置api；关闭保留回答与笔记。").font(.caption).foregroundStyle(.secondary)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("settings-japanese-card")
        PDFnoSettingsCard("英语学习",symbol: "textformat.abc") {
            Toggle("启用英语学习",isOn: Binding(get: { tools.english },set: { tools.set(.english,enabled: $0) }))
                .accessibilityIdentifier("settings-english-learning")
            Text("选文对话与结构、语法审阅。共用全局配置api；关闭保留回答与笔记。").font(.caption).foregroundStyle(.secondary)
            if let error = tools.error { Text(error).font(.caption).foregroundStyle(.red) }
        }.accessibilityElement(children: .contain).accessibilityIdentifier("settings-english-card")
    }
}
#endif
