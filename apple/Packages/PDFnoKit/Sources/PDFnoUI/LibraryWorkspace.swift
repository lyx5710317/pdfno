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
    @State private var conversion = false
    @State private var librarySearch = false
    @State private var booknoPreview = false
    @State private var localRecovery = false
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var selectedBookID: UUID?
    @State private var grid = false
    @State private var coverEditor: LibraryCoverItem?
    public init() {}
    public var body: some View {
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
        .disabled(model.storageMaintenance)
        .task { await model.load() }
        .onChange(of: displayedBookID) { _, id in selectedBookID = id }
        .fileImporter(isPresented: $importer, allowedContentTypes: importTypes) { result in
            switch result {
            case .success(let url): Task { await model.importFile(url); compactColumn = .detail }
            case .failure(let error): model.error = error.localizedDescription
            }
        }
        .toolbar {
            ToolbarItem { Button { about = true } label: { Label("功能状态", systemImage: "info.circle") } }
            #if os(macOS)
            ToolbarItem {
                Button { coverEditor = coverItems.first { $0.id == selectedBookID } } label: { Label("编辑封面", systemImage: "photo") }
                    .disabled(!coverItems.contains { $0.id == selectedBookID }).accessibilityIdentifier("library-edit-cover")
                    .help(model.textFormats.isActive ? "文本格式封面尚未开放" : "编辑选中书籍的本地封面")
            }
            ToolbarItem { Button { librarySearch = true } label: { Label("书库与笔记搜索", systemImage: "magnifyingglass") }.accessibilityIdentifier("library-search").keyboardShortcut("f", modifiers: [.command, .shift]).help("搜索书名与已保存笔记") }
            ToolbarItem { Button {
                model.prepareRecoveryManagement(); localRecovery = model.recoveryManagement != nil
            } label: { Label("回收站与备份", systemImage: "archivebox") }
                .disabled(!model.canImport || model.isBusy || model.storageMaintenance)
                .accessibilityIdentifier("library-local-recovery").help("预览本地删除、恢复与校验备份") }
            ToolbarItem { Button { conversion = true } label: { Label("格式转换", systemImage: "arrow.triangle.2.circlepath") }.accessibilityIdentifier("document-conversion").help("打开本地格式转换") }
            #endif
        }
        .sheet(isPresented: $about) { FeatureStatusView() }
        #if os(macOS)
        .sheet(item: $coverEditor) { item in LibraryCoverEditor(covers: model.covers, item: item) }
        .sheet(isPresented: $librarySearch) { LibrarySearchWorkspace(library: model) }
        .sheet(isPresented: $localRecovery) {
            NavigationStack {
                if let recovery = model.recoveryManagement {
                    LocalRecoveryWorkspace(model: recovery)
                        .toolbar { ToolbarItem { Button("完成") { localRecovery = false }.accessibilityIdentifier("local-recovery-close") } }
                }
            }.frame(minWidth: PDFnoDesign.Metric.sheetMinimum, idealWidth: 640, minHeight: 520)
        }
        .sheet(isPresented: $booknoPreview) { BooknoPreviewWorkspace(model: model.booknoPreview) }
        .sheet(isPresented: $conversion) { ConversionWorkspace() }
        .sheet(isPresented: $aiSettings) { AISettingsView(learning: model.learning, byok: model.byok) }
        #endif
        .alert("操作未完成", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .overlay { if model.isBusy { PDFnoStatusMessage(text: model.storageMaintenance ? "正在校验并重载书库…" : "正在打开…", kind: .busy).frame(maxWidth: 320).pdfnoCard() } }
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
    public init() {}
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
            .toolbar { ToolbarItem { Button("完成") { dismiss() } } }
        }.frame(minWidth: 300, minHeight: 420)
    }
}

