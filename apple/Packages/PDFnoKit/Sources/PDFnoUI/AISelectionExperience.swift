// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import PDFnoDomain
import PDFnoServices

enum SelectionAIRoute: String, Identifiable {
    case conversation, japaneseReview, englishReview
    var id: String { rawValue }
}

extension LibraryModel {
    var canResumeSelectionConversation: Bool {
        guard !storageMaintenance, let source = conversation.current?.source,
              source.bookID == currentAIBookID else { return false }
        return source.readerSessionID == (readingEPUB ? epub.readerSessionID : reader.readerSessionID)
    }
    /// Restores the existing sheet, including disabled tools and unsent drafts.
    /// Viewing an answer does not reopen a task or send a request.
    func resumeSelectionConversation() {
        guard canResumeSelectionConversation else { return }
        selectionAIRoute = .conversation
    }
    func openSelectionAI(_ kind: AILearningKind,anchor: AnnotationAnchor,sessionID: UUID) {
        guard let source = selectionAISource(anchor: anchor,sessionID: sessionID) else { return }
        learning.chooseTask(kind,source: source);selectionAIRoute = .conversation
    }
    func openConversationAI(_ task: ReadingConversationTask,anchor: AnnotationAnchor,sessionID: UUID) {
        guard learning.tools.isEnabled(task), let source = selectionAISource(anchor: anchor,sessionID: sessionID) else { return }
        conversation.open(task,source: source);selectionAIRoute = .conversation
    }
    func openJapaneseReview(anchor: AnnotationAnchor, sessionID: UUID) {
        guard learning.tools.isEnabled(.japanese), let source = selectionAISource(anchor: anchor, sessionID: sessionID) else { return }
        prepareJapaneseLearning(source: source)
        selectionAIRoute = .japaneseReview
    }
    func openEnglishReview(anchor: AnnotationAnchor, sessionID: UUID) {
        guard learning.tools.isEnabled(.english), let source = selectionAISource(anchor: anchor, sessionID: sessionID) else { return }
        prepareEnglishLearning(source: source)
        selectionAIRoute = .englishReview
    }
    /// Hiding a document cancels only its active structured request, retaining drafts and conversations.
    func dismissSelectionAI() {
        switch selectionAIRoute {
        case .japaneseReview: japaneseLearning.cancel()
        case .englishReview: englishLearning.cancel()
        default: break
        }
        selectionAIRoute = nil
    }
    private func selectionAISource(anchor: AnnotationAnchor,sessionID: UUID) -> AISourceSnapshot? {
        guard !storageMaintenance,let bookID=currentAIBookID else { return nil }
        let source: AISourceSnapshot
        switch anchor {
        case .pdf(let value):
            guard !readingEPUB,reader.readerSessionID==sessionID,reader.resolution(of: value) == .exact else { return nil }
            source=AISourceSnapshot(bookID: bookID,readerSessionID: sessionID,documentVersion: 0,anchor: .pdf(value))
        case .epub(let value):
            guard readingEPUB,!epub.busy,epub.readerSessionID==sessionID,epub.book?.accepts(value)==true else { return nil }
            source=AISourceSnapshot(bookID: bookID,readerSessionID: sessionID,documentVersion: epub.documentVersion,anchor: .epub(value))
        default: return nil
        }
        return source
    }
    func addAIResultToNotes() async -> Bool {
        guard !addingAIToNotes,let result=learning.result,result.canSaveSelectionResult,isCurrentAISource(result.source),ReadingSkillIdentity.matches(learning.config,result.provider) else { return false }
        addingAIToNotes=true;defer { addingAIToNotes=false }
        let comment=learning.userText
        do {
            guard await validateParagraphSourceForSave(result.source),learning.result?.requestID==result.requestID,isCurrentAISource(result.source),ReadingSkillIdentity.matches(learning.config,result.provider) else { throw AIFailure.stale }
            let fence=try makeParagraphCommitFence(result.source);defer { fence.invalidate() }
            let saved=try await annotations.repository.addAIResult(result,comment: comment,commitFence: fence)
            learning.didAddToAnnotations(result,comment: saved.userText)
            await annotations.reload()
            if let reader=annotations.reader,reader.bookID==result.source.bookID { await reader.project(annotations.records) }
            learning.status="已添加到当前文档笔记 · AI 结果与批注分别保留";return true
        } catch { learning.error=error.localizedDescription;return false }
    }
}

/// Observe the presentation owner directly. The annotation modifier observes a
/// different model, so a menu action must invalidate this sheet's own host.
struct SelectionAISheetPresenter: View {
    @ObservedObject var library: LibraryModel
    var body: some View {
        Color.clear.frame(width: 0,height: 0).accessibilityHidden(true)
            .sheet(item: $library.selectionAIRoute) { route in
                switch route {
                case .conversation:
                    ReadingSelectionWorkspace(library: library) { library.dismissSelectionAI() }
                        .frame(minWidth: 340,idealWidth: 500,minHeight: 360,idealHeight: 560)
                case .japaneseReview: JapaneseLearningSheet(library: library)
                case .englishReview: EnglishLearningSheet(library: library)
                }
            }
    }
}

/// Uses the same native text control as comments. Generated content is selectable and copyable.
struct AIResultNoteBox: View {
    let result: AIResult
    var identifier="ai-result"
    var body: some View {
        VStack(alignment: .leading,spacing: 8) {
            Label("AI "+result.taskTitle,systemImage: "sparkles").font(.headline)
            NativeNoteBodyInput(text: .constant(result.displayText),identifier: identifier,enabled: false).frame(height: 168)
            Button("复制结果") { NSPasteboard.general.clearContents();NSPasteboard.general.setString(result.displayText,forType: .string) }.accessibilityIdentifier("ai-result-copy")
        }
    }
}
#endif
