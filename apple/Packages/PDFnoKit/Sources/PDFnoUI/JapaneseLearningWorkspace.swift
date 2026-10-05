// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFnoDomain

/// Review surface; the Mac host supplies native source-return and independent persistence.
/// All source-return/emphasis/persistence actions are optional, explicit host integrations.
@MainActor
public struct JapaneseLearningWorkspace: View {
    @ObservedObject private var learning: JapaneseLearningModel
    private let returnToSource: ((AISourceSnapshot) -> Void)?
    private let emphasize: ((AISourceSnapshot, JapaneseSpan) -> Void)?
    @State private var confirmed = false
    public init(learning: JapaneseLearningModel, returnToSource: ((AISourceSnapshot) -> Void)? = nil,
                emphasize: ((AISourceSnapshot, JapaneseSpan) -> Void)? = nil) {
        self.learning = learning; self.returnToSource = returnToSource; self.emphasize = emphasize
    }
    public var body: some View {
        ScrollViewReader { proxy in
        Form {
            if let request = learning.request {
                Section("固定来源 · 日语选文") {
                    PDFnoTextViewport(text: request.source.anchor.quote, identifier: "japanese-learning-source")
                    Text(request.source.anchor.locationLabel).foregroundStyle(.secondary)
                    Text("原文不修改；作者 ruby、生成建议、用户修正和笔记分别保留。")
                    if let returnToSource {
                        Button("回到固定原文") {
                            learning.cancel()
                            if let source = learning.currentSourceForReturn() { returnToSource(source) }
                        }.accessibilityIdentifier("japanese-learning-return")
                    }
                }
                Section("本次接收方、范围与费用") {
                    Text(verbatim: request.provider.mode == .mock ? "本地 mock · 不联网、不代表语言质量" :
                        "DeepSeek · https://api.deepseek.com/chat/completions · \(request.provider.model)")
                    Text(verbatim: "仅此选文 \(request.source.anchor.quote.utf16.count) / 500 UTF-16；输出最多1024 tokens；最多30秒。共享阅读选文额度已用 \(learning.attemptsUsed) / 3，包含翻译、解释和日语学习；失败和取消也计次数。费用未知，已发请求可能收费；无自动重试。").accessibilityIdentifier("japanese-learning-budget")
                    Toggle("我确认固定选文、接收方、预算及可能费用", isOn: $confirmed)
                        .accessibilityIdentifier("japanese-learning-consent")
                    Button("开始日语学习") { learning.start(confirmed: confirmed); confirmed = false }
                        .disabled(!confirmed || !learning.canStart)
                        .buttonStyle(PDFnoActionStyle(role: .primary)).accessibilityIdentifier("japanese-learning-start")
                    if learning.busy { Button("取消请求") { learning.cancel(); confirmed = false }.accessibilityIdentifier("japanese-learning-cancel") }
                }
            } else { PDFnoEmptyState(title: "尚未固定日语选文", detail: "先在 PDF / EPUB 原文中选择一小段日语，然后重新固定选文。") }
            PDFnoStatusMessage(text: learning.status, kind: learning.busy ? .busy : .information, identifier: "japanese-learning-status").id("japanese-task-state")
            if let error = learning.error { PDFnoStatusMessage(text: error, kind: .error, identifier: "japanese-learning-error") }
            if let review = learning.review {
                Section("结果仅供审阅 · \(review.provider.mode == .mock ? "本地 mock" : "模型建议")") {
                    Text("逐字范围校验通过不等于读音或语法正确。中文译文与语法说明各自展示。")
                    if let translation = review.translationZh { Text(verbatim: translation).textSelection(.enabled).accessibilityIdentifier("japanese-learning-translation") }
                    ForEach(Array(review.warnings.enumerated()), id: \.offset) { _, warning in
                        Text(verbatim: warning).foregroundStyle(.orange)
                    }
                }
                .id("japanese-current-review")
                Section("原句成分分色 · 候选") { JapaneseSentenceComponentsView(review: review) }
                if !review.authorReadings.isEmpty {
                    Section("作者 ruby · 保留原有内容") {
                        ForEach(Array(review.authorReadings.enumerated()), id: \.offset) { _, item in
                            Text(verbatim: item.span.quote + " → " + item.reading)
                        }
                    }
                }
                Section("词语读音 · 生成建议") {
                    ForEach(review.readings) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: item.span.quote + " → " + item.candidates.joined(separator: " / ")).accessibilityIdentifier("japanese-learning-reading")
                            if item.ambiguous { Text("上下文有歧义 · 尚未确定读音").foregroundStyle(.orange) }
                            if !item.explanationZh.isEmpty { Text(verbatim: item.explanationZh) }
                            Text(verbatim: "原文 code point [\(item.span.start), \(item.span.end))")
                            TextField("你的假名修正（独立保存）", text: Binding(
                                get: { learning.readingCorrections[item.span.correctionKey] ?? "" },
                                set: { learning.readingCorrections[item.span.correctionKey] = $0 })).accessibilityIdentifier("japanese-learning-correction")
                            if let emphasize {
                                Button("在原文强调此词") {
                                    if let source = learning.emphasisSource(for: item.span) { emphasize(source, item.span) }
                                }
                            }
                        }
                    }
                }
                Section("中文语法解释 · 生成建议") {
                    ForEach(review.grammar) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: item.span.quote + " · " + item.labelZh)
                            Text(verbatim: item.explanationZh).textSelection(.enabled).accessibilityIdentifier("japanese-learning-grammar")
                            if let emphasize {
                                Button("在原文强调此结构") {
                                    if let source = learning.emphasisSource(for: item.span) { emphasize(source, item.span) }
                                }
                            }
                        }
                    }
                }
                Section("手动保存独立记录") {
                    TextField("你的笔记（不会被再分析覆盖）", text: $learning.userText, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("japanese-learning-user-note")
                    Text("保存内容：固定原文及锚点、模型建议与警告、你的假名修正和独立笔记。此组件不会自动写入原书或已有笔记。")
                    Button("保存审阅后的学习记录") { Task { _ = await learning.save() } }
                        .buttonStyle(PDFnoActionStyle(role: .primary)).disabled(!learning.canSave).accessibilityIdentifier("japanese-learning-save")
                    Text("只有点击保存才创建独立学习笔记；保存后可从当前书籍的“高亮与笔记”查看并回到原文。")
                }
            }
        }.font(PDFnoDesign.TypeStyle.body).accessibilityIdentifier("japanese-learning-form").formStyle(.grouped).navigationTitle("日语选文学习")
        .onChange(of: learning.confirmationRevision) { _, _ in confirmed = false }
        .onChange(of: learning.review?.requestID) { _, id in if id != nil { proxy.scrollTo("japanese-current-review", anchor: .top) } }
        .toolbar { ToolbarItem { Button("查看结果／错误") { proxy.scrollTo(learning.review == nil ? "japanese-task-state" : "japanese-current-review", anchor: .top) }.accessibilityIdentifier("japanese-learning-show-result") } }
        .onDisappear { learning.cancel(); confirmed = false }
        }
    }
}
