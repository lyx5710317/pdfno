// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if DEBUG
import Foundation
import PDFnoDomain
import PDFnoServices

/// Explicit isolated UI-test mode only. Every submission terminates here;
/// there is no URLSession fallback, even for malformed input.
actor OfflineSelectionUITestTransport: AIHTTPTransport {
    private var requests = 0
    private let pageScenario: String?
    init(pageScenario: String? = nil) { self.pageScenario = pageScenario }

    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        guard request.value(forHTTPHeaderField: "Authorization") == "Bearer synthetic-reading-ui-credential",
              let data = request.httpBody, let body = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let messages = body["messages"] as? [[String: String]], let input = messages.last?["content"]?.data(using: .utf8),
              let payload = try JSONSerialization.jsonObject(with: input) as? [String: String], let quote = payload["sourceText"] else { throw AIFailure.credentials }
        requests += 1
        if pageScenario == "slow" { try await Task.sleep(for: .seconds(30)) }
        if pageScenario == "fail-second", requests == 2 { return AIHTTPResponse(status: 402, body: Data()) }
        let output = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "sourceQuote": quote,
            "text": "[离线 DeepSeek UI 替身] " + (payload["task"] == "translate" ? "翻译" : "解释") + " · 只验证来源与笔记，不代表真实语言质量。"])
        return AIHTTPResponse(status: 200, body: try JSONSerialization.data(withJSONObject: ["choices": [[
            "finish_reason": "stop", "message": ["role": "assistant", "tool_calls": NSNull(), "content": String(decoding: output, as: UTF8.self)]
        ]]]))
    }
}
#endif
