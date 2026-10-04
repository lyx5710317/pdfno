// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CoreGraphics
import Testing
import PDFnoDomain
@testable import PDFnoServices

private enum ExchangeFixture {
    static let bookID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    static let editionID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
    static let noteID = UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
    static let receiverID = UUID(uuidString: "40000000-0000-0000-0000-000000000001")!
    static let epoch = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
    static let hash = LibraryRepository.digest(Data("original fixture source bytes".utf8))
    static let quote = " A😀か\u{3099}👩‍💻\n本 "
    static func book(title: String = "原创样书", cover: BooknoCoverAssetDTO? = nil, format: BooknoFormat = .pdf) -> BooknoBookDTO {
        BooknoBookDTO(bookUUID: bookID, edition: BooknoEditionDTO(id: editionID, format: format, sourceFileSHA256: hash),
                      title: title, coverAssetID: cover?.assetID, coverOrigin: cover == nil ? nil : .userImage,
                      coverSourceRevision: cover == nil ? nil : 1)
    }
    static func pdfNote(body: String = "\n  原创备注か\u{3099}😀  ", revision: Int = 12) throws -> BooknoNoteDTO {
        let anchor = PDFSourceAnchor(editionID: editionID, fileSHA256: hash, quote: quote,
            regions: [PageRegion(pageIndex: 0, x: 12, y: 34, width: 90, height: 15, quote: quote)])
        return try BooknoExportAdapter.note(.pdf(ReadingNote(id: noteID, bookID: bookID, anchor: anchor,
                                                            userText: body, revision: revision)), book: book())
    }
    static func epubAnchor() -> EPUBAnchor {
        EPUBAnchor(editionID: editionID, fileSHA256: hash, resourceHref: "OPS/chapter.xhtml", spineIndex: 2,
                   start: 21, end: 21 + quote.utf16.count, quote: quote, prefix: "前文😀", suffix: "后文", vertical: true)
    }
    static func session() -> BooknoOfflinePreview { BooknoOfflinePreview(mode: .preview, receiverID: receiverID, epoch: epoch) }
    static func mutation(_ payload: BooknoPayload, revision: Int = 1, base: Int = 0) throws -> BooknoMutation {
        BooknoMutation(revision: revision, baseRevision: base, contentHash: try BooknoExchangeCodec.contentHash(payload), payload: payload)
    }
    static func batch(_ payloads: [BooknoPayload], sequence: Int = 1, revision: Int = 1, base: Int = 0,
                      id: UUID = UUID(), assets: [BooknoCoverAssetDTO] = [], tombstones: [BooknoTombstoneDTO] = []) throws -> BooknoPreviewBatch {
        BooknoPreviewBatch(receiverID: receiverID, batchID: id, cursor: BooknoCursor(epoch: epoch, sequence: sequence),
            mutations: try payloads.map { try mutation($0, revision: revision, base: base) }, assets: assets, tombstones: tombstones)
    }
    static func png(red: Bool = true) throws -> (BooknoCoverAssetDTO, Data) {
        let context = try #require(CGContext(data: nil, width: 3, height: 4, bitsPerComponent: 8, bytesPerRow: 12,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: red ? 1 : 0, green: 0.25, blue: red ? 0 : 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 3, height: 4))
        let png = try CoverRaster.encode(#require(context.makeImage())).png
        return (BooknoCoverAssetDTO(sha256: LibraryRepository.digest(png), mimeType: "image/png", byteLength: png.count, width: 3, height: 4), png)
    }
}

@Test func booknoDefaultDisabledAndNoPublicationOnFailure() throws {
    var session = BooknoOfflinePreview(receiverID: ExchangeFixture.receiverID, epoch: ExchangeFixture.epoch)
    #expect(throws: BooknoPreviewError.disabled) { try session.stage([.book(ExchangeFixture.book())]) }
    #expect(session.lastBatch == nil)
    session.mode = .preview
    #expect(throws: BooknoPreviewError.invalidContract) { try session.stage([.book(ExchangeFixture.book()), .book(ExchangeFixture.book())]) }
    let batch = try session.stage([.book(ExchangeFixture.book())])
    #expect(batch.cursor.sequence == 1 && batch.mutations[0].revision == 1)
    #expect(FeatureAvailability.bookno.available == false)
}

@Test func booknoStableScopedIDsExcludeTitleEditionAndInstallIdentity() throws {
    let original = ExchangeFixture.book(), renamed = ExchangeFixture.book(title: "改名")
    #expect(original.externalID == renamed.externalID)
    #expect(original.externalID != ExchangeFixture.book(format: .epub).externalID)
    #expect(BooknoIdentity.note(ExchangeFixture.noteID, format: .pdf) != BooknoIdentity.note(ExchangeFixture.noteID, format: .pdf, kind: .learning))
    let restored = try JSONDecoder().decode(BooknoBookDTO.self, from: BooknoExchangeCodec.canonical(original))
    #expect(restored.externalID == original.externalID)
}

@Test func booknoPDFRoundtripPreservesExactUnicodeBodyCoordinatesAndLocalRevision() throws {
    let note = try ExchangeFixture.pdfNote()
    let batch = try ExchangeFixture.batch([.book(ExchangeFixture.book()), .note(note)])
    let decoded = try BooknoExchangeCodec.decode(BooknoExchangeCodec.encode(batch))
    let restored = try #require(decoded.mutations.compactMap { if case .note(let n) = $0.payload { return n }; return nil }.first)
    #expect(Array(restored.quote.utf8) == Array(ExchangeFixture.quote.utf8))
    #expect(Array(restored.userText.utf8) == Array(note.userText.utf8))
    #expect(restored.source.offsetUnit == .pdfUserSpace && restored.localEditRevision == 12)
    #expect(decoded.mutations.last?.revision == 1)
    #expect(restored.source.anchor == note.source.anchor)
    if case .pdf(let anchor) = restored.source.anchor {
        #expect(anchor.regions[0].x == 12 && anchor.regions[0].pageIndex == 0)
        #expect(anchor.extractionVersion == "pdfkit-selection-1")
    } else { Issue.record("PDF locator lost") }
}

@Test func booknoEPUBKeepsUTF16ResourceAndCombiningSequences() throws {
    let anchor = ExchangeFixture.epubAnchor(), book = ExchangeFixture.book(format: .epub)
    let note = try BooknoExportAdapter.note(.epub(EPUBNote(id: ExchangeFixture.noteID, bookID: ExchangeFixture.bookID,
        anchor: anchor, userText: "")), book: book)
    let decoded = try BooknoExchangeCodec.decode(BooknoExchangeCodec.encode(ExchangeFixture.batch([.book(book), .note(note)])))
    #expect(note.source.offsetUnit == .utf16CodeUnit && note.userText.isEmpty)
    if case .note(let n) = decoded.mutations[1].payload, case .epub(let restored) = n.source.anchor {
        #expect(restored.start == 21 && restored.end - restored.start == ExchangeFixture.quote.utf16.count)
        #expect(restored.end - restored.start != ExchangeFixture.quote.unicodeScalars.count)
        #expect(restored.resourceHref == "OPS/chapter.xhtml" && restored.vertical)
        #expect(Array(restored.quote.utf8) == Array(ExchangeFixture.quote.utf8))
    } else { Issue.record("EPUB locator lost") }
}

@Test func booknoLearningSeparatesUserBodyAndGeneratedProvenance() throws {
    let anchor = ExchangeFixture.epubAnchor()
    let source = AISourceSnapshot(bookID: ExchangeFixture.bookID, readerSessionID: UUID(), documentVersion: 2, anchor: .epub(anchor))
    var provider = AIProviderConfig(); provider.mode = .mock
    let request = AIRequest(source: source, provider: provider, kind: .explain)
    let result = AIResult(request: request, text: "原创 mock 解释", fromCache: false)
    let dto = try BooknoExportAdapter.note(.learning(AILearningNote(id: ExchangeFixture.noteID, result: result, userText: "用户正文")),
                                          book: ExchangeFixture.book(format: .epub))
    #expect(dto.annotationKind == .learning && dto.userText == "用户正文")
    #expect(dto.aiAttachments[0].author == "ai" && dto.aiAttachments[0].text == "原创 mock 解释")
    let json = String(decoding: try BooknoExchangeCodec.canonical(dto), as: UTF8.self)
    #expect(!json.contains("readerSessionID") && !json.contains("endpoint") && !json.contains("provider"))
}

@Test func booknoRejectsWrongSourceIdentityAndForgedUnicodeQuote() throws {
    let note = try ExchangeFixture.pdfNote()
    let wrongBook = BooknoBookDTO(bookUUID: ExchangeFixture.bookID,
        edition: BooknoEditionDTO(id: UUID(), format: .pdf, sourceFileSHA256: ExchangeFixture.hash), title: "版本变化")
    let anchor = PDFSourceAnchor(editionID: ExchangeFixture.editionID, fileSHA256: ExchangeFixture.hash,
        quote: ExchangeFixture.quote, regions: [PageRegion(pageIndex: 0, x: 0, y: 0, width: 1, height: 1, quote: ExchangeFixture.quote)])
    #expect(throws: BooknoPreviewError.sourceMismatch) {
        try BooknoExportAdapter.note(.pdf(ReadingNote(bookID: ExchangeFixture.bookID, anchor: anchor)), book: wrongBook)
    }
    let batch = try ExchangeFixture.batch([.book(ExchangeFixture.book()), .note(note)])
    var json = try #require(JSONSerialization.jsonObject(with: BooknoExchangeCodec.encode(batch)) as? [String: Any])
    var mutations = try #require(json["mutations"] as? [[String: Any]])
    var payload = try #require(mutations[1]["payload"] as? [String: Any])
    var tagged = try #require(payload["note"] as? [String: Any])
    var dto = try #require(tagged["_0"] as? [String: Any])
    dto["quote"] = note.quote.precomposedStringWithCanonicalMapping; tagged["_0"] = dto; payload["note"] = tagged
    mutations[1]["payload"] = payload; json["mutations"] = mutations
    #expect(throws: BooknoPreviewError.invalidContract) { try BooknoExchangeCodec.decode(JSONSerialization.data(withJSONObject: json)) }
}

