// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
#if os(macOS)
import PDFKit
#endif
@testable import PDFnoUI

private func parityRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Record-Parity-" + UUID().uuidString) }
private func parityJapanese() throws -> JapaneseLearningNote {
    let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
    let review = JapaneseLearningValidator.validate(try japaneseData(japanesePayload(request.source.anchor.quote,
        readings: [japaneseReading()], grammar: [japaneseGrammar()])), request: request)
    return try JapaneseLearningNote(review: review, userText: "Original Japanese body", corrections: [JapaneseReadingCorrection(span: review.readings[0].span, reading: "ネコ")])
}
private func parityText(_ root: URL) async throws -> (TextFormatBook, TextFormatNote, Data) {
    let original = Data("Original 😀 cafe\u{301}\n".utf8), repository = TextFormatRepository(root: root)
    let book = try await repository.importBook(original, filename: "Original.txt")
    let document = TextFormatDocument(blocks: [TextFormatBlock(id: 0, runs: [TextFormatRun("Original 😀 cafe\u{301}")], start: 0)])
    try await repository.bindRenderedDocument(document, book: book)
    let note = TextFormatNote(bookID: book.id, anchor: try #require(document.anchor(book: book, start: 0, end: document.text.utf16.count)), userText: "Original text body")
    try await repository.saveNote(note); return (book, note, original)
}
private func parityEbook(_ root: URL, format: EbookFormat = .mobi) async throws -> (EbookBook, EbookNote, Data) {
    let data = try Data(contentsOf: #require(Bundle.module.url(forResource: "study-sample", withExtension: format.rawValue, subdirectory: "Fixtures/Ebooks")))
    let repository = EbookRepository(root: root), book = try await repository.importBook(data, filename: "Original." + format.rawValue)
    let document = EbookDocument(blocks: [EbookBlock(id: 0, runs: [EbookRun("Original 😀 cafe\u{301}")], start: 0, section: 0)])
    try await repository.bindRenderedDocument(document, book: book)
    let note = EbookNote(bookID: book.id, anchor: try #require(document.anchor(book: book, start: 0, end: document.text.utf16.count)), userText: "Original ebook body")
    try await repository.saveNote(note); return (book, note, data)
}
private func wire(_ root: URL, _ name: String) throws -> Data { try Data(contentsOf: root.appendingPathComponent(name)) }
private func sameWire<T: Encodable>(_ a: T, _ b: T) throws -> Bool {
    let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
    return try encoder.encode(a) == encoder.encode(b)
}


#if os(macOS)
private actor RecordParitySearchGate {
    var pending: [String: CheckedContinuation<RecordSearchResponse, Error>] = [:]
    func search(_ query: String) async throws -> RecordSearchResponse {
        try await withCheckedThrowingContinuation { pending[query] = $0 }
    }
    func hasStarted(_ query: String) -> Bool { pending[query] != nil }
    func finish(_ query: String, count: Int) { pending.removeValue(forKey: query)?.resume(returning: RecordSearchResponse(totalCount: count)) }
    func fail(_ query: String) { pending.removeValue(forKey: query)?.resume(throwing: LibrarySearchFailure.store) }
}
#endif

struct RecordParityTests {
    @Test(arguments: TextFileFormat.allCases) func allTextV1NamespacesEditWithoutChangingLocatorOrMigrating(format: TextFileFormat) async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let book = TextFormatBook(fileSHA256: String(repeating: "a", count: 64), title: "Original", originalFilename: "original." + format.rawValue, format: format)
        let quote = "Original 😀", anchor = TextFormatAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, blockID: 0,
            start: 0, end: quote.utf16.count, quote: quote, prefix: "", suffix: "")
        let note = TextFormatNote(bookID: book.id, anchor: anchor, userText: "original")
        var state = TextFormatState(); state.books = [book]; state.notes = [note]
        try JSONEncoder().encode(state).write(to: root.appendingPathComponent("text-formats-v1.json"))
        let updated = try await TextFormatRepository(root: root).updateNoteBody(expected: note, text: "edited cafe\u{301}")
        #expect(updated.anchor == anchor && updated.id == note.id)
        #expect(try await TextFormatRepository(root: root).load().books[0].format == format)
        let hit = try #require(await RecordSearchRepository(root: root).search("CAFÉ").hits.first)
        #expect(hit.entry.target.book.format == .text(format) && hit.entry.quote.utf16.elementsEqual(quote.utf16))
    }
    @Test @MainActor func newJournalRefusesFutureAndNestedUnknownFieldsAndRetainsSessionDraft() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (_, n, _) = try await parityText(root), snapshot = RecordBodySnapshot.text(n)
        let path = root.appendingPathComponent(RecordBodySnapshot.draftFilename)
        let journal = SavedBodyDraftJournal<RecordBodySnapshot>(root: root)
        try journal.save([RecordEditDraft(baseline: snapshot, text: "original draft")])
        let initial = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
        for mode in 0..<2 {
            var object = initial
            if mode == 0 { object["schemaVersion"] = 2 }
            else {
                var rows = try #require(object["drafts"] as? [[String: Any]])
                var baseline = try #require(rows[0]["baseline"] as? [String: Any])
                var payload = try #require(baseline["text"] as? [String: Any])
                var note = try #require(payload["_0"] as? [String: Any]); note["future"] = true
                payload["_0"] = note; baseline["text"] = payload; rows[0]["baseline"] = baseline; object["drafts"] = rows
            }
            let bad = try japaneseData(object); try bad.write(to: path)
            let editor = RecordEditingModel(root: root) { _, _ in throw NoteBodyEditError.conflict }
            #expect(editor.journalError != nil)
            editor.begin(snapshot); editor.setText("session draft", for: snapshot)
            #expect(editor.drafts[snapshot.key]?.text == "session draft" && editor.journalError != nil)
            #expect(try Data(contentsOf: path) == bad)
        }
    }
    @Test func textBodyEditRestartsWithoutRenderedCacheAndPreservesOriginalAnchorAndSchema() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (book, note, original) = try await parityText(root), path = "text-formats-v1.json"
        let before = try wire(root, path), repository = TextFormatRepository(root: root), body = " \n日本語 👩🏽‍🚀 e\u{301} "
        let next = try await repository.updateNoteBody(expected: note, text: body)
        #expect(next.id == note.id && next.bookID == note.bookID && next.anchor == note.anchor && next.userText.utf8.elementsEqual(body.utf8))
        let encoded = try #require(JSONSerialization.jsonObject(with: wire(root, path)) as? [String: Any])
        #expect(encoded["schemaVersion"] as? Int == 1)
        #expect(Set(try #require((encoded["notes"] as? [[String: Any]])?.first).keys) == Set(["id", "bookID", "anchor", "userText"]))
        #expect(try wire(root, path + ".backup") == before)
        let unchangedBytes = try wire(root, path)
        #expect(try await repository.updateNoteBody(expected: next, text: body) == next)
        #expect(try wire(root, path) == unchangedBytes && wire(root, path + ".backup") == before)
        await #expect(throws: NoteBodyEditError.conflict) { try await repository.updateNoteBody(expected: note, text: "stale") }
        let cleared = try await repository.updateNoteBody(expected: next, text: "")
        #expect(try await TextFormatRepository(root: root).load().notes == [cleared] && cleared.userText.isEmpty)
        #expect(try await repository.read(book) == original)
    }
    @Test(arguments: EbookFormat.allCases) func ebookExistingBodyEditPreservesNativeFormatAndResultlessSource(format: EbookFormat) async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (book, note, original) = try await parityEbook(root, format: format), repository = EbookRepository(root: root)
        let body = "日本語 🌸 e\u{301}  ", next = try await repository.updateNoteBody(expected: note, text: body)
        #expect(next.id == note.id && next.bookID == note.bookID && next.anchor == note.anchor && next.anchor.format == format)
        #expect(next.userText.utf8.elementsEqual(body.utf8))
        #expect(try await repository.read(book) == original)
        await #expect(throws: NoteBodyEditError.conflict) { try await repository.updateNoteBody(expected: note, text: "stale") }
        let cleared = try await repository.updateNoteBody(expected: next, text: "")
        #expect(try await EbookRepository(root: root).load().notes == [cleared] && cleared.userText.isEmpty)
    }
    @Test func japaneseBodyOnlyCASAcrossRepositoryInstancesKeepsAllSuggestionsAndCorrections() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let note = try parityJapanese(), repository = JapaneseLearningRepository(root: root)
        try await repository.saveNote(note)
        let next = try await repository.updateNoteBody(expected: note, text: " \nか\u{3099}👩🏽‍🚀 ")
        #expect(next.id == note.id && next.corrections == note.corrections)
        #expect(try sameWire(next.review, note.review))
        await #expect(throws: NoteBodyEditError.conflict) { try await JapaneseLearningRepository(root: root).updateNoteBody(expected: note, text: "stale") }
        let before = try wire(root, JapaneseLearningRepository.filename)
        #expect(try await repository.updateNoteBody(expected: next, text: next.userText) == next)
        #expect(try wire(root, JapaneseLearningRepository.filename) == before)
        let cleared = try await repository.updateNoteBody(expected: next, text: "")
        #expect(try await JapaneseLearningRepository(root: root).load().notes == [cleared] && cleared.corrections == note.corrections)
    }
    @Test func scalarExactCASRejectsCanonicallyEquivalentButDifferentBaseline() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (_, n, _) = try await parityText(root), repository = TextFormatRepository(root: root)
        let stored = try await repository.updateNoteBody(expected: n, text: "e\u{301}")
        let lookalike = TextFormatNote(id: stored.id, bookID: stored.bookID, anchor: stored.anchor, userText: "é")
        #expect(stored == lookalike) // Swift's Equatable alone is insufficient for persisted Unicode.
        await #expect(throws: NoteBodyEditError.conflict) { try await repository.updateNoteBody(expected: lookalike, text: "overwrite") }
        let changed = try await repository.updateNoteBody(expected: stored, text: "é")
        #expect(changed.userText.utf8.elementsEqual("é".utf8))
    }
    @Test func existingBodyLimitsEmptyAndWhitespaceRemainFormatSpecific() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (_, t, _) = try await parityText(root), (_, e, _) = try await parityEbook(root), j = try parityJapanese()
        try await JapaneseLearningRepository(root: root).saveNote(j)
        #expect(RecordBodySnapshot.text(t).accepts(String(repeating: "🌸", count: 4000)))
        #expect(!RecordBodySnapshot.ebook(e).accepts(String(repeating: "🌸", count: 4001)))
        #expect(RecordBodySnapshot.japanese(j).accepts(String(repeating: "🌸", count: 8000)))
        await #expect(throws: NoteBodyEditError.tooLong) { try await TextFormatRepository(root: root).updateNoteBody(expected: t, text: String(repeating: "🌸", count: 4001)) }
        await #expect(throws: NoteBodyEditError.tooLong) { try await EbookRepository(root: root).updateNoteBody(expected: e, text: String(repeating: "🌸", count: 4001)) }
        await #expect(throws: NoteBodyEditError.tooLong) { try await JapaneseLearningRepository(root: root).updateNoteBody(expected: j, text: String(repeating: "🌸", count: 8001)) }
        #expect(try await TextFormatRepository(root: root).updateNoteBody(expected: t, text: " \n ").userText == " \n ")
    }
    @Test func allRecordUpdatesRefuseFutureUnknownOrCorruptStoreWithoutReplacingBytes() async throws {
        for name in ["text-formats-v1.json", "ebook-kookit-v1.json", JapaneseLearningRepository.filename] {
            for corrupt in [Data("{\"schemaVersion\":2,\"books\":[],\"notes\":[]}".utf8), Data("{\"schemaVersion\":1,\"books\":[],\"notes\":[],\"future\":true}".utf8), Data("broken".utf8)] {
                let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
                let (_, t, _) = try await parityText(root), (_, e, _) = try await parityEbook(root), j = try parityJapanese()
                try await JapaneseLearningRepository(root: root).saveNote(j)
                let path = root.appendingPathComponent(name), backup = path.appendingPathExtension("backup"), prior = Data("Original previous data".utf8)
                try corrupt.write(to: path); try prior.write(to: backup)
                do {
                    if name.hasPrefix("text") { _ = try await TextFormatRepository(root: root).updateNoteBody(expected: t, text: "new") }
                    else if name.hasPrefix("ebook") { _ = try await EbookRepository(root: root).updateNoteBody(expected: e, text: "new") }
                    else { _ = try await JapaneseLearningRepository(root: root).updateNoteBody(expected: j, text: "new") }
                    Issue.record("Invalid store must refuse update")
                } catch { }
                #expect(try Data(contentsOf: path) == corrupt && Data(contentsOf: backup) == prior)
            }
        }
    }
    @Test func japaneseLegacyPromptAndOmittedOptionalComponentsRemainEditable() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let note = try parityJapanese(), path = root.appendingPathComponent(JapaneseLearningRepository.filename)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(JapaneseLearningState(notes: [note]))) as? [String: Any])
        var rows = try #require(object["notes"] as? [[String: Any]]), review = try #require(rows[0]["review"] as? [String: Any])
        review["components"] = nil; review["promptVersion"] = JapaneseLearningPolicy.legacyPromptVersion; rows[0]["review"] = review; object["notes"] = rows
        try japaneseData(object).write(to: path)
        let repository = JapaneseLearningRepository(root: root), old = try #require(await repository.load().notes.first)
        let next = try await repository.updateNoteBody(expected: old, text: "legacy user edit")
        #expect(next.review.promptVersion == JapaneseLearningPolicy.legacyPromptVersion && next.review.components.isEmpty)
        #expect(try sameWire(next.review, old.review) && next.corrections == old.corrections)
    }
    @Test @MainActor func separateJournalRestartsAllRecordTypesAndCancelKeepsSavedBodies() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (_, t, _) = try await parityText(root), (_, e, _) = try await parityEbook(root), j = try parityJapanese()
        let legacy = root.appendingPathComponent("note-edit-drafts-v1.json"), sentinel = Data("Original legacy editor journal bytes".utf8)
        try sentinel.write(to: legacy)
        let snapshots: [RecordBodySnapshot] = [.text(t), .ebook(e), .japanese(j)]
        let editor = RecordEditingModel(root: root, filename: "record-edit-drafts-v1.json") { _, _ in throw NoteBodyEditError.conflict }
        for n in snapshots { editor.begin(n); editor.setText(" \n草稿 👩🏽‍🚀 e\u{301} " + n.key, for: n) }
        let restarted = RecordEditingModel(root: root, filename: "record-edit-drafts-v1.json") { _, _ in throw NoteBodyEditError.conflict }
        for n in snapshots {
            #expect(restarted.drafts[n.key]?.text.utf8.elementsEqual(editor.drafts[n.key]!.text.utf8) == true)
            restarted.cancel(n); #expect(restarted.drafts[n.key] == nil)
        }
        #expect(try wire(root, "note-edit-drafts-v1.json") == sentinel)
        #expect(try await TextFormatRepository(root: root).load().notes == [t])
    }
    @Test @MainActor func backupFailureRetainsDraftThenManualRetryAndConflictRebasePreservesText() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (_, n, _) = try await parityText(root), repository = TextFormatRepository(root: root), snapshot = RecordBodySnapshot.text(n)
        let editor = RecordEditingModel(root: root, filename: "record-edit-drafts-v1.json") { expected, text in
            guard case .text(let n) = expected else { throw NoteBodyEditError.conflict }
            return .text(try await repository.updateNoteBody(expected: n, text: text))
        }
        editor.begin(snapshot); editor.setText("explicit retry", for: snapshot)
        let backup = root.appendingPathComponent("text-formats-v1.json.backup")
        try FileManager.default.removeItem(at: backup); try FileManager.default.createDirectory(at: backup, withIntermediateDirectories: true)
        let before = try wire(root, "text-formats-v1.json")
        #expect(await editor.save(snapshot) == nil && editor.drafts[snapshot.key]?.text == "explicit retry")
        #expect(try wire(root, "text-formats-v1.json") == before)
        try FileManager.default.removeItem(at: backup)
        let next = try #require(await editor.save(snapshot)); #expect(next.userText == "explicit retry" && editor.drafts[snapshot.key] == nil)
        editor.begin(next); editor.setText("retain on conflict", for: next)
        guard case .text(let current) = next else { Issue.record("unexpected type"); return }
        let changed = try await repository.updateNoteBody(expected: current, text: "external change")
        #expect(await editor.save(next) == nil && editor.conflicts.contains(next.key))
        editor.rebase(.text(changed)); #expect(editor.drafts[next.key]?.text == "retain on conflict")
        #expect(await editor.save(next)?.userText == "retain on conflict")
    }
    @Test @MainActor func canonicalOnlyCommittedBodyChangeReconcilesCrashDraft() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (_, note, _) = try await parityText(root), repository = TextFormatRepository(root: root)
        let baseline = try await repository.updateNoteBody(expected: note, text: "e\u{301}"), snapshot = RecordBodySnapshot.text(baseline)
        let editor = RecordEditingModel(root: root, filename: "record-edit-drafts-v1.json") { _, _ in throw NoteBodyEditError.conflict }
        editor.begin(snapshot); editor.setText("é", for: snapshot)
        let saved = try await repository.updateNoteBody(expected: baseline, text: "é")
        #expect(editor.reconcile(.text(saved)) && editor.drafts[snapshot.key] == nil)
    }
    @Test func searchIncludesOnlyCommittedBodiesAndPreservesQuoteScalarsAndTypedTargets() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (_, t, _) = try await parityText(root), (_, e, _) = try await parityEbook(root), j = try parityJapanese()
        try await JapaneseLearningRepository(root: root).saveNote(j)
        let repository = RecordSearchRepository(root: root)
        for query in ["CAFÉ", "😀", "Original"] {
            let results = try await repository.search(query)
            #expect(results.hits.filter { $0.entry.target.kind == .note }.count == 2)
            #expect(results.hits.filter { $0.entry.target.kind == .note }.allSatisfy { $0.entry.quote.utf16.elementsEqual(t.anchor.quote.utf16) })
        }
        let saved = try await TextFormatRepository(root: root).updateNoteBody(expected: t, text: "fresh committed 日本語")
        #expect(try await repository.search("text body").totalCount == 0)
        let hit = try #require(await repository.search("committed 日本語").hits.first)
        #expect(hit.entry.userText == saved.userText && hit.entry.quote.utf16.elementsEqual(t.anchor.quote.utf16))
        guard case .text(let book, let anchor) = try await repository.resolve(hit.entry.target) else { Issue.record("wrong source namespace"); return }
        #expect(book.id == t.bookID && anchor == t.anchor)
        let wrong = RecordSearchTarget(book: RecordBookIdentity(format: .ebook(.mobi), bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256), kind: .note, noteID: e.id)
        await #expect(throws: LibrarySearchFailure.source) { try await repository.resolve(wrong) }
        #expect(try await repository.search("ネコ").hits.first?.entry.correctionsText == "ネコ")
        let orphan = try #require(await repository.search("猫").hits.first)
        #expect(orphan.entry.target.kind == .japanese && !orphan.entry.sourceAvailable && orphan.entry.quote == j.review.source.anchor.quote)
        await #expect(throws: LibrarySearchFailure.source) { try await repository.resolve(orphan.entry.target) }
        #expect(try await repository.search(" \n ").totalCount == 0)
        await #expect(throws: LibrarySearchFailure.queryLimit) { try await repository.search(String(repeating: "🌸", count: 513)) }
    }
    @Test func recordSearchLimitCountAndCombinedBudgetAreStableWithoutPersistentIndex() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (book, note, _) = try await parityText(root)
        var state = try await TextFormatRepository(root: root).load()
        state.notes = (0..<310).map { _ in TextFormatNote(bookID: book.id, anchor: note.anchor, userText: "sharedmatch") }
        try JSONEncoder().encode(state).write(to: root.appendingPathComponent("text-formats-v1.json"), options: .atomic)
        let repository = RecordSearchRepository(root: root), first = try await repository.search("sharedmatch", limit: 5), second = try await repository.search("sharedmatch", limit: 5)
        #expect(first == second && first.totalCount == 310 && first.hits.count == 5)
        let combined = try await SavedRecordSearchRepository(root: root).search("sharedmatch")
        #expect(combined.totalCount == 310 && combined.records.hits.count + combined.legacy.groups.flatMap(\.hits).count == 300)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("search-index.json").path))
    }
    #if os(macOS)
    @Test @MainActor func combinedControllerFindsLegacyAndNewSavedRecordsWithOneDisplayBudget() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (_, text, _) = try await parityText(root), library = LibraryModel(root: root)
        let book = try await library.repository.importPDF(originalSample(), filename: "Original.pdf", pageCount: 2)
        let anchor = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: "window",
            regions: [PageRegion(pageIndex: 0, x: 72, y: 650, width: 40, height: 16, quote: "window")])
        try await library.repository.saveNote(ReadingNote(bookID: book.id, anchor: anchor, userText: "combinedmarker"))
        _ = try await library.textFormats.repository.updateNoteBody(expected: text, text: "combinedmarker")
        let model = SavedRecordSearchModel(root: root); model.observeChanges(in: library)
        model.updateQuery("combinedmarker"); await model.waitForSearch()
        #expect(model.phase == .results && model.response.totalCount == 2)
        #expect(model.response.legacy.totalCount == 1 && model.response.records.totalCount == 1)
        model.updateQuery(""); await model.waitForSearch()
        #expect(model.phase == .idle && model.response.totalCount == 0 && model.response.legacy.books.contains { $0.identity.bookID == book.id })
        model.stopObservingChanges()
    }
    @Test @MainActor func recordSearchIgnoresLateSuccessFailureAndExplicitCancellation() async throws {
        let gate = RecordParitySearchGate(), model = RecordSearchModel(search: { try await gate.search($0) })
        func waitStarted(_ query: String) async throws {
            for _ in 0..<200 {
                if await gate.hasStarted(query) { return }
                try await Task.sleep(for: .milliseconds(10))
            }
            Issue.record("Backend did not start")
        }
        model.updateQuery("old"); try await waitStarted("old")
        model.updateQuery("fresh"); try await waitStarted("fresh")
        await gate.finish("fresh", count: 2); await model.waitForSearch()
        await gate.fail("old"); await Task.yield()
        #expect(model.phase == .results && model.response.totalCount == 2 && model.error == nil)
        model.updateQuery("cancel"); try await waitStarted("cancel"); model.cancel()
        await gate.finish("cancel", count: 99); await Task.yield()
        #expect(model.phase == .cancelled && model.response.hits.isEmpty && model.response.totalCount == 0)
        model.updateQuery("empty"); try await waitStarted("empty"); model.updateQuery("")
        await gate.finish("empty", count: 99); await Task.yield()
        #expect(model.phase == .idle && model.response.totalCount == 0)
        model.updateQuery("failure"); try await waitStarted("failure"); await gate.fail("failure"); await model.waitForSearch()
        #expect(model.phase == .failed && model.response.totalCount == 0 && model.error != nil)
    }
    @Test @MainActor func adapterPublishesSavedBodiesAndSearchRefreshesWithoutReaderReplacementOrDraftIndexing() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let (_, t, _) = try await parityText(root), (_, e, _) = try await parityEbook(root), j = try parityJapanese()
        try await JapaneseLearningRepository(root: root).saveNote(j)
        let library = LibraryModel(root: root), adapter = await library.makeRecordEditingAdapter()
        try await library.textFormats.load(); try await library.ebook.load(); await library.loadJapaneseLearningNotes()
        let textSession = library.textFormats.reader.readerSessionID, ebookSession = library.ebook.reader.readerSessionID
        let search = RecordSearchModel(root: root); search.observeChanges(in: library); search.updateQuery("new savedmarker"); await search.waitForSearch()
        #expect(search.response.totalCount == 0)
        for n in [RecordBodySnapshot.text(t), .ebook(e), .japanese(j)] {
            adapter.editor.begin(n); adapter.editor.setText("new savedmarker", for: n)
            search.refresh(); await search.waitForSearch() // drafts must not match.
            await adapter.save(n)
        }
        await search.waitForSearch()
        #expect(search.response.totalCount == 3 && library.textFormats.notes[0].userText == "new savedmarker" && library.ebook.notes[0].userText == "new savedmarker" && library.japaneseNotes[0].userText == "new savedmarker")
        #expect(library.textFormats.reader.readerSessionID == textSession && library.ebook.reader.readerSessionID == ebookSession)
        #expect(!library.textFormats.isActive && !library.ebook.isActive)
        search.stopObservingChanges()
    }
    @Test @MainActor func savedJapaneseSearchReturnsThroughExactPDFFixtureSourceAfterBodyEdit() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root), bytes = try originalSample()
        let book = try await library.repository.importPDF(bytes, filename: "Original.pdf", pageCount: 2)
        let document = try #require(PDFDocument(data: bytes)), page = try #require(document.page(at: 1)), bounds = page.bounds(for: .mediaBox)
        let quote = try #require(page.selection(for: bounds)?.string)
        let anchor = PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: quote,
            regions: [PageRegion(pageIndex: 1, x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height, quote: quote)])
        let source = AISourceSnapshot(bookID: book.id, readerSessionID: UUID(), documentVersion: 0, anchor: .pdf(anchor))
        let request = JapaneseLearningRequest(source: source, provider: japaneseConfig())
        let review = JapaneseLearningValidator.validate(try japaneseData(japanesePayload(quote)), request: request)
        let note = try JapaneseLearningNote(review: review, userText: "route marker", corrections: [])
        try await library.japaneseRepository.saveNote(note)
        let edited = try await library.japaneseRepository.updateNoteBody(expected: note, text: "edited route marker")
        let target = try #require(await RecordSearchRepository(root: root).search("edited route marker").hits.first?.entry.target)
        #expect(await library.openRecordSearchTarget(target))
        #expect(library.reader.book?.id == book.id && library.reader.pageIndex == 1)
        #expect(try await library.repository.readAsset(for: book) == bytes)
        #expect(try await library.japaneseRepository.load().notes == [edited])
        let wrong = RecordSearchTarget(book: RecordBookIdentity(format: .epub, bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256), kind: .japanese, noteID: note.id)
        let session = library.reader.readerSessionID
        #expect(await library.openRecordSearchTarget(wrong) == false)
        #expect(library.reader.readerSessionID == session && library.reader.book?.id == book.id)
    }
    @Test @MainActor func invalidRecordSearchTargetFailsWithoutChangingAnyReaderSession() async throws {
        let root = parityRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root), session = library.reader.readerSessionID, textSession = library.textFormats.reader.readerSessionID
        let target = RecordSearchTarget(book: RecordBookIdentity(format: .text(.txt), bookID: UUID(), editionID: UUID(), fileSHA256: String(repeating: "a", count: 64)), kind: .note, noteID: UUID())
        #expect(await library.openRecordSearchTarget(target) == false)
        #expect(library.reader.readerSessionID == session && library.textFormats.reader.readerSessionID == textSession && !library.textFormats.isActive)
    }
    #endif
}
