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
    var body: some View {
        if let context { DocumentLearningTools(library: context.library,source: context.source) }
        else { PDFnoEmptyState(title: "先选择阅读原文",detail: "打开 PDF 或 EPUB，选择要学习的文字，再进入设置 → AI工具。这里不会默认处理整本书。",icon: "text.cursor") }
    }
}
private struct DocumentLearningTools: View {
    @ObservedObject var library: LibraryModel
    let source: AISourceSnapshot?
    @State private var japanese=false
    @State private var english=false
    private var available: Bool { source.map { library.isCurrentAISource($0) } == true }
    var body: some View {
        VStack(alignment: .leading,spacing: 16) {
            PDFnoSettingsCard("本次学习来源",symbol: "text.quote") {
                Text(library.displayedDocumentTitle).font(.headline)
                if let source { Text(source.anchor.locationLabel);PDFnoTextViewport(text: source.anchor.quote,identifier: "settings-tools-source",height: 150) }
                if !available { Text("请返回 PDF 或 EPUB 选择原文，再打开 AI工具。来源改变后需要重新固定；不会发送其他书籍或整本书。").foregroundStyle(.secondary) }
            }
            PDFnoSettingsCard("选文语言学习",symbol: "textformat.abc") {
                Button("日语学习") { guard let source,available else { return };library.prepareJapaneseLearning(source: source);japanese=true }.accessibilityIdentifier("settings-japanese-learning")
                Button("英语学习") { guard let source,available else { return };library.prepareEnglishLearning(source: source);english=true }.accessibilityIdentifier("settings-english-learning")
                Text("使用 AI 栏目中已应用的阅读配置。每次先核对固定原文和服务，再手动开始。")
            }.disabled(!available)
        }.sheet(isPresented: $japanese) { JapaneseLearningSheet(library: library) }
            .sheet(isPresented: $english) { EnglishLearningSheet(library: library) }
    }
}
#endif