@Test func booknoSemanticHashesUseVerbatimBytesAndExcludeDiagnosticRevision() throws {
    let first = try ExchangeFixture.pdfNote(body: "か\u{3099}", revision: 1)
    let diagnostic = try ExchangeFixture.pdfNote(body: "か\u{3099}", revision: 19)
    let normalized = try ExchangeFixture.pdfNote(body: "が", revision: 1)
    #expect(try BooknoExchangeCodec.contentHash(.note(first)) == BooknoExchangeCodec.contentHash(.note(diagnostic)))
    #expect(try BooknoExchangeCodec.contentHash(.note(first)) != BooknoExchangeCodec.contentHash(.note(normalized)))
    #expect(try BooknoExchangeCodec.contentHash(.note(ExchangeFixture.pdfNote(body: " "))) != BooknoExchangeCodec.contentHash(.note(ExchangeFixture.pdfNote(body: ""))))
}

@Test func booknoCanonicalGoldenVectorUsesSortedKeysAndRawUnicode() throws {
    let expected = Data("{\"book\":\"😀\",\"title\":\"か\u{3099}\"}".utf8)
    let value = ["title": "か\u{3099}", "book": "😀"]
    #expect(try BooknoExchangeCodec.canonical(value) == expected)
    #expect(try BooknoExchangeCodec.hash(value) == "2208d213de7944da4e517a27d5197c597ca96cedabf7fbdc3d3c652013ac76aa")
}

