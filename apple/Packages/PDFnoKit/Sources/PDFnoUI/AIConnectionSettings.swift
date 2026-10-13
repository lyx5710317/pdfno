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
    private enum Provider: String, CaseIterable { case deepSeek = "DeepSeek", compatible = "OpenAI 兼容", mock = "本地示例" }
    private var provider: Provider {
        draft.mode == .mock ? .mock : DeepSeekSelectionPolicy.supports(draft) ? .deepSeek : .compatible
    }
    init(learning: AILearningModel, draft: Binding<AIProviderConfig>, secret: Binding<String>, active: Bool = true) {
        self.learning = learning; self.active = active; _draft = draft; _secret = secret
    }
    var body: some View {
        PDFnoSettingsCard("配置api",symbol: "sparkles") {
            if let legacy = learning.legacyConnectionConfiguration {
                Text("检测到两套配置api，请选择保留哪一套。")
                Text("当前：\((try? BYOKSelectionPolicy.finalURL(learning.config).host) ?? "未配置") · \(learning.config.model)").font(.caption)
                Text("旧配置：\((try? BYOKSelectionPolicy.finalURL(legacy).host) ?? "未配置") · \(legacy.model)").font(.caption)
                HStack {
                    Button("保留当前") { Task { await learning.chooseLegacyConnection(useLegacy: false); draft = learning.config } }
                    Button("使用旧配置") { Task { await learning.chooseLegacyConnection(useLegacy: true); draft = learning.config } }
                }.accessibilityIdentifier("ai-configuration-conflict")
            }
            Picker("服务商",selection: Binding(get: { provider }, set: { preset($0) })) { ForEach(Provider.allCases,id: \.self) { Text($0.rawValue).tag($0) } }.accessibilityIdentifier("ai-provider-mode")
            PDFnoSettingsField("API URL") { TextField("HTTPS API 地址",text: $draft.endpoint).disabled(draft.mode == .mock).accessibilityIdentifier("ai-endpoint") }
            PDFnoSettingsField("API Key") { SecureField(learning.hasSessionCredential ? "已配置 · 留空保留" : "仅保留在本次应用会话",text: $secret).disabled(draft.mode == .mock).accessibilityIdentifier("ai-session-key") }
            PDFnoSettingsField("模型") { TextField("服务商提供的模型名称",text: $draft.model).disabled(draft.mode == .mock).accessibilityIdentifier("ai-model") }
            if draft.mode == .mock { Text("本地示例不联网，不使用 API URL 或 Key。").font(.caption).foregroundStyle(.secondary) }
            else { Text(learning.hasSessionCredential ? "本次会话已配置 API Key" : "填写后点击应用连接；所有 AI 功能共用此配置。").font(.caption).foregroundStyle(.secondary).accessibilityIdentifier("ai-credential-status") }
            HStack {
                Button("应用连接") {
                    var candidate = draft
                    if candidate.mode == .unconfigured { candidate.mode = .openAICompatible; candidate.label = "OpenAI 兼容" }
                    Task { if await learning.applyConnection(candidate,temporarySecret: secret) { secret = ""; draft = learning.config } }
                }
                    .buttonStyle(.borderedProminent).accessibilityIdentifier("ai-settings-save").disabled(learning.connectionBusy || learning.legacyConnectionConfiguration != nil)
                Button("测试连接") {
                    if learning.config.mode == .mock { learning.testConnection(confirmed: true) } else { confirmTest = true }
                }.accessibilityIdentifier("ai-connection-test").disabled(learning.connectionBusy || !ReadingSkillIdentity.matches(draft,learning.config) || !learning.conversationConnectionAvailable)
                if learning.connectionBusy { Button("停止") { learning.cancelConnectionProbe() }.accessibilityIdentifier("ai-connection-stop") }
            }
            Text(learning.connectionStatus).font(.caption).accessibilityIdentifier("ai-connection-status")
            if let error = learning.error { PDFnoStatusMessage(text: error,kind: .error,identifier: "ai-settings-error") }
            Button { advanced.toggle() } label: {
                Label("高级",systemImage: advanced ? "chevron.down" : "chevron.right")
                    .frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityIdentifier("ai-connection-advanced")
                .accessibilityValue(advanced ? "已展开" : "已收起")
            if advanced {
                PDFnoSettingsField("服务名称") { TextField("服务名称",text: $draft.label).accessibilityIdentifier("ai-provider-label") }
                if let url = try? BYOKSelectionPolicy.finalURL(draft) { Text(verbatim: "请求地址：" + url.absoluteString).font(.caption).textSelection(.enabled).fixedSize(horizontal: false,vertical: true) }
                Text("选文对话发送固定选文；全文对话经单独确认发送当前完整文档。API Key 仅保留在本次应用会话。").font(.caption).foregroundStyle(.secondary)
                Text("阅读请求共用本次会话额度；连接测试单独计数。请求失败或取消也计数，不自动重试。").font(.caption).foregroundStyle(.secondary)
                if learning.hasSessionCredential { Button("清除 API Key") { secret = ""; Task { await learning.clearSessionCredential() } }.accessibilityIdentifier("ai-clear-key") }
            }
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
        }
    }
}
#endif
