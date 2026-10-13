// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import Combine
import PDFKit
import PDFnoDomain
import PDFnoServices

struct DocumentConversationAnswer: Identifiable {
    let id = UUID()
    let question: String
    let text: String
}
@MainActor final class DocumentConversationModel: ObservableObject {
    @Published private(set) var source: DocumentConversationSource?
    @Published private(set) var answers: [DocumentConversationAnswer] = []
    @Published private(set) var loading = false
    @Published private(set) var busy = false
    @Published private(set) var confirmed = false
    @Published var draft = ""
    @Published private(set) var error: String?
    private weak var library: LibraryModel?
    private var providerAtConfirmation: AIProviderConfig?
    private var turns: [DocumentConversationTurn] = []
    private var operation: Task<Void, Never>?
    private var generation = UUID()
    private var connectionChanges: AnyCancellable?
    init(library: LibraryModel) {
        self.library = library
        connectionChanges = library.learning.$config.combineLatest(library.learning.$hasSessionCredential)
            .removeDuplicates(by: { ReadingSkillIdentity.matches($0.0,$1.0) && $0.1 == $1.1 }).dropFirst()
            .sink { [weak self] _, _ in
                guard let self else { return }
                stop(); confirmed = false; providerAtConfirmation = nil; turns = []
            }
    }
    var connectionAvailable: Bool { library?.learning.conversationConnectionAvailable == true }
    var receiverDescription: String {
        guard let config = library?.learning.config else { return "未配置" }
        if config.mode == .mock { return "本地示例（不联网）" }
        return ((try? BYOKSelectionPolicy.finalURL(config).host) ?? "未配置") + " · " + config.model
    }
    var hasUnsavedWork: Bool { !draft.isEmpty || !answers.isEmpty }
    func prepare() async {
        guard !loading, let library else { return }
        if let source, library.isCurrentDocumentConversationSource(source) { return }
        discard(); loading = true; let token = generation
        do {
            let value = try await library.captureDocumentConversationSource()
            guard generation == token else { return }
            guard library.isCurrentDocumentConversationSource(value) else {
                loading = false; error = DocumentConversationFailure.cancelled.localizedDescription; return
            }
            source = value; loading = false
        } catch {
            guard generation == token else { return }
            self.error = error.localizedDescription; loading = false
        }
    }
    func confirmAndStart() {
        guard let library, let source, library.isCurrentDocumentConversationSource(source), connectionAvailable else { return }
        providerAtConfirmation = library.learning.config; confirmed = true
        send("请概述这份文档的主要内容。")
    }
    func sendFollowup() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }; send(question)
    }
    private func send(_ question: String) {
        guard !busy, confirmed, let library, let source, let config = providerAtConfirmation else { return }
        guard library.isCurrentDocumentConversationSource(source), ReadingSkillIdentity.matches(config, library.learning.config), connectionAvailable else {
            confirmed = false; error = DocumentConversationFailure.cancelled.localizedDescription; return
        }
        let plan: DocumentConversationPlan, provider: any DocumentConversationProvider
        do {
            plan = try DocumentConversationPlan(source: source, provider: config, history: turns, question: question)
            provider = try library.learning.documentConversationProvider()
        } catch { self.error = error.localizedDescription; return }
        let token = UUID(); generation = token; busy = true; error = nil
        let coordinator = DocumentConversationCoordinator()
        operation = Task { [weak self] in
            do {
                let text = try await coordinator.run(plan, confirmed: true, provider: provider)
                guard let self, generation == token else { return }
                guard self.confirmed, library.isCurrentDocumentConversationSource(source),
                      ReadingSkillIdentity.matches(config, library.learning.config) else {
                    discard(); return
                }
                turns += [.init(role: .user, text: question, sourceIdentity: source.identity),
                          .init(role: .assistant, text: text, sourceIdentity: source.identity)]
                answers.append(.init(question: question, text: text)); draft = ""; busy = false; operation = nil
            } catch {
                guard let self, generation == token else { return }
                self.error = error.localizedDescription; busy = false; operation = nil
            }
        }
    }
    func sourceDidChange() {
        guard let source, library?.isCurrentDocumentConversationSource(source) != true else { return }
        discard()
    }
    /// Published session changes arrive before the reader property is updated.
    func readerSessionDidChange(_ sessionID: UUID) {
        if loading || source.map({ $0.readerSessionID != sessionID }) == true { discard() }
    }
    func stop() { generation = UUID(); operation?.cancel(); operation = nil; busy = false }
    func discard() {
        stop(); source = nil; answers = []; turns = []; draft = ""; error = nil
        loading = false; confirmed = false; providerAtConfirmation = nil
    }
}
extension LibraryModel {
    func isCurrentDocumentConversationSource(_ source: DocumentConversationSource) -> Bool {
        guard !storageMaintenance else { return false }
        if source.format == "EPUB" {
            return readingEPUB && epub.book?.id == source.bookID && epub.readerSessionID == source.readerSessionID && epub.book?.fileSHA256 == source.fileSHA256
        }
        return !readingEPUB && reader.book?.id == source.bookID && reader.readerSessionID == source.readerSessionID && reader.book?.fileSHA256 == source.fileSHA256
    }
    func captureDocumentConversationSource() async throws -> DocumentConversationSource {
        guard !storageMaintenance else { throw DocumentConversationFailure.cancelled }
        if readingEPUB, let book = epub.book {
            let session = epub.readerSessionID, deadline = Date().addingTimeInterval(3)
            while epub.busy && Date() < deadline { try await Task.sleep(for: .milliseconds(50)) }
            let text = try await epub.captureCompleteDocumentText()
            return try DocumentConversationSource(bookID: book.id, readerSessionID: session,
                fileSHA256: book.fileSHA256, format: "EPUB", text: text)
        }
        guard let book = reader.book, let document = reader.document else { throw DocumentConversationFailure.incomplete }
        let session = reader.readerSessionID
        var parts: [String] = [], count = 0
        for index in 0..<document.pageCount {
            guard let text = document.page(at: index)?.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DocumentConversationFailure.incomplete }
            count += text.utf16.count + (parts.isEmpty ? 0 : 2)
            guard count <= DocumentConversationSource.maxTextUTF16 else { throw DocumentConversationFailure.tooLarge }
            parts.append(text)
        }
        return try DocumentConversationSource(bookID: book.id, readerSessionID: session,
            fileSHA256: book.fileSHA256, format: "PDF", text: parts.joined(separator: "\n\n"))
    }
}
#endif
