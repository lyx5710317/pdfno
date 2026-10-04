// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Fixed original examples and binding demonstrations only; never dictionary/model judgments.
public enum JapaneseLearningMockComponents {
    public static func rows(_ quote: String) -> [[String: Any]] {
        func item(_ id: String, _ role: String, _ text: String, _ start: Int, _ prefix: String, _ suffix: String, _ explanation: String) -> [String: Any] {
            ["id": id, "role": role, "quote": text, "start": start, "end": start + text.unicodeScalars.count,
             "prefix": prefix, "suffix": suffix, "certainty": "ambiguous", "omitted": false, "explanationZh": explanation]
        }
        if quote == "私は本を読む。" {
            return [item("c-topic", "topic", "私は", 0, "", "本", "原创固定示例：は标示主题；主题与语法主语分别审阅。"),
                    item("c-object", "object", "本を", 2, "は", "読", "原创固定示例：本を为动作对象候选。"),
                    item("c-predicate", "predicate", "読む", 4, "を", "。", "原创固定示例：読む为谓语候选。"),
                    ["id": "c-omitted", "role": "subject", "quote": NSNull(), "start": NSNull(), "end": NSNull(),
                     "prefix": "", "suffix": "", "certainty": "ambiguous", "omitted": true,
                     "explanationZh": "省略主语只作为推测演示，不为原文增加词语或跨度；真实上下文判断未验证。"]]
        }
        // UI transport uses a synthetic role solely to exercise the blue subject interaction.
        // The source quote is exact, and the explanation explicitly denies a language judgment.
        return [item("c-binding", "subject", quote, 0, "", "", "合成主语候选仅验证分色、点击与来源绑定，不判断选文语言或语法正确性。")]
    }
}
