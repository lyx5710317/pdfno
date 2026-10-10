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
    @State private var legacyNotes = false
    @StateObject private var annotations: AnnotationModel
    private let editing: RecordEditingAdapter?
    public init(model: EbookLibraryModel) { self.model = model; session = model.reader; editing = nil; _annotations = StateObject(wrappedValue: AnnotationModel(root: model.storageRoot)) }
    init(model: EbookLibraryModel, editing: RecordEditingAdapter, annotations: AnnotationModel) { self.model = model; session = model.reader; self.editing = editing; self._annotations = StateObject(wrappedValue: annotations) }
    public var body: some View {
        VStack(spacing: 0) {
            PDFnoProfessionalReaderChrome(title: session.book?.title ?? "文档", format: "") {} actions: {
                PDFnoReaderRailButton(title: "目录", symbol: "list.bullet", identifier: "ebook-navigation", active: navigation, disabled: !session.ready) { navigation.toggle(); notes = false }
                PDFnoReaderRailButton(title: "笔记", symbol: "note.text", identifier: "ebook-notes", active: notes, disabled: !session.ready) {
                    if notes { notes = false } else {
                        notes.toggle(); navigation = false
                    }
                }
                Menu {
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
                } label: { Image(systemName: "info.circle") }.help("文档显示限制").accessibilityIdentifier("ebook-display-info")
            } content: {
                PDFnoReaderShell(panels: readerPanels, profile: .professional) {
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
                } navigation: { navigationSheet } notes: { notesSheet }
            }
        }
        .annotationExperience(annotations,reader: .ebook(session))
        .sheet(isPresented: $legacyNotes) { legacyNotesSheet }
        .navigationTitle(session.book?.title ?? "Ebook")

        .onChange(of: session.progress) { _, anchor in if let anchor { Task { await model.saveProgress(anchor) } } }

        .alert("操作未完成", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("知道了") { model.error = nil }
        } message: { Text(model.error ?? "") }
    }
    private var readerPanels: PDFnoReaderPanels {
        var result = PDFnoReaderPanels()
        if navigation { result.show(.navigation, profile: .professional) }
        else if notes { result.show(.notes, profile: .professional) }
        return result
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
        }
    }
    private var notesSheet: some View { AnnotationList(model: annotations,legacy: { legacyNotes = true }) }
    private var legacyNotesSheet: some View {
        NavigationStack {
            List {
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
                                if await session.navigate(to: note.anchor) { legacyNotes = false }
                                else { model.error = EbookError.sourceMismatch.localizedDescription }
                            } }.accessibilityIdentifier("ebook-return")
                        }.padding(.vertical, 4)
                    }
                }
            }.accessibilityIdentifier("ebook-notes-list").navigationTitle("选文与笔记")
                .toolbar { ToolbarItem { Button("完成") { legacyNotes = false }.accessibilityIdentifier("ebook-close-notes") } }
        }
    }
}
#endif
