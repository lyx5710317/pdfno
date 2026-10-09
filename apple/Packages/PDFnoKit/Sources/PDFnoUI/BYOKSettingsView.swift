// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFnoDomain
import PDFnoServices

public struct BYOKSettingsView: View {
    @ObservedObject private var model: BYOKSettingsModel
    @State private var applying = false
    private let loadOnAppear: Bool
    public init(model: BYOKSettingsModel, loadOnAppear: Bool = true) { self.model = model; self.loadOnAppear = loadOnAppear }
    public var body: some View {
        #if os(macOS)
        ScrollView {
            VStack(alignment: .leading, spacing: PDFnoDesign.Space.regular) {
                PDFnoStatusMessage(text: "配置只在本次会话保存；填写不会发送请求。此身份仅供独立 HTTPS BYOK 选文入口，不切换其他阅读工具。持久 Keychain 尚未启用。")
                PDFnoSettingsCard("独立 HTTPS 服务与模型", symbol: "network") {
                    Button("使用官方 DeepSeek 默认配置") { model.draft = DeepSeekSelectionPolicy.configuration() }
                        .accessibilityIdentifier("byok-deepseek-default")
                    PDFnoSettingsField("服务名称") { TextField("服务名称", text: $model.draft.label).accessibilityIdentifier("byok-label") }
                    PDFnoSettingsField("HTTPS endpoint（基础路径或完整 chat/completions）") {
                        TextField("HTTPS endpoint（基础路径或完整 chat/completions）", text: $model.draft.endpoint).accessibilityIdentifier("byok-endpoint")
                    }
                    PDFnoSettingsField("模型标识") { TextField("模型标识", text: $model.draft.model).accessibilityIdentifier("byok-model") }
                }
                PDFnoSettingsCard("会话密钥", symbol: "lock") {
                    PDFnoSettingsField("本次会话临时 API key") {
                        SecureField("本次会话临时 API key", text: $model.temporarySecret).accessibilityIdentifier("byok-session-key")
                    }
                    Text(model.hasSessionCredential ? "已有会话密钥；重新应用配置时需要重新输入。" : "未配置会话密钥")
                    // Keep one stable action stack; no duplicated responsive controls.
                    VStack(alignment: .leading, spacing: PDFnoDesign.Space.small) {
                        Button("应用本次会话配置") {
                            applying = true
                            Task { await model.apply(); applying = false }
                        }.disabled(applying).accessibilityIdentifier("byok-apply")
                        Button("清除临时密钥") { Task { await model.clearCredential() } }.disabled(applying)
                            .accessibilityIdentifier("byok-clear-key")
                    }
                }
                PDFnoSettingsCard("状态与依赖") {
                    PDFnoStatusMessage(text: model.status, kind: applying ? .busy : .information, identifier: "byok-settings-status")
                    if let error = model.error { PDFnoStatusMessage(text: error, kind: .error, identifier: "byok-error") }
                }
                PDFnoSettingsCard("接收方预览") {
                    if let url = try? BYOKSelectionPolicy.finalURL(model.draft) {
                        Text("实际接收域名：\(url.host ?? "")").font(.headline).textSelection(.enabled)
                            .accessibilityIdentifier("byok-receiver-domain")
                        Text(url.absoluteString).font(.caption.monospaced()).textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                        Text((try? BYOKSelectionPolicy.capability(model.draft).explanation) ?? "")
                    } else { Text("仅 HTTPS；不能包含 URL 用户名、密码、查询或片段。不跟随任何重定向。") }
                }
            }.textFieldStyle(.roundedBorder).padding(PDFnoDesign.Space.section)
        }.background(PDFnoDesign.Palette.chrome)
            .preference(key: PDFnoWorkspaceBusyKey.self, value: applying)
            .task { if loadOnAppear { await model.load() } }.onDisappear { model.invalidate() }
        #else
        originalForm
        #endif
    }
    private var originalForm: some View {
        Form {
            PDFnoStatusMessage(text: "配置只在本次会话保存。填写地址、模型或密钥不会发送请求。关闭应用后需要重新输入；持久 Keychain 尚未启用。")
            Section("服务与模型") {
                Button("使用官方 DeepSeek 默认配置") { model.draft = DeepSeekSelectionPolicy.configuration() }
                    .accessibilityIdentifier("byok-deepseek-default")
                TextField("服务名称", text: $model.draft.label).accessibilityIdentifier("byok-label")
                TextField("HTTPS endpoint（基础路径或完整 chat/completions）", text: $model.draft.endpoint)
                    .accessibilityIdentifier("byok-endpoint")
                TextField("模型标识", text: $model.draft.model).accessibilityIdentifier("byok-model")
            }
            Section("会话密钥") {
                SecureField("本次会话临时 API key", text: $model.temporarySecret).accessibilityIdentifier("byok-session-key")
                Text(model.hasSessionCredential ? "已有会话密钥；重新应用配置时需要重新输入。" : "未配置会话密钥")
                VStack(alignment: .leading, spacing: PDFnoDesign.Space.small) {
                    Button("应用本次会话配置") {
                        applying = true
                        Task { await model.apply(); applying = false }
                    }.disabled(applying).accessibilityIdentifier("byok-apply")
                    Button("清除临时密钥") { Task { await model.clearCredential() } }.disabled(applying)
                        .accessibilityIdentifier("byok-clear-key")
                }
            }
            Section("状态") {
                PDFnoStatusMessage(text: model.status, kind: applying ? .busy : .information, identifier: "byok-settings-status")
                if let error = model.error { PDFnoStatusMessage(text: error, kind: .error, identifier: "byok-error") }
            }
            Section("接收方预览") {
                if let url = try? BYOKSelectionPolicy.finalURL(model.draft) {
                    Text("实际接收域名：\(url.host ?? "")").font(.headline).textSelection(.enabled)
                        .accessibilityIdentifier("byok-receiver-domain")
                    Text(url.absoluteString).font(.caption.monospaced()).textSelection(.enabled)
                    Text((try? BYOKSelectionPolicy.capability(model.draft).explanation) ?? "")
                } else { Text("仅 HTTPS；不能包含 URL 用户名、密码、查询或片段。不跟随任何重定向。") }
            }
        }
        .font(PDFnoDesign.TypeStyle.body).formStyle(.grouped)
        .task { if loadOnAppear { await model.load() } }
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
                #if os(macOS)
                Text(preview.request.source.anchor.locationLabel)
                Text("将发送的完整选文（\(preview.sourceText.utf16.count)/500 UTF-16）：")
                PDFnoTextViewport(text: preview.sourceText, identifier: "byok-consent-source")
                Text("实际接收域名：\(preview.receiverDomain)").font(.headline).textSelection(.enabled)
                    .accessibilityIdentifier("byok-consent-domain")
                Text(preview.receiverURL.absoluteString).font(.caption.monospaced()).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                Text("模型：\(preview.request.provider.model) · \(preview.request.kind == .translate ? "翻译" : "解释")")
                #else
                Text("实际接收域名：\(preview.receiverDomain)").font(.headline).textSelection(.enabled)
                    .accessibilityIdentifier("byok-consent-domain")
                Text(preview.receiverURL.absoluteString).font(.caption.monospaced()).textSelection(.enabled)
                Text("模型：\(preview.request.provider.model) · \(preview.request.kind == .translate ? "翻译" : "解释")")
                Text(preview.request.source.anchor.locationLabel)
                Text("将发送的完整选文（\(preview.sourceText.utf16.count)/500 UTF-16）：")
                PDFnoTextViewport(text: preview.sourceText, identifier: "byok-consent-source")
                #endif
                if preview.request.profile == .paragraphExplanation { Text("段落解释 · 简体中文 · 释义／术语／模型推断与原文依据分开；真实质量待人工审阅。只发送上述原文及固定段落解释指令，无额外上下文。") }
                Text(preview.capability.explanation).font(.caption)
                Text("最多1024输出token、30秒、应用会话共3次阅读请求；失败和取消也计数，不自动重试。服务可能收费。")
                Toggle("我确认上述域名、模型、完整选文和费用范围，允许发送一次", isOn: $confirmed)
                    .accessibilityIdentifier("byok-confirm")
                Button("发送本次选文") { model.start(confirmed: confirmed, sourceIsCurrent: sourceIsCurrent); confirmed = false }
                    .disabled(!confirmed || model.busy || !model.hasSessionCredential || model.attemptsUsed >= DeepSeekSelectionPolicy.maxAttempts)
                    .buttonStyle(PDFnoActionStyle(role: .primary)).accessibilityIdentifier("byok-send")
                if !model.hasSessionCredential { Text("请先应用带会话密钥的配置。") }
                else if model.attemptsUsed >= DeepSeekSelectionPolicy.maxAttempts { Text("本次会话阅读请求次数已用完。") }
                else if !confirmed && !model.busy { Text("核对范围并勾选确认后可发送。") }
            } else { PDFnoEmptyState(title: "尚未固定选文", detail: "请由阅读器重新固定 PDF/EPUB 选文并核对配置。") }
            if model.busy { Button("取消") { model.invalidate() }.accessibilityIdentifier("byok-cancel") }
            Text("本应用会话已用阅读请求：\(model.attemptsUsed)/3")
            PDFnoStatusMessage(text: model.status, kind: model.busy ? .busy : .information)
            if let error = model.error { PDFnoStatusMessage(text: error, kind: .error) }
            if let result = model.result, result.paragraphExplanation == nil { PDFnoTextViewport(text: result.displayText, identifier: "byok-result", height: 220) }
        }
        .onChange(of: model.preview) { _, _ in confirmed = false }
        .onDisappear { model.invalidate() }
    }
}
