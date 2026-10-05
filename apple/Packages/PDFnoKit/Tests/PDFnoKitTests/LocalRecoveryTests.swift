// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import CoreGraphics
import PDFnoDomain
@testable import PDFnoServices

private let recoveryFormats = ["pdf", "epub", "cbz", "cbt", "cb7", "cbr", "docx", "txt", "markdown", "html", "xhtml", "mhtml", "xml", "mobi", "azw", "azw3", "fb2"]
private let recoveryText = " 原创笔记\nか\u{3099}👩🏽‍🚀 e\u{301} "
private func recoveryJSON(_ value: some Encodable) throws -> [String: Any] { try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as! [String: Any] }
private struct RecoveryFixture {
    let parent: URL
    let root: URL
    let permit: LocalRecoveryWritePermit
    init() throws {
        parent = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Recovery-Original-" + UUID().uuidString).resolvingSymlinksInPath()
        root = parent.appendingPathComponent("source")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        permit = LocalRecoveryWritePermit(pausedRoot: root, writerEpoch: UUID())
    }
    func cleanup() { try? FileManager.default.removeItem(at: parent) }
    func write(_ object: [String: Any], _ path: String) throws { try RecoveryFiles.write(RecoveryRegistry.encode(object), root: root, path: path) }
    func add(_ format: String, sharedData: Data? = nil) throws -> LocalRecoveryBook {
        let data = sharedData ?? Data(("Self-authored storage fixture / " + format).utf8), hash = LibraryRepository.digest(data)
        let quote = "猫が e\u{301} 👩🏽‍🚀", noteID = UUID()
        let name: String, record: [String: Any], note: [String: Any]?
        if format == "pdf" {
            let book = BookRecord(title: "Original PDF", fileSHA256: hash, originalFilename: "original.pdf", pageCount: 2, lastPageIndex: 1)
            let anchor = PDFSourceAnchor(editionID: book.editionID, fileSHA256: hash, quote: quote,
                                         regions: [.init(pageIndex: 1, x: 1, y: 2, width: 20, height: 10, quote: quote)])
            record = try recoveryJSON(book); note = try recoveryJSON(ReadingNote(id: noteID, bookID: book.id, anchor: anchor, userText: recoveryText, revision: 7)); name = "library-v1.json"
        } else if format == "epub" {
            var book = EPUBBook(fileSHA256: hash, title: "Original EPUB", originalFilename: "original.epub")
            let anchor = EPUBAnchor(editionID: book.editionID, fileSHA256: hash, resourceHref: "Text/one.xhtml", spineIndex: 0, start: 0, end: quote.utf16.count, quote: quote, prefix: "", suffix: "", vertical: true)
            book.progress = anchor; record = try recoveryJSON(book); note = try recoveryJSON(EPUBNote(id: noteID, bookID: book.id, anchor: anchor, userText: recoveryText)); name = "epub-v1.json"
        } else if ["cbz", "cbt", "cb7", "cbr"].contains(format) {
            var book = ComicBook(fileSHA256: hash, title: "Original Comic", originalFilename: "original." + format, pages: [.init(path: "1.png", width: 10, height: 20)])
            book.progress = ComicProgress(editionID: book.editionID, fileSHA256: hash, pageIndex: 0, pagePath: "1.png", direction: .rightToLeft, layout: .double)
            record = try recoveryJSON(book); note = nil; name = format == "cbz" ? "comics-v1.json" : "comics-" + format + "-v1.json"
        } else if format == "docx" {
            var book = DOCXBook(fileSHA256: hash, title: "Original DOCX", originalFilename: "original.docx")
            let anchor = DOCXAnchor(editionID: book.editionID, fileSHA256: hash, blockID: 0, start: 0, end: quote.utf16.count, quote: quote, prefix: "", suffix: "")
            book.progress = anchor; record = try recoveryJSON(book); note = try recoveryJSON(DOCXNote(id: noteID, bookID: book.id, anchor: anchor, userText: recoveryText)); name = "docx-mammoth-v1.json"
        } else if let format = TextFileFormat(rawValue: format) {
            let ext = format == .markdown ? "md" : format.rawValue
            var book = TextFormatBook(fileSHA256: hash, title: "Original Text", originalFilename: "original." + ext, format: format)
            let anchor = TextFormatAnchor(editionID: book.editionID, fileSHA256: hash, blockID: 0, start: 0, end: quote.utf16.count, quote: quote, prefix: "", suffix: "")
            book.progress = anchor; record = try recoveryJSON(book); note = try recoveryJSON(TextFormatNote(id: noteID, bookID: book.id, anchor: anchor, userText: recoveryText)); name = "text-formats-v1.json"
        } else {
            let format = EbookFormat(rawValue: format)!, kind: EbookContentKind = format == .fb2 ? .fb2 : (format == .azw3 ? .kf8 : .mobi6)
            var book = EbookBook(fileSHA256: hash, format: format, contentKind: kind, title: "Original Ebook", originalFilename: "original." + format.rawValue)
            let anchor = EbookAnchor(editionID: book.editionID, fileSHA256: hash, format: format, contentKind: kind, section: 0, blockID: 0, start: 0, end: quote.utf16.count, quote: quote, prefix: "", suffix: "")
            book.progress = anchor; record = try recoveryJSON(book); note = try recoveryJSON(EbookNote(id: noteID, bookID: book.id, anchor: anchor, userText: recoveryText)); name = "ebook-kookit-v1.json"
        }
        var object = try RecoveryFiles.optional(root, name).map { try RecoveryRegistry.object($0) } ?? ["schemaVersion": 1, "books": [[String: Any]]()]
        var books = object["books"] as! [[String: Any]]; books.append(record); object["books"] = books
        if let note { var notes = object["notes"] as? [[String: Any]] ?? []; notes.append(note); object["notes"] = notes }
        try write(object, name); try RecoveryFiles.write(data, root: root, path: "Originals/" + hash + "." + format)
        let identity = try RecoveryRegistry.identity(record)
        return .init(id: identity.0, editionID: identity.1, fileSHA256: hash, format: format, title: record["title"] as! String, manifest: name)
    }
    func learning(_ book: LocalRecoveryBook) throws {
        let object = try RecoveryRegistry.object(RecoveryFiles.read(root, book.manifest)), note = (object["notes"] as! [[String: Any]])[0]
        let anchor = try JSONDecoder().decode(PDFSourceAnchor.self, from: RecoveryRegistry.encode(note["anchor"]!))
        let source = AISourceSnapshot(bookID: book.id, readerSessionID: UUID(), documentVersion: 0, anchor: .pdf(anchor))
        var provider = AIProviderConfig(); provider.mode = .mock; provider.label = "Original offline mock"
        var state = AILearningState(); state.config = provider
        state.notes = [.init(result: AIResult(request: AIRequest(source: source, provider: provider, kind: .explain), text: "原创解析", fromCache: false), userText: recoveryText)]
        try RecoveryFiles.write(JSONEncoder().encode(state), root: root, path: "learning-v1.json")
        let request = JapaneseLearningRequest(source: source, provider: provider)
        let review = JapaneseLearningValidator.validate(try japaneseData(japanesePayload(source.anchor.quote)), request: request)
        let japanese = try JapaneseLearningNote(review: review, userText: recoveryText, corrections: [])
        try RecoveryFiles.write(JSONEncoder().encode(JapaneseLearningState(notes: [japanese])), root: root, path: "japanese-learning-v1.json")
        var metadata = LocalBookMetadataState()
        metadata.records = [.init(book: .init(format: .pdf, bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256), title: "原创目录标题", author: "原创作者", revision: 8)]
        try RecoveryFiles.write(JSONEncoder().encode(metadata), root: root, path: "book-metadata-v1.json")
    }
}
struct LocalRecoveryTests {
    @Test(arguments: recoveryFormats) func allStorageFormatsDeleteRestoreRetainOriginalAndNotes(_ format: String) async throws {
        let fixture = try RecoveryFixture(); defer { fixture.cleanup() }
        let book = try fixture.add(format), service = try LocalRecoveryService(root: fixture.root)
        let original = try RecoveryFiles.read(fixture.root, book.originalPath)
        let before = try RecoveryRegistry.object(RecoveryFiles.read(fixture.root, book.manifest))
        let preview = try await service.previewMoveToTrash(.book(book))
        _ = try await service.moveToTrash(preview, permit: fixture.permit)
        #expect(try await service.books().isEmpty)
        #expect(try RecoveryFiles.read(fixture.root, book.originalPath) == original)
        let tombstone = try #require(await service.tombstones().first)
        #expect(tombstone.assets.first?.sha256 == book.fileSHA256)
        let restore = try await service.previewRestoreTombstone(tombstone.id)
        _ = try await service.restoreTombstone(restore, permit: fixture.permit)
        #expect(try await service.books() == [book])
        #expect(try RecoveryRegistry.encode(RecoveryRegistry.object(RecoveryFiles.read(fixture.root, book.manifest))) == RecoveryRegistry.encode(before))
        let again = try await service.previewRestoreTombstone(tombstone.id)
        #expect(try await service.restoreTombstone(again, permit: fixture.permit).disposition == "alreadyRestored")
    }
    @Test func associatedAILearningJapaneseMetadataAndUnicodeSurvive() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }
        let book = try f.add("pdf"); try f.learning(book)
        let names = ["learning-v1.json", "japanese-learning-v1.json", "book-metadata-v1.json"]
        let original = try names.map { try RecoveryRegistry.encode(RecoveryRegistry.object(RecoveryFiles.read(f.root, $0))) }
        let service = try LocalRecoveryService(root: f.root), preview = try await service.previewMoveToTrash(.book(book))
        #expect(preview.savedRecords == 3)
        _ = try await service.moveToTrash(preview, permit: f.permit)
        #expect(try await AILearningRepository(root: f.root).load().notes.isEmpty)
        #expect(try await JapaneseLearningRepository(root: f.root).load().notes.isEmpty)
        let id = try #require(await service.tombstones().first?.id)
        _ = try await service.restoreTombstone(service.previewRestoreTombstone(id), permit: f.permit)
        for (index, name) in names.enumerated() { #expect(try RecoveryRegistry.encode(RecoveryRegistry.object(RecoveryFiles.read(f.root, name))) == original[index]) }
    }
    @Test func noteRestoreRejectsNewEditingAndBookIDConflict() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }
        let book = try f.add("pdf"), service = try LocalRecoveryService(root: f.root)
        let state = try LibraryRepository.decode(RecoveryFiles.read(f.root, book.manifest)), note = state.notes[0]
        _ = try await service.moveToTrash(service.previewMoveToTrash(.note(manifest: book.manifest, id: note.id)), permit: f.permit)
        let id = try #require(await service.tombstones().first?.id)
        var new = state; new.notes[0].revision += 1; new.notes[0].userText = "新编辑必须保留"
        try RecoveryFiles.write(JSONEncoder().encode(new), root: f.root, path: book.manifest)
        await #expect(throws: LocalRecoveryError.self) { try await service.previewRestoreTombstone(id) }
        #expect(try LibraryRepository.decode(RecoveryFiles.read(f.root, book.manifest)).notes[0].userText == "新编辑必须保留")
        new.notes = []; try RecoveryFiles.write(JSONEncoder().encode(new), root: f.root, path: book.manifest)
        _ = try await service.moveToTrash(service.previewMoveToTrash(.book(book)), permit: f.permit)
        let bookID = try #require(await service.tombstones().last?.id)
        var conflicting = new; conflicting.books[0].title = "新版本书目"
        try RecoveryFiles.write(JSONEncoder().encode(conflicting), root: f.root, path: book.manifest)
        await #expect(throws: LocalRecoveryError.self) { try await service.previewRestoreTombstone(bookID) }
    }
    @Test func backupRoundTripAllFormatsTrashDraftExclusionAndSourceUnchanged() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }
        var books: [LocalRecoveryBook] = []
        for format in recoveryFormats { books.append(try f.add(format)) }
        try f.learning(books[0]); try RecoveryFiles.write(Data("unsaved original draft".utf8), root: f.root, path: "note-edit-drafts-v1.json")
        let service = try LocalRecoveryService(root: f.root)
        _ = try await service.moveToTrash(service.previewMoveToTrash(.book(books[0])), permit: f.permit)
        let before = try RecoveryFiles.capture(f.root, registry: RecoveryRegistry(additional: [])), package = f.parent.appendingPathComponent("export.pdfnobackup")
        let preview = try await service.exportBackup(to: package, permit: f.permit)
        #expect(preview.books.count == 16 && preview.tombstoneCount == 1)
        #expect(!preview.inventory.entries.contains { $0.path.contains("draft") || $0.path.contains("Transactions") })
        #expect(preview.omittedDrafts == ["note-edit-drafts-v1.json"])
        let destination = f.parent.appendingPathComponent("recovered")
        _ = try await service.restoreBackup(at: package, preview: preview, to: destination, permit: f.permit)
        #expect(try RecoveryFiles.capture(destination, registry: RecoveryRegistry(additional: [])).files == before.files)
        #expect(try RecoveryFiles.capture(f.root, registry: RecoveryRegistry(additional: [])).files == before.files)
        await #expect(throws: LocalRecoveryError.self) { try await service.restoreBackup(at: package, preview: preview, to: f.root, permit: f.permit) }
        await #expect(throws: LocalRecoveryError.self) { try await service.exportBackup(to: package, permit: f.permit) }
    }
    @Test func tamperedMissingUnknownFutureAndDuplicateDataAreRefused() async throws {
        for mode in 0..<7 {
            let f = try RecoveryFixture(); defer { f.cleanup() }
            let book = try f.add("pdf"), service = try LocalRecoveryService(root: f.root)
            if mode == 0 { try RecoveryFiles.write(Data("tampered".utf8), root: f.root, path: book.originalPath) }
            if mode == 1 { try FileManager.default.removeItem(at: f.root.appendingPathComponent(book.originalPath)) }
            if mode == 2 { var o = try RecoveryRegistry.object(RecoveryFiles.read(f.root, book.manifest)); o["schemaVersion"] = 2; try f.write(o, book.manifest) }
            if mode == 3 { var o = try RecoveryRegistry.object(RecoveryFiles.read(f.root, book.manifest)); o["newField"] = "future"; try f.write(o, book.manifest) }
            if mode == 4 { try RecoveryFiles.write(Data("{}".utf8), root: f.root, path: "english-learning-v1.json") }
            if mode == 5 { let bytes = try RecoveryFiles.read(f.root, book.manifest); try RecoveryFiles.write(Data((String(decoding: bytes.dropLast(), as: UTF8.self) + ",\"schemaVersion\":1}").utf8), root: f.root, path: book.manifest) }
            if mode == 6 { var o = try RecoveryRegistry.object(RecoveryFiles.read(f.root, book.manifest)); o["schemaVersion"] = true; try f.write(o, book.manifest) }
            let before = try RecoveryFiles.optional(f.root, book.manifest)
            await #expect(throws: (any Error).self) { try await service.exportBackup(to: f.parent.appendingPathComponent("bad"), permit: f.permit) }
            #expect(try RecoveryFiles.optional(f.root, book.manifest) == before)
            #expect(!FileManager.default.fileExists(atPath: f.parent.appendingPathComponent("bad").path))
        }
    }
    @Test func symlinkAndTraversalPackagePathsRejected() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }
        let book = try f.add("pdf"), service = try LocalRecoveryService(root: f.root)
        let package = f.parent.appendingPathComponent("package"), preview = try await service.exportBackup(to: package, permit: f.permit)
        let path = package.appendingPathComponent("Payload/" + book.originalPath)
        let bytes = try Data(contentsOf: path), unrelated = f.parent.appendingPathComponent("unrelated")
        try bytes.write(to: unrelated); try FileManager.default.removeItem(at: path)
        try FileManager.default.createSymbolicLink(at: path, withDestinationURL: unrelated)
        await #expect(throws: (any Error).self) { try await service.verifyBackup(at: package) }
        try FileManager.default.removeItem(at: path); try bytes.write(to: path)
        var inventory = try RecoveryRegistry.object(RecoveryFiles.read(package, "inventory-v1.json"))
        var entries = inventory["entries"] as! [[String: Any]]; entries[0]["path"] = "../unrelated"; inventory["entries"] = entries
        try RecoveryFiles.write(RecoveryRegistry.encode(inventory), root: package, path: "inventory-v1.json")
        await #expect(throws: (any Error).self) { try await service.restoreBackup(at: package, preview: preview, to: f.parent.appendingPathComponent("new"), permit: f.permit) }
        #expect(try Data(contentsOf: unrelated) == bytes)
    }
    @Test(arguments: [0, 1, 2, 3, 4]) func failureAndRestartAtEachCommitBoundary(_ boundary: Int) async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }
        let book = try f.add("pdf")
        let old = try RecoveryFiles.read(f.root, book.manifest)
        let failing = try LocalRecoveryService(root: f.root, fault: { point in
            let hit: Bool
            switch point { case .prepared: hit = boundary == 0; case .installed(let index): hit = boundary == index + 1; case .beforeCommit: hit = boundary == 4; case .committed, .packageStaged, .packageCopied, .beforePackageInstall, .packageInstalled: hit = false }
            if hit { throw RecoverySimulatedInterruption() }
        })
        await #expect(throws: RecoverySimulatedInterruption.self) { try await failing.moveToTrash(failing.previewMoveToTrash(.book(book)), permit: f.permit) }
        let restarted = try LocalRecoveryService(root: f.root)
        await #expect(throws: LocalRecoveryError.self) { try await restarted.books() }
        let receipts = try await restarted.recoverPendingTransactions(permit: f.permit)
        #expect(receipts.count == 1 && receipts[0].disposition == "rolledBack")
        #expect(try RecoveryFiles.read(f.root, book.manifest) == old)
        #expect(try await restarted.books() == [book])
        #expect(try await restarted.tombstones().isEmpty)
    }
    @Test func ordinaryWriteFailureAndCancelledTaskRollback() async throws {
        for cancel in [false, true] {
            let f = try RecoveryFixture(); defer { f.cleanup() }
            let book = try f.add("pdf"), before = try RecoveryFiles.read(f.root, book.manifest)
            let service = try LocalRecoveryService(root: f.root, fault: { point in
                if case .installed(1) = point {
                    if cancel { withUnsafeCurrentTask { $0?.cancel() }; throw CancellationError() }
                    throw CocoaError(.fileWriteOutOfSpace)
                }
            })
            let task = Task { try await service.moveToTrash(service.previewMoveToTrash(.book(book)), permit: f.permit) }
            do { _ = try await task.value; Issue.record("injected operation must fail") }
            catch { if cancel { #expect(error is CancellationError) } else { #expect((error as? CocoaError)?.code == .fileWriteOutOfSpace) } }
            let restarted = try LocalRecoveryService(root: f.root)
            #expect(try await restarted.books() == [book])
            #expect(try RecoveryFiles.read(f.root, book.manifest) == before)
            #expect(try await restarted.tombstones().isEmpty)
        }
    }
    @Test func committedCrashAndCASPreviewRemainHonest() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }
        let book = try f.add("pdf"), service = try LocalRecoveryService(root: f.root)
        let preview = try await service.previewMoveToTrash(.book(book))
        var state = try LibraryRepository.decode(RecoveryFiles.read(f.root, book.manifest)); state.notes[0].userText = "新编辑"; state.notes[0].revision += 1
        try RecoveryFiles.write(JSONEncoder().encode(state), root: f.root, path: book.manifest)
        await #expect(throws: LocalRecoveryError.self) { try await service.moveToTrash(preview, permit: f.permit) }
        let crash = try LocalRecoveryService(root: f.root, fault: { if case .committed = $0 { throw RecoverySimulatedInterruption() } })
        await #expect(throws: RecoverySimulatedInterruption.self) { try await crash.moveToTrash(crash.previewMoveToTrash(.book(book)), permit: f.permit) }
        let restarted = try LocalRecoveryService(root: f.root)
        #expect(try await restarted.books().isEmpty)
        #expect(try await restarted.recoverPendingTransactions(permit: f.permit).first?.disposition == "committed")
        #expect(try await restarted.tombstones().count == 1)
    }
    @Test func sharedOriginalBytesAndSharedCoverNotRemoved() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }
        let bytes = Data("Original shared text bytes".utf8), first = try f.add("txt", sharedData: bytes), second = try f.add("markdown", sharedData: bytes)
        let service = try LocalRecoveryService(root: f.root)
        _ = try await service.moveToTrash(service.previewMoveToTrash(.book(first)), permit: f.permit)
        #expect(try await service.books() == [second])
        #expect(try RecoveryFiles.read(f.root, second.originalPath) == bytes)
        let pdf = try f.add("pdf"), epub = try f.add("epub")
        let space = CGColorSpaceCreateDeviceRGB(), context = try #require(CGContext(data: nil, width: 2, height: 3, bitsPerComponent: 8, bytesPerRow: 8, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let image = try #require(context.makeImage()), raster = try CoverRaster.encode(image), hash = LibraryRepository.digest(raster.png)
        let records = [pdf, epub].map { book in CoverRecord(identity: .init(bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256, format: book.format == "pdf" ? .pdf : .epub), origin: .userImage, imageSHA256: hash, byteLength: raster.png.count, width: 2, height: 3, revision: 4, extractorVersion: "original-cover") }
        try f.write(["schemaVersion": 1, "records": try records.map(recoveryJSON)], "covers-v1.json")
        try RecoveryFiles.write(raster.png, root: f.root, path: "Covers/Assets/" + hash + ".png")
        _ = try await service.moveToTrash(service.previewMoveToTrash(.book(pdf)), permit: f.permit)
        #expect(try RecoveryFiles.read(f.root, "Covers/Assets/" + hash + ".png") == raster.png)
        let id = try #require(await service.tombstones().last?.id)
        // Cover writer garbage collection may remove an unreferenced asset; retained copy remains.
        _ = try await service.restoreTombstone(service.previewRestoreTombstone(id), permit: f.permit)
        #expect(try RecoveryRegistry.object(RecoveryFiles.read(f.root, "covers-v1.json"))["records"] as? [Any] != nil)
        #expect(try await CoverRepository(root: f.root).readOnlySnapshot(for: records[1].identity)?.png == raster.png)
    }
    @Test func auditedEnglishSeamAndUnknownFilenameRefusal() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }
        let book = try f.add("pdf"), recordID = UUID()
        let record: [String: Any] = ["id": recordID.uuidString, "source": ["bookID": book.id.uuidString, "editionID": book.editionID.uuidString, "fileSHA256": book.fileSHA256], "userText": recoveryText]
        try f.write(["schemaVersion": 1, "notes": [record]], "english-learning-v1.json")
        let adapter = try LocalRecoveryAdditionalAdapter(filename: "english-learning-v1.json", validate: { data in
            let object = try RecoveryRegistry.object(data)
            guard Set(object.keys) == ["schemaVersion", "notes"], let rows = object["notes"] as? [[String: Any]], rows.allSatisfy({ Set($0.keys) == ["id", "source", "userText"] && ($0["source"] as? [String: Any]).map({ Set($0.keys) == ["bookID", "editionID", "fileSHA256"] }) == true }) else { throw LocalRecoveryError.invalidPackage }
        }, associations: { data in
            let rows = try RecoveryRegistry.object(data)["notes"] as! [[String: Any]]
            return try rows.map { row in let source = row["source"] as! [String: Any], identity = try RecoveryRegistry.identity(source)
                return .init(recordID: try RecoveryRegistry.id(row), bookID: identity.0, editionID: identity.1, fileSHA256: identity.2) }
        })
        let service = try LocalRecoveryService(root: f.root, additionalAdapters: [adapter])
        _ = try await service.moveToTrash(service.previewMoveToTrash(.book(book)), permit: f.permit)
        #expect((try RecoveryRegistry.object(RecoveryFiles.read(f.root, "english-learning-v1.json"))["notes"] as? [[String: Any]])?.isEmpty == true)
        let id = try #require(await service.tombstones().first?.id)
        _ = try await service.restoreTombstone(service.previewRestoreTombstone(id), permit: f.permit)
        let restored = try RecoveryRegistry.object(RecoveryFiles.read(f.root, "english-learning-v1.json"))["notes"] as! [[String: Any]]
        #expect(try RecoveryRegistry.encode(restored[0]) == RecoveryRegistry.encode(record))
        #expect(throws: LocalRecoveryError.self) { try LocalRecoveryAdditionalAdapter(filename: "credentials.json", validate: { _ in }, associations: { _ in [] }) }
    }
    @Test(arguments: recoveryFormats.filter { !["cbz", "cbt", "cb7", "cbr"].contains($0) })
    func independentNoteTrashRoundTripDoesNotMoveBook(_ format: String) async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }
        let book = try f.add(format), service = try LocalRecoveryService(root: f.root)
        let original = try RecoveryRegistry.object(RecoveryFiles.read(f.root, book.manifest))
        let note = (original["notes"] as! [[String: Any]])[0], id = try RecoveryRegistry.id(note)
        _ = try await service.moveToTrash(service.previewMoveToTrash(.note(manifest: book.manifest, id: id)), permit: f.permit)
        #expect(try await service.books() == [book])
        #expect((try RecoveryRegistry.object(RecoveryFiles.read(f.root, book.manifest))["notes"] as? [Any])?.isEmpty == true)
        let tombstone = try #require(await service.tombstones().first)
        #expect(tombstone.assets.isEmpty)
        _ = try await service.restoreTombstone(service.previewRestoreTombstone(tombstone.id), permit: f.permit)
        #expect(try RecoveryRegistry.encode(RecoveryRegistry.object(RecoveryFiles.read(f.root, book.manifest))) == RecoveryRegistry.encode(original))
    }
    @Test(arguments: [0, 1, 2]) func backupExportAndRestoreFailBeforeInstallationPreserveSource(_ boundary: Int) async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }
        _ = try f.add("pdf"); let service = try LocalRecoveryService(root: f.root)
        let baseline = try RecoveryFiles.capture(f.root, registry: RecoveryRegistry(additional: [])).files
        let good = f.parent.appendingPathComponent("good"), preview = try await service.exportBackup(to: good, permit: f.permit)
        let failing = try LocalRecoveryService(root: f.root, fault: { point in
            let hit: Bool
            switch point { case .packageStaged: hit = boundary == 0; case .packageCopied(0): hit = boundary == 1; case .beforePackageInstall: hit = boundary == 2; default: hit = false }
            if hit { throw CocoaError(.fileWriteOutOfSpace) }
        })
        let bad = f.parent.appendingPathComponent("bad")
        await #expect(throws: CocoaError.self) { try await failing.exportBackup(to: bad, permit: f.permit) }
        #expect(!FileManager.default.fileExists(atPath: bad.path))
        let destination = f.parent.appendingPathComponent("destination")
        await #expect(throws: CocoaError.self) { try await failing.restoreBackup(at: good, preview: preview, to: destination, permit: f.permit) }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(try RecoveryFiles.capture(f.root, registry: RecoveryRegistry(additional: [])).files == baseline)
        #expect(try await service.verifyBackup(at: good).inventorySHA256 == preview.inventorySHA256)
        #expect(try !FileManager.default.contentsOfDirectory(atPath: f.parent.path).contains { $0.hasPrefix(".pdfno-stage-") })
    }
    @Test func cancelledBackupAndPostRenameInterruptionRemainSafe() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }; _ = try f.add("pdf")
        let cancelled = try LocalRecoveryService(root: f.root, fault: { if case .beforePackageInstall = $0 { withUnsafeCurrentTask { $0?.cancel() } } })
        let destination = f.parent.appendingPathComponent("cancelled")
        let task = Task { try await cancelled.exportBackup(to: destination, permit: f.permit) }
        do { _ = try await task.value; Issue.record("cancelled export must not install") } catch { #expect(error is CancellationError) }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        let crash = try LocalRecoveryService(root: f.root, fault: { if case .packageInstalled = $0 { throw RecoverySimulatedInterruption() } })
        await #expect(throws: RecoverySimulatedInterruption.self) { try await crash.exportBackup(to: destination, permit: f.permit) }
        let verified = try await LocalRecoveryService(root: f.root).verifyBackup(at: destination)
        #expect(verified.books.count == 1)
    }
    @Test func pendingRollbackConflictKeepsNewEditsAndBlocksWrites() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }; let book = try f.add("pdf")
        let root = f.root
        let failing = try LocalRecoveryService(root: root, fault: { point in
            if case .installed(1) = point {
                var state = try LibraryRepository.decode(RecoveryFiles.read(root, book.manifest))
                state.books = [BookRecord(id: book.id, editionID: book.editionID, title: "Concurrent original edit", fileSHA256: book.fileSHA256, originalFilename: "original.pdf", pageCount: 2)]
                try RecoveryFiles.write(JSONEncoder().encode(state), root: root, path: book.manifest)
                throw CocoaError(.fileWriteOutOfSpace)
            }
        })
        await #expect(throws: LocalRecoveryError.self) { try await failing.moveToTrash(failing.previewMoveToTrash(.book(book)), permit: f.permit) }
        let restarted = try LocalRecoveryService(root: root)
        await #expect(throws: LocalRecoveryError.self) { try await restarted.recoverPendingTransactions(permit: f.permit) }
        await #expect(throws: LocalRecoveryError.self) { try await restarted.books() }
        #expect(try LibraryRepository.decode(RecoveryFiles.read(root, book.manifest)).books[0].title == "Concurrent original edit")
    }
    @Test func emptyLibraryBackupAndMismatchedPermit() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }; let service = try LocalRecoveryService(root: f.root)
        let destination = f.parent.appendingPathComponent("empty")
        let wrong = LocalRecoveryWritePermit(pausedRoot: f.parent, writerEpoch: UUID())
        await #expect(throws: LocalRecoveryError.self) { try await service.exportBackup(to: destination, permit: wrong) }
        let preview = try await service.exportBackup(to: destination, permit: f.permit)
        #expect(preview.inventory.totalBytes == 0 && preview.books.isEmpty)
        _ = try await service.restoreBackup(at: destination, preview: preview, to: f.parent.appendingPathComponent("restored"), permit: f.permit)
    }
    @Test func oldBackupsAndUnrelatedManagedFilesStayByteExact() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }; let book = try f.add("pdf"), other = try f.add("epub")
        let backup = try RecoveryFiles.read(f.root, book.manifest), unrelated = try RecoveryFiles.read(f.root, other.manifest)
        try RecoveryFiles.write(backup, root: f.root, path: book.manifest + ".backup")
        let service = try LocalRecoveryService(root: f.root)
        _ = try await service.moveToTrash(service.previewMoveToTrash(.book(book)), permit: f.permit)
        #expect(try RecoveryFiles.read(f.root, book.manifest + ".backup") == backup)
        #expect(try RecoveryFiles.read(f.root, other.manifest) == unrelated)
        let destination = f.parent.appendingPathComponent("package")
        let preview = try await service.exportBackup(to: destination, permit: f.permit)
        #expect(preview.inventory.entries.contains { $0.path == book.manifest + ".backup" })
    }
    @Test(arguments: ["learning-v1.json", "japanese-learning-v1.json"])
    func independentLearningNoteRestorePreservesGeneratedAndUserFields(_ manifest: String) async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }; let book = try f.add("pdf"); try f.learning(book)
        let service = try LocalRecoveryService(root: f.root), before = try RecoveryRegistry.object(RecoveryFiles.read(f.root, manifest))
        let note = (before["notes"] as! [[String: Any]])[0], id = try RecoveryRegistry.id(note)
        _ = try await service.moveToTrash(service.previewMoveToTrash(.note(manifest: manifest, id: id)), permit: f.permit)
        let tombstone = try #require(await service.tombstones().first)
        _ = try await service.restoreTombstone(service.previewRestoreTombstone(tombstone.id), permit: f.permit)
        #expect(try RecoveryRegistry.encode(RecoveryRegistry.object(RecoveryFiles.read(f.root, manifest))) == RecoveryRegistry.encode(before))
        #expect(try await service.books() == [book])
    }
    @Test func separateNoteTombstoneWaitsForItsDeletedBook() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }; let book = try f.add("pdf"), service = try LocalRecoveryService(root: f.root)
        let noteID = try LibraryRepository.decode(RecoveryFiles.read(f.root, book.manifest)).notes[0].id
        _ = try await service.moveToTrash(service.previewMoveToTrash(.note(manifest: book.manifest, id: noteID)), permit: f.permit)
        let noteTombstone = try #require(await service.tombstones().first?.id)
        _ = try await service.moveToTrash(service.previewMoveToTrash(.book(book)), permit: f.permit)
        let bookTombstone = try #require(await service.tombstones().last?.id)
        await #expect(throws: (any Error).self) { try await service.previewRestoreTombstone(noteTombstone) }
        _ = try await service.restoreTombstone(service.previewRestoreTombstone(bookTombstone), permit: f.permit)
        _ = try await service.restoreTombstone(service.previewRestoreTombstone(noteTombstone), permit: f.permit)
        #expect(try LibraryRepository.decode(RecoveryFiles.read(f.root, book.manifest)).notes[0].id == noteID)
    }
    @Test func futureRecoveryAndInventorySchemasAndWrongSourceAreProtected() async throws {
        let f = try RecoveryFixture(); defer { f.cleanup() }; let book = try f.add("pdf"); try f.learning(book)
        let service = try LocalRecoveryService(root: f.root), baseline = try RecoveryFiles.read(f.root, "learning-v1.json")
        var state = try AILearningRepository.decode(baseline)
        let old = state.notes[0], source = AISourceSnapshot(bookID: UUID(), readerSessionID: old.result.source.readerSessionID, documentVersion: 0, anchor: old.result.source.anchor)
        state.notes = [.init(id: old.id, result: AIResult(request: AIRequest(source: source, provider: old.result.provider, kind: old.result.kind), text: old.result.text, fromCache: old.result.fromCache), userText: old.userText)]
        try RecoveryFiles.write(JSONEncoder().encode(state), root: f.root, path: "learning-v1.json")
        await #expect(throws: LocalRecoveryError.self) { try await service.books() }
        try RecoveryFiles.write(baseline, root: f.root, path: "learning-v1.json")
        let metadataBytes = try RecoveryFiles.read(f.root, "book-metadata-v1.json")
        var metadata = try RecoveryRegistry.object(metadataBytes), records = metadata["records"] as! [[String: Any]], identity = records[0]["book"] as! [String: Any]
        identity["format"] = "EPUB"; records[0]["book"] = identity; metadata["records"] = records
        try f.write(metadata, "book-metadata-v1.json")
        await #expect(throws: LocalRecoveryError.self) { try await service.books() }
        try RecoveryFiles.write(metadataBytes, root: f.root, path: "book-metadata-v1.json")
        _ = try await service.moveToTrash(service.previewMoveToTrash(.book(book)), permit: f.permit)
        let original = try RecoveryFiles.read(f.root, RecoveryFiles.stateName)
        for value in [2, true] as [Any] {
            var object = try RecoveryRegistry.object(original); object["schemaVersion"] = value; try f.write(object, RecoveryFiles.stateName)
            let refused = try RecoveryFiles.read(f.root, RecoveryFiles.stateName)
            await #expect(throws: (any Error).self) { try await service.tombstones() }
            #expect(try RecoveryFiles.read(f.root, RecoveryFiles.stateName) == refused)
        }
        try RecoveryFiles.write(original, root: f.root, path: RecoveryFiles.stateName)
        let package = f.parent.appendingPathComponent("future"), preview = try await service.exportBackup(to: package, permit: f.permit)
        let inventory = try RecoveryFiles.read(package, "inventory-v1.json")
        for mode in 0..<3 {
            var object = try RecoveryRegistry.object(inventory)
            if mode == 0 { object["schemaVersion"] = 2 }
            if mode == 1 { object["newField"] = "future" }
            if mode == 2 { object["schemaVersion"] = true }
            try RecoveryFiles.write(RecoveryRegistry.encode(object), root: package, path: "inventory-v1.json")
            await #expect(throws: (any Error).self) { try await service.restoreBackup(at: package, preview: preview, to: f.parent.appendingPathComponent("destination"), permit: f.permit) }
            #expect(!FileManager.default.fileExists(atPath: f.parent.appendingPathComponent("destination").path))
        }
    }
}
