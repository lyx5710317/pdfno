// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit
import PDFnoDomain

/// No success cache, retry, persistence or budget owner. One continuation fences each request.
public actor JapaneseLearningCoordinator {
    private struct Pending {
        let continuation: CheckedContinuation<JapaneseLearningReview, Error>
        var worker: Task<Void, Never>?
        var timer: Task<Void, Never>?
    }
    private var jobs: [UUID: Pending] = [:]
    public init() {}
    public static func fingerprint(_ request: JapaneseLearningRequest) throws -> String {
        struct Scope: Encodable {
            let purpose: String; let source: AISourceSnapshot; let provider: AIProviderConfig
            let authorReadings: [JapaneseAuthorReading]; let timeoutSeconds: Double
            let maxOutputTokens: Int
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(Scope(purpose: JapaneseLearningPolicy.promptVersion, source: request.source,
            provider: request.provider, authorReadings: request.authorReadings, timeoutSeconds: request.timeoutSeconds,
            maxOutputTokens: JapaneseLearningPolicy.maxOutputTokens))
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    /// Per-source drafts survive a new analysis/model version; never normalize source byte spelling.
    public static func draftFingerprint(_ source: AISourceSnapshot) throws -> String {
        struct Scope: Encodable { let bookID: UUID; let anchor: AISelectionAnchor }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let anchor: AISelectionAnchor
        if case .epub(let value) = source.anchor {
            anchor = .epub(EPUBAnchor(editionID: value.editionID, fileSHA256: value.fileSHA256,
                resourceHref: value.resourceHref, spineIndex: value.spineIndex, start: value.start, end: value.end,
                quote: value.quote, prefix: value.prefix, suffix: value.suffix, vertical: false))
        } else { anchor = source.anchor }
        return SHA256.hash(data: try encoder.encode(Scope(bookID: source.bookID, anchor: anchor)))
            .map { String(format: "%02x", $0) }.joined()
    }
    public func run(_ request: JapaneseLearningRequest, consent: AIConsent,
                    provider: any JapaneseLearningProvider) async throws -> JapaneseLearningReview {
        try Task.checkCancellation(); try request.validate()
        guard provider.mode == request.provider.mode else { throw AIFailure.configuration }
        guard consent.requestID == request.id, consent.scopeFingerprint == (try Self.fingerprint(request)) else { throw AIFailure.consent }
        guard jobs[request.id] == nil else { throw AIFailure.stale }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(throwing: AIFailure.cancelled); return }
                jobs[request.id] = Pending(continuation: continuation)
                jobs[request.id]?.worker = Task {
                    do {
                        let data = try await provider.analyze(request)
                        self.finish(request.id, .success(JapaneseLearningValidator.validate(data, request: request)))
                    } catch { self.finish(request.id, .failure(AIJobCoordinator.safeError(error))) }
                }
                jobs[request.id]?.timer = Task {
                    do { try await Task.sleep(for: .seconds(request.timeoutSeconds)) } catch { return }
                    self.finish(request.id, .failure(AIFailure.timeout))
                }
            }
        } onCancel: { Task { await self.cancel(request.id) } }
    }
    private func finish(_ id: UUID, _ outcome: Result<JapaneseLearningReview, Error>) {
        guard let pending = jobs.removeValue(forKey: id) else { return }
        pending.worker?.cancel(); pending.timer?.cancel(); pending.continuation.resume(with: outcome)
    }
    public func cancel(_ id: UUID) { finish(id, .failure(AIFailure.cancelled)) }
}
