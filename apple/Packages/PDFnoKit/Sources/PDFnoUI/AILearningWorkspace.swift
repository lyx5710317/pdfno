// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoServices

struct AISettingsView: View {
    @ObservedObject var learning: AILearningModel
    @Environment(\.dismiss) private var dismiss
    @State private var draft: AIProviderConfig
    @State private var secret = ""
    init(learning: AILearningModel) { self.learning = learning; _draft = State(initialValue: learning.config) }
    var body: some View {
        NavigationStack {
            Form {
                Text("真实 AI 请求尚未启用；本地 mock 可验证选文、引用与笔记闭环。").accessibilityIdentifier("ai-network-status")
                Picker("服务类型", selection: $draft.mode) {
                    Text("未配置").tag(AIProviderMode.unconfigured)
                    Text("本地 mock 示例").tag(AIProviderMode.mock)
                    Text("OpenAI-compatible（配置预览）").tag(AIProviderMode.openAICompatible)
                }.accessibilityIdentifier("ai-provider-mode")
                Button("使用本地 mock 示例") { draft.mode = .mock; draft.label = "本地 mock"; draft.model = "synthetic-selection-1"; draft.endpoint = ""; secret = "" }
                    .accessibilityIdentifier("ai-use-mock")
                TextField("服务名称", text: $draft.label).accessibilityIdentifier("ai-provider-label")
                TextField("API endpoint", text: $draft.endpoint).accessibilityIdentifier("ai-endpoint")
                TextField("模型", text: $draft.model).accessibilityIdentifier("ai-model")
                if draft.mode == .openAICompatible {
                    if let url = try? OpenAICompatibleSelectionProvider.finalURL(draft) { Text(verbatim: "最终 API 路径：" + url.absoluteString).font(.caption) }
                    SecureField("临时演示密钥（可选）", text: $secret).accessibilityIdentifier("ai-session-key")
                    Text("密钥输入只留在当前会话，不写入普通文件或持久钥匙串。关闭应用后需要重新输入。真实服务、内容与费用验证尚未完成。")
                }
                Text("仅选文；无隐含上下文、整页或整章。mock 不联网且费用为零；真实服务费用未知。")
                if let error = learning.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("ai-settings-error") }
            }.padding().navigationTitle("模型与 BYOK 设置")
            .toolbar {
                ToolbarItem { Button("取消") { secret = ""; dismiss() }.accessibilityIdentifier("ai-settings-cancel") }
                ToolbarItem { Button("保存配置") { Task { if await learning.saveConfig(draft, temporarySecret: secret) { secret = ""; dismiss() } } }
                    .accessibilityIdentifier("ai-settings-save") }
            }
        }.frame(minWidth: 480, minHeight: 440)
    }
}
struct AILearningWorkspace: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var learning: AILearningModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmed = false
    var body: some View {
        NavigationStack {
            List {
                Section("本次固定选文") {
                    if let source = learning.source {
                        Text(verbatim: source.anchor.quote).textSelection(.enabled).accessibilityIdentifier("ai-source-quote")
                        Text(source.anchor.locationLabel).font(.caption).accessibilityIdentifier("ai-source-location")
                        Text("\(source.anchor.quote.utf16.count) UTF-16 单位 · 不附加其他上下文")
                    } else { Text("先在 PDF / EPUB 原文中选择文字，再打开选文学习。") }
                }
                Section("任务与处理范围") {
                    Picker("任务", selection: $learning.kind) {
                        Text("选文翻译").tag(AILearningKind.translate); Text("选文解释").tag(AILearningKind.explain)
                    }.accessibilityIdentifier("ai-kind")
                    Text(verbatim: learning.config.mode == .mock ? "本地 mock · 不联网 · 费用 0" : "未配置或真实服务未启用 · 不会发送")
                        .accessibilityIdentifier("ai-provider-status")
                    Text(verbatim: "服务：" + learning.config.label + " · 模型：" + learning.config.model)
                    Toggle("确认仅处理上方选文及当前服务／模型", isOn: $confirmed).accessibilityIdentifier("ai-scope-consent")
                    Button("开始") { learning.start(confirmed: confirmed, sourceIsCurrent: library.isCurrentAISource) }
                        .disabled(!confirmed || learning.source == nil || learning.busy).accessibilityIdentifier("ai-start")
                    if learning.busy { Button("取消请求") { learning.cancel() }.accessibilityIdentifier("ai-cancel") }
                    Text(learning.status).accessibilityIdentifier("ai-task-status")
                    if let error = learning.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("ai-error") }
                }
                if let result = learning.result {
                    Section("结果 · \(result.provider.mode == .mock ? "本地 mock" : "模型生成")") {
                        Text(verbatim: result.text).textSelection(.enabled).accessibilityIdentifier("ai-result")
                        Button("引用 · 回到原文") { Task { learning.cancel(); if await library.returnToAISource(result.source) { dismiss() } } }
                            .accessibilityIdentifier("ai-result-source")
                        TextField("你的笔记（独立保存）", text: $learning.userText, axis: .vertical).accessibilityIdentifier("ai-user-note")
                        Button("保存学习笔记") { Task { _ = await learning.save(sourceIsCurrent: library.isCurrentAISource) } }
                            .disabled(learning.notes.contains { $0.result.requestID == result.requestID }).accessibilityIdentifier("ai-save-note")
                    }
                }
                Section("已保存学习笔记 · 本地") {
                    ForEach(learning.notes.filter { $0.result.source.bookID == library.currentAIBookID }) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: note.result.source.anchor.quote).accessibilityIdentifier("ai-saved-quote")
                            Text(verbatim: note.result.text).foregroundStyle(.secondary).accessibilityIdentifier("ai-saved-result")
                            if !note.userText.isEmpty { Text(verbatim: note.userText).accessibilityIdentifier("ai-saved-user-note") }
                            Button("引用 · 回到原文") { Task { learning.cancel(); if await library.returnToAISource(note.result.source) { dismiss() } } }
                                .accessibilityIdentifier("ai-saved-source")
                        }
                    }
                }
            }.navigationTitle("选文学习")
            .toolbar { ToolbarItem { Button("完成（取消未完成请求）") { learning.cancel(); dismiss() }.accessibilityIdentifier("ai-close") } }
        }.frame(minWidth: 440, minHeight: 600)
        .onChange(of: learning.kind) { _, _ in learning.cancel(); learning.result = nil; confirmed = false }
        .onChange(of: learning.config) { _, _ in learning.cancel(); learning.result = nil; confirmed = false }
        .onDisappear { learning.cancel() }
    }
}
#endif