@Test func booknoOriginalGoldenBatchFromPythonMatchesSwiftHashesAndMock() throws {
    let url = try #require(Bundle.module.url(forResource: "proposed-preview-v1", withExtension: "json", subdirectory: "Fixtures/Bookno"))
    let bytes = try Data(contentsOf: url), batch = try BooknoExchangeCodec.decode(bytes)
    #expect(batch.batchID.uuidString == "60000000-0000-0000-0000-000000000001")
    var receiver = BooknoMockReceiver(receiverID: batch.receiverID)
    let receipt = try receiver.receive(batch)
    #expect(receipt.items.count == 2 && receipt.items.allSatisfy { $0.status == .applied })
    #expect(receiver.acceptedSource(try ExchangeFixture.pdfNote().externalID) == .note(try ExchangeFixture.pdfNote()))
}

@Test func booknoEditionReplacementCannotSilentlyRetargetAnUnchangedNote() throws {
    var receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID), preview = ExchangeFixture.session()
    let note = try ExchangeFixture.pdfNote(), book = ExchangeFixture.book()
    _ = try receiver.receive(preview.stage([.book(book), .note(note)]))
    let replaced = BooknoBookDTO(bookUUID: book.bookUUID,
        edition: BooknoEditionDTO(id: UUID(), format: .pdf, sourceFileSHA256: ExchangeFixture.hash), title: book.title)
    let batch = try preview.stage([.book(replaced), .note(note)])
    #expect(throws: BooknoPreviewError.sourceMismatch) { try receiver.receive(batch) }
    #expect(receiver.acceptedSource(book.externalID) == .book(book))
    #expect(receiver.acceptedSource(note.externalID) == .note(note))
}

