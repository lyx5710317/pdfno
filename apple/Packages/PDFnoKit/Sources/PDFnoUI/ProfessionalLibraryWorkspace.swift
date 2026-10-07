// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoServices

struct ProfessionalLibraryActionStyle: ButtonStyle {
    var primary = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10).frame(minHeight: 30)
            .foregroundStyle(primary ? Color.white : Color.primary)
            .background(primary ? Color.blue.opacity(configuration.isPressed ? 0.7 : 1) : Color.primary.opacity(configuration.isPressed ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }
}
private struct ProfessionalLibraryItem: Identifiable {
    let id: UUID
    let title: String
    let subtitle: String
    let accessibilityID: String
    let cover: LibraryCoverItem?
    let example: Bool
}
struct ProfessionalLibraryWorkspace: View {
    @ObservedObject var model: LibraryModel
    @Binding var grid: Bool
    @Binding var selectedBookID: UUID?
    let importFile: () -> Void
    let search: () -> Void
    let examples: () -> Void
    let editCover: (LibraryCoverItem) -> Void
    let openBook: (UUID) -> Void
    let resume: (() -> Void)?
    @State private var showingExamples = false
    @State private var query = ""
    private var items: [ProfessionalLibraryItem] {
        func item(_ cover: LibraryCoverItem) -> ProfessionalLibraryItem {
            let identity = BundledExampleIdentity(format: cover.identity.format.rawValue, bookID: cover.identity.bookID,
                editionID: cover.identity.editionID, fileSHA256: cover.identity.fileSHA256)
            return .init(id: cover.id, title: cover.title, subtitle: cover.subtitle, accessibilityID: cover.accessibilityID,
                cover: cover, example: model.isBundledExample(identity))
        }
        var result = model.books.map { item(.init(identity: CoverIdentity($0), title: $0.title, subtitle: "PDF · \($0.pageCount) 页", accessibilityID: "library-book")) }
        result += model.docx.books.map { item(.init(identity: CoverIdentity($0), title: $0.title, subtitle: "DOCX · 语义重排", accessibilityID: "library-docx")) }
        result += model.epubBooks.map { item(.init(identity: CoverIdentity($0), title: $0.title, subtitle: "EPUB · 重排阅读", accessibilityID: "library-epub")) }
        result += model.comicBooks.map { item(.init(identity: CoverIdentity($0), title: $0.title, subtitle: $0.archiveFormat?.rawValue.uppercased() ?? "漫画", accessibilityID: "library-comic")) }
        result += model.ebook.books.map { b in
            .init(id: b.id, title: b.title, subtitle: b.format.rawValue.uppercased() + " · 本地原件", accessibilityID: "library-ebook-" + b.format.rawValue, cover: nil,
                example: model.isBundledExample(.init(format: b.format.rawValue, bookID: b.id, editionID: b.editionID, fileSHA256: b.fileSHA256)))
        }
        result += model.textFormats.books.map { .init(id: $0.id, title: $0.title, subtitle: $0.format.label + " · 本地文本", accessibilityID: "library-textformat", cover: nil, example: false) }
        return result
    }
    private var filtered: [ProfessionalLibraryItem] {
        items.filter { $0.example == showingExamples && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query)) }
    }
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "books.vertical.fill").foregroundStyle(.blue)
                    Text("PDFno").font(.system(size: 15, weight: .semibold))
                    Text("本地书库").font(.system(size: 11)).foregroundStyle(.secondary)
                    Spacer()
                    if let resume { Button(action: resume) { Label("继续阅读", systemImage: "arrow.right") }.accessibilityIdentifier("workspace-resume-reader") }
                    Button(action: importFile) { Label("导入书籍 / 文本", systemImage: "plus") }
                        .buttonStyle(ProfessionalLibraryActionStyle(primary: true)).accessibilityIdentifier("import-pdf").disabled(!model.canImport || model.isBusy)
                }.buttonStyle(ProfessionalLibraryActionStyle()).padding(.horizontal, 20).frame(height: 56)
                Divider()
                HStack(spacing: 0) {
                    if geometry.size.width >= 900 { categories(vertical: true).frame(width: 184); Divider() }
                    VStack(alignment: .leading, spacing: 18) {
                        if geometry.size.width < 900 { categories(vertical: false) }
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(showingExamples ? "示例文档" : "我的书库").font(.system(size: 22, weight: .semibold))
                                Text("\(items.filter { $0.example == showingExamples }.count) 本 · " + (showingExamples ? "来自内置示例入口" : "保存在此设备"))
                                    .font(.system(size: 12)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let cover = items.first(where: { $0.id == selectedBookID })?.cover {
                                Button { editCover(cover) } label: { Label("编辑封面", systemImage: "photo") }.accessibilityIdentifier("library-edit-cover")
                            } else {
                                Button {} label: { Label("编辑封面", systemImage: "photo") }.disabled(true).accessibilityIdentifier("library-edit-cover")
                            }
                            layoutPicker
                        }
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("筛选书名与格式", text: $query).textFieldStyle(.plain).font(.system(size: 13)).accessibilityIdentifier("library-title-filter")
                            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("清除筛选") }
                            Divider().frame(height: 16)
                            Button(action: search) { Text("搜索笔记") }.accessibilityIdentifier("library-search-notes")
                        }.padding(.horizontal, 12).frame(height: 36)
                            .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08)))
                        if filtered.isEmpty { emptyState.frame(maxWidth: .infinity, maxHeight: .infinity) }
                        else {
                            ScrollView {
                                if grid {
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 154, maximum: 205), alignment: .top)], alignment: .leading, spacing: 16) {
                                        ForEach(filtered) { row($0) }
                                    }
                                } else { LazyVStack(spacing: 8) { ForEach(filtered) { row($0) } } }
                            }.accessibilityElement(children: .contain).accessibilityIdentifier("professional-library-books")
                        }
                        HStack {
                            Image(systemName: "externaldrive").foregroundStyle(.secondary)
                            Text(showingExamples ? "旧记录不按标题自动分类；原文件与笔记保留。" : "导入与阅读均在本地；AI 发送需要逐次确认。")
                                .font(.system(size: 11)).foregroundStyle(.secondary)
                            Spacer()
                            if showingExamples { Button(action: examples) { Label("打开内置示例", systemImage: "doc.badge.plus") }.accessibilityIdentifier("library-example-help") }
                        }
                    }.padding(geometry.size.width < 900 ? 18 : 28)
                }
            }.background(PDFnoDesign.Palette.canvas).accessibilityElement(children: .contain).accessibilityIdentifier("professional-library-workspace")
                .buttonStyle(ProfessionalLibraryActionStyle())
        }
    }
    @ViewBuilder private func categories(vertical: Bool) -> some View {
        let personal = items.filter { !$0.example }.count, examples = items.filter(\.example).count
        if vertical {
            VStack(alignment: .leading, spacing: 10) {
                Text("书籍").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary).padding(.horizontal, 10).padding(.bottom, 4)
                category("我的书库", icon: "books.vertical", count: personal, active: !showingExamples) { showingExamples = false }.accessibilityIdentifier("library-category-personal")
                category("示例文档", icon: "doc.text", count: examples, active: showingExamples) { showingExamples = true }.accessibilityIdentifier("library-category-examples")
                Spacer()
                Text("原件保留\n示例与个人书籍分开").font(.system(size: 11)).foregroundStyle(.secondary).lineSpacing(5).padding(10)
            }.padding(14).background(PDFnoDesign.Palette.chrome)
        } else {
            HStack(spacing: 8) {
                category("我的书库", icon: "books.vertical", count: personal, active: !showingExamples) { showingExamples = false }.accessibilityIdentifier("library-category-personal")
                category("示例文档", icon: "doc.text", count: examples, active: showingExamples) { showingExamples = true }.accessibilityIdentifier("library-category-examples")
                Spacer(minLength: 0)
            }
        }
    }
    private func category(_ title: String, icon: String, count: Int, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) { Image(systemName: icon).frame(width: 16); Text(title); Spacer(minLength: 8); Text("\(count)").font(.system(size: 11)).monospacedDigit() }
                .font(.system(size: 12, weight: active ? .semibold : .regular)).padding(10)
                .foregroundStyle(active ? Color.blue : Color.secondary)
                .background(active ? Color.blue.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).accessibilityValue(active ? "已选中" : "未选中")
    }
    private var layoutPicker: some View {
        HStack(spacing: 2) {
            Button { grid = false } label: { Image(systemName: "list.bullet").frame(width: 30, height: 28).background(!grid ? Color.blue.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6)) }.accessibilityIdentifier("library-list-layout").accessibilityLabel("列表").accessibilityValue(!grid ? "已选中" : "未选中")
            Button { grid = true } label: { Image(systemName: "square.grid.2x2").frame(width: 30, height: 28).background(grid ? Color.blue.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6)) }.accessibilityIdentifier("library-grid-layout").accessibilityLabel("网格").accessibilityValue(grid ? "已选中" : "未选中")
        }.buttonStyle(.plain).padding(3).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
    private func row(_ item: ProfessionalLibraryItem) -> some View {
        Button { openBook(item.id) } label: {
            Group {
                if let cover = item.cover {
                    LibraryCoverRow(covers: model.covers, item: cover, grid: grid) { editCover(cover) }
                } else {
                    HStack(spacing: 14) {
                        Image(systemName: "book.closed").font(.system(size: grid ? 32 : 22)).foregroundStyle(.blue).frame(width: grid ? 60 : 44, height: grid ? 90 : 50)
                        VStack(alignment: .leading, spacing: 5) { Text(item.title).font(.system(size: 13, weight: .semibold)).lineLimit(2); Text(item.subtitle).font(.system(size: 11)).foregroundStyle(.secondary) }
                        if !grid { Spacer() }
                    }.accessibilityElement(children: .contain).accessibilityIdentifier(item.accessibilityID)
                }
            }.frame(maxWidth: .infinity, alignment: grid ? .center : .leading).padding(grid ? 14 : 12)
                .background(PDFnoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(selectedBookID == item.id ? Color.blue.opacity(0.35) : Color.primary.opacity(0.08)))
        }.buttonStyle(.plain)
    }
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: showingExamples ? "doc.text" : "books.vertical").font(.system(size: 34, weight: .light)).foregroundStyle(.blue.opacity(0.65))
            Text(query.isEmpty ? (showingExamples ? "试读内置示例" : "导入书籍，开始阅读") : "没有匹配的书籍").font(.system(size: 16, weight: .semibold))
            Text(query.isEmpty ? (showingExamples ? "从帮助与示例打开文档，新增示例会出现在这里。" : "选择 PDF、EPUB、Word、漫画或本地文本。") : "换一个书名或格式关键词。")
                .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if query.isEmpty { Button(action: showingExamples ? examples : importFile) { Label(showingExamples ? "帮助与示例" : "导入书籍 / 文本", systemImage: showingExamples ? "questionmark.circle" : "plus") }.buttonStyle(ProfessionalLibraryActionStyle(primary: true)) }
        }.padding(24).accessibilityIdentifier("library-empty-state")
    }
}
#endif
