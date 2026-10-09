// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoReaders

public struct EbookWorkspace: View {
    @ObservedObject var model: EbookLibraryModel
    @ObservedObject var session: EbookReaderSession
    @State private var navigation = false
    @State private var notes = false
    @State private var draft = ""
    @State private var draftOwner = UUID().uuidString
    @State private var captured: EbookAnchor?
    private let editing: RecordEditingAdapter?
    public init(model: EbookLibraryModel) { self.model = model; session = model.reader; editing = nil }
    init(model: EbookLibraryModel, editing: RecordEditingAdapter) { self.model = model; session = model.reader; self.editing = editing }
    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(session.book?.format.rawValue.uppercased() ?? "电子书") · 正文重排阅读").font(.headline)
                Text("无 DRM MOBI6/KF8、UTF-8 FB2。保留正文与作者读音；图片、字体、链接目标和原始分页不显示。")
                    .font(.caption).foregroundStyle(.secondary)
                if session.ready && !session.highlightsSupported {
                    Text("当前 WebKit 不支持持久高亮显示；选文笔记与精确回到原文仍可使用。").font(.caption).foregroundStyle(.secondary)
                }
                if let warnings = session.document?.warnings, !warnings.isEmpty {
                    DisclosureGroup("此文档的显示限制（\(warnings.count)）") {
                        ForEach(warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                    }.font(.caption)
                }
            }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.bar)
            HStack(spacing: 12) {
            Button { navigation = true } label: { Label("标题目录", systemImage: "list.bullet") }.disabled(!session.ready).accessibilityIdentifier("ebook-navigation")
            Button { Task { captured = await session.captureSelection(); notes = true } } label: { Label("选文与笔记", systemImage: "highlighter") }.disabled(!session.ready).accessibilityIdentifier("ebook-notes")
                Spacer()
            }.padding(.horizontal, 12).padding(.vertical, 8).background(.bar)
            if let error = session.error {
                VStack {
                    ContentUnavailableView("Ebook 无法显示", systemImage: "exclamationmark.triangle", description: Text(error))
                    if let book = session.book {
                        Button("重新打开") { Task {
                            do { try await model.open(book) } catch { model.error = error.localizedDescription }
                        } }.disabled(model.busy).padding()
                    }
                }
            }
            else { EbookCanvas(session: session).frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("ebook-content") }
        }
        .navigationTitle(session.book?.title ?? "Ebook")

        .onChange(of: draft) { _, value in LibraryMaintenanceOwners.setDraft(root: model.storageRoot, owner: draftOwner, dirty: !value.isEmpty) }
        .onDisappear { LibraryMaintenanceOwners.setDraft(root: model.storageRoot, owner: draftOwner, dirty: false) }
        .onChange(of: session.progress) { _, anchor in if let anchor { Task { await model.saveProgress(anchor) } } }
        .sheet(isPresented: $navigation) { navigationSheet }
        .sheet(isPresented: $notes) { notesSheet }
        .alert("操作未完成", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var navigationSheet: some View {
        NavigationStack {
            List {
                if session.document?.outline.isEmpty != false { Text("此电子书没有语义标题；可通过下方章节入口导航。") }
                ForEach(session.document?.navigationBlocks ?? []) { block in
                    Button { Task {
                        if await session.navigate(blockID: block.id) { navigation = false }
                        else { model.error = EbookError.sourceMismatch.localizedDescription }
                    } } label: { Text(block.text).padding(.leading, CGFloat((block.headingLevel ?? 1) - 1) * 12) }
                        .accessibilityIdentifier("ebook-chapter-\(block.id)")
                }
            }.navigationTitle("标题目录").toolbar { ToolbarItem { Button("完成") { navigation = false } } }
        }.frame(minWidth: 320, minHeight: 400)
    }
    private var notesSheet: some View {
        NavigationStack {
            List {
                Section("当前选文") {
                    if let anchor = captured {
                        Text(anchor.quote).textSelection(.enabled).accessibilityIdentifier("ebook-selection")
                        TextField("写下笔记（可选）", text: $draft, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("ebook-user-note")
                        Button("保存选文与笔记") { Task { if await model.saveNote(anchor, text: draft) { draft = "" } } }.accessibilityIdentifier("ebook-save-note")
                    } else { Text("先在 Ebook 正文中选择文字。最多保存 16000 个 UTF-16 字元。").accessibilityIdentifier("ebook-selection-empty") }
                }
                Section("已保存 · 本地") {
                    let saved = model.notes.filter { $0.bookID == session.book?.id }
                    if saved.isEmpty { Text("这份文档还没有笔记") }
                    ForEach(saved) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(note.anchor.quote).font(.callout).accessibilityIdentifier("ebook-saved-quote")
                            if !note.userText.isEmpty { Text(note.userText).foregroundStyle(.secondary).accessibilityIdentifier("ebook-saved-user-note") }
                            if let editing {
                                RecordBodyEditor(editor: editing.editor, note: .ebook(note), identifier: "ebook-note") {
                                    await editing.save(.ebook(note))
                                } reload: { await editing.reload(.ebook(note)) }
                            }
                            Button("回到原文 · 段落 \(note.anchor.blockID + 1)") { Task {
                                if await session.navigate(to: note.anchor) { notes = false }
                                else { model.error = EbookError.sourceMismatch.localizedDescription }
                            } }.accessibilityIdentifier("ebook-return")
                        }.padding(.vertical, 4)
                    }
                }
            }.accessibilityIdentifier("ebook-notes-list").navigationTitle("选文与笔记")
                .toolbar { ToolbarItem { Button("完成") { notes = false }.accessibilityIdentifier("ebook-close-notes") } }
        }.frame(minWidth: 340, minHeight: 440)
    }
}
#endif
