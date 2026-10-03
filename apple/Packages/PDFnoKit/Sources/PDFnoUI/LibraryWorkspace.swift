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
    @State private var compactColumn: NavigationSplitViewColumn = .sidebar
    @State private var selectedBookID: UUID?
    public init() {}
    public var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            VStack(spacing: 0) {
                List(selection: $selectedBookID) {
                    Section("我的书库") {
                        if model.books.isEmpty {
                            Text("导入 PDF，开始阅读").foregroundStyle(.secondary)
                        }
                        ForEach(model.books) { book in
                                HStack(spacing: 12) {
                                    Image(systemName: "book.closed.fill").font(.title2).foregroundStyle(.tint)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(book.title).font(.headline).lineLimit(2)
                                        Text("PDF · \(book.pageCount) 页 · 本地").font(.caption).foregroundStyle(.secondary)
                                    }
                                }.padding(.vertical, 6).frame(maxWidth: .infinity, alignment: .leading)
                                    .tag(book.id).accessibilityIdentifier("library-book")
                        }
                        #if os(macOS)
                        ForEach(model.epubBooks) { book in
                            Label(book.title + " · EPUB", systemImage: "book.closed")
                                .tag(book.id).accessibilityIdentifier("library-epub")
                        }
                        #endif
                    }
                }
                .onChange(of: selectedBookID) { _, id in
                    if let book = model.books.first(where: { $0.id == id }) {
                        Task { await model.open(book); if model.reader.book?.id == book.id { compactColumn = .detail } }
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
                    Button("打开示例 EPUB") { Task { await model.openEPUBSample(); compactColumn = .detail } }
                        .disabled(!model.canImport || model.isBusy).accessibilityIdentifier("open-epub-sample")
                    #endif
                    Text("仅在设备本地处理").font(.caption).foregroundStyle(.secondary)
                }.padding()
            }.navigationTitle("PDFno")
            .navigationSplitViewColumnWidth(min: 220, ideal: 270, max: 360)
        } detail: {
            #if os(macOS)
            if model.readingEPUB { EPUBWorkspace(model: model, session: model.epub) }
            else { ReaderWorkspace(model: model, session: model.reader) }
            #else
            ReaderWorkspace(model: model, session: model.reader)
            #endif
        }
        .task { await model.load() }
        .fileImporter(isPresented: $importer, allowedContentTypes: importTypes) { result in
            switch result {
            case .success(let url): Task { await model.importFile(url); if model.reader.book != nil { compactColumn = .detail } }
            case .failure(let error): model.error = error.localizedDescription
            }
        }
        .toolbar {
            ToolbarItem { Button { about = true } label: { Label("功能状态", systemImage: "info.circle") } }
            #if os(macOS)
            ToolbarItem { Button { aiSettings = true } label: { Label("模型与 BYOK 设置", systemImage: "slider.horizontal.3") }.accessibilityIdentifier("ai-settings") }
            #endif
        }
        .sheet(isPresented: $about) { FeatureStatusView() }
        #if os(macOS)
        .sheet(isPresented: $aiSettings) { AISettingsView(learning: model.learning) }
        #endif
        .alert("操作未完成", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .overlay { if model.isBusy { ProgressView("正在打开…").padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14)) } }
    }
    private var importTitle: String {
        #if os(macOS)
        "导入 PDF / EPUB"
        #else
        "导入 PDF"
        #endif
    }
    private var importTypes: [UTType] {
        #if os(macOS)
        [.pdf, UTType(filenameExtension: "epub") ?? .data]
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
                }
                Section("后续接入") {
                    Text("EPUB：Mac 本地重排阅读；移动适配与固定版式待验收")
                    Text("Mac 选文 AI：本地 mock 或用户操作的 DeepSeek 翻译／解释；500字范围、来源与学习笔记；质量、页章双语与完整日英学习待验收")
                    Text("Bookno API：尚未接入")
                    Text("iCloud：未配置容器，数据仅保存在本地")
                    Text("漫画 / 其他格式 / 转换 / OCR / Apple Pencil：尚未实现")
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
                        Button("选文 AI") { model.learning.prepare(model.captureAISource()); ai = true }.accessibilityIdentifier("reader-ai")
                        #endif
                    }
                }
                .onChange(of: session.pageIndex) { _, _ in Task { await model.saveProgress() } }
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
                            if !note.userText.isEmpty { Text(note.userText).foregroundStyle(.secondary) }
                            Button("回到原文 · 第 \((note.anchor.regions.first?.pageIndex ?? 0) + 1) 页") {
                                if session.navigate(to: note.anchor) == .exact { notesPanel = false }
                                else { model.error = "来源无法精确恢复，旧引文已保留；请重新选择原文。" }
                            }.accessibilityIdentifier("return-to-source")
                        }.padding(.vertical, 4)
                    }
                }
            }.navigationTitle("高亮与笔记").toolbar { ToolbarItem { Button("完成") { notesPanel = false }.accessibilityIdentifier("close-notes") } }
        }.frame(minWidth: 300, minHeight: 420)
    }
}
