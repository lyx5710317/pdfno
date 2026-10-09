// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import UniformTypeIdentifiers
import PDFnoDomain

struct MacTabbedWorkspace: View {
    @ObservedObject var model: LibraryModel
    @ObservedObject var navigation: PDFnoWorkspaceNavigation
    let settingsRequest: Int
    @StateObject private var documents: MacDocumentTabs
    @State private var sidebar = true
    @State private var grid = true
    @State private var selectedBookID: UUID?
    @State private var importer = false
    @State private var examples = false
    @State private var navigationBusy = false
    @State private var windowWidth: CGFloat = 1180
    @State private var filePanel: MacDocumentFilePanel?
    init(model: LibraryModel, navigation: PDFnoWorkspaceNavigation, settingsRequest: Int) {
        self.model = model; self.navigation = navigation; self.settingsRequest = settingsRequest
        _documents = StateObject(wrappedValue: MacDocumentTabs(catalogue: model))
    }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                globalSidebar.frame(width: sidebar ? 180 : 56)
                Divider()
                ZStack {
                    ForEach(documents.tabs) { tab in
                        MacDocumentReader(model: tab.model, workspaceClose: {
                            Task { await documents.requestClose(tab.id); if documents.active == nil { navigation.showLibrary() } }
                        })
                            .opacity(isVisible(tab) ? 1 : 0)
                            .allowsHitTesting(isVisible(tab)).disabled(!isVisible(tab))
                            .accessibilityHidden(!isVisible(tab))
                    }
                    if navigation.route == .library {
                        ProfessionalLibraryWorkspace(model: model, grid: $grid, selectedBookID: $selectedBookID,
                            importFile: { importer = true }, search: { showTool(.search) }, examples: { examples = true },
                            editCover: { _ in }, openBook: openBook,
                            resume: documents.active == nil ? nil : { navigation.showReader() })
                    }
                    if navigation.route == .tool { toolContent }
                    if navigation.hasOpenedSettings {
                        AISettingsView(learning: model.learning, byok: model.byok, library: model, embedded: true,
                            active: navigation.route == .settings,
                            close: { navigation.returnFromSettings(readerAvailable: documents.active != nil) })
                            .opacity(navigation.route == .settings ? 1 : 0)
                            .allowsHitTesting(navigation.route == .settings).disabled(navigation.route != .settings)
                            .accessibilityHidden(navigation.route != .settings)
                    }
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.tint(.blue).background(PDFnoDesign.Palette.canvas)
            // SwiftUI owns its toolbar and appearance observers. The document
            // band is a native titlebar accessory, independent of route toolbars.
            .environment(\.pdfnoWorkspaceNavigation, navigation)
            .background(PDFnoWorkspaceWindowTitle(title: windowTitle, documentToolbar: true))
            .background {
                GeometryReader { geometry in
                    Color.clear.onAppear { windowWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { _, width in windowWidth = width }
                }
            }
            .background {
                MacDocumentWindowToolbar(content: AnyView(documentBar), width: windowWidth).frame(width: 0, height: 0)
            }
            .disabled(model.storageMaintenance)
            .task { await model.load(); if model.displayedDocumentID != nil { documents.adopt(model) } }
            .onChange(of: model.displayedDocumentID) { _, id in
                if id != nil && !model.storageMaintenance { documents.adopt(model); navigation.showReader() }
            }
            .onChange(of: model.storageMaintenance) { _, paused in
                if !paused { documents.reconcileAfterMaintenance(); if documents.active == nil && navigation.route == .reader { navigation.showLibrary() } }
            }
            .onChange(of: settingsRequest, initial: true) { _, value in if value > 0 && !navigationBusy { navigation.showSettings() } }
            .onPreferenceChange(PDFnoWorkspaceBusyKey.self) { navigationBusy = $0 }
            .fileImporter(isPresented: $importer, allowedContentTypes: importTypes) { result in
                switch result {
                case .success(let url): Task { if await documents.openNew({ await $0.importFile(url) }) { navigation.showReader() } }
                case .failure(let error): documents.error = error.localizedDescription
                }
            }
            .popover(isPresented: $examples) { examplesMenu }
            .sheet(item: $filePanel) { panel in MacDocumentFileWorkspace(panel: panel) }
            .alert("关闭这个文件？", isPresented: Binding(get: { documents.pendingCloseID != nil }, set: { if !$0 { documents.pendingCloseID = nil } })) {
                Button("取消", role: .cancel) { documents.pendingCloseID = nil }.accessibilityIdentifier("document-close-cancel")
                Button("放弃未保存内容并关闭", role: .destructive) {
                    if let id = documents.pendingCloseID { Task { await documents.close(id, confirmed: true); if documents.active == nil && navigation.route == .reader { navigation.showLibrary() } } }
                }.accessibilityIdentifier("document-close-confirm")
            } message: {
                Text("此文件有未保存草稿、结果或运行中的任务。关闭会取消任务并放弃未保存内容；已保存的笔记保留。选择取消可回到文件继续编辑。")
            }
            .alert("操作未完成", isPresented: Binding(get: { documents.error != nil || model.error != nil }, set: { if !$0 { documents.error = nil; model.error = nil } })) {
                Button("知道了") { documents.error = nil; model.error = nil }
            } message: { Text(documents.error ?? model.error ?? "") }
            .overlay { if documents.opening { ProgressView("正在打开文件…").padding(20).pdfnoCard() } }
    }
    private func isVisible(_ tab: MacDocumentTab) -> Bool { navigation.route == .reader && documents.activeID == tab.id }
    private var windowTitle: String {
        switch navigation.route {
        case .library: "PDFno"
        case .reader: documents.active?.title ?? "PDFno"
        case .settings: "设置"
        case .tool: toolTitle
        }
    }
    private var documentBar: some View {
        HStack(spacing: 6) {
            Button { navigation.showLibrary() } label: { Image(systemName: "house").frame(width: 34, height: 32) }
                .background(navigation.route == .library ? Color.blue.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .accessibilityIdentifier("workspace-back-library").accessibilityLabel("主页").help("返回书库，保留所有文件与草稿")
                .pdfnoTitlebarControl()
            ScrollView(.horizontal) {
                HStack(spacing: 5) {
                    ForEach(documents.tabs) { tab in
                        HStack(spacing: 6) {
                            Button { documents.activate(tab.id); navigation.showReader() } label: {
                                HStack(spacing: 7) {
                                    Image(systemName: "doc.text")
                                    Text(tab.title).lineLimit(1)
                                    Text(documentFormat(tab.model)).font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
                                }
                                    .frame(minWidth: 86, maxWidth: 180, minHeight: 32, alignment: .leading).contentShape(Rectangle())
                            }.accessibilityIdentifier("document-tab-" + tab.id.uuidString)
                                .accessibilityValue(isVisible(tab) ? "已选中" : "未选中")
                                .pdfnoTitlebarControl()
                            Button { Task { await documents.requestClose(tab.id); if documents.active == nil && navigation.route == .reader { navigation.showLibrary() } } } label: {
                                Image(systemName: "xmark").font(.system(size: 10)).frame(width: 24, height: 28).contentShape(Rectangle())
                            }.accessibilityLabel("关闭文件：" + tab.title).accessibilityIdentifier("document-tab-close-" + tab.id.uuidString)
                                .pdfnoTitlebarControl()
                        }.padding(.horizontal, 9)
                            .background(isVisible(tab) ? PDFnoDesign.Palette.surface : Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isVisible(tab) ? Color.blue.opacity(0.4) : Color.primary.opacity(0.06)))
                    }
                }.padding(.vertical, 2)
            }.scrollIndicators(.hidden).accessibilityIdentifier("document-tabs")
            Button { importer = true } label: { Image(systemName: "plus").frame(width: 28, height: 30) }
                .disabled(!model.canImport).accessibilityIdentifier("document-add").accessibilityLabel("导入文件到新标签")
                .help("选择本地文件；已打开的文件会激活原标签")
                .pdfnoTitlebarControl()
            if let active = documents.active, navigation.route == .reader {
                MacDocumentMoreMenu(model: active.model) { action in
                    Task {
                        guard documents.activeID == active.id, navigation.route == .reader else { return }
                        switch action {
                        case .tools:
                            if PDFnoReadingToolContext(library: active.model).format == .pdf { active.model.reader.captureSelection() }
                        case .japanese: active.model.prepareJapaneseLearning()
                        case .english: active.model.prepareEnglishLearning()
                        case .page: active.model.preparePageTranslation()
                        case .spine: await active.model.prepareChapterTranslation()
                        case .trash:
                            model.prepareRecoveryManagement()
                            guard let recovery = model.recoveryManagement else { return }
                            await recovery.refresh()
                            guard let book = recovery.books.first(where: { $0.id == active.id }) else { documents.error = "当前文件已不可用，请刷新书库。"; return }
                            await recovery.preview(.book(book))
                            guard recovery.changePreview != nil else { documents.error = recovery.message; return }
                        case .settings: break
                        }
                        guard documents.activeID == active.id, navigation.route == .reader else { return }
                        filePanel = MacDocumentFilePanel(model: active.model, action: action, recovery: model.recoveryManagement)
                    }
                }.pdfnoTitlebarControl()
            } else {
                Image(systemName: "ellipsis").frame(width: 22, height: 28).foregroundStyle(.tertiary)
                    .accessibilityLabel("当前文件菜单：需要活动文件").accessibilityIdentifier("document-more-unavailable")
            }
        }.buttonStyle(.plain).font(.system(size: 12)).padding(.horizontal, 2).frame(height: 34)
            .background(PDFnoDesign.Palette.chrome).disabled(navigationBusy || documents.opening)
    }
    private func documentFormat(_ model: LibraryModel) -> String {
        if model.ebook.isActive { return model.ebook.reader.book?.format.rawValue.uppercased() ?? "电子书" }
        if model.textFormats.isActive { return model.textFormats.reader.book?.format.rawValue.uppercased() ?? "文本" }
        if model.docx.isActive { return "DOCX" }
        if model.readingComic { return "漫画" }
        return model.readingEPUB ? "EPUB" : "PDF"
    }
    private var globalSidebar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                if sidebar {
                    Text("PDFno").font(.system(size: 18, weight: .semibold)).accessibilityIdentifier("workspace-brand")
                    Spacer(minLength: 0)
                }
                Button { sidebar.toggle() } label: {
                    Image(systemName: "sidebar.left").frame(width: 28, height: 28).contentShape(Rectangle())
                }.buttonStyle(.plain)
                    .accessibilityLabel(sidebar ? "切换为图标侧栏" : "展开全局侧栏")
                    .accessibilityIdentifier("workspace-sidebar-toggle")
                    .accessibilityValue(sidebar ? "已展开" : "图标侧栏")
                    .help(sidebar ? "切换为图标侧栏" : "展开全局侧栏")
            }.frame(maxWidth: .infinity).padding(.horizontal, sidebar ? 10 : 0).padding(.vertical, 18)
            sidebarButton("书库", "books.vertical", "workspace-library", selected: navigation.route == .library) { navigation.showLibrary() }
            sidebarButton("查找", "magnifyingglass", "library-search", selected: selected(.search)) { showTool(.search) }
            sidebarButton("格式转换", "arrow.triangle.2.circlepath", "document-conversion", selected: selected(.conversion)) { showTool(.conversion) }
            sidebarButton("Bookno 离线预览", "globe", "bookno-preview-open", selected: selected(.bookno)) { showTool(.bookno) }
            sidebarButton("回收站", "trash", "library-local-recovery", selected: selected(.recovery)) {
                model.prepareRecoveryManagement(); if model.recoveryManagement != nil { showTool(.recovery) }
            }
            Spacer()
            Divider().padding(.horizontal, 10)
            sidebarButton("设置", "gearshape", "ai-settings", selected: navigation.route == .settings) { navigation.showSettings() }
            sidebarButton("帮助与示例", "questionmark.circle", "workspace-help", selected: false) { examples = true }
            if sidebar { Text("本地阅读").font(.system(size: 11)).foregroundStyle(.secondary).padding(12) }
            else { Spacer().frame(height: 12) }
        }.padding(8).background(PDFnoDesign.Palette.chrome).disabled(navigationBusy || documents.opening)
    }
    private func sidebarButton(_ title: String, _ symbol: String, _ id: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: symbol).frame(width: 18)
                if sidebar { Text(title).lineLimit(1) }
            }.font(.system(size: 12, weight: selected ? .semibold : .regular))
                .frame(maxWidth: .infinity, minHeight: 38, alignment: sidebar ? .leading : .center)
                .padding(.horizontal, sidebar ? 10 : 0).contentShape(Rectangle())
        }.buttonStyle(.plain).foregroundStyle(selected ? Color.blue : Color.primary)
            .background(selected ? Color.blue.opacity(0.10) : .clear, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityIdentifier(id).accessibilityLabel(title).accessibilityValue(selected ? "已选中" : "未选中").help(title)
    }
    private func selected(_ tool: PDFnoWorkspaceTool) -> Bool { navigation.route == .tool && navigation.tool == tool }
    private func showTool(_ tool: PDFnoWorkspaceTool) { navigation.showTool(tool) }
    private func openBook(_ id: UUID) { selectedBookID = id; Task { if await documents.open(id) { navigation.showReader() } } }
    private var toolTitle: String {
        switch navigation.tool {
        case .search: "查找"
        case .conversion: "格式转换"
        case .bookno: "Bookno 离线预览"
        case .recovery: "回收站"
        default: "帮助"
        }
    }
    private var toolContent: some View {
        VStack(spacing: 0) {
            HStack {
                Text(toolTitle).font(PDFnoDesign.TypeStyle.title)
                Spacer()
                Button("返回") { navigation.returnFromTool(readerAvailable: documents.active != nil) }
                    .disabled(navigationBusy).accessibilityIdentifier("workspace-tool-return")
            }.padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 12)
            Group {
                switch navigation.tool {
                case .search: LibrarySearchWorkspace(library: model, openTarget: documents.openSearchTarget, openRecordTarget: documents.openRecordSearchTarget)
                case .conversion: ConversionWorkspace()
                case .bookno: BooknoPreviewWorkspace(model: model.booknoPreview)
                case .recovery: if let recovery = model.recoveryManagement { LocalRecoveryWorkspace(model: recovery, mode: .recycle, showsTitle: false) }
                default: FeatureStatusView(embedded: true)
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.background(PDFnoDesign.Palette.canvas)
            .environment(\.pdfnoInlineDismiss, { navigation.returnFromTool(readerAvailable: documents.active != nil) })
    }
    private var examplesMenu: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("帮助与示例", systemImage: "doc.text").font(.headline)
            Text("内置原创文档 · 每个文件在独立标签中阅读").font(.caption).foregroundStyle(.secondary)
            Button("打开示例 PDF") { openExample { await $0.openSample() } }.accessibilityIdentifier("open-sample")
            Button("打开示例 EPUB") { openExample { await $0.openEPUBSample() } }.accessibilityIdentifier("open-epub-sample")
            Button("打开示例 DOCX") { openExample { await $0.openDOCXSample() } }.accessibilityIdentifier("open-docx-sample")
            Menu("打开电子书示例") {
                ForEach(EbookFormat.allCases, id: \.self) { format in
                    Button(format.rawValue.uppercased()) { openExample { await $0.openEbookSample(format) } }.accessibilityIdentifier("open-ebook-sample-" + format.rawValue)
                }
            }.accessibilityIdentifier("open-ebook-sample")
            Divider()
            Button("功能与帮助") { examples = false; navigation.showTool(.help) }
        }.buttonStyle(ProfessionalLibraryActionStyle()).padding(20).frame(width: 320)
            .disabled(!model.canImport || documents.opening)
    }
    private func openExample(_ operation: @escaping @MainActor (LibraryModel) async -> Void) {
        examples = false; Task { if await documents.openNew(operation) { navigation.showReader() } }
    }
    private var importTypes: [UTType] {
        [.pdf, .plainText, .html, .xml] + ["htm", "xhtml", "mhtml", "md", "markdown", "epub", "docx"].map { UTType(filenameExtension: $0) ?? .data }
        + ComicArchiveFormat.allCases.map { UTType(filenameExtension: $0.rawValue) ?? .data }
        + EbookFormat.allCases.map { UTType(filenameExtension: $0.rawValue) ?? .data }
    }
}

struct MacDocumentReader: View {
    @ObservedObject var model: LibraryModel
    var workspaceClose: (() -> Void)? = nil
    var body: some View {
        Group {
            if model.ebook.isActive { EbookWorkspace(model: model.ebook, editing: model.recordEditing) }
            else if model.textFormats.isActive { TextFormatWorkspace(model: model.textFormats, editing: model.recordEditing) }
            else if model.docx.isActive { DOCXWorkspace(model: model.docx) }
            else if model.readingComic { ComicWorkspace(session: model.comic, close: { workspaceClose?() }) }
            else if model.readingEPUB { EPUBWorkspace(model: model, session: model.epub) }
            else { ReaderWorkspace(model: model, session: model.reader) }
        }.alert("操作未完成", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
}

#endif
