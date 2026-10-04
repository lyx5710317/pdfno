// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFnoDomain
import PDFnoServices

public struct BYOKSettingsView: View {
    @ObservedObject private var model: BYOKSettingsModel
    @State private var applying = false
    public init(model: BYOKSettingsModel) { self.model = model }
    public var body: some View {
        Form {
            Text("配置只在本次会话保存。填写地址、模型或密钥不会发送请求。关闭应用后需要重新输入；持久 Keychain 尚未启用。")
            Button("使用官方 DeepSeek 默认配置") { model.draft = DeepSeekSelectionPolicy.configuration() }
                .accessibilityIdentifier("byok-deepseek-default")
            TextField("服务名称", text: $model.draft.label).accessibilityIdentifier("byok-label")
            TextField("HTTPS endpoint（基础路径或完整 chat/completions）", text: $model.draft.endpoint)
                .accessibilityIdentifier("byok-endpoint")
            TextField("模型标识", text: $model.draft.model).accessibilityIdentifier("byok-model")
            if let url = try? BYOKSelectionPolicy.finalURL(model.draft) {
                Text("实际接收域名：\(url.host ?? "")").font(.headline).textSelection(.enabled)
                    .accessibilityIdentifier("byok-receiver-domain")
                Text(url.absoluteString).font(.caption.monospaced()).textSelection(.enabled)
                Text((try? BYOKSelectionPolicy.capability(model.draft).explanation) ?? "")
            } else { Text("仅 HTTPS；不能包含 URL 用户名、密码、查询或片段。不跟随任何重定向。") }
            SecureField("本次会话临时 API key", text: $model.temporarySecret).accessibilityIdentifier("byok-session-key")
            Text(model.hasSessionCredential ? "已有会话密钥；重新应用配置时需要重新输入。" : "未配置会话密钥")
            HStack {
                Button("应用本次会话配置") {
                    applying = true
                    Task { await model.apply(); applying = false }
                }.disabled(applying).accessibilityIdentifier("byok-apply")
                Button("清除临时密钥") { Task { await model.clearCredential() } }.disabled(applying)
                    .accessibilityIdentifier("byok-clear-key")
            }
            Text(model.status).accessibilityIdentifier("byok-settings-status")
            if let error = model.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("byok-error") }
        }
        .formStyle(.grouped)
        .task { await model.load() }
        .onDisappear { model.invalidate() }
    }
}
/// Host freezes a source through prepareSelection before presenting this component.
/// Host must invalidate the model on source/session changes and validate navigation itself.
public struct BYOKSelectionConsentView: View {
    @ObservedObject private var model: BYOKSettingsModel
    private let sourceIsCurrent: @MainActor (AISourceSnapshot) -> Bool
    @State private var confirmed = false
    public init(model: BYOKSettingsModel, sourceIsCurrent: @escaping @MainActor (AISourceSnapshot) -> Bool) {
        self.model = model; self.sourceIsCurrent = sourceIsCurrent
    }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preview = model.preview {
                Text("实际接收域名：\(preview.receiverDomain)").font(.headline).textSelection(.enabled)
                    .accessibilityIdentifier("byok-consent-domain")
                Text(preview.receiverURL.absoluteString).font(.caption.monospaced()).textSelection(.enabled)
                Text("模型：\(preview.request.provider.model) · \(preview.request.kind == .translate ? "翻译" : "解释")")
                Text(preview.request.source.anchor.locationLabel)
                Text("将发送的完整选文（\(preview.sourceText.utf16.count)/500 UTF-16）：")
                ScrollView { Text(preview.sourceText).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled) }
                    .frame(maxHeight: 180).accessibilityIdentifier("byok-consent-source")
                Text(preview.capability.explanation).font(.caption)
                Text("最多1024输出token、30秒、应用会话共3次阅读请求；失败和取消也计数，不自动重试。服务可能收费。")
                Toggle("我确认上述域名、模型、完整选文和费用范围，允许发送一次", isOn: $confirmed)
                    .accessibilityIdentifier("byok-confirm")
                Button("发送本次选文") { model.start(confirmed: confirmed, sourceIsCurrent: sourceIsCurrent); confirmed = false }
                    .disabled(!confirmed || model.busy || !model.hasSessionCredential || model.attemptsUsed >= DeepSeekSelectionPolicy.maxAttempts)
                    .accessibilityIdentifier("byok-send")
            } else { Text("请由阅读器重新固定 PDF/EPUB 选文并核对配置。") }
            if model.busy { Button("取消") { model.invalidate() }.accessibilityIdentifier("byok-cancel") }
            Text("本应用会话已用阅读请求：\(model.attemptsUsed)/3")
            Text(model.status)
            if let error = model.error { Text(error).foregroundStyle(.red) }
            if let result = model.result { Text(result.text).textSelection(.enabled).accessibilityIdentifier("byok-result") }
        }
        .onChange(of: model.preview) { _, _ in confirmed = false }
        .onDisappear { model.invalidate() }
    }
}
