// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain

func japaneseSource(_ quote: String = "猫を見た。猫は静かだ。") -> AISourceSnapshot {
    AISourceSnapshot(bookID: UUID(), readerSessionID: UUID(), documentVersion: 1,
        anchor: .epub(EPUBAnchor(editionID: UUID(), fileSHA256: String(repeating: "a", count: 64),
            resourceHref: "OEBPS/original.xhtml", spineIndex: 0, start: 0, end: quote.utf16.count,
            quote: quote, prefix: "PRIVATE-OUTSIDE-SELECTION", suffix: "PRIVATE-SUFFIX", vertical: true)))
}
func japaneseConfig(mock: Bool = true) -> AIProviderConfig {
    if !mock { return DeepSeekSelectionPolicy.configuration() }
    var value = AIProviderConfig(); value.mode = .mock; value.label = "Explicit offline mock"; return value
}
func japanesePayload(_ source: String, readings: [[String: Any]] = [], grammar: [[String: Any]] = []) -> [String: Any] {
    ["schemaVersion": 1, "language": "ja", "sourceQuote": source, "offsetUnit": "unicode-code-point",
        "translationZh": "看到了猫。猫很安静。", "readings": readings, "grammar": grammar, "warnings": []]
}
func japaneseReading(_ quote: String = "猫", start: Any = 0, end: Any = 1, id: String = "r1",
                     prefix: String = "", suffix: String = "を", candidates: [String] = ["ねこ"], certainty: String = "suggestion") -> [String: Any] {
    ["id": id, "quote": quote, "start": start, "end": end, "prefix": prefix, "suffix": suffix,
        "candidates": candidates, "certainty": certainty, "explanationZh": "结合此选文审阅读音。"]
}
func japaneseGrammar(_ quote: String = "を", start: Any = 1, end: Any = 2, id: String = "g1",
                     prefix: String = "猫", suffix: String = "見") -> [String: Any] {
    ["id": id, "quote": quote, "start": start, "end": end, "prefix": prefix, "suffix": suffix,
        "labelZh": "宾语助词", "explanationZh": "助词を提示动作对象。这只是模型建议。"]
}
func japaneseData(_ object: [String: Any]) throws -> Data { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) }

