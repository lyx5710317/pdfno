// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum DeepSeekSelectionPolicy {
    public static let endpoint = "https://api.deepseek.com"
    public static let model = "deepseek-flash"
    public static let maxSourceUTF16 = 500
    public static let maxOutputTokens = 1024
    public static let maxAttempts = 3
    public static let promptVersion = "deepseek-selection-1"
    public static func supports(_ config: AIProviderConfig) -> Bool {
        guard config.mode == .openAICompatible, config.model == model,
              ProviderValidation.validate(endpoint: config.endpoint, model: config.model),
              let parts = URLComponents(string: config.endpoint), parts.scheme == "https",
              parts.host?.lowercased() == "api.deepseek.com", parts.port == nil || parts.port == 443 else { return false }
        var path = parts.path
        while path.hasSuffix("/") { path.removeLast() }
        return ["", "/v1", "/chat/completions", "/v1/chat/completions"].contains(path)
    }
    public static func configuration() -> AIProviderConfig {
        var value = AIProviderConfig(); value.mode = .openAICompatible; value.label = "DeepSeek"
        value.endpoint = endpoint; value.model = model; return value
    }
}