@Test func booknoAssetMetadataBudgetAndCoverProvenanceAreValidated() throws {
    let (asset, bytes) = try ExchangeFixture.png()
    for metadata in [
        BooknoCoverAssetDTO(sha256: asset.sha256, mimeType: "application/octet-stream", byteLength: bytes.count, width: 3, height: 4),
        BooknoCoverAssetDTO(sha256: asset.sha256, mimeType: "image/png", byteLength: bytes.count, width: 4097, height: 4),
        BooknoCoverAssetDTO(sha256: asset.sha256, mimeType: "image/png", byteLength: BooknoExchangeCodec.maximumAssetBytes + 1, width: 3, height: 4)
    ] { #expect(throws: BooknoPreviewError.assetInvalid) { try BooknoExchangeCodec.validateAsset(bytes, declaration: metadata) } }
    let book = ExchangeFixture.book()
    let forged = BooknoBookDTO(bookUUID: book.bookUUID, edition: book.edition, title: book.title,
        coverAssetID: asset.assetID, coverOrigin: .epubEmbedded, coverSourceRevision: 1)
    #expect(throws: BooknoPreviewError.invalidContract) { try BooknoExchangeCodec.validate(.book(forged)) }
}

@Test func booknoStrictReaderRefusesFutureUnknownAndBooleanSchema() throws {
    let bytes = try BooknoExchangeCodec.encode(ExchangeFixture.batch([.book(ExchangeFixture.book())]))
    for value: Any in [2, true, "1"] {
        var json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any]); json["schemaVersion"] = value
        #expect(throws: BooknoPreviewError.invalidContract) { try BooknoExchangeCodec.decode(JSONSerialization.data(withJSONObject: json)) }
    }
    var json = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: Any]); json["apiKey"] = "synthetic-unknown-field"
    #expect(throws: BooknoPreviewError.invalidContract) { try BooknoExchangeCodec.decode(JSONSerialization.data(withJSONObject: json)) }
    json.removeValue(forKey: "apiKey")
    var mutations = try #require(json["mutations"] as? [[String: Any]]); mutations[0]["futureSecret"] = "original-synthetic"
    json["mutations"] = mutations
    #expect(throws: BooknoPreviewError.invalidContract) { try BooknoExchangeCodec.decode(JSONSerialization.data(withJSONObject: json)) }
}

@Test func booknoMockLossAfterCommitRetriesSameBatchWithoutDuplicateRecords() throws {
    var preview = ExchangeFixture.session(), receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID)
    let inputs: [BooknoPayload] = [.book(ExchangeFixture.book()), .note(try ExchangeFixture.pdfNote())]
    let batch = try preview.stage(inputs)
    #expect(throws: BooknoPreviewError.mockResultUnknown) { try receiver.receive(batch, loseReceiptAfterCommit: true) }
    #expect(receiver.recordCount == 2)
    let retry = try preview.stage(inputs.reversed()), receipt = try receiver.receive(retry)
    #expect(retry.batchID == batch.batchID && retry.cursor == batch.cursor)
    #expect(try receiver.receive(retry) == receipt)
    var tracker = BooknoConfirmationTracker(receiverID: preview.receiverID, epoch: preview.epoch)
    try tracker.register(batch)
    #expect(tracker.confirmedSequence == 0 && tracker.confirmed.isEmpty)
    try tracker.acknowledge(receipt)
    #expect(tracker.confirmedSequence == 1 && tracker.confirmed.count == 2 && receiver.recordCount == 2)
    // Deserialize immutable batch after simulated sender loss; receiver outcome remains idempotent.
    #expect(try receiver.receive(BooknoExchangeCodec.decode(BooknoExchangeCodec.encode(batch))) == receipt)
}

@Test func booknoBatchIDCannotBeReusedForDifferentContent() throws {
    var receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID)
    let batch = try ExchangeFixture.batch([.book(ExchangeFixture.book())]); _ = try receiver.receive(batch)
    let changed = try ExchangeFixture.batch([.book(ExchangeFixture.book(title: "不同内容"))], id: batch.batchID)
    #expect(throws: BooknoPreviewError.batchContentMismatch) { try receiver.receive(changed) }
    #expect(receiver.acceptedSource(ExchangeFixture.book().externalID) == .book(ExchangeFixture.book()))
}

