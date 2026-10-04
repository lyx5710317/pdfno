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
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var selectedBookID: UUID?
    @State private var grid = false
    @State private var coverEditor: LibraryCoverItem?
    public init() {}
    public var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            VStack(spacing: 0) {
                #if os(macOS)
                HStack {
                    Button { grid = false } label: { Label("列表", systemImage: "list.bullet") }
                        .accessibilityIdentifier("library-list-layout")
                    Button { grid = true } label: { Label("网格", systemImage: "square.grid.2x2") }
                        .accessibilityIdentifier("library-grid-layout")
                }.buttonStyle(.borderless).padding(8)
                #endif
                Group {
                    if grid {
                        ScrollView {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), alignment: .top)], spacing: 16) {
                                ForEach(coverItems) { item in
                                    LibraryCoverRow(covers: model.covers, item: item, grid: true) { coverEditor = item }
                                        .contentShape(Rectangle())
                                        .onTapGesture { selectedBookID = item.id }
                                        .accessibilityAction { selectedBookID = item.id }
                                        .focusable()
                                        .onKeyPress(.return) { selectedBookID = item.id; return .handled }
                                        .onKeyPress(.space) { selectedBookID = item.id; return .handled }
                                        .padding(4)
                                        .background(selectedBookID == item.id ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
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
                                        .padding(4)
                                        .background(selectedBookID == book.id ? Color.accentColor.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                                }
                                #endif
                            }.padding(12)
                        }
                    } else {
                        List(selection: $selectedBookID) {
                            Section("我的书库") {
                                if libraryIsEmpty { Text("导入书籍，开始阅读").foregroundStyle(.secondary) }
                                ForEach(coverItems) { item in
                                    LibraryCoverRow(covers: model.covers, item: item, grid: false) { coverEditor = item }.tag(item.id)
                                }
                                #if os(macOS)
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
                VStack(spacing: 10) {
                    Button { importer = true } label: { Label(importTitle, systemImage: "plus") }
                        .buttonStyle(.borderedProminent).disabled(!model.canImport || model.isBusy)
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
                    Text("仅在设备本地处理").font(.caption).foregroundStyle(.secondary)
                }.padding()
            }.navigationTitle("PDFno")
            .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 360)
        } detail: {
            #if os(macOS)
            if model.textFormats.isActive { TextFormatWorkspace(model: model.textFormats) }
            else if model.docx.isActive { DOCXWorkspace(model: model.docx) }
            else if model.readingComic { ComicWorkspace(session: model.comic, close: { model.closeComic() }) }
            else if model.readingEPUB { EPUBWorkspace(model: model, session: model.epub) }
            else { ReaderWorkspace(model: model, session: model.reader) }
            #else
            ReaderWorkspace(model: model, session: model.reader)
            #endif
        }
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
            ToolbarItem { Button { librarySearch = true } label: { Label("书库与笔记搜索", systemImage: "magnifyingglass") }.accessibilityIdentifier("library-search") }
            ToolbarItem { Button { conversion = true } label: { Label("格式转换", systemImage: "arrow.triangle.2.circlepath") }.accessibilityIdentifier("document-conversion") }
            ToolbarItem { Button { aiSettings = true } label: { Label("模型与 BYOK 设置", systemImage: "slider.horizontal.3") }.accessibilityIdentifier("ai-settings") }
            #endif
        }
        .sheet(isPresented: $about) { FeatureStatusView() }
        #if os(macOS)
        .sheet(item: $coverEditor) { item in LibraryCoverEditor(covers: model.covers, item: item) }
        .sheet(isPresented: $librarySearch) { LibrarySearchWorkspace(library: model) }
        .sheet(isPresented: $booknoPreview) { BooknoPreviewWorkspace(model: model.booknoPreview) }
        .sheet(isPresented: $conversion) { ConversionWorkspace() }
        .sheet(isPresented: $aiSettings) { AISettingsView(learning: model.learning) }
        #endif
        .alert("操作未完成", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .overlay { if model.isBusy { ProgressView("正在打开…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
    }
    private var libraryIsEmpty: Bool {
        #if os(macOS)
        coverItems.isEmpty && model.textFormats.books.isEmpty
        #else
        coverItems.isEmpty
        #endif
    }
    private var coverItems: [LibraryCoverItem] {
        var items = model.books.map { LibraryCoverItem(identity: CoverIdentity($0), title: $0.title, subtitle: "PDF · \($0.pageCount) 页 · 本地", accessibilityID: "library-book") }
        #if os(macOS)
        items += model.docx.books.map { LibraryCoverItem(identity: CoverIdentity($0), title: $0.title, subtitle: "DOCX · 本地", accessibilityID: "library-docx") }
        items += model.comicBooks.map { LibraryCoverItem(identity: CoverIdentity($0), title: $0.title, subtitle: "CBZ · \($0.pages.count) 页 · 本地", accessibilityID: "library-comic") }
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
        if model.textFormats.isActive { return model.textFormats.reader.book?.id }
        if model.docx.isActive { return model.docx.reader.book?.id }
        if model.readingComic { return model.comic.book?.id }
        if model.readingEPUB { return model.epub.book?.id }
        #endif
        return model.reader.book?.id
    }
    private var importTypes: [UTType] {
        #if os(macOS)
        [.pdf, .plainText, .html, UTType(filenameExtension: "htm") ?? .html, UTType(filenameExtension: "md") ?? .plainText, UTType(filenameExtension: "markdown") ?? .plainText, UTType(filenameExtension: "epub") ?? .data, UTType(filenameExtension: "docx") ?? .data, UTType(filenameExtension: "cbz", conformingTo: .zip) ?? .zip]
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
                    Text("TXT／Markdown／HTML：Mac 本地阅读、标题导航、选文笔记与进度；严格 UTF-8 或带 BOM 的 UTF-16，链接仅显示文字")
                    Text("DOCX：Mac 语义重排阅读、标题目录与选文笔记；与 Word 原版式不同；DOC 未支持")
                    Label("CBZ 漫画：导入、页序、左右方向、单双页与进度恢复", systemImage: "checkmark.circle")
                    Label("DOCX 正文转 TXT / 简化 HTML（有损副本）", systemImage: "checkmark.circle")
                    #endif
                }
                Section("后续接入") {
                    Text("EPUB：Mac 本地重排阅读；移动适配与固定版式待验收")
                    Text("Mac AI：选文翻译／解释、受限 PDF 当前页与 EPUB 当前完整文档双语对照；范围预览、手动确认发送和学习笔记。当前 EPUB 文档不等于目录逻辑章节；真实质量与完整日英学习待验收")
                    Text("Bookno API：尚未接入")
                    Text("iCloud：未配置容器，数据仅保存在本地")
                    Text("CBZ：移动阅读适配待验收；当前 Mac 支持静态 PNG / JPEG")
                    Text("CBR / 其他格式阅读 / PDF、Word、EPUB 高保真互转 / OCR / Apple Pencil：尚未实现")
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
    @State private var searchText = ""
    @State private var searched = false
    @State private var draft = ""
    @State private var ai = false
    @State private var pageTranslation = false
    var body: some View {
        Group {
            if let book = session.book {
                VStack(spacing: 0) {
                    PDFCanvas(session: session).background(.secondary.opacity(0.1))
                    HStack {
                        Text("第 \(session.pageIndex + 1) / \(book.pageCount) 页").monospacedDigit()
                            .accessibilityIdentifier("page-position")
                        Spacer()
                        Text(model.status).lineLimit(1)
                    }.font(.caption).foregroundStyle(.secondary).padding(10)
                }.navigationTitle(book.title)
                .toolbar {
                    ToolbarItemGroup {
                        Button { navigation = true } label: { Label("导航与搜索", systemImage: "list.bullet") }
                            .accessibilityIdentifier("reader-navigation")
                        Button { session.go(to: session.pageIndex - 1) } label: { Label("上一页", systemImage: "chevron.left") }
                            .disabled(session.pageIndex == 0).accessibilityIdentifier("previous-page")
                        Button { session.go(to: session.pageIndex + 1) } label: { Label("下一页", systemImage: "chevron.right") }
                            .disabled(session.pageIndex >= book.pageCount - 1).accessibilityIdentifier("next-page")
                        Button { notesPanel = true } label: { Label("高亮与笔记", systemImage: "highlighter") }
                            .accessibilityIdentifier("reader-notes")
                        #if os(macOS)
                        Button("翻译当前页") { model.preparePageTranslation(); pageTranslation = true }.accessibilityIdentifier("reader-page-translation")
                        Button("选文 AI") { model.learning.prepare(model.captureAISource()); ai = true }.accessibilityIdentifier("reader-ai")
                        #endif
                    }
                }
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
        .sheet(isPresented: $navigation) { navigationSheet }
        .sheet(isPresented: $notesPanel) { notesSheet }
        #if os(macOS)
        .sheet(isPresented: $ai) { AILearningWorkspace(library: model, learning: model.learning) }
        .sheet(isPresented: $pageTranslation) { PDFPageTranslationWorkspace(library: model, translation: model.pageTranslation, learning: model.learning) }
        #endif
    }
    private var navigationSheet: some View {
        NavigationStack {
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
                        Button(match.string ?? "匹配结果") { session.show(match); navigation = false }
                            .accessibilityIdentifier("search-result")
                    }
                    if searched && session.searchMatches.isEmpty { Text("没有匹配文本。扫描页可能没有可选文字。").font(.caption) }
                }
                Section("目录") {
                    if session.outline.isEmpty { Text("此 PDF 没有内置目录") }
                    ForEach(session.outline) { item in Button(item.title) { session.go(to: item.pageIndex); navigation = false } }
                }
                Section("页面") {
                    ForEach(0..<(session.document?.pageCount ?? 0), id: \.self) { index in
                        Button("第 \(index + 1) 页") { session.go(to: index); navigation = false }
                    }
                }
            }.buttonStyle(.borderless).navigationTitle("导航与搜索").toolbar { ToolbarItem { Button("完成") { navigation = false }.accessibilityIdentifier("close-navigation") } }
        }.frame(minWidth: 300, minHeight: 400)
    }
    private var notesSheet: some View {
        NavigationStack {
            List {
                Section("当前选区") {
                    if let anchor = session.capturedSelection {
                        Text(anchor.quote).textSelection(.enabled)
                        TextField("写下你的笔记（可选）", text: $draft, axis: .vertical).lineLimit(3...8)
                            .accessibilityIdentifier("note-input")
                        Button("保存高亮与笔记") {
                            Task { if await model.saveNote(anchor: anchor, text: draft) { draft = "" } }
                        }.accessibilityIdentifier("save-note")
                    } else { Text("在 PDF 中选中文字，再打开这里。扫描页或受限文件可能不可选择。") }
                }
                Section("已保存 · 本地") {
                    let notes = model.notes.filter { $0.bookID == session.book?.id }
                    if notes.isEmpty { Text("这本书还没有笔记") }
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
                                if session.navigate(to: note.anchor) == .exact { notesPanel = false }
                                else { model.error = "来源无法精确恢复，旧引文已保留；请重新选择原文。" }
                            }.accessibilityIdentifier("return-to-source")
                        }.padding(.vertical, 4)
                    }
                }
            }.accessibilityIdentifier("pdf-notes-list").navigationTitle("高亮与笔记").toolbar { ToolbarItem { Button("完成") { notesPanel = false }.accessibilityIdentifier("close-notes") } }
        }.frame(minWidth: 300, minHeight: 420)
    }
}