struct JapaneseLearningDomainTests {
    @Test func exactRepeatedWordsContextAndOverlappingGrammar() throws {
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        let review = JapaneseLearningValidator.validate(try japaneseData(japanesePayload(request.source.anchor.quote,
            readings: [japaneseReading(), japaneseReading(start: 5, end: 6, id: "r2", prefix: "。", suffix: "は")],
            grammar: [japaneseGrammar(), japaneseGrammar("猫を見た", start: 0, end: 4, id: "g2", prefix: "", suffix: "。")])), request: request)
        #expect(review.status == .reviewable && review.readings.count == 2 && review.grammar.count == 2)
        #expect(review.readings[1].span.start == 5)
        #expect(try review.readings[1].span.utf16Range(in: request.source.anchor.quote) == 5..<6)
        #expect(review.source == request.source && review.promptVersion == JapaneseLearningPolicy.promptVersion)
    }
    @Test func badSpanQuoteContextAndRepeatedPhraseWithoutContextAreDropped() throws {
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        let bad = [japaneseReading(start: -1), japaneseReading(start: 1), japaneseReading(end: 999),
            japaneseReading("犬"), japaneseReading(prefix: "犬"), japaneseReading(suffix: "犬"), japaneseReading(suffix: "")]
        for item in bad {
            let review = JapaneseLearningValidator.validate(try japaneseData(japanesePayload(request.source.anchor.quote,
                readings: [item], grammar: [japaneseGrammar()])), request: request)
            #expect(review.readings.isEmpty && review.grammar.count == 1 && review.status == .needsReview)
            #expect(!review.warnings.isEmpty)
        }
    }
    @Test func scalarBoundariesPreserveIVSCombiningKanaAndEmoji() throws {
        let text = "𠮷\u{E0100}か\u{3099}👩🏽‍🚀食べる"
        let scalars = Array(text.unicodeScalars)
        var offset = 0, boundaries: Set<Int> = [0]
        for character in text { offset += String(character).unicodeScalars.count; boundaries.insert(offset) }
        for start in 0..<scalars.count {
            for end in (start + 1)...scalars.count {
                let quote = String(String.UnicodeScalarView(scalars[start..<end]))
                let span = JapaneseSpan(start: start, end: end, quote: quote)
                #expect(span.isValid(in: text) == (boundaries.contains(start) && boundaries.contains(end)))
                if span.isValid(in: text) {
                    let range = try span.utf16Range(in: text)
                    #expect(range.lowerBound == (try UnicodeOffsets.utf16Offset(in: text, codePointOffset: start)))
                    #expect(range.upperBound == (try UnicodeOffsets.utf16Offset(in: text, codePointOffset: end)))
                }
            }
        }
        #expect(!JapaneseSpan(start: 0, end: 1, quote: "𠮷").isValid(in: text))
        #expect(!JapaneseSpan(start: 2, end: 3, quote: "か").isValid(in: text))
    }
    @Test func normalizedQuoteIsNotAcceptedAndWrongUnitsNeverGuessed() throws {
        let source = japaneseSource("か\u{3099}𠮷\u{E0100}猫"), request = JapaneseLearningRequest(source: source, provider: japaneseConfig())
        var payload = japanesePayload(source.anchor.quote); payload["sourceQuote"] = "が𠮷\u{E0100}猫"
        #expect(JapaneseLearningValidator.validate(try japaneseData(payload), request: request).status == .unavailable)
        payload = japanesePayload(source.anchor.quote); payload["offsetUnit"] = "utf16"
        #expect(JapaneseLearningValidator.validate(try japaneseData(payload), request: request).status == .unavailable)
        let split = japaneseReading("𠮷", start: 2, end: 3, suffix: "", candidates: ["よし"])
        #expect(JapaneseLearningValidator.validate(try japaneseData(japanesePayload(source.anchor.quote, readings: [split])), request: request).readings.isEmpty)
    }
    @Test func strictTypedSchemaUnknownKeysBoundsAndInvalidJSON() throws {
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        for change in [["schemaVersion": true], ["schemaVersion": 2], ["language": "en"], ["endpoint": "other"],
                       ["sourceQuote": "wrong"], ["translationZh": 1], ["warnings": [String(repeating: "x", count: 301)]],
                       ["readings": Array(repeating: japaneseReading(), count: 33)]] as [[String: Any]] {
            var object = japanesePayload(request.source.anchor.quote); object.merge(change) { _, new in new }
            let review = JapaneseLearningValidator.validate(try japaneseData(object), request: request)
            #expect(review.status == .unavailable && review.translationZh == nil && review.readings.isEmpty && review.grammar.isEmpty)
            #expect(review.source == request.source)
        }
        #expect(JapaneseLearningValidator.validate(Data("not json PRIVATE RESPONSE".utf8), request: request).status == .unavailable)
        #expect(JapaneseLearningValidator.validate(Data(repeating: 32, count: 65537), request: request).status == .unavailable)
        for change in [["start": true], ["end": false], ["start": 0.5], ["reading": "unknown key"],
                       ["candidates": ["cat"]], ["certainty": "certain"], ["candidates": ["ねこ", "ねこ"]]] as [[String: Any]] {
            var item = japaneseReading(); item.merge(change) { _, new in new }
            let review = JapaneseLearningValidator.validate(try japaneseData(japanesePayload(request.source.anchor.quote, readings: [item])), request: request)
            #expect(review.readings.isEmpty && review.status == .needsReview)
        }
    }
    @Test func authorRubyWinsAndAmbiguousCandidatesRemainReviewable() throws {
        let source = japaneseSource(), author = JapaneseAuthorReading(span: JapaneseSpan(start: 0, end: 1, quote: "猫"), reading: "ねこ")
        let request = JapaneseLearningRequest(source: source, provider: japaneseConfig(), authorReadings: [author])
        let review = JapaneseLearningValidator.validate(try japaneseData(japanesePayload(source.anchor.quote,
            readings: [japaneseReading(), japaneseReading(start: 5, end: 6, id: "r2", prefix: "。", suffix: "は", candidates: ["ねこ", "ネコ"], certainty: "ambiguous")])), request: request)
        #expect(review.authorReadings == [author] && review.readings.count == 1 && review.readings[0].ambiguous)
        #expect(review.status == .needsReview && review.readings[0].candidates == ["ねこ", "ネコ"])
    }
    @Test func duplicateIDsAndConflictingReadingSpansAreRejected() throws {
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        let duplicate = JapaneseLearningValidator.validate(try japaneseData(japanesePayload(request.source.anchor.quote,
            readings: [japaneseReading(), japaneseReading(start: 5, end: 6, prefix: "。", suffix: "は")])), request: request)
        #expect(duplicate.readings.count == 1 && duplicate.status == .needsReview)
        let overlap = JapaneseLearningValidator.validate(try japaneseData(japanesePayload(request.source.anchor.quote,
            readings: [japaneseReading(), japaneseReading("猫を", start: 0, end: 2, id: "r2", suffix: "見", candidates: ["ねこを"])])), request: request)
        #expect(overlap.readings.isEmpty && overlap.status == .needsReview)
    }
    @Test func correctionAndUserBodyRemainSeparateFromGeneratedReview() throws {
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        let review = JapaneseLearningValidator.validate(try japaneseData(japanesePayload(request.source.anchor.quote, readings: [japaneseReading()])), request: request)
        let correction = JapaneseReadingCorrection(span: review.readings[0].span, reading: "ネコ")
        let note = try JapaneseLearningNote(review: review, userText: " 独立正文\nか\u{3099}👩🏽‍🚀 ", corrections: [correction])
        #expect(note.review.readings[0].candidates == ["ねこ"] && note.corrections == [correction])
        #expect(note.userText.utf8.elementsEqual(" 独立正文\nか\u{3099}👩🏽‍🚀 ".utf8))
        #expect(throws: AIFailure.output) { try JapaneseLearningNote(review: review, userText: "", corrections: [JapaneseReadingCorrection(span: correction.span, reading: "not kana")]) }
        #expect(throws: AIFailure.output) { try JapaneseLearningNote(review: review, userText: "", corrections: [correction, correction]) }
        #expect(throws: AIFailure.output) { try JapaneseLearningNote(review: review, userText: String(repeating: "x", count: 16001), corrections: []) }
    }
    @Test func selectionOnlyCapsAndAuthorBoundaryValidation() throws {
        let source = japaneseSource(), config = japaneseConfig()
        try JapaneseLearningRequest(source: japaneseSource(String(repeating: "猫", count: 500)), provider: config).validate()
        #expect(throws: AIFailure.remoteInputLimit) { try JapaneseLearningRequest(source: japaneseSource(String(repeating: "猫", count: 501)), provider: config).validate() }
        for timeout in [Double.nan, .infinity, 0, -1, 30.1] {
            #expect(throws: AIFailure.configuration) { try JapaneseLearningRequest(source: source, provider: config, timeoutSeconds: timeout).validate() }
        }
        guard case .epub(let anchor) = source.anchor else { return }
        let chapter = AISourceSnapshot(bookID: source.bookID, readerSessionID: source.readerSessionID, documentVersion: 1, anchor: .epubChapter(anchor))
        #expect(throws: AIFailure.configuration) { try JapaneseLearningRequest(source: chapter, provider: config).validate() }
        let badRuby = JapaneseAuthorReading(span: JapaneseSpan(start: 1, end: 2, quote: "猫"), reading: "ねこ")
        #expect(throws: AIFailure.output) { try JapaneseLearningRequest(source: source, provider: config, authorReadings: [badRuby]).validate() }
    }
}

extension JapaneseLearningDomainTests {
    @Test func duplicateJSONMembersAndEscapedKeysCannotOverwriteValidatedFields() throws {
        let request = JapaneseLearningRequest(source: japaneseSource(), provider: japaneseConfig())
        let valid = String(decoding: try japaneseData(japanesePayload(request.source.anchor.quote)), as: UTF8.self)
        let duplicate = valid.dropLast() + ",\"schemaVersion\":1}"
        let escaped = valid.dropLast() + ",\"schema\\u0056ersion\":1}"
        for text in [String(duplicate), String(escaped)] {
            #expect(!JapaneseLearningJSON.hasUniqueKeys(Data(text.utf8)))
            #expect(JapaneseLearningValidator.validate(Data(text.utf8), request: request).status == .unavailable)
        }
        #expect(JapaneseLearningJSON.hasUniqueKeys(Data("{\"x\":[{\"k\":\"escaped \\\" { } , [ ]\"},{\"k\":2}]}".utf8)))
        #expect(!JapaneseLearningJSON.hasUniqueKeys(Data("{\"x\":{\"k\":1,\"k\":2}}".utf8)))
    }
}
