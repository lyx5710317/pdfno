// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import SwiftUI
import PDFnoDomain
import PDFnoServices

struct EPUBChapterTranslationSegment: Identifiable {
    let id: Int
    let source: AISourceSnapshot
    var result: AIResult?
    var failure: AIFailure?
    var userText = ""
}
struct EPUBChapterRetainedBatch: Identifiable {
    let id = UUID()
    let plan: EPUBChapterTranslationPlan
    var segments: [EPUBChapterTranslationSegment]
}
@MainActor
public final class EPUBChapterTranslationModel: ObservableObject {
    @Published private(set) var plan: EPUBChapterTranslationPlan?
    @Published var segments: [EPUBChapterTranslationSegment] = []
    @Published var retainedBatches: [EPUBChapterRetainedBatch] = []
    @Published private(set) var preview: EPUBChapterTextSnapshot?
    @Published private(set) var submitted = false
    @Published private(set) var busy = false
    @Published private(set) var attemptsUsed = 0
    @Published private(set) var status = "仅处理点击时的完整 EPUB spine 文档"
    @Published private(set) var error: String?
    @Published private(set) var preparationError: String?
    @Published var temporarySecret = ""
    let offlineTransport: Bool
    private let transport: any AIHTTPTransport
    private let timeoutSeconds: Double
    private let budget: DeepSeekSelectionBudget
    private let coordinator = AIJobCoordinator()
    private let credentials = SessionCredentialStore()
    private var credentialReference: UUID?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    public init(transport: any AIHTTPTransport = URLSessionAITransport(), timeoutSeconds: Double = 30, offlineTransport: Bool = false, aiSession: AppAISession = .shared) {
        self.transport = transport; self.timeoutSeconds = timeoutSeconds; self.offlineTransport = offlineTransport
        budget = aiSession.chapter
        Task { [weak self, budget] in
            let used = await budget.attemptsUsed()
            guard let self else { return }; attemptsUsed = max(attemptsUsed, used)
        }
    }
    func prepare(_ snapshot: EPUBChapterTextSnapshot) {
        do {
            let plan = try EPUBChapterTranslationPlan(snapshot: snapshot)
            if self.plan == plan, self.plan?.snapshot.text?.unicodeScalars.elementsEqual(snapshot.text?.unicodeScalars ?? "".unicodeScalars) == true { return }
            reset(); preview = snapshot; self.plan = plan
            segments = plan.sources.enumerated().map { EPUBChapterTranslationSegment(id: $0.offset, source: $0.element) }
        } catch { rejectPreparation(error); preview = snapshot }
    }
    func rejectPreparation(_ error: Error) {
        reset(); preparationError = (error as? EPUBChapterTranslationFailure)?.localizedDescription ?? EPUBChapterTranslationFailure.invalidSource.localizedDescription
    }
    private func reset() {
        cancel()
        if let plan, segments.contains(where: { $0.result != nil }) {
            retainedBatches.append(EPUBChapterRetainedBatch(plan: plan, segments: segments))
        }
        submitted = false; preview = nil; plan = nil; segments = []; error = nil; preparationError = nil
        status = "完整范围已固定 · 尚未发送"
    }
    func cancel() {
        generation = UUID(); task?.cancel(); task = nil; temporarySecret = ""
        if busy { status = "已取消 · 已完成分段保留，其余未完成；已发请求可能收费"; error = AIFailure.cancelled.localizedDescription }
        busy = false
        if let reference = credentialReference { Task { await credentials.remove(reference) } }
        credentialReference = nil
        Task { [weak self] in
            guard let self else { return }
            attemptsUsed = max(attemptsUsed, await budget.attemptsUsed())
        }
    }
    func start(confirmed: Bool, sourceIsCurrent: @escaping @MainActor (AISourceSnapshot) -> Bool) {
        guard !busy, let plan else { return }
        guard confirmed else { error = AIFailure.consent.localizedDescription; return }
        guard plan.sources.allSatisfy(sourceIsCurrent) else { error = AIFailure.stale.localizedDescription; return }
        guard !submitted else { error = "此批次已发起；本首片不重发或恢复，已完成分段保留。"; return }
        guard CredentialValidation.valid(temporarySecret) else { error = AIFailure.credentials.localizedDescription; return }
        guard plan.sources.count <= EPUBChapterTranslationPolicy.maxSessionRequests - attemptsUsed else { error = EPUBChapterTranslationFailure.budget.localizedDescription; return }
        // Copy only after the explicit send action. Never persist or share selection/probe keys.
        let secret = temporarySecret; temporarySecret = ""; generation = UUID(); let token = generation
        let reference = UUID(); credentialReference = reference
        let providerConfig = DeepSeekSelectionPolicy.configuration() // One immutable profile per explicit chapter submission.
        submitted = true; busy = true; error = nil; segments.indices.forEach { segments[$0].failure = nil }
        status = "发送前核对完整计划 · 不自动重试"
        task = Task { [weak self] in
            guard let self else { return }
            var batchID: UUID?
            defer {
                Task {
                    await credentials.remove(reference)
                    if let batchID { await budget.releaseChapterBatch(batchID) }
                }
                if generation == token { credentialReference = nil; busy = false; task = nil }
            }
            do {
                let used = await budget.attemptsUsed()
                guard generation == token, !Task.isCancelled else { return }
                attemptsUsed = max(attemptsUsed, used)
                guard plan.sources.count <= EPUBChapterTranslationPolicy.maxSessionRequests - used else { throw EPUBChapterTranslationFailure.budget }
                try await credentials.put(secret, reference: reference)
                batchID = try await budget.claimChapterBatch(count: plan.sources.count)
                guard generation == token, !Task.isCancelled else { return }
                let provider = DeepSeekSelectionProvider(transport: transport, credentials: credentials, credentialReference: reference, budget: budget, chapterBatchID: batchID)
                for (index, source) in plan.sources.enumerated() {
                    try Task.checkCancellation()
                    guard generation == token, sourceIsCurrent(source) else { throw AIFailure.stale }
                    status = "正在处理第 \(index + 1) / \(plan.sources.count) 段 · 仅当前 spine 文档"
                    let request = AIRequest(source: source, provider: providerConfig, kind: .translate, timeoutSeconds: timeoutSeconds)
                    do {
                        let consent = AIConsent(requestID: request.id, scopeFingerprint: try AIJobCoordinator.fingerprint(request))
                        let result = try await coordinator.run(request, consent: consent, provider: provider)
                        guard generation == token, !Task.isCancelled else { return }
                        guard sourceIsCurrent(source), result.source == source else { throw AIFailure.stale }
                        segments[index].result = result
                    } catch {
                        guard generation == token else { return }
                        segments[index].failure = AIJobCoordinator.safeError(error)
                        throw error // Stop the remainder; no implicit retry or extra scope.
                    }
                    let used = await budget.attemptsUsed()
                    guard generation == token else { return }; attemptsUsed = max(attemptsUsed, used)
                }
                status = "当前 spine 文档全部 \(segments.count) 段收到并校验来源 · 未自动保存 · 语言质量需人工核验"
            } catch {
                guard generation == token else { return }
                self.error = (error as? EPUBChapterTranslationFailure)?.localizedDescription ?? AIJobCoordinator.safeError(error).localizedDescription
                let completed = segments.filter { $0.result != nil }.count
                status = "当前 spine 文档未完成 · 已完成 \(completed) / \(segments.count) 段 · 剩余已停止 · 无自动重试"
            }
            let used = await budget.attemptsUsed()
            guard generation == token else { return }; attemptsUsed = max(attemptsUsed, used)
        }
    }
}
