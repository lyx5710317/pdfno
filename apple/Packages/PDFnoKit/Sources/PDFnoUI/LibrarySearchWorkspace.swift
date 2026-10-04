// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

struct LibrarySearchWorkspace: View {
    let library: LibraryModel
    @State private var search: SavedRecordSearchModel?
    var body: some View {
        Group {
            if let search { LibrarySearchContent(library: library, model: search) }
            else { ProgressView("正在加载本地书库…").frame(minWidth: 520, minHeight: 480) }
        }.task {
            guard search == nil else { return }
            let root = await library.repository.root
            search = SavedRecordSearchModel(root: root)
        }
    }
}

private struct LibrarySearchContent: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: LibraryModel
    @ObservedObject var model: SavedRecordSearchModel
    @State private var query = ""
    @State private var metadata = false
    @State private var opening = false
    @State private var sourceError: String?
    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("书名、作者、笔记或引文", text: $query)
                    .textFieldStyle(.roundedBorder).accessibilityIdentifier("library-search-input")
                    .onChange(of: query) { _, value in sourceError = nil; model.updateQuery(value) }
                Text("搜索PDF／EPUB／DOCX／四种漫画书目，以及已保存的PDF／EPUB／文本／电子书／AI与日语笔记；文本和电子书仅书名。共享300项显示上限；不搜索全书正文、扫描图片或未保存草稿。")
                    .font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    Text(status).font(.caption).accessibilityIdentifier("library-search-status")
                    Spacer()
                    if model.phase == .searching {
                        ProgressView().controlSize(.small)
                        Button("取消") { model.cancel() }.accessibilityIdentifier("library-search-cancel")
                    }
                    Button("刷新") { sourceError = nil; model.refresh() }.accessibilityIdentifier("library-search-refresh")
                    Button("清空") { query = ""; model.updateQuery("") }.accessibilityIdentifier("library-search-clear")
                }
                if let error = sourceError ?? model.error {
                    Text(error).foregroundStyle(.red).textSelection(.enabled).accessibilityIdentifier("library-search-error")
                }
                List {
                    ForEach(model.response.legacy.groups) { group in
                        Section {
                            ForEach(group.hits) { hit in
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(kindLabel(hit.entry.target.kind) + (hit.entry.location.isEmpty ? "" : " · " + hit.entry.location))
                                        .font(.caption).foregroundStyle(.secondary)
                                    Text(hit.preview).lineLimit(4).textSelection(.enabled).accessibilityIdentifier("library-search-preview")
                                    if hit.entry.target.kind == .learning { Text("已保存 AI 结果 · 本地").font(.caption).foregroundStyle(.secondary) }
                                    Button(hit.entry.target.kind == .book ? "打开书籍" : "回到来源") {
                                        opening = true
                                        Task {
                                            let opened = await library.openSearchTarget(hit.entry.target)
                                            opening = false
                                            if opened { dismiss() } else { sourceError = LibrarySearchFailure.source.localizedDescription }
                                        }
                                    }.disabled(opening || library.isBusy || !hit.entry.book.sourceAvailable)
                                        .accessibilityIdentifier(hit.entry.target.kind == .book ? "library-search-open-book" : "library-search-source")
                                    if !hit.entry.book.sourceAvailable { Text("来源书籍不在书库；引文仍可查看。").font(.caption) }
                                }.padding(.vertical, 4)
                            }
                        } header: {
                            Text(group.book.title + " · " + group.book.identity.format.rawValue + (group.book.author.isEmpty ? "" : " · " + group.book.author))
                                .accessibilityIdentifier("library-search-group")
                        }
                    }
                    RecordSearchResults(response: model.response.records, error: nil) { target in
                        guard !opening, !library.isBusy else { return false }
                        opening = true
                        let opened = await library.openRecordSearchTarget(target)
                        opening = false
                        if opened { dismiss() }
                        return opened
                    }
                }.overlay {
                    if model.phase == .idle { Text("输入关键词搜索书库与笔记").foregroundStyle(.secondary).accessibilityIdentifier("library-search-empty") }
                    else if model.phase == .results && model.response.totalCount == 0 { Text("没有匹配结果").foregroundStyle(.secondary).accessibilityIdentifier("library-search-no-results") }
                }
            }.padding().navigationTitle("书库与笔记搜索")
                .toolbar {
                    ToolbarItem { Button("书目信息") { metadata = true }.disabled(opening || model.response.legacy.books.isEmpty).accessibilityIdentifier("library-search-metadata") }
                    ToolbarItem { Button("完成") { dismiss() }.disabled(opening).accessibilityIdentifier("library-search-close") }
                }
        }.frame(minWidth: 520, idealWidth: 640, minHeight: 480)
            .task { model.observeChanges(in: library); model.updateQuery("") }
            .onDisappear { model.stopObservingChanges(); model.cancel() }
            .sheet(isPresented: $metadata) { LocalBookMetadataWorkspace(model: model) }
    }
    private var status: String {
        switch model.phase {
        case .idle: "输入关键词；空查询不列出全部笔记"
        case .searching: "正在搜索…"
        case .cancelled: "搜索已取消，点击刷新重试"
        case .failed: "搜索未完成"
        case .results: "找到 \(model.response.totalCount) 项" + (model.response.totalCount > 300 ? "（显示前 300 项）" : "")
        }
    }
    private func kindLabel(_ kind: LibrarySearchKind) -> String {
        switch kind { case .book: "书目信息"; case .note: "用户笔记／引文"; case .learning: "AI 学习笔记" }
    }
}

private struct LocalBookMetadataWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: SavedRecordSearchModel
    @State private var selectedID: String?
    @State private var draftBook: LibrarySearchBook?
    @State private var title = ""
    @State private var author = ""
    @State private var saving = false
    @State private var saved = false
    var body: some View {
        NavigationStack {
            Form {
                Picker("书籍", selection: $selectedID) {
                    Text("选择一本书").tag(String?.none)
                    ForEach(model.response.legacy.books) { book in Text(book.title + " · " + book.identity.format.rawValue).tag(Optional(book.id)) }
                }.accessibilityIdentifier("library-metadata-book")
                    .onChange(of: selectedID) { _, id in select(id) }
                TextField("书名", text: $title).accessibilityIdentifier("library-metadata-title")
                TextField("作者（可选）", text: $author).accessibilityIdentifier("library-metadata-author")
                Text("本地书目信息用于搜索；不会改写原文件或已保存引文。作者留空表示未知。")
                    .font(.caption).foregroundStyle(.secondary)
                if let error = model.error { Text(error).foregroundStyle(.red) }
                if saved { Text("书目信息已保存").accessibilityIdentifier("library-metadata-saved") }
                Button("保存书目信息") {
                    guard let book = draftBook else { return }; saving = true; saved = false
                    Task { saved = await model.saveMetadata(book, title: title, author: author); saving = false; if saved { select(book.id) } }
                }.disabled(saving || draftBook == nil || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("library-metadata-save")
            }.padding().disabled(saving).navigationTitle("本地书目信息")
                .toolbar { ToolbarItem { Button("完成") { dismiss() }.disabled(saving).accessibilityIdentifier("library-metadata-close") } }
        }.frame(minWidth: 480, minHeight: 300)
            .task { if selectedID == nil { selectedID = model.response.legacy.books.first?.id; select(selectedID) } }
    }
    private func select(_ id: String?) {
        draftBook = model.response.legacy.books.first { $0.id == id }
        title = draftBook?.title ?? ""; author = draftBook?.author ?? ""
    }
}
#endif
