// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Independent selection-only contract. No change to AIRequest, persisted notes or reader anchors.
public enum JapaneseLearningPolicy {
    public static let promptVersion = "japanese-selection-2"
    public static let legacyPromptVersion = "japanese-selection-1"
    public static let maxComponents = 16
    public static let maxSourceUTF16 = DeepSeekSelectionPolicy.maxSourceUTF16
    public static let maxOutputTokens = DeepSeekSelectionPolicy.maxOutputTokens
    public static let maxTimeoutSeconds: Double = 30
    public static let maxReadings = 32
    public static let maxGrammar = 16
}
public struct JapaneseSpan: Codable, Sendable, Equatable, Hashable {
    public let start: Int
    public let end: Int
    public let quote: String
    public init(start: Int, end: Int, quote: String) { self.start = start; self.end = end; self.quote = quote }
    public func isValid(in text: String) -> Bool {
        guard UnicodeOffsets.quotedSpan(in: text, quote: quote, start: start, end: end) else { return false }
        // Display ranges must not split combining kana, IVS, surrogate pairs or ZWJ emoji.
        var boundaries: Set<Int> = [0], offset = 0
        for character in text { offset += String(character).unicodeScalars.count; boundaries.insert(offset) }
        return boundaries.contains(start) && boundaries.contains(end)
    }
    public func overlaps(_ other: JapaneseSpan) -> Bool { start < other.end && other.start < end }
    public func utf16Range(in text: String) throws -> Range<Int> {
        guard isValid(in: text) else { throw SourceValidationError.invalidSpan }
        return try UnicodeOffsets.utf16Offset(in: text, codePointOffset: start)..<UnicodeOffsets.utf16Offset(in: text, codePointOffset: end)
    }
    /// Source byte spelling is part of the correction key (Swift String equality is insufficient).
    public var correctionKey: String { "\(start):\(end):" + Data(quote.utf8).base64EncodedString() }
}
public struct JapaneseAuthorReading: Codable, Sendable, Equatable {
    public let span: JapaneseSpan
    public let reading: String
    public init(span: JapaneseSpan, reading: String) { self.span = span; self.reading = reading }
}
public struct JapaneseLearningRequest: Sendable {
    public let id: UUID
    public let source: AISourceSnapshot
    public let provider: AIProviderConfig
    public let authorReadings: [JapaneseAuthorReading]
    public let timeoutSeconds: Double
    public init(id: UUID = UUID(), source: AISourceSnapshot, provider: AIProviderConfig,
                authorReadings: [JapaneseAuthorReading] = [], timeoutSeconds: Double = 30) {
        self.id = id; self.source = source; self.provider = provider
        self.authorReadings = authorReadings; self.timeoutSeconds = timeoutSeconds
    }
    public func validate() throws {
        guard source.isValid else { throw AIFailure.inputLimit }
        switch source.anchor { case .pdf, .epub: break; case .pdfPage, .epubChapter: throw AIFailure.configuration }
        guard source.anchor.quote.utf16.count <= JapaneseLearningPolicy.maxSourceUTF16 else { throw AIFailure.remoteInputLimit }
        guard provider.isValid, timeoutSeconds.isFinite, timeoutSeconds > 0,
              timeoutSeconds <= JapaneseLearningPolicy.maxTimeoutSeconds else { throw AIFailure.configuration }
        guard provider.mode != .unconfigured else { throw AIFailure.unconfigured }
        guard provider.mode == .mock || DeepSeekSelectionPolicy.supports(provider) else { throw AIFailure.configuration }
        guard authorReadings.count <= JapaneseLearningPolicy.maxReadings,
              authorReadings.allSatisfy({ $0.span.isValid(in: source.anchor.quote) && !$0.reading.isEmpty && $0.reading.utf16.count <= 100 }) else { throw AIFailure.output }
    }
}
public struct JapaneseReadingSuggestion: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let span: JapaneseSpan
    public let candidates: [String]
    public let ambiguous: Bool
    public let explanationZh: String
}
public struct JapaneseGrammarSuggestion: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let span: JapaneseSpan
    public let labelZh: String
    public let explanationZh: String
}
public enum JapaneseReviewStatus: String, Codable, Sendable { case reviewable, needsReview, unavailable }
public struct JapaneseLearningReview: Codable, Sendable, Equatable {
    public let requestID: UUID
    public let source: AISourceSnapshot
    public let provider: AIProviderConfig
    public let promptVersion: String
    public let authorReadings: [JapaneseAuthorReading]
    public let translationZh: String?
    public let readings: [JapaneseReadingSuggestion]
    public let grammar: [JapaneseGrammarSuggestion]
    public let warnings: [String]
    public let components: [JapaneseSentenceComponent]
    public let status: JapaneseReviewStatus
    init(request: JapaneseLearningRequest, translationZh: String?, readings: [JapaneseReadingSuggestion],
         grammar: [JapaneseGrammarSuggestion], warnings: [String], status: JapaneseReviewStatus, components: [JapaneseSentenceComponent] = []) {
        requestID = request.id; source = request.source; provider = request.provider
        promptVersion = JapaneseLearningPolicy.promptVersion; authorReadings = request.authorReadings
        self.translationZh = translationZh; self.readings = readings; self.grammar = grammar
        self.warnings = warnings; self.status = status; self.components = components
    }
    private enum CodingKeys: String, CodingKey { case requestID, source, provider, promptVersion, authorReadings, translationZh, readings, grammar, warnings, status, components }
    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        requestID = try values.decode(UUID.self, forKey: .requestID)
        source = try values.decode(AISourceSnapshot.self, forKey: .source)
        provider = try values.decode(AIProviderConfig.self, forKey: .provider)
        promptVersion = try values.decode(String.self, forKey: .promptVersion)
        authorReadings = try values.decode([JapaneseAuthorReading].self, forKey: .authorReadings)
        translationZh = try values.decodeIfPresent(String.self, forKey: .translationZh)
        readings = try values.decode([JapaneseReadingSuggestion].self, forKey: .readings)
        grammar = try values.decode([JapaneseGrammarSuggestion].self, forKey: .grammar)
        warnings = try values.decode([String].self, forKey: .warnings)
        status = try values.decode(JapaneseReviewStatus.self, forKey: .status)
        components = try values.decodeIfPresent([JapaneseSentenceComponent].self, forKey: .components) ?? []
    }
}
public struct JapaneseReadingCorrection: Codable, Sendable, Equatable {
    public let span: JapaneseSpan
    public let reading: String
    public init(span: JapaneseSpan, reading: String) { self.span = span; self.reading = reading }
}
/// A manual-save proposal for the host, not an automatic write or an existing-note update.
public struct JapaneseLearningNote: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let review: JapaneseLearningReview
    public let userText: String
    public let corrections: [JapaneseReadingCorrection]
    public init(id: UUID = UUID(), review: JapaneseLearningReview, userText: String, corrections: [JapaneseReadingCorrection]) throws {
        guard userText.utf16.count <= 16000, corrections.count <= JapaneseLearningPolicy.maxReadings,
              Set(corrections.map { $0.span.correctionKey }).count == corrections.count,
              corrections.allSatisfy({ correction in
                  JapaneseLearningValidator.isKana(correction.reading) && review.readings.contains {
                      $0.span.correctionKey == correction.span.correctionKey
                  }
              }) else { throw AIFailure.output }
        self.id = id; self.review = review; self.userText = userText; self.corrections = corrections
    }
}

