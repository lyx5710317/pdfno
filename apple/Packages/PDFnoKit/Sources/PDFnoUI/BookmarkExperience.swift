// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFKit
import PDFnoDomain
import PDFnoServices

@MainActor final class BookmarkModel: ObservableObject {
    @Published private(set) var records: [ReadingBookmark]=[]
    @Published private(set) var saving=false
    @Published var selectedID: UUID?
    @Published var error: String?
    weak var library: LibraryModel?
    let repository: BookmarkRepository
    init(root: URL,library: LibraryModel) { repository=BookmarkRepository(root: root);self.library=library }
    var bookRecords: [ReadingBookmark] { records.filter { $0.bookID==library?.currentAIBookID } }
    func matchingTitles(_ text: String) -> [ReadingBookmark] { bookRecords.filter { text.isEmpty || $0.title.localizedCaseInsensitiveContains(text) } }
    func reload() async { do { records=try await repository.load().bookmarks } catch { self.error=error.localizedDescription } }
    func currentLocation() -> BookmarkLocation? {
        guard let library,!library.storageMaintenance else { return nil }
        if library.readingEPUB {
            guard !library.epub.busy,let book=library.epub.book,let anchor=library.epub.progress,book.accepts(anchor) else { return nil }
            return .epub(anchor.withVertical(false))
        }
        guard library.currentAIBookID != nil,let book=library.reader.book,let page=library.reader.document?.page(at: library.reader.pageIndex),let view=library.reader.view else { return nil }
        let box=page.bounds(for: .cropBox),visible=view.convert(view.bounds,to: page)
        let x=min(max(visible.minX,box.minX),box.maxX),y=min(max(visible.maxY,box.minY),box.maxY)
        return .pdf(PDFBookmarkPosition(editionID: book.editionID,fileSHA256: book.fileSHA256,pageIndex: library.reader.pageIndex,x: x,y: y))
    }
    func addCurrent() async {
        guard !saving,let library,let bookID=library.currentAIBookID,let location=currentLocation() else { error="请先打开 PDF 或 EPUB，等待读取完成后添加当前位置。";return }
        saving=true;defer { saving=false }
        do { let saved=try await repository.add(ReadingBookmark(bookID: bookID,location: location,title: location.label));await reload();selectedID=saved.id;error=nil } catch { self.error=error.localizedDescription }
    }
    func rename(_ record: ReadingBookmark,title: String) async -> Bool {
        guard !saving,record.bookID==library?.currentAIBookID else { return false };saving=true;defer { saving=false }
        do { _=try await repository.rename(record,title: title);await reload();error=nil;return true } catch { self.error=error.localizedDescription;return false }
    }
    func delete(_ record: ReadingBookmark) async {
        guard !saving,record.bookID==library?.currentAIBookID else { return };saving=true;defer { saving=false }
        do { try await repository.delete(record);await reload();if selectedID==record.id { selectedID=nil };error=nil } catch { self.error=error.localizedDescription }
    }
    func navigate(_ record: ReadingBookmark) async -> Bool {
        guard let library,!saving,record.bookID==library.currentAIBookID else { return false }
        let success: Bool
        switch record.location {
        case .pdf(let position):
            guard !library.readingEPUB,let book=library.reader.book,book.editionID==position.editionID,book.fileSHA256==position.fileSHA256,let page=library.reader.document?.page(at: position.pageIndex),let view=library.reader.view else { error="书签来源无法验证；记录已保留。";return false }
            success=library.reader.jump(to: position.pageIndex)
            if success { view.go(to: PDFDestination(page: page,at: CGPoint(x: position.x,y: position.y))) }
        case .epub(let anchor):
            guard library.readingEPUB,library.epub.book?.accepts(anchor)==true else { error="书签来源无法验证；记录已保留。";return false }
            success=await library.epub.command("navigate",anchor: anchor.withVertical(library.epub.vertical))
        }
        if success { selectedID=record.id;error=nil } else { error="此书签无法精确定位；记录已保留。" };return success
    }
}

