// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

/// Each document owns its native reader, source fences, task results and draft owners.
/// Presentation changes never reopen a document or persist a draft.
@MainActor final class MacDocumentTab: Identifiable {
    let id: UUID
    let title: String
    let model: LibraryModel
    init(model: LibraryModel) {
        self.model = model
        id = model.displayedDocumentID!
        title = model.displayedDocumentTitle
    }
}

@MainActor final class MacDocumentTabs: ObservableObject {
    let catalogue: LibraryModel
    @Published private(set) var tabs: [MacDocumentTab] = []
    @Published private(set) var activeID: UUID?
    @Published private(set) var opening = false
    @Published var pendingCloseID: UUID?
    @Published var error: String?
    private let documentFactory: (@MainActor (URL) -> LibraryModel)?
    init(catalogue: LibraryModel, documentFactory: (@MainActor (URL) -> LibraryModel)? = nil) {
        self.catalogue = catalogue; self.documentFactory = documentFactory
    }
    var active: MacDocumentTab? { tabs.first { $0.id == activeID } }
    func adopt(_ model: LibraryModel) {
        guard let id = model.displayedDocumentID else { return }
        if !tabs.contains(where: { $0.id == id }) { tabs.append(MacDocumentTab(model: model)) }
        activeID = id
    }
    func activate(_ id: UUID) {
        guard tabs.contains(where: { $0.id == id }) else { return }
        activeID = id
    }
    func makeDocumentModel() -> LibraryModel { documentFactory?(catalogue.recordRoot) ?? LibraryModel(root: catalogue.recordRoot) }
    func open(_ id: UUID) async -> Bool {
        if tabs.contains(where: { $0.id == id }) { activate(id); return true }
        guard !opening, !catalogue.storageMaintenance else { return false }
        opening = true; defer { opening = false }
        let model = makeDocumentModel()
        await model.load()
        if let book = model.books.first(where: { $0.id == id }) { await model.open(book) }
        else if let book = model.epubBooks.first(where: { $0.id == id }) { await model.openEPUB(book) }
        else if let book = model.docx.books.first(where: { $0.id == id }) { await model.openDOCX(book) }
        else if let book = model.comicBooks.first(where: { $0.id == id }) { await model.openComic(book) }
        else if let book = model.textFormats.books.first(where: { $0.id == id }) { await model.openTextFormat(book) }
        else if let book = model.ebook.books.first(where: { $0.id == id }) { await model.openEbook(book) }
        guard model.displayedDocumentID == id, model.error == nil else { error = model.error ?? "文件已不可用，请刷新书库。"; return false }
        adopt(model); return true
    }
    func openNew(_ operation: @MainActor (LibraryModel) async -> Void) async -> Bool {
        guard !opening, !catalogue.storageMaintenance else { return false }
        opening = true; defer { opening = false }
        let model = makeDocumentModel()
        await model.load(); await operation(model)
        guard model.error == nil, model.displayedDocumentID != nil else { error = model.error; return false }
        adopt(model)
        if model !== catalogue { await catalogue.load() }
        return true
    }
    func requestClose(_ id: UUID) async {
        guard let tab = tabs.first(where: { $0.id == id }), !opening else { return }
        if tab.model.hasDocumentWorkToReview { pendingCloseID = id }
        else { await close(id, confirmed: false) }
    }
    func close(_ id: UUID, confirmed: Bool) async {
        guard let index = tabs.firstIndex(where: { $0.id == id }), !opening else { return }
        let model = tabs[index].model
        guard !model.isBusy, !model.storageMaintenance, !model.hasDocumentSaveInFlight else {
            error = "文件正在写入或重载。请等操作完成再关闭标签。"; return
        }
        guard confirmed || !model.hasDocumentWorkToReview else { pendingCloseID = id; return }
        opening = true; defer { opening = false }
        if confirmed {
            for draft in model.noteEditing.drafts.values where draft.baseline.bookID == id { model.noteEditing.cancel(draft.baseline) }
            for draft in model.recordEditing.editor.drafts.values where draft.baseline.bookID == id { model.recordEditing.editor.cancel(draft.baseline) }
            guard !model.hasDocumentEditorChanges else { error = "草稿取消未完成，文件保持打开。请载入最新笔记后核对。"; return }
        }
        model.cancelDocumentTasks()
        await model.saveProgress()
        guard model.error == nil else { error = model.error; return }
        for owner in model.documentVisibleDrafts { model.recordVisibleDraft(owner: owner, dirty: false) }
        model.reader.close(); model.epub.close(); model.comic.close()
        model.docx.deactivate(); model.textFormats.deactivate(); model.ebook.deactivate()
        tabs.remove(at: index)
        if activeID == id { activeID = tabs.isEmpty ? nil : tabs[min(index, tabs.count - 1)].id }
        pendingCloseID = nil
    }
}

extension LibraryModel {
    var displayedDocumentID: UUID? {
        if ebook.isActive { return ebook.reader.book?.id }
        if textFormats.isActive { return textFormats.reader.book?.id }
        if docx.isActive { return docx.reader.book?.id }
        if readingComic { return comic.book?.id }
        if readingEPUB { return epub.book?.id }
        return reader.book?.id
    }
    var displayedDocumentTitle: String {
        if ebook.isActive { return ebook.reader.book?.title ?? "电子书" }
        if textFormats.isActive { return textFormats.reader.book?.title ?? "文本" }
        if docx.isActive { return docx.reader.book?.title ?? "Word" }
        if readingComic { return comic.book?.title ?? "漫画" }
        if readingEPUB { return epub.book?.title ?? "EPUB" }
        return reader.book?.title ?? "PDFno"
    }
    var hasDocumentSaveInFlight: Bool {
        learning.saving || byok.saving || japaneseLearning.saving || englishLearning.saving ||
        !noteEditing.saving.isEmpty || !recordEditing.editor.saving.isEmpty
    }
    var hasDocumentEditorChanges: Bool {
        noteEditing.journalError != nil || recordEditing.editor.journalError != nil ||
        noteEditing.drafts.values.contains { $0.baseline.bookID == displayedDocumentID && $0.text != $0.baseline.userText } ||
        recordEditing.editor.drafts.values.contains { $0.baseline.bookID == displayedDocumentID && $0.text != $0.baseline.userText }
    }
    var hasDocumentRunningTasks: Bool {
        learning.busy || byok.busy || pageTranslation.busy || chapterTranslation.busy || japaneseLearning.busy || englishLearning.busy
    }
    var hasDocumentWorkToReview: Bool {
        hasDocumentEditorChanges || !documentVisibleDrafts.isEmpty || hasDocumentRunningTasks || hasDocumentSaveInFlight ||
        !learning.userText.isEmpty || !byokUserText.isEmpty || !englishLearning.userText.isEmpty || !japaneseLearning.userText.isEmpty ||
        learning.result.map { result in !learning.notes.contains { $0.result.requestID == result.requestID } } == true ||
        byok.result.map { result in !learning.notes.contains { $0.result.requestID == result.requestID } } == true ||
        pageTranslation.segments.contains { !$0.userText.isEmpty || $0.result != nil } ||
        chapterTranslation.segments.contains { !$0.userText.isEmpty || $0.result != nil } ||
        (englishLearning.review != nil && !englishLearning.saved) || (japaneseLearning.review != nil && !japaneseLearning.saved)
    }
    func cancelDocumentTasks() {
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        englishLearning.cancel(); japaneseLearning.cancel(); invalidateBYOKSelection()
    }
}
#endif
