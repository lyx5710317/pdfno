// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import CoreGraphics
import Testing
import PDFnoDomain
@testable import PDFnoServices
@testable import PDFnoUI

private actor BooknoMaterialBox {
    var value: BooknoPreviewMaterial
    init(_ value: BooknoPreviewMaterial) { self.value = value }
    func get() -> BooknoPreviewMaterial { value }
    func set(_ value: BooknoPreviewMaterial) { self.value = value }
}
private actor BooknoDeferredMaterial {
    var pending: CheckedContinuation<BooknoPreviewMaterial, Never>?
    func load() async -> BooknoPreviewMaterial { await withCheckedContinuation { pending = $0 } }
    func started() -> Bool { pending != nil }
    func finish(_ value: BooknoPreviewMaterial) { pending?.resume(returning: value); pending = nil }
}
private actor BooknoDeferredCatalog {
    var pending: CheckedContinuation<[BooknoPreviewChoice], Never>?
    func load() async -> [BooknoPreviewChoice] { await withCheckedContinuation { pending = $0 } }
    func started() -> Bool { pending != nil }
    func finish(_ value: [BooknoPreviewChoice]) { pending?.resume(returning: value); pending = nil }
}

@Suite(.serialized) @MainActor struct BooknoIntegrationTests {
    private func root() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Bookno-Integration-" + UUID().uuidString) }
    private func files(_ root: URL) throws -> [String: Data] {
        guard let entries = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) else { return [:] }
        var result: [String: Data] = [:]
        for case let file as URL in entries where try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
            result[file.path.replacingOccurrences(of: root.path + "/", with: "")] = try Data(contentsOf: file)
        }
        return result
    }
    private func seedPDF(_ root: URL, body: String = "Original saved body か\u{3099}😀") async throws -> (BookRecord, ReadingNote) {
        let source = LibraryRepository(root: root), book = try await source.importPDF(originalSample(), filename: "Original fixture.pdf", pageCount: 2)
        let note = ReadingNote(bookID: book.id, anchor: PDFSourceAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256,
            quote: "window", regions: [PageRegion(pageIndex: 0, x: 72, y: 650, width: 40, height: 16, quote: "window")]), userText: body)
        try await source.saveNote(note); return (book, note)
    }
    private func png() throws -> Data {
        let context = try #require(CGContext(data: nil, width: 800, height: 1000, bitsPerComponent: 8, bytesPerRow: 3200,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 800, height: 1000))
        return try CoverRaster.encode(#require(context.makeImage())).png
    }
    private func standaloneBook(_ format: BooknoFormat = .pdf) -> BooknoBookDTO {
        BooknoBookDTO(bookUUID: UUID(), edition: BooknoEditionDTO(id: UUID(), format: format, sourceFileSHA256: String(repeating: "a", count: 64)), title: "Original standalone")
    }

    @Test(arguments: [TextFileFormat.txt, .markdown, .html]) func textAnchorsKeepOwnNamespaceExactUnicodeAndNoFakeCover(format: TextFileFormat) async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let text = "  Original か\u{3099}😀👩‍💻\nEnd  ", repository = TextFormatRepository(root: root)
        let filename = "Original." + (format == .markdown ? "md" : format.rawValue)
        let book = try await repository.importBook(Data(text.utf8), filename: filename)
        let document = TextFormatDocument(blocks: [TextFormatBlock(id: 0, runs: [TextFormatRun(text)], start: 0)])
        try await repository.bindRenderedDocument(document, book: book)
        let anchor = try #require(document.anchor(book: book, start: 2, end: text.utf16.count - 2))
        let note = TextFormatNote(bookID: book.id, anchor: anchor, userText: "\n 原样用户正文か\u{3099} ")
        try await repository.saveNote(note)
        let preview = BooknoLibraryPreviewRepository(root: root), choices = try await preview.catalog(), before = try files(root)
        let material = try await preview.materialize(choices, includeSavedNotes: true, includeCovers: true)
        #expect(material.payloads.count == 2 && material.assets.isEmpty && material.assetBytes.isEmpty && material.notices.count == 1)
        var ledger = BooknoOfflinePreview(mode: .preview)
        let batch = try BooknoExchangeCodec.decode(BooknoExchangeCodec.encode(ledger.stage(material.payloads)))
        let restored = try #require(batch.mutations.compactMap { if case .note(let n) = $0.payload { return n }; return nil }.first)
        #expect(restored.source.format == BooknoFormat(format) && restored.source.offsetUnit == .utf16CodeUnit)
        #expect(restored.externalID.hasPrefix("pdfno:note:" + format.rawValue + ":highlight:"))
        if case .text(let value) = restored.source.anchor {
            #expect(value == anchor && value.extractionVersion == TextFormatDocument.extractionVersion)
            #expect(value.quote.utf8.elementsEqual(anchor.quote.utf8) && value.prefix.utf8.elementsEqual(anchor.prefix.utf8))
        } else { Issue.record("Text source must retain its own locator") }
        #expect(restored.userText.utf8.elementsEqual(note.userText.utf8) && restored.aiAttachments.isEmpty)
        #expect(try files(root) == before)
        let sameID = Set(BooknoFormat.allCases.map { BooknoIdentity.book(book.id, format: $0) })
        #expect(sameID.count == 7)
    }

    @Test func nativeSavedEditsMetadataDraftExclusionRestartAndMockReplayUseFreshReadOnlySnapshots() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let (book, note) = try await seedPDF(root), source = LibraryRepository(root: root)
        let identity = LocalBookIdentity(format: .pdf, bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256)
        let metadata = LocalBookMetadataRepository(root: root)
        try await metadata.save(book: identity, title: "Original edited title", author: "Original author", expectedRevision: 0)
        let editor = NoteEditingModel(root: root) { snapshot, body in
            guard case .pdf(let value) = snapshot else { throw NoteBodyEditError.conflict }
            return .pdf(try await source.updateNoteBody(expected: value, text: body))
        }
        let snapshot = NoteBodySnapshot.pdf(note); editor.begin(snapshot); editor.setText("private-draft-probe", for: snapshot)
        let preview = BooknoLibraryPreviewRepository(root: root), model = BooknoPreviewModel(repository: preview)
        await model.refresh(); #expect(!model.enabled && model.batch == nil && model.mockRecordCount == 0)
        model.enabled = true; model.selectedIDs = [try #require(model.choices.first).id]; model.includeSavedNotes = true
        let before = try files(root); await model.prepare()
        let first = try #require(model.batch), saved = try #require(first.mutations.compactMap { if case .note(let n) = $0.payload { return n }; return nil }.first)
        #expect(saved.userText.utf8.elementsEqual(note.userText.utf8) && saved.localEditRevision == note.revision)
        #expect(!model.json.contains("private-draft-probe") && !model.json.contains(root.path) && !model.json.contains("originalFilename"))
        model.runMock(loseReceipt: true)
        #expect(model.mockRecordCount == 2 && model.confirmedCursor == 0 && model.receipt == nil)
        model.runMock(); model.runMock()
        #expect(model.mockRecordCount == 2 && model.confirmedCursor == 1 && model.batch?.batchID == first.batchID)
        #expect(try files(root) == before)
        editor.setText("  Saved replacement か\u{3099}🌸\n ", for: snapshot); _ = try #require(await editor.save(snapshot))
        try await metadata.save(book: identity, title: "Fresh metadata title", author: "Fresh author", expectedRevision: 1)
        let afterEdit = try files(root); await model.prepare()
        let second = try #require(model.batch), changed = try #require(second.mutations.compactMap { if case .note(let n) = $0.payload { return n }; return nil }.first)
        #expect(second.cursor.sequence == 2 && changed.externalID == saved.externalID && changed.quote == saved.quote && changed.source == saved.source)
        #expect(changed.userText.utf8.elementsEqual("  Saved replacement か\u{3099}🌸\n ".utf8) && changed.localEditRevision == note.revision + 1)
        #expect(second.mutations.allSatisfy { $0.revision == 2 })
        if case .book(let b) = try #require(second.mutations.first { $0.payload.kind == .book }).payload {
            #expect(b.title == "Fresh metadata title" && b.authors == ["Fresh author"] && b.metadataSourceRevision == 2)
        }
        model.runMock(); #expect(model.confirmedCursor == 2 && model.mockRecordCount == 2)
        model.close(); #expect(!model.enabled && model.batch == nil && model.json.isEmpty && model.mockRecordCount == 0)
        let restarted = BooknoPreviewModel(repository: BooknoLibraryPreviewRepository(root: root)); await restarted.refresh()
        #expect(!restarted.enabled && restarted.batch == nil && restarted.confirmedCursor == 0)
        let result = try await preview.materialize(restarted.choices, includeSavedNotes: true, includeCovers: false)
        #expect(result.payloads.contains { if case .note(let n) = $0 { return n.userText.utf8.elementsEqual(changed.userText.utf8) }; return false })
        let original = try await source.readAsset(for: book)
        #expect(try files(root) == afterEdit)
        #expect(try original == originalSample())
    }

    @Test func chapterLearningKeepsTypedLocatorImmutableAIAndSavedUserBodyWithoutProviderFields() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let bytes = try ConversionFixture.zip([
            ("mimetype", Data("application/epub+zip".utf8)),
            ("META-INF/container.xml", Data("<container><rootfiles><rootfile full-path='book.opf'/></rootfiles></container>".utf8)),
            ("book.opf", Data("<package><metadata><title>Original Bookno EPUB</title></metadata><manifest><item id='one' href='one.xhtml' media-type='application/xhtml+xml'/></manifest><spine><itemref idref='one'/></spine></package>".utf8)),
            ("one.xhtml", Data("<html><body><p>Original 日本語が😀</p></body></html>".utf8))], deflated: false)
        let book = try await EPUBRepository(root: root).importBook(bytes, filename: "Original Bookno.epub"), quote = "Original 日本語か\u{3099}😀"
        let anchor = EPUBAnchor(editionID: book.editionID, fileSHA256: book.fileSHA256, resourceHref: "one.xhtml", spineIndex: 0,
            start: 0, end: quote.utf16.count, quote: quote, prefix: "", suffix: "", vertical: true)
        let source = AISourceSnapshot(bookID: book.id, readerSessionID: UUID(), documentVersion: 2, anchor: .epubChapter(anchor))
        let result = AIResult(request: AIRequest(source: source, provider: DeepSeekSelectionPolicy.configuration(), kind: .translate), text: "Original offline chapter result", fromCache: false)
        let note = AILearningNote(result: result, userText: "Old saved body"), notes = AILearningRepository(root: root)
        try await notes.saveNote(note); let changed = try await notes.updateNoteBody(expected: note, text: " New saved body か\u{3099} ")
        let repository = BooknoLibraryPreviewRepository(root: root), choices = try await repository.catalog(), before = try files(root)
        let material = try await repository.materialize(choices, includeSavedNotes: true, includeCovers: false)
        let dto = try #require(material.payloads.compactMap { if case .note(let n) = $0 { return n }; return nil }.first)
        #expect(dto.source.anchor == BooknoSourceAnchor(.epubChapter(anchor)) && dto.annotationKind == .learning)
        #expect(dto.userText.utf8.elementsEqual(changed.userText.utf8) && dto.aiAttachments.first?.text == result.text)
        #expect(dto.aiAttachments.first?.promptVersion == EPUBChapterTranslationPolicy.promptVersion && dto.source.offsetUnit == .utf16CodeUnit)
        var ledger = BooknoOfflinePreview(mode: .preview)
        let encoded = try BooknoExchangeCodec.encode(ledger.stage(material.payloads)); _ = try BooknoExchangeCodec.decode(encoded)
        let text = String(decoding: encoded, as: UTF8.self)
        #expect(!text.contains("readerSessionID") && !text.contains("endpoint") && !text.contains("provider") && !text.contains("api.deepseek.com"))
        let savedResult = try await notes.load().notes.first?.result
        #expect(try files(root) == before && savedResult == result)
        let forged = BooknoNoteDTO(noteUUID: dto.noteUUID, annotationKind: .learning, userText: dto.userText, source: dto.source,
            aiAttachments: [BooknoAIAttachmentDTO(kind: .explain, text: result.text, promptVersion: "selection-1")])
        #expect(throws: BooknoPreviewError.sourceMismatch) { try BooknoExchangeCodec.validate(.note(forged)) }
    }

    @Test func existingCoverExportsOriginalAssetNotResampledCacheAndDoesNotRepairCorruption() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let (book, _) = try await seedPDF(root), covers = CoverRepository(root: root), identity = CoverIdentity(book)
        let art = root.appendingPathComponent("Original blue art.png"); try png().write(to: art)
        let record = try await covers.replace(identity, withLocalImage: art), thumbnail = try await covers.thumbnail(for: identity)
        let before = try files(root), stored = try #require(await covers.readOnlySnapshot(for: identity)), original = try #require(stored.png)
        #expect(LibraryRepository.digest(original) == record.imageSHA256 && original.count == record.byteLength)
        #expect(try #require(thumbnail.png) != original)
        let repository = BooknoLibraryPreviewRepository(root: root)
        let choices = try await repository.catalog()
        let material = try await repository.materialize(choices, includeSavedNotes: true, includeCovers: true)
        #expect(material.assets.count == 1 && material.assetBytes.values.first == original)
        var ledger = BooknoOfflinePreview(mode: .preview), receiver = BooknoMockReceiver(receiverID: ledger.receiverID)
        let receipt = try receiver.receive(ledger.stage(material.payloads, assets: material.assets), assetBytes: material.assetBytes)
        #expect(receipt.verifiedAssetIDs.count == 1 && receiver.assetCount == 1)
        #expect(try files(root) == before)
        let path = root.appendingPathComponent("Covers/Assets/" + (try #require(record.imageSHA256)) + ".png")
        try Data("Original corrupt fixture".utf8).write(to: path); let corrupt = try files(root)
        await #expect(throws: CoverError.invalidImage) { try await covers.readOnlySnapshot(for: identity) }
        let preservedRecord = try await covers.record(for: identity)
        #expect(try files(root) == corrupt && preservedRecord == record)
    }

    @Test func missingCoversAreExplicitAndReadOnlyEvenWithoutOriginalFile() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let (book, _) = try await seedPDF(root), source = root.appendingPathComponent("Originals/" + book.fileSHA256 + ".pdf")
        try FileManager.default.removeItem(at: source)
        let before = try files(root), repository = BooknoLibraryPreviewRepository(root: root)
        let choices = try await repository.catalog()
        let material = try await repository.materialize(choices, includeSavedNotes: false, includeCovers: true)
        #expect(material.assets.isEmpty && material.assetBytes.isEmpty && material.notices.count == 1 && material.payloads.count == 1)
        #expect(try files(root) == before && !FileManager.default.fileExists(atPath: root.appendingPathComponent("covers-v1.json").path))
    }

    @Test func diagnosticMetadataRevisionDoesNotChangeSemanticHash() throws {
        let b = standaloneBook()
        let first = BooknoBookDTO(bookUUID: b.bookUUID, edition: b.edition, title: b.title, metadataSourceRevision: 1)
        let next = BooknoBookDTO(bookUUID: b.bookUUID, edition: b.edition, title: b.title, metadataSourceRevision: 8)
        #expect(try BooknoExchangeCodec.contentHash(.book(first)) == BooknoExchangeCodec.contentHash(.book(next)))
        let renamed = BooknoBookDTO(bookUUID: b.bookUUID, edition: b.edition, title: "Saved renamed title", metadataSourceRevision: 9)
        #expect(try BooknoExchangeCodec.contentHash(.book(renamed)) != BooknoExchangeCodec.contentHash(.book(next)))
        var ledger = BooknoOfflinePreview(mode: .preview)
        #expect(try ledger.stage([.book(first)]).mutations.first?.revision == 1)
        #expect(try ledger.stage([.book(next)]).mutations.first?.revision == 1)
        #expect(try ledger.stage([.book(renamed)]).mutations.first?.revision == 2)
    }

    @Test func uncheckedNotesAndForeignBooksAreRefusedBeforeStaging() async throws {
        let book = standaloneBook(), choice = BooknoPreviewChoice(book: book), foreign = standaloneBook(.epub)
        let anchor = PDFSourceAnchor(editionID: book.edition.id, fileSHA256: book.edition.sourceFileSHA256, quote: "Original quote",
            regions: [PageRegion(pageIndex: 0, x: 1, y: 2, width: 30, height: 10, quote: "Original quote")])
        let note = BooknoNoteDTO(noteUUID: UUID(), userText: "Original body", source: BooknoSourceDTO(bookUUID: book.bookUUID, format: .pdf, anchor: .pdf(anchor)))
        for bad in [BooknoPreviewMaterial(payloads: [.book(book), .note(note)]), BooknoPreviewMaterial(payloads: [.book(book), .book(foreign)])] {
            let box = BooknoMaterialBox(bad), model = BooknoPreviewModel(catalog: { [choice] }, materialize: { _, _, _ in await box.get() })
            await model.refresh(); model.enabled = true; model.selectedIDs = [choice.id]
            await model.prepare(); #expect(model.batch == nil && model.error != nil && model.mockRecordCount == 0)
            await box.set(BooknoPreviewMaterial(payloads: [.book(book)])); await model.prepare()
            #expect(model.batch?.cursor.sequence == 1 && model.batch?.mutations.count == 1)
        }
    }

    @Test func closeWhilePreparingDiscardsLateContentAndMockCannotRunDisabled() async throws {
        let book = standaloneBook(), choice = BooknoPreviewChoice(book: book), deferred = BooknoDeferredMaterial()
        let model = BooknoPreviewModel(catalog: { [choice] }, materialize: { _, _, _ in await deferred.load() })
        await model.refresh(); await model.prepare(); #expect(model.batch == nil)
        model.enabled = true; model.selectedIDs = [choice.id]
        let pending = Task { await model.prepare() }, deadline = Date().addingTimeInterval(3)
        while !(await deferred.started()) && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(await deferred.started()); model.close()
        await deferred.finish(BooknoPreviewMaterial(payloads: [.book(book)])); await pending.value; model.runMock()
        #expect(!model.enabled && model.batch == nil && model.json.isEmpty && model.selectedIDs.isEmpty && model.choices.isEmpty)
        #expect(model.mockRecordCount == 0 && model.confirmedCursor == 0)
    }

    @Test func closeBeforeDefaultDisabledCatalogCompletesDoesNotRestoreChoices() async throws {
        let deferred = BooknoDeferredCatalog(), choice = BooknoPreviewChoice(book: standaloneBook())
        let model = BooknoPreviewModel(catalog: { await deferred.load() }, materialize: { _, _, _ in BooknoPreviewMaterial(payloads: []) })
        let pending = Task { await model.refresh() }, deadline = Date().addingTimeInterval(3)
        while !(await deferred.started()) && Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        try #require(await deferred.started()); model.close(); await deferred.finish([choice]); await pending.value
        #expect(!model.enabled && model.choices.isEmpty && model.batch == nil && model.json.isEmpty)
    }

    @Test func staleEditionNeverRetargetsNotesAndBatchLimitDoesNotPublishPartialContent() async throws {
        let root = root(); defer { try? FileManager.default.removeItem(at: root) }
        let (book, _) = try await seedPDF(root), repository = BooknoLibraryPreviewRepository(root: root)
        let choice = try #require(await repository.catalog().first)
        let stale = BooknoPreviewChoice(book: BooknoBookDTO(bookUUID: book.id,
            edition: BooknoEditionDTO(id: UUID(), format: .pdf, sourceFileSHA256: book.fileSHA256), title: book.title))
        await #expect(throws: BooknoPreviewError.sourceMismatch) { try await repository.materialize([stale], includeSavedNotes: true, includeCovers: false) }
        await #expect(throws: BooknoPreviewError.selectionLimit) { try await repository.materialize(Array(repeating: choice, count: 21), includeSavedNotes: true, includeCovers: false) }
        #expect(FeatureAvailability.bookno.available == false)
    }
}
#endif
