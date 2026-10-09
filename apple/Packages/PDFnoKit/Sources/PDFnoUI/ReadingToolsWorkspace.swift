// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoServices

enum PDFnoReadingTool: String, CaseIterable, Identifiable {
    case translate, explain, japanese, english, page, spine, byok, savedSearch
    var id: String { rawValue }
    var title: String {
        switch self {
        case .translate: "选文翻译"
        case .explain: "段落解释"
        case .japanese: "日语假名与语法"
        case .english: "英语结构与语法"
        case .page: "当前 PDF 物理页翻译"
        case .spine: "当前 EPUB spine 文档翻译"
        case .byok: "HTTPS BYOK 选文"
        case .savedSearch: "书名与已保存笔记搜索"
        }
    }
    var detail: String {
        switch self {
        case .translate: "翻译固定选文；先预览接收方和范围。"
        case .explain: "固定选文的释义、术语与模型推断分开；显示原文依据，手动保存。"
        case .japanese: "区分作者 ruby、生成建议与用户修正。"
        case .english: "结构分色与语法候选；真实语言质量尚未验收。"
        case .page: "预览当前物理页完整文字与分段预算。"
        case .spine: "处理当前完整 spine 文档，不推断目录逻辑章节。"
        case .byok: "使用独立 HTTPS 会话配置，逐次确认后发送。"
        case .savedSearch: "仅检索书名与已保存记录；未保存草稿不入索引。"
        }
    }
    var scope: String {
        switch self {
        case .page: "PDF · 独立 6 次预算 · 本次手动输入密钥"
        case .spine: "EPUB · 独立 6 次预算 · 本次手动输入密钥"
        case .savedSearch: "本地保存记录 · 无语义检索或书籍全文索引"
        case .byok: "PDF / EPUB 选文 · 独立配置 · 共享 3 次预算"
        default: "PDF / EPUB 选文 · 官方 DeepSeek / 原创 mock · 共享 3 次预算"
        }
    }
    var symbol: String {
        switch self {
        case .translate, .byok: "character.bubble"
        case .explain: "text.bubble"
        case .japanese, .english: "textformat.abc"
        case .page: "doc.text"
        case .spine: "book"
        case .savedSearch: "magnifyingglass"
        }
    }
}

enum PDFnoToolAvailability: String {
    case enter = "可进入", selection = "需选文", configuration = "需配置", unsupported = "格式不支持"
    var canOpen: Bool { self != .unsupported }
}

/// Read-only projection of the existing reader and independent configuration owners.
struct PDFnoReadingToolContext {
    enum Format { case none, pdf, epub, other }
    var format: Format
    var hasSelection: Bool
    var readingConfigured: Bool
    var byokConfigured: Bool
    func availability(_ tool: PDFnoReadingTool) -> PDFnoToolAvailability {
        if tool == .savedSearch { return .enter }
        if tool == .page { return format == .pdf ? .enter : .unsupported }
        if tool == .spine { return format == .epub ? .enter : .unsupported }
        guard format == .pdf || format == .epub else { return .unsupported }
        guard hasSelection else { return .selection }
        return (tool == .byok ? byokConfigured : readingConfigured) ? .enter : .configuration
    }
    @MainActor init(library: LibraryModel) {
        if library.readingComic || library.docx.isActive || library.textFormats.isActive || library.ebook.isActive { format = .other }
        else if library.readingEPUB { format = .epub }
        else { format = library.reader.book == nil ? .none : .pdf }
        if format == .epub {
            hasSelection = library.epub.selection.map { library.epub.book?.accepts($0) == true } ?? false
        } else if format == .pdf {
            hasSelection = library.reader.capturedSelection.map { library.reader.resolution(of: $0) == .exact } ?? false
        } else { hasSelection = false }
        readingConfigured = library.learning.config.mode == .mock ||
            (DeepSeekSelectionPolicy.supports(library.learning.config) && library.learning.hasSessionCredential)
        byokConfigured = library.byok.hasSessionCredential
    }
    init(format: Format, hasSelection: Bool, readingConfigured: Bool, byokConfigured: Bool) {
        self.format = format; self.hasSelection = hasSelection
        self.readingConfigured = readingConfigured; self.byokConfigured = byokConfigured
    }
}

