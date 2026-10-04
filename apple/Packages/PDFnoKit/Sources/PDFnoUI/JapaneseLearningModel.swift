// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import SwiftUI
import PDFnoDomain
import PDFnoServices

/// Host-injected dependencies only: this model owns no key, transport, library or extra quota.
@MainActor
public final class JapaneseLearningModel: ObservableObject {
    public typealias CurrentScope = @MainActor (AISourceSnapshot, AIProviderConfig) -> Bool
    public typealias SaveNote = @MainActor (JapaneseLearningNote) async throws -> Void
    @Published public private(set) var request: JapaneseLearningRequest?
    @Published public private(set) var review: JapaneseLearningReview?
    @Published public private(set) var confirmationScope = ""
    @Published public private(set) var confirmationRevision = UUID()
    @Published public private(set) var busy = false
    @Published public private(set) var saving = false
    @Published public private(set) var saved = false
    @Published public private(set) var attemptsUsed = 0
    @Published public private(set) var status = "未发送 · 请先在原文中选择日语"
    @Published public private(set) var error: String?
    @Published public var userText = ""
    @Published public var readingCorrections: [String: String] = [:]
    public var canSave: Bool { saveNote != nil && review != nil && review?.status != .unavailable && !busy && !saving && !saved }
    private var preparationFailure: AIFailure?
    public var canStart: Bool {
        guard let request else { return false }
        return !busy && !saving && preparationFailure == nil && (try? request.validate()) != nil &&
            (request.provider.mode == .mock || attemptsUsed < DeepSeekSelectionPolicy.maxAttempts)
    }
    public func presentFailure(_ failure: AIFailure) { error = failure.localizedDescription }
    private var provider: any JapaneseLearningProvider
    private let isCurrent: CurrentScope
    private let saveNote: SaveNote?
    private let coordinator = JapaneseLearningCoordinator()
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private struct Draft { let userText: String; let corrections: [String: String] }
    private var drafts: [String: Draft] = [:]
    private var noteIDs: [UUID: UUID] = [:]
    public init(provider: any JapaneseLearningProvider, sourceIsCurrent: @escaping CurrentScope,
                saveReviewedNote: SaveNote? = nil) {
        self.provider = provider; isCurrent = sourceIsCurrent; saveNote = saveReviewedNote
    }
    private func retainDraft() {
        guard let source = request?.source, let key = try? JapaneseLearningCoordinator.draftFingerprint(source) else { return }
        drafts[key] = Draft(userText: userText, corrections: readingCorrections)
    }
    /// Host calls on capture/close/book/version/reflow/config/credential-generation changes.
    /// Replacing a provider also invalidates consent, even if nonsecret configuration is identical.
    public func prepare(_ candidate: JapaneseLearningRequest?, provider replacement: (any JapaneseLearningProvider)? = nil, failure: AIFailure? = nil) {
        let scope = candidate.flatMap { try? JapaneseLearningCoordinator.fingerprint($0) } ?? ""
        if replacement == nil && failure == preparationFailure && scope == confirmationScope && (candidate == nil) == (request == nil) { return }
        retainDraft(); cancel()
        if let replacement { provider = replacement }
        preparationFailure = failure
        request = candidate; confirmationScope = scope; confirmationRevision = UUID(); review = nil; saved = false; error = nil
        userText = ""; readingCorrections = [:]
        if let candidate {
            do { try candidate.validate() }
            catch { self.error = AIJobCoordinator.safeError(error).localizedDescription }
            if let key = try? JapaneseLearningCoordinator.draftFingerprint(candidate.source), let draft = drafts[key] {
                userText = draft.userText; readingCorrections = draft.corrections
            }
        }
        if let failure { error = failure.localizedDescription }
        status = candidate == nil ? "请先在 PDF / EPUB 中选择日语原文" : "固定选文已准备 · 等待手动确认与开始"
        Task { [weak self, provider] in
            let used = await provider.attemptsUsed()
            guard let self else { return }; attemptsUsed = max(attemptsUsed, used)
        }
    }
    public func start(confirmed: Bool) {
        guard !busy, !saving, let prepared = request else { return }
        guard confirmed else { error = AIFailure.consent.localizedDescription; return }
        do {
            if let preparationFailure { throw preparationFailure }
            try prepared.validate()
            guard isCurrent(prepared.source, prepared.provider) else { throw AIFailure.stale }
            guard provider.mode == prepared.provider.mode else { throw AIFailure.configuration }
        } catch { self.error = AIJobCoordinator.safeError(error).localizedDescription; return }
        cancel(); let token = generation, provider = self.provider
        let request = JapaneseLearningRequest(source: prepared.source, provider: prepared.provider,
            authorReadings: prepared.authorReadings, timeoutSeconds: prepared.timeoutSeconds)
        review = nil; error = nil; busy = true; saved = false
        status = provider.mode == .mock ? "本地 mock 审阅演示 · 不联网" : "正在分析固定选文 · 共享选文额度 · 无自动重试"
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let consent = AIConsent(requestID: request.id, scopeFingerprint: try JapaneseLearningCoordinator.fingerprint(request))
                let result = try await coordinator.run(request, consent: consent, provider: provider)
                guard generation == token else { return }
                guard isCurrent(request.source, request.provider), result.requestID == request.id,
                      confirmationScope == (try JapaneseLearningCoordinator.fingerprint(request)) else { throw AIFailure.stale }
                review = result
                noteIDs = [result.requestID: UUID()]
                status = result.status == .unavailable ? "输出无法验证 · 仅保留来源供审阅" : "收到可审阅建议 · 范围核验不代表语言准确 · 未自动保存"
            } catch {
                guard generation == token else { return }
                self.error = AIJobCoordinator.safeError(error).localizedDescription
                status = "本次未完成 · 不会自动重试或切换 mock"
            }
            let used = await provider.attemptsUsed()
            guard generation == token else { return }; attemptsUsed = max(attemptsUsed, used); busy = false; task = nil
        }
    }
    public func cancel() {
        generation = UUID(); task?.cancel(); task = nil
        if busy { error = AIFailure.cancelled.localizedDescription; status = "请求已取消 · 已发请求可能收费，迟到结果不会显示或保存" }
        busy = false
        Task { [weak self, provider] in
            let used = await provider.attemptsUsed()
            guard let self else { return }; attemptsUsed = max(attemptsUsed, used)
        }
    }
    public func currentSourceForReturn() -> AISourceSnapshot? {
        guard let request, (try? request.validate()) != nil, isCurrent(request.source, request.provider) else {
            error = AIFailure.stale.localizedDescription; return nil
        }
        return request.source
    }
    /// Only valid generated items can request emphasis. The host must revalidate native geometry.
    public func emphasisSource(for span: JapaneseSpan) -> AISourceSnapshot? {
        guard let review, isCurrent(review.source, review.provider), span.isValid(in: review.source.anchor.quote),
              review.readings.contains(where: { $0.span.correctionKey == span.correctionKey }) ||
              review.grammar.contains(where: { $0.span.correctionKey == span.correctionKey }) else { return nil }
        return review.source
    }
    public func save() async -> Bool {
        guard canSave, let review, let saveNote else { return false }
        guard isCurrent(review.source, review.provider) else { error = AIFailure.stale.localizedDescription; return false }
        do {
            let corrections = review.readings.compactMap { item -> JapaneseReadingCorrection? in
                guard let reading = readingCorrections[item.span.correctionKey], !reading.isEmpty else { return nil }
                return JapaneseReadingCorrection(span: item.span, reading: reading)
            }
            guard corrections.allSatisfy({ JapaneseLearningValidator.isKana($0.reading) }) else {
                error = "用户修正须填写100 UTF-16以内的平假名或片假名；草稿已保留。"; return false
            }
            let note = try JapaneseLearningNote(id: noteIDs[review.requestID] ?? UUID(), review: review,
                userText: userText, corrections: corrections)
            let token = generation
            saving = true; defer { saving = false }
            try await saveNote(note) // Integration must create a new note atomically/idempotently.
            guard generation == token else { return true } // Never replace a new source's draft/status.
            saved = true; error = nil; retainDraft(); status = "已保存独立学习记录 · 用户正文与生成建议分开"
            return true
        } catch { self.error = AIFailure.store.localizedDescription; return false }
    }
}
