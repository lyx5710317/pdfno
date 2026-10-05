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
    @State private var showDeepSeekTest = false
    private let byok: BYOKSettingsModel?
    @State private var showBYOKSettings = false
    init(learning: AILearningModel, byok: BYOKSettingsModel? = nil) { self.learning = learning; self.byok = byok; _draft = State(initialValue: learning.config) }
    var body: some View {
        NavigationStack {
            Form {
                PDFnoStatusMessage(text: "选文翻译／解释支持本地 mock 或官方 DeepSeek；配置和输入密钥不会发送请求，选文窗口确认后由你点击开始。", identifier: "ai-network-status")
                if byok != nil {
                    Button("其他 HTTPS BYOK选文设置") { showBYOKSettings = true }.accessibilityIdentifier("byok-settings-open")
                    Text("独立会话配置只用于BYOK选文入口；不会替换下方DeepSeek、日语、页或章节配置。").font(.caption).foregroundStyle(.secondary)
                }
                Button("DeepSeek 短句自助测试") { showDeepSeekTest = true }.accessibilityIdentifier("ai-deepseek-self-test")
                Section("服务与模型") {
                    Picker("服务类型", selection: $draft.mode) {
                        Text("未配置").tag(AIProviderMode.unconfigured)
                        Text("本地 mock 示例").tag(AIProviderMode.mock)
                        Text("OpenAI-compatible（DeepSeek已支持）").tag(AIProviderMode.openAICompatible)
                    }.accessibilityIdentifier("ai-provider-mode")
                    Button("使用本地 mock 示例") { draft.mode = .mock; draft.label = "本地 mock"; draft.model = "synthetic-selection-1"; draft.endpoint = ""; secret = "" }
                        .accessibilityIdentifier("ai-use-mock")
                    Button("使用 DeepSeek 选文配置") { draft = DeepSeekSelectionPolicy.configuration(); secret = "" }.accessibilityIdentifier("ai-use-deepseek")
                    TextField("服务名称", text: $draft.label).accessibilityIdentifier("ai-provider-label")
                    TextField("API endpoint", text: $draft.endpoint).accessibilityIdentifier("ai-endpoint")
                    TextField("模型", text: $draft.model).accessibilityIdentifier("ai-model")
                }
                Section("会话密钥") {
                    if draft.mode == .openAICompatible {
                        if let url = try? OpenAICompatibleSelectionProvider.finalURL(draft) { Text(verbatim: "最终 API 路径：" + url.absoluteString).font(.caption) }
                        if DeepSeekSelectionPolicy.supports(draft) {
                            SecureField("当前应用会话的临时 API key", text: $secret).accessibilityIdentifier("ai-session-key")
                            Text("由你手动输入；只留在本次应用内存，不写文件或持久钥匙串。保存时新输入会替换会话密钥，留空则清除；重开应用后需重新输入。")
                        } else { Text("此服务仍仅配置预览，不收取密钥或发送阅读请求。本片只开放官方 DeepSeek HTTPS 地址及 deepseek-flash。") }
                    }
                    Text(learning.hasSessionCredential ? "当前会话密钥已输入" : "当前会话密钥未配置").accessibilityIdentifier("ai-credential-status")
                    if learning.hasSessionCredential { Button("清除当前会话密钥") { Task { await learning.clearSessionCredential() } }.accessibilityIdentifier("ai-clear-key") }
                }
                Section("处理范围与状态") {
                    Text("仅选文；无隐含上下文、整页或整章。mock 不联网且费用为零；真实服务费用未知。")
                    if let error = learning.error { PDFnoStatusMessage(text: error, kind: .error, identifier: "ai-settings-error") }
                }
            }.font(PDFnoDesign.TypeStyle.body).formStyle(.grouped).navigationTitle("模型与 BYOK 设置")
                .accessibilityIdentifier("ai-settings-form")
            .toolbar {
                ToolbarItem { Button("取消") { secret = ""; dismiss() }.accessibilityIdentifier("ai-settings-cancel") }
                ToolbarItem { Button("保存配置") { Task { if await learning.saveConfig(draft, temporarySecret: secret) { secret = ""; dismiss() } } }
                    .accessibilityIdentifier("ai-settings-save") }
            }
        }.frame(minWidth: PDFnoDesign.Metric.sheetMinimum, idealWidth: PDFnoDesign.Metric.sheetIdeal, minHeight: 560)
        .sheet(isPresented: $showDeepSeekTest) { DeepSeekSelfTestView(model: learning.deepSeekTest) }
        .sheet(isPresented: $showBYOKSettings) { if let byok { BYOKSettingsSheet(model: byok) } }
        .onChange(of: DeepSeekSelectionPolicy.supports(draft)) { _, supported in if !supported { secret = "" } }
        .onDisappear { secret = "" }
    }
}
struct AILearningWorkspace: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var learning: AILearningModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirmed = false
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            List {
                Section("本次固定选文") {
                    if let source = learning.source {
                        PDFnoTextViewport(text: source.anchor.quote, identifier: "ai-source-quote")
                        Text(source.anchor.locationLabel).font(.caption).accessibilityIdentifier("ai-source-location")
                        Text("\(source.anchor.quote.utf16.count) UTF-16 单位 · 不附加其他上下文")
                    } else { PDFnoEmptyState(title: "尚未固定选文", detail: "先在 PDF / EPUB 原文中选择文字，再打开选文学习。") }
                }
                Section("任务与处理范围") {
                    Picker("任务", selection: $learning.kind) {
                        Text("选文翻译").tag(AILearningKind.translate); Text("选文解释").tag(AILearningKind.explain)
                    }.accessibilityIdentifier("ai-kind")
                    Text(verbatim: learning.config.mode == .mock ? "本地 mock · 不联网 · 费用 0" : DeepSeekSelectionPolicy.supports(learning.config) ? "接收方：DeepSeek 官方 API · 只发送显示的选文及固定任务指令" : "未配置或仅配置预览 · 不会发送")
                        .accessibilityIdentifier("ai-provider-status")
                    Text(verbatim: "服务：" + learning.config.label + " · 模型：" + learning.config.model)
                    if DeepSeekSelectionPolicy.supports(learning.config) {
                        Text(verbatim: "最终地址：" + ((try? DeepSeekSelectionProvider.finalURL(learning.config).absoluteString) ?? "无效"))
                        Text("选文最多500 UTF-16单位 · 输出最多1024 tokens（包括JSON及引文）· 最多30秒 · 不附加上下文或源文件 · 无自动重试")
                        Text("真实服务会计费，金额由服务方计价；客户端不能强制人民币账单上限，取消或失败仍可能计费。请确认服务方费用限制和本次外发内容。")
                        Text("本次应用会话阅读请求已用 \(learning.remoteAttemptsUsed) / 3 次 · 关闭或切书不会重置")
                        Text(learning.hasSessionCredential ? "会话密钥已输入" : "请先在模型设置中手动输入会话密钥").accessibilityIdentifier("ai-reading-key-status")
                        if let source = learning.source, source.anchor.quote.utf16.count > DeepSeekSelectionPolicy.maxSourceUTF16 { Text(AIFailure.remoteInputLimit.localizedDescription).foregroundStyle(.red) }
                    }
                    if learning.offlineTransport { Text("自动测试离线替身 · 不联网 · 虚构凭据").accessibilityIdentifier("ai-offline-fixture") }
                    Toggle("确认上方选文、任务、接收方及费用范围", isOn: $confirmed).accessibilityIdentifier("ai-scope-consent")
                    Button("开始") { learning.start(confirmed: confirmed, sourceIsCurrent: library.isCurrentAISource); confirmed = false }
                        .disabled(!confirmed || learning.source == nil || learning.busy ||
                            (DeepSeekSelectionPolicy.supports(learning.config) && (!learning.hasSessionCredential || learning.remoteAttemptsUsed >= DeepSeekSelectionPolicy.maxAttempts || (learning.source?.anchor.quote.utf16.count ?? 0) > DeepSeekSelectionPolicy.maxSourceUTF16)))
                        .buttonStyle(PDFnoActionStyle(role: .primary)).accessibilityIdentifier("ai-start")
                    if learning.busy { Button("取消请求") { learning.cancel() }.accessibilityIdentifier("ai-cancel") }
                    PDFnoStatusMessage(text: learning.status, kind: learning.busy ? .busy : .information, identifier: "ai-task-status")
                    if let reason = startUnavailableReason { Text(reason).font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary) }
                    if let error = learning.error { PDFnoStatusMessage(text: error, kind: .error, identifier: "ai-error") }
                }.id("ai-task-state")
                if let result = learning.result {
                    Section("结果 · \(result.provider.mode == .mock ? "本地 mock" : "模型生成")") {
                        PDFnoTextViewport(text: result.text, identifier: "ai-result", height: 220)
                        Button("引用 · 回到原文") { Task { learning.cancel(); if await library.returnToAISource(result.source) { dismiss() } } }
                            .accessibilityIdentifier("ai-result-source")
                        TextField("你的笔记（独立保存）", text: $learning.userText, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("ai-user-note")
                        Button("保存学习笔记") { Task { _ = await learning.save(sourceIsCurrent: library.isCurrentAISource) } }
                            .buttonStyle(PDFnoActionStyle(role: .primary)).disabled(learning.notes.contains { $0.result.requestID == result.requestID }).accessibilityIdentifier("ai-save-note")
                        let savedNote = learning.notes.first { $0.result.requestID == result.requestID }
                        let changed = savedNote.map { $0.userText != learning.userText } ?? false
                        PDFnoStatusMessage(text: savedNote == nil ? "结果与笔记尚未保存 · 点击保存才写入本地" : changed
                            ? "已保存版本保留 · 当前正文改动尚未保存，请在下方已保存笔记中编辑正文" : "学习笔记已保存到本地",
                            kind: savedNote != nil && !changed ? .success : .information, identifier: "ai-result-save-state")
                        Text("只有你点击保存才写入学习笔记；关闭窗口只取消未完成请求，不自动保存结果。")
                    }.id("ai-current-result")
                }
                Section("本次应用的请求记录 · 当前书籍 · 最近10项") {
                    let attempts = learning.attempts.filter { $0.source.bookID == library.currentAIBookID }
                    if attempts.isEmpty { PDFnoEmptyState(title: "还没有请求记录", detail: "确认范围并点击开始后，任务记录显示在这里。", icon: "clock") }
                    ForEach(attempts) { attempt in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: attempt.source.anchor.quote).textSelection(.enabled)
                            Text(attempt.source.anchor.locationLabel + " · " + (attempt.kind == .translate ? "翻译" : "解释"))
                            switch attempt.outcome {
                            case .requesting: PDFnoStatusMessage(text: "正在等待", kind: .busy)
                            case .completed(let result): Text(verbatim: result.text).textSelection(.enabled).accessibilityIdentifier("ai-history-result")
                            case .failed(let failure): PDFnoStatusMessage(text: failure.localizedDescription, kind: .error, identifier: "ai-history-error")
                            }
                        }
                    }
                    Text("记录只留内存，切书不混用；应用退出后不保留未主动保存的内容。")
                }
                Section("已保存学习笔记 · 本地") {
                    let savedNotes = learning.notes.filter { $0.result.source.bookID == library.currentAIBookID }
                    if savedNotes.isEmpty { PDFnoEmptyState(title: "还没有学习笔记", detail: "完成任务后手动保存；原文、结果与用户正文分别保留。", icon: "note.text") }
                    ForEach(savedNotes) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: note.result.source.anchor.quote).accessibilityIdentifier("ai-saved-quote")
                            Text(verbatim: note.result.text).foregroundStyle(.secondary).accessibilityIdentifier("ai-saved-result")
                            if !note.userText.isEmpty { Text(verbatim: note.userText).accessibilityIdentifier("ai-saved-user-note") }
                            NoteBodyEditor(editor: library.noteEditing, note: .learning(note), identifier: "ai-note") {
                                await library.saveEditedNote(.learning(note))
                            } reload: { await library.reloadEditedNote(.learning(note)) }
                            Button("引用 · 回到原文") { Task { learning.cancel(); if await library.returnToAISource(note.result.source) { dismiss() } } }
                                .accessibilityIdentifier("ai-saved-source")
                        }
                    }
                }
            }.font(PDFnoDesign.TypeStyle.body).accessibilityIdentifier("ai-notes-list").navigationTitle("选文学习")
            .toolbar {
                ToolbarItem { Button("查看结果／错误") { proxy.scrollTo(learning.result == nil ? "ai-task-state" : "ai-current-result", anchor: .top) } }
                ToolbarItem { Button("完成（取消未完成请求）") { learning.cancel(); dismiss() }.accessibilityIdentifier("ai-close") }
            }
            .onChange(of: learning.result?.requestID) { _, result in if result != nil { withAnimation { proxy.scrollTo("ai-current-result", anchor: .top) } } }
            .onChange(of: learning.error) { _, error in if error != nil { withAnimation { proxy.scrollTo("ai-task-state", anchor: .top) } } }
            }
        }.frame(minWidth: PDFnoDesign.Metric.sheetMinimum, idealWidth: PDFnoDesign.Metric.sheetIdeal, minHeight: 600)
        .onChange(of: learning.kind) { _, _ in learning.cancel(); learning.result = nil; confirmed = false }
        .onChange(of: learning.config) { _, _ in learning.cancel(); learning.result = nil; confirmed = false }
        .onChange(of: learning.source) { _, _ in confirmed = false }
        .onDisappear { learning.cancel() }
    }
    private var startUnavailableReason: String? {
        if learning.source == nil { return "请先选择原文。" }
        if learning.busy { return "请求进行中，可以取消请求。" }
        if DeepSeekSelectionPolicy.supports(learning.config) {
            if !learning.hasSessionCredential { return "请先在模型设置中输入会话密钥。" }
            if learning.remoteAttemptsUsed >= DeepSeekSelectionPolicy.maxAttempts { return "本次会话阅读请求次数已用完。" }
            if (learning.source?.anchor.quote.utf16.count ?? 0) > DeepSeekSelectionPolicy.maxSourceUTF16 { return "选文超过 500 UTF-16 单位，请缩短选文。" }
        }
        return confirmed ? nil : "核对选文、任务、接收方和费用后，勾选确认以开始。"
    }
}
#endif
