// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import PDFnoDomain
import PDFnoServices

extension LibraryModel {
    func makeJapaneseLearningModel() -> JapaneseLearningModel {
        JapaneseLearningModel(provider: UnavailableJapaneseLearningProvider(), sourceIsCurrent: { [weak self] source, config in
            self?.isCurrentJapaneseScope(source, config: config) == true
        }, saveReviewedNote: { [weak self] note in
            guard let self, !storageMaintenance else { throw AIFailure.stale }
            let operation = try storeWriteGate.beginWrite()
            defer { operation.finish() }
            guard await validateJapaneseSourceForSave(note.review.source, config: note.review.provider) else { throw AIFailure.stale }
            try await japaneseRepository.saveNote(note)
            japaneseNotes = try await japaneseRepository.load().notes
        })
    }
    func isCurrentJapaneseScope(_ source: AISourceSnapshot, config: AIProviderConfig) -> Bool {
        guard isCurrentAISource(source), !epub.busy,
              case .pdf = source.anchor else {
            guard isCurrentAISource(source), !epub.busy, case .epub = source.anchor else { return false }
            return sameJapaneseConfiguration(config)
        }
        return sameJapaneseConfiguration(config)
    }
    private func sameJapaneseConfiguration(_ config: AIProviderConfig) -> Bool {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(config)) == (try? encoder.encode(learning.config))
    }
    func prepareJapaneseLearning() {
        guard let source = captureAISource() else { japaneseLearning.prepare(nil); return }
        let request = JapaneseLearningRequest(source: source, provider: learning.config)
        do {
            let provider = try learning.japaneseLearningProvider()
            if japaneseLearning.confirmationScope == (try JapaneseLearningCoordinator.fingerprint(request)), japaneseLearning.request != nil {
                japaneseLearning.prepare(request) // Retain same-scope completed result/draft on reopen.
            } else { japaneseLearning.prepare(request, provider: provider) }
        } catch {
            let failure = AIJobCoordinator.safeError(error)
            japaneseLearning.prepare(request, provider: UnavailableJapaneseLearningProvider(mode: learning.config.mode, failure: failure), failure: failure)
        }
    }
    func invalidateJapaneseLearning() { japaneseLearning.prepare(nil) }
    func japaneseSelectionDidChange(_ anchor: AISelectionAnchor?) {
        // Nil can be focus moving into a sheet; retain the immutable source. Real replacement,
        // session/version/reflow changes are independently fenced and cancelled.
        guard let anchor, let previous = japaneseLearning.request?.source else { return }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        if (try? encoder.encode(anchor)) != (try? encoder.encode(previous.anchor)) { invalidateJapaneseLearning() }
    }
    func validateJapaneseSourceForSave(_ source: AISourceSnapshot, config: AIProviderConfig) async -> Bool {
        guard isCurrentJapaneseScope(source, config: config) else { return false }
        if case .epub(let anchor) = source.anchor {
            guard await epub.validateChapterAnchor(anchor) else { return false }
        }
        return isCurrentJapaneseScope(source, config: config)
    }
    /// Saved records may outlive the reader session/config; original edition/hash/extraction and
    /// native exact quote/geometry/resource validation remain mandatory on every return.
    func returnToJapaneseSource(_ source: AISourceSnapshot) async -> Bool {
        guard source.isValid else { japaneseLearning.presentFailure(.stale); return false }
        switch source.anchor { case .pdf, .epub: break; default: japaneseLearning.presentFailure(.stale); return false }
        japaneseLearning.cancel()
        let returned = await returnToAISource(source)
        if !returned { japaneseLearning.presentFailure(.stale) }
        return returned
    }
    func loadJapaneseLearningNotes() async {
        do { japaneseNotes = try await japaneseRepository.load().notes; japaneseStoreError = nil }
        catch { japaneseStoreError = AIFailure.store.localizedDescription }
    }
}
#endif
