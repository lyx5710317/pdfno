// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import AppKit
import PDFnoDomain
import PDFnoServices

enum PDFnoWorkspaceStyle {
    static let background = Color(nsColor: NSColor(name: "PDFnoWorkspaceBackground") { appearance in
        appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor(srgbRed: 0.10, green: 0.11, blue: 0.13, alpha: 1)
            : NSColor(srgbRed: 0.96, green: 0.97, blue: 0.98, alpha: 1)
    })
}

struct ProfessionalLibraryActionStyle: ButtonStyle {
    var primary = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10).frame(minHeight: 30)
            .foregroundStyle(primary ? Color.white : Color.primary)
            .background(primary ? Color.blue.opacity(configuration.isPressed ? 0.7 : 1) : Color.primary.opacity(configuration.isPressed ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8)).opacity(enabled ? 1 : 0.4)
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
    @State private var format = "全部格式"
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
        items.filter { $0.example == showingExamples && (format == "全部格式" || $0.subtitle.components(separatedBy: " · ").first == format) && (query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.subtitle.localizedCaseInsensitiveContains(query)) }
    }
    private var formats: [String] { ["全部格式"] + Array(Set(items.map { $0.subtitle.components(separatedBy: " · ")[0] })).sorted() }
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.height < 600
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    categories
                    Spacer(minLength: 8)
                    if let resume { Button(action: resume) { Label("继续阅读", systemImage: "arrow.right") }.accessibilityIdentifier("workspace-resume-reader") }
                    Button(action: importFile) { Label("导入书籍 / 文本", systemImage: "plus") }
                        .buttonStyle(ProfessionalLibraryActionStyle(primary: true)).accessibilityIdentifier("import-pdf").disabled(!model.canImport || model.isBusy)
                }.buttonStyle(ProfessionalLibraryActionStyle()).padding(.horizontal, 24).frame(height: compact ? 52 : 64)
                Divider()
                VStack(alignment: .leading, spacing: compact ? 12 : 18) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(showingExamples ? "示例文档" : "我的书库").font(.system(size: compact ? 20 : 24, weight: .semibold))
                            Text("\(items.filter { $0.example == showingExamples }.count) 本 · " + (showingExamples ? "内置原创文档" : "保存在此设备"))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let cover = items.first(where: { $0.id == selectedBookID })?.cover {
                            Button { editCover(cover) } label: { Label("编辑封面", systemImage: "photo") }.accessibilityIdentifier("library-edit-cover")
                        } else {
                            Button {} label: { Label("编辑封面", systemImage: "photo") }.disabled(true).accessibilityIdentifier("library-edit-cover")
                        }
                    }
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                            TextField("筛选书名与格式", text: $query).textFieldStyle(.plain).accessibilityIdentifier("library-title-filter")
                            if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("清除筛选") }
                        }.padding(.horizontal, 12).frame(height: 36)
                            .background(PDFnoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.08)))
                        Picker("格式", selection: $format) { ForEach(formats, id: \.self) { Text($0).tag($0) } }
                            .labelsHidden().frame(width: 108).accessibilityIdentifier("library-format-filter")
                        layoutPicker
                        Button(action: search) { Label("搜索笔记", systemImage: "text.magnifyingglass") }.accessibilityIdentifier("library-search-notes")
                    }.font(.system(size: 13))
                    if filtered.isEmpty { emptyState.frame(maxWidth: .infinity, maxHeight: .infinity) }
                    else {
                        ScrollView {
                            if grid {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 20, alignment: .top)], alignment: .leading, spacing: 20) {
                                    ForEach(filtered) { row($0, compact: compact) }
                                }.padding(1)
                            } else { LazyVStack(spacing: 8) { ForEach(filtered) { row($0, compact: compact) } }.padding(1) }
                        }.accessibilityElement(children: .contain).accessibilityIdentifier("professional-library-books")
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "externaldrive")
                        Text("原件与已保存笔记保存在本地").font(.system(size: 11))
                        Spacer()
                        if showingExamples { Button(action: examples) { Label("打开内置示例", systemImage: "doc.badge.plus") }.accessibilityIdentifier("library-example-help") }
                    }.foregroundStyle(.secondary)
                }.padding(compact ? 16 : (geometry.size.width < 900 ? 20 : 28))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(PDFnoWorkspaceStyle.background)
            }.background(PDFnoDesign.Palette.canvas).accessibilityElement(children: .contain).accessibilityIdentifier("professional-library-workspace")
                .buttonStyle(ProfessionalLibraryActionStyle())
        }
    }
    private var categories: some View {
        HStack(spacing: 8) {
            category("我的书库", icon: "books.vertical", count: items.filter { !$0.example }.count, active: !showingExamples) { showingExamples = false }.accessibilityIdentifier("library-category-personal")
            category("示例文档", icon: "doc.text", count: items.filter(\.example).count, active: showingExamples) { showingExamples = true }.accessibilityIdentifier("library-category-examples")
        }.fixedSize(horizontal: true, vertical: false)
    }
    private func category(_ title: String, icon: String, count: Int, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 9) { Image(systemName: icon).frame(width: 16); Text(title); Text("\(count)").font(.system(size: 11)).monospacedDigit() }
                .font(.system(size: 12, weight: active ? .semibold : .regular)).padding(10)
                .foregroundStyle(active ? Color.blue : Color.secondary)
                .background(active ? Color.blue.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 8))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityLabel(title).accessibilityAddTraits(.isButton)
            .accessibilityAction { action() }
            .accessibilityValue(active ? "已选中" : "未选中").accessibilityHint("\(count) 本书籍")
    }
    private var layoutPicker: some View {
        HStack(spacing: 2) {
            Button { grid = false } label: { Image(systemName: "list.bullet").frame(width: 30, height: 28).background(!grid ? Color.blue.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6)) }.accessibilityIdentifier("library-list-layout").accessibilityLabel("列表").accessibilityValue(!grid ? "已选中" : "未选中")
            Button { grid = true } label: { Image(systemName: "square.grid.2x2").frame(width: 30, height: 28).background(grid ? Color.blue.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6)) }.accessibilityIdentifier("library-grid-layout").accessibilityLabel("网格").accessibilityValue(grid ? "已选中" : "未选中")
        }.buttonStyle(.plain).padding(3).background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }
    private func row(_ item: ProfessionalLibraryItem, compact: Bool) -> some View {
        Group {
            if grid {
                VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.025))
                        if let cover = item.cover {
                            LibraryCoverImage(covers: model.covers, identity: cover.identity, width: compact ? 88 : 126, height: compact ? 126 : 180)
                                .shadow(color: .black.opacity(0.10), radius: 6, y: 3)
                        } else { placeholder(item, width: compact ? 88 : 126, height: compact ? 126 : 180) }
                    }.frame(height: compact ? 140 : 202)
                    Text(item.title).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                        .frame(height: compact ? 32 : 36, alignment: .topLeading).frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 4) {
                        Text(item.subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                        Spacer(minLength: 0)
                        if let cover = item.cover {
                            Menu { Button("编辑封面") { editCover(cover) } } label: { Image(systemName: "ellipsis") }
                                .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("书籍操作：" + item.title)
                        }
                    }.frame(height: 20)
                }
            } else {
                HStack(spacing: 14) {
                    if let cover = item.cover { LibraryCoverImage(covers: model.covers, identity: cover.identity, width: 40, height: 56) }
                    else { placeholder(item, width: 40, height: 56) }
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title).font(.system(size: 13, weight: .semibold)).lineLimit(2)
                        Text(item.subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(compact ? 10 : 12)
            .background(PDFnoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selectedBookID == item.id ? Color.blue.opacity(0.45) : Color.primary.opacity(0.07)))
            .accessibilityElement(children: .contain).accessibilityIdentifier(item.accessibilityID)
            .contextMenu { if let cover = item.cover { Button("编辑封面") { editCover(cover) } } }
            .contentShape(Rectangle()).onTapGesture { openBook(item.id) }
            .accessibilityAction { openBook(item.id) }.focusable()
            .onKeyPress(.return) { openBook(item.id); return .handled }
            .onKeyPress(.space) { openBook(item.id); return .handled }
    }
    private func placeholder(_ item: ProfessionalLibraryItem, width: CGFloat, height: CGFloat) -> some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.text").font(.system(size: width > 60 ? 28 : 16, weight: .light))
            Text(item.subtitle.components(separatedBy: " · ")[0]).font(.system(size: width > 60 ? 12 : 8, weight: .medium))
        }.foregroundStyle(.secondary).frame(width: width, height: height)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            .accessibilityLabel("默认封面")
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
