// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// These finite original sentences are protocol fixtures, not an English parser or accuracy test.
public enum EnglishLearningMockCorpus {
    public static let sentences = [
        "Maya reads a book.", "The letter was written by Maya.",
        "Maya reads and Leo writes.", "The book that Maya bought is useful.",
        "They saw her duck.", "Close the door.", "I read. Then I read again.",
        "When Maya had finished the book that Leo lent her, she returned it because he needed it."
    ]
    public static func payload(for text: String) throws -> Data {
        var components: [[String: Any]] = [], grammar: [[String: Any]] = [], translation: Any = NSNull()
        let scalars = Array(text.unicodeScalars)
        func span(_ start: Int, _ end: Int) -> [String: Any] {
            func slice(_ a: Int, _ b: Int) -> String { String(String.UnicodeScalarView(scalars[a..<b])) }
            return ["quote": slice(start, end), "start": start, "end": end,
                "prefix": slice(max(0, start - 32), start), "suffix": slice(end, min(scalars.count, end + 32))]
        }
        func component(_ id: String, _ role: String, _ start: Int, _ end: Int, _ explanation: String, ambiguous: Bool = false) {
            var row = span(start, end); row.merge(["id": id, "role": role, "certainty": ambiguous ? "ambiguous" : "suggestion",
                "omitted": false, "inferred": false, "explanationZh": explanation]) { _, next in next }; components.append(row)
        }
        func detail(_ id: String, _ aspect: String, _ start: Int, _ end: Int, _ explanation: String, ambiguous: Bool = false) {
            var row = span(start, end); row.merge(["id": id, "aspect": aspect, "certainty": ambiguous ? "ambiguous" : "suggestion",
                "explanationZh": explanation]) { _, next in next }; grammar.append(row)
        }
        let sample = sentences.firstIndex { $0.utf8.elementsEqual(text.utf8) }
        switch sample {
        case 0:
            component("s", "subject", 0, 4, "Maya 是执行阅读动作的主语。")
            component("p", "predicate", 5, 10, "reads 是第三人称单数一般现在时的谓语。")
            component("o", "object", 11, 17, "a book 是 reads 的宾语。")
            detail("t", "tense", 5, 10, "一般现在时可表示习惯；仅此句不能确定实际阅读时间。")
            translation = "玛雅读一本书。"
        case 1:
            component("s", "subject", 0, 10, "The letter 是句子的语法主语，是动作承受者。")
            component("p", "predicate", 11, 22, "was written 构成一般过去时被动谓语。")
            component("a", "adverbial", 23, 30, "by Maya 是施事短语，不把 Maya 误标为此句主语。")
            detail("v", "voice", 11, 30, "be 的过去式加过去分词构成被动语态，by 短语提示施事。")
            translation = "这封信是玛雅写的。"
        case 2:
            component("s1", "subject", 0, 4, "第一分句的主语。")
            component("p1", "predicate", 5, 10, "第一分句的谓语。")
            component("s2", "subject", 15, 18, "第二分句的主语。")
            component("p2", "predicate", 19, 25, "第二分句的谓语。")
            detail("c", "coordination", 0, 25, "and 连接两个各有主语和谓语的并列分句。")
        case 3:
            component("s", "subject", 0, 25, "主语是包含关系从句的完整名词短语。")
            component("a", "attributive", 9, 25, "that Maya bought 修饰 book，与主语范围嵌套；选择后单独显示。")
            component("p", "predicate", 26, 28, "is 是主句的系动词。")
            component("c", "complement", 29, 35, "useful 是表语，说明主语性质。")
            detail("r", "clause", 9, 25, "关系词 that 指 book，在从句中作 bought 的宾语。")
            translation = "玛雅买的那本书很有用。"
        case 4:
            component("s", "subject", 0, 4, "They 是主语；具体指谁缺乏上下文。", ambiguous: true)
            component("p", "predicate", 5, 8, "saw 是 see 的过去式。")
            component("o1", "object", 9, 17, "her duck 可理解为她的鸭子，整个名词短语作宾语。", ambiguous: true)
            component("o2", "object", 9, 12, "另一读法中 her 是 saw 的宾语。", ambiguous: true)
            component("c", "complement", 13, 17, "另一读法中 duck 是省略 to 的动词补语，意为低头躲避。", ambiguous: true)
            detail("r", "reference", 9, 12, "her 可作物主限定词或宾格代词；不能仅凭此句自动消歧。", ambiguous: true)
        case 5:
            components.append(["id": "s", "role": "subject", "quote": NSNull(), "start": NSNull(), "end": NSNull(),
                "prefix": "", "suffix": "", "certainty": "ambiguous", "omitted": true, "inferred": true,
                "explanationZh": "祈使句常省略第二人称主语 you；这是结构推断，you 不在原文中。"])
            component("p", "predicate", 0, 5, "Close 是祈使句谓语。")
            component("o", "object", 6, 14, "the door 是动作对象。")
        case 6:
            component("s1", "subject", 0, 1, "第一句主语 I。")
            component("p1", "predicate", 2, 6, "第一处 read；没有把第二处匹配到此处。", ambiguous: true)
            component("s2", "subject", 13, 14, "第二句主语 I。")
            component("p2", "predicate", 15, 19, "第二处 read，通过原始位置和上下文区分。", ambiguous: true)
            component("a", "adverbial", 20, 25, "again 修饰第二句谓语。")
            detail("t", "tense", 15, 19, "read 的现在和过去式拼写相同，语境不足时保留时态不确定。", ambiguous: true)
        case 7:
            component("s", "subject", 51, 54, "she 是主句主语，候选指代 Maya，需核对上下文。", ambiguous: true)
            component("p", "predicate", 55, 63, "returned 是主句谓语。")
            component("o", "object", 64, 66, "it 是宾语，候选指代书，需核对上下文。", ambiguous: true)
            component("a1", "adverbial", 0, 49, "When 引导时间状语从句，内部还嵌有关系从句。")
            component("a2", "adverbial", 67, 87, "because 引导原因状语从句。")
            detail("l", "longSentence", 0, 87, "先找主句 she returned it，再审阅 when 时间从句与 because 原因从句。")
            detail("t", "tense", 10, 22, "had finished 为过去完成时，表示早于主句过去动作的完成。")
            detail("r", "reference", 51, 66, "she 与 it 的指代是上下文候选，不作为确定事实。", ambiguous: true)
        default: break
        }
        return try JSONSerialization.data(withJSONObject: ["schemaVersion": 1, "language": "en", "sourceQuote": text,
            "offsetUnit": "unicode-code-point", "translationZh": translation, "components": components, "grammar": grammar,
            "warnings": ["离线合成演示：仅内置原创例句提供预写候选；不联网，不证明模型或真实英语语法质量。"]], options: [.sortedKeys])
    }
}