@Test func booknoEntityRevisionDedupSurvivesNewBatchIDsAndRejectsStaleOrForkedContent() throws {
    var receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID)
    _ = try receiver.receive(ExchangeFixture.batch([.book(ExchangeFixture.book())]))
    let replay = try receiver.receive(ExchangeFixture.batch([.book(ExchangeFixture.book())], sequence: 2))
    #expect(replay.items[0].status == .unchanged)
    let fork = try receiver.receive(ExchangeFixture.batch([.book(ExchangeFixture.book(title: "同修订不同内容"))], sequence: 3))
    #expect(fork.items[0].status == .revisionContentMismatch)
    let gap = try receiver.receive(ExchangeFixture.batch([.book(ExchangeFixture.book(title: "缺少基线"))], sequence: 4, revision: 3, base: 2))
    #expect(gap.items[0].status == .baseRevisionMismatch)
    _ = try receiver.receive(ExchangeFixture.batch([.book(ExchangeFixture.book(title: "新版本"))], sequence: 5, revision: 2, base: 1))
    let stale = try receiver.receive(ExchangeFixture.batch([.book(ExchangeFixture.book())], sequence: 6))
    #expect(stale.items[0].status == .staleRevision && receiver.recordCount == 1)
    #expect(receiver.acceptedSource(ExchangeFixture.book().externalID) == .book(ExchangeFixture.book(title: "新版本")))
}

@Test func booknoEpochResetDoesNotOverwritePreviouslyAcceptedData() throws {
    var receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID)
    _ = try receiver.receive(ExchangeFixture.batch([.book(ExchangeFixture.book())]))
    var restored = BooknoOfflinePreview(mode: .preview, receiverID: ExchangeFixture.receiverID, epoch: UUID())
    let receipt = try receiver.receive(restored.stage([.book(ExchangeFixture.book(title: "恢复后的不同内容"))]))
    #expect(receipt.items[0].status == .baseRevisionMismatch)
}

@Test func booknoThreeWayConflictPreservesLocalBodyAndBlocksWholeBatch() throws {
    var receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID), preview = ExchangeFixture.session()
    let first = try preview.stage([.book(ExchangeFixture.book()), .note(ExchangeFixture.pdfNote(body: "基线"))])
    _ = try receiver.receive(first)
    let noteID = try ExchangeFixture.pdfNote().externalID
    try receiver.editLocalField(noteID, field: "userText", encodedValue: BooknoExchangeCodec.canonical("Bookno 本地编辑"))
    let changed = try preview.stage([.book(ExchangeFixture.book(title: "源端改书名")), .note(ExchangeFixture.pdfNote(body: "PDFno 源端编辑"))])
    let receipt = try receiver.receive(changed)
    #expect(receipt.items.first { $0.externalID == noteID }?.status == .localEditDiverged)
    #expect(receipt.items.first { $0.externalID == ExchangeFixture.book().externalID }?.status == .blockedDependency)
    #expect(receiver.localField(noteID, field: "userText") == (try BooknoExchangeCodec.canonical("Bookno 本地编辑")))
    #expect(receiver.acceptedSource(ExchangeFixture.book().externalID) == .book(ExchangeFixture.book()))
    var tracker = BooknoConfirmationTracker(receiverID: preview.receiverID, epoch: preview.epoch)
    try tracker.register(changed); try tracker.acknowledge(receipt)
    #expect(tracker.confirmedSequence == 0 && tracker.confirmed.isEmpty)
}

@Test func booknoIndependentSourceFieldUpdateKeepsReceiverLocalEdit() throws {
    var receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID), preview = ExchangeFixture.session()
    let book = ExchangeFixture.book(), first = try preview.stage([.book(book)])
    _ = try receiver.receive(first)
    try receiver.editLocalField(book.externalID, field: "title", encodedValue: BooknoExchangeCodec.canonical("本地书名"))
    let source = BooknoBookDTO(bookUUID: book.bookUUID, edition: book.edition, title: book.title, authors: ["源端作者"])
    let receipt = try receiver.receive(preview.stage([.book(source)]))
    #expect(receipt.items[0].status == .applied)
    #expect(receiver.localField(book.externalID, field: "title") == (try BooknoExchangeCodec.canonical("本地书名")))
    #expect(receiver.localField(book.externalID, field: "authors") == (try BooknoExchangeCodec.canonical(["源端作者"])))
}

