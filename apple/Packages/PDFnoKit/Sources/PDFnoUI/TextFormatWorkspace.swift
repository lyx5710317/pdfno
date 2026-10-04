// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoReaders

public struct TextFormatWorkspace: View {
    @ObservedObject var model: TextFormatLibraryModel
    @ObservedObject var session: TextFormatReaderSession
    @State private var navigation = false
    @State private var notes = false
    @State private var draft = ""
    @State private var captured: TextFormatAnchor?
    public init(model: TextFormatLibraryModel) { self.model = model; session = model.reader }
    public var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text((session.book?.format.label ?? "文本") + " · 本地阅读").font(.headline)
                Text("TXT 章节为自动识别；标记文档按实际标题导航。网页归档仅离线正文，图片与样式不显示。链接仅显示文字。引文定位于规范化显示正文，原文件保持不变。")
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
                    ContentUnavailableView("文本无法显示", systemImage: "exclamationmark.triangle", description: Text(error))
                    if let book = session.book {
                        Button("重新打开") { Task {
                            do { try await model.open(book) } catch { model.error = error.localizedDescription }
                        } }.disabled(model.busy).padding()
                    }
                }
            }
            else { TextFormatCanvas(session: session).frame(maxWidth: .infinity, maxHeight: .infinity).accessibilityIdentifier("textformat-content") }
            if session.ready, let document = session.document {
                HStack {
                    if let anchor = session.progress { Text("段落 \(anchor.blockID + 1) / \(document.blocks.count)").monospacedDigit() }
                    else { Text("共 \(document.blocks.count) 段") }
                    Spacer(); Text("笔记与进度保存在本地")
                }.font(.caption).foregroundStyle(.secondary).padding(10).accessibilityIdentifier("textformat-position")
            }
        }
        .navigationTitle(session.book?.title ?? "文本")
        .toolbar { ToolbarItemGroup {
            Button { navigation = true } label: { Label("标题目录", systemImage: "list.bullet") }.disabled(!session.ready).accessibilityIdentifier("textformat-navigation")
            Button { Task { captured = await session.captureSelection(); notes = true } } label: { Label("选文与笔记", systemImage: "highlighter") }.disabled(!session.ready).accessibilityIdentifier("textformat-notes")
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
                if session.document?.outline.isEmpty != false { Text("此文件没有识别到标题；可以阅读、选文和保存进度。") }
                ForEach(session.document?.outline ?? []) { block in
                    Button { Task {
                        if await session.navigate(blockID: block.id) { navigation = false }
                        else { model.error = TextFormatError.sourceMismatch.localizedDescription }
                    } } label: { Text(verbatim: block.text).padding(.leading, CGFloat((block.headingLevel ?? 1) - 1) * 12) }
                        .accessibilityIdentifier("textformat-chapter-\(block.id)")
                }
            }.navigationTitle("标题目录").toolbar { ToolbarItem { Button("完成") { navigation = false } } }
        }.frame(minWidth: 320, minHeight: 400)
    }
    private var notesSheet: some View {
        NavigationStack {
            List {
                Section("当前选文") {
                    if let anchor = captured {
                        Text(verbatim: anchor.quote).textSelection(.enabled).accessibilityIdentifier("textformat-selection")
                        TextField("写下笔记（可选）", text: $draft, axis: .vertical).lineLimit(3...8).accessibilityIdentifier("textformat-user-note")
                        Button("保存选文与笔记") { Task { if await model.saveNote(anchor, text: draft) { draft = "" } } }.accessibilityIdentifier("textformat-save-note")
                    } else { Text("先在正文中选择文字。最多保存 16000 个 UTF-16 字元。").accessibilityIdentifier("textformat-selection-empty") }
                }
                Section("已保存 · 本地") {
                    let saved = model.notes.filter { $0.bookID == session.book?.id }
                    if saved.isEmpty { Text("这份文档还没有笔记") }
                    ForEach(saved) { note in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: note.anchor.quote).font(.callout).accessibilityIdentifier("textformat-saved-quote")
                            if !note.userText.isEmpty { Text(verbatim: note.userText).foregroundStyle(.secondary).accessibilityIdentifier("textformat-saved-user-note") }
                            Button("回到原文 · 段落 \(note.anchor.blockID + 1)") { Task {
                                if await session.navigate(to: note.anchor) { notes = false }
                                else { model.error = TextFormatError.sourceMismatch.localizedDescription }
                            } }.accessibilityIdentifier("textformat-return")
                        }.padding(.vertical, 4)
                    }
                }
            }.navigationTitle("选文与笔记").toolbar { ToolbarItem { Button("完成") { notes = false } } }
        }.frame(minWidth: 340, minHeight: 440)
    }
}
#endif
