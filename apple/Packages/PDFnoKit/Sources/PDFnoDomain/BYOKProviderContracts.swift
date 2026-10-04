// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// A finite wire contract, not a claim that every vendor or model implements it.
public enum BYOKProviderCapability: String, Sendable {
    case officialDeepSeek, httpsChatCompletionsJSON
    public var explanation: String {
        switch self {
        case .officialDeepSeek:
            "官方 DeepSeek 既有选文协议；关闭 thinking，使用固定模型。"
        case .httpsChatCompletionsJSON:
            "需服务支持 Bearer 认证、chat/completions、system/user 消息、stream:false、max_tokens、response_format:json_object，并返回单个 assistant JSON 结果及 finish_reason:stop。兼容性和语言质量未经真实服务验证。"
        }
    }
}
public enum BYOKSelectionPolicy {
    public static let maxSourceUTF16 = DeepSeekSelectionPolicy.maxSourceUTF16
    public static let maxOutputTokens = DeepSeekSelectionPolicy.maxOutputTokens
    public static let timeoutSeconds: Double = 30
    public static func capability(_ config: AIProviderConfig) throws -> BYOKProviderCapability {
        _ = try finalURL(config)
        return DeepSeekSelectionPolicy.supports(config) ? .officialDeepSeek : .httpsChatCompletionsJSON
    }
    /// A root uses /v1/chat/completions; a base path appends /chat/completions once.
    /// No local HTTP, userinfo, query, fragment, encoded authority or redirect discovery.
    public static func finalURL(_ config: AIProviderConfig) throws -> URL {
        guard config.mode == .openAICompatible, config.isValid,
              !config.endpoint.contains("\\"),
              var parts = URLComponents(string: config.endpoint), parts.scheme == "https",
              let host = parts.host, !host.isEmpty,
              host.unicodeScalars.allSatisfy({ $0.isASCII && $0.value > 32 && $0.value != 127 }),
              !host.contains("%"), let encodedHost = parts.percentEncodedHost, !encodedHost.contains("%"),
              parts.user == nil, parts.password == nil,
              parts.query == nil, parts.fragment == nil,
              parts.port == nil || (1...65535).contains(parts.port!),
              !parts.path.unicodeScalars.contains(where: { $0.value <= 32 || $0.value == 127 }) else { throw AIFailure.configuration }
        if DeepSeekSelectionPolicy.supports(config) { return URL(string: "https://api.deepseek.com/chat/completions")! }
        while parts.path.hasSuffix("/") { parts.path.removeLast() }
        if parts.path.isEmpty { parts.path = "/v1/chat/completions" }
        else if !parts.path.hasSuffix("/chat/completions") { parts.path += "/chat/completions" }
        guard let url = parts.url, url.host != nil else { throw AIFailure.configuration }
        return url
    }
    public static func validate(_ request: AIRequest) throws {
        _ = try finalURL(request.provider)
        guard request.timeoutSeconds.isFinite, request.timeoutSeconds > 0, request.timeoutSeconds <= timeoutSeconds else { throw AIFailure.configuration }
        switch request.source.anchor {
        case .pdf, .epub: break
        case .pdfPage, .epubChapter: throw AIFailure.configuration
        }
        guard request.source.isValid, request.source.anchor.quote.utf16.count <= maxSourceUTF16 else { throw AIFailure.remoteInputLimit }
    }
}
