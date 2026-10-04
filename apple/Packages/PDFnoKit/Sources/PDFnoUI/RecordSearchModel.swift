// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import SwiftUI
import Combine
import PDFnoDomain
import PDFnoServices

/// Independent controllers for additional records or a single combined search; retained by the integration host.
/// Query generations suppress even injected backends that ignore cancellation.
typealias RecordSearchModel = SavedSearchModel<RecordSearchResponse>
typealias SavedRecordSearchModel = SavedSearchModel<SavedRecordSearchResponse>

@MainActor
final class SavedSearchModel<Response: SavedSearchResponse>: ObservableObject {
    enum Phase: Equatable { case idle, searching, results, cancelled, failed }
    @Published private(set) var response = Response.emptySearchResponse
    @Published private(set) var phase: Phase = .idle
    @Published private(set) var error: String?
    private let search: @Sendable (String) async throws -> Response
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var subscriptions: Set<AnyCancellable> = []
    private var query = ""
    init(search: @escaping @Sendable (String) async throws -> Response) { self.search = search }
    func observeChanges(in library: LibraryModel) {
        stopObservingChanges()
        library.$notes.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.$epubNotes.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.$comicBooks.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.docx.$books.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.docx.$notes.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.learning.$notes.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.textFormats.$books.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.textFormats.$notes.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.ebook.$books.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.ebook.$notes.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.$japaneseNotes.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.$books.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
        library.$epubBooks.dropFirst().sink { [weak self] _ in self?.refresh() }.store(in: &subscriptions)
    }
    func stopObservingChanges() { subscriptions.removeAll() }
    func updateQuery(_ value: String) {
        query = value; generation = UUID(); let token = generation
        task?.cancel(); response = Response.emptySearchResponse; error = nil
        let empty = value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        phase = empty ? .idle : .searching
        guard !empty || Response.loadsCatalogForEmptyQuery else { task = nil; return }
        let search = self.search
        task = Task { [weak self] in
            do {
                if !empty { try await Task.sleep(for: .milliseconds(180)) }
                let result = try await search(value); try Task.checkCancellation()
                guard let self, generation == token else { return }
                response = result; phase = empty ? .idle : .results
            } catch is CancellationError { }
            catch {
                guard let self, generation == token, !Task.isCancelled else { return }
                response = Response.emptySearchResponse; phase = .failed; self.error = LibrarySearchFailure.store.localizedDescription
                if let failure = error as? LibrarySearchFailure { self.error = failure.localizedDescription }
            }
        }
    }
    func refresh() { updateQuery(query) }
    func cancel() { generation = UUID(); task?.cancel(); task = nil; response = Response.emptySearchResponse; phase = query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .idle : .cancelled }
    func waitForSearch() async { await task?.value }
}
extension SavedSearchModel where Response == RecordSearchResponse {
    convenience init(root: URL) {
        let repository = RecordSearchRepository(root: root)
        self.init(search: { try await repository.search($0) })
    }
}
extension SavedSearchModel where Response == SavedRecordSearchResponse {
    convenience init(root: URL) {
        let repository = SavedRecordSearchRepository(root: root)
        self.init(search: { try await repository.search($0) })
    }
}
#endif
