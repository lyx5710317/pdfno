// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFnoDomain
import PDFnoServices

/// Standalone host-injected surface; no implicit request, source navigation or persistence.
public struct EnglishLearningWorkspace: View {
    @ObservedObject private var model: EnglishLearningModel
    private let returnToSource: (@MainActor (AISourceSnapshot) -> Void)?
    @State private var confirmed = false
    private var remote: Bool { model.request?.provider.mode == .openAICompatible }
    public init(model: EnglishLearningModel, returnToSource: (@MainActor (AISourceSnapshot) -> Void)? = nil) {
        self.model = model; self.returnToSource = returnToSource
    }
    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(remote ? "英语语法 · 固定选文 AI" : "英语语法 · 离线合成演示")
                    .font(.title2).accessibilityIdentifier("english-learning-title")
                if remote {
                    Text("仅发送本次固定选文。英语语法与译文是待核对建议，真实服务质量尚未验收。")
                        .foregroundStyle(.secondary)
                } else {
                    Text("离线合成演示仅对内置原创语料提供预写候选，不联网，不证明模型或语法质量。")
                        .foregroundStyle(.secondary)
                }
                if let request = model.request {
                    Text(request.source.anchor.locationLabel).font(.headline)
                    Text(verbatim: request.source.anchor.quote).textSelection(.enabled)
                        .accessibilityIdentifier("english-learning-fixed-source")
                    Text("固定选文 \(request.source.anchor.quote.utf16.count) / 500 UTF-16 · 输出候选上限 1024 tokens · 30 秒。完整 JSON 若超限或截断，将拒绝结果，不自动重试。")
                    Text(verbatim: "服务：" + request.provider.label + " · 提示词：" + EnglishLearningPolicy.promptVersion)
                    if remote {
                        Text(verbatim: "接收方：" + ((try? DeepSeekSelectionProvider.finalURL(request.provider).absoluteString) ?? request.provider.endpoint) + " · 模型：" + request.provider.model)
                        Text("共享选文额度：\(model.attemptsUsed) / 3 次。网络尝试失败、取消或超时仍计次数并可能收费；客户端不保证人民币账单上限。点击开始即确认本次服务费用，未确认不会发送。")
                            .accessibilityIdentifier("english-learning-remote-limits")
                    }
                    Toggle(remote ? "确认原文、接收方、模型、本次费用与处理范围" : "确认固定原文与离线演示范围", isOn: $confirmed)
                        .accessibilityIdentifier("english-learning-confirm")
                    HStack {
                        Button(remote ? "开始英语分析" : "开始离线分析") { model.start(confirmed: confirmed) }
                            .disabled(!confirmed || !model.canStart).accessibilityIdentifier("english-learning-start")
                        Button("取消") { model.cancel() }.disabled(!model.busy)
                        Button("回到原文") {
                            if let source = model.currentSourceForReturn() { returnToSource?(source) }
                        }.disabled(returnToSource == nil).accessibilityIdentifier("english-learning-return-source")
                    }
                }
                Text(model.status).accessibilityIdentifier("english-learning-status")
                if let error = model.error { Text(verbatim: error).foregroundStyle(.red).accessibilityIdentifier("english-learning-error") }
                if let review = model.review {
                    if review.status != .unavailable {
                        EnglishSentenceComponentsView(review: review)
                        if let translation = review.translationZh {
                            Text("自然译文候选").font(.headline)
                            Text(verbatim: translation).textSelection(.enabled)
                        }
                        ForEach(review.grammar) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.aspect.labelZh + (item.ambiguous ? " · 不确定" : " · 候选")).font(.headline)
                                Text(verbatim: item.span.quote).textSelection(.enabled)
                                Text(verbatim: item.explanationZh).textSelection(.enabled)
                            }.accessibilityIdentifier("english-grammar-" + item.aspect.rawValue)
                        }
                    }
                    ForEach(Array(review.warnings.enumerated()), id: \.offset) { _, warning in
                        Text(verbatim: warning).foregroundStyle(.secondary)
                    }
                }
                Text("用户学习正文").font(.headline)
                TextEditor(text: $model.userText).frame(minHeight: 100).disabled(model.saving)
                    .accessibilityIdentifier("english-learning-user-text")
                Text("保存将保留原文、来源、生成审阅和独立用户正文。修改或重新分析不会覆盖用户正文。")
                    .foregroundStyle(.secondary)
                Button(model.saved ? "已保存学习记录" : "保存学习记录") { Task { _ = await model.save() } }
                    .disabled(!model.canSave).accessibilityIdentifier("english-learning-save")
            }.padding()
        }.accessibilityIdentifier("english-learning-form")
            .onChange(of: model.confirmationRevision) { _, _ in confirmed = false }
            .onDisappear { model.cancel() }
    }
}
