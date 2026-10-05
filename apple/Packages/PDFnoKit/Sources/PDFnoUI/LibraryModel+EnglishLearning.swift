// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFnoDomain
import PDFnoServices

extension LibraryModel {
    func makeEnglishLearningModel() -> EnglishLearningModel {
        EnglishLearningModel(provider: UnavailableEnglishLearningProvider(), sourceIsCurrent: { [weak self] source, config in
            guard let self, !storageMaintenance else { return false }
            return isCurrentJapaneseScope(source, config: config)
        }, saveReviewedNote: { [weak self] note in
            guard let self, !storageMaintenance else { throw AIFailure.stale }
            let lease = try storeWriteGate.beginWrite()
            defer { lease.finish() }
            // Native source validation occurs only after writer admission. The
            // file transaction additionally checks existence/hash and revocation.
            guard await validateJapaneseSourceForSave(note.review.source, config: note.review.provider) else { throw AIFailure.stale }
            let fence = try EnglishLearningSourceCommitFence(root: recordRoot, source: note.review.source)
            englishCommitFence?.invalidate(); englishCommitFence = fence
            defer { if englishCommitFence === fence { englishCommitFence = nil } }
            try await englishRepository.saveNote(note, commitFence: fence)
            englishNotes = try await englishRepository.load().notes
        })
    }
    func prepareEnglishLearning() {
        guard !storageMaintenance, let source = captureAISource() else { englishLearning.prepare(nil); return }
        let request = EnglishLearningRequest(source: source, provider: learning.config)
        do {
            let provider = try learning.englishLearningProvider()
            if englishLearning.confirmationScope == (try EnglishLearningCoordinator.fingerprint(request)), englishLearning.request != nil {
                englishLearning.prepare(request)
            } else { englishLearning.prepare(request, provider: provider) }
        } catch {
            let failure = AIJobCoordinator.safeError(error)
            englishLearning.prepare(request, provider: UnavailableEnglishLearningProvider(mode: learning.config.mode, failure: failure), failure: failure)
        }
    }
    func invalidateEnglishLearning() {
        englishCommitFence?.invalidate(); englishCommitFence = nil
        englishLearning.prepare(nil)
    }
    func englishSelectionDidChange(_ anchor: AISelectionAnchor?) {
        guard let anchor, let previous = englishLearning.request?.source else { return }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        if (try? encoder.encode(anchor)) != (try? encoder.encode(previous.anchor)) { invalidateEnglishLearning() }
    }
    func returnToEnglishSource(_ source: AISourceSnapshot) async -> Bool {
        guard !storageMaintenance, source.isValid else { englishLearning.presentFailure(.stale); return false }
        switch source.anchor { case .pdf, .epub: break; default: englishLearning.presentFailure(.stale); return false }
        englishLearning.cancel()
        let returned = await returnToAISource(source)
        if !returned { englishLearning.presentFailure(.stale) }
        return returned
    }
    func loadEnglishLearningNotes() async {
        do { englishNotes = try await englishRepository.load().notes; englishStoreError = nil }
        catch { englishStoreError = AIFailure.store.localizedDescription }
    }
}
#endif
