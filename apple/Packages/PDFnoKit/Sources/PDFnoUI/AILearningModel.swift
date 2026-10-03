// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import SwiftUI
import PDFnoDomain
import PDFnoServices

@MainActor
public final class AILearningModel: ObservableObject {
    @Published var config = AIProviderConfig()
    @Published var source: AISourceSnapshot?
    @Published var kind: AILearningKind = .translate
    @Published var result: AIResult?
    @Published var notes: [AILearningNote] = []
    @Published var userText = ""
    @Published var busy = false
    @Published var status = "未配置 · 未发送请求"
    @Published var error: String?
    private let repository: AILearningRepository
    private let coordinator = AIJobCoordinator()
    private let sessionCredentials = SessionCredentialStore()
    private var temporaryCredentialReference: UUID?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var drafts: [String: String] = [:]
    private func draftKey(_ source: AISourceSnapshot) -> String? {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(source)).map(LibraryRepository.digest)
    }
    public init(root: URL) { repository = AILearningRepository(root: root) }
    func load() async {
        do { let state = try await repository.load(); config = state.config; notes = state.notes }
        catch { self.error = AIFailure.store.localizedDescription }
    }
    func saveConfig(_ candidate: AIProviderConfig, temporarySecret: String) async -> Bool {
        do {
            if !temporarySecret.isEmpty, !CredentialValidation.valid(temporarySecret) { throw AIFailure.credentials }
            let saved = try await repository.saveConfig(candidate)
            cancel(); result = nil; config = saved
            if let reference = temporaryCredentialReference { await sessionCredentials.remove(reference) }
            temporaryCredentialReference = nil
            if !temporarySecret.isEmpty {
                let reference = UUID(); try await sessionCredentials.put(temporarySecret, reference: reference); temporaryCredentialReference = reference
            }
            status = saved.mode == .mock ? "本地 mock 已配置 · 不联网" : "配置已保存 · 真实远程请求未启用"
            return true
        } catch { self.error = AIJobCoordinator.safeError(error).localizedDescription; return false }
    }
    func prepare(_ source: AISourceSnapshot?) {
        if let old = self.source, let key = draftKey(old) { drafts[key] = userText }
        if let source, let key = draftKey(source) { userText = drafts[key] ?? "" }
        else { userText = "" }
        cancel(); self.source = source; result = nil; error = nil
        status = source == nil ? "请先在原文中选择文字" : "来源已固定 · 确认范围后开始"
    }
    func cancel() {
        generation = UUID(); task?.cancel(); task = nil
        if busy { status = AIFailure.cancelled.localizedDescription }; busy = false
    }
    func start(confirmed: Bool, sourceIsCurrent: @escaping @MainActor (AISourceSnapshot) -> Bool) {
        guard let source, source.isValid else { error = AIFailure.inputLimit.localizedDescription; return }
        guard confirmed else { error = AIFailure.consent.localizedDescription; return }
        guard sourceIsCurrent(source) else { error = AIFailure.stale.localizedDescription; return }
        guard config.mode == .mock else { error = (config.mode == .unconfigured ? AIFailure.unconfigured : .credentials).localizedDescription; return }
        cancel(); let token = generation, request = AIRequest(source: source, provider: config, kind: kind)
        result = nil; error = nil; busy = true; status = "本地 mock 正在生成 · 无网络请求"
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let consent = AIConsent(requestID: request.id, scopeFingerprint: try AIJobCoordinator.fingerprint(request))
                let result = try await coordinator.run(request, consent: consent, provider: LocalMockAIProvider())
                guard generation == token else { return }
                guard config == request.provider, sourceIsCurrent(source), result.requestID == request.id else { throw AIFailure.stale }
                self.result = result; status = result.fromCache ? "本地 mock 结果 · 本次来自内存缓存" : "本地 mock 结果 · 不代表真实翻译或解释质量"
            } catch {
                guard generation == token else { return }
                self.error = AIJobCoordinator.safeError(error).localizedDescription; status = "请求未完成"
            }
            guard generation == token else { return }; busy = false; task = nil
        }
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
