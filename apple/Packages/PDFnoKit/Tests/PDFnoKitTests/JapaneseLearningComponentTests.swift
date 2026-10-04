// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

func japaneseComponent(_ source: String, role: String, start: Int, end: Int, id: String) -> [String: Any] {
    let scalars = Array(source.unicodeScalars)
    func slice(_ a: Int, _ b: Int) -> String { String(String.UnicodeScalarView(scalars[a..<b])) }
    return ["id": id, "role": role, "quote": slice(start, end), "start": start, "end": end,
        "prefix": slice(max(0, start - 1), start), "suffix": slice(end, min(scalars.count, end + 1)),
        "certainty": "suggestion", "omitted": false, "explanationZh": role + " 的原创中文候选解释。"]
}
func japaneseOmitted(_ role: String = "subject", id: String = "omitted") -> [String: Any] {
    ["id": id, "role": role, "quote": NSNull(), "start": NSNull(), "end": NSNull(), "prefix": "", "suffix": "",
        "certainty": "ambiguous", "omitted": true, "explanationZh": "省略仅为上下文推测，不在原文中插入词语或虚构跨度。"]
}
func japaneseComponentReview(_ source: String, rows: [[String: Any]]) throws -> JapaneseLearningReview {
    let request = JapaneseLearningRequest(source: japaneseSource(source), provider: japaneseConfig())
    var payload = japanesePayload(source); payload["components"] = rows
    return JapaneseLearningValidator.validate(try japaneseData(payload), request: request)
}
private actor JapaneseComponentDeferred: JapaneseLearningProvider {
    nonisolated let mode = AIProviderMode.mock
    var continuation: CheckedContinuation<Data, Error>?
    func attemptsUsed() -> Int { 0 }
    func started() -> Bool { continuation != nil }
    func analyze(_ request: JapaneseLearningRequest) async throws -> Data { try await withCheckedThrowingContinuation { continuation = $0 } }
    func finish(_ source: String) throws {
        var payload = japanesePayload(source); payload["components"] = [japaneseComponent(source, role: "subject", start: 0, end: source.unicodeScalars.count, id: "subject")]
        continuation?.resume(returning: try japaneseData(payload)); continuation = nil
    }
}
@MainActor
struct JapaneseLearningComponentTests {
    @Test func topicSubjectFiveRolesAndOmittedSubjectStayIndependent() throws {
        let text = "私は昨日買った本を読む。"
        let rows = [japaneseComponent(text, role: "topic", start: 0, end: 2, id: "topic"),
            japaneseComponent(text, role: "adverbial", start: 2, end: 4, id: "time"),
            japaneseComponent(text, role: "attributive", start: 2, end: 7, id: "modifier"),
            japaneseComponent(text, role: "object", start: 7, end: 9, id: "object"),
            japaneseComponent(text, role: "predicate", start: 9, end: 11, id: "predicate"), japaneseOmitted()]
        let review = try japaneseComponentReview(text, rows: rows)
        #expect(review.components.count == 6 && review.components[0].role == .topic)
        #expect(review.components.last?.role == .subject && review.components.last?.span == nil && review.components.last?.omitted == true)
        #expect(JapaneseSentenceRole.subject.labelZh != JapaneseSentenceRole.topic.labelZh)
        #expect([JapaneseSentenceRole.subject.colorLabelZh, JapaneseSentenceRole.predicate.colorLabelZh, JapaneseSentenceRole.object.colorLabelZh, JapaneseSentenceRole.attributive.colorLabelZh, JapaneseSentenceRole.adverbial.colorLabelZh] == ["蓝色", "红色", "绿色", "紫色", "橙色"])
        #expect(review.isPersistable)
    }
    @Test func nestedModifiersSelectOneLayerAndPreserveOriginalBytes() throws {
        let text = "私は昨日買った本を読む。"
        let review = try japaneseComponentReview(text, rows: [
            japaneseComponent(text, role: "attributive", start: 2, end: 7, id: "outer"),
            japaneseComponent(text, role: "adverbial", start: 2, end: 4, id: "inner"),
            japaneseComponent(text, role: "predicate", start: 9, end: 11, id: "verb")])
        #expect(JapaneseSentenceProjection.hasOverlaps(review.components))
        let first = JapaneseSentenceProjection.runs(source: text, components: review.components)
        #expect(first.contains { $0.componentID == "outer" } && !first.contains { $0.componentID == "inner" })
        let selected = JapaneseSentenceProjection.runs(source: text, components: review.components, selectedID: "inner")
        #expect(selected.contains { $0.componentID == "inner" } && !selected.contains { $0.componentID == "outer" })
        for runs in [first, selected] {
            #expect(runs.map(\.text).joined().utf8.elementsEqual(text.utf8))
            for (a, b) in zip(runs, runs.dropFirst()) { #expect(a.end == b.start) }
        }
    }
    @Test func duplicateSameRoleRangeIsDroppedButDifferentNestedRolesRemain() throws {
        let text = "猫は猫を見た。", first = japaneseComponent(text, role: "subject", start: 0, end: 1, id: "one")
        var duplicate = first; duplicate["id"] = "two"
        let other = japaneseComponent(text, role: "topic", start: 0, end: 1, id: "topic")
        let review = try japaneseComponentReview(text, rows: [first, duplicate, other])
        #expect(review.components.count == 2 && !review.warnings.isEmpty)
        #expect(Set(review.components.map(\.role)) == Set([.subject, .topic]))
    }
    @Test func repeatedWordsNeedContextAndWrongOffsetsNeverRepair() throws {
        let text = "猫は猫を見た。"
        let good = japaneseComponent(text, role: "object", start: 2, end: 3, id: "object")
        var absentContext = good; absentContext["prefix"] = ""; absentContext["suffix"] = ""
        var wrong = good; wrong["start"] = 1; wrong["end"] = 2
        let review = try japaneseComponentReview(text, rows: [good, absentContext.merging(["id": "missing"]) { _, new in new }, wrong.merging(["id": "wrong"]) { _, new in new }])
        #expect(review.components.count == 1 && review.components[0].span?.start == 2)
        #expect(review.warnings.count >= 2)
    }
    @Test func omittedElementsCannotClaimTextSpanOrCertainty() throws {
        let text = "本を読む。", valid = japaneseOmitted()
        var span = valid; span["quote"] = "本"; span["start"] = 0; span["end"] = 1
        var certainty = valid; certainty["certainty"] = "suggestion"
        var wrongBool = valid; wrongBool["omitted"] = 1
        for bad in [span, certainty, wrongBool] { #expect(try japaneseComponentReview(text, rows: [bad]).components.isEmpty) }
        let review = try japaneseComponentReview(text, rows: [valid])
        #expect(review.components.count == 1 && review.components[0].ambiguous)
        let runs = JapaneseSentenceProjection.runs(source: text, components: review.components, selectedID: "omitted")
        #expect(runs.allSatisfy { $0.componentID == nil } && runs.map(\.text).joined() == text)
    }
    @Test func combiningKanaIVSEmojiBoundariesArePreservedInColorProjection() throws {
        let text = "𠮷\u{E0100}か\u{3099}👩🏽‍🚀本を読む。", scalars = Array(text.unicodeScalars)
        var boundaries: [Int] = [0], cursor = 0
        for character in text { cursor += String(character).unicodeScalars.count; boundaries.append(cursor) }
        let valid = boundaries.dropLast().enumerated().map { index, start in
            japaneseComponent(text, role: "attributive", start: start, end: boundaries[index + 1], id: "c\(index)")
        }
        let review = try japaneseComponentReview(text, rows: valid)
        #expect(review.components.count == valid.count)
        #expect(JapaneseSentenceProjection.runs(source: text, components: review.components).map(\.text).joined().utf8.elementsEqual(text.utf8))
        let split = japaneseComponent(text, role: "subject", start: 0, end: 1, id: "split-ivs")
        #expect(try japaneseComponentReview(text, rows: [split]).components.isEmpty)
        let fake = JapaneseSentenceComponent(id: "split", role: .subject, span: JapaneseSpan(start: 2, end: 3, quote: String(scalars[2])), ambiguous: false, omitted: false, explanationZh: "bad")
        #expect(JapaneseSentenceProjection.runs(source: text, components: [fake]).allSatisfy { $0.role == nil })
    }
    @Test func invalidRoleBooleanOffsetsUnknownFieldsAndExcessItemsDegradeSafely() throws {
        let text = "本を読む。", good = japaneseComponent(text, role: "object", start: 0, end: 2, id: "c1")
        for change in [["role": "invented"], ["start": true], ["end": 1.5], ["omitted": "false"], ["extra": "unknown"], ["certainty": "certain"]] as [[String: Any]] {
            let row = good.merging(change) { _, new in new }
            #expect(try japaneseComponentReview(text, rows: [row]).components.isEmpty)
        }
        let request = JapaneseLearningRequest(source: japaneseSource(text), provider: japaneseConfig())
        var payload = japanesePayload(text); payload["components"] = Array(repeating: good, count: 17)
        #expect(JapaneseLearningValidator.validate(try japaneseData(payload), request: request).status == .unavailable)
    }
    @Test func componentsPersistWithExactSourceAndLegacyReviewRemainsReadable() async throws {
        let text = "私は本を読む。", review = try japaneseComponentReview(text, rows: JapaneseLearningMockComponents.rows(text))
        let note = try JapaneseLearningNote(review: review, userText: "Independent role review", corrections: [])
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Component-Store-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = JapaneseLearningRepository(root: root); try await repository.saveNote(note)
        let restored = try #require(await repository.load().notes.first)
        #expect(restored.review.components == review.components && restored.review.source.anchor.quote.utf8.elementsEqual(text.utf8))
        var raw = try JSONSerialization.jsonObject(with: JSONEncoder().encode(JapaneseLearningState(notes: [note]))) as! [String: Any]
        var notes = raw["notes"] as! [[String: Any]], old = notes[0]["review"] as! [String: Any]
        old.removeValue(forKey: "components"); old["promptVersion"] = JapaneseLearningPolicy.legacyPromptVersion
        notes[0]["review"] = old; raw["notes"] = notes
        let legacy = try JapaneseLearningRepository.decode(japaneseData(raw))
        #expect(legacy.notes[0].review.components.isEmpty && legacy.notes[0].userText == note.userText)
    }
    @Test func cancelledNoncooperativeComponentsNeverDisplayOrSave() async throws {
        let provider = JapaneseComponentDeferred(), model = JapaneseLearningModel(provider: provider, sourceIsCurrent: { _, _ in true })
        let text = "私は本を読む。"
        model.prepare(JapaneseLearningRequest(source: japaneseSource(text), provider: japaneseConfig()))
        model.start(confirmed: true)
        let deadline = Date().addingTimeInterval(3)
        while !(await provider.started()), Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        try #require(await provider.started())
        model.prepare(nil); try await provider.finish(text); try await Task.sleep(for: .milliseconds(20))
        #expect(model.review == nil && !model.canSave && !model.busy)
    }
}