/// Never repairs/normalizes a model offset. Structural errors yield a trusted-source-only review;
/// bad entries are dropped with fixed warnings. Accepted spans are suggestions, not quality proof.
public enum JapaneseLearningValidator {
    public static func isKana(_ text: String) -> Bool {
        !text.isEmpty && text.utf16.count <= 100 && text.unicodeScalars.allSatisfy {
            (0x3041...0x3096).contains($0.value) || (0x3099...0x309F).contains($0.value) ||
            (0x30A1...0x30FA).contains($0.value) || (0x30FC...0x30FF).contains($0.value) || (0xFF66...0xFF9F).contains($0.value)
        }
    }
    private static func string(_ value: Any?, limit: Int, nonempty: Bool = true) -> String? {
        guard let value = value as? String, value.utf16.count <= limit,
              !value.unicodeScalars.contains(where: { $0.value == 0 }),
              !nonempty || !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return value
    }
    private static func integer(_ value: Any?) -> Int? {
        // NSNumber bridging must not admit booleans, decimals or exponent-form offsets.
        guard let value = value as? NSNumber, ["q", "i", "s", "l"].contains(String(cString: value.objCType)) else { return nil }
        return Int(exactly: value.int64Value)
    }
    private static func contextMatches(_ item: [String: Any], span: JapaneseSpan, text: String) -> Bool {
        guard let prefix = string(item["prefix"], limit: 64, nonempty: false),
              let suffix = string(item["suffix"], limit: 64, nonempty: false) else { return false }
        let scalars = Array(text.unicodeScalars), p = Array(prefix.unicodeScalars), s = Array(suffix.unicodeScalars)
        guard p.count <= 32, s.count <= 32, p.count <= span.start, s.count <= scalars.count - span.end,
              scalars[(span.start - p.count)..<span.start].elementsEqual(p),
              scalars[span.end..<(span.end + s.count)].elementsEqual(s) else { return false }
        let q = Array(span.quote.unicodeScalars)
        var occurrences = 0
        for index in 0...(scalars.count - q.count) where scalars[index..<(index + q.count)].elementsEqual(q) { occurrences += 1 }
        return occurrences <= 1 || !p.isEmpty || !s.isEmpty
    }
    private static func span(_ item: [String: Any], text: String) -> JapaneseSpan? {
        guard let start = integer(item["start"]), let end = integer(item["end"]),
              let quote = string(item["quote"], limit: JapaneseLearningPolicy.maxSourceUTF16) else { return nil }
        let span = JapaneseSpan(start: start, end: end, quote: quote)
        guard span.isValid(in: text), contextMatches(item, span: span, text: text) else { return nil }
        return span
    }
    public static func validate(_ data: Data, request: JapaneseLearningRequest) -> JapaneseLearningReview {
        func unavailable() -> JapaneseLearningReview {
            JapaneseLearningReview(request: request, translationZh: nil, readings: [], grammar: [],
                warnings: ["模型输出结构或原文引文无法验证；仅保留固定来源供审阅，不展示或定位未验证内容。"], status: .unavailable)
        }
        guard (try? request.validate()) != nil, data.count <= 65536, JapaneseLearningJSON.hasUniqueKeys(data),
              String(data: data, encoding: .utf8).map({ $0.utf16.count <= 16000 }) == true,
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(["schemaVersion", "language", "sourceQuote", "offsetUnit", "translationZh", "readings", "grammar", "warnings"]).isSubset(of: Set(object.keys)),
              Set(object.keys).isSubset(of: Set(["schemaVersion", "language", "sourceQuote", "offsetUnit", "translationZh", "readings", "grammar", "warnings", "components"])),
              integer(object["schemaVersion"]) == 1, object["language"] as? String == "ja",
              object["offsetUnit"] as? String == "unicode-code-point",
              let quote = object["sourceQuote"] as? String, quote.utf8.elementsEqual(request.source.anchor.quote.utf8),
              let readings = object["readings"] as? [[String: Any]], readings.count <= JapaneseLearningPolicy.maxReadings,
              let grammar = object["grammar"] as? [[String: Any]], grammar.count <= JapaneseLearningPolicy.maxGrammar,
              let modelWarnings = object["warnings"] as? [String], modelWarnings.count <= 8,
              modelWarnings.allSatisfy({ string($0, limit: 300) != nil }) else { return unavailable() }
        let components: [[String: Any]]
        if let raw = object["components"] {
            guard let rows = raw as? [[String: Any]], rows.count <= JapaneseLearningPolicy.maxComponents else { return unavailable() }
            components = rows
        } else { components = [] } // Older valid reading/grammar replies remain a visibly partial review.
        let translation: String?
        if object["translationZh"] is NSNull { translation = nil }
        else if let value = string(object["translationZh"], limit: 2000) { translation = value }
        else { return unavailable() }
        var warnings = modelWarnings.map { "模型提示（未核实）：" + $0 }
        var acceptedReadings: [JapaneseReadingSuggestion] = [], acceptedGrammar: [JapaneseGrammarSuggestion] = []
        var ids: Set<String> = []
        for item in readings {
            guard Set(item.keys) == Set(["id", "quote", "start", "end", "prefix", "suffix", "candidates", "certainty", "explanationZh"]),
                  let id = string(item["id"], limit: 64), ids.insert(id).inserted,
                  let span = span(item, text: quote), let candidates = item["candidates"] as? [String],
                  !candidates.isEmpty, candidates.count <= 4, candidates.allSatisfy(isKana), Set(candidates).count == candidates.count,
                  let certainty = item["certainty"] as? String, ["suggestion", "ambiguous"].contains(certainty),
                  certainty == "ambiguous" || candidates.count == 1,
                  let explanation = string(item["explanationZh"], limit: 300, nonempty: certainty == "ambiguous") else {
                warnings.append("一条读音的结构、原文范围、上下文或假名无效，已排除；没有猜测位置。")
                continue
            }
            if request.authorReadings.contains(where: { $0.span.overlaps(span) }) {
                warnings.append("一条生成读音与作者 ruby 范围重叠，已排除；作者读音保留。")
                continue
            }
            acceptedReadings.append(JapaneseReadingSuggestion(id: id, span: span, candidates: candidates,
                ambiguous: certainty == "ambiguous", explanationZh: explanation))
        }
        // Overlapping reading layers are not implicitly combined; grammar overlaps are allowed.
        let conflicts = acceptedReadings.filter { candidate in acceptedReadings.contains { $0.id != candidate.id && $0.span.overlaps(candidate.span) } }
        if !conflicts.isEmpty {
            let ids = Set(conflicts.map(\.id)); acceptedReadings.removeAll { ids.contains($0.id) }
            warnings.append("生成读音范围相互重叠，冲突条目已排除；可缩小选区后手动重新确认。")
        }
        for item in grammar {
            guard Set(item.keys) == Set(["id", "quote", "start", "end", "prefix", "suffix", "labelZh", "explanationZh"]),
                  let id = string(item["id"], limit: 64), ids.insert(id).inserted,
                  let span = span(item, text: quote), let label = string(item["labelZh"], limit: 80),
                  let explanation = string(item["explanationZh"], limit: 600) else {
                warnings.append("一条语法解释的结构、原文范围或上下文无效，已排除；没有猜测位置。")
                continue
            }
            acceptedGrammar.append(JapaneseGrammarSuggestion(id: id, span: span, labelZh: label, explanationZh: explanation))
        }
        var acceptedComponents: [JapaneseSentenceComponent] = [], componentKeys: Set<String> = []
        for item in components {
            guard Set(item.keys) == Set(["id", "role", "quote", "start", "end", "prefix", "suffix", "certainty", "omitted", "explanationZh"]),
                  let id = string(item["id"], limit: 64), ids.insert(id).inserted,
                  let roleValue = item["role"] as? String, let role = JapaneseSentenceRole(rawValue: roleValue),
                  let omittedValue = item["omitted"] as? NSNumber, ["c", "B"].contains(String(cString: omittedValue.objCType)),
                  let certainty = item["certainty"] as? String, ["suggestion", "ambiguous"].contains(certainty),
                  let explanation = string(item["explanationZh"], limit: 400) else {
                warnings.append("一条句子成分的结构、角色或解释无效，已排除。"); continue
            }
            let omitted = omittedValue.boolValue
            let componentSpan: JapaneseSpan?
            if omitted {
                guard certainty == "ambiguous", item["quote"] is NSNull, item["start"] is NSNull, item["end"] is NSNull,
                      item["prefix"] as? String == "", item["suffix"] as? String == "" else {
                    warnings.append("省略成分不得声明原文引文或跨度，已排除；不会在原文中虚构词语。"); continue
                }
                componentSpan = nil
            } else {
                guard let exact = span(item, text: quote) else {
                    warnings.append("一条句子成分的原文范围或上下文无法验证，已排除；没有涂色或猜测位置。"); continue
                }
                componentSpan = exact
            }
            let key = role.rawValue + ":" + (componentSpan?.correctionKey ?? "omitted")
            guard componentKeys.insert(key).inserted else {
                warnings.append("重复的同角色同范围成分已排除；其他重叠或嵌套候选分别保留。"); continue
            }
            acceptedComponents.append(JapaneseSentenceComponent(id: id, role: role, span: componentSpan,
                ambiguous: certainty == "ambiguous", omitted: omitted, explanationZh: explanation))
        }
        if acceptedComponents.contains(where: { $0.ambiguous || $0.omitted }) { warnings.append("句子成分含不确定候选或省略推测；文字标签与解释保留，省略成分不在原句中涂色。") }
        if acceptedReadings.contains(where: \.ambiguous) { warnings.append("部分读音存在上下文歧义，候选仅供审阅；请核对或填写用户修正。") }
        if acceptedReadings.isEmpty && acceptedGrammar.isEmpty { warnings.append("没有可验证的生成读音或语法条目；不会自动注音或高亮。") }
        return JapaneseLearningReview(request: request, translationZh: translation, readings: acceptedReadings,
            grammar: acceptedGrammar, warnings: warnings, status: warnings.isEmpty ? .reviewable : .needsReview, components: acceptedComponents)
    }
}