@Test func booknoMissingParentAndWrongEditionNeverCreateOrphanNotes() throws {
    var receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID)
    let missing = try receiver.receive(ExchangeFixture.batch([.note(ExchangeFixture.pdfNote())]))
    #expect(missing.items[0].status == .missingParent && receiver.recordCount == 0)
    let wrong = BooknoBookDTO(bookUUID: ExchangeFixture.bookID,
        edition: BooknoEditionDTO(id: UUID(), format: .pdf, sourceFileSHA256: ExchangeFixture.hash), title: "版本不同")
    #expect(throws: BooknoPreviewError.sourceMismatch) {
        try receiver.receive(ExchangeFixture.batch([.book(wrong), .note(ExchangeFixture.pdfNote())]))
    }
    #expect(receiver.recordCount == 0)
}

@Test func booknoCoverAdapterExcludesResourcePathsAndSharesAssetByHash() throws {
    let (asset, bytes) = try ExchangeFixture.png()
    let identity = LocalBookIdentity(format: .pdf, bookID: ExchangeFixture.bookID, editionID: ExchangeFixture.editionID, fileSHA256: ExchangeFixture.hash)
    let cover = CoverRecord(identity: CoverIdentity(bookID: identity.bookID, editionID: identity.editionID, fileSHA256: identity.fileSHA256, format: .pdf),
        origin: .userImage, imageSHA256: asset.sha256, byteLength: asset.byteLength, width: 3, height: 4, revision: 9, extractorVersion: "original-fixture-1")
    let (dto, declared) = try BooknoExportAdapter.book(LibrarySearchBook(identity: identity, title: "原创封面"), cover: cover)
    #expect(declared == asset && dto.coverSourceRevision == 9)
    let second = BooknoBookDTO(bookUUID: UUID(), edition: dto.edition, title: "另一独立书", coverAssetID: asset.assetID, coverOrigin: .userImage, coverSourceRevision: 1)
    var preview = ExchangeFixture.session(), receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID)
    let batch = try preview.stage([.book(dto), .book(second)], assets: [asset])
    let json = String(decoding: try BooknoExchangeCodec.encode(batch), as: UTF8.self)
    #expect(!json.contains("originalFilename") && !json.contains("resourcePath") && !json.contains("transferRef"))
    let receipt = try receiver.receive(batch, assetBytes: [asset.assetID: bytes])
    #expect(receiver.assetCount == 1 && receiver.recordCount == 2 && receipt.verifiedAssetIDs == [asset.assetID])
    let replay = try ExchangeFixture.batch([.book(dto), .book(second)], sequence: 2, assets: [asset])
    #expect(try receiver.receive(replay).items.allSatisfy { $0.status == .unchanged })
    #expect(receiver.assetCount == 1)
}

@Test func booknoCoverBytesMissingCorruptOrWrongTypeNeverConfirmOrPartiallyCommit() throws {
    let (asset, bytes) = try ExchangeFixture.png(), batch = try ExchangeFixture.batch([.book(ExchangeFixture.book(cover: asset))], assets: [asset])
    var receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID)
    #expect(throws: BooknoPreviewError.assetMissing) { try receiver.receive(batch) }
    #expect(throws: BooknoPreviewError.assetInvalid) { try receiver.receive(batch, assetBytes: [asset.assetID: Data("not an image".utf8)]) }
    let forged = BooknoCoverAssetDTO(sha256: asset.sha256, mimeType: "image/jpeg", byteLength: bytes.count, width: 3, height: 4)
    #expect(throws: BooknoPreviewError.assetInvalid) { try BooknoExchangeCodec.validateAsset(bytes, declaration: forged) }
    let wrongSize = BooknoCoverAssetDTO(sha256: asset.sha256, mimeType: "image/png", byteLength: bytes.count, width: 4, height: 3)
    #expect(throws: BooknoPreviewError.assetInvalid) { try BooknoExchangeCodec.validateAsset(bytes, declaration: wrongSize) }
    #expect(receiver.recordCount == 0 && receiver.assetCount == 0)
}

