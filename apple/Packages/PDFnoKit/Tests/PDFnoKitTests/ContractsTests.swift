// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain

struct ContractsTests {
    private var anchor: PDFSourceAnchor {
        PDFSourceAnchor(editionID: UUID(), fileSHA256: String(repeating: "a", count: 64), quote: "source",
                        regions: [PageRegion(pageIndex: 0, x: 1, y: 2, width: 3, height: 4, quote: "source")])
    }
    @Test func unicodeRoundTripRejectsSurrogateInteriorAndPreservesCombiningMarks() throws {
        let text = "本を😀読みます。e\u{301}"
        for offset in 0...text.unicodeScalars.count {
            let utf16 = try UnicodeOffsets.utf16Offset(in: text, codePointOffset: offset)
            #expect(try UnicodeOffsets.codePointOffset(in: text, utf16Offset: utf16) == offset)
        }
        #expect(throws: SourceValidationError.self) { try UnicodeOffsets.codePointOffset(in: text, utf16Offset: 3) }
        #expect(UnicodeOffsets.quotedSpan(in: text, quote: "😀", start: 2, end: 3))
        #expect(!UnicodeOffsets.quotedSpan(in: text, quote: "😀", start: 3, end: 4))
        #expect(UnicodeOffsets.quotedSpan(in: text, quote: "e\u{301}", start: 8, end: 10))
        #expect(!UnicodeOffsets.quotedSpan(in: text, quote: "é", start: 8, end: 10))
    }
    @Test func authorRubyStaysSeparateFromCanonicalSource() {
        let fragments: [CanonicalFragment] = [.authorRuby(base: "本", reading: "ほん"), .text("を😀読みます。"), .auxiliary("generated reading")]
        #expect(fragments.map(\.sourceText).joined() == "本を😀読みます。")
    }
    @Test func duplicateQuotesKeepDistinctOffsets() {
        let source = "同じ言葉。もう一度、同じ言葉。"
        #expect(UnicodeOffsets.quotedSpan(in: source, quote: "同じ言葉。", start: 0, end: 5))
        #expect(UnicodeOffsets.quotedSpan(in: source, quote: "同じ言葉。", start: 10, end: 15))
        #expect(!UnicodeOffsets.quotedSpan(in: source, quote: "同じ言葉。", start: 9, end: 14))
    }
    @Test func cancellationFreezesSourceAndIgnoresLateOrForeignEvents() {
        let original = anchor
        var state = LearningTaskState(source: original)
        state.apply(.stream("wrong"), taskID: UUID())
        #expect(state.output.isEmpty)
        state.apply(.stream("first"), taskID: state.id)
        state.apply(.cancel, taskID: state.id)
        state.apply(.stream("late"), taskID: state.id)
        state.apply(.complete, taskID: state.id)
        #expect(state.status == .cancelled)
        #expect(state.output == "first")
        #expect(state.source == original)
    }
    @Test func allTerminalTaskStatesRejectFurtherOutput() {
        for event in [LearningEvent.complete, .partial("limit"), .failure("rate-limit"), .cancel] {
            var task = LearningTaskState(source: anchor)
            task.apply(.stream("saved"), taskID: task.id)
            task.apply(event, taskID: task.id)
            #expect(task.status.isTerminal)
            task.apply(.stream("unexpected"), taskID: task.id)
            #expect(task.output == "saved")
        }
    }
    @Test func providerContractRejectsUnsafeOrCredentialBearingEndpoints() {
        #expect(ProviderValidation.validate(endpoint: "https://api.example.com/v1", model: "model"))
        #expect(ProviderValidation.validate(endpoint: "http://127.0.0.1:8080/v1", model: "local"))
        for endpoint in ["http://example.com/v1", "https://user:secret@example.com", "https://example.com?key=secret", "file:///tmp/key", "https://example.com#secret"] {
            #expect(!ProviderValidation.validate(endpoint: endpoint, model: "model"))
        }
        #expect(!ProviderValidation.validate(endpoint: "https://example.com", model: " "))
        #if os(macOS)
        #expect(FeatureAvailability.epub.available)
        #else
        #expect(!FeatureAvailability.epub.available)
        #endif
        #if os(macOS)
        #expect(FeatureAvailability.ai.available)
        #else
        #expect(!FeatureAvailability.ai.available)
        #endif
        #expect(!FeatureAvailability.cloud.available)
        #expect(!FeatureAvailability.bookno.available)
    }
}
