// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import SwiftUI
import PDFnoDomain
import PDFnoServices

/// Independent integration seam. It neither opens a library nor writes settings/notes to disk.
@MainActor public final class BYOKSettingsModel: ObservableObject {
    @Published public var draft = DeepSeekSelectionPolicy.configuration() {
        didSet {
            guard !synchronizing, draft != oldValue else { return }
            invalidate()
            if draft.endpoint != oldValue.endpoint {
                temporarySecret = ""; hasSessionCredential = false
                let previous = credentialClearTask, session = session
                credentialClearTask = Task { await previous?.value; await session.clearCredential() }
                status = "接收地址已更改 · 旧会话密钥已撤销 · 请重新输入"
            }
        }
    }
    @Published public var temporarySecret = ""
    @Published public private(set) var hasSessionCredential = false
    @Published public private(set) var preview: BYOKSelectionPreview?
    @Published public private(set) var result: AIResult?
    @Published public private(set) var busy = false
    @Published public private(set) var status = "官方 DeepSeek 默认配置 · 尚未发送"
    @Published public private(set) var error: String?
    @Published public private(set) var attemptsUsed = 0
    public let session: BYOKProviderSession
    private let transport: any AIHTTPTransport
    private let aiSession: AppAISession
    private let coordinator = AIJobCoordinator()
    private var credentialClearTask: Task<Void, Never>?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var synchronizing = false
    public init(session: BYOKProviderSession = BYOKProviderSession(),
                transport: any AIHTTPTransport = URLSessionAITransport(), aiSession: AppAISession = .shared) {
        self.session = session; self.transport = transport; self.aiSession = aiSession
    }
    public func load() async {
        let token = generation
        await credentialClearTask?.value
        let snapshot = await session.snapshot()
        guard generation == token else { return }
        synchronizing = true; draft = snapshot.configuration; synchronizing = false
        hasSessionCredential = snapshot.hasSessionCredential
        let count = await aiSession.selection.attemptsUsed()
        attemptsUsed = max(attemptsUsed, count)
    }
    @discardableResult public func apply() async -> Bool {
        invalidate(); let token = generation
        await credentialClearTask?.value
        guard generation == token else { return false }
        let candidate = draft, value = temporarySecret
        temporarySecret = ""
        do {
            let snapshot = try await session.configure(candidate, temporarySecret: value)
            guard generation == token, draft == candidate else { await session.clearCredential(); throw AIFailure.stale }
            draft = snapshot.configuration; hasSessionCredential = snapshot.hasSessionCredential; error = nil
            status = "配置仅在本次会话生效 · " + (hasSessionCredential ? "需要逐次确认后发送" : "需要重新输入会话密钥")
            return true
        } catch {
            hasSessionCredential = (await session.snapshot()).hasSessionCredential
            self.error = Self.message(error); return false
        }
    }
    public func clearCredential() async {
        temporarySecret = ""; invalidate(); hasSessionCredential = false
        await credentialClearTask?.value; await session.clearCredential()
        draft = (await session.snapshot()).configuration
        status = "会话密钥已清除 · 已有结果与外部笔记保留"
    }
    /// Caller supplies an already captured immutable PDF/EPUB selection; no document discovery.
    public func prepareSelection(_ source: AISourceSnapshot, kind: AILearningKind) async {
        invalidate(); let token = generation
        await credentialClearTask?.value
        do {
            let snapshot = await session.snapshot()
            guard generation == token else { return }
            guard draft == snapshot.configuration else { throw AIFailure.stale }
            preview = try BYOKSelectionPreview(request: AIRequest(source: source, provider: snapshot.configuration, kind: kind))
            hasSessionCredential = snapshot.hasSessionCredential; result = nil; error = nil
            status = "核对实际域名与下方完整选文 · 不会自动发送"
        } catch { self.error = Self.message(error) }
    }
    public func start(confirmed: Bool, sourceIsCurrent: @escaping @MainActor (AISourceSnapshot) -> Bool) {
        guard !busy else { return }
        guard confirmed, let preview else { error = Self.message(AIFailure.consent); return }
        guard sourceIsCurrent(preview.request.source), draft == preview.request.provider else { error = Self.message(AIFailure.stale); return }
        let token = UUID(); generation = token; busy = true; error = nil; result = nil
        task = Task { [weak self] in
            guard let self else { return }
            do {
                await credentialClearTask?.value
                let snapshot = await session.snapshot()
                guard generation == token, snapshot.configuration == preview.request.provider,
                      sourceIsCurrent(preview.request.source) else { throw AIFailure.stale }
                let provider = try BYOKProviderFactory.selection(snapshot: snapshot, session: session, transport: transport, aiSession: aiSession)
                let output = try await coordinator.run(preview.request, consent: preview.consent, provider: provider)
                guard generation == token else { return }
                guard draft == preview.request.provider, sourceIsCurrent(output.source) else { throw AIFailure.stale }
                result = output; status = output.fromCache ? "已校验内存缓存 · 未发送新请求" : "收到结果并核验原文 · 未自动保存笔记"
            } catch {
                guard generation == token else { return }
                self.error = Self.message(error); status = "请求未完成 · 不会自动重试或切换供应商"
            }
            let count = await aiSession.selection.attemptsUsed()
            guard generation == token else { return }
            attemptsUsed = max(attemptsUsed, count); busy = false; task = nil
        }
    }
    /// Host calls on selection/book/session change or component dismissal.
    public func invalidate() {
        if busy { error = AIFailure.cancelled.localizedDescription; status = "请求已取消 · 不会保存迟到结果或自动重发" }
        generation = UUID(); task?.cancel(); task = nil; busy = false; preview = nil
        let budget = aiSession.selection
        Task { [weak self] in let count = await budget.attemptsUsed(); guard let self else { return }; attemptsUsed = max(attemptsUsed, count) }
    }
    public static func message(_ error: Error) -> String {
        let failure = AIJobCoordinator.safeError(error)
        if failure == .configuration { return "此 BYOK 首片仅接受有效 HTTPS 地址和模型；不允许本地 HTTP、URL 凭据、查询、片段或重定向。" }
        if failure == .remoteInputLimit { return "仅接受最多500 UTF-16单位的 PDF/EPUB 固定选文；不会截断或扩范围。" }
        return failure.localizedDescription
    }
}
