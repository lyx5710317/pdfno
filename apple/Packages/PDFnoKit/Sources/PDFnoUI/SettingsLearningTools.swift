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
        PDFnoSettingsCard("选文学习工具",symbol: "textformat.abc") {
            Toggle("日语学习",isOn: Binding(get: { tools.japanese },set: { tools.set(.japanese,enabled: $0) }))
                .accessibilityIdentifier("settings-japanese-learning")
            Toggle("英语学习",isOn: Binding(get: { tools.english },set: { tools.set(.english,enabled: $0) }))
                .accessibilityIdentifier("settings-english-learning")
            Text("开启后，在选文 AI 菜单中使用。关闭不会删除已有回答或笔记。").font(.callout).foregroundStyle(.secondary)
            Text("解释、翻译与总结始终可用；连接在设置 → AI 中配置。").font(.caption).foregroundStyle(.secondary)
            if let error = tools.error { Text(error).font(.caption).foregroundStyle(.red) }
        }
    }
}
#endif