struct BookmarkList: View {
    @ObservedObject var model: BookmarkModel
    let close: () -> Void
    let closeIdentifier: String
    @State private var search=""
    @State private var searchShown=false
    @State private var editing=false
    @State private var renaming: ReadingBookmark?
    @State private var title=""
    private var rows: [ReadingBookmark] { model.matchingTitles(search) }
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text("书签").font(.headline);Spacer()
                Button { Task { await model.addCurrent() } } label: { Image(systemName: "plus") }.help("添加当前阅读位置").accessibilityLabel("添加书签").accessibilityIdentifier("bookmark-add")
                Button { searchShown.toggle();if !searchShown { search="" } } label: { Image(systemName: "magnifyingglass") }.help("搜索书签标题").accessibilityLabel("搜索书签").accessibilityIdentifier("bookmark-search-toggle")
                Button(editing ? "完成" : "编辑") { editing.toggle() }.accessibilityIdentifier("bookmark-edit-toggle")
                Button(action: close) { Image(systemName: "xmark") }.accessibilityLabel("关闭书签").accessibilityIdentifier(closeIdentifier)
            }.buttonStyle(.plain).padding(12).disabled(model.saving)
            if searchShown { TextField("搜索书签标题",text: $search).textFieldStyle(.roundedBorder).padding(.horizontal,12).padding(.bottom,8).accessibilityIdentifier("bookmark-search") }
            Divider()
            List {
                if rows.isEmpty { Text(search.isEmpty ? "还没有书签。添加当前阅读位置，稍后快速返回。" : "没有匹配的书签。").foregroundStyle(.secondary) }
                ForEach(rows) { record in
                    HStack {
                        Button { Task { _=await model.navigate(record) } } label: {
                            VStack(alignment: .leading,spacing: 5) { Text(record.title).lineLimit(2);Text(record.location.label).font(.caption).foregroundStyle(.secondary) }.frame(maxWidth: .infinity,alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityIdentifier("bookmark-row-"+record.id.uuidString)
                        if editing {
                            Button { beginRename(record) } label: { Image(systemName: "pencil") }.accessibilityLabel("重命名书签").accessibilityIdentifier("bookmark-rename")
                            Button { Task { await model.delete(record) } } label: { Image(systemName: "trash") }.accessibilityLabel("删除书签").accessibilityIdentifier("bookmark-delete")
                        }
                    }.padding(6).background(model.selectedID==record.id ? Color.purple.opacity(0.14) : .clear,in: RoundedRectangle(cornerRadius: 7))
                        .contextMenu { Button("重命名") { beginRename(record) };Button("删除书签") { Task { await model.delete(record) } } }
                }
            }.listStyle(.plain).disabled(model.saving).accessibilityIdentifier("bookmark-list")
            if let error=model.error { Text(error).font(.caption).foregroundStyle(.red).padding(10).accessibilityIdentifier("bookmark-error") }
        }.task { await model.reload() }
            .sheet(item: $renaming) { record in
                VStack(alignment: .leading,spacing: 14) {
                    Text("重命名书签").font(.headline)
                    TextField("书签标题",text: $title).textFieldStyle(.roundedBorder).accessibilityIdentifier("bookmark-title-input")
                    Text(record.location.label).foregroundStyle(.secondary)
                    HStack { Button("取消") { renaming=nil };Spacer();Button("保存") { Task { if await model.rename(record,title: title) { renaming=nil } } }.disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || title.utf16.count>128 || title.contains("\n") || model.saving).accessibilityIdentifier("bookmark-title-save") }
                    if let error=model.error { Text(error).font(.caption).foregroundStyle(.red) }
                }.padding(20).frame(width: 360).interactiveDismissDisabled(model.saving)
            }
    }
    private func beginRename(_ record: ReadingBookmark) { title=record.title;renaming=record }
}
#endif
