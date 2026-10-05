// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// No credential, transport or quota owner is created by the grammar module.
/// Remote adapters use the host's same AppAISession.selection and credentials.
public protocol EnglishLearningProvider: Sendable {
    var mode: AIProviderMode { get }
    func analyze(_ request: EnglishLearningRequest) async throws -> Data
    func attemptsUsed() async -> Int
}
extension EnglishLearningProvider { public func attemptsUsed() async -> Int { 0 } }

/// Uses the existing host transport, session-only credential reference, and shared selection quota.
/// Never creates another credential/budget owner. The host must inject its AILearningModel session.
public struct DeepSeekEnglishLearningProvider: EnglishLearningProvider {
    public let mode = AIProviderMode.openAICompatible
    private let transport: any AIHTTPTransport
    private let credentials: any AICredentialStore
    private let reference: UUID
    private let budget: DeepSeekSelectionBudget
    public init(transport: any AIHTTPTransport, credentials: any AICredentialStore,
                credentialReference: UUID, aiSession: AppAISession) {
        self.transport = transport; self.credentials = credentials; reference = credentialReference; budget = aiSession.selection
    }
    public func attemptsUsed() async -> Int { await budget.attemptsUsed() }
    public func analyze(_ request: EnglishLearningRequest) async throws -> Data {
        try request.validate(); guard request.provider.mode == mode else { throw AIFailure.configuration }
        let url = try DeepSeekSelectionProvider.finalURL(request.provider)
        try Task.checkCancellation()
        guard let key = try await credentials.read(reference), CredentialValidation.valid(key) else { throw AIFailure.credentials }
        try Task.checkCancellation() // A cancelled credential read never reserves or submits.
        let input = try EnglishLearningPrompt.userContent(for: request)
        var http = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: request.timeoutSeconds)
        http.httpMethod = "POST"; http.httpShouldHandleCookies = false
        http.setValue("Bearer " + key, forHTTPHeaderField: "Authorization")
        http.setValue("application/json", forHTTPHeaderField: "Content-Type")
        http.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": DeepSeekSelectionPolicy.model, "stream": false, "max_tokens": EnglishLearningPolicy.maxOutputTokens,
            "thinking": ["type": "disabled"], "response_format": ["type": "json_object"], "messages": [
                ["role": "system", "content": EnglishLearningPrompt.system],
                ["role": "user", "content": String(decoding: input, as: UTF8.self)]
            ]
        ], options: [.sortedKeys])
        try await budget.reserve() // Same three attempts, including failures/cancellation. No retry.
        try Task.checkCancellation()
        return try EnglishLearningResponseDecoder.decode(await transport.send(http))
    }
}
/// An injected offline response source for envelope/lifecycle tests. There is no URLSession path.
public protocol EnglishLearningOfflineTransport: Sendable {
    func send(_ body: Data) async throws -> AIHTTPResponse
}
public struct OfflineEnvelopeEnglishLearningProvider: EnglishLearningProvider {
    public let mode = AIProviderMode.mock
    private let transport: any EnglishLearningOfflineTransport
    public init(transport: any EnglishLearningOfflineTransport) { self.transport = transport }
    public func analyze(_ request: EnglishLearningRequest) async throws -> Data {
        try request.validate(); guard request.provider.mode == .mock else { throw AIFailure.configuration }
        try Task.checkCancellation()
        let body = try JSONSerialization.data(withJSONObject: ["sourceText": request.source.anchor.quote,
            "task": "english-selection-learning", "max_tokens": EnglishLearningPolicy.maxOutputTokens,
            "stream": false], options: [.sortedKeys])
        return try EnglishLearningResponseDecoder.decode(await transport.send(body))
    }
}
public enum EnglishLearningResponseDecoder {
    public static func decode(_ response: AIHTTPResponse) throws -> Data {
        switch response.status {
        case 200...299: break
        case 300...399: throw AIFailure.redirect
        case 401, 403: throw AIFailure.authentication
        case 402: throw AIFailure.quota
        case 429: throw AIFailure.rateLimit
        default: throw AIFailure.server
        }
        guard response.body.count <= EnglishLearningPolicy.maxResponseBytes, JapaneseLearningJSON.hasUniqueKeys(response.body),
              let root = try? JSONSerialization.jsonObject(with: response.body) as? [String: Any],
              Set(root.keys).isSubset(of: ["id", "object", "created", "model", "choices", "usage", "system_fingerprint", "service_tier"]),
              ["id", "object", "model"].allSatisfy({ root[$0] == nil || (root[$0] as? String).map({ EnglishLearningValidator.plain($0, limit: 300) }) == true }),
              root["created"] == nil || EnglishLearningValidator.integer(root["created"]).map({ $0 >= 0 }) == true,
              ["system_fingerprint", "service_tier"].allSatisfy({ root[$0] == nil || root[$0] is NSNull || root[$0] is String }),
              let choices = root["choices"] as? [[String: Any]], choices.count == 1,
              let choice = choices.first, Set(choice.keys).isSubset(of: ["index", "message", "finish_reason", "logprobs"]),
              choice["logprobs"] == nil || choice["logprobs"] is NSNull,
              EnglishLearningValidator.integer(choice["index"]) == 0 else { throw AIFailure.output }
        if choice["finish_reason"] as? String == "length" { throw AIFailure.truncated }
        guard choice["finish_reason"] as? String == "stop", let message = choice["message"] as? [String: Any],
              Set(message.keys).isSubset(of: ["role", "content", "tool_calls", "function_call", "refusal", "reasoning_content"]),
              message["role"] as? String == "assistant",
              ["tool_calls", "function_call", "refusal"].allSatisfy({ message[$0] == nil || message[$0] is NSNull }),
              message["reasoning_content"] == nil || message["reasoning_content"] is NSNull || message["reasoning_content"] as? String == "",
              let content = message["content"] as? String, content.utf16.count <= 16000,
              let data = content.data(using: .utf8), data.count <= EnglishLearningPolicy.maxResponseBytes else { throw AIFailure.output }
        if let rawUsage = root["usage"], !(rawUsage is NSNull) {
            guard let usage = rawUsage as? [String: Any],
                  Set(usage.keys).isSubset(of: ["prompt_tokens", "completion_tokens", "total_tokens", "prompt_cache_hit_tokens", "prompt_cache_miss_tokens", "prompt_tokens_details", "completion_tokens_details"]),
                  ["prompt_tokens", "completion_tokens", "total_tokens", "prompt_cache_hit_tokens", "prompt_cache_miss_tokens"].allSatisfy({ key in
                      usage[key] == nil || EnglishLearningValidator.integer(usage[key]).map({ $0 >= 0 }) == true
                  }),
                  details(usage["prompt_tokens_details"], keys: ["cached_tokens"]),
                  details(usage["completion_tokens_details"], keys: ["reasoning_tokens", "accepted_prediction_tokens", "rejected_prediction_tokens"]) else { throw AIFailure.output }
            if let count = EnglishLearningValidator.integer(usage["completion_tokens"]), count > EnglishLearningPolicy.maxOutputTokens { throw AIFailure.truncated }
        }
        return data
    }
    private static func details(_ raw: Any?, keys: Set<String>) -> Bool {
        guard let raw, !(raw is NSNull) else { return true }
        guard let value = raw as? [String: Any], Set(value.keys).isSubset(of: keys) else { return false }
        return value.values.allSatisfy { EnglishLearningValidator.integer($0).map { $0 >= 0 } == true }
    }
}

/// Self-authored fixed examples. Every reply says it is an offline synthetic demonstration.
public struct LocalMockEnglishLearningProvider: EnglishLearningProvider {
    public let mode = AIProviderMode.mock
    public init() {}
    public func analyze(_ request: EnglishLearningRequest) async throws -> Data {
        try request.validate(); guard request.provider.mode == .mock else { throw AIFailure.configuration }
        try Task.checkCancellation()
        return try EnglishLearningMockCorpus.payload(for: request.source.anchor.quote)
    }
}
public struct UnavailableEnglishLearningProvider: EnglishLearningProvider {
    public let mode: AIProviderMode
    public let failure: AIFailure
    public init(mode: AIProviderMode = .unconfigured, failure: AIFailure = .unconfigured) { self.mode = mode; self.failure = failure }
    public func analyze(_ request: EnglishLearningRequest) throws -> Data { throw failure }
}