struct ReaderWorkspace: View {
    @ObservedObject var model: LibraryModel
    @ObservedObject var session: PDFReaderSession
    @State private var navigation = false
    @State private var notesPanel = false
    @State private var panels = PDFnoReaderPanels()
    @State private var readerWidth: CGFloat = 0
    @State private var searchText = ""
    @State private var searched = false
    @State private var draft = ""
    @State private var ai = false
    @State private var pageTranslation = false
    @State private var japaneseLearning = false
    @State private var englishLearning = false
    @State private var draftOwner = UUID().uuidString
    @State private var byokLearning = false
    var body: some View {
        Group {
            if let book = session.book {
                VStack(spacing: 0) {
                    #if os(macOS)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: PDFnoDesign.Space.small)], alignment: .leading, spacing: PDFnoDesign.Space.small) {
                        Button { openNavigation() } label: { Label("导航与搜索", systemImage: "list.bullet") }
                            .accessibilityIdentifier("reader-navigation").keyboardShortcut("f", modifiers: .command).accessibilityValue(navigationVisible ? "已展开" : "已收起").help("显示或收起 PDF 目录与文本搜索")
                        Button { session.go(to: session.pageIndex - 1) } label: { Label("上一页", systemImage: "chevron.left") }
                            .disabled(session.pageIndex == 0).accessibilityIdentifier("previous-page").help("阅读上一页")
                        Button { session.go(to: session.pageIndex + 1) } label: { Label("下一页", systemImage: "chevron.right") }
                            .disabled(session.pageIndex >= book.pageCount - 1).accessibilityIdentifier("next-page").help("阅读下一页")
                        Button { openNotes() } label: { Label("高亮与笔记", systemImage: "highlighter") }
                            .accessibilityIdentifier("reader-notes").accessibilityValue(notesVisible ? "已展开" : "已收起").help("显示或收起高亮与笔记，保留草稿和选区")
                        JapaneseLearningEntry(identifier: "reader-japanese-learning") {
                            model.prepareJapaneseLearning(); japaneseLearning = true
                        }
                        Button("英语结构与语法") { model.prepareEnglishLearning(); englishLearning = true }
                            .accessibilityIdentifier("reader-english-learning").help("固定当前选文，确认后生成英语结构候选")
                        BYOKSelectionEntry(library: model, identifier: "reader-byok") { byokLearning = true }
                        Button("翻译当前页") { model.preparePageTranslation(); pageTranslation = true }
                            .accessibilityIdentifier("reader-page-translation").help("预览当前页翻译范围，确认后手动发送")
                        Button("选文 AI") { model.learning.prepare(model.captureAISource()); ai = true }
                            .accessibilityIdentifier("reader-ai").help("预览已捕获选文的 AI 任务")
                    }.buttonStyle(PDFnoActionStyle(role: .quiet))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, PDFnoDesign.Space.regular).padding(.vertical, PDFnoDesign.Space.tight)
                        .background(PDFnoDesign.Palette.chrome)
                    #endif
                    #if os(macOS)
                    PDFnoReaderShell(panels: panels) {
                        PDFCanvas(session: session).background(PDFnoDesign.Palette.canvas)
                    } navigation: {
                        PDFnoPanel(title: "导航与搜索", icon: "list.bullet", closeIdentifier: "close-navigation", close: { panels.navigation = false }) { navigationContent }
                    } notes: {
                        PDFnoPanel(title: "高亮与笔记", icon: "highlighter", closeIdentifier: "close-notes", close: { panels.notes = false }) { notesContent }
                    }
                    .background {
                        GeometryReader { geometry in
                            Color.clear.onAppear { readerWidth = geometry.size.width }
                                .onChange(of: geometry.size.width) { _, width in readerWidth = width }
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
        .sheet(isPresented: $ai) { AILearningWorkspace(library: model, learning: model.learning) }
        .sheet(isPresented: $pageTranslation) { PDFPageTranslationWorkspace(library: model, translation: model.pageTranslation, learning: model.learning) }
        .sheet(isPresented: $byokLearning) { BYOKLearningWorkspace(library: model, model: model.byok) }
        #endif
    }
    private var navigationVisible: Bool {
        #if os(macOS)
        panels.placement(width: readerWidth).showNavigation
        #else
        navigation
        #endif
    }
    private var notesVisible: Bool {
        #if os(macOS)
        panels.placement(width: readerWidth).showNotes
        #else
        notesPanel
        #endif
    }
    private func openNavigation() {
        #if os(macOS)
        panels.toggle(.navigation, width: readerWidth)
        #else
        navigation = true
        #endif
    }
    private func openNotes() {
        #if os(macOS)
        panels.toggle(.notes, width: readerWidth)
        #else
        notesPanel = true
        #endif
    }
    private func closeNavigation() { navigation = false; panels.navigation = false }
    private func closeNotes() { notesPanel = false; panels.notes = false }
    private var navigationSheet: some View {
        NavigationStack {
            navigationContent.navigationTitle("导航与搜索")
                .toolbar { ToolbarItem { Button("完成", action: closeNavigation).accessibilityIdentifier("close-navigation") } }
        }.frame(minWidth: 300, minHeight: 400)
    }
    private var navigationContent: some View {
        List {
            Section("查找文本") {
                TextField("输入关键词", text: $searchText).accessibilityIdentifier("search-input")
                    .onSubmit { session.search(searchText); searched = true }
                Button("查找") { session.search(searchText); searched = true }.accessibilityIdentifier("search-submit")
                if searched {
                    Text("找到 \(session.searchMatches.count) 项（最多显示 100 项）").font(.caption)
                        .accessibilityIdentifier("search-status")
                }
                ForEach(session.searchMatches, id: \.self) { match in
                    Button(match.string ?? "匹配结果") { session.show(match); closeNavigation() }
                        .accessibilityIdentifier("search-result")
                }
                if searched && session.searchMatches.isEmpty { PDFnoEmptyState(title: "没有匹配文本", detail: "扫描页可能没有可选文字。请更换关键词或检查文字层。", icon: "magnifyingglass") }
            }
            Section("目录") {
                if session.outline.isEmpty { PDFnoEmptyState(title: "此 PDF 没有内置目录", detail: "可以从下方页码或文本搜索定位。") }
                ForEach(session.outline) { item in Button(item.title) { session.go(to: item.pageIndex); closeNavigation() } }
            }
            Section("页面") {
                ForEach(0..<(session.document?.pageCount ?? 0), id: \.self) { index in
                    Button("第 \(index + 1) 页") { session.go(to: index); closeNavigation() }
                }
            }
        }.buttonStyle(.borderless).font(PDFnoDesign.TypeStyle.body)
    }
    private var notesSheet: some View {
        NavigationStack {
            notesContent.navigationTitle("高亮与笔记")
                .toolbar { ToolbarItem { Button("完成", action: closeNotes).accessibilityIdentifier("close-notes") } }
        }.frame(minWidth: 300, minHeight: 420)
    }
    private var notesContent: some View {
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
        }.font(PDFnoDesign.TypeStyle.body).accessibilityIdentifier("pdf-notes-list")
    }
}
