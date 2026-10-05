// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import PDFKit
import Testing
import PDFnoDomain
@testable import PDFnoServices
@testable import PDFnoUI

private actor NextBatchTransport: AIHTTPTransport {
    private(set) var calls = 0
    func send(_ request: URLRequest) throws -> AIHTTPResponse {
        let bytes = try #require(request.httpBody)
        let body = try #require(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let messages = try #require(body["messages"] as? [[String: String]])
        let message = try #require(messages.last?["content"])
        let input = try #require(try JSONSerialization.jsonObject(with: Data(message.utf8)) as? [String: String])
        let quote = try #require(input["sourceText"]); calls += 1
        let payload: Data
        switch input["task"] {
        case "english-selection-learning":
            payload = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "language": "en", "sourceQuote": quote,
                "offsetUnit": "unicode-code-point", "translationZh": "Intercepted English translation marker", "components": [[
                    "id": "s", "role": "subject", "quote": quote, "start": 0, "end": quote.unicodeScalars.count,
                    "prefix": "", "suffix": "", "certainty": "ambiguous", "omitted": false, "inferred": false,
                    "explanationZh": "Intercepted component marker; this synthetic response does not judge grammar."]],
                "grammar": [["id": "g", "aspect": "clause", "quote": quote, "start": 0, "end": quote.unicodeScalars.count,
                    "prefix": "", "suffix": "", "certainty": "ambiguous", "explanationZh": "Intercepted grammar marker"]],
                "warnings": ["Original intercepted fixture, no real language judgment."]])
        case "japanese-selection-learning": payload = try japaneseData(japanesePayload(quote, readings: [], grammar: [japaneseGrammar(quote, start: 0, end: quote.unicodeScalars.count, prefix: "", suffix: "")]))
        default: payload = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "sourceQuote": quote, "text": "Intercepted selection translation"])
        }
        return AIHTTPResponse(status: 200, body: try JSONSerialization.data(withJSONObject: ["choices": [["index": 0, "finish_reason": "stop",
            "message": ["role": "assistant", "tool_calls": NSNull(), "content": String(decoding: payload, as: UTF8.self)]]]]))
    }
}

