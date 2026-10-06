// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices
@testable import PDFnoUI

private actor UnavailableAXInputProvider: JapaneseLearningProvider {
    nonisolated let mode = AIProviderMode.mock
    private var submissions = 0
    func attemptsUsed() -> Int { submissions }
    func callCount() -> Int { submissions }
    func analyze(_ request: JapaneseLearningRequest) throws -> Data {
        submissions += 1
        return Data("invalid synthetic Japanese response".utf8)
    }
}

/// In-memory model/projection evidence only. No App, NSHostingView, window or AX session.
@MainActor
struct JapaneseUnavailableAXInputTests {
    @Test(arguments: ["window", "日本語 か\u{3099}👩🏽‍🚀"])
    func unavailableResponseStillPublishesExactSourceWithoutLinkedCandidates(_ quote: String) async throws {
        let provider = UnavailableAXInputProvider()
        var saves = 0
        let model = JapaneseLearningModel(provider: provider, sourceIsCurrent: { _, _ in true },
            saveReviewedNote: { _ in saves += 1 })
        let authorReadings = quote.hasPrefix("日本語")
            ? [JapaneseAuthorReading(span: JapaneseSpan(start: 0, end: 3, quote: "日本語"), reading: "にほんご")] : []
        let request = JapaneseLearningRequest(source: japaneseSource(quote), provider: japaneseConfig(), authorReadings: authorReadings)
        model.prepare(request)
        #expect(model.review == nil && model.canStart)
        model.start(confirmed: true)
        let deadline = Date().addingTimeInterval(3)
        while model.busy, Date() < deadline { try await Task.sleep(for: .milliseconds(5)) }
        #expect(!model.busy)
        let review = try #require(model.review)
        // Workspace's `if let review` branch remains active for this unavailable result.
        #expect(review.status == .unavailable)
        #expect(model.status.contains("输出无法验证") && model.status.contains("仅保留来源"))
        #expect(review.source.anchor.quote.utf8.elementsEqual(quote.utf8))
        #expect(review.components.isEmpty && review.translationZh == nil)
        #expect(review.authorReadings == authorReadings)
        let runs = JapaneseSentenceProjection.runs(source: review.source.anchor.quote, components: review.components)
        #expect(runs.count == 1)
        #expect(runs.allSatisfy { $0.componentID == nil && $0.role == nil })
        #expect(runs.map(\.text).joined().utf8.elementsEqual(quote.utf8))
        #expect(await provider.callCount() == 1)
        #expect(!model.canSave)
        #expect(await model.save() == false)
        #expect(saves == 0 && !model.saved)
    }
}
