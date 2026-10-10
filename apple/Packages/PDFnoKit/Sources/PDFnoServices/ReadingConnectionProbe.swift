// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Tests the applied endpoint/model with one fixed original sentence, never a document.
public actor ReadingConnectionProbe {
    public static let sentence = DeepSeekSelfTest.sentence
    private struct Pending {
        let id: UUID; let continuation: CheckedContinuation<String, Error>
        var worker: Task<Void, Never>?; var timer: Task<Void, Never>?
    }
    private var pending: Pending?
    private var preparing = false
    public init() {}
    public func run(configuration: AIProviderConfig, credentials: any AICredentialStore, reference: UUID,
                    transport: any AIHTTPTransport, budget: DeepSeekSelectionBudget, confirmed: Bool,
                    timeoutSeconds: Double = 30, current: @escaping @Sendable (AIProviderConfig) async -> Bool) async throws -> String {
        guard confirmed else { throw AIFailure.consent }
        guard pending == nil, !preparing, timeoutSeconds.isFinite, timeoutSeconds > 0, timeoutSeconds <= 30 else { throw AIFailure.configuration }
        preparing = true; defer { preparing = false }
        let url = try BYOKSelectionPolicy.finalURL(configuration)
        try Task.checkCancellation(); guard await current(configuration) else { throw AIFailure.stale }
        guard let key = try await credentials.read(reference), CredentialValidation.valid(key) else { throw AIFailure.credentials }
        guard await current(configuration) else { throw AIFailure.stale }; try Task.checkCancellation()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeoutSeconds)
        request.httpMethod = "POST"; request.httpShouldHandleCookies = false
        request.setValue("Bearer " + key, forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let input = try JSONSerialization.data(withJSONObject: ["sourceText": Self.sentence, "task": "translate", "targetLanguage": "zh-Hans"], options: [.sortedKeys])
        var body: [String: Any] = ["model": configuration.model, "stream": false, "max_tokens": 128,
            "response_format": ["type": "json_object"], "messages": [
                ["role": "system", "content": "Translate the fixed original test sentence into Simplified Chinese. Return only JSON with exactly schemaVersion:1, sourceQuote (exact sourceText), text. Do not use tools."],
                ["role": "user", "content": String(decoding: input, as: UTF8.self)]]]
        if DeepSeekSelectionPolicy.supports(configuration) { body["thinking"] = ["type": "disabled"] }
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
        try await budget.reserve(); try Task.checkCancellation()
        let http = request, id = UUID()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard pending == nil, !Task.isCancelled else { continuation.resume(throwing: AIFailure.cancelled); return }
                pending = Pending(id: id, continuation: continuation)
                pending?.worker = Task {
                    do {
                        let response = try await transport.send(http)
                        try Task.checkCancellation(); guard await current(configuration) else { throw AIFailure.stale }
                        let text = try ReadingConversationHTTPProvider.decode(response, quote: Self.sentence).text
                        guard text.utf16.count <= 2048 else { throw AIFailure.output }
                        self.finish(id, .success(text))
                    } catch { self.finish(id, .failure(AIJobCoordinator.safeError(error))) }
                }
                pending?.timer = Task {
                    do { try await Task.sleep(for: .seconds(timeoutSeconds)) } catch { return }
                    self.finish(id, .failure(AIFailure.timeout))
                }
            }
        } onCancel: { Task { await self.finish(id, .failure(AIFailure.cancelled)) } }
    }
    private func finish(_ id: UUID, _ result: Result<String, Error>) {
        guard let active = pending, active.id == id else { return }
        pending = nil; active.worker?.cancel(); active.timer?.cancel(); active.continuation.resume(with: result)
    }
}
