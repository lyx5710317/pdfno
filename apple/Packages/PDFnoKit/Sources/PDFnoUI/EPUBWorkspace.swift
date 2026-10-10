// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoReaders

struct EPUBWorkspace: View {
    @Environment(\.pdfnoWorkspaceNavigation) private var workspaceNavigation
    @ObservedObject var model: LibraryModel
    @ObservedObject var session: EPUBReaderSession
    @State private var panels = PDFnoReaderPanels()
    @State private var inspector = PDFnoReaderInspector.notes
    @State private var readerWidth: CGFloat = 0
    @State private var readerSettings = false
    @State private var legacyNotes = false
    @State private var draft = ""
    @State private var draftAnchor: EPUBAnchor?
    @State private var chapterTranslation = false
    @State private var japaneseLearning = false
    @State private var englishLearning = false
    @State private var draftOwner = UUID().uuidString
    @State private var byokLearning = false
    @State private var aiTools = false
    var body: some View {
        VStack(spacing: 0) {
            PDFnoProfessionalReaderChrome(title: session.book?.title ?? "EPUB", format: "EPUB") {
            } actions: { professionalActions } content: {
                PDFnoReaderShell(panels: panels, profile: .professional) {
                    VStack(spacing: 0) {
                        EPUBCanvas(session: session).background(PDFnoDesign.Palette.canvas)
                            .overlay(alignment: .bottom) {
                                if session.readingLayout.mode != .scroll {
                                    ReadingPageButtons(previousEnabled: !session.busy && session.hasPreviousPage,nextEnabled: !session.busy && session.hasNextPage,previous: { Task { _=await session.command("previous") } },next: { Task { _=await session.command("next") } })
                                }
                            }
                    }
                } navigation: {
                    PDFnoPanel(title: "目录", icon: "list.bullet", closeIdentifier: "epub-close-contents", close: { panels.navigation = false }, surface: PDFnoDesign.Palette.surface,showsHeading: false) { contentsContent }
                } notes: {
                    if inspector == .layout {
                        ReadingLayoutPanel(layout: session.readingLayout,language: session.writingLanguage,busy: session.busy,close: { panels.notes=false }) { value in Task { _=await session.applyReadingLayout(value) } }
                    } else if inspector == .bookmarks {
                        BookmarkList(model: model.bookmarks,close: { panels.notes=false },closeIdentifier: "epub-close-bookmarks")
                    } else if inspector == .learning {
                        ReadingSelectionWorkspace(library: model) { panels.notes = false }
                    } else {
                        PDFnoPanel(title: "文档标注", icon: "note.text", closeIdentifier: "epub-close-notes", close: closeNotes) { notesContent }
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
                Text(session.vertical ? "竖排 · 上下连续滚动 · 原书未改写" : "上下连续滚动 · 原书未改写")
            }.font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary).padding(PDFnoDesign.Space.regular)
                .background(PDFnoDesign.Palette.chrome)
            if let error = session.error { PDFnoStatusMessage(text: error, kind: .error, identifier: "epub-error") }
        }.navigationTitle(session.book?.title ?? "EPUB")
        .annotationExperience(model.annotations,reader: .epub(session),aiLibrary: model)
        .sheet(isPresented: $legacyNotes) { NavigationStack { legacyNotesContent.navigationTitle("旧笔记与学习记录").toolbar { ToolbarItem { Button("完成") { legacyNotes = false } } } } }
        .overlay { if session.busy { PDFnoStatusMessage(text: "正在排版…", kind: .busy).frame(maxWidth: 320).pdfnoCard() } }
        .onChange(of: session.progress) { _, anchor in if let anchor { Task { await model.saveEPUBProgress(anchor) } } }
        .sheet(isPresented: $chapterTranslation) { EPUBChapterTranslationWorkspace(library: model, translation: model.chapterTranslation, learning: model.learning) }
        .onChange(of: draft) { _, value in
            if value.isEmpty { draftAnchor = nil }
            else if draftAnchor == nil { draftAnchor = session.selection }
            model.recordVisibleDraft(owner: draftOwner, dirty: !value.isEmpty)
        }
        .onDisappear { model.recordVisibleDraft(owner: draftOwner, dirty: false) }
        .sheet(isPresented: $englishLearning) { EnglishLearningSheet(library: model) }
        .sheet(isPresented: $japaneseLearning) { JapaneseLearningSheet(library: model) }
        .sheet(isPresented: $byokLearning) { BYOKLearningWorkspace(library: model, model: model.byok) }
        .sheet(isPresented: $aiTools) { ReadingToolsWorkspace(library: model) }
        .sheet(isPresented: $readerSettings) { AISettingsView(learning: model.learning, byok: model.byok, library: model) }
    }
    private var contentsVisible: Bool { panels.placement(width: readerWidth, profile: .professional).showNavigation }
    private var notesVisible: Bool { panels.placement(width: readerWidth, profile: .professional).showNotes && inspector == .notes }
    private func closeNotes() { legacyNotes = false; panels.notes = false }
    private func openNotes() {
        if inspector == .notes { panels.toggle(.notes, width: readerWidth, profile: .professional) }
        else { inspector = .notes; panels.show(.notes, profile: .professional) }
    }
    private var professionalActions: some View {
        Group {
            if session.readingCapability.allowsAa {
            PDFnoReaderRailButton(title: "Aa",symbol: "textformat",identifier: "epub-aa",accessibilityTitle: "Aa 排版",active: panels.placement(width: readerWidth,profile: .professional).showNotes && inspector == .layout,disabled: session.book == nil || session.busy,hint: session.writingLanguage.permitsVerticalReflow ? "字号、横竖排与翻页模式":"字号与翻页模式") {
                if inspector == .layout { panels.toggle(.notes,width: readerWidth,profile: .professional) }
                else { inspector = .layout;panels.show(.notes,profile: .professional) }
            }
            }
            PDFnoReaderRailButton(title: "目录", symbol: "list.bullet", identifier: "epub-contents", active: contentsVisible, disabled: session.book == nil || session.busy, hint: "显示或收起 EPUB 目录，保留阅读位置") { panels.toggle(.navigation, width: readerWidth, profile: .professional) }
            PDFnoReaderRailButton(title: "笔记", symbol: "note.text", identifier: "epub-notes", accessibilityTitle: "高亮与笔记", active: notesVisible, action: openNotes)
            PDFnoReaderRailButton(title: "书签",symbol: "bookmark",identifier: "epub-bookmarks",active: panels.placement(width: readerWidth,profile: .professional).showNotes && inspector == .bookmarks,hint: "显示或收起当前文档书签") {
                if inspector == .bookmarks { panels.toggle(.notes,width: readerWidth,profile: .professional) }
                else { inspector = .bookmarks;panels.show(.notes,profile: .professional) }
            }
            PDFnoReaderRailButton(title: "AI", symbol: "brain.head.profile", identifier: "epub-ai", accessibilityTitle: "选文 AI", active: panels.placement(width: readerWidth, profile: .professional).showNotes && inspector == .learning, disabled: session.selection == nil && model.learning.source == nil && !model.hasCurrentSavedLearningNotes) {
                if panels.placement(width: readerWidth, profile: .professional).showNotes && inspector == .learning { panels.notes = false }
                else { model.learning.prepare(model.captureAISource() ?? model.learning.source); inspector = .learning; panels.show(.notes, profile: .professional) }
            }

        }
    }
    private var contentsContent: some View {
        List {
            if session.outline.isEmpty { PDFnoEmptyState(title: "此 EPUB 没有内置目录", detail: "仍可在正文中继续滚动阅读。") }
            ForEach(session.outline) { item in
                Button { Task { if await session.jump(to: item) { panels.navigation = false } } } label: {
                    Text(item.title).frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.accessibilityIdentifier("epub-chapter-\(item.index)")
            }
        }.listStyle(.sidebar).scrollContentBackground(.hidden)
            .background(PDFnoDesign.Palette.surface).font(PDFnoDesign.TypeStyle.body)
    }
    private var notesContent: some View { AnnotationList(model: model.annotations,legacy: { legacyNotes = true }) }
    private var legacyNotesContent: some View {
        List {
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
