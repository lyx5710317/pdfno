// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if DEBUG
import Foundation
import PDFnoDomain
import PDFnoServices

/// Explicit isolated UI-test mode only. Every submission terminates here;
/// there is no URLSession fallback, even for malformed input.
actor OfflineSelectionUITestTransport: AIHTTPTransport {
    private var requests = 0
    private let japaneseScenario = ProcessInfo.processInfo.environment["PDFNO_UI_TEST_JAPANESE_RESPONSE"]
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
        if payload["task"] == "japanese-selection-learning" {
            if japaneseScenario == "slow" { try await Task.sleep(for: .seconds(30)) }
            let first = String(quote.first ?? "日"), end = first.unicodeScalars.count
            let components: [[String: Any]]
            if japaneseScenario == "components" {
                // Synthetic overlapping/omitted roles exercise review interactions only.
                // They are explicitly ambiguous, never a language-quality assertion.
                components = [
                    ["id": "c1", "role": "subject", "quote": quote, "start": 0, "end": quote.unicodeScalars.count, "prefix": "", "suffix": "", "certainty": "ambiguous", "omitted": false, "explanationZh": "合成主语候选：仅验证蓝色显示和点击解释。"],
                    ["id": "c2", "role": "topic", "quote": quote, "start": 0, "end": quote.unicodeScalars.count, "prefix": "", "suffix": "", "certainty": "ambiguous", "omitted": false, "explanationZh": "合成主题候选：与主语分开，仅验证重叠切层。"],
                    ["id": "c3", "role": "object", "quote": first, "start": 0, "end": end, "prefix": "", "suffix": String(quote.dropFirst().prefix(1)), "certainty": "ambiguous", "omitted": false, "explanationZh": "合成宾语候选：仅验证绿色片段和解释切换。"],
                    ["id": "c4", "role": "subject", "quote": NSNull(), "start": NSNull(), "end": NSNull(), "prefix": "", "suffix": "", "certainty": "ambiguous", "omitted": true, "explanationZh": "合成省略主语：只在解释区演示，不增加原文跨度或涂色。"]]
            } else { components = JapaneseLearningMockComponents.rows(quote) }
            let content: Data
            if japaneseScenario == "invalid" { content = Data("invalid synthetic Japanese response".utf8) }
            else {
                content = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "language": "ja", "sourceQuote": quote,
                    "offsetUnit": "unicode-code-point", "translationZh": "[离线日语 UI 替身] 仅验证来源和保存，不代表语言质量。",
                    "readings": [["id": "r1", "quote": first, "start": 0, "end": end, "prefix": "", "suffix": String(quote.dropFirst().prefix(1)),
                        "candidates": ["あ"], "certainty": "suggestion", "explanationZh": "合成读音，仅供协议演示。"]],
                    "grammar": [["id": "g1", "quote": quote, "start": 0, "end": quote.unicodeScalars.count, "prefix": "", "suffix": "",
                        "labelZh": "离线语法结构示例", "explanationZh": "此合成解释只检验审阅和来源，不判断选文语法。"]], "components": components, "warnings": ["离线 UI transport，没有真实语言判断。"]])
            }
            return AIHTTPResponse(status: 200, body: try JSONSerialization.data(withJSONObject: ["choices": [[
                "finish_reason": "stop", "message": ["role": "assistant", "tool_calls": NSNull(), "content": String(decoding: content, as: UTF8.self)]
            ]]]))
        }
        let output = try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "sourceQuote": quote,
            "text": "[离线 DeepSeek UI 替身] " + (payload["task"] == "translate" ? "翻译" : "解释") + " · 只验证来源与笔记，不代表真实语言质量。"])
        return AIHTTPResponse(status: 200, body: try JSONSerialization.data(withJSONObject: ["choices": [[
            "finish_reason": "stop", "message": ["role": "assistant", "tool_calls": NSNull(), "content": String(decoding: output, as: UTF8.self)]
        ]]]))
    }
}
#endif
