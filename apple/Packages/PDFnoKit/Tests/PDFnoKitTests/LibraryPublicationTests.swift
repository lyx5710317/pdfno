// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Combine
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

/// Observe the actual collection used by the visible library during reload.
/// Keep original fixture roots as evidence; no app, credential or network calls.
@MainActor struct LibraryPublicationTests {
    private func root() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Publication-Original-" + UUID().uuidString)
    }
    private func identity(_ book: BookRecord) -> BundledExampleIdentity {
        .init(format: "pdf", bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256)
    }

    @Test(arguments: [false, true])
    func restoredExampleNeverAppearsAsPersonalDuringPublication(withDraft: Bool) async throws {
        let root = root(), bytes = try originalSample(), repository = LibraryRepository(root: root)
        let book = try await repository.importPDF(bytes, filename: "study-sample.pdf", pageCount: 2)
        let source = identity(book)
        _ = try await BundledExampleRepository(root: root).registerNewImport(source, resource: "study-sample.pdf",
            existingBookIDs: [], newImport: true, bundledSHA256: LibraryRepository.digest(bytes))
        let note = ReadingNote(bookID: book.id, anchor: PDFSourceAnchor(editionID: book.editionID,
            fileSHA256: book.fileSHA256, quote: "window",
            regions: [PageRegion(pageIndex: 0, x: 72, y: 650, width: 40, height: 16, quote: "window")]),
            userText: "Original committed body")
        try await repository.saveNote(note)
        let snapshot = NoteBodySnapshot.pdf(note), draft = "Original recovered 日本語🌸 cafe\u{301}"
        var draftOwner: LibraryModel?
        if withDraft {
            let owner = LibraryModel(root: root, aiSession: AppAISession())
            await owner.load()
            owner.noteEditing.begin(snapshot); owner.noteEditing.setText(draft, for: snapshot)
            draftOwner = owner
        }
        let before = try Data(contentsOf: root.appendingPathComponent("library-v1.json"))
        let model = LibraryModel(root: root, aiSession: AppAISession())
        var classifications: [Bool] = []
        let observation = model.$books.sink { published in
            if published.contains(where: { $0.id == book.id }) {
                classifications.append(model.isBundledExample(source))
            }
        }
        await model.load(); observation.cancel()
        #expect(!classifications.isEmpty)
        #expect(classifications.allSatisfy { $0 })
        #expect(model.books.map(\.id) == [book.id] && model.isBundledExample(source))
        #expect(model.notes == [note])
        #expect(try Data(contentsOf: root.appendingPathComponent("library-v1.json")) == before)
        #expect(try await repository.readAsset(for: book) == bytes)
        if withDraft {
            #expect(model.noteEditing.drafts[snapshot.key]?.text.utf8.elementsEqual(draft.utf8) == true)
            #expect(draftOwner?.noteEditing.drafts[snapshot.key]?.text == draft)
        }
    }

    @Test func personalBookNamedLikeExampleStaysPersonalDuringPublication() async throws {
        let root = root(), repository = LibraryRepository(root: root)
        let book = try await repository.importPDF(originalSample(), filename: "study-sample.pdf", pageCount: 2)
        let source = identity(book), model = LibraryModel(root: root, aiSession: AppAISession())
        var classifications: [Bool] = []
        let observation = model.$books.sink { published in
            if published.contains(where: { $0.id == book.id }) { classifications.append(model.isBundledExample(source)) }
        }
        await model.load(); observation.cancel()
        #expect(!classifications.isEmpty && classifications.allSatisfy { !$0 })
        #expect(model.bundledExamples.isEmpty && !model.isBundledExample(source))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("bundled-examples-v1.json").path))
    }
}
#endif
