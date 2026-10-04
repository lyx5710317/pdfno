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
    @State private var byokLearning = false
    var body: some View {
        VStack(spacing: 0) {
            JapaneseLearningEntry(identifier: "epub-japanese-learning", disabled: session.busy) {
                model.prepareJapaneseLearning(); japaneseLearning = true
            }
            BYOKSelectionEntry(library: model, identifier: "epub-byok", disabled: session.busy) { byokLearning = true }
            EPUBCanvas(session: session)
            HStack {
                Text(session.position).accessibilityIdentifier("epub-position")
                Spacer()
                Button("翻译当前文档") { Task { await model.prepareChapterTranslation(); chapterTranslation = true } }
                    .font(.body).accessibilityIdentifier("epub-chapter-translation").disabled(session.busy)
                Text("EPUB · 本地 · 原书未改写").lineLimit(1)
            }.font(.caption).padding(10)
            if let error = session.error { Text(error).foregroundStyle(.red).padding().accessibilityIdentifier("epub-error") }
        }.navigationTitle(session.book?.title ?? "EPUB")
        .overlay { if session.busy { ProgressView("正在排版…").padding().background(.regularMaterial) } }
        .toolbar {
            ToolbarItemGroup {
                Button("目录") { contents = true }.accessibilityIdentifier("epub-contents")
                Button { Task { _ = await session.command("previous") } } label: { Label("上一页", systemImage: "chevron.left") }
                    .accessibilityIdentifier("epub-previous")
                Button { Task { _ = await session.command("next") } } label: { Label("下一页", systemImage: "chevron.right") }
                    .accessibilityIdentifier("epub-next")
                Button(session.vertical ? "横排" : "竖排") { Task { _ = await session.command("vertical") } }
                    .accessibilityIdentifier("epub-orientation")
                Button("高亮与笔记") { notes = true }.accessibilityIdentifier("epub-notes")
                Button("选文 AI") { model.learning.prepare(model.captureAISource()); ai = true }.accessibilityIdentifier("epub-ai")
                Button("取消并关闭") { session.close() }.accessibilityIdentifier("epub-close")
            }
        }
        .onChange(of: session.progress) { _, anchor in if let anchor { Task { await model.saveEPUBProgress(anchor) } } }
        .sheet(isPresented: $contents) {
            NavigationStack {
                List(session.outline) { item in
                    Button(item.title) { Task { if await session.command("chapter", index: item.index) { contents = false } } }
                        .accessibilityIdentifier("epub-chapter-\(item.index)")
                }.navigationTitle("目录").toolbar { ToolbarItem { Button("完成") { contents = false } } }
            }.frame(minWidth: 320, minHeight: 400)
        }
        .sheet(isPresented: $notes) {
            NavigationStack {
                List {
                    Section("当前选区") {
                        if let anchor = session.selection {
                            Text(anchor.quote).accessibilityIdentifier("epub-selection")
                            TextField("写下你的笔记（可选）", text: $draft, axis: .vertical)
                                .accessibilityIdentifier("epub-note-input")
                            Button("保存高亮与笔记") { Task { if await model.saveEPUBNote(anchor, text: draft) { draft = "" } } }
                                .accessibilityIdentifier("epub-save-note")
                        } else { Text("在原文中选择文字，再打开这里。正文定位保留作者 ruby。") }
                    }
                    Section("已保存 · 本地") {
                        ForEach(model.epubNotes.filter { $0.bookID == session.book?.id }) { note in
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
                }.accessibilityIdentifier("epub-notes-list").navigationTitle("高亮与笔记").toolbar { ToolbarItem { Button("完成") { notes = false }.accessibilityIdentifier("epub-close-notes") } }
            }.frame(minWidth: 360, minHeight: 420)
        }
        .sheet(isPresented: $chapterTranslation) { EPUBChapterTranslationWorkspace(library: model, translation: model.chapterTranslation, learning: model.learning) }
        .sheet(isPresented: $japaneseLearning) { JapaneseLearningSheet(library: model) }
        .sheet(isPresented: $ai) { AILearningWorkspace(library: model, learning: model.learning) }
        .sheet(isPresented: $byokLearning) { BYOKLearningWorkspace(library: model, model: model.byok) }
    }
}
#endif
