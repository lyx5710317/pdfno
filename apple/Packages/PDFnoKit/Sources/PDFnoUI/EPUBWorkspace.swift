// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoReaders

struct EPUBWorkspace: View {
    @ObservedObject var model: LibraryModel
    @ObservedObject var session: EPUBReaderSession
    @State private var contents = false
    @State private var notes = false
    @State private var draft = ""
    @State private var ai = false
    @State private var chapterTranslation = false
    @State private var japaneseLearning = false
    @State private var englishLearning = false
    @State private var draftOwner = UUID().uuidString
    @State private var byokLearning = false
    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: PDFnoDesign.Space.small)], alignment: .leading, spacing: PDFnoDesign.Space.small) {
                JapaneseLearningEntry(identifier: "epub-japanese-learning", disabled: session.busy) {
                    model.prepareJapaneseLearning(); japaneseLearning = true
                }
                Button("英语结构与语法") { model.prepareEnglishLearning(); englishLearning = true }
                    .disabled(session.busy).accessibilityIdentifier("epub-english-learning")
                BYOKSelectionEntry(library: model, identifier: "epub-byok", disabled: session.busy) { byokLearning = true }
                Button("选文 AI") { model.learning.prepare(model.captureAISource()); ai = true }
                    .accessibilityIdentifier("epub-ai")
            }.buttonStyle(PDFnoActionStyle(role: .quiet))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, PDFnoDesign.Space.regular).padding(.vertical, PDFnoDesign.Space.tight)
                .background(PDFnoDesign.Palette.chrome)
            EPUBCanvas(session: session).background(PDFnoDesign.Palette.canvas)
            VStack(alignment: .leading, spacing: PDFnoDesign.Space.tight) {
                HStack {
                    Text(session.position).accessibilityIdentifier("epub-position")
                    Spacer()
                    Button("翻译当前文档") { Task { await model.prepareChapterTranslation(); chapterTranslation = true } }
                        .font(.body).accessibilityIdentifier("epub-chapter-translation").disabled(session.busy)
                }
                Text("EPUB · 本地 · 原书未改写")
            }.font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary).padding(PDFnoDesign.Space.regular)
                .background(PDFnoDesign.Palette.chrome)
            if let error = session.error { PDFnoStatusMessage(text: error, kind: .error, identifier: "epub-error") }
        }.navigationTitle(session.book?.title ?? "EPUB")
        .overlay { if session.busy { PDFnoStatusMessage(text: "正在排版…", kind: .busy).frame(maxWidth: 320).pdfnoCard() } }
        .toolbar {
            ToolbarItemGroup {
                Button("目录") { contents = true }.accessibilityIdentifier("epub-contents").accessibilityValue(contents ? "已展开" : "已收起").help("显示 EPUB 目录，保留阅读位置")
                Button { Task { _ = await session.command("previous") } } label: { Label("上一页", systemImage: "chevron.left") }
                    .accessibilityIdentifier("epub-previous")
                Button { Task { _ = await session.command("next") } } label: { Label("下一页", systemImage: "chevron.right") }
                    .accessibilityIdentifier("epub-next")
                Button(session.vertical ? "横排" : "竖排") { Task { _ = await session.command("vertical") } }
                    .accessibilityIdentifier("epub-orientation")
                Button("高亮与笔记") { notes = true }.accessibilityIdentifier("epub-notes").accessibilityValue(notes ? "已展开" : "已收起").help("显示高亮与笔记，保留选文和草稿")
                Button("取消并关闭") { session.close() }.accessibilityIdentifier("epub-close")
            }
        }
        .onChange(of: session.progress) { _, anchor in if let anchor { Task { await model.saveEPUBProgress(anchor) } } }
        .sheet(isPresented: $contents) {
            NavigationStack {
                List {
                    if session.outline.isEmpty { PDFnoEmptyState(title: "此 EPUB 没有内置目录", detail: "仍可使用上一页和下一页继续阅读。") }
                    ForEach(session.outline) { item in
                        Button(item.title) { Task { if await session.command("chapter", index: item.index) { contents = false } } }
                            .accessibilityIdentifier("epub-chapter-\(item.index)")
                    }
                }.font(PDFnoDesign.TypeStyle.body).navigationTitle("目录").toolbar { ToolbarItem { Button("完成") { contents = false } } }
            }.frame(minWidth: PDFnoDesign.Metric.sheetMinimum, minHeight: 400)
        }
        .sheet(isPresented: $notes) {
            NavigationStack {
                List {
                    Section("当前选区") {
                        if let anchor = session.selection {
                            PDFnoTextViewport(text: anchor.quote, identifier: "epub-selection")
                            TextField("写下你的笔记（可选）", text: $draft, axis: .vertical)
                                .lineLimit(3...8).accessibilityIdentifier("epub-note-input")
                            if !draft.isEmpty { PDFnoStatusMessage(text: "草稿未保存 · 关闭面板会保留，保存成功后清空") }
                            Button("保存高亮与笔记") { Task { if await model.saveEPUBNote(anchor, text: draft) { draft = "" } } }
                                .buttonStyle(PDFnoActionStyle(role: .primary)).accessibilityIdentifier("epub-save-note")
                        } else { PDFnoEmptyState(title: "尚未选择原文", detail: "在原文中选择文字，再打开这里。正文定位保留作者 ruby。") }
                    }
                    Section("已保存 · 本地") {
                        let savedNotes = model.epubNotes.filter { $0.bookID == session.book?.id }
                        if savedNotes.isEmpty { PDFnoEmptyState(title: "这本书还没有笔记", detail: "选择原文后保存高亮或笔记；来源会随记录保留。", icon: "note.text") }
                        ForEach(savedNotes) { note in
                            VStack(alignment: .leading) {
                                Text(note.anchor.quote).accessibilityIdentifier("epub-saved-quote")
                                if !note.userText.isEmpty { Text(verbatim: note.userText).foregroundStyle(.secondary).accessibilityIdentifier("epub-saved-user-text") }
                                NoteBodyEditor(editor: model.noteEditing, note: .epub(note), identifier: "epub-note") {
                                    await model.saveEditedNote(.epub(note))
                                } reload: { await model.reloadEditedNote(.epub(note)) }
                                Button("回到原文") { Task { if await session.command("navigate", anchor: note.anchor) { notes = false } } }
                                    .accessibilityIdentifier("epub-return")
                            }
                        }
                    }
                    JapaneseSavedNotesSection(library: model, bookID: session.book?.id) { notes = false }
                    EnglishSavedNotesSection(library: model, bookID: session.book?.id) { notes = false }
                }.font(PDFnoDesign.TypeStyle.body).accessibilityIdentifier("epub-notes-list").navigationTitle("高亮与笔记").toolbar { ToolbarItem { Button("完成") { notes = false }.accessibilityIdentifier("epub-close-notes") } }
            }.frame(minWidth: PDFnoDesign.Metric.sheetMinimum, idealWidth: 480, minHeight: 420)
        }
        .sheet(isPresented: $chapterTranslation) { EPUBChapterTranslationWorkspace(library: model, translation: model.chapterTranslation, learning: model.learning) }
        .onChange(of: draft) { _, value in model.recordVisibleDraft(owner: draftOwner, dirty: !value.isEmpty) }
        .onDisappear { model.recordVisibleDraft(owner: draftOwner, dirty: false) }
        .sheet(isPresented: $englishLearning) { EnglishLearningSheet(library: model) }
        .sheet(isPresented: $japaneseLearning) { JapaneseLearningSheet(library: model) }
        .sheet(isPresented: $ai) { AILearningWorkspace(library: model, learning: model.learning) }
        .sheet(isPresented: $byokLearning) { BYOKLearningWorkspace(library: model, model: model.byok) }
    }
}
#endif
