// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoReaders

struct EPUBWorkspace: View {
    @ObservedObject var model: LibraryModel
    @ObservedObject var session: EPUBReaderSession
    @State private var panels = PDFnoReaderPanels()
    @State private var inspector = PDFnoReaderInspector.notes
    @State private var readerWidth: CGFloat = 0
    @State private var readerSettings = false
    @State private var draft = ""
    @State private var chapterTranslation = false
    @State private var japaneseLearning = false
    @State private var englishLearning = false
    @State private var draftOwner = UUID().uuidString
    @State private var byokLearning = false
    @State private var aiTools = false
    var body: some View {
        VStack(spacing: 0) {
            PDFnoProfessionalReaderChrome(title: session.book?.title ?? "EPUB", format: "EPUB") {
                Button { Task { _ = await session.command("previous") } } label: { Label("上一页", systemImage: "chevron.left") }
                    .disabled(session.book == nil || session.busy).accessibilityIdentifier("epub-previous")
                Button { Task { _ = await session.command("next") } } label: { Label("下一页", systemImage: "chevron.right") }
                    .disabled(session.book == nil || session.busy).accessibilityIdentifier("epub-next")
                EPUBReturnToPreviousLocationButton(session: session)
                Button(session.vertical ? "横排" : "竖排") { Task { _ = await session.command("vertical") } }
                    .accessibilityIdentifier("epub-orientation")
                Button { session.close() } label: { Label("取消并关闭", systemImage: "xmark") }
                    .accessibilityIdentifier("epub-close")
            } actions: { professionalActions } content: {
                PDFnoReaderShell(panels: panels, profile: .professional, overlayPanels: true) {
                    EPUBCanvas(session: session).background(PDFnoDesign.Palette.canvas)
                } navigation: {
                    PDFnoPanel(title: "目录", icon: "list.bullet", closeIdentifier: "epub-close-contents", close: { panels.navigation = false }) { contentsContent }
                } notes: {
                    if inspector == .learning {
                        AILearningWorkspace(library: model, learning: model.learning, embedded: true) { panels.notes = false }
                    } else {
                        PDFnoPanel(title: "高亮与笔记", icon: "highlighter", closeIdentifier: "epub-close-notes", close: closeNotes) { notesContent }
                    }
                }.background {
                    GeometryReader { geometry in
                        Color.clear.onAppear { readerWidth = geometry.size.width }
                            .onChange(of: geometry.size.width) { _, width in readerWidth = width }
                    }
                }
            }
            HStack {
                Text(session.position).accessibilityIdentifier("epub-position")
                Spacer()
                Text("EPUB · 本地 · 原书未改写")
            }.font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary).padding(PDFnoDesign.Space.regular)
                .background(PDFnoDesign.Palette.chrome)
            if let error = session.error { PDFnoStatusMessage(text: error, kind: .error, identifier: "epub-error") }
        }.navigationTitle(session.book?.title ?? "EPUB")
        .overlay { if session.busy { PDFnoStatusMessage(text: "正在排版…", kind: .busy).frame(maxWidth: 320).pdfnoCard() } }
        .onChange(of: session.progress) { _, anchor in if let anchor { Task { await model.saveEPUBProgress(anchor) } } }
        .sheet(isPresented: $chapterTranslation) { EPUBChapterTranslationWorkspace(library: model, translation: model.chapterTranslation, learning: model.learning) }
        .onChange(of: draft) { _, value in model.recordVisibleDraft(owner: draftOwner, dirty: !value.isEmpty) }
        .onDisappear { model.recordVisibleDraft(owner: draftOwner, dirty: false) }
        .sheet(isPresented: $englishLearning) { EnglishLearningSheet(library: model) }
        .sheet(isPresented: $japaneseLearning) { JapaneseLearningSheet(library: model) }
        .sheet(isPresented: $byokLearning) { BYOKLearningWorkspace(library: model, model: model.byok) }
        .sheet(isPresented: $aiTools) { ReadingToolsWorkspace(library: model) }
        .sheet(isPresented: $readerSettings) { AISettingsView(learning: model.learning, byok: model.byok, library: model) }
    }
    private var contentsVisible: Bool { panels.placement(width: readerWidth, profile: .professional).showNavigation }
    private var notesVisible: Bool { panels.placement(width: readerWidth, profile: .professional).showNotes && inspector == .notes }
    private func closeNotes() { panels.notes = false }
    private func openNotes() {
        if inspector == .notes { panels.toggle(.notes, width: readerWidth, profile: .professional) }
        else { inspector = .notes; panels.show(.notes) }
    }
    private var professionalActions: some View {
        Group {
            PDFnoReaderRailButton(title: "目录", symbol: "list.bullet", identifier: "epub-contents", active: contentsVisible, disabled: session.book == nil || session.busy, hint: "显示或收起 EPUB 目录，保留阅读位置") { panels.toggle(.navigation, width: readerWidth, profile: .professional) }
            PDFnoReaderRailButton(title: "笔记", symbol: "highlighter", identifier: "epub-notes", accessibilityTitle: "高亮与笔记", active: notesVisible, action: openNotes)
            PDFnoReaderRailButton(title: "AI", symbol: "sparkles", identifier: "epub-ai", accessibilityTitle: "选文 AI", active: panels.placement(width: readerWidth, profile: .professional).showNotes && inspector == .learning) {
                if panels.placement(width: readerWidth, profile: .professional).showNotes && inspector == .learning { panels.notes = false }
                else { model.learning.prepare(model.captureAISource()); inspector = .learning; panels.show(.notes) }
            }
            Divider().padding(.horizontal, 12).padding(.vertical, 4)
            PDFnoReaderRailButton(title: "工具", symbol: "square.grid.2x2", identifier: "epub-ai-tools", accessibilityTitle: "AI工具", disabled: session.busy) { aiTools = true }
            PDFnoReaderRailButton(title: "日语", symbol: "character.ja", identifier: "epub-japanese-learning", accessibilityTitle: "日语选文学习", disabled: session.busy) { model.prepareJapaneseLearning(); japaneseLearning = true }
            PDFnoReaderRailButton(title: "英语", symbol: "textformat.abc", identifier: "epub-english-learning", accessibilityTitle: "英语结构与语法", disabled: session.busy) { model.prepareEnglishLearning(); englishLearning = true }
            PDFnoReaderRailButton(title: "整章", symbol: "book", identifier: "epub-chapter-translation", accessibilityTitle: "翻译当前文档", disabled: session.busy, hint: "预览当前完整 spine 文档，确认后发送") { Task { await model.prepareChapterTranslation(); chapterTranslation = true } }
            PDFnoReaderRailButton(title: "BYOK", symbol: "network", identifier: "epub-byok", accessibilityTitle: "BYOK选文 · 翻译/解释", disabled: session.busy) { Task { await model.prepareBYOKSelection(); byokLearning = true } }
            Divider().padding(.horizontal, 12).padding(.vertical, 4)
            PDFnoReaderRailButton(title: "设置", symbol: "slider.horizontal.3", identifier: "epub-reader-settings", accessibilityTitle: "模型与 BYOK 设置") { readerSettings = true }
        }
    }
    private var contentsContent: some View {
        List {
            if session.outline.isEmpty { PDFnoEmptyState(title: "此 EPUB 没有内置目录", detail: "仍可使用上一页和下一页继续阅读。") }
            ForEach(session.outline) { item in
                Button { Task { if await session.jump(to: item) { panels.navigation = false } } } label: {
                    Text(item.title).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.accessibilityIdentifier("epub-chapter-\(item.index)")
            }
        }.listStyle(.sidebar).font(PDFnoDesign.TypeStyle.body)
    }
    private var notesContent: some View {
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
                        Button("回到原文") { Task { if await session.command("navigate", anchor: note.anchor) { closeNotes() } } }
                            .accessibilityIdentifier("epub-return")
                    }
                }
            }
            JapaneseSavedNotesSection(library: model, bookID: session.book?.id) { closeNotes() }
            EnglishSavedNotesSection(library: model, bookID: session.book?.id) { closeNotes() }
        }.font(PDFnoDesign.TypeStyle.body).accessibilityIdentifier("epub-notes-list")
    }
}
#endif
