// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoReaders

public struct DOCXWorkspace: View {
    @ObservedObject var model: DOCXLibraryModel
    @ObservedObject var session: DOCXReaderSession
    @State private var navigation = false
    @State private var notes = false
    @State private var draft = ""
    @State private var captured: DOCXAnchor?
    public init(model: DOCXLibraryModel) { self.model = model; session = model.reader }
    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("DOCX · 语义重排阅读").font(.headline)
                Text("保留正文与标题层级。分页、字体、页眉页脚等与 Word 原版式不同；旧版 DOC 尚未支持。")
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
            if let error = session.error {
                VStack {
                    ContentUnavailableView("DOCX 无法显示", systemImage: "exclamationmark.triangle", description: Text(error))
                    if let book = session.book {
                        Button("重新打开") { Task {
                            do { try await model.open(book) } catch { model.error = error.localizedDescription }
                        } }.disabled(model.busy).padding()
                    }
                }
            }
            else { DOCXCanvas(session: session) }
        }
        .navigationTitle(session.book?.title ?? "DOCX")
        .toolbar { ToolbarItemGroup {
            Button { navigation = true } label: { Label("标题目录", systemImage: "list.bullet") }.disabled(!session.ready)
            Button { captured = session.selection; notes = true } label: { Label("选文与笔记", systemImage: "highlighter") }.disabled(!session.ready)
        } }
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
                if session.document?.outline.isEmpty != false { Text("此 DOCX 没有语义标题；字号大小不会自动当作标题。") }
                ForEach(session.document?.outline ?? []) { block in
                    Button { Task {
                        if await session.navigate(blockID: block.id) { navigation = false }
                        else { model.error = DOCXError.sourceMismatch.localizedDescription }
                    } } label: { Text(block.text).padding(.leading, CGFloat((block.headingLevel ?? 1) - 1) * 12) }
                }
            }.navigationTitle("标题目录").toolbar { ToolbarItem { Button("完成") { navigation = false } } }
        }.frame(minWidth: 320, minHeight: 400)
    }
    private var notesSheet: some View {
        NavigationStack {
            List {
                Section("当前选文") {
                    if let anchor = captured {
                        Text(anchor.quote).textSelection(.enabled)
                        TextField("写下笔记（可选）", text: $draft, axis: .vertical).lineLimit(3...8)
                        Button("保存选文与笔记") { Task { if await model.saveNote(anchor, text: draft) { draft = "" } } }
                    } else { Text("先在 DOCX 正文中选择文字。最多保存 16000 个 UTF-16 字元。") }
                }
                Section("已保存 · 本地") {
                    let saved = model.notes.filter { $0.bookID == session.book?.id }
                    if saved.isEmpty { Text("这份文档还没有笔记") }
                    ForEach(saved) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(note.anchor.quote).font(.callout)
                            if !note.userText.isEmpty { Text(note.userText).foregroundStyle(.secondary) }
                            Button("回到原文 · 段落 \(note.anchor.blockID + 1)") { Task {
                                if await session.navigate(to: note.anchor) { notes = false }
                                else { model.error = DOCXError.sourceMismatch.localizedDescription }
                            } }
                        }.padding(.vertical, 4)
                    }
                }
            }.navigationTitle("选文与笔记").toolbar { ToolbarItem { Button("完成") { notes = false } } }
        }.frame(minWidth: 340, minHeight: 440)
    }
}
#endif
