// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFnoDomain
import PDFnoServices

extension LibraryModel {
    func paragraphSelectionDidChange(_ anchor: AISelectionAnchor?) {
        guard let anchor, let source = learning.source, learning.kind == .explain else { return }
        if !ReadingSkillIdentity.matches(anchor, source.anchor) { learning.invalidateParagraphSource() }
    }
    func isCurrentParagraphSource(_ source: AISourceSnapshot) -> Bool {
        guard isCurrentAISource(source) else { return false }
        return !(learning.paragraphSourceIsStale && learning.source.map { ReadingSkillIdentity.matches($0, source) } == true)
    }
    /// Saved notes outlive the generating session. Navigation still requires the same
    /// original edition/hash and native quote/geometry or DOM anchor validation.
    func canReturnToSavedParagraphSource(_ source: AISourceSnapshot) -> Bool {
        guard !storageMaintenance, !readingComic, !docx.isActive, !textFormats.isActive, !ebook.isActive, source.isValid else { return false }
        switch source.anchor {
        case .pdf(let anchor): return !readingEPUB && source.bookID == reader.book?.id && reader.resolution(of: anchor) == .exact
        case .epub(let anchor): return readingEPUB && !epub.busy && source.bookID == epub.book?.id && epub.book?.accepts(anchor) == true
        default: return false
        }
    }
    func validateParagraphSourceForSave(_ source: AISourceSnapshot) async -> Bool {
        guard !storageMaintenance, isCurrentParagraphSource(source), !epub.busy else { return false }
        if case .epub(let anchor) = source.anchor, !(await epub.validateChapterAnchor(anchor)) { return false }
        return !storageMaintenance && isCurrentParagraphSource(source) && !epub.busy
    }
    func makeParagraphCommitFence(_ source: AISourceSnapshot) throws -> EnglishLearningSourceCommitFence {
        guard isCurrentParagraphSource(source) else { throw AIFailure.stale }
        return try EnglishLearningSourceCommitFence(root: recordRoot, source: source)
    }
}
#endif
