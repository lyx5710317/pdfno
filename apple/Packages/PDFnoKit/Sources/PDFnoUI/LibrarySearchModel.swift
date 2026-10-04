// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import SwiftUI
import PDFnoDomain
import PDFnoServices

@MainActor public final class LibrarySearchModel: ObservableObject {
    enum Phase: Equatable { case idle, searching, results, cancelled, failed }
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var response = LibrarySearchResponse(books: [], groups: [], totalCount: 0)
    @Published private(set) var error: String?
    private let search: @Sendable (String) async throws -> LibrarySearchResponse
    private let metadata: LocalBookMetadataRepository
    private let debounce: Duration
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private(set) var query = ""
    public convenience init(root: URL) {
        let repository = LibrarySearchRepository(root: root)
        self.init(root: root, debounce: .milliseconds(180), search: { try await repository.search($0) })
    }
    init(root: URL, debounce: Duration, search: @escaping @Sendable (String) async throws -> LibrarySearchResponse) {
        self.search = search; self.debounce = debounce; metadata = LocalBookMetadataRepository(root: root)
    }
    func updateQuery(_ value: String) {
        query = value; generation = UUID(); let token = generation
        task?.cancel(); error = nil
        response = LibrarySearchResponse(books: response.books, groups: [], totalCount: 0)
        let empty = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        phase = empty ? .idle : .searching
        let search = self.search, delay = debounce
        task = Task { [weak self] in
            do {
                if !empty { try await Task.sleep(for: delay) }
                let result = try await search(value)
                try Task.checkCancellation()
                guard let self, self.generation == token else { return }
                self.response = result; self.phase = empty ? .idle : .results
            } catch is CancellationError {
                // The newer generation owns the visible state.
            } catch {
                guard let self, self.generation == token, !Task.isCancelled else { return }
                self.error = (error as? LibrarySearchFailure)?.localizedDescription ?? LibrarySearchFailure.store.localizedDescription
                self.response = LibrarySearchResponse(books: [], groups: [], totalCount: 0); self.phase = .failed
            }
        }
    }
    /// Integration hook: existing note/import publishers call this after a successful repository reload.
    /// Also supports explicit refresh when an editor does not publish a new array.
    func refresh() { updateQuery(query) }
    func cancel() {
        generation = UUID(); task?.cancel(); task = nil
        response = LibrarySearchResponse(books: response.books, groups: [], totalCount: 0)
        phase = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .idle : .cancelled
    }
    func waitForSearch() async { await task?.value }
    func saveMetadata(_ book: LibrarySearchBook, title: String, author: String) async -> Bool {
        do {
            let current = try await search("")
            guard current.books.contains(where: { $0.identity == book.identity && $0.metadataRevision == book.metadataRevision }) else { throw LibrarySearchFailure.metadataConflict }
            try await metadata.save(book: book.identity, title: title, author: author, expectedRevision: book.metadataRevision)
            refresh(); await waitForSearch(); return true
        } catch { self.error = (error as? LibrarySearchFailure)?.localizedDescription ?? LibrarySearchFailure.store.localizedDescription; return false }
    }
}
