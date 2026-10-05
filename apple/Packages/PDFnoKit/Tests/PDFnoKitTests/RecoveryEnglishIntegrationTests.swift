// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

struct RecoveryEnglishIntegrationTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Recovery-English-" + UUID().uuidString) }
    /// Storage fixtures only: these bytes do not certify native PDF rendering or grammar quality.
    private func fixture(_ root: URL) async throws -> (BookRecord, EnglishLearningNote) {
        let book = try await LibraryRepository(root: root).importPDF(Data("%PDF-1.7 synthetic storage fixture".utf8), filename: "Original.pdf", pageCount: 1)
        let text = EnglishLearningMockCorpus.sentences[0]
        let source = AISourceSnapshot(bookID: book.id, readerSessionID: UUID(), documentVersion: 1,
            anchor: .pdf(PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, quote: text,
                regions: [PageRegion(pageIndex: 0, x: 72, y: 650, width: 120, height: 16, quote: text)])))
        var config = AIProviderConfig(); config.mode = .mock; config.label = "Synthetic offline"
        let request = EnglishLearningRequest(source: source, provider: config)
        let review = EnglishLearningValidator.validate(try await LocalMockEnglishLearningProvider().analyze(request), request: request)
        return (book, try EnglishLearningNote(review: review, userText: "Original user body"))
    }
    private func paused(_ operation: () async throws -> Void) async {
        do { try await operation(); Issue.record("A paused writer was admitted") }
        catch { #expect(error as? LocalStoreWriteGateError == .paused) }
    }
    @Test func actualRepositoryAndDraftMutationEntrypointsRespectSameRootPause() async throws {
        let root = root(), gate = LocalStoreWriteGate.shared(root: root), pause = try gate.beginPause()
        defer { pause.finish(); try? FileManager.default.removeItem(at: root) }
        try await pause.drain()
        await paused { _ = try await LibraryRepository(root: root).importPDF(Data(), filename: "x.pdf", pageCount: 1) }
        await paused { _ = try await EPUBRepository(root: root).importBook(Data(), filename: "x.epub") }
        await paused { _ = try await ComicRepository(root: root).importBook(Data(), filename: "x.cbz") }
        await paused { _ = try await DOCXRepository(root: root).importBook(Data(), filename: "x.docx") }
        await paused { _ = try await TextFormatRepository(root: root).importBook(Data(), filename: "x.txt") }
        await paused { _ = try await EbookRepository(root: root).importBook(Data(), filename: "x.fb2") }
        await paused { _ = try await AILearningRepository(root: root).saveConfig(AIProviderConfig()) }
        let identity = CoverIdentity(bookID: UUID(), editionID: UUID(), fileSHA256: String(repeating: "a", count: 64), format: .pdf)
        await paused { _ = try await CoverRepository(root: root).thumbnail(for: identity) }
        await paused { try await LocalBookMetadataRepository(root: root).save(book: LocalBookIdentity(format: .pdf, bookID: identity.bookID,
            editionID: identity.editionID, fileSHA256: identity.fileSHA256), title: "Title", author: "", expectedRevision: 0) }
        #expect(throws: LocalStoreWriteGateError.paused) { try NoteEditDraftJournal(root: root).save([]) }
        #expect(throws: LocalStoreWriteGateError.paused) { try SavedBodyDraftJournal<RecordBodySnapshot>(root: root).save([]) }
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }
    @Test func revokedSourceCannotCreateManifestOrReportIdempotentSave() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let (_, note) = try await fixture(root), repository = EnglishLearningRepository(root: root)
        let fence = try EnglishLearningSourceCommitFence(root: root, source: note.review.source); fence.invalidate()
        do { try await repository.saveNote(note, commitFence: fence); Issue.record("Revoked source was saved") }
        catch { #expect(error as? AIFailure == .stale) }
        #expect(try await repository.load().notes.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(EnglishLearningRepository.filename).path))
    }
    @Test func replacedOriginalFailsInsideSavedNoteTransaction() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let (book, note) = try await fixture(root), fence = try EnglishLearningSourceCommitFence(root: root, source: note.review.source)
        let original = root.appendingPathComponent("Originals").appendingPathComponent(book.fileSHA256 + ".pdf")
        try Data("%PDF-1.7 changed bytes".utf8).write(to: original, options: .atomic)
        do { try await EnglishLearningRepository(root: root).saveNote(note, commitFence: fence); Issue.record("Changed original was accepted") }
        catch { #expect(error as? AIFailure == .stale) }
        #expect(try await EnglishLearningRepository(root: root).load().notes.isEmpty)
    }
    @Test func englishSavedRecordParticipatesInBackupTrashAndExactRestore() async throws {
        let root = root(), parent = root.deletingLastPathComponent(), package = parent.appendingPathComponent("PDFno-Backup-" + UUID().uuidString), recovered = parent.appendingPathComponent("PDFno-Recovered-" + UUID().uuidString)
        defer { for path in [root, package, recovered] { try? FileManager.default.removeItem(at: path) } }
        let (book, note) = try await fixture(root), notes = EnglishLearningRepository(root: root)
        try await notes.saveNote(note, commitFence: EnglishLearningSourceCommitFence(root: root, source: note.review.source))
        let service = try LocalRecoveryService(root: root, additionalAdapters: [.englishLearning()]), gate = LocalStoreWriteGate.shared(root: root)
        let target = try #require(try await service.books().first(where: { $0.id == book.id }))
        let pause = try gate.beginPause(); try await pause.drain(); defer { pause.finish() }
        let permit = LocalRecoveryWritePermit(pausedRoot: root, writerEpoch: pause.epoch)
        let backup = try await service.exportBackup(to: package, permit: permit)
        _ = try await service.restoreBackup(at: package, preview: backup, to: recovered, permit: permit)
        #expect(try await EnglishLearningRepository(root: recovered).load().notes == [note])
        let deletion = try await service.previewMoveToTrash(.book(target)); _ = try await service.moveToTrash(deletion, permit: permit)
        #expect(try await notes.load().notes.isEmpty)
        #expect(try await LibraryRepository(root: root).load().books.isEmpty)
        // The transaction receipt identifies the operation, not the trash row.
        let tombstone = try #require(try await service.tombstones().first(where: { $0.target == .book(target) && !$0.restored }))
        let restoration = try await service.previewRestoreTombstone(tombstone.id)
        _ = try await service.restoreTombstone(restoration, permit: permit)
        #expect(try await notes.load().notes == [note])
        #expect(try await LibraryRepository(root: root).load().books == [book])
        #expect(throws: LocalStoreWriteGateError.paused) { try gate.beginWrite() }
    }
}
