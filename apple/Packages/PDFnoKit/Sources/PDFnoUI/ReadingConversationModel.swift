// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import Combine
import PDFnoDomain
import PDFnoServices

struct ReadingConversationAnswer: Identifiable {
    let result: AIResult
    let question: String
    var id: UUID { result.requestID }
}
struct ReadingConversationThread: Identifiable {
    let id: UUID
    let identity: String
    let task: ReadingConversationTask
    let source: AISourceSnapshot
    var turns: [ReadingConversationTurn] = []
    var answers: [ReadingConversationAnswer] = []
    var draft = ""
    var pendingQuestion: String?
    var failedQuestion: String?
    var failedAnswerID: UUID?
    var status = ""
    var invalidated = false
}
/// This owner belongs to one document tab. Hiding a rail/sheet retains it; document close discards it.
@MainActor final class ReadingConversationModel: ObservableObject {
    @Published private(set) var threads: [ReadingConversationThread] = []
    @Published private(set) var currentID: UUID?
    @Published private(set) var busy = false
    @Published private(set) var savedAnswers: Set<UUID> = []
    @Published private(set) var savingAnswers: Set<UUID> = []
    @Published var saveStatus: String?
    private weak var library: LibraryModel?
    private var operation: Task<Void, Never>?
    private var generation = UUID()
    private var configurationChanges: AnyCancellable?
    private var toolChanges: AnyCancellable?
    init(library: LibraryModel) {
        self.library = library
        configurationChanges = library.learning.$config.combineLatest(library.learning.$hasSessionCredential)
            .removeDuplicates(by: { ReadingSkillIdentity.matches($0.0,$1.0) && $0.1 == $1.1 }).dropFirst()
            .sink { [weak self] _, _ in self?.stop() }
        toolChanges = library.learning.tools.$japanese.combineLatest(library.learning.tools.$english).dropFirst().sink { [weak self] japanese, english in
            guard let self, let task = current?.task else { return }
            if (task == .japanese && !japanese) || (task == .english && !english) { stop() }
        }
    }
    var current: ReadingConversationThread? { threads.first { $0.id == currentID } }
    var connectionAvailable: Bool { library?.learning.conversationConnectionAvailable == true }
    var hasUnsavedWork: Bool { threads.contains { !$0.draft.isEmpty || $0.answers.contains { !savedAnswers.contains($0.id) } } }
    private func edit(_ id: UUID, _ change: (inout ReadingConversationThread) -> Void) {
        guard let index = threads.firstIndex(where: { $0.id == id }) else { return }; change(&threads[index])
    }
    func setDraft(_ text: String) { guard let currentID else { return }; edit(currentID) { $0.draft = text } }
    func select(_ id: UUID) {
        guard threads.contains(where: { $0.id == id }) else { return }
        if id != currentID { stop() }; currentID = id
    }
    func open(_ task: ReadingConversationTask, source: AISourceSnapshot, fresh: Bool = false) {
        guard let library, !library.storageMaintenance, library.isCurrentAISource(source),
              library.learning.tools.isEnabled(task) else { return }
        guard let data = try? ReadingSkillIdentity.data(source) else { return }
        let identity = task.rawValue + ":" + ReadingSkillIdentity.digest(data)
        if !fresh, let retained = threads.last(where: { $0.identity == identity }) {
            if currentID != retained.id { stop() }
            currentID = retained.id; edit(retained.id) { $0.invalidated = false }
            if retained.answers.isEmpty, retained.failedQuestion == nil, !busy { send(task.initialQuestion) }
            return
        }
        stop()
        let thread = ReadingConversationThread(id: UUID(), identity: identity, task: task, source: source)
        threads.append(thread); currentID = thread.id; saveStatus = nil
        send(task.initialQuestion)
    }
    func sendFollowup() {
        guard let thread = current else { return }
        let question = thread.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }; send(question)
    }
    func retry() {
        guard let thread = current, let question = thread.failedQuestion else { return }
        send(question, answerID: thread.failedAnswerID ?? UUID())
    }
    func send(_ question: String, answerID: UUID = UUID()) {
        guard !busy, let library, let thread = current else { return }
        guard library.learning.tools.isEnabled(thread.task) else { edit(thread.id) { $0.status = "此工具已关闭；已有回答保留。可在设置 → AI工具重新开启。" }; return }
        guard !thread.invalidated, library.isCurrentAISource(thread.source) else { edit(thread.id) { $0.status = AIFailure.stale.localizedDescription }; return }
        guard connectionAvailable else { edit(thread.id) { $0.status = "请先在设置 → AI 配置连接与 API Key。" }; return }
        let plan: ReadingConversationPlan, provider: any ReadingConversationProvider
        do {
            plan = try ReadingConversationPlan(conversationID: thread.id, answerID: answerID, task: thread.task,
                source: thread.source, provider: library.learning.config, history: thread.turns, question: question)
            provider = try library.learning.conversationProvider()
        } catch {
            edit(thread.id) { value in
                if error as? ReadingSkillFailure == .input { value.status = "追问或对话内容过长。请缩短追问，或为这段选文新建对话。" }
                else if error as? AIFailure == .remoteInputLimit { value.status = "选文过长，请缩小选区后再试。" }
                else { value.status = ReadingSkillSelectionAdapter.hostFailure(error).localizedDescription }
            }; return
        }
        let coordinator = ReadingConversationCoordinator(), token = UUID(); generation = token; busy = true
        edit(thread.id) { $0.pendingQuestion = question; $0.failedQuestion = nil; $0.failedAnswerID = nil; $0.status = "正在生成…" }
        // The explicit task or Send/Retry click confirms precisely this immutable selection and thread.
        let consent = ReadingSkillConsent(taskID: plan.requestID, planFingerprint: plan.fingerprint)
        operation = Task { [weak self, coordinator] in
            do {
                let result = try await coordinator.run(plan, consent: consent, provider: provider,
                    current: { [weak self] source, config in await MainActor.run { self?.isCurrent(thread.id, token: token, source: source, config: config) == true } })
                guard let self, isCurrent(thread.id, token: token, source: plan.source, config: plan.provider) else { return }
                let user = try ReadingConversationTurn(role: .user, text: question, conversationID: thread.id, source: thread.source)
                let assistant = try ReadingConversationTurn(id: result.requestID, role: .assistant, text: result.text, conversationID: thread.id, source: thread.source)
                edit(thread.id) { value in
                    value.turns += [user, assistant]; value.answers.append(ReadingConversationAnswer(result: result, question: question))
                    value.pendingQuestion = nil; value.draft = ""; value.status = plan.provider.mode == .mock ? "本地 mock · 未联网" : "已完成"
                }
                busy = false; operation = nil
            } catch {
                guard let self, generation == token, currentID == thread.id else { return }
                edit(thread.id) { $0.pendingQuestion = nil; $0.failedQuestion = question; $0.failedAnswerID = answerID; $0.status = ReadingSkillSelectionAdapter.hostFailure(error).localizedDescription }
                busy = false; operation = nil
            }
        }
    }
    private func isCurrent(_ id: UUID, token: UUID, source: AISourceSnapshot, config: AIProviderConfig) -> Bool {
        guard generation == token, currentID == id, let thread = current, !thread.invalidated,
              ReadingSkillIdentity.matches(thread.source, source), let library else { return false }
        return library.isCurrentAISource(source) && ReadingSkillIdentity.matches(library.learning.config, config)
    }
    func selectionDidChange(_ anchor: AISelectionAnchor?) {
        // Moving focus to the dialogue can collapse selection. A real replacement revokes the pending request.
        guard let anchor, let thread = current, !ReadingSkillIdentity.matches(anchor, thread.source.anchor) else { return }
        stop(); edit(thread.id) { $0.invalidated = true; $0.status = "选区已改变 · 当前对话仍保留原文。请重新选择原文后打开此任务。" }
    }
    func sourceDidChange() { stop(); if let id = currentID { edit(id) { $0.invalidated = true; $0.status = AIFailure.stale.localizedDescription } } }
    func stop() {
        generation = UUID(); operation?.cancel(); operation = nil
        if busy, let id = currentID {
            edit(id) { $0.failedQuestion = $0.pendingQuestion; $0.failedAnswerID = UUID(); $0.pendingQuestion = nil; $0.status = "已停止 · 可手动重试" }
        }
        busy = false
    }
    func discard() { stop(); threads = []; currentID = nil; savedAnswers = []; savingAnswers = []; saveStatus = nil }
    func addToNotes(_ answer: ReadingConversationAnswer) async -> Bool {
        guard let library, !savingAnswers.contains(answer.id), !library.storageMaintenance,
              answer.result.isValidAnnotationResult, library.isCurrentAISource(answer.result.source),
              threads.contains(where: { $0.answers.contains(where: { $0.id == answer.id }) }) else { return false }
        if savedAnswers.contains(answer.id) { saveStatus = "已添加到笔记"; return true }
        savingAnswers.insert(answer.id); defer { savingAnswers.remove(answer.id) }
        do {
            guard await library.validateParagraphSourceForSave(answer.result.source), library.isCurrentAISource(answer.result.source) else { throw AIFailure.stale }
            let fence = try library.makeParagraphCommitFence(answer.result.source); defer { fence.invalidate() }
            _ = try await library.annotations.repository.addAIResult(answer.result, comment: "", commitFence: fence)
            savedAnswers.insert(answer.id); await library.annotations.reload()
            if let reader = library.annotations.reader, reader.bookID == answer.result.source.bookID { await reader.project(library.annotations.records) }
            saveStatus = "已添加到当前文档笔记"; return true
        } catch { saveStatus = AIJobCoordinator.safeError(error).localizedDescription; return false }
    }
}
#endif
