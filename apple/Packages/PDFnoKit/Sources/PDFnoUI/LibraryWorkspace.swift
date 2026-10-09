// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFKit
import UniformTypeIdentifiers
import PDFnoDomain
import PDFnoReaders

public struct LibraryWorkspace: View {
    @StateObject private var model = LibraryModel()
    @State private var importer = false
    @State private var about = false
    @State private var aiSettings = false
    @State private var aiTools = false
    @State private var conversion = false
    @State private var librarySearch = false
    @State private var booknoPreview = false
    @State private var localRecovery = false
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var selectedBookID: UUID?
    #if os(macOS)
    @State private var grid = true
    @State private var navigationBusy = false
    #else
    @State private var grid = false
    #endif
    @State private var coverEditor: LibraryCoverItem?
    #if os(macOS)
    @StateObject private var workspaceNavigation = PDFnoWorkspaceNavigation()
    private var libraryMode: Bool {
        get { workspaceNavigation.route == .library }
        nonmutating set { if newValue { workspaceNavigation.showLibrary() } else { workspaceNavigation.showReader() } }
    }
    #else
    @State private var libraryMode = true
    #endif
    private let settingsRequest: Int
    @State private var examplesHelp = false
    @State private var toolsPopover = false
    public init(settingsRequest: Int = 0) { self.settingsRequest = settingsRequest }
    #if os(macOS)
    init(model: LibraryModel, navigation: PDFnoWorkspaceNavigation) {
        _model = StateObject(wrappedValue: model)
        _workspaceNavigation = StateObject(wrappedValue: navigation)
        settingsRequest = 0
    }
    #endif
    public var body: some View {
        #if os(macOS)
        MacTabbedWorkspace(model: model, navigation: workspaceNavigation, settingsRequest: settingsRequest)
        #else
        legacyBody
        #endif
    }
    private var legacyBody: some View {
        workspaceContent
        .disabled(model.storageMaintenance)
        .task { await model.load() }
        .onChange(of: displayedBookID) { _, id in
            selectedBookID = id
            if id != nil { libraryMode = false }
        }
        .fileImporter(isPresented: $importer, allowedContentTypes: importTypes) { result in
            switch result {
            case .success(let url): Task { await model.importFile(url); if displayedBookID != nil { compactColumn = .detail; libraryMode = false } }
            case .failure(let error): model.error = error.localizedDescription
            }
        }
        .toolbar { workspaceToolbar }
        #if !os(macOS)
        .sheet(isPresented: $about) { FeatureStatusView() }
        #endif
        #if os(macOS)
        .popover(isPresented: $examplesHelp) { examplesMenu }
        .onChange(of: coverEditor?.id) { _, id in if id != nil { workspaceNavigation.showTool(.cover) } }
        .onChange(of: librarySearch) { _, value in if value { librarySearch = false; workspaceNavigation.showTool(.search) } }
        .onChange(of: localRecovery) { _, value in if value { localRecovery = false; workspaceNavigation.showTool(.recovery) } }
        .onChange(of: booknoPreview) { _, value in if value { booknoPreview = false; workspaceNavigation.showTool(.bookno) } }
        .onChange(of: conversion) { _, value in if value { conversion = false; workspaceNavigation.showTool(.conversion) } }
        .onChange(of: aiTools) { _, value in if value { aiTools = false; workspaceNavigation.showTool(.tools) } }
        .onChange(of: settingsRequest, initial: true) { _, request in if request > 0 && !navigationBusy { workspaceNavigation.showSettings() } }
        .onPreferenceChange(PDFnoWorkspaceBusyKey.self) { navigationBusy = $0 }
        #endif
        .alert("操作未完成", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .overlay { if model.isBusy { PDFnoStatusMessage(text: model.storageMaintenance ? "正在校验并重载书库…" : "正在打开…", kind: .busy).frame(maxWidth: 320).pdfnoCard() } }
    }
    @ViewBuilder private var workspaceContent: some View {
        #if os(macOS)
        ZStack {
            readerContent
                .opacity(workspaceNavigation.route == .reader ? 1 : 0)
                .allowsHitTesting(workspaceNavigation.route == .reader)
                .disabled(workspaceNavigation.route != .reader)
                .accessibilityHidden(workspaceNavigation.route != .reader)
            if libraryMode {
                ProfessionalLibraryWorkspace(model: model, grid: $grid, selectedBookID: $selectedBookID,
                    importFile: { importer = true }, search: { librarySearch = true },
                    examples: { examplesHelp = true }, editCover: { coverEditor = $0 }, openBook: { openSelectedBook($0) },
                    resume: displayedBookID == nil ? nil : { libraryMode = false })
            }
            if workspaceNavigation.route == .tool { inlineTool }
            if workspaceNavigation.hasOpenedSettings {
                AISettingsView(learning: model.learning, byok: model.byok, library: model, embedded: true,
                    active: workspaceNavigation.route == .settings,
                    close: { workspaceNavigation.returnFromSettings(readerAvailable: displayedBookID != nil) })
                    .opacity(workspaceNavigation.route == .settings ? 1 : 0)
                    .allowsHitTesting(workspaceNavigation.route == .settings)
                    .disabled(workspaceNavigation.route != .settings)
                    .accessibilityHidden(workspaceNavigation.route != .settings)
            }
        }.tint(.blue).navigationTitle("PDFno")
            .background(PDFnoWorkspaceWindowTitle(title: workspaceWindowTitle))
            .environment(\.pdfnoWorkspaceNavigation, workspaceNavigation)
        #else
        legacyWorkspace
        #endif
    }
    @ViewBuilder private var readerContent: some View {
        #if os(macOS)
        if model.ebook.isActive { EbookWorkspace(model: model.ebook, editing: model.recordEditing) }
        else if model.textFormats.isActive { TextFormatWorkspace(model: model.textFormats, editing: model.recordEditing) }
        else if model.docx.isActive { DOCXWorkspace(model: model.docx) }
        else if model.readingComic { ComicWorkspace(session: model.comic, close: { model.closeComic() }) }
        else if model.readingEPUB { EPUBWorkspace(model: model, session: model.epub) }
        else { ReaderWorkspace(model: model, session: model.reader) }
        #else
        ReaderWorkspace(model: model, session: model.reader)
        #endif
    }
    @ToolbarContentBuilder private var workspaceToolbar: some ToolbarContent {
        #if os(macOS)
        ToolbarItem(placement: .navigation) {
            if workspaceNavigation.route != .library {
                Button { libraryMode = true } label: { Label("返回书库", systemImage: "books.vertical") }
                    .disabled(navigationBusy).accessibilityIdentifier("workspace-back-library").help("返回书库，保留当前阅读与草稿")
            }
        }
        ToolbarItem {
            Button { workspaceNavigation.showSettings() } label: { Label("设置", systemImage: "gearshape") }
                .disabled(navigationBusy).accessibilityIdentifier("ai-settings")
                .accessibilityValue(workspaceNavigation.route == .settings ? "已选中" : "未选中")
        }
        ToolbarItem {
            Button { toolsPopover.toggle() } label: { Label("更多工具", systemImage: "square.grid.2x2") }
                .disabled(navigationBusy).accessibilityIdentifier("workspace-tools")
                .popover(isPresented: $toolsPopover) { toolsMenu }
        }
        ToolbarItem { Button { examplesHelp = true } label: { Label("帮助与示例", systemImage: "questionmark.circle") }.disabled(navigationBusy).accessibilityIdentifier("workspace-help") }
        ToolbarItem { Button { librarySearch = true } label: { Label("书库与笔记搜索", systemImage: "magnifyingglass") }.disabled(navigationBusy).accessibilityIdentifier("library-search").keyboardShortcut("f", modifiers: [.command, .shift]) }
        #endif
        #if !os(macOS)
        ToolbarItem { Button { about = true } label: { Label("功能状态", systemImage: "info.circle") } }
        #endif
    }
    #if os(macOS)
    private var workspaceWindowTitle: String {
        switch workspaceNavigation.route {
        case .library: "PDFno"
        case .settings: "设置"
        case .reader: coverItems.first(where: { $0.id == displayedBookID })?.title
            ?? model.ebook.reader.book?.title ?? model.textFormats.reader.book?.title ?? "PDFno"
        case .tool: "PDFno · 本地工具"
        }
    }
    private func finishTool() {
        workspaceNavigation.returnFromTool(readerAvailable: displayedBookID != nil)
        coverEditor = nil
    }
    private var inlineTool: some View {
        VStack(spacing: 0) {
            HStack {
                Button { finishTool() } label: { Label("返回", systemImage: "chevron.left") }
                    .disabled(navigationBusy).accessibilityIdentifier("workspace-tool-return")
                Spacer()
                Text("本地工具").foregroundStyle(.secondary)
            }.padding(16).background(PDFnoDesign.Palette.surface)
            Divider()
            Group {
                switch workspaceNavigation.tool {
                case .search: LibrarySearchWorkspace(library: model)
                case .cover: if let coverEditor { LibraryCoverEditor(covers: model.covers, item: coverEditor) }
                case .conversion: ConversionWorkspace()
                case .bookno: BooknoPreviewWorkspace(model: model.booknoPreview)
                case .tools: ReadingToolsWorkspace(library: model)
                case .help: FeatureStatusView()
                case .recovery:
                    NavigationStack {
                        if let recovery = model.recoveryManagement {
                            LocalRecoveryWorkspace(model: recovery)
                                .toolbar { ToolbarItem { Button("完成") { finishTool() }.disabled(recovery.busy).accessibilityIdentifier("local-recovery-close") } }
                        }
                    }
                }
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.environment(\.pdfnoInlineDismiss, { finishTool() })
    }
    private var toolsMenu: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("更多工具").font(.system(size: 16, weight: .semibold))
            Button { toolsPopover = false; model.reader.captureSelection(); aiTools = true } label: { Label("AI 工具", systemImage: "square.grid.2x2") }.accessibilityIdentifier("ai-tools-open")
            Divider()
            Button { toolsPopover = false; booknoPreview = true } label: { Label("Bookno 离线预览", systemImage: "globe") }.accessibilityIdentifier("bookno-preview-open")
            Button { toolsPopover = false; conversion = true } label: { Label("格式转换", systemImage: "arrow.triangle.2.circlepath") }.accessibilityIdentifier("document-conversion")
            Button { toolsPopover = false; model.prepareRecoveryManagement(); localRecovery = model.recoveryManagement != nil } label: { Label("回收站与备份", systemImage: "archivebox") }.accessibilityIdentifier("library-local-recovery").disabled(!model.canImport || model.isBusy)
        }.buttonStyle(ProfessionalLibraryActionStyle()).padding(20).frame(width: 280)
    }
    private var examplesMenu: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("示例文档", systemImage: "doc.text").font(.system(size: 16, weight: .semibold))
            Text("应用内置文档 · 本地试读\n新建示例与个人书籍分别显示。").font(.system(size: 12)).foregroundStyle(.secondary)
            Button("打开示例 PDF") { openExample { await model.openSample() } }.accessibilityIdentifier("open-sample")
            Button("打开示例 EPUB") { openExample { await model.openEPUBSample() } }.accessibilityIdentifier("open-epub-sample")
            Button("打开示例 DOCX") { openExample { await model.openDOCXSample() } }.accessibilityIdentifier("open-docx-sample")
            Menu("打开电子书示例") {
                ForEach(EbookFormat.allCases, id: \.self) { format in
                    Button(format.rawValue.uppercased()) { openExample { await model.openEbookSample(format) } }.accessibilityIdentifier("open-ebook-sample-\(format.rawValue)")
                }
            }.accessibilityIdentifier("open-ebook-sample")
        }.buttonStyle(ProfessionalLibraryActionStyle()).padding(20).frame(width: 270)
            .disabled(!model.canImport || model.isBusy)
    }
    private func openExample(_ action: @escaping @MainActor () async -> Void) {
        examplesHelp = false
        Task { await action(); if displayedBookID != nil { libraryMode = false } }
    }
    #endif
    private func openSelectedBook(_ id: UUID?) {
        guard let id else { return }
        selectedBookID = id
        if id == displayedBookID { libraryMode = false; return }
        Task {
            #if os(macOS)
            if let b = model.ebook.books.first(where: { $0.id == id }) { await model.openEbook(b) }
            else if let b = model.textFormats.books.first(where: { $0.id == id }) { await model.openTextFormat(b) }
            else if let b = model.docx.books.first(where: { $0.id == id }) { await model.openDOCX(b) }
            else if let b = model.books.first(where: { $0.id == id }) { await model.open(b) }
            else if let b = model.comicBooks.first(where: { $0.id == id }) { await model.openComic(b) }
            else if let b = model.epubBooks.first(where: { $0.id == id }) { await model.openEPUB(b) }
            #else
            if let b = model.books.first(where: { $0.id == id }) { await model.open(b) }
            #endif
            if displayedBookID == id { compactColumn = .detail; libraryMode = false }
        }
    }
    private var legacyWorkspace: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            VStack(spacing: 0) {
                #if os(macOS)
                VStack(alignment: .leading, spacing: PDFnoDesign.Space.small) {
                    HStack {
                        Text("我的书库").font(PDFnoDesign.TypeStyle.title)
                        Spacer()
                        Text("\(libraryBookCount) 本").font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary)
                    }
                    PDFnoLibraryLayoutPicker(grid: $grid)
                    Button { aiSettings = true } label: { Label("模型与 BYOK 设置", systemImage: "slider.horizontal.3") }
                        .buttonStyle(PDFnoActionStyle(role: .quiet)).accessibilityIdentifier("ai-settings")
                        .help("配置模型与会话临时密钥")
                }.padding(PDFnoDesign.Space.regular)
                #endif
                Group {
                    if grid {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 108), alignment: .top)], spacing: PDFnoDesign.Space.section) {
                                ForEach(coverItems) { item in
                                    LibraryCoverRow(covers: model.covers, item: item, grid: true) { coverEditor = item }
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedBookID = item.id }
                                        .accessibilityAction { selectedBookID = item.id }
                                        .focusable()
                                        .onKeyPress(.return) { selectedBookID = item.id; return .handled }
                                        .onKeyPress(.space) { selectedBookID = item.id; return .handled }
                                        .padding(PDFnoDesign.Space.small)
                                        .background(selectedBookID == item.id ? PDFnoDesign.Palette.selection : Color.clear, in: RoundedRectangle(cornerRadius: PDFnoDesign.Metric.corner))
                                }
                                #if os(macOS)
                                ForEach(model.textFormats.books) { book in
                                    Label(book.title + " · " + book.format.label, systemImage: "doc.plaintext")
                                        .accessibilityElement(children: .contain)
                                        .accessibilityIdentifier("library-textformat")
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedBookID = book.id }
                                        .accessibilityAction { selectedBookID = book.id }
                                        .focusable()
                                        .onKeyPress(.return) { selectedBookID = book.id; return .handled }
                                        .onKeyPress(.space) { selectedBookID = book.id; return .handled }
                                        .padding(PDFnoDesign.Space.small)
                                        .background(selectedBookID == book.id ? PDFnoDesign.Palette.selection : Color.clear, in: RoundedRectangle(cornerRadius: PDFnoDesign.Metric.corner))
                                }
                                #endif
                            }.padding(PDFnoDesign.Space.regular)
                            if libraryIsEmpty { libraryEmptyState.padding(PDFnoDesign.Space.section) }
                            ebookShelf
                        }
                    } else {
                        List(selection: $selectedBookID) {
                            Section("我的书库") {
                                if libraryIsEmpty { libraryEmptyState }
                                ForEach(coverItems) { item in
                                    LibraryCoverRow(covers: model.covers, item: item, grid: false) { coverEditor = item }.tag(item.id)
                                }
                                #if os(macOS)
                                ForEach(model.ebook.books) { book in ebookRow(book).tag(book.id) }
                                ForEach(model.textFormats.books) { book in
                                    Label(book.title + " · " + book.format.label, systemImage: "doc.plaintext")
                                        .tag(book.id).accessibilityIdentifier("library-textformat")
                                }
                                #endif
                            }
                        }
                    }
                }
                .onChange(of: selectedBookID) { _, id in
                    guard id != displayedBookID else { return }
                    #if os(macOS)
                    if let book = model.ebook.books.first(where: { $0.id == id }) { Task { await model.openEbook(book); if model.ebook.isActive { compactColumn = .detail } }; return }
                    if let book = model.textFormats.books.first(where: { $0.id == id }) {
                        Task { await model.openTextFormat(book); if model.textFormats.isActive { compactColumn = .detail } }; return
                    }
                    if let book = model.docx.books.first(where: { $0.id == id }) {
                        Task { await model.openDOCX(book); if model.docx.isActive { compactColumn = .detail } }; return
                    }
                    #endif
                    if let book = model.books.first(where: { $0.id == id }) {
                        Task { await model.open(book); if model.reader.book?.id == book.id { compactColumn = .detail } }
                    } else if let book = model.comicBooks.first(where: { $0.id == id }) {
                        Task { await model.openComic(book); compactColumn = .detail }
                    } else if let book = model.epubBooks.first(where: { $0.id == id }) {
                        Task { await model.openEPUB(book); compactColumn = .detail }
                    }
                }
                Divider()
                ScrollView {
                    VStack(spacing: PDFnoDesign.Space.small) {
                        Button { importer = true } label: { Label(importTitle, systemImage: "plus").frame(maxWidth: .infinity) }
                            .buttonStyle(PDFnoActionStyle(role: .primary)).disabled(!model.canImport || model.isBusy)
                            .accessibilityIdentifier("import-pdf")
                        Button("打开示例 PDF") {
                            Task { await model.openSample(); if model.reader.book != nil { compactColumn = .detail } }
                        }.disabled(!model.canImport || model.isBusy).accessibilityIdentifier("open-sample")
                        #if os(macOS)
                        Button("打开示例 DOCX") { Task { await model.openDOCXSample(); compactColumn = .detail } }
                            .disabled(!model.canImport || model.isBusy).accessibilityIdentifier("open-docx-sample")
                        Button("打开示例 EPUB") { Task { await model.openEPUBSample(); compactColumn = .detail } }
                            .disabled(!model.canImport || model.isBusy).accessibilityIdentifier("open-epub-sample")
                        Button("Bookno 离线预览") { booknoPreview = true }
                            .disabled(!model.canImport || model.isBusy).accessibilityIdentifier("bookno-preview-open")
                        #endif
                        #if os(macOS)
                        Menu("打开电子书示例") {
                            ForEach(EbookFormat.allCases, id: \.self) { format in
                                Button(format.rawValue.uppercased()) { Task { await model.openEbookSample(format); compactColumn = .detail } }
                                    .accessibilityIdentifier("open-ebook-sample-\(format.rawValue)")
                            }
                        }.disabled(!model.canImport || model.isBusy).accessibilityIdentifier("open-ebook-sample")
                        #endif
                        #if os(macOS)
                        Button { model.reader.captureSelection(); aiTools = true } label: { Label("AI工具", systemImage: "square.grid.2x2") }
                            .accessibilityIdentifier("ai-tools-open").disabled(model.isBusy || model.storageMaintenance)
                        #endif
                        Text("仅在设备本地处理").font(.caption).foregroundStyle(.secondary)
                    }.buttonStyle(PDFnoActionStyle(role: .quiet))
                        .padding(PDFnoDesign.Space.regular)
                }.frame(maxHeight: 260)
            }.background(PDFnoDesign.Palette.chrome).navigationTitle("PDFno")
            .navigationSplitViewColumnWidth(min: PDFnoDesign.Metric.sidebarMinimum, ideal: PDFnoDesign.Metric.sidebarIdeal, max: PDFnoDesign.Metric.sidebarMaximum)
        } detail: {
            #if os(macOS)
            if model.ebook.isActive { EbookWorkspace(model: model.ebook, editing: model.recordEditing) }
            else if model.textFormats.isActive { TextFormatWorkspace(model: model.textFormats, editing: model.recordEditing) }
            else if model.docx.isActive { DOCXWorkspace(model: model.docx) }
            else if model.readingComic { ComicWorkspace(session: model.comic, close: { model.closeComic() }) }
            else if model.readingEPUB { EPUBWorkspace(model: model, session: model.epub) }
            else { ReaderWorkspace(model: model, session: model.reader) }
            #else
            ReaderWorkspace(model: model, session: model.reader)
            #endif
        }
    }
    private var libraryBookCount: Int {
        #if os(macOS)
        coverItems.count + model.textFormats.books.count + model.ebook.books.count
        #else
        coverItems.count
        #endif
    }
    private var libraryEmptyState: some View {
        VStack(alignment: .leading, spacing: PDFnoDesign.Space.small) {
            Label("导入书籍，开始阅读", systemImage: "books.vertical").font(PDFnoDesign.TypeStyle.section)
            Text("选择本地文件，或试读下方自制示例。").font(PDFnoDesign.TypeStyle.body).foregroundStyle(.secondary)
        }.padding(.vertical, PDFnoDesign.Space.regular).accessibilityIdentifier("library-empty-state")
    }
    private var libraryIsEmpty: Bool {
        #if os(macOS)
        coverItems.isEmpty && model.textFormats.books.isEmpty && model.ebook.books.isEmpty
        #else
        coverItems.isEmpty
        #endif
    }
    #if os(macOS)
    private func ebookRow(_ book: EbookBook) -> some View {
        HStack {
            Image(systemName: "book.closed").font(.title2).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: PDFnoDesign.Space.tight) {
                Text(book.title).font(PDFnoDesign.TypeStyle.section).lineLimit(2)
                Text("\(book.format.rawValue.uppercased()) · 本地").font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary)
            }
        }.accessibilityElement(children: .combine).accessibilityIdentifier("library-ebook-\(book.format.rawValue)")
    }
    private var ebookShelf: some View {
        ForEach(model.ebook.books) { book in
            Button { selectedBookID = book.id } label: { ebookRow(book) }.buttonStyle(.plain).padding(8)
        }
    }
    #else
    private var ebookShelf: some View { EmptyView() }
    #endif
    private var coverItems: [LibraryCoverItem] {
        var items = model.books.map { LibraryCoverItem(identity: CoverIdentity($0), title: $0.title, subtitle: "PDF · \($0.pageCount) 页 · 本地", accessibilityID: "library-book") }
        #if os(macOS)
        items += model.docx.books.map { LibraryCoverItem(identity: CoverIdentity($0), title: $0.title, subtitle: "DOCX · 本地", accessibilityID: "library-docx") }
        items += model.comicBooks.map { LibraryCoverItem(identity: CoverIdentity($0), title: $0.title, subtitle: "\($0.archiveFormat?.rawValue.uppercased() ?? "漫画") · \($0.pages.count) 页 · 本地", accessibilityID: "library-comic") }
        items += model.epubBooks.map { LibraryCoverItem(identity: CoverIdentity($0), title: $0.title, subtitle: "EPUB · 本地", accessibilityID: "library-epub") }
        #endif
        return items
    }
    private var importTitle: String {
        #if os(macOS)
        "导入书籍 / 文本"
        #else
        "导入 PDF"
        #endif
    }
    private var displayedBookID: UUID? {
        #if os(macOS)
        if model.ebook.isActive { return model.ebook.reader.book?.id }
        if model.textFormats.isActive { return model.textFormats.reader.book?.id }
        if model.docx.isActive { return model.docx.reader.book?.id }
        if model.readingComic { return model.comic.book?.id }
        if model.readingEPUB { return model.epub.book?.id }
        #endif
        return model.reader.book?.id
    }
    private var importTypes: [UTType] {
        #if os(macOS)
        let documents: [UTType] = [.pdf, .plainText, .html, .xml]
        let text: [UTType] = [UTType(filenameExtension: "htm") ?? .html, UTType(filenameExtension: "xhtml") ?? .xml,
                              UTType(filenameExtension: "mhtml") ?? .data, UTType(filenameExtension: "md") ?? .plainText,
                              UTType(filenameExtension: "markdown") ?? .plainText]
        let books: [UTType] = [UTType(filenameExtension: "epub") ?? .data, UTType(filenameExtension: "docx") ?? .data]
        let comics: [UTType] = ComicArchiveFormat.allCases.map { format in
            let fallback: UTType = format == .cbz ? .zip : .archive
            return UTType(filenameExtension: format.rawValue, conformingTo: fallback) ?? fallback
        }
        let ebooks: [UTType] = EbookFormat.allCases.map { UTType(filenameExtension: $0.rawValue) ?? .data }
        return documents + text + books + comics + ebooks
        #else
        [.pdf]
        #endif
    }
}