struct ReadingToolsWorkspace: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject private var learning: AILearningModel
    @ObservedObject private var byok: BYOKSettingsModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pdfnoInlineDismiss) private var inlineDismiss
    @State private var route: PDFnoReadingTool?
    @State private var existingOnly = false
    @State private var settings = false
    @Environment(\.pdfnoWorkspaceNavigation) private var workspaceNavigation
    @State private var width: CGFloat = 0
    private let settingsAction: (() -> Void)?
    init(library: LibraryModel, settingsAction: (() -> Void)? = nil) { self.library = library; learning = library.learning; byok = library.byok; self.settingsAction = settingsAction }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: PDFnoDesign.Space.regular) {
                    PDFnoStatusMessage(text: "点击现有工具只进入预览。来源、接收方、开始、取消和手动保存沿用原流程；可进入不表示模型或语言质量已经验收。")
                    Picker("显示范围", selection: $existingOnly) {
                        Text("全部").tag(false); Text("现有入口").tag(true)
                    }.pickerStyle(.segmented).accessibilityIdentifier("ai-tools-filter")
                    PDFnoSettingsCard("阅读与语言", symbol: "book") {
                        ForEach(PDFnoReadingTool.allCases.filter { $0 != .savedSearch }) { tool in toolRow(tool) }
                    }
                    PDFnoSettingsCard("知识与模板", symbol: "note.text") {
                        toolRow(.savedSearch)
                        if !existingOnly {
                            DisclosureGroup("规划中 · 论证结构、引用学习卡、单书问答、个人模板") {
                                Text("上述能力尚未实现；本片只保留规划说明，没有生成或模板编辑入口。")
                                    .foregroundStyle(.secondary).padding(.top, PDFnoDesign.Space.small)
                            }.accessibilityIdentifier("ai-tools-knowledge-planned")
                        }
                    }
                    if !existingOnly {
                        PDFnoSettingsCard("外部能力", symbol: "network", status: "规划中 · 未实现 · 默认关闭") {
                            DisclosureGroup("网页阅读、公共搜索、MCP Client、MCP Server") {
                                Text("尚无网络研究、工具调用或对外读取服务。查看设置中的依赖说明不会连接、下载或添加工具。")
                                    .foregroundStyle(.secondary).padding(.top, PDFnoDesign.Space.small)
                            }.accessibilityIdentifier("ai-tools-external-planned")
                        }
                    }
                    Button("模型与 BYOK 设置") { if let settingsAction { settingsAction() } else if let workspaceNavigation { workspaceNavigation.showSettings() } else { settings = true } }
                        .buttonStyle(PDFnoActionStyle()).accessibilityIdentifier("ai-tools-settings")
                }.padding(PDFnoDesign.Space.section).frame(maxWidth: PDFnoTemporaryLayout.contentMaximum, alignment: .leading)
                    .frame(maxWidth: .infinity)
            }.background(PDFnoDesign.Palette.chrome)
                .background { GeometryReader { geometry in
                    Color.clear.onAppear { width = geometry.size.width }
                        .onChange(of: geometry.size.width) { _, value in width = value }
                } }.navigationTitle("AI工具")
                .accessibilityIdentifier("ai-tools-directory")
                .toolbar { ToolbarItem { Button("完成") { if let inlineDismiss { inlineDismiss() } else { dismiss() } }.keyboardShortcut(.cancelAction).accessibilityIdentifier("ai-tools-close") } }
        }.frame(minWidth: PDFnoDesign.Metric.sheetMinimum, idealWidth: 860, minHeight: inlineDismiss == nil ? 600 : 0)
            .sheet(item: $route) { tool in
                Group { switch tool {
                case .translate, .explain: AILearningWorkspace(library: library, learning: learning)
                case .japanese: JapaneseLearningSheet(library: library)
                case .english: EnglishLearningSheet(library: library)
                case .page: PDFPageTranslationWorkspace(library: library, translation: library.pageTranslation, learning: learning)
                case .spine: EPUBChapterTranslationWorkspace(library: library, translation: library.chapterTranslation, learning: learning)
                case .byok: BYOKLearningWorkspace(library: library, model: byok)
                case .savedSearch: LibrarySearchWorkspace(library: library)
                } }.environment(\.pdfnoInlineDismiss, nil)
            }
            .sheet(isPresented: $settings) { AISettingsView(learning: learning, byok: byok, library: library) }
    }
    private func toolRow(_ tool: PDFnoReadingTool) -> some View {
        let status = PDFnoReadingToolContext(library: library).availability(tool)
        return Button { open(tool) } label: {
            HStack(alignment: .top, spacing: PDFnoDesign.Space.regular) {
                Image(systemName: tool.symbol).frame(width: 24).foregroundStyle(PDFnoDesign.Palette.accent).accessibilityHidden(true)
                VStack(alignment: .leading, spacing: PDFnoDesign.Space.tight) {
                    Text(tool.title).font(PDFnoDesign.TypeStyle.section)
                    Text(tool.detail).foregroundStyle(.secondary)
                    Text(tool.scope).font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary)
                    if width < 640 { Text(status.rawValue).font(PDFnoDesign.TypeStyle.metadata) }
                    if status == .unsupported { Text("请打开适用格式的原书").font(PDFnoDesign.TypeStyle.metadata) }
                }.frame(maxWidth: .infinity, alignment: .leading).fixedSize(horizontal: false, vertical: true)
                VStack(alignment: .trailing, spacing: PDFnoDesign.Space.small) {
                    if width >= 640 { Text(status.rawValue).font(PDFnoDesign.TypeStyle.metadata) }
                    Image(systemName: "chevron.right").accessibilityHidden(true)
                }
            }.padding(.vertical, PDFnoDesign.Space.small).frame(minHeight: 44)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!status.canOpen || library.isBusy || library.storageMaintenance)
            .accessibilityIdentifier("ai-tool-" + tool.rawValue).accessibilityValue(status.rawValue)
    }
    private func open(_ tool: PDFnoReadingTool) {
        guard PDFnoReadingToolContext(library: library).availability(tool).canOpen,
              !library.isBusy, !library.storageMaintenance else { return }
        switch tool {
        case .translate, .explain:
            let kind: AILearningKind = tool == .translate ? .translate : .explain
            if learning.kind != kind { learning.cancel(); learning.result = nil; learning.kind = kind }
            learning.prepare(library.captureAISource()); route = tool
        case .japanese: library.prepareJapaneseLearning(); route = tool
        case .english: library.prepareEnglishLearning(); route = tool
        case .page: library.preparePageTranslation(); route = tool
        case .spine: Task { await library.prepareChapterTranslation(); route = tool }
        case .byok: Task { await library.prepareBYOKSelection(); route = tool }
        case .savedSearch: route = tool
        }
    }
}
#endif
