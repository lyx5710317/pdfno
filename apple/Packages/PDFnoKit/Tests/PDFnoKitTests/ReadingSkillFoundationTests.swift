// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// All text, credentials and transports below are original synthetic fixtures; no network path.
import Foundation
import Testing
import PDFnoDomain
@testable import PDFnoServices

private func skillSource(_ text: String = "Maya reads a book.", session: UUID = UUID(), version: Int = 0,
                         book: UUID = UUID(), edition: UUID = UUID()) -> AISourceSnapshot {
    let anchor = PDFSourceAnchor(editionID: edition, fileSHA256: String(repeating: "a", count: 64), quote: text,
        regions: [PageRegion(pageIndex: 0, x: 1, y: 2, width: 3, height: 4, quote: text)])
    return AISourceSnapshot(bookID: book, readerSessionID: session, documentVersion: version, anchor: .pdf(anchor))
}
private func skillMock() -> AIProviderConfig {
    var value = AIProviderConfig(); value.mode = .mock; value.label = "original synthetic fixture"; return value
}
private func skillConsent(_ plan: ReadingSkillInputPlan) -> ReadingSkillConsent {
    .init(taskID: plan.taskID, planFingerprint: plan.confirmationFingerprint)
}
private func skillHostConsent(_ request: AIRequest) throws -> AIConsent {
    .init(requestID: request.id, scopeFingerprint: try AIJobCoordinator.fingerprint(request))
}
private func skillHostConsent(_ request: JapaneseLearningRequest) throws -> AIConsent {
    .init(requestID: request.id, scopeFingerprint: try JapaneseLearningCoordinator.fingerprint(request))
}
private func skillHostConsent(_ request: EnglishLearningRequest) throws -> AIConsent {
    .init(requestID: request.id, scopeFingerprint: try EnglishLearningCoordinator.fingerprint(request))
}
private actor SkillTextProvider: AIProvider {
    private(set) var count = 0
    let quote: String?
    init(quote: String? = nil) { self.quote = quote }
    func analyze(_ request: AIRequest) -> AIProviderOutput {
        count += 1; return .init(sourceQuote: quote ?? request.source.anchor.quote, text: "original synthetic result")
    }
}
private actor SkillCredentials: AICredentialStore {
    private(set) var reads = 0
    func read(_ reference: UUID) -> String? { reads += 1; return "original-synthetic-credential-only" }
    func put(_ value: String, reference: UUID) {}
    func remove(_ reference: UUID) {}
}
private actor SkillFailureTransport: AIHTTPTransport {
    private(set) var count = 0
    func send(_ request: URLRequest) -> AIHTTPResponse {
        count += 1; return .init(status: 429, body: Data("original synthetic failure".utf8))
    }
}
private actor SkillDeferredProvider: AIProvider {
    private var continuation: CheckedContinuation<AIProviderOutput, Error>?
    func analyze(_ request: AIRequest) async throws -> AIProviderOutput {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func started() -> Bool { continuation != nil }
    func finish(_ quote: String) { continuation?.resume(returning: .init(sourceQuote: quote, text: "original late response")); continuation = nil }
}
private actor SkillCurrentFence {
    var current = true
    func check() -> Bool { current }
    func expire() { current = false }
}
private struct SkillMalformedEnglishProvider: EnglishLearningProvider {
    let mode = AIProviderMode.mock
    func analyze(_ request: EnglishLearningRequest) -> Data { Data("{\"schemaVersion\":true,\"tool\":\"execute\"}".utf8) }
}
private func awaitSkillProvider(_ provider: SkillDeferredProvider) async throws {
    for _ in 0..<200 { if await provider.started() { return }; try await Task.sleep(for: .milliseconds(5)) }
    throw ReadingSkillFailure.result
}
private func skillManifestCopy(_ original: ReadingSkillManifest, skillID: String? = nil, skillVersion: String? = nil,
                               manifestSchemaVersion: Int? = nil, runtimeVersion: String? = nil, scope: ReadingSkillScope? = nil,
                               maxInputUTF16: Int? = nil, tools: [String]? = nil, extraContext: [String]? = nil,
                               automaticSave: Bool? = nil, result: ReadingSkillResultContract? = nil) -> ReadingSkillManifest {
    .init(skillID: skillID ?? original.skillID, skillVersion: skillVersion ?? original.skillVersion,
        manifestSchemaVersion: manifestSchemaVersion ?? original.manifestSchemaVersion, runtimeVersion: runtimeVersion ?? original.runtimeVersion,
        title: original.title, scope: scope ?? original.scope, formats: original.formats, sourceLanguages: original.sourceLanguages,
        maxInputUTF16: maxInputUTF16 ?? original.maxInputUTF16, maxSegments: original.maxSegments, parameters: original.parameters,
        result: result ?? original.result, routing: original.routing, budget: original.budget,
        tools: tools ?? original.tools, extraContext: extraContext ?? original.extraContext, automaticSave: automaticSave ?? original.automaticSave)
}
struct ReadingSkillFoundationTests {
    @Test func compiledCatalogKeepsSixHonestScopesAndAllHostLimits() throws {
        let registry = ReadingSkillRegistry.builtin
        #expect(registry.entries.count == 6 && registry.entries.allSatisfy(\.isEnabled))
        for id in ReadingSkillID.allCases {
            let manifest = try registry.manifest(for: id)
            #expect(manifest.skillVersion == "1.0.0" && manifest.runtimeVersion == "1.0.0" && manifest.manifestSchemaVersion == 1)
            #expect(manifest.tools.isEmpty && manifest.extraContext.isEmpty && !manifest.automaticSave)
            #expect(manifest.budget.maxOutputTokensPerRequest == 1024 && manifest.budget.maxTimeoutSecondsPerRequest == 30)
            #expect(manifest.budget.maxResponseBytesPerRequest == 65536 && manifest.budget.automaticRetries == 0)
            #expect(manifest.maxInputUTF16 == (manifest.scope == .selection ? 500 : 3000))
            #expect(manifest.maxSegments == (manifest.scope == .selection ? 1 : 6))
            #expect(manifest.budget.maxSessionAttempts == (manifest.scope == .selection ? 3 : 6))
        }
        #expect(try registry.manifest(for: .translatePDFPage).routing == .existingBatchHostOnly)
        #expect(try registry.manifest(for: .translateEPUBSpine).scope == .epubCurrentSpine)
        #expect(try registry.manifest(for: .japaneseSelection).result.promptVersions == [JapaneseLearningPolicy.promptVersion])
        #expect(try registry.manifest(for: .englishSelection).result.promptVersions == [EnglishLearningPolicy.promptVersion])
    }
    @Test func futureUnknownMissingValidatorAndChangedContractsStayDisabledAndRetained() throws {
        let original = try ReadingSkillRegistry.builtin.manifest(for: .translateSelection)
        let candidates: [(ReadingSkillManifest, ReadingSkillDisabledReason)] = [
            (skillManifestCopy(original, manifestSchemaVersion: 2), .manifestSchema),
            (skillManifestCopy(original, runtimeVersion: "2.0.0"), .runtimeVersion),
            (skillManifestCopy(original, skillVersion: "9.0.0"), .skillVersion),
            (skillManifestCopy(original, skillID: "personal.unknown"), .unknownSkill),
            (skillManifestCopy(original, scope: .singleBookRetrieval), .unsupportedContract),
            (skillManifestCopy(original, maxInputUTF16: 8000), .unsupportedContract),
            (skillManifestCopy(original, tools: ["shell"]), .unsupportedContract),
            (skillManifestCopy(original, automaticSave: true), .unsupportedContract),
            (skillManifestCopy(original, extraContext: ["wholeLibrary"]), .unsupportedContract)
        ]
        for (candidate, reason) in candidates {
            let registry = ReadingSkillRegistry(manifests: [candidate])
            #expect(registry.entries.first?.disabledReason == reason)
            #expect(ReadingSkillIdentity.matches(try #require(registry.entries.first).manifest, candidate))
            #expect(throws: ReadingSkillFailure.self) { try registry.manifest(for: .translateSelection) }
        }
        let missing = skillManifestCopy(original, result: .init(kind: original.result.kind,
            validatorID: "missing-validator", promptVersions: original.result.promptVersions))
        #expect(ReadingSkillRegistry(manifests: [missing]).entries.first?.disabledReason == .missingValidator)
        let duplicates = ReadingSkillRegistry(manifests: [original, original])
        #expect(duplicates.entries.count == 2 && duplicates.entries.allSatisfy { $0.disabledReason == .duplicateIdentity })
        #expect(throws: ReadingSkillFailure.disabled) { try duplicates.manifest(for: .translateSelection) }
    }
    @Test func capabilityCatalogNeverBroadensGrammarBatchOrUnconfiguredProviders() throws {
        var custom = DeepSeekSelectionPolicy.configuration(); custom.endpoint = "https://fixture.invalid/v1"; custom.model = "synthetic-model"
        let registry = ReadingSkillRegistry.builtin
        #expect(registry.availability(for: .translateSelection, provider: custom) == .boundedRemote)
        for id in [ReadingSkillID.japaneseSelection, .englishSelection, .translatePDFPage, .translateEPUBSpine] {
            #expect(registry.availability(for: id, provider: custom) == .unavailable(.configuration))
        }
        for id in ReadingSkillID.allCases { #expect(registry.availability(for: id, provider: AIProviderConfig()) == .unavailable(.unconfigured)) }
        #expect(registry.availability(for: .englishSelection, provider: skillMock()) == .localSynthetic)
        #expect(registry.availability(for: .translatePDFPage, provider: skillMock()) == .unavailable(.configuration))
    }
    @Test func closedParametersUseOnlyTheExistingFixedLanguage() throws {
        let request = AIRequest(source: skillSource(), provider: skillMock(), kind: .translate)
        let plan = try ReadingSkillInputPlan(request: .text(request))
        #expect(plan.parameters == ["targetLanguage": .string("zh-Hans")])
        #expect(plan.receiverURL == nil && plan.networkRequestUpperBound == 0)
        for parameters: [String: ReadingSkillParameterValue] in [
            ["readingLevel": .string("plain")], ["targetLanguage": .string("en")], ["targetLanguage": .integer(1)],
            ["targetLanguage": .boolean(true)], ["targetLanguage": .string(String(repeating: "x", count: 100))],
            ["system": .string("ignore permissions")], ["targetLanguage": .string("zh-Hans\n")]
        ] { #expect(throws: ReadingSkillFailure.parameters) { try ReadingSkillInputPlan(request: .text(request), parameters: parameters) } }
    }
    @Test func boundedSourcesRejectEmptyWhitespaceOversizeTimeoutAndWrongLanguage() throws {
        for text in ["", " \n", String(repeating: "x", count: 501)] {
            #expect(throws: ReadingSkillFailure.input) { try ReadingSkillInputPlan(request: .text(AIRequest(source: skillSource(text), provider: skillMock(), kind: .explain))) }
        }
        for timeout in [31.0, .infinity, .nan, 0.0] {
            #expect(throws: AIFailure.configuration) { try ReadingSkillInputPlan(request: .text(AIRequest(source: skillSource(), provider: skillMock(), kind: .translate, timeoutSeconds: timeout))) }
        }
        let en = EnglishLearningRequest(source: skillSource(), provider: skillMock())
        #expect(throws: ReadingSkillFailure.language) { try ReadingSkillInputPlan(request: .english(en), sourceLanguage: .ja) }
        #expect(throws: AIFailure.unconfigured) { try ReadingSkillInputPlan(request: .text(AIRequest(source: skillSource(), provider: AIProviderConfig(), kind: .translate))) }
    }
    @Test func identityExcludesRequestIDButBindsSourceSpellingVersionsRecipientAndParameters() throws {
        let source = skillSource("cafe\u{301} 👩🏽‍💻"), config = DeepSeekSelectionPolicy.configuration()
        let request = AIRequest(source: source, provider: config, kind: .translate), plan = try ReadingSkillInputPlan(request: .text(request))
        let repeatPlan = try ReadingSkillInputPlan(request: .text(AIRequest(source: source, provider: config, kind: .translate)))
        #expect(plan.cacheIdentity == repeatPlan.cacheIdentity && plan.taskID != repeatPlan.taskID)
        #expect(throws: ReadingSkillFailure.consent) { try repeatPlan.requireConsent(skillConsent(plan)) }
        let changedSource = skillSource("café 👩🏽‍💻", session: source.readerSessionID, version: source.documentVersion, book: source.bookID, edition: source.anchor.editionID)
        #expect(plan.cacheIdentity != (try ReadingSkillInputPlan(request: .text(AIRequest(source: changedSource, provider: config, kind: .translate)))).cacheIdentity)
        var changed = config; changed.generation += 1
        #expect(plan.cacheIdentity != (try ReadingSkillInputPlan(request: .text(AIRequest(source: source, provider: changed, kind: .translate)))).cacheIdentity)
        changed = config; changed.endpoint = "https://fixture.invalid"; changed.model = "synthetic-model"
        #expect(plan.cacheIdentity != (try ReadingSkillInputPlan(request: .text(AIRequest(source: source, provider: changed, kind: .translate)))).cacheIdentity)
        #expect(plan.cacheIdentity != (try ReadingSkillInputPlan(request: .text(AIRequest(source: source, provider: config, kind: .explain)))).cacheIdentity)
        let newer = AISourceSnapshot(bookID: source.bookID, readerSessionID: source.readerSessionID, documentVersion: 1, anchor: source.anchor)
        #expect(plan.cacheIdentity != (try ReadingSkillInputPlan(request: .text(AIRequest(source: newer, provider: config, kind: .translate)))).cacheIdentity)
        #expect(plan.cacheIdentity != (try ReadingSkillInputPlan(request: .text(request), sourceLanguage: .en)).cacheIdentity)
        #expect(plan.cacheIdentity != (try ReadingSkillInputPlan(request: .text(AIRequest(id: request.id, source: source, provider: config, kind: .translate, timeoutSeconds: 10)))).cacheIdentity)
        #expect(plan.receiverURL?.absoluteString == "https://api.deepseek.com/chat/completions")
        #expect(plan.sourceReference(id: "source-1")?.bodySHA256 == EnglishLearningPolicy.textHash(source.anchor.quote))
        #expect(plan.sourceReference(id: "invented-page") == nil)
    }
    @Test func fullPhysicalPageAndSpineReuseNativeSegmentationAndNeverBecomeSelectionRequests() throws {
        let text = String(repeating: "Aか\u{3099}👩🏽‍💻 ", count: 65), book = UUID(), session = UUID(), edition = UUID(), hash = String(repeating: "a", count: 64)
        let nativePage = try PDFPageTranslationPlan(snapshot: .init(bookID: book, readerSessionID: session, editionID: edition, fileSHA256: hash, pageIndex: 4, text: text))
        let page = try ReadingSkillInputPlan(request: .pdfPage(nativePage, provider: DeepSeekSelectionPolicy.configuration()))
        #expect(page.manifest.scope == .pdfPhysicalPage && page.manifest.budget.pool == .pdfPage)
        #expect(page.sources.map { $0.source.anchor.quote }.joined().utf8.elementsEqual(text.utf8))
        #expect(page.maxOutputTokens == nativePage.maxOutputTokens && page.inputUTF16 == text.utf16.count)
        #expect(throws: ReadingSkillFailure.scope) { try ReadingSkillInputPlan(request: .text(AIRequest(source: nativePage.sources[0], provider: DeepSeekSelectionPolicy.configuration(), kind: .translate))) }
        let nativeSpine = try EPUBChapterTranslationPlan(snapshot: .init(bookID: book, readerSessionID: session, documentVersion: 2,
            editionID: edition, fileSHA256: hash, resourceHref: "OEBPS/original.xhtml", spineIndex: 1, chapterCount: 3,
            utf16Count: text.utf16.count, text: text, vertical: true))
        let spine = try ReadingSkillInputPlan(request: .epubSpine(nativeSpine, provider: DeepSeekSelectionPolicy.configuration()))
        #expect(spine.manifest.scope == .epubCurrentSpine && spine.manifest.budget.pool == .epubSpine)
        #expect(spine.sources.map { $0.source.anchor.quote }.joined().unicodeScalars.elementsEqual(text.unicodeScalars))
        #expect(spine.maxRequestDurationSeconds == Double(nativeSpine.maxDurationSeconds))
        #expect(throws: ReadingSkillFailure.capability) { try ReadingSkillInputPlan(request: .pdfPage(nativePage, provider: skillMock())) }
        #expect(throws: PDFPageTranslationFailure.self) { try PDFPageTranslationPlan(snapshot: .init(bookID: book, readerSessionID: session, editionID: edition, fileSHA256: hash, pageIndex: 0, text: "")) }
        #expect(throws: PDFPageTranslationFailure.self) { try PDFPageTranslationPlan(snapshot: .init(bookID: book, readerSessionID: session, editionID: edition, fileSHA256: hash, pageIndex: 0, text: String(repeating: "x", count: 3001))) }
    }
    @Test func batchDescriptionsCannotExecuteThroughASelectionAdapter() async throws {
        let native = try PDFPageTranslationPlan(snapshot: .init(bookID: UUID(), readerSessionID: UUID(), editionID: UUID(),
            fileSHA256: String(repeating: "a", count: 64), pageIndex: 0, text: "Original bounded page."))
        let config = DeepSeekSelectionPolicy.configuration(), provider = SkillTextProvider()
        let plan = try ReadingSkillInputPlan(request: .pdfPage(native, provider: config))
        await #expect(throws: ReadingSkillFailure.scope) {
            try await ReadingSkillSelectionAdapter.runText(plan, consent: skillConsent(plan), hostConsent: .init(requestID: UUID(), scopeFingerprint: "not-authority"),
                coordinator: AIJobCoordinator(), provider: provider, sourceAndConfigurationAreCurrent: { _, _ in true })
        }
        #expect(await provider.count == 0)
    }
    @Test func japaneseAuthorRubyIsBoundLocallyAndCannotChangeAnApprovedPlan() throws {
        let source = skillSource("山へ行く。"), config = skillMock()
        let reading = JapaneseAuthorReading(span: .init(start: 0, end: 1, quote: "山"), reading: "やま")
        let original = JapaneseLearningRequest(source: source, provider: config, authorReadings: [reading])
        let plan = try ReadingSkillInputPlan(request: .japanese(original))
        let other = JapaneseLearningRequest(id: original.id, source: source, provider: config)
        #expect(plan.sourceLanguage == .ja && plan.promptVersion == JapaneseLearningPolicy.promptVersion)
        #expect(plan.cacheIdentity != (try ReadingSkillInputPlan(request: .japanese(other))).cacheIdentity)
        #expect(throws: AIFailure.output) { try ReadingSkillInputPlan(request: .japanese(JapaneseLearningRequest(source: source, provider: config,
            authorReadings: [.init(span: .init(start: 0, end: 1, quote: "川"), reading: "かわ")]))) }
    }
    @Test func plansHaveNoCredentialReadsRequestsOrBudgetReservations() async throws {
        let session = AppAISession(), credentials = SkillCredentials(), transport = SkillFailureTransport()
        // Construction of an existing provider is also inert; this is never analyzed here.
        _ = DeepSeekEnglishLearningProvider(transport: transport, credentials: credentials, credentialReference: UUID(), aiSession: session)
        for _ in 0..<5 { _ = try ReadingSkillInputPlan(request: .english(EnglishLearningRequest(source: skillSource(), provider: DeepSeekSelectionPolicy.configuration()))) }
        #expect(await credentials.reads == 0)
        #expect(await transport.count == 0)
        #expect(await session.selection.attemptsUsed() == 0)
        #expect(await session.page.attemptsUsed() == 0)
        #expect(await session.chapter.attemptsUsed() == 0)
    }
    @Test func bothConfirmationsAndCurrentSourceAreRequiredBeforeProviderWork() async throws {
        let request = AIRequest(source: skillSource(), provider: skillMock(), kind: .translate), provider = SkillTextProvider()
        let plan = try ReadingSkillInputPlan(request: .text(request)), runner = AIJobCoordinator()
        await #expect(throws: ReadingSkillFailure.consent) {
            try await ReadingSkillSelectionAdapter.runText(plan, consent: .init(taskID: plan.taskID, planFingerprint: "wrong"), hostConsent: skillHostConsent(request),
                coordinator: runner, provider: provider, sourceAndConfigurationAreCurrent: { _, _ in true })
        }
        await #expect(throws: AIFailure.consent) {
            try await ReadingSkillSelectionAdapter.runText(plan, consent: skillConsent(plan), hostConsent: .init(requestID: request.id, scopeFingerprint: "wrong"),
                coordinator: runner, provider: provider, sourceAndConfigurationAreCurrent: { _, _ in true })
        }
        await #expect(throws: ReadingSkillFailure.staleSource) {
            try await ReadingSkillSelectionAdapter.runText(plan, consent: skillConsent(plan), hostConsent: skillHostConsent(request),
                coordinator: runner, provider: provider, sourceAndConfigurationAreCurrent: { _, _ in false })
        }
        #expect(await provider.count == 0)
    }
    @Test func textRouteRetainsHostCacheAndStillRequiresFreshConsent() async throws {
        let source = skillSource(), config = skillMock(), provider = SkillTextProvider(), coordinator = AIJobCoordinator()
        var first: ReadingSkillResultEnvelope?
        for index in 0..<2 {
            let request = AIRequest(source: source, provider: config, kind: .translate), plan = try ReadingSkillInputPlan(request: .text(request))
            let envelope = try await ReadingSkillSelectionAdapter.runText(plan, consent: skillConsent(plan), hostConsent: skillHostConsent(request),
                coordinator: coordinator, provider: provider, sourceAndConfigurationAreCurrent: { _, _ in true })
            #expect(envelope.fromCache == (index == 1))
            #expect(envelope.usage == (index == 1 ? .cacheWithoutNetwork : .localSynthetic))
            #expect(envelope.sources.first?.source.bookID == source.bookID && envelope.validation == .sourceAndStructure)
            if let first { #expect(first.taskID != envelope.taskID && first.inputAndParametersSHA256 == envelope.inputAndParametersSHA256) } else { first = envelope }
        }
        #expect(await provider.count == 1)
    }
    @Test func wrongQuoteOrNormalizedSourceCannotAcquireResultProvenance() async throws {
        let source = skillSource("cafe\u{301}"), config = skillMock(), request = AIRequest(source: source, provider: config, kind: .explain)
        let plan = try ReadingSkillInputPlan(request: .text(request))
        await #expect(throws: AIFailure.output) {
            try await ReadingSkillSelectionAdapter.runText(plan, consent: skillConsent(plan), hostConsent: skillHostConsent(request),
                coordinator: AIJobCoordinator(), provider: SkillTextProvider(quote: "café"), sourceAndConfigurationAreCurrent: { _, _ in true })
        }
        let normalized = skillSource("café", session: source.readerSessionID, version: 0, book: source.bookID, edition: source.anchor.editionID)
        let forged = AIResult(request: AIRequest(id: request.id, source: normalized, provider: config, kind: .explain), text: "synthetic", fromCache: false)
        #expect(throws: ReadingSkillFailure.result) { try ReadingSkillResultEnvelope(plan: plan, payload: .text(forged)) }
    }
    @Test func japaneseAndEnglishRoutesKeepTheirOwnValidatorsAndCandidateStatus() async throws {
        let japanese = JapaneseLearningRequest(source: skillSource("山へ行く。"), provider: skillMock(),
            authorReadings: [.init(span: .init(start: 0, end: 1, quote: "山"), reading: "やま")])
        let jpPlan = try ReadingSkillInputPlan(request: .japanese(japanese))
        let jp = try await ReadingSkillSelectionAdapter.runJapanese(jpPlan, consent: skillConsent(jpPlan), hostConsent: skillHostConsent(japanese),
            coordinator: JapaneseLearningCoordinator(), provider: LocalMockJapaneseLearningProvider(), sourceAndConfigurationAreCurrent: { _, _ in true })
        #expect(jp.validation == .candidatesNeedReview && jp.usage == .localSynthetic)
        if case .japanese(let review) = jp.payload { #expect(review.authorReadings.count == 1 && review.isPersistable) } else { Issue.record("Wrong typed payload") }
        let english = EnglishLearningRequest(source: skillSource(), provider: skillMock()), enPlan = try ReadingSkillInputPlan(request: .english(english))
        let en = try await ReadingSkillSelectionAdapter.runEnglish(enPlan, consent: skillConsent(enPlan), hostConsent: skillHostConsent(english),
            coordinator: EnglishLearningCoordinator(), provider: LocalMockEnglishLearningProvider(), sourceAndConfigurationAreCurrent: { _, _ in true })
        #expect(en.validation == .candidatesNeedReview)
        if case .english(let review) = en.payload { #expect(review.isPersistable && review.components.count == 3) } else { Issue.record("Wrong typed payload") }
        #expect(throws: ReadingSkillFailure.result) { try ReadingSkillResultEnvelope(plan: jpPlan, payload: en.payload) }
        await #expect(throws: ReadingSkillFailure.result) {
            try await ReadingSkillSelectionAdapter.runEnglish(enPlan, consent: skillConsent(enPlan), hostConsent: skillHostConsent(english),
                coordinator: EnglishLearningCoordinator(), provider: SkillMalformedEnglishProvider(), sourceAndConfigurationAreCurrent: { _, _ in true })
        }
    }
    @Test func existingSelectionJapaneseEnglishShareThreeAttemptsAndNeverRetry() async throws {
        let session = AppAISession(), credentials = SkillCredentials(), transport = SkillFailureTransport(), reference = UUID()
        let config = DeepSeekSelectionPolicy.configuration(), source = skillSource()
        let text = AIRequest(source: source, provider: config, kind: .translate), textPlan = try ReadingSkillInputPlan(request: .text(text))
        let textProvider = DeepSeekSelectionProvider(transport: transport, credentials: credentials, credentialReference: reference, budget: session.selection)
        await #expect(throws: AIFailure.rateLimit) {
            try await ReadingSkillSelectionAdapter.runText(textPlan, consent: skillConsent(textPlan), hostConsent: skillHostConsent(text),
                coordinator: AIJobCoordinator(), provider: textProvider, sourceAndConfigurationAreCurrent: { _, _ in true })
        }
        let japanese = JapaneseLearningRequest(source: skillSource("山へ行く。"), provider: config), jpPlan = try ReadingSkillInputPlan(request: .japanese(japanese))
        await #expect(throws: AIFailure.rateLimit) {
            try await ReadingSkillSelectionAdapter.runJapanese(jpPlan, consent: skillConsent(jpPlan), hostConsent: skillHostConsent(japanese), coordinator: JapaneseLearningCoordinator(),
                provider: DeepSeekJapaneseLearningProvider(transport: transport, credentials: credentials, credentialReference: reference, aiSession: session), sourceAndConfigurationAreCurrent: { _, _ in true })
        }
        let english = EnglishLearningRequest(source: source, provider: config), enPlan = try ReadingSkillInputPlan(request: .english(english))
        await #expect(throws: AIFailure.rateLimit) {
            try await ReadingSkillSelectionAdapter.runEnglish(enPlan, consent: skillConsent(enPlan), hostConsent: skillHostConsent(english), coordinator: EnglishLearningCoordinator(),
                provider: DeepSeekEnglishLearningProvider(transport: transport, credentials: credentials, credentialReference: reference, aiSession: session), sourceAndConfigurationAreCurrent: { _, _ in true })
        }
        // A new adapter/registry/coordinator provides no new quota; the fourth send is refused.
        await #expect(throws: AIFailure.attemptLimit) {
            try await ReadingSkillSelectionAdapter.runText(textPlan, consent: skillConsent(textPlan), hostConsent: skillHostConsent(text),
                coordinator: AIJobCoordinator(), provider: textProvider, sourceAndConfigurationAreCurrent: { _, _ in true })
        }
        #expect(await transport.count == 3)
        #expect(await session.selection.attemptsUsed() == 3)
        #expect(await session.page.attemptsUsed() == 0)
        #expect(await session.chapter.attemptsUsed() == 0)
        #expect(await session.probe.attemptsUsed() == 0)
    }
    @Test(arguments: [false, true]) func cancellationAndTimeoutFenceUncooperativeLateResponses(timedOut: Bool) async throws {
        let source = skillSource(), config = skillMock(), deferred = SkillDeferredProvider(), coordinator = AIJobCoordinator()
        let request = AIRequest(source: source, provider: config, kind: .translate, timeoutSeconds: timedOut ? 0.1 : 30)
        let plan = try ReadingSkillInputPlan(request: .text(request)), permission = skillConsent(plan), hostPermission = try skillHostConsent(request)
        let task = Task { try await ReadingSkillSelectionAdapter.runText(plan, consent: permission, hostConsent: hostPermission,
            coordinator: coordinator, provider: deferred, sourceAndConfigurationAreCurrent: { _, _ in true }) }
        try await awaitSkillProvider(deferred)
        if !timedOut { task.cancel() }
        do { _ = try await task.value; Issue.record("Expired request acquired provenance") }
        catch { #expect(error as? AIFailure == (timedOut ? .timeout : .cancelled)) }
        await deferred.finish(source.anchor.quote)
        let fresh = AIRequest(source: source, provider: config, kind: .translate), freshPlan = try ReadingSkillInputPlan(request: .text(fresh))
        let result = try await ReadingSkillSelectionAdapter.runText(freshPlan, consent: skillConsent(freshPlan), hostConsent: skillHostConsent(fresh),
            coordinator: coordinator, provider: SkillTextProvider(), sourceAndConfigurationAreCurrent: { _, _ in true })
        #expect(!result.fromCache)
    }
    @Test func sourceOrCredentialGenerationChangingDuringWorkRejectsEnvelope() async throws {
        let fence = SkillCurrentFence(), deferred = SkillDeferredProvider(), request = AIRequest(source: skillSource(), provider: skillMock(), kind: .translate)
        let plan = try ReadingSkillInputPlan(request: .text(request)), permission = skillConsent(plan), hostPermission = try skillHostConsent(request)
        let task = Task { try await ReadingSkillSelectionAdapter.runText(plan, consent: permission, hostConsent: hostPermission,
            coordinator: AIJobCoordinator(), provider: deferred, sourceAndConfigurationAreCurrent: { _, _ in await fence.check() }) }
        try await awaitSkillProvider(deferred); await fence.expire(); await deferred.finish(request.source.anchor.quote)
        do { _ = try await task.value; Issue.record("Stale response acquired provenance") }
        catch { #expect(error as? ReadingSkillFailure == .staleSource) }
    }
}
