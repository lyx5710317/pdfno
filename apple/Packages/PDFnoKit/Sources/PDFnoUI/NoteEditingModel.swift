// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import SwiftUI
import PDFnoDomain
import PDFnoServices

typealias NoteEditingModel = SavedBodyEditingModel<NoteBodySnapshot>
typealias RecordEditingModel = SavedBodyEditingModel<RecordBodySnapshot>

@MainActor
final class SavedBodyEditingModel<Snapshot: SavedBodySnapshot>: ObservableObject {
    typealias SaveBody = @MainActor (Snapshot, String) async throws -> Snapshot
    @Published private(set) var drafts: [String: SavedBodyDraft<Snapshot>] = [:]
    @Published private(set) var saving: Set<String> = []
    @Published private(set) var feedback: [String: String] = [:]
    @Published private(set) var journalError: String?
    @Published private(set) var conflicts: Set<String> = []
    private let journal: SavedBodyDraftJournal<Snapshot>
    private let saveBody: SaveBody
    private var tokens: [String: UUID] = [:]
    private var maintenanceReview: Set<String> = []
    func invalidatePendingSavesForMaintenance() {
        for key in tokens.keys { tokens[key] = UUID() }
        saving.removeAll()
    }
    func requireReviewAfterMaintenance() {
        maintenanceReview = Set(drafts.keys); conflicts.formUnion(maintenanceReview)
        for key in maintenanceReview { feedback[key] = "书库状态已恢复，请重新载入笔记后核对草稿。" }
    }

    init(root: URL, filename: String? = nil, saveBody: @escaping SaveBody) {
        journal = SavedBodyDraftJournal<Snapshot>(root: root, filename: filename); self.saveBody = saveBody
        do { drafts = Dictionary(uniqueKeysWithValues: try journal.load().map { ($0.baseline.key, $0) }) }
        catch { journalError = NoteBodyEditError.draftStore.localizedDescription }
    }
    func begin(_ note: Snapshot) {
        guard !saving.contains(note.key) else { return }
        if reconcile(note) { return }
        if drafts[note.key] != nil { return } // Retain a real conflict and its baseline.
        drafts[note.key] = SavedBodyDraft<Snapshot>(baseline: note, text: note.userText)
        tokens[note.key] = UUID(); feedback[note.key] = nil; checkpoint()
    }
    @discardableResult
    func reconcile(_ note: Snapshot) -> Bool {
        guard !saving.contains(note.key), let old = drafts[note.key], !sameStoredSnapshot(old.baseline, note),
              old.text.utf8.elementsEqual(note.userText.utf8) else { return false }
        // Recover a crash between the note commit and draft checkpoint removal.
        drafts[note.key] = nil; conflicts.remove(note.key); checkpoint()
        feedback[note.key] = "正文已保存到本地"; return true
    }
    private func sameStoredSnapshot(_ a: Snapshot, _ b: Snapshot) -> Bool {
        // String equality is canonically equivalent; persisted scalars are not.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let first = try? encoder.encode(a), let second = try? encoder.encode(b) else { return false }
        return first == second
    }
    func setText(_ text: String, for note: Snapshot) {
        guard !maintenanceReview.contains(note.key) else { return }
        guard !saving.contains(note.key), var draft = drafts[note.key] else { return }
        draft.text = text; drafts[note.key] = draft; feedback[note.key] = "正文未保存"; checkpoint()
    }
    func cancel(_ note: Snapshot) {
        guard !saving.contains(note.key) else { return }
        maintenanceReview.remove(note.key)
        drafts[note.key] = nil; tokens[note.key] = UUID()
        conflicts.remove(note.key)
        feedback[note.key] = "已取消编辑 · 已保存正文保留"; checkpoint()
    }
    /// Explicit conflict resolution changes the baseline while retaining the
    /// draft text. No automatic merge or overwrite happens on reload.
    func rebase(_ fresh: Snapshot) {
        maintenanceReview.remove(fresh.key)
        guard !saving.contains(fresh.key), let old = drafts[fresh.key] else { return }
        drafts[fresh.key] = SavedBodyDraft<Snapshot>(baseline: fresh, text: old.text)
        conflicts.remove(fresh.key); checkpoint()
        feedback[fresh.key] = "已载入最新笔记 · 草稿正文保留，请核对后保存"
    }
    func reportReloadFailure(_ note: Snapshot) {
        feedback[note.key] = "重新载入失败 · 草稿与已保存正文保留"
    }
    private func checkpoint() {
        do { try journal.save(Array(drafts.values)); journalError = nil }
        catch { journalError = NoteBodyEditError.draftStore.localizedDescription }
    }
    func save(_ note: Snapshot) async -> Snapshot? {
        guard !maintenanceReview.contains(note.key) else { feedback[note.key] = "请先重新载入并核对恢复后的笔记。"; return nil }
        guard !saving.contains(note.key), let draft = drafts[note.key] else { return nil }
        guard draft.baseline.accepts(draft.text) else {
            feedback[note.key] = NoteBodyEditError.tooLong.localizedDescription; return nil
        }
        let token = UUID(); tokens[note.key] = token; saving.insert(note.key)
        feedback[note.key] = "正在保存正文…"
        defer { if tokens[note.key] == token { saving.remove(note.key) } }
        do {
            // Capture the book/note/baseline/text before suspension. A book
            // switch cannot redirect the write or clear another note's draft.
            let saved = try await saveBody(draft.baseline, draft.text)
            guard tokens[note.key] == token, saved.key == note.key else { return nil }
            drafts[note.key] = nil; conflicts.remove(note.key); checkpoint(); feedback[note.key] = "正文已保存到本地"
            return saved
        } catch {
            guard tokens[note.key] == token else { return nil }
            if case NoteBodyEditError.conflict = error { conflicts.insert(note.key) }
            feedback[note.key] = "保存失败 · " + error.localizedDescription + " 草稿保留。"
            return nil
        }
    }
}
