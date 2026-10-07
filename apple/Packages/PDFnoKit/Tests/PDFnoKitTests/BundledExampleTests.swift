// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
@testable import PDFnoServices

struct BundledExampleTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Example-Original-" + UUID().uuidString) }
    private func identity(_ book: BookRecord) -> BundledExampleIdentity { .init(format: "pdf", bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256) }
    @Test func loadDoesNotCreateOrMigrateStore() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let state = try await BundledExampleRepository(root: r).load()
        #expect(state.records.isEmpty); #expect(!FileManager.default.fileExists(atPath: r.path))
    }
    @Test func deduplicatedPersonalBookIsNeverReclassified() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let bytes = try originalSample(), library = LibraryRepository(root: r)
        let created = try await library.importPDFWithStatus(bytes, filename: "study-sample.pdf", pageCount: 2)
        let personal = created.book
        #expect(created.created)
        let reused = try await library.importPDFWithStatus(bytes, filename: "study-sample.pdf", pageCount: 2)
        let deduplicated = reused.book
        #expect(!reused.created)
        #expect(personal.id == deduplicated.id)
        let state = try await BundledExampleRepository(root: r).registerNewImport(identity(deduplicated), resource: "study-sample.pdf", existingBookIDs: [personal.id], newImport: false, bundledSHA256: LibraryRepository.digest(bytes))
        #expect(state.records.isEmpty)
        let staleWindow = try await BundledExampleRepository(root: r).registerNewImport(identity(deduplicated), resource: "study-sample.pdf", existingBookIDs: [], newImport: reused.created, bundledSHA256: LibraryRepository.digest(bytes))
        #expect(staleWindow.records.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: r.appendingPathComponent("bundled-examples-v1.json").path))
        #expect(try await library.load().books.count == 1)
    }
    @Test func exactIdentityReloadAndWrongContentRefusal() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let bytes = try originalSample()
        let book = try await LibraryRepository(root: r).importPDF(bytes, filename: "study-sample.pdf", pageCount: 2)
        let repo = BundledExampleRepository(root: r), exact = identity(book)
        let marked = try await repo.registerNewImport(exact, resource: "study-sample.pdf", existingBookIDs: [], newImport: true, bundledSHA256: LibraryRepository.digest(bytes))
        #expect(marked.records.map(\.book) == [exact])
        #expect(try await BundledExampleRepository(root: r).load().records == marked.records)
        let changed = BundledExampleIdentity(format: "pdf", bookID: book.id, editionID: UUID(), fileSHA256: book.fileSHA256)
        #expect(!marked.records.contains { $0.book == changed })
        await #expect(throws: BundledExampleError.self) { try await repo.registerNewImport(changed, resource: "study-sample.pdf", existingBookIDs: [], newImport: true, bundledSHA256: String(repeating: "0", count: 64)) }
    }
    @Test func corruptAndFutureStorePreserved() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        try FileManager.default.createDirectory(at: r, withIntermediateDirectories: true)
        let path = r.appendingPathComponent("bundled-examples-v1.json"), repo = BundledExampleRepository(root: r)
        let b = BundledExampleIdentity(format: "pdf", bookID: UUID(), editionID: UUID(), fileSHA256: String(repeating: "a", count: 64))
        for bytes in [Data("{broken".utf8), Data("{\"schemaVersion\":2,\"records\":[]}".utf8), Data("{\"schemaVersion\":true,\"records\":[]}".utf8), Data("{\"schemaVersion\":1,\"schemaVersion\":1,\"records\":[]}".utf8)] {
            try bytes.write(to: path)
            await #expect(throws: (any Error).self) { try await repo.registerNewImport(b, resource: "study-sample.pdf", existingBookIDs: [], newImport: true, bundledSHA256: b.fileSHA256) }
            #expect(try Data(contentsOf: path) == bytes)
        }
    }
    @Test func backupAndTrashRestoreRetainProvenance() async throws {
        let r = root(); defer { try? FileManager.default.removeItem(at: r) }
        let bytes = try originalSample(), book = try await LibraryRepository(root: r).importPDF(bytes, filename: "study-sample.pdf", pageCount: 2)
        let repo = BundledExampleRepository(root: r), exact = identity(book)
        _ = try await repo.registerNewImport(exact, resource: "study-sample.pdf", existingBookIDs: [], newImport: true, bundledSHA256: LibraryRepository.digest(bytes))
        let service = try LocalRecoveryService(root: r), permit = LocalRecoveryWritePermit(pausedRoot: r, writerEpoch: UUID())
        let target = try await service.books().first { $0.id == book.id }!
        let preview = try await service.previewMoveToTrash(.book(target))
        _ = try await service.moveToTrash(preview, permit: permit)
        #expect(try await repo.load().records.isEmpty)
        let restore = try await service.previewRestoreTombstone(try await service.tombstones().first!.id)
        _ = try await service.restoreTombstone(restore, permit: permit)
        #expect(try await repo.load().records.map(\.book) == [exact])
        let package = r.appendingPathExtension("package"), restored = r.appendingPathExtension("restored")
        defer { try? FileManager.default.removeItem(at: package); try? FileManager.default.removeItem(at: restored) }
        let backup = try await service.exportBackup(to: package, permit: permit)
        _ = try await service.verifyBackup(at: package)
        _ = try await service.restoreBackup(at: package, preview: backup, to: restored, permit: permit)
        #expect(try await BundledExampleRepository(root: restored).load().records.map(\.book) == [exact])
        // Actual package validation admits the new sidecar and checks its source association.
        #expect(try await service.books().count == 1)
    }
}
