// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public protocol AIProvider: Sendable {
    func analyze(_ request: AIRequest) async throws -> AIProviderOutput
}
public struct LocalMockAIProvider: AIProvider {
    public init() {}
    public func analyze(_ request: AIRequest) async throws -> AIProviderOutput {
        try await Task.sleep(for: .milliseconds(300)); try Task.checkCancellation()
        // Fixed synthetic demonstrations, never a claim of model translation quality.
        let text = request.kind == .translate
            ? "[本地 mock 示例] 窗边的一段阅读时光。此内容仅演示结果与来源闭环，不是选文的真实译文。"
            : "[本地 mock 示例] 英语可观察主谓结构；日语可观察助词与接续。此内容不判断选文语法，只演示解释、引用与保存。"
        return AIProviderOutput(sourceQuote: request.source.anchor.quote, text: text)
    }
}
public actor AIJobCoordinator {
    private struct Pending {
        let continuation: CheckedContinuation<AIResult, Error>
        var worker: Task<Void, Never>?
        var timer: Task<Void, Never>?
    }
    private var jobs: [UUID: Pending] = [:]
    private var cache: [String: String] = [:]
    private var cacheOrder: [String] = []
    public init() {}
    public static func fingerprint(_ request: AIRequest) throws -> String {
        struct Scope: Encodable { let source: AISourceSnapshot; let provider: AIProviderConfig; let kind: AILearningKind; let promptVersion: String }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return LibraryRepository.digest(try encoder.encode(Scope(source: request.source, provider: request.provider, kind: request.kind,
            promptVersion: DeepSeekSelectionPolicy.supports(request.provider) ? DeepSeekSelectionPolicy.promptVersion : "selection-1")))
    }
    public func run(_ request: AIRequest, consent: AIConsent, provider: any AIProvider) async throws -> AIResult {
        try Task.checkCancellation()
        guard request.source.isValid else { throw AIFailure.inputLimit }
        guard request.provider.isValid, request.timeoutSeconds.isFinite, request.timeoutSeconds > 0, request.timeoutSeconds <= 120 else { throw AIFailure.configuration }
        guard request.provider.mode != .unconfigured else { throw AIFailure.unconfigured }
        let key = try Self.fingerprint(request)
        guard consent.requestID == request.id, consent.scopeFingerprint == key else { throw AIFailure.consent }
        guard jobs[request.id] == nil else { throw AIFailure.stale }
        if let text = cache[key] { return AIResult(request: request, text: text, fromCache: true) }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(throwing: AIFailure.cancelled); return }
                jobs[request.id] = Pending(continuation: continuation)
                jobs[request.id]?.worker = Task {
                    do {
                        let output = try await provider.analyze(request)
                        guard output.sourceQuote.unicodeScalars.elementsEqual(request.source.anchor.quote.unicodeScalars),
                              !output.text.isEmpty, output.text.utf16.count <= 16000 else { throw AIFailure.output }
                        self.finish(request, key: key, outcome: .success(AIResult(request: request, text: output.text, fromCache: false)))
                    } catch { self.finish(request, key: key, outcome: .failure(Self.safeError(error))) }
                }
                jobs[request.id]?.timer = Task {
                    do { try await Task.sleep(for: .seconds(request.timeoutSeconds)) }
                    catch { return }
                    self.finish(request, key: key, outcome: .failure(AIFailure.timeout))
                }
            }
        } onCancel: { Task { await self.cancel(request.id) } }
    }
    private func finish(_ request: AIRequest, key: String, outcome: Result<AIResult, Error>) {
        guard let pending = jobs.removeValue(forKey: request.id) else { return }
        pending.worker?.cancel(); pending.timer?.cancel()
        if case .success(let result) = outcome {
            cache[key] = result.text; cacheOrder.removeAll { $0 == key }; cacheOrder.append(key)
            if cacheOrder.count > 20 { cache.removeValue(forKey: cacheOrder.removeFirst()) }
        }
        pending.continuation.resume(with: outcome)
    }
    public func cancel(_ id: UUID) {
        guard let pending = jobs.removeValue(forKey: id) else { return }
        pending.worker?.cancel(); pending.timer?.cancel(); pending.continuation.resume(throwing: AIFailure.cancelled)
    }
    public func clearCache() { cache = [:]; cacheOrder = [] }
    public static func safeError(_ error: Error) -> AIFailure {
        if let error = error as? AIFailure { return error }
        if error is CancellationError { return .cancelled }
        if let error = error as? URLError { return error.code == .timedOut ? .timeout : error.code == .cancelled ? .cancelled : .network }
        return .server
    }
}