@Suite(.serialized) @MainActor struct NextBatchHostTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Next-Host-" + UUID().uuidString) }
    private func wait(_ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !(await condition()), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(await condition())
    }
    private func storageBook(_ root: URL) async throws -> BookRecord {
        try await LibraryRepository(root: root).importPDF(Data("%PDF-1.7 original isolated storage fixture".utf8), filename: "Original.pdf", pageCount: 1)
    }
    private func note(_ book: BookRecord) -> ReadingNote {
        ReadingNote(bookID: book.id, anchor: PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256,
            quote: "Original quote", regions: [PageRegion(pageIndex: 0, x: 72, y: 650, width: 90, height: 16, quote: "Original quote")]), userText: "Original body")
    }
    private func selectPDF(_ library: LibraryModel) async throws -> PDFView {
        NSApplication.shared.setActivationPolicy(.prohibited)
        await library.load()
        let fixture = try #require(Bundle.module.url(forResource: "study-sample", withExtension: "pdf", subdirectory: "Fixtures"))
        await library.importFile(fixture)
        let view = PDFView(frame: CGRect(x: 0, y: 0, width: 800, height: 600)); library.reader.attach(view)
        await Task.yield()
        library.reader.search("window"); library.reader.show(try #require(library.reader.searchMatches.first)); library.reader.captureSelection()
        try #require(library.captureAISource()?.anchor.quote == "window")
        return view // Never mounted in a window or activated on the desktop.
    }
    @Test func hostEnglishManualSaveSearchCASRestartAndNativeReturnPreserveOriginals() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let transport = NextBatchTransport(), library = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: transport)
        let view = try await selectPDF(library); defer { view.document = nil }
        #expect(await library.learning.saveConfig(DeepSeekSelectionPolicy.configuration(), temporarySecret: "synthetic-next-host"))
        let book = try #require(library.reader.book), original = try await library.repository.readAsset(for: book)
        library.prepareEnglishLearning(); let model = library.englishLearning
        #expect(model.canStart && model.request?.source.anchor.quote == "window")
        model.start(confirmed: false); #expect(await transport.calls == 0)
        model.start(confirmed: true); try await wait { !model.busy }
        #expect(model.review?.status == .needsReview && library.englishNotes.isEmpty)
        model.userText = "Uncommitted English search marker"
        #expect(try await RecordSearchRepository(root: root).search("Uncommitted English").totalCount == 0)
        #expect(await model.save()); let saved = try #require(library.englishNotes.first)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let resultBytes = try encoder.encode(saved.review)
        for query in ["English search marker", "translation marker", "component marker", "grammar marker", "window"] {
            #expect(try await RecordSearchRepository(root: root).search(query).hits.contains { $0.entry.target.kind == .english && $0.entry.target.noteID == saved.id })
        }
        library.recordEditing.editor.begin(.english(saved)); library.recordEditing.editor.setText("Edited English body 🌸", for: .english(saved))
        await library.recordEditing.save(.english(saved))
        let edited = try #require(library.englishNotes.first)
        #expect(edited.userText == "Edited English body 🌸" && edited.review == saved.review)
        #expect(try encoder.encode(edited.review) == resultBytes)
        await #expect(throws: NoteBodyEditError.conflict) { try await library.englishRepository.updateNoteBody(expected: saved, text: "Stale overwrite") }
        let target = try #require(try await RecordSearchRepository(root: root).search("Edited English").hits.first?.entry.target)
        #expect(await library.openRecordSearchTarget(target))
        #expect(try await library.repository.readAsset(for: book) == original)
        let bytes = try Data(contentsOf: root.appendingPathComponent(EnglishLearningRepository.filename))
        #expect(!String(decoding: bytes, as: UTF8.self).contains("synthetic-next-host"))
        let restarted = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: transport)
        await restarted.load(); #expect(restarted.englishNotes == [edited] && !restarted.learning.hasSessionCredential)
        await restarted.open(book); #expect(await restarted.returnToEnglishSource(saved.review.source))
        #expect(await transport.calls == 1)
    }
    @Test func actualFactoriesShareThreeAttemptsAcrossEnglishJapaneseTranslationAndBYOK() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let app = AppAISession(), transport = NextBatchTransport(), learning = AILearningModel(root: root, transport: transport, aiSession: app)
        #expect(throws: AIFailure.unconfigured) { try learning.englishLearningProvider() }
        #expect(await learning.saveConfig(DeepSeekSelectionPolicy.configuration(), temporarySecret: "synthetic-next-host"))
        let source = englishSource("Maya reads a book.")
        _ = try await learning.englishLearningProvider().analyze(EnglishLearningRequest(source: source, provider: learning.config))
        _ = try await learning.japaneseLearningProvider().analyze(JapaneseLearningRequest(source: source, provider: learning.config))
        learning.prepare(source); learning.start(confirmed: true, sourceIsCurrent: { _ in true }); try await wait { !learning.busy }
        #expect(learning.result != nil); #expect(await app.selection.attemptsUsed() == 3); #expect(await transport.calls == 3)
        let byok = BYOKSettingsModel(transport: transport, aiSession: app)
        byok.draft = DeepSeekSelectionPolicy.configuration(); byok.temporarySecret = "synthetic-next-host"
        #expect(await byok.apply()); await byok.prepareSelection(source, kind: .explain)
        byok.start(confirmed: true, sourceIsCurrent: { _ in true }); try await wait { !byok.busy }
        #expect(byok.error == AIFailure.attemptLimit.localizedDescription); #expect(await transport.calls == 3)
        await learning.clearSessionCredential()
        #expect(throws: AIFailure.credentials) { try learning.englishLearningProvider() }
        #expect(await app.selection.attemptsUsed() == 3)
    }
    @Test func rootPauseDrainsExistingWriterAndReloadsAllOwnersBeforeReopening() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let book = try await storageBook(root), first = LibraryModel(root: root), second = LibraryModel(root: root)
        await first.load(); await second.load()
        let service = try first.recoveryService(), target = try #require(try await service.books().first)
        let gate = first.storeWriteGate, admitted = try gate.beginWrite()
        let transaction = Task { try await first.withPausedStoreWriters { permit in
            #expect(gate.snapshot.activeWrites == 0)
            _ = try await service.moveToTrash(service.previewMoveToTrash(.book(target)), permit: permit)
        } }
        try await wait { first.storeWriteGate.snapshot.phase == .draining }
        #expect(first.storageMaintenance && second.storageMaintenance)
        #expect(throws: LocalStoreWriteGateError.paused) { try second.storeWriteGate.beginWrite() }
        let third = LibraryModel(root: root), thirdLoad = Task { await third.load() }
        await Task.yield(); #expect(!third.canImport)
        admitted.finish(); try await transaction.value; await thirdLoad.value
        #expect(third.books.isEmpty && third.canImport && !third.storageMaintenance)
        #expect(first.books.isEmpty && second.books.isEmpty && !first.storageMaintenance && !second.storageMaintenance)
        #expect(first.canImport && second.canImport && first.storeWriteGate.snapshot.phase == .writable)
        let tombstone = try #require(try await service.tombstones().first)
        try await second.withPausedStoreWriters { permit in _ = try await service.restoreTombstone(service.previewRestoreTombstone(tombstone.id), permit: permit) }
        #expect(first.books == [book] && second.books == [book] && third.books == [book])
    }
    @Test func visibleAndCheckpointedDirtyDraftsBlockMutationAndRemainByteExact() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let book = try await storageBook(root), saved = note(book), library = LibraryModel(root: root)
        try await library.repository.saveNote(saved); await library.load()
        let before = try Data(contentsOf: root.appendingPathComponent("library-v1.json"))
        library.recordVisibleDraft(owner: "isolated-reader", dirty: true)
        await #expect(throws: LibraryMaintenanceFailure.self) { try await library.withPausedStoreWriters { _ in Issue.record("Visible draft gate bypassed") } }
        library.recordVisibleDraft(owner: "isolated-reader", dirty: false)
        library.noteEditing.begin(.pdf(saved)); library.noteEditing.setText("Unsaved original cafe\u{301}", for: .pdf(saved))
        let journal = root.appendingPathComponent("note-edit-drafts-v1.json"), draftBytes = try Data(contentsOf: journal)
        await #expect(throws: LibraryMaintenanceFailure.self) { try await library.withPausedStoreWriters { _ in Issue.record("Checkpointed draft gate bypassed") } }
        #expect(try Data(contentsOf: journal) == draftBytes && Data(contentsOf: root.appendingPathComponent("library-v1.json")) == before)
        #expect(library.noteEditing.drafts[NoteBodySnapshot.pdf(saved).key]?.text == "Unsaved original cafe\u{301}")
    }
    @Test func failedOperationRecoversAndClearsMaintenanceWhileReloadFailureRetainsFence() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        _ = try await storageBook(root); let library = LibraryModel(root: root); await library.load()
        await #expect(throws: CancellationError.self) { try await library.withPausedStoreWriters { _ in throw CancellationError() } }
        #expect(!library.storageMaintenance && library.canImport && library.storeWriteGate.snapshot.phase == .writable)
        let path = root.appendingPathComponent("library-v1.json"), before = try Data(contentsOf: path)
        await #expect(throws: LibraryMaintenanceFailure.self) { try await library.withPausedStoreWriters { _ in
            try Data("{\"schemaVersion\":99}".utf8).write(to: path, options: .atomic)
        } }
        #expect(library.storageMaintenance && !library.canImport && library.storeWriteGate.snapshot.phase == .recoveryRequired)
        #expect(throws: LocalStoreWriteGateError.paused) { try library.storeWriteGate.beginWrite() }
        try before.write(to: path, options: .atomic) // Isolated fault fixture repaired explicitly, not production overwrite.
        let recreated = LibraryModel(root: root); await recreated.load()
        #expect(recreated.canImport && library.canImport && !library.storageMaintenance && library.storeWriteGate.snapshot.phase == .writable)
    }
    @Test func healthyStartupRetainsOrdinaryDraftSaveWhileActualRecoveryRequiresReview() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let book = try await storageBook(root), saved = note(book)
        try await LibraryRepository(root: root).saveNote(saved)
        try NoteEditDraftJournal(root: root).save([.init(baseline: .pdf(saved), text: "Original restart draft")])
        let library = LibraryModel(root: root); await library.load()
        #expect(!library.needsRecoveryDraftReview)
        await library.saveEditedNote(.pdf(saved))
        #expect(library.notes.first?.userText == "Original restart draft")
        let edited = try #require(library.notes.first)
        library.noteEditing.begin(.pdf(edited)) // Clean checkpoint can survive a backup/recovery boundary.
        try await library.withPausedStoreWriters { _ in }
        #expect(library.needsRecoveryDraftReview)
        #expect(await library.noteEditing.save(.pdf(edited)) == nil)
        await library.reloadEditedNote(.pdf(edited))
        #expect(await library.noteEditing.save(.pdf(edited)) != nil)
    }
    @Test func startupRollsBackPreparedJournalBeforeAnyOwnerLoadsWritableState() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let book = try await storageBook(root), service = try LocalRecoveryService(root: root)
        let target = try #require(try await service.books().first), gate = LocalStoreWriteGate.shared(root: root), pause = try gate.beginPause()
        try await pause.drain()
        let fault = try LocalRecoveryService(root: root, fault: { if case .prepared = $0 { throw RecoverySimulatedInterruption() } })
        await #expect(throws: RecoverySimulatedInterruption.self) { _ = try await fault.moveToTrash(fault.previewMoveToTrash(.book(target)), permit: .init(pausedRoot: root, writerEpoch: pause.epoch)) }
        pause.retainFenceUntilRecovery(); pause.finish()
        let library = LibraryModel(root: root); await library.load()
        #expect(library.books == [book] && library.canImport && library.startupRecoveryCompleted)
        #expect(try await service.tombstones().isEmpty && gate.snapshot.phase == .writable)
        try await library.withPausedStoreWriters { permit in let receipts = try await service.recoverPendingTransactions(permit: permit); #expect(receipts.isEmpty) }
    }
}
#endif