public struct FeatureStatusView: View {
    @Environment(\.dismiss) private var dismiss
    private let embedded: Bool
    public init(embedded: Bool = false) { self.embedded = embedded }
    public var body: some View {
        NavigationStack {
            List {
                Section("当前可以使用") {
                    Label("本地 PDF 导入、阅读、目录与搜索", systemImage: "checkmark.circle")
                    Label("选区高亮、笔记与本地保存", systemImage: "checkmark.circle")
                    #if os(macOS)
                    Text("TXT／Markdown／HTML／XHTML／MHTML／可读 XML：Mac 本地正文、标题导航、选文笔记与进度；图片、样式与链接目标不加载")
                    Text("电子书候选：MOBI / AZW / AZW3 / FB2；无 DRM 正文、目录与笔记代码已接入，隔离 Mac 验收待完成")
                    Text("DOCX：Mac 语义重排阅读、标题目录与选文笔记；与 Word 原版式不同；DOC 未支持")
                    Label("CBZ / CBT / 有限 CB7 / CBR 漫画：导入、页序、左右方向、单双页与进度恢复", systemImage: "checkmark.circle")
                    Label("DOCX 正文转 TXT / 简化 HTML（有损副本）", systemImage: "checkmark.circle")
                    Text("DOCX 阅读版PDF：本机语义正文重新分页，不能还原Word原版式；独立导出入口已接，实际UI待验收")
                    Text("有限HTTPS BYOK选文：PDF/EPUB最多500 UTF-16，逐次确认域名/模型/完整原文；仅会话密钥，实际服务质量待验收")
                    #endif
                }
                Section("后续接入") {
                    Text("EPUB：Mac 本地重排阅读；移动适配与固定版式待验收")
                    Text("Mac AI：选文翻译／解释、受限 PDF 当前页与 EPUB 当前完整文档双语对照；范围预览、手动确认发送和学习笔记。当前 EPUB 文档不等于目录逻辑章节；日语选文读音与中文语法建议可审阅并手动保存；英语选文结构与语法及保存／搜索／编辑入口已接；真实语言质量与实际新界面闭环待验收")
                    Text("本地回收站、校验目录备份和恢复到新目录：Mac候选已接线；实际目录选择与新界面闭环待隔离验收。未保存草稿不进入备份。")
                    Text("Bookno API：尚未接入")
                    Text("iCloud：未配置容器，数据仅保存在本地")
                    Text("CBZ / CBT：移动阅读适配待验收；当前 Mac 支持静态 PNG / JPEG，CBT 限未压缩 POSIX USTAR；CB7 限非 solid COPY/LZMA/LZMA2 和明文头；CBR 限 RAR4/RAR5 STORE")
                    Text("其他格式阅读 / PDF、Word、EPUB 高保真互转 / OCR / Apple Pencil：尚未实现")
                }
                Section("开源") { Text("PDFno · AGPL-3.0-or-later").font(.footnote) }
            }.navigationTitle("功能状态")
            .toolbar { if !embedded { ToolbarItem { Button("完成") { dismiss() } } } }
        }.frame(minWidth: 300, minHeight: 420)
    }
}

