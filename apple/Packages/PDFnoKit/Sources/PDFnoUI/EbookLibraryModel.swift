// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import SwiftUI
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

/// Independent format slice. The shared LibraryModel only routes imports and active-reader state.
@MainActor public final class EbookLibraryModel: ObservableObject {
    var lastCreatedImport: BundledExampleIdentity?
    @Published public private(set) var books: [EbookBook] = []
    @Published public private(set) var notes: [EbookNote] = []
    @Published public private(set) var isActive = false
    @Published public private(set) var busy = false
    @Published public var error: String?
    public let reader = EbookReaderSession()
    public let repository: EbookRepository
    let storageRoot: URL
    public init(root: URL) { storageRoot = root; repository = EbookRepository(root: root) }
    public func load() async throws {
        let state = try await repository.load(); books = state.books; notes = state.notes
    }
    public func deactivate() { isActive = false; reader.close() }
    public func importFile(_ url: URL) async throws {
        lastCreatedImport = nil
        let hostOperation = try LocalStoreWriteGate.shared(root: storageRoot).beginWrite()
        defer { hostOperation.finish() }
        guard !busy else { throw EbookError.cancelled }; busy = true; defer { busy = false }
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try await Task.detached { try BoundedFileReader.read(url, limit: 8 * 1024 * 1024) }.value
        guard let format = EbookFormat(rawValue: url.pathExtension.lowercased()) else { throw EbookError.unsupportedContent }
        let kind = try await Task.detached { try EbookPreflight.validate(data, format: format) }.value
        let candidate = EbookBook(fileSHA256: LibraryRepository.digest(data), format: format, contentKind: kind, title: url.deletingPathExtension().lastPathComponent, originalFilename: url.lastPathComponent)
        try await reader.open(data: data, book: candidate, notes: [])
        guard let document = reader.document else { throw EbookError.bridge }
        let imported = try await repository.importBookWithStatus(data, filename: url.lastPathComponent, candidate: candidate)
        let book = imported.book
        if imported.created { lastCreatedImport = .init(format: book.format.rawValue, bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256) }
        try await repository.bindRenderedDocument(document, book: book)
        try await load(); try await activate(book)
    }
    public func open(_ book: EbookBook) async throws {
        let hostOperation = try LocalStoreWriteGate.shared(root: storageRoot).beginWrite()
        defer { hostOperation.finish() }
        guard !busy else { throw EbookError.cancelled }; busy = true; defer { busy = false }
        try await load()
        guard let current = books.first(where: { $0.id == book.id }) else { throw EbookError.sourceMismatch }
        try await activate(current)
    }
    private func activate(_ book: EbookBook) async throws {
        let data = try await repository.read(book)
        try await reader.open(data: data, book: book, notes: notes)
        guard let document = reader.document else { throw EbookError.bridge }
        try await repository.bindRenderedDocument(document, book: book); isActive = true
    }
    public func saveNote(_ anchor: EbookAnchor, text: String) async -> Bool {
        guard let hostOperation = try? LocalStoreWriteGate.shared(root: storageRoot).beginWrite() else { return false }
        defer { hostOperation.finish() }
        guard !busy, let book = reader.book, book.accepts(anchor), reader.document?.resolves(anchor) == true else {
            error = EbookError.sourceMismatch.localizedDescription; return false
        }
        do {
            try await repository.saveNote(EbookNote(bookID: book.id, anchor: anchor, userText: text))
            try await load(); reader.project(notes); return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func publishEditedNote(_ note: EbookNote, session: UUID?) {
        if let index = notes.firstIndex(where: { $0.id == note.id && $0.bookID == note.bookID }) { notes[index] = note }
        if isActive, let session, reader.readerSessionID == session, reader.book?.id == note.bookID { reader.project(notes) }
    }
    public func saveProgress(_ anchor: EbookAnchor) async {
        guard let hostOperation = try? LocalStoreWriteGate.shared(root: storageRoot).beginWrite() else { return  }
        defer { hostOperation.finish() }
        guard !busy, let book = reader.book, book.accepts(anchor), reader.document?.resolves(anchor) == true else { return }
        do { try await repository.saveProgress(anchor, bookID: book.id) }
        catch { self.error = error.localizedDescription }
    }
}
#endif
