// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFnoDomain
import PDFnoServices

extension LibraryModel {
    func prepareBYOKSelection(kind: AILearningKind = .translate) async {
        guard let source = captureAISource() else {
            invalidateBYOKSelection(); byokSaveStatus = "先在当前PDF或EPUB中选择可靠原文。"; return
        }
        byokSource = source; byokSaveStatus = nil
        await byok.prepareSelection(source, kind: kind)
        if !isCurrentBYOKSource(source) { invalidateBYOKSelection() }
    }
    func invalidateBYOKSelection() { byokSource = nil; byok.invalidate() }
    func byokSelectionDidChange(_ anchor: AISelectionAnchor?) {
        // A temporary loss of native selection while focusing a panel does not
        // change the captured source. A different real selection does.
        guard let anchor, let source = byokSource else { return }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        if (try? encoder.encode(anchor)) != (try? encoder.encode(source.anchor)) { invalidateBYOKSelection() }
    }
    func isCurrentBYOKSource(_ source: AISourceSnapshot) -> Bool {
        guard isCurrentAISource(source), let captured = byokSource else { return false }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(captured)) == (try? encoder.encode(source))
    }
    func saveBYOKResult() async -> Bool {
        guard !byok.saving else { return false }
        byok.saving = true; defer { byok.saving = false }
        guard let operation = try? storeWriteGate.beginWrite() else { return false }
        defer { operation.finish() }
        guard let result = byok.result, ["selection-1", ParagraphExplanationPolicy.promptVersion].contains(result.promptVersion), result.canSaveSelectionResult,
              ReadingSkillIdentity.matches(result.provider, byok.draft), isCurrentBYOKSource(result.source) else {
            byokSaveStatus = AIFailure.stale.localizedDescription; return false
        }
        guard !learning.notes.contains(where: { $0.result.requestID == result.requestID }) else { return true }
        let body = byokUserText
        do {
            var fence: EnglishLearningSourceCommitFence?
            if result.paragraphExplanation != nil {
                guard await validateParagraphSourceForSave(result.source), isCurrentBYOKSource(result.source),
                      byok.result?.requestID == result.requestID, ReadingSkillIdentity.matches(result.provider, byok.draft) else { throw AIFailure.stale }
                fence = try makeParagraphCommitFence(result.source); byok.paragraphCommitFence = fence
            }
            defer { fence?.invalidate(); if byok.paragraphCommitFence === fence { byok.paragraphCommitFence = nil } }
            try await learning.repository.saveNote(AILearningNote(result: result, userText: body), commitFence: fence)
            learning.notes = try await learning.repository.load().notes
            byokSaveStatus = "BYOK学习笔记已保存 · 原结果与用户正文独立保留"; return true
        } catch {
            byokSaveStatus = AIJobCoordinator.safeError(error).localizedDescription; return false
        }
    }
}
#endif
