// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import SwiftUI
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

/// Independent format slice. The shared LibraryModel only routes imports and active-reader state.
@MainActor public final class DOCXLibraryModel: ObservableObject {
    var lastCreatedImport: BundledExampleIdentity?
    @Published public private(set) var books: [DOCXBook] = []
    @Published public private(set) var notes: [DOCXNote] = []
    @Published public private(set) var isActive = false
    @Published public private(set) var busy = false
    @Published public var error: String?
    public let reader = DOCXReaderSession()
    public let repository: DOCXRepository
    let storageRoot: URL
    public init(root: URL) { storageRoot = root; repository = DOCXRepository(root: root) }
    public func load() async throws {
        let state = try await repository.load(); books = state.books; notes = state.notes
    }
    public func deactivate() { isActive = false; reader.close() }
    public func importFile(_ url: URL) async throws {
        lastCreatedImport = nil
        let hostOperation = try LocalStoreWriteGate.shared(root: storageRoot).beginWrite()
        defer { hostOperation.finish() }
        guard !busy else { return }; busy = true; defer { busy = false }
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let imported = try await repository.importFileWithStatus(url)
        let book = imported.book
        if imported.created { lastCreatedImport = .init(format: "docx", bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256) }; try await load(); try await activate(book)
    }
    public func open(_ book: DOCXBook) async throws {
        let hostOperation = try LocalStoreWriteGate.shared(root: storageRoot).beginWrite()
        defer { hostOperation.finish() }
        guard !busy else { return }; busy = true; defer { busy = false }
        try await load()
        guard let current = books.first(where: { $0.id == book.id }) else { throw DOCXError.sourceMismatch }
        try await activate(current)
    }
    private func activate(_ book: DOCXBook) async throws {
        let data = try await repository.read(book)
        try await reader.open(data: data, book: book, notes: notes)
        guard let document = reader.document else { throw DOCXError.bridge }
        try await repository.bindRenderedDocument(document, book: book); isActive = true
    }
    public func saveNote(_ anchor: DOCXAnchor, text: String) async -> Bool {
        guard let hostOperation = try? LocalStoreWriteGate.shared(root: storageRoot).beginWrite() else { return false }
        defer { hostOperation.finish() }
        guard !busy, let book = reader.book, book.accepts(anchor), reader.document?.resolves(anchor) == true else {
            error = DOCXError.sourceMismatch.localizedDescription; return false
        }
        do {
            try await repository.saveNote(DOCXNote(bookID: book.id, anchor: anchor, userText: text))
            try await load(); reader.project(notes); return true
        } catch { self.error = error.localizedDescription; return false }
    }
    public func saveProgress(_ anchor: DOCXAnchor) async {
        guard let hostOperation = try? LocalStoreWriteGate.shared(root: storageRoot).beginWrite() else { return  }
        defer { hostOperation.finish() }
        guard !busy, let book = reader.book, book.accepts(anchor), reader.document?.resolves(anchor) == true else { return }
        do { try await repository.saveProgress(anchor, bookID: book.id) }
        catch { self.error = error.localizedDescription }
    }
}
#endif
