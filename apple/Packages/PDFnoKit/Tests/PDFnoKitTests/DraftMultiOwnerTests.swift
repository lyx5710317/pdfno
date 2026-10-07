// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

private func multiDraftRoot() -> URL {
    FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Draft-Multi-Owner-" + UUID().uuidString)
}
private func multiDraftNote() -> NoteBodySnapshot {
    let book = BookRecord(title: "Original fixture", fileSHA256: String(repeating: "a", count: 64), originalFilename: "Original.pdf", pageCount: 1)
    let anchor = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: "Original",
        regions: [PageRegion(pageIndex: 0, x: 1, y: 2, width: 3, height: 4, quote: "Original")])
    return .pdf(ReadingNote(bookID: book.id, anchor: anchor, userText: "Original body"))
}
private func multiDraftRecord() -> RecordBodySnapshot {
    let anchor = TextFormatAnchor(editionID: UUID(), fileSHA256: String(repeating: "b", count: 64), blockID: 0,
        start: 0, end: 8, quote: "Original", prefix: "", suffix: "")
    return .text(TextFormatNote(bookID: UUID(), anchor: anchor, userText: "Original record body"))
}
private func multiDraftSaved(_ snapshot: NoteBodySnapshot, _ text: String) -> NoteBodySnapshot {
    guard case .pdf(var note) = snapshot else { return snapshot }
    note.userText = text; note.revision += 1; return .pdf(note)
}
@MainActor private final class MultiDraftSave {
    var captured: (NoteBodySnapshot, String)?
    var pending: CheckedContinuation<NoteBodySnapshot, Error>?
    func save(_ snapshot: NoteBodySnapshot, _ text: String) async throws -> NoteBodySnapshot {
        captured = (snapshot, text)
        return try await withCheckedThrowingContinuation { pending = $0 }
    }
    func finish() { if let captured { pending?.resume(returning: multiDraftSaved(captured.0, captured.1)) }; pending = nil }
}