/// JSONSerialization collapses duplicate members. Reject them before either payload or envelope
/// decoding, including escaped spellings of a key. JSONSerialization still owns syntax validation.
public enum JapaneseLearningJSON {
    public static func hasUniqueKeys(_ data: Data) -> Bool { uniqueKeys(data, maxBytes: 65536) }
    public static func hasUniqueKeysForStore(_ data: Data) -> Bool { uniqueKeys(data, maxBytes: 5 * 1024 * 1024) }
    private static func uniqueKeys(_ data: Data, maxBytes: Int) -> Bool {
        guard data.count <= maxBytes else { return false }
        struct Frame { var keys: Set<String>?; var expectingKey: Bool }
        let bytes = Array(data)
        var stack: [Frame] = [], index = 0
        while index < bytes.count {
            switch bytes[index] {
            case 123: stack.append(Frame(keys: [], expectingKey: true))
            case 91: stack.append(Frame(keys: nil, expectingKey: false))
            case 125, 93:
                guard let frame = stack.popLast(), (bytes[index] == 125) == (frame.keys != nil) else { return false }
            case 44:
                if !stack.isEmpty, stack[stack.count - 1].keys != nil { stack[stack.count - 1].expectingKey = true }
            case 34:
                let start = index; index += 1
                while index < bytes.count {
                    if bytes[index] == 92 { index += 2; continue }
                    if bytes[index] == 34 { break }
                    index += 1
                }
                guard index < bytes.count else { return false }
                if !stack.isEmpty, stack[stack.count - 1].keys != nil, stack[stack.count - 1].expectingKey {
                    guard let key = try? JSONDecoder().decode(String.self, from: Data(bytes[start...index])),
                          stack[stack.count - 1].keys!.insert(key).inserted else { return false }
                    stack[stack.count - 1].expectingKey = false
                }
            default: break
            }
            guard stack.count <= 32 else { return false }
            index += 1
        }
        return stack.isEmpty
    }
}
