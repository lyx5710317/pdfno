// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import PDFnoDomain
import PDFnoServices

extension LibraryModel {
    func openSelectionAI(_ kind: AILearningKind,anchor: AnnotationAnchor,sessionID: UUID) {
        guard !storageMaintenance,let bookID=currentAIBookID else { return }
        let source: AISourceSnapshot
        switch anchor {
        case .pdf(let value):
            guard !readingEPUB,reader.readerSessionID==sessionID,reader.resolution(of: value) == .exact else { return }
            source=AISourceSnapshot(bookID: bookID,readerSessionID: sessionID,documentVersion: 0,anchor: .pdf(value))
        case .epub(let value):
            guard readingEPUB,!epub.busy,epub.readerSessionID==sessionID,epub.book?.accepts(value)==true else { return }
            source=AISourceSnapshot(bookID: bookID,readerSessionID: sessionID,documentVersion: epub.documentVersion,anchor: .epub(value))
        default: return
        }
        learning.chooseTask(kind,source: source);showingSelectionAI=true
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
            .sheet(isPresented: $library.showingSelectionAI) {
                ReadingSelectionWorkspace(library: library) { library.showingSelectionAI=false }
                    .frame(minWidth: 420,idealWidth: 500,minHeight: 540)
            }
    }
}

/// Uses the same native text control as comments. Generated content is selectable and copyable.
struct AIResultNoteBox: View {
    let result: AIResult
    var identifier="ai-result"
    var body: some View {
        VStack(alignment: .leading,spacing: 8) {
            Label("AI "+result.kind.title,systemImage: "sparkles").font(.headline)
            NativeNoteBodyInput(text: .constant(result.displayText),identifier: identifier,enabled: false).frame(height: 168)
            Button("复制结果") { NSPasteboard.general.clearContents();NSPasteboard.general.setString(result.displayText,forType: .string) }.accessibilityIdentifier("ai-result-copy")
        }
    }
}
#endif
