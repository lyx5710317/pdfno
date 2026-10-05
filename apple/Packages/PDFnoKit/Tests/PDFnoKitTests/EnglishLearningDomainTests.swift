// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

func englishSource(_ quote: String = "Maya reads a book.", bookID: UUID = UUID()) -> AISourceSnapshot {
    AISourceSnapshot(bookID: bookID, readerSessionID: UUID(), documentVersion: 1,
        anchor: .epub(EPUBAnchor(editionID: UUID(), fileSHA256: String(repeating: "a", count: 64),
            resourceHref: "OEBPS/original.xhtml", spineIndex: 0, start: 0, end: quote.utf16.count,
            quote: quote, prefix: "OUTSIDE-FIXED-SELECTION", suffix: "OUTSIDE-SUFFIX", vertical: false)))
}
func englishConfig() -> AIProviderConfig {
    var config = AIProviderConfig(); config.mode = .mock; config.label = "离线合成演示"; return config
}
func englishRequest(_ text: String = "Maya reads a book.", timeout: Double = 30) -> EnglishLearningRequest {
    EnglishLearningRequest(source: englishSource(text), provider: englishConfig(), timeoutSeconds: timeout)
}
func englishData(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) }
func englishPayload(_ text: String = "Maya reads a book.") throws -> [String: Any] {
    try #require(JSONSerialization.jsonObject(with: EnglishLearningMockCorpus.payload(for: text)) as? [String: Any])
}
func englishReview(_ request: EnglishLearningRequest = englishRequest()) throws -> EnglishLearningReview {
    EnglishLearningValidator.validate(try EnglishLearningMockCorpus.payload(for: request.source.anchor.quote), request: request)
}
func englishExactRow(_ text: String, start: Int, end: Int, id: String = "item", role: String = "object") -> [String: Any] {
    let scalars = Array(text.unicodeScalars)
    func slice(_ a: Int, _ b: Int) -> String { String(String.UnicodeScalarView(scalars[a..<b])) }
    return ["id": id, "role": role, "quote": slice(start, end), "start": start, "end": end,
        "prefix": slice(max(0, start - 32), start), "suffix": slice(end, min(scalars.count, end + 32)),
        "certainty": "suggestion", "omitted": false, "inferred": false, "explanationZh": "原创范围契约样例。"]
}

