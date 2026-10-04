// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoReaders
@testable import PDFnoUI

@MainActor private final class DeferredNoteBodySave {
    var continuation: CheckedContinuation<NoteBodySnapshot, Error>?
    var captured: (NoteBodySnapshot, String)?
    func save(_ note: NoteBodySnapshot, _ text: String) async throws -> NoteBodySnapshot {
        captured = (note, text)
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func finish(_ note: NoteBodySnapshot) { continuation?.resume(returning: note); continuation = nil }
}

struct NoteEditingTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Note-Editing-" + UUID().uuidString) }
    private func pdfNote(book: BookRecord, text: String = "Original body") -> ReadingNote {
        ReadingNote(bookID: book.id, anchor: PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256,
            quote: "window", regions: [PageRegion(pageIndex: 0, x: 72, y: 650, width: 40, height: 16, quote: "window")]), userText: text)
    }
    private func learningNote(epub: Bool = false, page: Bool = false) -> AILearningNote {
        let quote = "Original 日本語🌸 cafe\u{301}", hash = String(repeating: "a", count: 64), edition = UUID()
        let anchor: AISelectionAnchor
        if epub {
            anchor = .epub(EPUBAnchor(editionID: edition, fileSHA256: hash, resourceHref: "OEBPS/chapter.xhtml", spineIndex: 0,
                start: 0, end: quote.utf16.count, quote: quote, prefix: "", suffix: "", vertical: false))
        } else if page {
            let snapshot = PDFPageTextSnapshot(bookID: UUID(), readerSessionID: UUID(), editionID: edition,
                fileSHA256: hash, pageIndex: 0, text: quote)
            anchor = .pdfPage(PDFPageTextAnchor(snapshot: snapshot, start: 0, end: quote.utf16.count, quote: quote))
        } else {
            anchor = .pdf(PDFSourceAnchor(editionID: edition, fileSHA256: hash, quote: quote,
                regions: [PageRegion(pageIndex: 0, x: 1, y: 2, width: 3, height: 4, quote: quote)]))
        }
        var config = AIProviderConfig(); config.mode = .mock; config.label = "Original local fixture"; config.model = "mock"
        if page { config = DeepSeekSelectionPolicy.configuration() } // Data only; no transport or credential.
        let source = AISourceSnapshot(bookID: UUID(), readerSessionID: UUID(), documentVersion: 0, anchor: anchor)
        let request = AIRequest(source: source, provider: config, kind: .translate)
        return AILearningNote(result: AIResult(request: request, text: "Original offline result", fromCache: false), userText: "Original body")
    }
    private func jsonNote(_ root: URL, _ manifest: String) throws -> [String: Any] {
        let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(manifest))) as? [String: Any])
        #expect(object["schemaVersion"] as? Int == 1)
        return try #require((object["notes"] as? [[String: Any]])?.first)
    }

    @Test func PDFBodySaveEmptyNoOpRestartRevisionAndOriginals() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LibraryRepository(root: root), original = try originalSample()
        let book = try await repository.importPDF(original, filename: "Original.pdf", pageCount: 2)
        let note = pdfNote(book: book); try await repository.saveNote(note)
        let before = try jsonNote(root, "library-v1.json")
        let text = "  Original revised 日本語🌸 cafe\u{301}\n"
        let next = try await repository.updateNoteBody(expected: note, text: text)
        #expect(next.anchor == note.anchor && next.id == note.id && next.bookID == note.bookID && next.createdAt == note.createdAt)
        #expect(next.revision == note.revision + 1 && next.userText.utf8.elementsEqual(text.utf8))
        let after = try jsonNote(root, "library-v1.json")
        #expect(Set(before.keys) == Set(after.keys))
        #expect(NSDictionary(dictionary: try #require(before["anchor"] as? [String: Any])) == NSDictionary(dictionary: try #require(after["anchor"] as? [String: Any])))
        await #expect(throws: NoteBodyEditError.self) { try await repository.updateNoteBody(expected: note, text: "stale overwrite") }
        let unchanged = try await repository.updateNoteBody(expected: next, text: text)
        #expect(unchanged == next)
        let cleared = try await repository.updateNoteBody(expected: next, text: "")
        let restarted = try await LibraryRepository(root: root).load()
        #expect(restarted.notes == [cleared] && cleared.userText.isEmpty && cleared.anchor == note.anchor)
        #expect(try await repository.readAsset(for: book) == original)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("library-v1.json.backup").path))
    }
    @Test func EPUBLegacySchemaBodyCASUnicodeBlankAndSourceArePreserved() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = EPUBRepository(root: root)
        let data = try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: "epub", subdirectory: "Fixtures")))
        let book = try await repository.importBook(data, filename: "Original.epub")
        let anchor = EPUBAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, resourceHref: "OEBPS/chapter.xhtml", spineIndex: 0,
            start: 0, end: 6, quote: "window", prefix: "", suffix: "", vertical: false)
        let note = EPUBNote(bookID: book.id, anchor: anchor, userText: "Original body"); try await repository.saveNote(note)
        #expect(Set(try jsonNote(root, "epub-v1.json").keys) == Set(["id", "bookID", "anchor", "userText"]))
        let body = "日本語 🌸 e\u{301}\n ", next = try await repository.updateNoteBody(expected: note, text: body)
        #expect(next.userText.utf8.elementsEqual(body.utf8) && next.anchor == anchor && next.id == note.id)
        await #expect(throws: NoteBodyEditError.self) { try await repository.updateNoteBody(expected: note, text: "stale") }
        let cleared = try await repository.updateNoteBody(expected: next, text: "")
        #expect(try await EPUBRepository(root: root).load().notes == [cleared])
        #expect(Set(try jsonNote(root, "epub-v1.json").keys) == Set(["id", "bookID", "anchor", "userText"]))
        #expect(try await repository.read(book) == data)
    }
    @Test func LearningPDFEPUBAndPageEditOnlyBodyWithoutSchemaChangeOrRegeneration() async throws {
        for mode in 0..<3 {
            let root = root(); defer { try? FileManager.default.removeItem(at: root) }
            let repository = AILearningRepository(root: root), note = learningNote(epub: mode == 1, page: mode == 2)
            try await repository.saveNote(note)
            let before = try jsonNote(root, "learning-v1.json")
            let next = try await repository.updateNoteBody(expected: note, text: "  Original new body 日本語🌸\n")
            #expect(next.result == note.result && next.id == note.id)
            let after = try jsonNote(root, "learning-v1.json")
            #expect(Set(before.keys) == Set(after.keys) && Set(after.keys) == Set(["id", "result", "userText"]))
            #expect(NSDictionary(dictionary: try #require(before["result"] as? [String: Any])) == NSDictionary(dictionary: try #require(after["result"] as? [String: Any])))
            await #expect(throws: NoteBodyEditError.self) { try await repository.updateNoteBody(expected: note, text: "stale") }
            let cleared = try await repository.updateNoteBody(expected: next, text: "")
            #expect(try await AILearningRepository(root: root).load().notes == [cleared])
        }
    }
    @Test func ExistingBodyLimitsRejectWithoutChangingStoredBytes() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let pdf = LibraryRepository(root: root), epub = EPUBRepository(root: root), ai = AILearningRepository(root: root)
        let book = try await pdf.importPDF(originalSample(), filename: "Original.pdf", pageCount: 2)
        let note = pdfNote(book: book); try await pdf.saveNote(note)
        let aiNote = learningNote(); try await ai.saveNote(aiNote)
        let pdfBytes = try Data(contentsOf: root.appendingPathComponent("library-v1.json")), aiBytes = try Data(contentsOf: root.appendingPathComponent("learning-v1.json"))
        await #expect(throws: NoteBodyEditError.self) { try await pdf.updateNoteBody(expected: note, text: String(repeating: "x", count: 50_001)) }
        await #expect(throws: NoteBodyEditError.self) { try await ai.updateNoteBody(expected: aiNote, text: String(repeating: "🌸", count: 8_001)) }
        let epubNote = EPUBNote(bookID: UUID(), anchor: EPUBAnchor(editionID: UUID(), fileSHA256: String(repeating: "a", count: 64), resourceHref: "chapter.xhtml", spineIndex: 0, start: 0, end: 1, quote: "x", prefix: "", suffix: "", vertical: false), userText: "")
        await #expect(throws: NoteBodyEditError.self) { try await epub.updateNoteBody(expected: epubNote, text: String(repeating: "日", count: 5_334)) }
        #expect(try Data(contentsOf: root.appendingPathComponent("library-v1.json")) == pdfBytes)
        #expect(try Data(contentsOf: root.appendingPathComponent("learning-v1.json")) == aiBytes)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("epub-v1.json").path))
    }
    @Test @MainActor func DraftsSurvivePanelBookSwitchAndRestartCancelIsExplicit() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let first = NoteBodySnapshot.learning(learningNote()), second = NoteBodySnapshot.learning(learningNote(epub: true))
        let editor = NoteEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        editor.begin(first); editor.setText("Original draft A 日本語🌸", for: first)
        editor.begin(second); editor.setText("Original draft B", for: second)
        editor.begin(first)
        #expect(editor.drafts[first.key]?.text == "Original draft A 日本語🌸")
        let restarted = NoteEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        #expect(restarted.drafts[first.key]?.text == "Original draft A 日本語🌸" && restarted.drafts[second.key]?.text == "Original draft B")
        restarted.cancel(first)
        #expect(restarted.drafts[first.key] == nil && restarted.drafts[second.key]?.text == "Original draft B")
        #expect(restarted.feedback[first.key]?.contains("已取消") == true)
        #expect(try NoteEditDraftJournal(root: root).load().map(\.baseline.key) == [second.key])
    }
    @Test @MainActor func LateSaveCapturesOriginalBookAndDoesNotClearOtherDraftOrAcceptDuplicateSave() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let gate = DeferredNoteBodySave(), first = NoteBodySnapshot.learning(learningNote()), second = NoteBodySnapshot.learning(learningNote(epub: true))
        let editor = NoteEditingModel(root: root, saveBody: gate.save)
        editor.begin(first); editor.setText("Original captured A", for: first)
        let task = Task { await editor.save(first) }
        for _ in 0..<100 { if gate.continuation != nil { break }; await Task.yield() }
        #expect(gate.captured?.0 == first && gate.captured?.1 == "Original captured A")
        #expect(editor.saving.contains(first.key))
        editor.cancel(first); editor.setText("late keyboard overwrite", for: first)
        #expect(editor.drafts[first.key]?.text == "Original captured A")
        #expect(await editor.save(first) == nil)
        editor.begin(second); editor.setText("Original B remains", for: second)
        let original = try #require({ if case .learning(let n) = first { return n }; return nil }())
        let saved = NoteBodySnapshot.learning(AILearningNote(id: original.id, result: original.result, userText: "Original captured A"))
        gate.finish(saved)
        #expect(await task.value == saved)
        #expect(editor.drafts[first.key] == nil && !editor.saving.contains(first.key))
        #expect(editor.drafts[second.key]?.text == "Original B remains")
        #expect(try NoteEditDraftJournal(root: root).load().map(\.baseline.key) == [second.key])
    }
    @Test @MainActor func DiskFailureRetainsBaselineAndDraftAllowsExplicitRetry() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LibraryRepository(root: root)
        let book = try await repository.importPDF(originalSample(), filename: "Original.pdf", pageCount: 2)
        let note = pdfNote(book: book); try await repository.saveNote(note)
        let baseline = NoteBodySnapshot.pdf(note), before = try Data(contentsOf: root.appendingPathComponent("library-v1.json"))
        let backup = root.appendingPathComponent("library-v1.json.backup")
        try FileManager.default.removeItem(at: backup); try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: false)
        let editor = NoteEditingModel(root: root) { expected, text in
            guard case .pdf(let n) = expected else { throw NoteBodyEditError.conflict }
            return .pdf(try await repository.updateNoteBody(expected: n, text: text))
        }
        editor.begin(baseline); editor.setText("Original retained failure draft", for: baseline)
        #expect(await editor.save(baseline) == nil)
        #expect(editor.feedback[baseline.key]?.contains("保存失败") == true && editor.drafts[baseline.key]?.text == "Original retained failure draft")
        #expect(try Data(contentsOf: root.appendingPathComponent("library-v1.json")) == before)
        #expect(try NoteEditDraftJournal(root: root).load().first?.text == "Original retained failure draft")
        try FileManager.default.removeItem(at: backup)
        let saved = try #require(await editor.save(baseline))
        #expect(saved.userText == "Original retained failure draft" && editor.drafts[baseline.key] == nil)
        #expect(try await LibraryRepository(root: root).load().notes.first?.userText == saved.userText)
    }
    @Test @MainActor func MalformedOrFutureDraftJournalIsNeverOverwrittenAndLiveTextRemains() throws {
        for bytes in [Data("{broken".utf8), Data("{\"schemaVersion\":99,\"drafts\":[]}".utf8)] {
            let root = root(); defer { try? FileManager.default.removeItem(at: root) }
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            let url = root.appendingPathComponent("note-edit-drafts-v1.json"); try bytes.write(to: url)
            let editor = NoteEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
            let note = NoteBodySnapshot.learning(learningNote())
            editor.begin(note); editor.setText("Original live draft", for: note)
            #expect(editor.journalError != nil && editor.drafts[note.key]?.text == "Original live draft")
            #expect(try Data(contentsOf: url) == bytes)
        }
    }
    @Test @MainActor func PublishedCollectionsRefreshWithoutReplacingTheActiveReader() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let model = LibraryModel(root: root, aiSession: AppAISession())
        let data = try originalSample(), first = try await model.repository.importPDF(data, filename: "Original.pdf", pageCount: 2)
        // A second original PDF has a distinct digest. PDF trailing comments are legal.
        let secondData = data + Data("\n% Original second fixture\n".utf8)
        let second = try await model.repository.importPDF(secondData, filename: "Other Original.pdf", pageCount: 2)
        let note = pdfNote(book: first); try await model.repository.saveNote(note)
        model.notes = [note]; try model.reader.open(data: secondData, book: second)
        let session = model.reader.readerSessionID
        let baseline = NoteBodySnapshot.pdf(note)
        model.noteEditing.begin(baseline); model.noteEditing.setText("Original published edit", for: baseline)
        await model.saveEditedNote(baseline)
        #expect(model.notes.first?.userText == "Original published edit")
        #expect(model.reader.book?.id == second.id && model.reader.readerSessionID == session)
        #expect(try await model.repository.load().notes.first?.bookID == first.id)
        let aiNote = learningNote(); try await model.learning.repository.saveNote(aiNote); model.learning.notes = [aiNote]
        let aiBaseline = NoteBodySnapshot.learning(aiNote)
        model.noteEditing.begin(aiBaseline); model.noteEditing.setText("Original published AI edit", for: aiBaseline)
        await model.saveEditedNote(aiBaseline)
        #expect(model.learning.notes.first?.userText == "Original published AI edit")
        #expect(model.learning.notes.first?.result == aiNote.result && model.reader.readerSessionID == session)
    }
    @Test @MainActor func ConflictRetainsDraftAndExplicitRebasePreservesLatestSource() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = AILearningRepository(root: root), note = learningNote()
        try await repository.saveNote(note)
        let editor = NoteEditingModel(root: root) { baseline, text in
            guard case .learning(let note) = baseline else { throw NoteBodyEditError.conflict }
            return .learning(try await repository.updateNoteBody(expected: note, text: text))
        }
        let baseline = NoteBodySnapshot.learning(note)
        editor.begin(baseline); editor.setText("Original user draft", for: baseline)
        let other = try await repository.updateNoteBody(expected: note, text: "Original other saved edit")
        #expect(await editor.save(baseline) == nil && editor.conflicts.contains(baseline.key))
        #expect(editor.drafts[baseline.key]?.text == "Original user draft")
        #expect(try await repository.load().notes == [other])
        editor.rebase(.learning(other))
        #expect(editor.drafts[baseline.key]?.text == "Original user draft" && !editor.conflicts.contains(baseline.key))
        let saved = try #require(await editor.save(.learning(other)))
        #expect(saved.userText == "Original user draft")
        #expect(try await repository.load().notes.first?.result == note.result)
    }
    @Test @MainActor func CrashBetweenNoteCommitAndDraftRemovalReconcilesOnlyIdenticalSavedText() throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let note = learningNote(), baseline = NoteBodySnapshot.learning(note)
        try NoteEditDraftJournal(root: root).save([NoteEditDraft(baseline: baseline, text: "Original committed draft")])
        let editor = NoteEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
        let changed = NoteBodySnapshot.learning(AILearningNote(id: note.id, result: note.result, userText: "Original conflicting body"))
        #expect(!editor.reconcile(changed) && editor.drafts[baseline.key]?.text == "Original committed draft")
        let committed = NoteBodySnapshot.learning(AILearningNote(id: note.id, result: note.result, userText: "Original committed draft"))
        #expect(editor.reconcile(committed) && editor.drafts[baseline.key] == nil)
        #expect(try NoteEditDraftJournal(root: root).load().isEmpty)
    }
    @Test func DraftJournalRefusesUnknownNestedFieldsWithoutOverwriting() throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let journal = NoteEditDraftJournal(root: root), baseline = NoteBodySnapshot.learning(learningNote())
        try journal.save([NoteEditDraft(baseline: baseline, text: "Original draft")])
        let url = root.appendingPathComponent("note-edit-drafts-v1.json")
        var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        var rows = try #require(object["drafts"] as? [[String: Any]])
        var snapshot = try #require(rows[0]["baseline"] as? [String: Any])
        snapshot["futureField"] = "Original incompatible fixture"; rows[0]["baseline"] = snapshot; object["drafts"] = rows
        let bytes = try JSONSerialization.data(withJSONObject: object); try bytes.write(to: url)
        #expect(throws: NoteBodyEditError.self) { try journal.save([]) }
        #expect(try Data(contentsOf: url) == bytes)
    }
    @Test func CorruptAndFutureSavedManifestsRefuseBodyWrites() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let repository = LibraryRepository(root: root), ai = AILearningRepository(root: root)
        let book = try await repository.importPDF(originalSample(), filename: "Original.pdf", pageCount: 2)
        let note = pdfNote(book: book); try await repository.saveNote(note)
        let aiNote = learningNote(); try await ai.saveNote(aiNote)
        let data = try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: "epub", subdirectory: "Fixtures")))
        let epub = EPUBRepository(root: root), epubBook = try await epub.importBook(data, filename: "Original.epub")
        let epubNote = EPUBNote(bookID: epubBook.id, anchor: EPUBAnchor(editionID: epubBook.editionID, fileSHA256: epubBook.fileSHA256,
            resourceHref: "OEBPS/chapter.xhtml", spineIndex: 0, start: 0, end: 6, quote: "window", prefix: "", suffix: "", vertical: false), userText: "Original body")
        try await epub.saveNote(epubNote)
        for manifest in ["library-v1.json", "epub-v1.json", "learning-v1.json"] {
            let url = root.appendingPathComponent(manifest), original = try Data(contentsOf: url)
            var future = try #require(JSONSerialization.jsonObject(with: original) as? [String: Any]); future["schemaVersion"] = 99
            for bytes in [Data("{broken".utf8), try JSONSerialization.data(withJSONObject: future)] {
                try bytes.write(to: url)
                do {
                    switch manifest {
                    case "library-v1.json": _ = try await repository.updateNoteBody(expected: note, text: "refused")
                    case "epub-v1.json": _ = try await epub.updateNoteBody(expected: epubNote, text: "refused")
                    default: _ = try await ai.updateNoteBody(expected: aiNote, text: "refused")
                    }
                    Issue.record("Incompatible saved manifest was overwritten")
                } catch { }
                #expect(try Data(contentsOf: url) == bytes)
            }
            try original.write(to: url)
        }
    }

}
