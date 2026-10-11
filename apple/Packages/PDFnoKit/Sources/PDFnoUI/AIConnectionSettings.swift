// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoServices

struct AIConnectionSettings: View {
    @ObservedObject var learning: AILearningModel
    var active = true
    @Binding private var draft: AIProviderConfig
    @Binding private var secret: String
    @State private var advanced = false
    @State private var confirmTest = false
    private enum Provider: String, CaseIterable { case deepSeek = "DeepSeek", compatible = "OpenAI 兼容", mock = "本地示例", unconfigured = "未配置" }
    private var provider: Provider {
        draft.mode == .mock ? .mock : draft.mode == .unconfigured ? .unconfigured : DeepSeekSelectionPolicy.supports(draft) ? .deepSeek : .compatible
    }
    init(learning: AILearningModel, draft: Binding<AIProviderConfig>, secret: Binding<String>, active: Bool = true) {
        self.learning = learning; self.active = active; _draft = draft; _secret = secret
    }
    var body: some View {
        PDFnoSettingsCard("AI 连接",symbol: "sparkles") {
            Picker("服务商",selection: Binding(get: { provider }, set: { preset($0) })) { ForEach(Provider.allCases,id: \.self) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("ai-provider-mode")
            if draft.mode == .openAICompatible {
                PDFnoSettingsField("API URL") { TextField("HTTPS API 地址",text: $draft.endpoint).accessibilityIdentifier("ai-endpoint") }
                PDFnoSettingsField("API Key") { SecureField(learning.hasSessionCredential ? "已配置 · 留空保留" : "仅保留在本次应用会话",text: $secret).accessibilityIdentifier("ai-session-key") }
                PDFnoSettingsField("模型") { TextField("服务商提供的模型名称",text: $draft.model).accessibilityIdentifier("ai-model") }
                Text(learning.hasSessionCredential ? "本次会话已配置 API Key" : "需要 API Key").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("ai-credential-status")
            } else if draft.mode == .mock { Text("本地示例不联网，不验证真实 AI 质量。").font(.callout).foregroundStyle(.secondary) }
            HStack {
                Button("应用连接") { Task { if await learning.applyConnection(draft,temporarySecret: secret) { secret = ""; draft = learning.config } } }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("ai-settings-save").disabled(learning.connectionBusy)
                Button("测试连接") {
                    if learning.config.mode == .mock { learning.testConnection(confirmed: true) } else { confirmTest = true }
                }.accessibilityIdentifier("ai-connection-test").disabled(learning.connectionBusy || !ReadingSkillIdentity.matches(draft,learning.config) || !learning.conversationConnectionAvailable)
                if learning.connectionBusy { Button("停止") { learning.cancelConnectionProbe() }.accessibilityIdentifier("ai-connection-stop") }
            }
            Text(learning.connectionStatus).font(.caption).accessibilityIdentifier("ai-connection-status")
            if let error = learning.error { PDFnoStatusMessage(text: error,kind: .error,identifier: "ai-settings-error") }
            DisclosureGroup("高级",isExpanded: $advanced) {
                PDFnoSettingsField("服务名称") { TextField("服务名称",text: $draft.label).accessibilityIdentifier("ai-provider-label") }
                if let url = try? BYOKSelectionPolicy.finalURL(draft) { Text(verbatim: "请求地址：" + url.absoluteString).font(.caption).textSelection(.enabled).fixedSize(horizontal: false,vertical: true) }
                Text("使用 HTTPS chat/completions 与 JSON 返回协议。每次只发送固定选文和该对话的消息；不读取整本书或其他文档。API Key 不写入磁盘；重开应用需重新输入。").font(.caption).foregroundStyle(.secondary)
                Text("阅读请求沿用本次应用共用 3 次上限；连接测试另有 3 次上限。每次最多 1024 输出 tokens、30 秒、64 KiB 响应。失败或取消也计数，不自动重试。").font(.caption).foregroundStyle(.secondary)
                if learning.hasSessionCredential { Button("清除 API Key") { secret = ""; Task { await learning.clearSessionCredential() } }.accessibilityIdentifier("ai-clear-key") }
            }.accessibilityIdentifier("ai-connection-advanced")
        }.textFieldStyle(.roundedBorder)
            .onChange(of: draft.endpoint) { _, _ in secret = ""; learning.cancelConnectionProbe() }
            .onDisappear { secret = ""; learning.cancelConnectionProbe() }
            .onChange(of: active) { _, active in if !active { secret = ""; learning.cancelConnectionProbe() } }
            .confirmationDialog("测试已应用的连接",isPresented: $confirmTest) {
                Button("发送固定短句进行测试") { learning.testConnection(confirmed: true) }
                Button("取消",role: .cancel) {}
            } message: { Text("只发送原创短句：\n" + ReadingConnectionProbe.sentence + "\n使用当前服务、模型和 API Key；服务商可能计费，不发送书籍或对话。") }
    }
    private func preset(_ provider: Provider) {
        secret = ""; learning.cancelConnectionProbe()
        switch provider {
        case .deepSeek: draft = DeepSeekSelectionPolicy.configuration()
        case .compatible: draft.mode = .openAICompatible; draft.label = "OpenAI 兼容"; draft.endpoint = ""; draft.model = ""
        case .mock: draft.mode = .mock; draft.label = "本地 mock"; draft.endpoint = ""; draft.model = "synthetic-conversation-1"
        case .unconfigured: draft.mode = .unconfigured; draft.endpoint = ""; draft.model = ""; draft.label = "未配置"
        }
    }
}
#endif
