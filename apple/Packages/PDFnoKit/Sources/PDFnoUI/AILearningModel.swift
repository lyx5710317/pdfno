// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import SwiftUI
import PDFnoDomain
import PDFnoServices

enum AILearningAttemptOutcome: Equatable { case requesting, completed(AIResult), failed(AIFailure) }
struct AILearningAttempt: Identifiable, Equatable {
    let id: UUID
    let source: AISourceSnapshot
    let provider: AIProviderConfig
    let kind: AILearningKind
    var outcome: AILearningAttemptOutcome
}

@MainActor
public final class AILearningModel: ObservableObject {
    #if os(macOS)
    let deepSeekTest: DeepSeekTestModel
    #endif
    @Published var config = AIProviderConfig()
    @Published var source: AISourceSnapshot?
    @Published var kind: AILearningKind = .translate
    @Published var result: AIResult?
    @Published var notes: [AILearningNote] = []
    @Published var userText = ""
    @Published var busy = false
    @Published var status = "未配置 · 未发送请求"
    @Published var error: String?
    @Published private(set) var hasSessionCredential = false
    @Published private(set) var remoteAttemptsUsed = 0
    @Published private(set) var attempts: [AILearningAttempt] = []
    let offlineTransport: Bool
    private let repository: AILearningRepository
    private let coordinator = AIJobCoordinator()
    private let sessionCredentials = SessionCredentialStore()
    private let transport: any AIHTTPTransport
    private let remoteBudget: DeepSeekSelectionBudget
    private let timeoutSeconds: Double
    private var temporaryCredentialReference: UUID?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var drafts: [String: String] = [:]
    private func draftKey(_ source: AISourceSnapshot) -> String? {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        // Reader identity/version fences requests; drafts belong to immutable source text.
        struct DraftSource: Encodable { let bookID: UUID; let anchor: AISelectionAnchor }
        let anchor: AISelectionAnchor
        if case .epub(let value) = source.anchor {
            anchor = .epub(EPUBAnchor(editionID: value.editionID, fileSHA256: value.fileSHA256,
                resourceHref: value.resourceHref, spineIndex: value.spineIndex, start: value.start, end: value.end,
                quote: value.quote, prefix: value.prefix, suffix: value.suffix, vertical: false))
        } else { anchor = source.anchor }
        return (try? encoder.encode(DraftSource(bookID: source.bookID, anchor: anchor))).map(LibraryRepository.digest)
    }
    public init(root: URL, transport: any AIHTTPTransport = URLSessionAITransport(), timeoutSeconds: Double = 30, offlineTransport: Bool = false, aiSession: AppAISession = .shared) {
        repository = AILearningRepository(root: root); self.transport = transport; self.timeoutSeconds = timeoutSeconds; self.offlineTransport = offlineTransport
        remoteBudget = aiSession.selection
        #if os(macOS)
        deepSeekTest = DeepSeekTestModel(service: DeepSeekSelfTest(budget: aiSession.probe))
        #endif
        Task { [weak self, remoteBudget] in
            let used = await remoteBudget.attemptsUsed()
            guard let self else { return }; remoteAttemptsUsed = max(remoteAttemptsUsed, used)
        }
    }
    func load() async {
        do { let state = try await repository.load(); config = state.config; notes = state.notes }
        catch { self.error = AIFailure.store.localizedDescription }
    }
    func saveConfig(_ candidate: AIProviderConfig, temporarySecret: String) async -> Bool {
        do {
            if !temporarySecret.isEmpty, !CredentialValidation.valid(temporarySecret) { throw AIFailure.credentials }
            if !temporarySecret.isEmpty, !DeepSeekSelectionPolicy.supports(candidate) { throw AIFailure.configuration }
            cancel()
            let saved = try await repository.saveConfig(candidate)
            result = nil; config = saved; error = nil
            if let reference = temporaryCredentialReference { await sessionCredentials.remove(reference) }
            temporaryCredentialReference = nil; hasSessionCredential = false
            if !temporarySecret.isEmpty {
                let reference = UUID(); try await sessionCredentials.put(temporarySecret, reference: reference); temporaryCredentialReference = reference
                hasSessionCredential = true
            }
            status = saved.mode == .mock ? "本地 mock 已配置 · 不联网" :
                DeepSeekSelectionPolicy.supports(saved) ? "DeepSeek 选文已配置 · 手动确认后发送 · " + (hasSessionCredential ? "会话密钥已输入" : "需要会话密钥") : "配置预览已保存 · 此服务的阅读请求未开放"
            return true
        } catch { self.error = AIJobCoordinator.safeError(error).localizedDescription; return false }
    }
    func clearSessionCredential() async {
        cancel()
        if let reference = temporaryCredentialReference { await sessionCredentials.remove(reference) }
        temporaryCredentialReference = nil; hasSessionCredential = false; status = "会话密钥已清除 · 已有结果与笔记保留"
    }
    func prepare(_ source: AISourceSnapshot?) {
        if self.source == source { return } // Reopening the same selection retains its visible outcome.
        if let old = self.source, let key = draftKey(old) { drafts[key] = userText }
        if let source, let key = draftKey(source) { userText = drafts[key] ?? "" }
        else { userText = "" }
        cancel(); self.source = source; result = nil; error = nil
        status = source == nil ? "请先在原文中选择文字" : "来源已固定 · 确认范围后开始"
    }
    func cancel() {
        generation = UUID(); task?.cancel(); task = nil
        if busy {
            if let index = attempts.lastIndex(where: { $0.outcome == .requesting }) { attempts[index].outcome = .failed(.cancelled) }
            error = AIFailure.cancelled.localizedDescription; status = error!
        }
        busy = false
        Task { [weak self] in
            guard let self else { return }
            let count = await remoteBudget.attemptsUsed(); remoteAttemptsUsed = max(remoteAttemptsUsed, count)
        }
    }
    func start(confirmed: Bool, sourceIsCurrent: @escaping @MainActor (AISourceSnapshot) -> Bool) {
        guard let source, source.isValid else { error = AIFailure.inputLimit.localizedDescription; return }
        guard confirmed else { error = AIFailure.consent.localizedDescription; return }
        guard sourceIsCurrent(source) else { error = AIFailure.stale.localizedDescription; return }
        guard config.mode != .unconfigured else { error = AIFailure.unconfigured.localizedDescription; return }
        let provider: any AIProvider
        if config.mode == .mock { provider = LocalMockAIProvider() }
        else {
            guard DeepSeekSelectionPolicy.supports(config) else { error = AIFailure.configuration.localizedDescription; return }
            guard source.anchor.quote.utf16.count <= DeepSeekSelectionPolicy.maxSourceUTF16 else { error = AIFailure.remoteInputLimit.localizedDescription; return }
            guard hasSessionCredential, let reference = temporaryCredentialReference else { error = AIFailure.credentials.localizedDescription; return }
            guard remoteAttemptsUsed < DeepSeekSelectionPolicy.maxAttempts else { error = AIFailure.attemptLimit.localizedDescription; return }
            provider = DeepSeekSelectionProvider(transport: transport, credentials: sessionCredentials, credentialReference: reference, budget: remoteBudget)
        }
        guard !busy else { return }
        cancel(); let token = generation, request = AIRequest(source: source, provider: config, kind: kind, timeoutSeconds: timeoutSeconds)
        attempts.append(AILearningAttempt(id: request.id, source: source, provider: config, kind: kind, outcome: .requesting))
        if attempts.count > 10 { attempts.removeFirst(attempts.count - 10) }
        result = nil; error = nil; busy = true
        status = config.mode == .mock ? "本地 mock 正在生成 · 无网络请求" : "DeepSeek 正在处理固定选文 · 无自动重试"
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let consent = AIConsent(requestID: request.id, scopeFingerprint: try AIJobCoordinator.fingerprint(request))
                let result = try await coordinator.run(request, consent: consent, provider: provider)
                guard generation == token else { return }
                guard config == request.provider, sourceIsCurrent(source), result.requestID == request.id else { throw AIFailure.stale }
                self.result = result
                if let index = attempts.firstIndex(where: { $0.id == request.id }) { attempts[index].outcome = .completed(result) }
                status = result.fromCache ? "本次来自已校验内存缓存 · 没有发送网络请求" :
                    result.provider.mode == .mock ? "本地 mock 结果 · 不代表真实翻译或解释质量" : "收到 DeepSeek 结果并核验原文 · 未自动保存学习笔记"
            } catch {
                guard generation == token else { return }
                let failure = AIJobCoordinator.safeError(error)
                if let index = attempts.firstIndex(where: { $0.id == request.id }) { attempts[index].outcome = .failed(failure) }
                self.error = failure.localizedDescription; status = "请求未完成 · 错误记录保留 · 不会自动重发"
            }
            let count = await remoteBudget.attemptsUsed()
            guard generation == token else { return }; remoteAttemptsUsed = max(remoteAttemptsUsed, count); busy = false; task = nil
        }
    }
    func savePageResult(_ result: AIResult, userText: String, sourceIsCurrent: (AISourceSnapshot) -> Bool) async -> Bool {
        guard case .pdfPage = result.source.anchor, result.promptVersion == PDFPageTranslationPolicy.promptVersion,
              sourceIsCurrent(result.source) else { error = AIFailure.stale.localizedDescription; return false }
        guard !notes.contains(where: { $0.result.requestID == result.requestID }) else { return true }
        do {
            try await repository.saveNote(AILearningNote(result: result, userText: userText))
            notes = try await repository.load().notes; return true
        } catch { self.error = AIJobCoordinator.safeError(error).localizedDescription; return false }
    }
    func save(sourceIsCurrent: (AISourceSnapshot) -> Bool) async -> Bool {
        guard let result, sourceIsCurrent(result.source), result.provider == config else { error = AIFailure.stale.localizedDescription; return false }
        guard !notes.contains(where: { $0.result.requestID == result.requestID }) else { return true }
        do {
            try await repository.saveNote(AILearningNote(result: result, userText: userText))
            notes = try await repository.load().notes; status = "学习笔记已保存到本地 · 用户正文与 AI 结果分别保留"; return true
        } catch { self.error = AIJobCoordinator.safeError(error).localizedDescription; return false }
    }
}
