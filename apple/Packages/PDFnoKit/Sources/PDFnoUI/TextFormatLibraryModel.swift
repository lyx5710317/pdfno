// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import SwiftUI
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

/// Independent format slice. The shared LibraryModel only routes imports and active-reader state.
@MainActor public final class TextFormatLibraryModel: ObservableObject {
    @Published public private(set) var books: [TextFormatBook] = []
    @Published public private(set) var notes: [TextFormatNote] = []
    @Published public private(set) var isActive = false
    @Published public private(set) var busy = false
    @Published public var error: String?
    public let reader = TextFormatReaderSession()
    public let repository: TextFormatRepository
    private var activationGeneration = UUID()
    let storageRoot: URL
    public init(root: URL) { storageRoot = root; repository = TextFormatRepository(root: root) }
    public func load() async throws {
        let state = try await repository.load(); books = state.books; notes = state.notes
    }
    public func deactivate() { activationGeneration = UUID(); isActive = false; reader.close() }
    public func importFile(_ url: URL) async throws {
        let hostOperation = try LocalStoreWriteGate.shared(root: storageRoot).beginWrite()
        defer { hostOperation.finish() }
        guard !busy else { return }; busy = true; defer { busy = false }
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let book = try await repository.importFile(url); try await load(); try await activate(book)
    }
    public func open(_ book: TextFormatBook) async throws {
        let hostOperation = try LocalStoreWriteGate.shared(root: storageRoot).beginWrite()
        defer { hostOperation.finish() }
        guard !busy else { return }; busy = true; defer { busy = false }
        try await load()
        guard let current = books.first(where: { $0.id == book.id }) else { throw TextFormatError.sourceMismatch }
        try await activate(current)
    }
    private func activate(_ book: TextFormatBook) async throws {
        activationGeneration = UUID(); let token = activationGeneration
        let data = try await repository.read(book)
        guard token == activationGeneration else { throw TextFormatError.cancelled }
        isActive = true
        try await reader.open(data: data, book: book, notes: notes)
        guard token == activationGeneration, let document = reader.document else { throw TextFormatError.cancelled }
        let session = reader.readerSessionID
        try await repository.bindRenderedDocument(document, book: book)
        guard token == activationGeneration, session == reader.readerSessionID, reader.ready else { throw TextFormatError.cancelled }
    }
    public func saveNote(_ anchor: TextFormatAnchor, text: String) async -> Bool {
        guard let hostOperation = try? LocalStoreWriteGate.shared(root: storageRoot).beginWrite() else { return false }
        defer { hostOperation.finish() }
        guard !busy, let book = reader.book, book.accepts(anchor), reader.document?.resolves(anchor) == true else {
            error = TextFormatError.sourceMismatch.localizedDescription; return false
        }
        do {
            try await repository.saveNote(TextFormatNote(bookID: book.id, anchor: anchor, userText: text))
            try await load(); reader.project(notes); return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func publishEditedNote(_ note: TextFormatNote, session: UUID?) {
        if let index = notes.firstIndex(where: { $0.id == note.id && $0.bookID == note.bookID }) { notes[index] = note }
        if isActive, let session, reader.readerSessionID == session, reader.book?.id == note.bookID { reader.project(notes) }
    }
    public func saveProgress(_ anchor: TextFormatAnchor) async {
        guard let hostOperation = try? LocalStoreWriteGate.shared(root: storageRoot).beginWrite() else { return  }
        defer { hostOperation.finish() }
        guard !busy, let book = reader.book, book.accepts(anchor), reader.document?.resolves(anchor) == true else { return }
        do { try await repository.saveProgress(anchor, bookID: book.id) }
        catch { self.error = error.localizedDescription }
    }
}
#endif
