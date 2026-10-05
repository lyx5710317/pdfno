// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit

public enum EnglishLearningPolicy {
    public static let promptVersion = "english-selection-1"
    public static let maxSourceUTF16 = DeepSeekSelectionPolicy.maxSourceUTF16
    public static let maxOutputTokens = DeepSeekSelectionPolicy.maxOutputTokens
    public static let maxResponseBytes = 65536
    public static let maxTimeoutSeconds: Double = 30
    public static let maxComponents = 16
    public static let maxGrammar = 12
    public static func textHash(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

/// Offsets are Unicode scalars within the fixed selection, never resource/UTF-16 offsets.
/// Context is persisted so reopening a record repeats the same exact validation.
public struct EnglishSpan: Codable, Sendable, Equatable {
    public let start: Int
    public let end: Int
    public let quote: String
    public let prefix: String
    public let suffix: String
    public init(start: Int, end: Int, quote: String, prefix: String = "", suffix: String = "") {
        self.start = start; self.end = end; self.quote = quote; self.prefix = prefix; self.suffix = suffix
    }
    public var exactKey: String { "\(start):\(end):" + Data(quote.utf8).base64EncodedString() }
    public func overlaps(_ other: EnglishSpan) -> Bool { start < other.end && other.start < end }
    public func isValid(in text: String) -> Bool {
        guard UnicodeOffsets.quotedSpan(in: text, quote: quote, start: start, end: end) else { return false }
        var boundaries: Set<Int> = [0], offset = 0
        for character in text { offset += String(character).unicodeScalars.count; boundaries.insert(offset) }
        guard boundaries.contains(start), boundaries.contains(end),
              EnglishLearningValidator.plain(prefix, limit: 64, nonempty: false),
              EnglishLearningValidator.plain(suffix, limit: 64, nonempty: false) else { return false }
        let scalars = Array(text.unicodeScalars), p = Array(prefix.unicodeScalars), s = Array(suffix.unicodeScalars)
        guard p.count <= 32, s.count <= 32, p.count <= start, s.count <= scalars.count - end,
              scalars[(start - p.count)..<start].elementsEqual(p),
              scalars[end..<(end + s.count)].elementsEqual(s) else { return false }
        let q = Array(quote.unicodeScalars)
        let matches = (0...(scalars.count - q.count)).filter { scalars[$0..<($0 + q.count)].elementsEqual(q) }
        // Context must distinguish this occurrence, not merely be nonempty.
        if matches.count > 1 {
            guard !p.isEmpty || !s.isEmpty else { return false }
            let candidates = matches.filter { index in
                index >= p.count && index + q.count + s.count <= scalars.count &&
                scalars[(index - p.count)..<index].elementsEqual(p) &&
                scalars[(index + q.count)..<(index + q.count + s.count)].elementsEqual(s)
            }
            guard candidates == [start] else { return false }
        }
        return true
    }
    public func utf16Range(in text: String) throws -> Range<Int> {
        guard isValid(in: text) else { throw SourceValidationError.invalidSpan }
        return try UnicodeOffsets.utf16Offset(in: text, codePointOffset: start)..<UnicodeOffsets.utf16Offset(in: text, codePointOffset: end)
    }
}

public struct EnglishLearningRequest: Sendable {
    public let id: UUID
    public let source: AISourceSnapshot
    public let provider: AIProviderConfig
    public let timeoutSeconds: Double
    public init(id: UUID = UUID(), source: AISourceSnapshot, provider: AIProviderConfig, timeoutSeconds: Double = 30) {
        self.id = id; self.source = source; self.provider = provider; self.timeoutSeconds = timeoutSeconds
    }
    public func validate() throws {
        guard source.isValid else { throw AIFailure.inputLimit }
        switch source.anchor { case .pdf, .epub: break; case .pdfPage, .epubChapter: throw AIFailure.configuration }
        guard source.anchor.quote.utf16.count <= EnglishLearningPolicy.maxSourceUTF16 else { throw AIFailure.remoteInputLimit }
        guard provider.isValid, timeoutSeconds.isFinite, timeoutSeconds > 0,
              timeoutSeconds <= EnglishLearningPolicy.maxTimeoutSeconds else { throw AIFailure.configuration }
        guard provider.mode != .unconfigured else { throw AIFailure.unconfigured }
        guard provider.mode == .mock || DeepSeekSelectionPolicy.supports(provider) else { throw AIFailure.configuration }
    }
}
public enum EnglishSentenceRole: String, Codable, Sendable, CaseIterable {
    case subject, predicate, object, complement, attributive, adverbial, other
    public var labelZh: String {
        switch self {
        case .subject: "主语"; case .predicate: "谓语"; case .object: "宾语"; case .complement: "补语／表语"
        case .attributive: "定语／修饰语"; case .adverbial: "状语"; case .other: "其他结构"
        }
    }
    public var colorLabelZh: String {
        switch self {
        case .subject: "蓝色"; case .predicate: "红色"; case .object: "绿色"; case .attributive: "紫色"
        case .adverbial: "橙色"; case .complement, .other: "正文色"
        }
    }
}
public struct EnglishSentenceComponent: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let role: EnglishSentenceRole
    public let span: EnglishSpan?
    public let ambiguous: Bool
    public let omitted: Bool
    public let inferred: Bool
    public let explanationZh: String
    public init(id: String, role: EnglishSentenceRole, span: EnglishSpan?, ambiguous: Bool,
                omitted: Bool = false, inferred: Bool = false, explanationZh: String) {
        self.id = id; self.role = role; self.span = span; self.ambiguous = ambiguous
        self.omitted = omitted; self.inferred = inferred; self.explanationZh = explanationZh
    }
}
public enum EnglishGrammarAspect: String, Codable, Sendable, CaseIterable {
    case clause, tense, voice, reference, coordination, longSentence
    public var labelZh: String {
        switch self {
        case .clause: "从句"; case .tense: "时态"; case .voice: "语态"; case .reference: "指代"
        case .coordination: "并列结构"; case .longSentence: "长句结构"
        }
    }
}
public struct EnglishGrammarSuggestion: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let aspect: EnglishGrammarAspect
    public let span: EnglishSpan
    public let ambiguous: Bool
    public let explanationZh: String
}
public enum EnglishReviewStatus: String, Codable, Sendable { case reviewable, needsReview, unavailable }
public struct EnglishLearningReview: Codable, Sendable, Equatable {
    public let requestID: UUID
    public let source: AISourceSnapshot
    public let sourceTextSHA256: String
    public let provider: AIProviderConfig
    public let promptVersion: String
    public let translationZh: String?
    public let components: [EnglishSentenceComponent]
    public let grammar: [EnglishGrammarSuggestion]
    public let warnings: [String]
    public let status: EnglishReviewStatus
    init(request: EnglishLearningRequest, translationZh: String?, components: [EnglishSentenceComponent],
         grammar: [EnglishGrammarSuggestion], warnings: [String], status: EnglishReviewStatus) {
        requestID = request.id; source = request.source; provider = request.provider
        sourceTextSHA256 = EnglishLearningPolicy.textHash(request.source.anchor.quote)
        promptVersion = EnglishLearningPolicy.promptVersion; self.translationZh = translationZh
        self.components = components; self.grammar = grammar; self.warnings = warnings; self.status = status
    }
    /// Decoding, matching text, and compiling cannot establish English grammar accuracy.
    public var isPersistable: Bool {
        let request = EnglishLearningRequest(id: requestID, source: source, provider: provider)
        guard (try? request.validate()) != nil, promptVersion == EnglishLearningPolicy.promptVersion,
              sourceTextSHA256 == EnglishLearningPolicy.textHash(source.anchor.quote), status != .unavailable,
              components.count <= EnglishLearningPolicy.maxComponents, grammar.count <= EnglishLearningPolicy.maxGrammar,
              warnings.count <= 64, warnings.allSatisfy({ EnglishLearningValidator.plain($0, limit: 400) }),
              translationZh.map({ EnglishLearningValidator.plain($0, limit: 2000) }) ?? true,
              (status == .reviewable) == warnings.isEmpty,
              Set(components.map(\.id) + grammar.map(\.id)).count == components.count + grammar.count else { return false }
        var keys: Set<String> = []
        for item in components {
            guard EnglishLearningValidator.plain(item.id, limit: 64), EnglishLearningValidator.plain(item.explanationZh, limit: 400),
                  (item.omitted || item.inferred) == (item.span == nil), !item.omitted || item.inferred,
                  !item.inferred || item.ambiguous, item.span.map({ $0.isValid(in: source.anchor.quote) }) ?? true,
                  keys.insert(item.role.rawValue + ":" + (item.span?.exactKey ?? "inferred")).inserted else { return false }
        }
        guard grammar.allSatisfy({ EnglishLearningValidator.plain($0.id, limit: 64) &&
            EnglishLearningValidator.plain($0.explanationZh, limit: 600) && $0.span.isValid(in: source.anchor.quote) }) else { return false }
        return !(components.isEmpty && grammar.isEmpty && warnings.isEmpty) &&
            (!(components.contains { $0.ambiguous || $0.inferred } || grammar.contains { $0.ambiguous }) || !warnings.isEmpty)
    }
}
/// A manual save proposal. Reanalysis creates a new review without overwriting userText.
public struct EnglishLearningNote: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let review: EnglishLearningReview
    public let userText: String
    public init(id: UUID = UUID(), review: EnglishLearningReview, userText: String) throws {
        guard EnglishLearningValidator.plain(userText, limit: 16000, nonempty: false) else { throw AIFailure.output }
        self.id = id; self.review = review; self.userText = userText
    }
    public var isPersistable: Bool { review.isPersistable && EnglishLearningValidator.plain(userText, limit: 16000, nonempty: false) }
}