struct ReaderWorkspace: View {
    @ObservedObject var model: LibraryModel
    @ObservedObject var session: PDFReaderSession
    #if os(macOS)
    @Environment(\.pdfnoWorkspaceNavigation) private var workspaceNavigation
    #endif
    @State private var navigation = false
    @State private var notesPanel = false
    @State private var panels = PDFnoReaderPanels()
    @State private var readerWidth: CGFloat = 0
    @State private var searchText = ""
    @State private var searched = false
    @State private var draft = ""
    #if os(macOS)
    @State private var inspector = PDFnoReaderInspector.notes
    @State private var navigationTab = PDFnoReaderNavigationTab.contents
    @State private var readerSettings = false
    @FocusState private var searchFocused: Bool
    #endif
    @State private var pageTranslation = false
    @State private var japaneseLearning = false
    @State private var englishLearning = false
    @State private var draftOwner = UUID().uuidString
    @State private var byokLearning = false
    @State private var aiTools = false
    var body: some View {
        Group {
            if let book = session.book {
                VStack(spacing: 0) {
                    #if os(macOS)
                    PDFnoProfessionalReaderChrome(title: book.title, format: "PDF") {
                        Button { session.go(to: session.pageIndex - 1) } label: { Label("上一页", systemImage: "chevron.left") }
                            .disabled(session.pageIndex == 0).accessibilityIdentifier("previous-page").help("阅读上一页")
                        Button { session.go(to: session.pageIndex + 1) } label: { Label("下一页", systemImage: "chevron.right") }
                            .disabled(session.pageIndex >= book.pageCount - 1).accessibilityIdentifier("next-page").help("阅读下一页")
                        PDFReturnToPreviousLocationButton(session: session)
                    } actions: { professionalActions } content: {
                        PDFnoReaderShell(panels: panels, profile: .professional) {
                            VStack(spacing: 0) {
                                if session.capturedSelection != nil { selectionActions }
                                PDFCanvas(session: session).background(PDFnoDesign.Palette.canvas)
                                    .onReceive(NotificationCenter.default.publisher(for: .PDFViewSelectionChanged)) { notification in
                                        guard let view = notification.object as? PDFView, view === session.view else { return }
                                        session.captureSelection()
                                    }
                                    .background { PDFReaderNavigationShortcuts(session: session) }
                            }
                        } navigation: {
                            PDFnoPanel(title: "导航与搜索", icon: "list.bullet", closeIdentifier: "close-navigation", close: closeNavigation) { navigationContent }
                        } notes: {
                            if inspector == .learning {
                                ReadingSelectionWorkspace(library: model) { panels.notes = false }
                            } else {
                                PDFnoPanel(title: "高亮与笔记", icon: "highlighter", closeIdentifier: "close-notes", close: closeNotes) { notesContent }
                            }
                        }
                        .background {
                            GeometryReader { geometry in
                                Color.clear.onAppear { readerWidth = geometry.size.width }
                                    .onChange(of: geometry.size.width) { _, width in readerWidth = width }
                            }
                        }
                    }
                    #else
                    PDFCanvas(session: session).background(PDFnoDesign.Palette.canvas)
                    #endif
                    HStack {
                        Text("第 \(session.pageIndex + 1) / \(book.pageCount) 页").monospacedDigit()
                            .accessibilityIdentifier("page-position")
                        Spacer()
                        Text(model.status).lineLimit(1)
                    }.font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary).padding(PDFnoDesign.Space.regular)
                        .background(PDFnoDesign.Palette.chrome)
                }.navigationTitle(book.title)
                #if !os(macOS)
                .toolbar {
                    ToolbarItemGroup {
                        Button { openNavigation() } label: { Label("导航与搜索", systemImage: "list.bullet") }
                            .accessibilityIdentifier("reader-navigation").keyboardShortcut("f", modifiers: .command).accessibilityValue(navigationVisible ? "已展开" : "已收起").help("显示或收起 PDF 目录与文本搜索")
                        Button { session.go(to: session.pageIndex - 1) } label: { Label("上一页", systemImage: "chevron.left") }
                            .disabled(session.pageIndex == 0).accessibilityIdentifier("previous-page").help("阅读上一页")
                        Button { session.go(to: session.pageIndex + 1) } label: { Label("下一页", systemImage: "chevron.right") }
                            .disabled(session.pageIndex >= book.pageCount - 1).accessibilityIdentifier("next-page").help("阅读下一页")
                        PDFReturnToPreviousLocationButton(session: session)
                        Button { openNotes() } label: { Label("高亮与笔记", systemImage: "highlighter") }
                            .accessibilityIdentifier("reader-notes").accessibilityValue(notesVisible ? "已展开" : "已收起").help("显示或收起高亮与笔记，保留草稿和选区")
                    }
                }
                #endif
                .onChange(of: session.pageIndex) { _, _ in
                    if let snapshot = model.capturePDFProgress() { Task { await model.saveProgress(snapshot) } }
                }
            } else {
                ContentUnavailableView {
                    Label("留一点时间，读一本书", systemImage: "book")
                } description: {
                    Text("从书库导入 PDF，或打开自制示例。\n你的原文件不会被改写。")
                }
            }
        }
        #if !os(macOS)
        .sheet(isPresented: $navigation) { navigationSheet }
        .sheet(isPresented: $notesPanel) { notesSheet }
        #endif
        #if os(macOS)
        .onChange(of: draft) { _, value in model.recordVisibleDraft(owner: draftOwner, dirty: !value.isEmpty) }
        .onDisappear { model.recordVisibleDraft(owner: draftOwner, dirty: false) }
        .sheet(isPresented: $englishLearning) { EnglishLearningSheet(library: model) }
        .sheet(isPresented: $japaneseLearning) { JapaneseLearningSheet(library: model) }
        .sheet(isPresented: $readerSettings) { AISettingsView(learning: model.learning, byok: model.byok, library: model) }
        .sheet(isPresented: $pageTranslation) { PDFPageTranslationWorkspace(library: model, translation: model.pageTranslation, learning: model.learning) }
        .sheet(isPresented: $byokLearning) { BYOKLearningWorkspace(library: model, model: model.byok) }
        .sheet(isPresented: $aiTools) { ReadingToolsWorkspace(library: model) }
        #endif
    }
    private var navigationVisible: Bool {
        #if os(macOS)
        panels.placement(width: readerWidth, profile: .professional).showNavigation
        #else
        navigation
        #endif
    }
    private var notesVisible: Bool {
        #if os(macOS)
        panels.placement(width: readerWidth, profile: .professional).showNotes && inspector == .notes
        #else
        notesPanel
        #endif
    }
    private func openNavigation() {
        #if os(macOS)
        navigationTab = .contents
        panels.toggle(.navigation, width: readerWidth, profile: .professional)
        #else
        navigation = true
        #endif
    }
    private func openNotes() {
        #if os(macOS)
        if inspector == .notes { panels.toggle(.notes, width: readerWidth, profile: .professional) }
        else { inspector = .notes; panels.show(.notes) }
        #else
        notesPanel = true
        #endif
    }
    private func closeNavigation() {
        navigation = false; panels.navigation = false
        #if os(macOS)
        navigationTab = .contents; searchFocused = false
        #endif
    }
    private func closeNotes() { notesPanel = false; panels.notes = false }
    private var navigationSheet: some View {
        NavigationStack {
            navigationContent.navigationTitle("导航与搜索")
                .toolbar { ToolbarItem { Button("完成", action: closeNavigation).accessibilityIdentifier("close-navigation") } }
        }.frame(minWidth: 300, minHeight: 400)
    }
    private var navigationContent: some View {
        #if os(macOS)
        let navigationSessionID = session.readerSessionID
        return VStack(spacing: 0) {
            #if os(macOS)
            PDFnoReaderNavigationPicker(tab: $navigationTab)
            #endif
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary).accessibilityHidden(true)
                TextField("输入关键词", text: $searchText).accessibilityIdentifier("search-input")
                    .onSubmit(performSearch)
                    #if os(macOS)
                    .focused($searchFocused).autocorrectionDisabled()
                    #endif
                Button("查找", action: performSearch).accessibilityIdentifier("search-submit")
            }.textFieldStyle(.plain).padding(10)
                .background(PDFnoDesign.Palette.canvas, in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12).padding(.bottom, 10)
            Divider()
            List {
                #if os(macOS)
                if navigationTab == .search { searchResults }
                else { contentsResults(navigationSessionID: navigationSessionID) }
                #else
                searchResults
                contentsResults(navigationSessionID: navigationSessionID)
                #endif
            }.listStyle(.sidebar)
        }.buttonStyle(.borderless).font(PDFnoDesign.TypeStyle.body)
        #else
        return mobileNavigationContent
        #endif
    }
    #if !os(macOS)
    private var mobileNavigationContent: some View {
        let navigationSessionID = session.readerSessionID
        return VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                Text("查找文本").font(.headline)
                HStack {
                    TextField("输入关键词", text: $searchText).accessibilityIdentifier("search-input")
                        .onSubmit { session.search(searchText); searched = true }
                    Button("查找") { session.search(searchText); searched = true }.accessibilityIdentifier("search-submit")
                }
            }.padding()
            Divider()
            List {
                Section("搜索结果") {
                    if searched {
                        Text("找到 \(session.searchMatches.count) 项（最多显示 100 项）").font(.caption)
                            .accessibilityIdentifier("search-status")
                    }
                    ForEach(session.searchMatches, id: \.self) { match in
                        Button { if session.show(match) { closeNavigation() } } label: {
                            Text(match.string ?? "匹配结果")
                                .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }
                            .accessibilityIdentifier("search-result")
                    }
                    if searched && session.searchMatches.isEmpty { PDFnoEmptyState(title: "没有匹配文本", detail: "扫描页可能没有可选文字。请更换关键词或检查文字层。", icon: "magnifyingglass") }
                }
                Section("目录") {
                    if session.outline.isEmpty { PDFnoEmptyState(title: "此 PDF 没有内置目录", detail: "可以从下方页码或文本搜索定位。") }
                    ForEach(session.outline) { item in
                        Button { if session.jump(to: item) { closeNavigation() } } label: {
                            Text(item.title).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }
                    }
                }
                Section("页面") {
                    ForEach(0..<(session.document?.pageCount ?? 0), id: \.self) { index in
                        Button { if session.jump(to: index, in: navigationSessionID) { closeNavigation() } } label: {
                            Text("第 \(index + 1) 页").frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                        }
                    }
                }
            }
        }.buttonStyle(.borderless).font(PDFnoDesign.TypeStyle.body)
    }
    #endif
    private func performSearch() {
        session.search(searchText); searched = true
        #if os(macOS)
        navigationTab = .search
        #endif
    }
    private var searchResults: some View {
        Section("搜索结果") {
            if searched {
                Text("找到 \(session.searchMatches.count) 项（最多显示 100 项）").font(.caption)
                    .accessibilityIdentifier("search-status")
            }
            ForEach(session.searchMatches, id: \.self) { match in
                Button { if session.show(match) { closeNavigation() } } label: {
                    Text(match.string ?? "匹配结果")
                        .frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.accessibilityIdentifier("search-result")
            }
            if searched && session.searchMatches.isEmpty { PDFnoEmptyState(title: "没有匹配文本", detail: "扫描页可能没有可选文字。请更换关键词或检查文字层。", icon: "magnifyingglass") }
        }
    }
    @ViewBuilder private func contentsResults(navigationSessionID: UUID) -> some View {
        Section("目录") {
            if session.outline.isEmpty { PDFnoEmptyState(title: "此 PDF 没有内置目录", detail: "可以从下方页码或文本搜索定位。") }
            ForEach(session.outline) { item in
                Button { if session.jump(to: item) { closeNavigation() } } label: {
                    Text(item.title).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
            }
        }
        Section("页面") {
            ForEach(0..<(session.document?.pageCount ?? 0), id: \.self) { index in
                Button { if session.jump(to: index, in: navigationSessionID) { closeNavigation() } } label: {
                    Text("第 \(index + 1) 页").frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }
            }
        }
    }
    #if os(macOS)
    private var professionalActions: some View {
        Group {
            PDFnoReaderRailButton(title: "目录", symbol: "list.bullet", identifier: "reader-navigation", accessibilityTitle: "导航与搜索", active: navigationVisible && navigationTab == .contents, hint: "显示或收起目录与页码", action: openNavigation)
                .accessibilityValue(navigationVisible ? "已展开" : "已收起")
            PDFnoReaderRailButton(title: "查找", symbol: "magnifyingglass", identifier: "reader-search", active: navigationVisible && navigationTab == .search, hint: "查找 PDF 文本 · ⌘F") {
                navigationTab = .search; panels.show(.navigation); searchFocused = true
            }.keyboardShortcut("f", modifiers: .command)
            PDFnoReaderRailButton(title: "笔记", symbol: "highlighter", identifier: "reader-notes", accessibilityTitle: "高亮与笔记", active: notesVisible, hint: "显示或收起高亮与笔记，保留草稿和选区", action: openNotes)
            PDFnoReaderRailButton(title: "AI", symbol: "sparkles", identifier: "reader-ai", accessibilityTitle: "选文 AI", active: panels.placement(width: readerWidth, profile: .professional).showNotes && inspector == .learning, disabled: session.capturedSelection == nil && model.learning.source == nil, hint: "先选择原文；固定选文后核对接收方与任务") {
                if panels.placement(width: readerWidth, profile: .professional).showNotes && inspector == .learning { panels.notes = false }
                else { model.learning.prepare(model.captureAISource()); inspector = .learning; panels.show(.notes) }
            }

        }
    }
    #endif
    #if os(macOS)
    private var selectionActions: some View {
        ReadingSelectionActions(available: session.capturedSelection != nil, busy: model.hasDocumentSaveInFlight,
            highlight: { session.captureSelection(); if let anchor = session.capturedSelection { _ = model.savePDFNoteImmediately(anchor: anchor, text: "") } },
            note: { session.captureSelection(); inspector = .notes; panels.show(.notes) },
            translate: { openSelection(.translate) }, explain: { openSelection(.explain) },
            japanese: { model.prepareJapaneseLearning(); japaneseLearning = true },
            english: { model.prepareEnglishLearning(); englishLearning = true })
    }
    private func openSelection(_ kind: AILearningKind) {
        model.learning.kind = kind; model.learning.prepare(model.captureAISource())
        inspector = .learning; panels.show(.notes)
    }
    #endif
    private var notesSheet: some View {
        NavigationStack {
            notesContent.navigationTitle("高亮与笔记")
                .toolbar { ToolbarItem { Button("完成", action: closeNotes).accessibilityIdentifier("close-notes") } }
        }.frame(minWidth: 300, minHeight: 420)
    }
    private var notesContent: some View {
        #if os(macOS)
        VStack(spacing: 0) {
            PDFNoteComposer(anchor: session.capturedSelection, draft: $draft, enabled: !model.storageMaintenance) { anchor, text in
                model.savePDFNoteImmediately(anchor: anchor, text: text)
            }
            Divider()
            List { savedNotesContent }.accessibilityIdentifier("pdf-notes-list")
        }.font(PDFnoDesign.TypeStyle.body)
        #else
        List {
            Section("当前选区") {
                if let anchor = session.capturedSelection {
                    PDFnoTextViewport(text: anchor.quote)
                    TextField("写下你的笔记（可选）", text: $draft, axis: .vertical).lineLimit(3...8)
                        .accessibilityIdentifier("note-input")
                    if !draft.isEmpty { PDFnoStatusMessage(text: "草稿未保存 · 关闭面板会保留，保存成功后清空") }
                    Button("保存高亮与笔记") {
                        if model.savePDFNoteImmediately(anchor: anchor, text: draft) { draft = "" }
                    }.buttonStyle(PDFnoActionStyle(role: .primary)).accessibilityIdentifier("save-note")
                } else { PDFnoEmptyState(title: "尚未选择原文", detail: "在 PDF 中选中文字，再打开这里。扫描页或受限文件可能不可选择。") }
            }
            savedNotesContent
        }.font(PDFnoDesign.TypeStyle.body).accessibilityIdentifier("pdf-notes-list")
        #endif
    }
    @ViewBuilder private var savedNotesContent: some View {
            Section("已保存 · 本地") {
                let notes = model.notes.filter { $0.bookID == session.book?.id }
                if notes.isEmpty { PDFnoEmptyState(title: "这本书还没有笔记", detail: "选择原文后保存高亮或笔记；来源会随记录保留。", icon: "note.text") }
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(note.anchor.quote).font(.callout).accessibilityIdentifier("saved-note-quote")
                        if !note.userText.isEmpty { Text(verbatim: note.userText).foregroundStyle(.secondary).accessibilityIdentifier("saved-note-user-text") }
                        #if os(macOS)
                        NoteBodyEditor(editor: model.noteEditing, note: .pdf(note), identifier: "pdf-note") {
                            await model.saveEditedNote(.pdf(note))
                        } reload: { await model.reloadEditedNote(.pdf(note)) }
                        #endif
                        Button("回到原文 · 第 \((note.anchor.regions.first?.pageIndex ?? 0) + 1) 页") {
                            if session.navigate(to: note.anchor) == .exact { closeNotes() }
                            else { model.error = "来源无法精确恢复，旧引文已保留；请重新选择原文。" }
                        }.accessibilityIdentifier("return-to-source")
                    }.padding(.vertical, 4)
                }
            }
            #if os(macOS)
            JapaneseSavedNotesSection(library: model, bookID: session.book?.id) { closeNotes() }
            EnglishSavedNotesSection(library: model, bookID: session.book?.id) { closeNotes() }
            #endif
    }
}
