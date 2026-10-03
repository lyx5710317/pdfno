// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public enum DeepSeekTestFailure: Error, Sendable, Equatable, LocalizedError {
    case consent, credentials, limit, busy, timeout, cancelled, network, redirect, authentication, quota, rateLimit, server, output, truncated
    public var errorDescription: String? {
        switch self {
        case .consent: "请先确认固定短句的发送范围与费用范围。"
        case .credentials: "请在此入口手动输入有效的临时密钥。"
        case .limit: "本次应用会话的三次测试额度已用完。"
        case .busy: "已有测试正在进行，请等待或取消。"
        case .timeout: "请求已超时；服务商仍可能计费，不会自动重试。"
        case .cancelled: "请求已取消；服务商仍可能计费，不会自动重试。"
        case .network: "网络请求未完成；未验证服务连通，不会自动重试。"
        case .redirect: "已拒绝重定向，密钥不会转发到其他地址。"
        case .authentication: "HTTP 401 / 403：服务商拒绝认证；请自行检查密钥。"
        case .quota: "HTTP 402：服务商报告余额或配额不足。"
        case .rateLimit: "HTTP 429：服务商限制请求频率；不会自动重试。"
        case .server: "服务商拒绝请求或暂时不可用。"
        case .output: "响应格式或大小不符合本次短句测试约定。"
        case .truncated: "服务响应达到输出上限而截断，未计为成功；不会自动重试。"
        }
    }
}

/// Bookless, fixed-scope probe. No library, provider settings, persistent credentials,
/// tools, conversation history, cache, logging or automatic retries are involved.
public actor DeepSeekSelfTest {
    public static let endpoint = "https://api.deepseek.com"
    public static let model = "deepseek-flash"
    public static let sentence = "A small blue bird rests beside a quiet window."
    public static let instruction = "Translate the following original test sentence into Simplified Chinese. Return only one short sentence."
    public static let maxOutputTokens = 128
    public static let maxAttempts = 3
    public static let timeoutSeconds: TimeInterval = 30
    private let transport: any AIHTTPTransport
    private struct Pending {
        let id: UUID
        let continuation: CheckedContinuation<String, Error>
        var worker: Task<Void, Never>?
        var timer: Task<Void, Never>?
    }
    private var pending: Pending?
    private let budget: DeepSeekSelectionBudget
    public init(transport: any AIHTTPTransport = URLSessionAITransport(), budget: DeepSeekSelectionBudget = AppAISession.shared.probe) {
        self.transport = transport; self.budget = budget
    }
    public func attemptsUsed() async -> Int { await budget.attemptsUsed() }

    public func run(temporaryKey: String, confirmedScopeAndBudget: Bool, timeoutSeconds: TimeInterval = DeepSeekSelfTest.timeoutSeconds) async throws -> String {
        guard confirmedScopeAndBudget else { throw DeepSeekTestFailure.consent }
        guard CredentialValidation.valid(temporaryKey) else { throw DeepSeekTestFailure.credentials }
        guard timeoutSeconds.isFinite, timeoutSeconds > 0, timeoutSeconds <= Self.timeoutSeconds else { throw DeepSeekTestFailure.timeout }
        guard pending == nil else { throw DeepSeekTestFailure.busy }
        guard !Task.isCancelled else { throw DeepSeekTestFailure.cancelled }
        let id = UUID()
        // The URL is a literal, never taken from reader content or user configuration.
        var request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!,
                                 cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: timeoutSeconds)
        request.httpMethod = "POST"; request.httpShouldHandleCookies = false
        request.setValue("Bearer " + temporaryKey, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": Self.model, "stream": false, "max_tokens": Self.maxOutputTokens,
            "thinking": ["type": "disabled"], "messages": [
                ["role": "system", "content": Self.instruction], ["role": "user", "content": Self.sentence]
            ]
        ], options: [.sortedKeys])
        let http = request
        do { try await budget.reserve() }
        catch is CancellationError { throw DeepSeekTestFailure.cancelled }
        catch { throw DeepSeekTestFailure.limit }
        guard pending == nil else { throw DeepSeekTestFailure.busy }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard !Task.isCancelled else { continuation.resume(throwing: DeepSeekTestFailure.cancelled); return }
                // Failed, timed-out and cancelled submissions consume an attempt too.
                pending = Pending(id: id, continuation: continuation)
                pending?.worker = Task {
                    do { self.finish(id, outcome: .success(try Self.decode(await transport.send(http)))) }
                    catch { self.finish(id, outcome: .failure(Self.safeError(error))) }
                }
                pending?.timer = Task {
                    do { try await Task.sleep(for: .seconds(timeoutSeconds)) } catch { return }
                    self.finish(id, outcome: .failure(DeepSeekTestFailure.timeout))
                }
            }
        } onCancel: { Task { await self.finish(id, outcome: .failure(DeepSeekTestFailure.cancelled)) } }
    }

    private func finish(_ id: UUID, outcome: Result<String, Error>) {
        guard let current = pending, current.id == id else { return }
        pending = nil
        current.worker?.cancel(); current.timer?.cancel()
        current.continuation.resume(with: outcome)
    }
    private static func decode(_ response: AIHTTPResponse) throws -> String {
        switch response.status {
        case 200...299: break
        case 300...399: throw DeepSeekTestFailure.redirect
        case 401, 403: throw DeepSeekTestFailure.authentication
        case 402: throw DeepSeekTestFailure.quota
        case 429: throw DeepSeekTestFailure.rateLimit
        default: throw DeepSeekTestFailure.server
        }
        guard response.body.count <= 65536,
              let envelope = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              let choices = envelope["choices"] as? [[String: Any]], choices.count == 1 else { throw DeepSeekTestFailure.output }
        if choices[0]["finish_reason"] as? String == "length" { throw DeepSeekTestFailure.truncated }
        guard choices[0]["finish_reason"] as? String == "stop",
              let message = choices[0]["message"] as? [String: Any], message["role"] as? String == "assistant",
              message["tool_calls"] == nil || message["tool_calls"] is NSNull,
              message["function_call"] == nil || message["function_call"] is NSNull,
              let content = message["content"] as? String, !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              content.utf16.count <= 2048 else { throw DeepSeekTestFailure.output }
        return content
    }
    public static func safeError(_ error: Error) -> DeepSeekTestFailure {
        if let known = error as? DeepSeekTestFailure { return known }
        if error as? AIFailure == .output { return .output }
        if error is CancellationError { return .cancelled }
        if let urlError = error as? URLError {
            if urlError.code == .cancelled { return .cancelled }
            if urlError.code == .timedOut { return .timeout }
        }
        return .network // Never show URLSession's raw URL/header/body/error details.
    }
}