struct EnglishLearningDomainTests {
    @Test func finiteCorpusHasDistinctEnglishRolesAndGrammarAspects() throws {
        var roles: Set<EnglishSentenceRole> = [], aspects: Set<EnglishGrammarAspect> = []
        for text in EnglishLearningMockCorpus.sentences {
            let request = englishRequest(text), review = try englishReview(request)
            #expect(review.status == .needsReview && review.isPersistable && !review.components.isEmpty)
            #expect(review.sourceTextSHA256 == EnglishLearningPolicy.textHash(text))
            #expect(review.source == request.source && review.promptVersion == "english-selection-1")
            #expect(review.warnings.count == (review.components.contains { $0.ambiguous || $0.inferred } || review.grammar.contains { $0.ambiguous } ? 2 : 1))
            roles.formUnion(review.components.map(\.role)); aspects.formUnion(review.grammar.map(\.aspect))
        }
        #expect(roles == [.subject, .predicate, .object, .complement, .attributive, .adverbial])
        #expect(aspects == Set(EnglishGrammarAspect.allCases))
    }
    @Test func activeAndPassiveDoNotConfuseAgentWithSubject() throws {
        let active = try englishReview(), passive = try englishReview(englishRequest(EnglishLearningMockCorpus.sentences[1]))
        #expect(active.components.map(\.role) == [.subject, .predicate, .object])
        #expect(passive.components.first?.span?.quote == "The letter")
        #expect(passive.components.last?.role == .adverbial && passive.components.last?.span?.quote == "by Maya")
        #expect(passive.grammar.first?.aspect == .voice)
    }
    @Test func longSentenceHasExactMainClauseAndSeparateExplanation() throws {
        let review = try englishReview(englishRequest(EnglishLearningMockCorpus.sentences[7]))
        #expect(review.components.map { $0.span!.quote } == ["she", "returned", "it", "When Maya had finished the book that Leo lent her", "because he needed it"])
        #expect(review.grammar.map(\.aspect) == [.longSentence, .tense, .reference])
    }
    @Test func overlapsRemainAndSelectedCandidateProjectsOneExactLayer() throws {
        let review = try englishReview(englishRequest(EnglishLearningMockCorpus.sentences[3]))
        #expect(EnglishSentenceProjection.hasOverlaps(review.components))
        for selection in [nil, "s", "a"] as [String?] {
            let runs = EnglishSentenceProjection.runs(source: review.source.anchor.quote, components: review.components, selectedID: selection)
            #expect(runs.map(\.text).joined().utf8.elementsEqual(review.source.anchor.quote.utf8))
            if selection == "a" { #expect(runs.contains { $0.componentID == "a" } && !runs.contains { $0.componentID == "s" }) }
            #expect(zip(runs, runs.dropFirst()).allSatisfy { $0.end == $1.start })
        }
    }
    @Test func ambiguousDuckHasTwoInterpretationsWithoutAutomaticChoice() throws {
        let review = try englishReview(englishRequest("They saw her duck."))
        #expect(review.components.filter { $0.role == .object }.count == 2)
        #expect(review.components.filter { $0.role == .object }.allSatisfy { $0.ambiguous })
        #expect(review.components.contains { $0.role == .complement && $0.span?.quote == "duck" })
        #expect(review.grammar.first?.ambiguous == true)
    }
    @Test func omittedSubjectIsOnlyAnInferenceAndHasNoHighlight() throws {
        let review = try englishReview(englishRequest("Close the door.")), inferred = try #require(review.components.first)
        #expect(inferred.omitted && inferred.inferred && inferred.ambiguous && inferred.span == nil)
        let runs = EnglishSentenceProjection.runs(source: review.source.anchor.quote, components: review.components, selectedID: inferred.id)
        #expect(!runs.contains { $0.componentID == inferred.id })
        #expect(runs.map(\.text).joined() == "Close the door.")
    }
    @Test func inferredOrOmittedItemsCannotInventSourceSpans() throws {
        let request = englishRequest("Close the door."), original = try englishPayload("Close the door.")
        for change in [["quote": "you"], ["start": 0], ["end": 1], ["inferred": false], ["certainty": "suggestion"], ["prefix": "x"]] as [[String: Any]] {
            var payload = original, rows = payload["components"] as! [[String: Any]]
            rows[0].merge(change) { _, next in next }; payload["components"] = rows
            let review = EnglishLearningValidator.validate(try englishData(payload), request: request)
            #expect(review.components.count == 2 && !review.components.contains { $0.omitted })
            #expect(review.isPersistable && review.status == .needsReview)
        }
    }
    @Test func repeatedTermsUseExactOccurrenceAndDisambiguatingContext() throws {
        let request = englishRequest("I read. Then I read again."), review = try englishReview(request)
        #expect(review.components.first { $0.id == "p2" }?.span?.start == 15)
        #expect(try review.components.first { $0.id == "p2" }?.span?.utf16Range(in: request.source.anchor.quote) == 15..<19)
        let text = "cat cat cat"
        #expect(!EnglishSpan(start: 4, end: 7, quote: "cat").isValid(in: text))
        #expect(!EnglishSpan(start: 4, end: 7, quote: "cat", prefix: " ").isValid(in: text))
        #expect(EnglishSpan(start: 4, end: 7, quote: "cat", prefix: "cat ", suffix: " cat").isValid(in: text))
        #expect(!EnglishSpan(start: 8, end: 11, quote: "cat", prefix: "cat ", suffix: " cat").isValid(in: text))
    }
    @Test func allGraphemeBoundariesConvertScalarsToUTF16WithoutSplitting() throws {
        let text = "e\u{301} 👩🏽‍🚀\r\n‘read’ 𠮷\u{E0100}"
        let scalars = Array(text.unicodeScalars)
        var boundaries: Set<Int> = [0], position = 0
        for character in text { position += String(character).unicodeScalars.count; boundaries.insert(position) }
        for start in 0..<scalars.count { for end in (start + 1)...scalars.count {
            let row = englishExactRow(text, start: start, end: end)
            let span = EnglishSpan(start: start, end: end, quote: row["quote"] as! String, prefix: row["prefix"] as! String, suffix: row["suffix"] as! String)
            #expect(span.isValid(in: text) == (boundaries.contains(start) && boundaries.contains(end)))
            if span.isValid(in: text) {
                let range = try span.utf16Range(in: text)
                #expect(range.lowerBound == (try UnicodeOffsets.utf16Offset(in: text, codePointOffset: start)))
                #expect(range.upperBound == (try UnicodeOffsets.utf16Offset(in: text, codePointOffset: end)))
            }
        } }
    }
    @Test func normalizationTrimmingAndWrongOffsetUnitsAreNeverRepaired() throws {
        let request = englishRequest("e\u{301} reads.\r\n")
        for change in [["sourceQuote": "é reads.\r\n"], ["sourceQuote": "e\u{301} reads."], ["offsetUnit": "utf16"]] {
            var payload = try englishPayload(request.source.anchor.quote); payload.merge(change) { _, next in next }
            let review = EnglishLearningValidator.validate(try englishData(payload), request: request)
            #expect(review.status == .unavailable && !review.isPersistable && review.components.isEmpty)
        }
        #expect(!EnglishSpan(start: 0, end: 1, quote: "e").isValid(in: request.source.anchor.quote))
        #expect(EnglishLearningPolicy.textHash("é") != EnglishLearningPolicy.textHash("e\u{301}"))
    }
    @Test func invalidRootTypesUnknownFieldsAndBudgetsYieldUnavailable() throws {
        let request = englishRequest()
        for change in [["schemaVersion": true], ["schemaVersion": 2], ["language": "ja"], ["secret": "not accepted"],
            ["translationZh": 1], ["components": "wrong"], ["grammar": NSNull()], ["warnings": [1]],
            ["components": Array(repeating: NSNull(), count: 17)], ["grammar": Array(repeating: NSNull(), count: 13)],
            ["translationZh": String(repeating: "x", count: 2001)]] as [[String: Any]] {
            var payload = try englishPayload(); payload.merge(change) { _, next in next }
            let review = EnglishLearningValidator.validate(try englishData(payload), request: request)
            #expect(review.status == .unavailable && review.translationZh == nil && review.components.isEmpty && review.grammar.isEmpty)
            #expect(review.source == request.source && !review.isPersistable)
        }
    }
    @Test func malformedTruncatedDuplicateEscapedJSONAndOversizeAreRejected() throws {
        let request = englishRequest(), data = try EnglishLearningMockCorpus.payload(for: request.source.anchor.quote)
        let text = String(decoding: data, as: UTF8.self)
        for bad in [Data("invalid untrusted response".utf8), Data(data.dropLast()),
            Data((text.dropLast() + ",\"schemaVersion\":1}").utf8),
            Data((text.dropLast() + ",\"schema\\u0056ersion\":1}").utf8), Data(repeating: 32, count: 65537)] {
            let review = EnglishLearningValidator.validate(bad, request: request)
            #expect(review.status == .unavailable && !review.isPersistable && review.warnings.count == 1)
        }
    }
    @Test func decimalAndExponentOffsetsAreNotIntegerTokens() throws {
        let request = englishRequest(), text = String(decoding: try EnglishLearningMockCorpus.payload(for: request.source.anchor.quote), as: UTF8.self)
        for replacement in ["1.0", "1e0"] {
            let root = text.replacingOccurrences(of: "\"schemaVersion\":1", with: "\"schemaVersion\":" + replacement)
            #expect(EnglishLearningValidator.validate(Data(root.utf8), request: request).status == .unavailable)
        }
        for replacement in ["0.0", "0e0"] {
            let row = text.replacingOccurrences(of: "\"start\":0", with: "\"start\":" + replacement)
            let review = EnglishLearningValidator.validate(Data(row.utf8), request: request)
            #expect(review.components.count == 2 && !review.components.contains { $0.id == "s" })
        }
    }
    @Test func badSingleRowsDropWithFixedWarningAndKeepGoodSuggestions() throws {
        let request = englishRequest(), original = try englishPayload()
        for change in [["start": true], ["end": false], ["start": 0.5], ["start": -1], ["end": 999],
            ["quote": "wrong"], ["prefix": "wrong"], ["role": "topic"], ["omitted": 1], ["inferred": 0],
            ["extra": "x"], ["certainty": "certain"]] as [[String: Any]] {
            var payload = original, rows = payload["components"] as! [[String: Any]]
            rows[0].merge(change) { _, next in next }; payload["components"] = rows
            let review = EnglishLearningValidator.validate(try englishData(payload), request: request)
            #expect(review.components.count == 2 && review.status == .needsReview && review.isPersistable)
            #expect(!review.components.contains { $0.id == "s" })
        }
        var payload = original; payload["components"] = [NSNull(), (original["components"] as! [[String: Any]])[1]]
        #expect(EnglishLearningValidator.validate(try englishData(payload), request: request).components.count == 1)
    }
    @Test func duplicateIDsAndSameRoleRangeAreDroppedButNestedRolesStay() throws {
        var payload = try englishPayload(), rows = payload["components"] as! [[String: Any]]
        rows[1]["id"] = rows[0]["id"]; payload["components"] = rows
        #expect(EnglishLearningValidator.validate(try englishData(payload), request: englishRequest()).components.count == 2)
        rows = (try englishPayload())["components"] as! [[String: Any]]
        var duplicate = rows[0]; duplicate["id"] = "another"; rows.append(duplicate); payload["components"] = rows
        #expect(EnglishLearningValidator.validate(try englishData(payload), request: englishRequest()).components.count == 3)
    }
    @Test func unknownSelectionNeverPretendsToHaveBeenParsed() async throws {
        let request = englishRequest("Self-authored unknown sentence."), data = try await LocalMockEnglishLearningProvider().analyze(request)
        let review = EnglishLearningValidator.validate(data, request: request)
        #expect(review.components.isEmpty && review.grammar.isEmpty && review.translationZh == nil && review.status == .needsReview)
        #expect(review.warnings.contains { $0.contains("离线合成演示") })
    }
    @Test func selectionCapsRejectPageChapterAndUnconfiguredProvider() throws {
        #expect(throws: AIFailure.remoteInputLimit) { try englishRequest(String(repeating: "a", count: 501)).validate() }
        try englishRequest(String(repeating: "👩", count: 250)).validate()
        #expect(throws: AIFailure.remoteInputLimit) { try englishRequest(String(repeating: "👩", count: 251)).validate() }
        let source = englishSource()
        if case .epub(let anchor) = source.anchor {
            let chapter = AISourceSnapshot(bookID: source.bookID, readerSessionID: source.readerSessionID, documentVersion: 1, anchor: .epubChapter(anchor))
            #expect(throws: AIFailure.configuration) { try EnglishLearningRequest(source: chapter, provider: englishConfig()).validate() }
        }
        #expect(throws: AIFailure.unconfigured) { try EnglishLearningRequest(source: source, provider: AIProviderConfig()).validate() }
        for seconds in [0, -1, .infinity, .nan, 30.01] {
            #expect(throws: AIFailure.configuration) { try englishRequest(timeout: seconds).validate() }
        }
    }
    @Test func syntheticPDFSnapshotRetainsGeometryAndExactQuote() throws {
        let anchor = PDFSourceAnchor(editionID: UUID(), fileSHA256: String(repeating: "b", count: 64), quote: "Maya reads a book.",
            regions: [PageRegion(pageIndex: 0, x: 10, y: 20, width: 200, height: 18, quote: "Maya reads a book.")])
        let source = AISourceSnapshot(bookID: UUID(), readerSessionID: UUID(), documentVersion: 1, anchor: .pdf(anchor))
        let review = try englishReview(EnglishLearningRequest(source: source, provider: englishConfig()))
        #expect(review.source == source && review.isPersistable)
    }
}
