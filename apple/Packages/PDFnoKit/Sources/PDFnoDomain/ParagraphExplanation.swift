// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// A selection-only profile of the existing text job. No new session, tools or persistence schema.
public enum AISelectionProfile: String, Sendable { case legacy, paragraphExplanation }
public enum ParagraphExplanationPolicy {
    public static let promptVersion = "paragraph-explanation-1"
    public static let skillID = "pdfno.reading.paragraph-explanation"
    public static func validate(_ request: AIRequest) throws {
        guard request.profile == .paragraphExplanation, request.kind == .explain else { throw AIFailure.configuration }
        switch request.source.anchor { case .pdf, .epub: break; default: throw AIFailure.configuration }
        guard request.source.isValid, !request.source.anchor.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, request.source.anchor.quote.utf16.count <= 500 else { throw AIFailure.remoteInputLimit }
        guard request.provider.isValid, request.provider.mode != .unconfigured,
              request.timeoutSeconds.isFinite, request.timeoutSeconds > 0, request.timeoutSeconds <= 30 else { throw AIFailure.configuration }
        if request.provider.mode != .mock { try BYOKSelectionPolicy.validate(request) }
    }
}
public struct ParagraphCitation: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    public let sourceRefID: String
    public let startScalar: Int
    public let endScalar: Int
    public let quote: String
    public var span: JapaneseSpan { .init(start: startScalar, end: endScalar, quote: quote) }
    /// EPUB derives a true canonical UTF-16 subrange. PDF retains original verified regions;
    /// a text offset cannot establish a new PDF rectangle.
    public func navigationSource(in source: AISourceSnapshot) throws -> AISourceSnapshot {
        let range = try span.utf16Range(in: source.anchor.quote)
        guard sourceRefID == "source-1" else { throw AIFailure.output }
        switch source.anchor {
        case .pdf: return source
        case .epub(let anchor):
            let scalars = Array(source.anchor.quote.unicodeScalars)
            let before = String(String.UnicodeScalarView(scalars[..<startScalar]))
            let after = String(String.UnicodeScalarView(scalars[endScalar...]))
            let prefix = String(String.UnicodeScalarView(Array((anchor.prefix + before).unicodeScalars.suffix(32))))
            let suffix = String(String.UnicodeScalarView(Array((after + anchor.suffix).unicodeScalars.prefix(32))))
            let sub = EPUBAnchor(editionID: anchor.editionID, fileSHA256: anchor.fileSHA256,
                resourceHref: anchor.resourceHref, spineIndex: anchor.spineIndex,
                start: anchor.start + range.lowerBound, end: anchor.start + range.upperBound,
                quote: quote, prefix: prefix, suffix: suffix, vertical: anchor.vertical)
            guard sub.isValid else { throw AIFailure.output }
            return .init(bookID: source.bookID, readerSessionID: source.readerSessionID,
                documentVersion: source.documentVersion, anchor: .epub(sub))
        default: throw AIFailure.configuration
        }
    }
}
public struct ParagraphExplanationItem: Codable, Sendable, Equatable, Identifiable {
    public enum Kind: String, Codable, Sendable { case paraphrase, term, inference
        public var title: String { switch self { case .paraphrase: "释义"; case .term: "术语说明"; case .inference: "模型推断 · 待核对" } }
    }
    public enum Uncertainty: String, Codable, Sendable { case none, tentative }
    public let id: String
    public let kind: Kind
    public let text: String
    public let evidenceRefs: [String]
    public let uncertainty: Uncertainty
}
public struct ParagraphExplanation: Codable, Sendable, Equatable {
    public enum Status: String, Codable, Sendable { case complete, insufficientEvidence = "insufficient_evidence" }
    public enum Reason: String, Codable, Sendable { case ambiguousText = "ambiguous_text", noSupportedExplanation = "no_supported_explanation" }
    public struct Payload: Codable, Sendable, Equatable { public let items: [ParagraphExplanationItem] }
    public let resultSchemaVersion: Int
    public let skillID: String
    public let scope: String
    public let targetLanguage: String
    public let status: Status
    public let insufficiencyReason: Reason?
    public let citations: [ParagraphCitation]
    public let payload: Payload
    public var canSave: Bool { status == .complete }
    public var displayText: String {
        if status == .insufficientEvidence {
            return insufficiencyReason == .ambiguousText ? "选文含义不明确，证据不足；请重新选择更明确的片段。" : "选文没有足够依据支持解释；没有生成可保存的解释。"
        }
        return payload.items.map { item in
            item.kind.title + "：" + item.text + "\n" + citations.filter { item.evidenceRefs.contains($0.id) }.map { "原文依据 [" + $0.id + "]：" + $0.quote }.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
}
public enum ParagraphExplanationValidator {
    /// Throw a fixed safe error; never repair JSON, expose raw service content or salvage nodes.
    public static func validate(_ data: Data, source: AISourceSnapshot) throws -> ParagraphExplanation {
        switch source.anchor { case .pdf, .epub: break; default: throw AIFailure.output }
        guard source.isValid, source.anchor.quote.utf16.count <= 500,
              data.count <= 65536, String(data: data, encoding: .utf8) != nil,
              JapaneseLearningJSON.hasUniqueKeys(data),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              Set(root.keys) == Set(["resultSchemaVersion", "skillID", "scope", "targetLanguage", "status", "insufficiencyReason", "citations", "payload"]),
              let citations = root["citations"] as? [[String: Any]], citations.count <= 6,
              citations.allSatisfy({ Set($0.keys) == Set(["id", "sourceRefID", "startScalar", "endScalar", "quote"]) }),
              let payload = root["payload"] as? [String: Any], Set(payload.keys) == Set(["items"]),
              let items = payload["items"] as? [[String: Any]], items.count <= 3,
              items.allSatisfy({ Set($0.keys) == Set(["id", "kind", "text", "evidenceRefs", "uncertainty"]) }),
              let result = try? JSONDecoder().decode(ParagraphExplanation.self, from: data),
              result.resultSchemaVersion == 1, result.skillID == ParagraphExplanationPolicy.skillID,
              result.scope == "selection", result.targetLanguage == "zh-Hans" else { throw AIFailure.output }
        // JSONDecoder may accept numeric booleans/floating point integers on some Foundation versions.
        func integer(_ value: Any?) -> Bool {
            guard let n = value as? NSNumber else { return false }
            return String(cString: n.objCType) != "c" && n.doubleValue.isFinite && n.doubleValue.rounded() == n.doubleValue
        }
        guard integer(root["resultSchemaVersion"]), citations.allSatisfy({ integer($0["startScalar"]) && integer($0["endScalar"]) }) else { throw AIFailure.output }
        if result.status == .insufficientEvidence {
            guard result.insufficiencyReason != nil, result.citations.isEmpty, result.payload.items.isEmpty else { throw AIFailure.output }
            return result
        }
        guard result.insufficiencyReason == nil, !result.citations.isEmpty, !result.payload.items.isEmpty else { throw AIFailure.output }
        func validID(_ id: String) -> Bool { !id.isEmpty && id.utf8.count <= 64 && id.utf8.allSatisfy { (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 } }
        var ids = Set<String>()
        for citation in result.citations {
            guard validID(citation.id), ids.insert(citation.id).inserted, citation.sourceRefID == "source-1",
                  !citation.quote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, citation.quote.utf16.count <= 120,
                  citation.span.isValid(in: source.anchor.quote) else { throw AIFailure.output }
        }
        let citationIDs = Set(result.citations.map(\.id))
        var used = Set<String>()
        for item in result.payload.items {
            guard validID(item.id), ids.insert(item.id).inserted,
                  !item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, item.text.utf16.count <= 180,
                  item.text.range(of: "<[^>]+>", options: .regularExpression) == nil,
                  !item.text.contains("```"),
                  item.evidenceRefs.count >= 1, item.evidenceRefs.count <= 2,
                  Set(item.evidenceRefs).count == item.evidenceRefs.count,
                  Set(item.evidenceRefs).isSubset(of: citationIDs),
                  item.uncertainty == (item.kind == .inference ? .tentative : .none) else { throw AIFailure.output }
            used.formUnion(item.evidenceRefs)
        }
        guard used == citationIDs else { throw AIFailure.output }
        return result
    }
}
extension AIResult {
    public var paragraphExplanation: ParagraphExplanation? {
        guard kind == .explain, promptVersion == ParagraphExplanationPolicy.promptVersion else { return nil }
        return try? ParagraphExplanationValidator.validate(Data(text.utf8), source: source)
    }
    public var displayText: String { promptVersion == ParagraphExplanationPolicy.promptVersion ? paragraphExplanation?.displayText ?? AIFailure.output.localizedDescription : text }
    public var canSaveSelectionResult: Bool { promptVersion != ParagraphExplanationPolicy.promptVersion || paragraphExplanation?.canSave == true }
}
