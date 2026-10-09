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
    @State private var category = PDFnoSettingsCategory.ai
    @State private var showDeepSeekTest = false
    private let byok: BYOKSettingsModel?
    private let library: LibraryModel?
    @State private var showBYOKSettings = false
    @State private var hasLoadedBYOK = false
    @State private var childBusy = false
    @State private var showTools = false
    @State private var showRecovery = false
    @State private var showBookno = false
    @State private var backupModel: LocalRecoveryManagementModel?
    private let embedded: Bool
    private let active: Bool
    private let close: (() -> Void)?
    init(learning: AILearningModel, byok: BYOKSettingsModel? = nil, library: LibraryModel? = nil,
         initialCategory: PDFnoSettingsCategory = .ai, embedded: Bool = false, active: Bool = true,
         close: (() -> Void)? = nil) {
        self.learning = learning; self.byok = byok; self.library = library
        self.embedded = embedded; self.active = active; self.close = close
        _draft = State(initialValue: learning.config)
        _category = State(initialValue: initialCategory)
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
            PDFnoSettingsShell(category: $category, navigationDisabled: childBusy) {
                if embedded && hasSubpage {
                    VStack(spacing: 0) {
                        contentHeading.padding(.bottom, 12)
                        HStack {
                            Button { closeSubpage() } label: { Label("返回" + category.title, systemImage: "chevron.left") }
                                .disabled(childBusy).accessibilityIdentifier("settings-subpage-return")
                            Spacer()
                        }.padding(.bottom, 12)
                        settingsSubpage.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: PDFnoDesign.Space.regular) {
                                if embedded { contentHeading }
                                categoryContent
                            }
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }.accessibilityIdentifier("ai-settings-form")
                            .onChange(of: showBYOKSettings) { _, shown in if shown && embedded { proxy.scrollTo("settings-inline-byok", anchor: .top) } }
                    }
                }
            }.disabled(childBusy && !hasSubpage)
            }.navigationTitle("设置")
            .toolbar {
                if !embedded {
                ToolbarItem { Button("取消") { cancelConfiguration() }.keyboardShortcut(.cancelAction).accessibilityIdentifier("ai-settings-cancel") }
                ToolbarItem {
                    if byok != nil {
                        Button("HTTPS BYOK") { showBYOKSettings = true }.accessibilityIdentifier("byok-settings-open")
                            .help("打开独立 HTTPS BYOK 选文身份，不替换当前阅读配置")
                    }
                }
                ToolbarItem { Button("保存配置") { saveConfiguration() }
                    .accessibilityIdentifier("ai-settings-save").disabled(category != .ai || childBusy) }
                }
            }
        }.frame(minWidth: embedded ? 0 : PDFnoDesign.Metric.sheetMinimum, idealWidth: 980, minHeight: embedded ? 0 : 560)
        .sheet(isPresented: Binding(get: { showDeepSeekTest && !embedded }, set: { showDeepSeekTest = $0 })) { DeepSeekSelfTestView(model: learning.deepSeekTest) }
        .sheet(isPresented: Binding(get: { showBYOKSettings && !embedded }, set: { showBYOKSettings = $0 })) { if let byok { BYOKSettingsSheet(model: byok) } }
        .sheet(isPresented: Binding(get: { showTools && !embedded }, set: { showTools = $0 })) { if let library { ReadingToolsWorkspace(library: library) } }
        .sheet(isPresented: Binding(get: { showBookno && !embedded }, set: { showBookno = $0 })) { if let library { BooknoPreviewWorkspace(model: library.booknoPreview) } }
        .sheet(isPresented: Binding(get: { showRecovery && !embedded }, set: { showRecovery = $0 })) {
            if let recovery = library?.recoveryManagement {
                NavigationStack {
                    LocalRecoveryWorkspace(model: recovery)
                        .toolbar { ToolbarItem { Button("完成") { showRecovery = false }.accessibilityIdentifier("local-recovery-close") } }
                }.frame(minWidth: PDFnoDesign.Metric.sheetMinimum, idealWidth: 640, minHeight: 520)
            }
        }
        .onChange(of: category) { _, _ in clearUnappliedSecrets(); closeSubpage() }
        .onChange(of: active) { _, active in if !active { clearUnappliedSecrets() } }
        .onChange(of: learning.config) { old, new in if draft == old { draft = new } }
        .onChange(of: DeepSeekSelectionPolicy.supports(draft)) { _, supported in if !supported { secret = "" } }
        .onDisappear { clearUnappliedSecrets() }
        .onPreferenceChange(PDFnoWorkspaceBusyKey.self) { childBusy = $0 }
    }
    private var contentHeading: some View {
        HStack {
            Spacer()
            Button("返回") { clearUnappliedSecrets(); close?() }
                .disabled(childBusy).accessibilityIdentifier("settings-return")
        }
    }
    private var hasSubpage: Bool { showDeepSeekTest || showTools || showBookno || showRecovery }
    private func clearUnappliedSecrets() { secret = ""; if embedded { byok?.temporarySecret = "" } }
    private func closeSubpage() { showDeepSeekTest = false; showTools = false; showBookno = false; showRecovery = false }
    @ViewBuilder private var settingsSubpage: some View {
        Group {
            if showDeepSeekTest { DeepSeekSelfTestView(model: learning.deepSeekTest) }
            else if showTools, let library { ReadingToolsWorkspace(library: library, settingsAction: { showTools = false; category = .ai }) }
            else if showBookno, let library { BooknoPreviewWorkspace(model: library.booknoPreview) }
            else if showRecovery, let recovery = library?.recoveryManagement {
                NavigationStack {
                    LocalRecoveryWorkspace(model: recovery)
                        .toolbar { ToolbarItem { Button("完成") { showRecovery = false }.disabled(recovery.busy).accessibilityIdentifier("local-recovery-close") } }
                }
            }
        }.environment(\.pdfnoInlineDismiss, { closeSubpage() })
    }
    private func cancelConfiguration() {
        draft = learning.config; clearUnappliedSecrets()
        if let close { close() } else { dismiss() }
    }
    private func saveConfiguration() {
        Task {
            if await learning.saveConfig(draft, temporarySecret: secret) {
                secret = ""
                if let close { close() } else { dismiss() }
            }
        }
    }
    @ViewBuilder private var categoryContent: some View {
        switch category {
        case .ai: aiContent
        case .tools:
            PDFnoSettingsCard("选文与语言学习", detail: "从阅读器的选文工具栏进入；结果与原文并排查看。", symbol: "book") {
                Text("选文翻译、解释、日语与英语沿用 AI 分类中的阅读配置。每次先核对来源、接收方和预算，再手动开始；生成结果由你决定是否保存。")
                Text("日语保留作者 ruby、生成读音建议与用户修正；英语保留结构与语法候选。当前没有额外的持久阅读辅助开关。")
                Button("查看现有阅读配置") { category = .ai }.accessibilityIdentifier("settings-reading-configuration")
            }
            PDFnoSettingsCard("整页与 spine 翻译", symbol: "doc.text") {
                Text("从当前文件的更多菜单进入。PDF 处理当前物理页；EPUB 处理当前完整 spine 文档。先展示完整原文与分段计划，本次密钥由你单独输入。")
                Text("此页只说明现有范围，打开设置不会捕获非活动文件或发送请求。").foregroundStyle(.secondary)
            }
        case .backup:
            if let library {
                if let recovery = backupModel {
                    LocalRecoveryWorkspace(model: recovery, mode: .backup)
                        .frame(minHeight: 430)
                } else {
                    ProgressView("正在准备本地备份…")
                        .task {
                            if library.recoveryManagement == nil { library.prepareRecoveryManagement() }
                            backupModel = library.recoveryManagement
                        }
                }
            } else { Text("请从书库设置打开备份与恢复。") }
        case .general:
            PDFnoSettingsCard("外观", symbol: "circle.lefthalf.filled") {
                PDFnoAppearancePicker()
            }
        case .shortcuts:
            PDFnoSettingsCard("现有应用内快捷键", symbol: "keyboard") {
                Text("PDF 导航与搜索：⌘F\n书库与已保存笔记搜索：⌘⇧F\nPDF 阅读区翻页：⌘⌥← / ⌘⌥→\nPDF 返回跳转前页面：⌘⌥↑\n翻页与返回仅在 PDF 阅读区获得焦点时生效；文本输入、输入法和面板保持系统行为。")
                Text("本片未新增全局快捷键、快捷键录制或系统权限申请。").foregroundStyle(.secondary)
            }
        case .diagnostics:
            PDFnoSettingsCard("请求与错误记录", symbol: "doc.text.magnifyingglass") {
                Text("阅读任务中的状态、错误和取消来自原模型。独立短句测试记录只在应用会话内保留。")
                Button("DeepSeek 短句自助测试") { showDeepSeekTest = true }
                    .accessibilityIdentifier("settings-diagnostic-test")
                Text("本片未新增日志上传或导出。打开此页面不会发送测试请求。").foregroundStyle(.secondary)
            }
        case .about:
            PDFnoSettingsCard("PDFno", detail: "原生本地阅读与可核对的学习记录。", symbol: "book.closed") {
                Text("AGPL-3.0-or-later")
                Text("现有阅读、笔记与有限 AI 入口各保留原能力范围。语义检索、MCP 和工具调用仍为规划。")
            }
            ForEach(PDFnoPlannedCapability.settings) { PDFnoPlannedCapabilityCard(capability: $0) }
            PDFnoSettingsCard("工具目录", status: "规划中") { PDFnoPlannedDirectory() }
            PDFnoSettingsCard("功能状态", symbol: "checklist") { FeatureStatusView(embedded: true).frame(height: 620) }
        }
    }
    private var aiContent: some View {
        Group {
            PDFnoStatusMessage(text: "选文翻译／解释支持本地 mock 或官方 DeepSeek；配置和输入密钥不会发送请求，选文窗口确认后由你点击开始。", identifier: "ai-network-status")
            PDFnoSettingsCard("官方 DeepSeek 与现有阅读配置", detail: "此配置供原有选文、日语与英语入口；页与 spine 仍手动输入本次密钥。", symbol: "sparkles") {
                Picker("服务类型", selection: $draft.mode) {
                    Text("未配置").tag(AIProviderMode.unconfigured)
                    Text("本地 mock 示例").tag(AIProviderMode.mock)
                    Text("HTTPS／DeepSeek").tag(AIProviderMode.openAICompatible)
                }.accessibilityIdentifier("ai-provider-mode")
                Button("使用本地 mock 示例") { draft.mode = .mock; draft.label = "本地 mock"; draft.model = "synthetic-selection-1"; draft.endpoint = ""; secret = "" }
                    .accessibilityIdentifier("ai-use-mock")
                Button("使用 DeepSeek 选文配置") { draft = DeepSeekSelectionPolicy.configuration(); secret = "" }.accessibilityIdentifier("ai-use-deepseek")
                if draft.mode == .openAICompatible, DeepSeekSelectionPolicy.supports(draft) {
                    PDFnoSettingsField("当前应用会话的临时 API key") {
                        SecureField("当前应用会话的临时 API key", text: $secret).accessibilityIdentifier("ai-session-key")
                    }
                }
                PDFnoSettingsField("服务名称") { TextField("服务名称", text: $draft.label).accessibilityIdentifier("ai-provider-label") }
                PDFnoSettingsField("API endpoint") { TextField("API endpoint", text: $draft.endpoint).accessibilityIdentifier("ai-endpoint") }
                PDFnoSettingsField("模型") { TextField("模型", text: $draft.model).accessibilityIdentifier("ai-model") }
                if draft.mode == .openAICompatible {
                    if DeepSeekSelectionPolicy.supports(draft) {
                        Text("由你手动输入；只留在本次应用内存。保存时新输入会替换会话密钥，留空则清除；重开应用需重新输入。分类切换会清空尚未应用的密钥输入。").foregroundStyle(.secondary)
                    } else { Text("此服务仍仅配置预览，不收取密钥或发送阅读请求。本片只开放官方 DeepSeek HTTPS 地址及 deepseek-flash。") }
                }
                Text(learning.hasSessionCredential ? "当前会话密钥已输入" : "当前会话密钥未配置").accessibilityIdentifier("ai-credential-status")
                if learning.hasSessionCredential { Button("清除当前会话密钥") { Task { await learning.clearSessionCredential() } }.accessibilityIdentifier("ai-clear-key") }
                if let url = try? OpenAICompatibleSelectionProvider.finalURL(draft), draft.mode == .openAICompatible {
                    Text(verbatim: "最终 API 路径：" + url.absoluteString).textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true).font(.caption)
                }
                if let error = learning.error { PDFnoStatusMessage(text: error, kind: .error, identifier: "ai-settings-error") }
                if embedded {
                    HStack {
                        Spacer()
                        Button("取消") { cancelConfiguration() }.disabled(childBusy).accessibilityIdentifier("ai-settings-cancel")
                        Button("保存配置") { saveConfiguration() }.disabled(childBusy)
                            .buttonStyle(PDFnoActionStyle(role: .primary)).accessibilityIdentifier("ai-settings-save")
                    }.padding(.top, 8)
                }
            }
            PDFnoSettingsCard("其他 HTTPS BYOK 选文配置", detail: "独立会话身份；不会替换上方 DeepSeek、日语、英语、页或 spine 配置。", symbol: "network") {
                if let byok {
                    Button("其他 HTTPS BYOK选文设置") { showBYOKSettings.toggle() }.accessibilityIdentifier("settings-byok-details")
                    if embedded && showBYOKSettings {
                        BYOKSettingsView(model: byok, loadOnAppear: false)
                            .frame(minHeight: 560)
                            .task { if !hasLoadedBYOK { hasLoadedBYOK = true; await byok.load() } }
                        Button("取消未应用的 BYOK 修改") { Task { byok.temporarySecret = ""; await byok.load(); showBYOKSettings = false } }
                            .accessibilityIdentifier("settings-byok-cancel")
                    }
                } else { Text("此宿主未接入独立 BYOK 设置。") }
            }.id("settings-inline-byok")
            PDFnoSettingsCard("会话密钥与预算", symbol: "lock") {
                Text("配置预览与分类切换不保存、不测试、不发送。应用会话凭据和未应用输入各沿用原生命周期；持久 Keychain 尚未启用。")
                Text("选文翻译、解释、日语、英语与独立 BYOK 共用 3 次；PDF页与EPUB spine 各 6 次。每次最多 1024 输出 tokens、30 秒、64 KiB 响应；失败、取消也计数，自动重试 0 次。")
                Text("费用与 usage 未知；页与 spine 只处理完整预览计划，不附加上下文。mock 不联网且费用为零。").foregroundStyle(.secondary)
            }
            PDFnoSettingsCard("独立短句自助测试", detail: "只测试原创短句，不读取书籍；有独立确认与 3 次上限。", symbol: "checkmark.bubble") {
                Button("DeepSeek 短句自助测试") { showDeepSeekTest = true }.accessibilityIdentifier("ai-deepseek-self-test")
            }
        }.textFieldStyle(.roundedBorder)
    }
}
struct AILearningWorkspace: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var learning: AILearningModel
    var embedded = false
    var close: (() -> Void)? = nil
    var consentRevision: UUID? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var confirmed = false
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            VStack(spacing: 0) {
            if embedded {
                HStack(spacing: 6) {
                    Label("选文学习", systemImage: "sparkles").font(PDFnoDesign.TypeStyle.section)
                    Spacer(minLength: 0)
                    Button { proxy.scrollTo(learning.result == nil ? "ai-task-state" : "ai-current-result", anchor: .top) } label: { Image(systemName: "text.viewfinder") }
                        .help("查看结果／错误").accessibilityLabel("查看结果／错误")
                    Button { learning.cancel(); finish() } label: { Image(systemName: "xmark") }
                        .accessibilityLabel("完成（取消未完成请求）").accessibilityIdentifier("ai-close")
                        .help("关闭面板，保留已生成结果与笔记草稿")
                }.buttonStyle(PDFnoActionStyle(role: .quiet)).padding(8)
                Divider()
            }
            ScrollView {
            VStack(alignment: .leading, spacing: PDFnoDesign.Space.regular) {
                PDFnoSettingsCard("本次固定选文") {
                    if let source = learning.source {
                        PDFnoTextViewport(text: source.anchor.quote, identifier: "ai-source-quote")
                        Text(source.anchor.locationLabel).font(.caption).accessibilityIdentifier("ai-source-location")
                        Text("\(source.anchor.quote.utf16.count) UTF-16 单位 · 不附加其他上下文")
                    } else { PDFnoEmptyState(title: "尚未固定选文", detail: "先在 PDF / EPUB 原文中选择文字，再打开选文学习。") }
                }
                PDFnoSettingsCard("任务与处理范围") {
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
                    if learning.kind == .explain { Text("段落解释 Skill 1.0.1 / schema 1：仅简体中文、最多500 UTF-16；释义／术语／模型推断分开，原文依据可核对。证据不足或结构错误不保存。真实解释质量待人工审阅。") }
                    Toggle("确认上方选文、任务、接收方及费用范围", isOn: $confirmed).accessibilityIdentifier("ai-scope-consent")
                    Button("开始") { learning.start(confirmed: confirmed, sourceIsCurrent: library.isCurrentAISource); confirmed = false }
                        .disabled(!confirmed || learning.source == nil || learning.busy || learning.saving || (learning.kind == .explain && (learning.source?.anchor.quote.utf16.count ?? 0) > 500) ||
                            (DeepSeekSelectionPolicy.supports(learning.config) && (!learning.hasSessionCredential || learning.remoteAttemptsUsed >= DeepSeekSelectionPolicy.maxAttempts || (learning.source?.anchor.quote.utf16.count ?? 0) > DeepSeekSelectionPolicy.maxSourceUTF16)))
                        .buttonStyle(PDFnoActionStyle(role: .primary)).accessibilityIdentifier("ai-start")
                    if learning.busy { Button("取消请求") { learning.cancel() }.accessibilityIdentifier("ai-cancel") }
                    PDFnoStatusMessage(text: learning.status, kind: learning.busy ? .busy : .information, identifier: "ai-task-status")
                    if let reason = startUnavailableReason { Text(reason).font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary) }
                    if let error = learning.error { PDFnoStatusMessage(text: error, kind: .error, identifier: "ai-error") }
                }.id("ai-task-state")
                if let result = learning.result {
                    PDFnoSettingsCard("结果 · \(result.provider.mode == .mock ? "本地 mock" : "模型生成")") {
                        if let explanation = result.paragraphExplanation {
                            ParagraphExplanationResultView(explanation: explanation, source: result.source, library: library) { finish() }
                        } else { PDFnoTextViewport(text: result.displayText, identifier: "ai-result", height: 220) }
                        Button("引用 · 回到原文") { Task { if result.paragraphExplanation != nil && !library.isCurrentParagraphSource(result.source) { learning.error = AIFailure.stale.localizedDescription; return }; learning.cancel(); if await library.returnToAISource(result.source) { finish() } } }
                            .accessibilityIdentifier("ai-result-source")
                        TextField("你的笔记（独立保存）", text: $learning.userText, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("ai-user-note")
                        Button("保存学习笔记") { Task { _ = await learning.save(sourceIsCurrent: library.isCurrentAISource, validateSource: library.validateParagraphSourceForSave, makeCommitFence: library.makeParagraphCommitFence) } }
                            .buttonStyle(PDFnoActionStyle(role: .primary)).disabled(learning.saving || !result.canSaveSelectionResult || (result.paragraphExplanation != nil && !library.isCurrentParagraphSource(result.source)) || !library.isCurrentAISource(result.source) || result.provider != learning.config || learning.notes.contains { $0.result.requestID == result.requestID }).accessibilityIdentifier("ai-save-note")
                        let savedNote = learning.notes.first { $0.result.requestID == result.requestID }
                        let changed = savedNote.map { $0.userText != learning.userText } ?? false
                        PDFnoStatusMessage(text: savedNote == nil ? "结果与笔记尚未保存 · 点击保存才写入本地" : changed
                            ? "已保存版本保留 · 当前正文改动尚未保存，请在下方已保存笔记中编辑正文" : "学习笔记已保存到本地",
                            kind: savedNote != nil && !changed ? .success : .information, identifier: "ai-result-save-state")
                        Text("只有你点击保存才写入学习笔记；关闭窗口只取消未完成请求，不自动保存结果。")
                    }.id("ai-current-result")
                }
                PDFnoSettingsCard("本次应用的请求记录 · 当前书籍 · 最近10项") {
                    let attempts = learning.attempts.filter { $0.source.bookID == library.currentAIBookID }
                    if attempts.isEmpty { PDFnoEmptyState(title: "还没有请求记录", detail: "确认范围并点击开始后，任务记录显示在这里。", icon: "clock") }
                    ForEach(attempts) { attempt in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: attempt.source.anchor.quote).textSelection(.enabled)
                            Text(attempt.source.anchor.locationLabel + " · " + (attempt.kind == .translate ? "翻译" : "解释"))
                            switch attempt.outcome {
                            case .requesting: PDFnoStatusMessage(text: "正在等待", kind: .busy)
                            case .completed(let result): Text(verbatim: result.displayText).textSelection(.enabled).accessibilityIdentifier("ai-history-result")
                            case .failed(let failure): PDFnoStatusMessage(text: failure.localizedDescription, kind: .error, identifier: "ai-history-error")
                            }
                        }
                    }
                    Text("记录只留内存，切书不混用；应用退出后不保留未主动保存的内容。")
                }
                PDFnoSettingsCard("已保存学习笔记 · 本地") {
                    let savedNotes = learning.notes.filter { $0.result.source.bookID == library.currentAIBookID }
                    if savedNotes.isEmpty { PDFnoEmptyState(title: "还没有学习笔记", detail: "完成任务后手动保存；原文、结果与用户正文分别保留。", icon: "note.text") }
                    ForEach(savedNotes) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: note.result.source.anchor.quote).accessibilityIdentifier("ai-saved-quote")
                            if let explanation = note.result.paragraphExplanation {
                                ParagraphExplanationResultView(explanation: explanation, source: note.result.source, library: library, saved: true, summaryIdentifier: "ai-saved-result") { finish() }
                            } else { Text(verbatim: note.result.displayText).foregroundStyle(.secondary).accessibilityIdentifier("ai-saved-result") }
                            if !note.userText.isEmpty { Text(verbatim: note.userText).accessibilityIdentifier("ai-saved-user-note") }
                            NoteBodyEditor(editor: library.noteEditing, note: .learning(note), identifier: "ai-note") {
                                await library.saveEditedNote(.learning(note))
                            } reload: { await library.reloadEditedNote(.learning(note)) }
                            Button("引用 · 回到原文") { Task { if note.result.paragraphExplanation != nil && !library.canReturnToSavedParagraphSource(note.result.source) { learning.error = AIFailure.stale.localizedDescription; return }; learning.cancel(); if await library.returnToAISource(note.result.source) { finish() } } }
                                .accessibilityIdentifier("ai-saved-source")
                        }
                    }
                }
            }.padding(PDFnoDesign.Space.section)
            }.background(PDFnoDesign.Palette.chrome).font(PDFnoDesign.TypeStyle.body).accessibilityIdentifier("ai-notes-list")
            .modifier(AILearningPresentationTitle(embedded: embedded))
            .toolbar {
                if !embedded {
                    ToolbarItem { Button("查看结果／错误") { proxy.scrollTo(learning.result == nil ? "ai-task-state" : "ai-current-result", anchor: .top) } }
                    ToolbarItem { Button("完成（取消未完成请求）") { learning.cancel(); finish() }.accessibilityIdentifier("ai-close") }
                }
            }
            .onChange(of: learning.result?.requestID) { _, result in if result != nil { withAnimation { proxy.scrollTo("ai-current-result", anchor: .top) } } }
            .onChange(of: learning.error) { _, error in if error != nil { withAnimation { proxy.scrollTo("ai-task-state", anchor: .top) } } }
            }
            }
        }.frame(minWidth: embedded ? 0 : PDFnoDesign.Metric.sheetMinimum, idealWidth: embedded ? PDFnoDesign.Metric.notesWidth : PDFnoDesign.Metric.sheetIdeal, minHeight: embedded ? 0 : 600)
        .onChange(of: consentRevision) { _, _ in confirmed = false }
        .onChange(of: learning.kind) { _, _ in learning.cancel(); learning.result = nil; confirmed = false }
        .onChange(of: try? ReadingSkillIdentity.data(learning.config)) { _, _ in learning.cancel(); learning.result = nil; confirmed = false }
        .onChange(of: try? ReadingSkillIdentity.data(learning.source)) { _, _ in confirmed = false }
        .onDisappear { learning.cancel() }
    }
    private func finish() { if let close { close() } else { dismiss() } }
    private var startUnavailableReason: String? {
        if learning.source == nil { return "请先选择原文。" }
        if learning.busy { return "请求进行中，可以取消请求。" }
        if learning.kind == .explain && (learning.source?.anchor.quote.utf16.count ?? 0) > 500 { return "段落解释最多500 UTF-16 单位，请缩小选文。" }
        if DeepSeekSelectionPolicy.supports(learning.config) {
            if !learning.hasSessionCredential { return "请先在模型设置中输入会话密钥。" }
            if learning.remoteAttemptsUsed >= DeepSeekSelectionPolicy.maxAttempts { return "本次会话阅读请求次数已用完。" }
            if (learning.source?.anchor.quote.utf16.count ?? 0) > DeepSeekSelectionPolicy.maxSourceUTF16 { return "选文超过 500 UTF-16 单位，请缩短选文。" }
        }
        return confirmed ? nil : "核对选文、任务、接收方和费用后，勾选确认以开始。"
    }
}

private struct AILearningPresentationTitle: ViewModifier {
    let embedded: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if embedded { content }
        else { content.navigationTitle("选文学习") }
    }
}
#endif