struct DraftMultiOwnerTests {
    @Test func oldBatchSnapshotsMergeOwnChangesWithoutErasingOrResurrectingForeignKeys() throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let a = NoteEditDraftJournal(root: root), b = NoteEditDraftJournal(root: root)
        let first = multiDraftNote(), second = multiDraftNote()
        #expect(try a.load().isEmpty && b.load().isEmpty)
        let draftA = NoteEditDraft(baseline: first, text: "Unsaved A 日本語"), draftB = NoteEditDraft(baseline: second, text: "Unsaved B cafe\u{301}")
        try a.save([draftA]); try b.save([draftB])
        #expect(Set(try NoteEditDraftJournal(root: root).load().map(\.baseline.key)) == Set([first.key, second.key]))
        let c = NoteEditDraftJournal(root: root), d = NoteEditDraftJournal(root: root)
        _ = try c.load(); _ = try d.load()
        try c.save([draftB])
        let changedB = NoteEditDraft(baseline: second, text: "B updated after A removal")
        try d.save([draftA, changedB])
        let state = try NoteEditDraftJournal(root: root).load()
        #expect(state.count == 1 && state.first?.baseline.key == second.key && state.first?.text == changedB.text)
        #expect(throws: NoteBodyEditError.conflict) { try d.save([NoteEditDraft(baseline: first, text: "must not resurrect A"), changedB]) }
        #expect(try NoteEditDraftJournal(root: root).load().count == 1)
    }

    @Test func sameKeyUpdatesAndCancelRequireTheOwnersRevisionIncludingExactUnicode() throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let note = multiDraftNote(), seed = NoteEditDraftJournal(root: root)
        try seed.save([NoteEditDraft(baseline: note, text: "cafe\u{301}")])
        let a = NoteEditDraftJournal(root: root), b = NoteEditDraftJournal(root: root)
        _ = try a.load(); _ = try b.load()
        try a.checkpoint(NoteEditDraft(baseline: note, text: "café"), for: note.key)
        #expect(throws: NoteBodyEditError.conflict) { try b.checkpoint(NoteEditDraft(baseline: note, text: "stale B"), for: note.key) }
        #expect(throws: NoteBodyEditError.conflict) { try b.checkpoint(nil, for: note.key) }
        #expect(try NoteEditDraftJournal(root: root).load().first?.text.utf8.elementsEqual("café".utf8) == true)
        try b.reloadBaseline(for: note.key)
        try b.checkpoint(NoteEditDraft(baseline: note, text: "Explicit resolved B"), for: note.key)
        #expect(throws: NoteBodyEditError.conflict) { try a.checkpoint(nil, for: note.key) }
        #expect(try NoteEditDraftJournal(root: root).load().first?.text == "Explicit resolved B")
    }

    @Test func deleteAndRecreateIdenticalDraftDoesNotAuthorizeAnOldCancel() throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let note = multiDraftNote(), draft = NoteEditDraft(baseline: note, text: "Identical recreated draft")
        try NoteEditDraftJournal(root: root).save([draft])
        let old = NoteEditDraftJournal(root: root), current = NoteEditDraftJournal(root: root)
        _ = try old.load(); _ = try current.load()
        try current.checkpoint(nil, for: note.key); try current.checkpoint(draft, for: note.key)
        #expect(throws: NoteBodyEditError.conflict) { try old.checkpoint(nil, for: note.key) }
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(NoteBodySnapshot.draftFilename))) as? [String: Any])
        #expect(object["schemaVersion"] as? Int == 1)
        let row = try #require((object["drafts"] as? [[String: Any]])?.first)
        #expect(Set(row.keys) == Set(["baseline", "text"]) && row["text"] as? String == draft.text)
    }

    @Test func observationalLoadCannotAuthorizeAStaleOverwriteOrCancel() throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let note = multiDraftNote(), initial = NoteEditDraft(baseline: note, text: "Original shared baseline")
        try NoteEditDraftJournal(root: root).save([initial])
        let a = NoteEditDraftJournal(root: root), b = NoteEditDraftJournal(root: root)
        _ = try a.load(); _ = try b.load()
        try a.checkpoint(NoteEditDraft(baseline: note, text: "Original newer owner"), for: note.key)
        #expect(try b.load().first?.text == "Original newer owner")
        #expect(throws: NoteBodyEditError.conflict) { try b.checkpoint(nil, for: note.key) }
        #expect(throws: NoteBodyEditError.conflict) { try b.save([NoteEditDraft(baseline: note, text: "stale snapshot after inspection")]) }
        #expect(try NoteEditDraftJournal(root: root).load().first?.text == "Original newer owner")
    }

    @Test func canonicalFileAliasesAndDifferentJournalsPreserveTheirOwnNamespaces() throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let real = root.appendingPathComponent("real"), alias = root.appendingPathComponent("alias")
        try FileManager.default.createDirectory(at: real, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: real)
        let a = NoteEditDraftJournal(root: real), b = NoteEditDraftJournal(root: alias), alternate = NoteEditDraftJournal(root: real, filename: "original-alternate.json")
        let first = multiDraftNote(), second = multiDraftNote()
        _ = try a.load(); _ = try b.load()
        try a.save([NoteEditDraft(baseline: first, text: "Original real root")]); try b.save([NoteEditDraft(baseline: second, text: "Original alias root")])
        try alternate.save([NoteEditDraft(baseline: first, text: "Original separate filename")])
        let record = multiDraftRecord(), recordJournal = SavedBodyDraftJournal<RecordBodySnapshot>(root: alias)
        try recordJournal.save([RecordEditDraft(baseline: record, text: "Original record namespace")])
        #expect(try NoteEditDraftJournal(root: alias).load().count == 2)
        #expect(try alternate.load().first?.text == "Original separate filename")
        #expect(try recordJournal.load().first?.text == "Original record namespace")
    }

    @Test func mergedLimitsRejectWritesWithoutDamagingOtherOwners() throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let a = NoteEditDraftJournal(root: root), b = NoteEditDraftJournal(root: root)
        _ = try a.load(); _ = try b.load()
        let rows = (0..<100).map { _ in NoteEditDraft(baseline: multiDraftNote(), text: "Original bounded draft") }
        try a.save(rows)
        let path = root.appendingPathComponent(NoteBodySnapshot.draftFilename), before = try Data(contentsOf: path)
        #expect(throws: NoteBodyEditError.draftStore) { try b.save([NoteEditDraft(baseline: multiDraftNote(), text: "101st draft")]) }
        try b.reloadBaseline(for: rows[0].baseline.key)
        #expect(throws: NoteBodyEditError.draftStore) { try b.checkpoint(NoteEditDraft(baseline: rows[0].baseline, text: String(repeating: "a", count: 256_001)), for: rows[0].baseline.key) }
        #expect(try Data(contentsOf: path) == before)
        let other = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: other) }
        let huge = (0..<41).map { _ in NoteEditDraft(baseline: multiDraftNote(), text: String(repeating: "a", count: 256_000)) }
        #expect(throws: NoteBodyEditError.draftStore) { try NoteEditDraftJournal(root: other).save(huge) }
        #expect(!FileManager.default.fileExists(atPath: other.appendingPathComponent(NoteBodySnapshot.draftFilename).path))
    }

    @Test func maintenancePauseRejectsKeyOperationsAndThenReleasesWithoutLosingDrafts() async throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let journal = NoteEditDraftJournal(root: root), note = multiDraftNote()
        try journal.checkpoint(NoteEditDraft(baseline: note, text: "Original held draft"), for: note.key)
        let before = try Data(contentsOf: root.appendingPathComponent(NoteBodySnapshot.draftFilename))
        let gate = LocalStoreWriteGate.shared(root: root), pause = try gate.beginPause()
        try await pause.drain(); try pause.assertReady()
        #expect(throws: LocalStoreWriteGateError.paused) { try journal.checkpoint(nil, for: note.key) }
        #expect(throws: LocalStoreWriteGateError.paused) { try journal.save([]) }
        #expect(try Data(contentsOf: root.appendingPathComponent(NoteBodySnapshot.draftFilename)) == before)
        pause.finish(); try journal.checkpoint(nil, for: note.key)
        #expect(try journal.load().isEmpty && gate.snapshot.activeWrites == 0)
    }

    @Test @MainActor func twoModelsOnlyCheckpointTheirChangedKeyThroughCancelAndRestart() throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let first = multiDraftNote(), second = multiDraftNote()
        let a = NoteEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        a.begin(first); a.setText("Original A initial", for: first)
        let b = NoteEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        a.setText("Original A newer", for: first)
        b.begin(second); b.setText("Original B draft", for: second)
        #expect(try NoteEditDraftJournal(root: root).load().first { $0.baseline.key == first.key }?.text == "Original A newer")
        a.cancel(first); b.setText("Original B after A removal", for: second)
        let restarted = NoteEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        #expect(restarted.drafts[first.key] == nil && restarted.drafts[second.key]?.text == "Original B after A removal")
        b.cancel(second)
        #expect(try NoteEditDraftJournal(root: root).load().isEmpty)
        #expect(b.drafts[first.key]?.text == "Original A initial", "An untouched stale view is not republished to disk")
    }

    @Test @MainActor func sameKeyModelConflictRetainsTextBlocksSaveAndOldCancelUntilExplicitReload() async throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let note = multiDraftNote(), a = NoteEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        a.begin(note); a.setText("Original A shared", for: note)
        var calls = 0
        let b = NoteEditingModel(root: root) { snapshot, text in calls += 1; return multiDraftSaved(snapshot, text) }
        a.setText("Original A latest", for: note); b.setText("Original B retained conflict", for: note)
        #expect(b.conflicts.contains(note.key) && b.journalError?.contains("其他编辑器") == true)
        #expect(await b.save(note) == nil && calls == 0)
        b.cancel(note)
        #expect(b.drafts[note.key]?.text == "Original B retained conflict")
        #expect(try NoteEditDraftJournal(root: root).load().first?.text == "Original A latest")
        b.rebase(note)
        #expect(!b.conflicts.contains(note.key) && b.drafts[note.key]?.text == "Original B retained conflict")
        a.cancel(note)
        #expect(a.drafts[note.key]?.text == "Original A latest")
        #expect(try NoteEditDraftJournal(root: root).load().first?.text == "Original B retained conflict")
    }

    @Test @MainActor func lateSaveRemovalAndCrashReconcileCannotDeleteNewerForeignDraft() async throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let note = multiDraftNote(), gate = MultiDraftSave(), a = NoteEditingModel(root: root, saveBody: gate.save)
        a.begin(note); a.setText("Original A captured", for: note)
        let b = NoteEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        let pending = Task { await a.save(note) }
        for _ in 0..<100 { if gate.pending != nil { break }; await Task.yield() }
        try #require(gate.pending != nil)
        b.setText("Original B newer during save", for: note); gate.finish()
        let saved = try #require(await pending.value)
        #expect(saved.userText == "Original A captured" && !a.saving.contains(note.key))
        #expect(a.drafts[note.key]?.text == "Original A captured" && a.conflicts.contains(note.key))
        #expect(a.feedback[note.key]?.contains("正文已保存到本地") == true)
        #expect(!a.reconcile(saved))
        #expect(try NoteEditDraftJournal(root: root).load().first?.text == "Original B newer during save")
    }

    @Test @MainActor func recordSnapshotOwnersShareTheSameProtectionWithoutMixingNoteJournal() throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let first = multiDraftRecord(), second = multiDraftRecord()
        let a = RecordEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        let b = RecordEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        a.begin(first); a.setText("Original record A", for: first)
        b.begin(second); b.setText("Original record B", for: second)
        #expect(try SavedBodyDraftJournal<RecordBodySnapshot>(root: root).load().count == 2)
        a.cancel(first); b.setText("Original record B newer", for: second)
        #expect(try SavedBodyDraftJournal<RecordBodySnapshot>(root: root).load().first?.text == "Original record B newer")
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(NoteBodySnapshot.draftFilename).path))
    }

    @Test @MainActor func checkpointFailureKeepsLiveTextAndDoesNotBlockAnotherKeysValidUpdate() throws {
        let root = multiDraftRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let first = multiDraftNote(), second = multiDraftNote()
        let a = NoteEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        let b = NoteEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        a.begin(first); a.setText("Original A checkpoint", for: first)
        b.begin(second); b.setText("Original B checkpoint", for: second)
        let overLimit = String(repeating: "a", count: 256_001)
        a.setText(overLimit, for: first)
        #expect(a.journalError != nil && a.drafts[first.key]?.text == overLimit)
        b.setText("Original B valid update", for: second)
        let persisted = try NoteEditDraftJournal(root: root).load()
        #expect(persisted.first { $0.baseline.key == first.key }?.text == "Original A checkpoint")
        #expect(persisted.first { $0.baseline.key == second.key }?.text == "Original B valid update")
        a.setText("Original A explicit retry", for: first)
        #expect(a.journalError == nil && a.drafts[first.key]?.text == "Original A explicit retry")
        #expect(try NoteEditDraftJournal(root: root).load().first { $0.baseline.key == second.key }?.text == "Original B valid update")
    }
}