@Test func booknoLocalCoverEditConflictKeepsExistingAssetReference() throws {
    let (old, oldBytes) = try ExchangeFixture.png(), (new, newBytes) = try ExchangeFixture.png(red: false)
    var receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID), preview = ExchangeFixture.session()
    let first = try preview.stage([.book(ExchangeFixture.book(cover: old))], assets: [old])
    _ = try receiver.receive(first, assetBytes: [old.assetID: oldBytes])
    let local = try BooknoExchangeCodec.canonical("Bookno-local-cover-reference")
    try receiver.editLocalField(ExchangeFixture.book().externalID, field: "cover", encodedValue: local)
    let next = try preview.stage([.book(ExchangeFixture.book(cover: new))], assets: [new])
    let receipt = try receiver.receive(next, assetBytes: [new.assetID: newBytes])
    #expect(receipt.items[0].status == .localEditDiverged && receipt.verifiedAssetIDs.isEmpty)
    #expect(receiver.assetCount == 1 && receiver.localField(ExchangeFixture.book().externalID, field: "cover") == local)
    var tracker = BooknoConfirmationTracker(receiverID: preview.receiverID, epoch: preview.epoch)
    try tracker.register(next); try tracker.acknowledge(receipt)
    #expect(tracker.confirmed.isEmpty && tracker.confirmedSequence == 0)
}

@Test func booknoTombstonesAndAbsentEntitiesArePreviewOnly() throws {
    var receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID)
    let note = try ExchangeFixture.pdfNote()
    _ = try receiver.receive(ExchangeFixture.batch([.book(ExchangeFixture.book()), .note(note)]))
    let tombstone = BooknoTombstoneDTO(kind: .note, externalID: note.externalID, lastKnownRevision: 1)
    let receipt = try receiver.receive(ExchangeFixture.batch([], sequence: 2, tombstones: [tombstone]))
    #expect(receipt.deletionPreviewIDs == [note.externalID] && receiver.recordCount == 2)
    #expect(receiver.acceptedSource(note.externalID) == .note(note))
    _ = try receiver.receive(ExchangeFixture.batch([.book(ExchangeFixture.book())], sequence: 3))
    #expect(receiver.recordCount == 2)
}

@Test func booknoLateReceiptAndOutOfOrderCursorCannotRegressConfirmation() throws {
    var preview = ExchangeFixture.session(), receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID)
    let first = try preview.stage([.book(ExchangeFixture.book())]), a = try receiver.receive(first)
    let second = try preview.stage([.book(ExchangeFixture.book(title: "第二版"))]), b = try receiver.receive(second)
    var tracker = BooknoConfirmationTracker(receiverID: preview.receiverID, epoch: preview.epoch)
    try tracker.register(first); try tracker.register(second); try tracker.acknowledge(b)
    #expect(tracker.confirmedSequence == 0 && tracker.confirmed[ExchangeFixture.book().externalID]?.revision == 2)
    try tracker.acknowledge(a); try tracker.acknowledge(a)
    #expect(tracker.confirmedSequence == 2 && tracker.confirmed[ExchangeFixture.book().externalID]?.revision == 2)
}

@Test func booknoForgedReceiptHashAndReceiverDoNotAdvanceCursor() throws {
    var preview = ExchangeFixture.session(), receiver = BooknoMockReceiver(receiverID: ExchangeFixture.receiverID)
    let batch = try preview.stage([.book(ExchangeFixture.book())]), good = try receiver.receive(batch)
    var tracker = BooknoConfirmationTracker(receiverID: preview.receiverID, epoch: preview.epoch); try tracker.register(batch)
    let forged = BooknoMockReceipt(receiverID: UUID(), batchID: good.batchID, batchHash: good.batchHash, cursor: good.cursor,
        items: good.items, verifiedAssetIDs: [], deletionPreviewIDs: [])
    #expect(throws: BooknoPreviewError.receiptMismatch) { try tracker.acknowledge(forged) }
    let wrongHash = BooknoMockReceipt(receiverID: good.receiverID, batchID: good.batchID, batchHash: good.batchHash, cursor: good.cursor,
        items: [BooknoReceiptItem(externalID: good.items[0].externalID, revision: 1, contentHash: ExchangeFixture.hash, status: .applied)],
        verifiedAssetIDs: [], deletionPreviewIDs: [])
    #expect(throws: BooknoPreviewError.receiptMismatch) { try tracker.acknowledge(wrongHash) }
    #expect(tracker.confirmed.isEmpty && tracker.confirmedSequence == 0)
}