/// Strict root failures keep only the trusted source; invalid individual suggestions are discarded.
public enum EnglishLearningValidator {
    public static func plain(_ text: String, limit: Int, nonempty: Bool = true) -> Bool {
        text.utf16.count <= limit && !text.unicodeScalars.contains { $0.value == 0 } &&
        (!nonempty || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }
    public static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, ["q", "i", "s", "l"].contains(String(cString: number.objCType)) else { return nil }
        return Int(exactly: number.int64Value)
    }
    private static func boolean(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, ["c", "B"].contains(String(cString: number.objCType)) else { return nil }
        return number.boolValue
    }
    private static func string(_ value: Any?, limit: Int, nonempty: Bool = true) -> String? {
        guard let text = value as? String, plain(text, limit: limit, nonempty: nonempty) else { return nil }; return text
    }
    private static func span(_ row: [String: Any], text: String) -> EnglishSpan? {
        guard let start = integer(row["start"]), let end = integer(row["end"]),
              let quote = string(row["quote"], limit: EnglishLearningPolicy.maxSourceUTF16),
              let prefix = string(row["prefix"], limit: 64, nonempty: false),
              let suffix = string(row["suffix"], limit: 64, nonempty: false) else { return nil }
        let value = EnglishSpan(start: start, end: end, quote: quote, prefix: prefix, suffix: suffix)
        return value.isValid(in: text) ? value : nil
    }
    public static func validate(_ data: Data, request: EnglishLearningRequest) -> EnglishLearningReview {
        func unavailable() -> EnglishLearningReview {
            EnglishLearningReview(request: request, translationZh: nil, components: [], grammar: [],
                warnings: ["英语分析结构或原文引文无法验证；仅保留固定来源，不展示或保存未验证结果。"], status: .unavailable)
        }
        guard (try? request.validate()) != nil, data.count <= EnglishLearningPolicy.maxResponseBytes,
              JapaneseLearningJSON.hasUniqueKeys(data), String(data: data, encoding: .utf8).map({ $0.utf16.count <= 16000 }) == true,
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys) == Set(["schemaVersion", "language", "sourceQuote", "offsetUnit", "translationZh", "components", "grammar", "warnings"]),
              integer(root["schemaVersion"]) == 1, root["language"] as? String == "en",
              root["offsetUnit"] as? String == "unicode-code-point", let text = root["sourceQuote"] as? String,
              text.utf8.elementsEqual(request.source.anchor.quote.utf8),
              let components = root["components"] as? [Any], components.count <= EnglishLearningPolicy.maxComponents,
              let grammar = root["grammar"] as? [Any], grammar.count <= EnglishLearningPolicy.maxGrammar,
              let rawWarnings = root["warnings"] as? [String], rawWarnings.count <= 8,
              rawWarnings.allSatisfy({ plain($0, limit: 300) }) else { return unavailable() }
        let translation: String?
        if root["translationZh"] is NSNull { translation = nil }
        else if let value = string(root["translationZh"], limit: 2000) { translation = value }
        else { return unavailable() }
        var warnings = rawWarnings.map { "模型提示（未核实）：" + $0 }
        var accepted: [EnglishSentenceComponent] = [], acceptedGrammar: [EnglishGrammarSuggestion] = []
        var ids: Set<String> = [], keys: Set<String> = []
        for raw in components {
            guard let row = raw as? [String: Any],
                  Set(row.keys) == Set(["id", "role", "quote", "start", "end", "prefix", "suffix", "certainty", "omitted", "inferred", "explanationZh"]),
                  let id = string(row["id"], limit: 64), ids.insert(id).inserted,
                  let roleValue = row["role"] as? String, let role = EnglishSentenceRole(rawValue: roleValue),
                  let omitted = boolean(row["omitted"]), let inferred = boolean(row["inferred"]),
                  let certainty = row["certainty"] as? String, ["suggestion", "ambiguous"].contains(certainty),
                  let explanation = string(row["explanationZh"], limit: 400) else {
                warnings.append("一条英语成分的结构、角色或解释无效，已排除。"); continue
            }
            let exact: EnglishSpan?
            if omitted || inferred {
                guard inferred, certainty == "ambiguous", row["quote"] is NSNull, row["start"] is NSNull, row["end"] is NSNull,
                      row["prefix"] as? String == "", row["suffix"] as? String == "" else {
                    warnings.append("省略或推断成分不得声明原文范围，已排除；不会虚构高亮。"); continue
                }
                exact = nil
            } else {
                guard let value = span(row, text: text) else {
                    warnings.append("一条英语成分的原文范围或紧邻上下文无效，已排除；没有猜测位置。"); continue
                }
                exact = value
            }
            guard keys.insert(role.rawValue + ":" + (exact?.exactKey ?? "inferred")).inserted else {
                warnings.append("重复的同角色同范围英语成分已排除；其他重叠候选保留。"); continue
            }
            accepted.append(EnglishSentenceComponent(id: id, role: role, span: exact, ambiguous: certainty == "ambiguous",
                omitted: omitted, inferred: inferred, explanationZh: explanation))
        }
        for raw in grammar {
            guard let row = raw as? [String: Any],
                  Set(row.keys) == Set(["id", "aspect", "quote", "start", "end", "prefix", "suffix", "certainty", "explanationZh"]),
                  let id = string(row["id"], limit: 64), ids.insert(id).inserted,
                  let aspectValue = row["aspect"] as? String, let aspect = EnglishGrammarAspect(rawValue: aspectValue),
                  let exact = span(row, text: text), let certainty = row["certainty"] as? String,
                  ["suggestion", "ambiguous"].contains(certainty), let explanation = string(row["explanationZh"], limit: 600) else {
                warnings.append("一条英语语法的结构、原文范围或解释无效，已排除。"); continue
            }
            acceptedGrammar.append(EnglishGrammarSuggestion(id: id, aspect: aspect, span: exact,
                ambiguous: certainty == "ambiguous", explanationZh: explanation))
        }
        if accepted.contains(where: { $0.ambiguous || $0.inferred }) || acceptedGrammar.contains(where: \.ambiguous) {
            warnings.append("英语分析含不确定候选或省略推断；推断仅作解释，不在原句中涂色。")
        }
        if accepted.isEmpty && acceptedGrammar.isEmpty { warnings.append("没有可验证的英语结构条目；只显示原句，不猜测语法。") }
        return EnglishLearningReview(request: request, translationZh: translation, components: accepted, grammar: acceptedGrammar,
            warnings: warnings, status: warnings.isEmpty ? .reviewable : .needsReview)
    }
}
