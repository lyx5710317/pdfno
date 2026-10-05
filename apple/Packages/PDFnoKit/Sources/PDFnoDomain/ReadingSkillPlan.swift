// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CryptoKit

/// Existing typed requests are the only execution inputs. Batch plans remain with their original host.
public enum ReadingSkillRequest: Sendable {
    case text(AIRequest)
    case japanese(JapaneseLearningRequest)
    case english(EnglishLearningRequest)
    case pdfPage(PDFPageTranslationPlan, provider: AIProviderConfig)
    case epubSpine(EPUBChapterTranslationPlan, provider: AIProviderConfig)
}
public struct ReadingSkillSourceReference: Sendable, Equatable {
    public let id: String
    public let source: AISourceSnapshot
    public let bodySHA256: String
    public let snapshotSHA256: String
    init(id: String, source: AISourceSnapshot) throws {
        self.id = id; self.source = source
        bodySHA256 = ReadingSkillIdentity.digest(Data(source.anchor.quote.utf8))
        snapshotSHA256 = ReadingSkillIdentity.digest(try ReadingSkillIdentity.data(source))
    }
}
public struct ReadingSkillConsent: Sendable {
    public let taskID: UUID
    public let planFingerprint: String
    public init(taskID: UUID, planFingerprint: String) { self.taskID = taskID; self.planFingerprint = planFingerprint }
}
/// Offline, immutable preview. Construction performs no credential read, request, reservation or save.
/// It does not issue consent. The host records consent only after its existing explicit confirmation.
public struct ReadingSkillInputPlan: Sendable {
    public let taskID: UUID
    public let request: ReadingSkillRequest
    public let manifest: ReadingSkillManifest
    public let provider: AIProviderConfig
    public let receiverURL: URL?
    public let sourceLanguage: ReadingSkillLanguage
    public let parameters: [String: ReadingSkillParameterValue]
    public let sources: [ReadingSkillSourceReference]
    public let promptVersion: String
    public let timeoutSecondsPerRequest: Double
    public let inputUTF16: Int
    public let cacheIdentity: String
    public var confirmationFingerprint: String { cacheIdentity }
    public var networkRequestUpperBound: Int { provider.mode == .mock ? 0 : sources.count }
    public var maxOutputTokens: Int { sources.count * manifest.budget.maxOutputTokensPerRequest }
    public var maxRequestDurationSeconds: Double { Double(sources.count) * timeoutSecondsPerRequest }
    public init(request: ReadingSkillRequest, sourceLanguage: ReadingSkillLanguage = .unspecified,
                parameters: [String: ReadingSkillParameterValue] = [:], registry: ReadingSkillRegistry = .builtin,
                batchTaskID: UUID = UUID()) throws {
        let id: ReadingSkillID, taskID: UUID, provider: AIProviderConfig, promptVersion: String
        let snapshots: [AISourceSnapshot], timeout: Double, readings: [JapaneseAuthorReading]
        let language: ReadingSkillLanguage
        // Extra batch metadata is bound even when it is not sent to the provider.
        var batchMetadata: Data?
        switch request {
        case .text(let value):
            switch value.source.anchor { case .pdf, .epub: break; case .pdfPage, .epubChapter: throw ReadingSkillFailure.scope }
            id = value.kind == .translate ? .translateSelection : .explainSelection
            taskID = value.id; provider = value.provider; promptVersion = value.promptVersion
            snapshots = [value.source]; timeout = value.timeoutSeconds; readings = []; language = sourceLanguage
            if provider.mode == .openAICompatible { try BYOKSelectionPolicy.validate(value) }
        case .japanese(let value):
            try value.validate(); id = .japaneseSelection; taskID = value.id; provider = value.provider
            promptVersion = JapaneseLearningPolicy.promptVersion; snapshots = [value.source]; timeout = value.timeoutSeconds
            readings = value.authorReadings; language = .ja
            guard sourceLanguage == .unspecified || sourceLanguage == .ja else { throw ReadingSkillFailure.language }
        case .english(let value):
            try value.validate(); id = .englishSelection; taskID = value.id; provider = value.provider
            promptVersion = EnglishLearningPolicy.promptVersion; snapshots = [value.source]; timeout = value.timeoutSeconds
            readings = []; language = .en
            guard sourceLanguage == .unspecified || sourceLanguage == .en else { throw ReadingSkillFailure.language }
        case .pdfPage(let value, let config):
            id = .translatePDFPage; taskID = batchTaskID; provider = config; promptVersion = PDFPageTranslationPolicy.promptVersion
            snapshots = value.sources; timeout = 30; readings = []; language = sourceLanguage
            struct Metadata: Encodable { let pageIndex: Int; let text: String }
            batchMetadata = try ReadingSkillIdentity.data(Metadata(pageIndex: value.snapshot.pageIndex, text: value.snapshot.text))
        case .epubSpine(let value, let config):
            id = .translateEPUBSpine; taskID = batchTaskID; provider = config; promptVersion = EPUBChapterTranslationPolicy.promptVersion
            snapshots = value.sources; timeout = 30; readings = []; language = sourceLanguage
            struct Metadata: Encodable { let href: String; let spineIndex: Int; let chapterCount: Int; let utf16Count: Int; let text: String?; let vertical: Bool }
            batchMetadata = try ReadingSkillIdentity.data(Metadata(href: value.snapshot.resourceHref, spineIndex: value.snapshot.spineIndex,
                chapterCount: value.snapshot.chapterCount, utf16Count: value.snapshot.utf16Count, text: value.snapshot.text, vertical: value.snapshot.vertical))
        }
        let manifest = try registry.manifest(for: id)
        guard provider.isValid else { throw AIFailure.configuration }
        guard provider.mode != .unconfigured else { throw AIFailure.unconfigured }
        switch registry.availability(for: id, provider: provider) {
        case .localSynthetic, .boundedRemote: break
        case .unavailable: throw ReadingSkillFailure.capability
        }
        guard timeout.isFinite, timeout > 0, timeout <= manifest.budget.maxTimeoutSecondsPerRequest else { throw AIFailure.configuration }
        let inputLimit = provider.mode == .mock ? (manifest.maxMockInputUTF16 ?? manifest.maxInputUTF16) : manifest.maxInputUTF16
        let segmentLimit = manifest.scope == .selection ? inputLimit : DeepSeekSelectionPolicy.maxSourceUTF16
        guard !snapshots.isEmpty, snapshots.count <= manifest.maxSegments,
              snapshots.allSatisfy({ $0.isValid && $0.anchor.quote.utf16.count <= segmentLimit }) else { throw ReadingSkillFailure.input }
        let count = snapshots.reduce(0) { $0 + $1.anchor.quote.utf16.count }
        guard count <= inputLimit else { throw ReadingSkillFailure.input }
        for snapshot in snapshots {
            let format: ReadingSkillFormat, scope: ReadingSkillScope
            switch snapshot.anchor {
            case .pdf: format = .pdf; scope = .selection
            case .epub: format = .epub; scope = .selection
            case .pdfPage: format = .pdf; scope = .pdfPhysicalPage
            case .epubChapter: format = .epub; scope = .epubCurrentSpine
            }
            guard manifest.formats.contains(format), manifest.scope == scope else { throw ReadingSkillFailure.scope }
        }
        guard manifest.sourceLanguages.contains(language) else { throw ReadingSkillFailure.language }
        let resolved = try manifest.resolveParameters(parameters)
        let receiverURL = provider.mode == .mock ? nil : try BYOKSelectionPolicy.finalURL(provider)
        struct Identity: Encodable {
            let manifest: ReadingSkillManifest; let provider: AIProviderConfig; let receiver: String?
            let sourceLanguage: ReadingSkillLanguage; let parameters: [String: ReadingSkillParameterValue]
            let sources: [AISourceSnapshot]; let authorReadings: [JapaneseAuthorReading]
            let promptVersion: String; let timeoutSeconds: Double; let batchMetadata: Data?
            let context: [String] // Explicitly empty. No notes/history/other books/implicit memory.
        }
        let identity = Identity(manifest: manifest, provider: provider, receiver: receiverURL?.absoluteString,
            sourceLanguage: language, parameters: resolved, sources: snapshots, authorReadings: readings,
            promptVersion: promptVersion, timeoutSeconds: timeout, batchMetadata: batchMetadata, context: [])
        self.taskID = taskID; self.request = request; self.manifest = manifest; self.provider = provider
        self.receiverURL = receiverURL; self.sourceLanguage = language; self.parameters = resolved
        self.sources = try snapshots.enumerated().map { try .init(id: "source-\($0.offset + 1)", source: $0.element) }
        self.promptVersion = promptVersion; timeoutSecondsPerRequest = timeout; inputUTF16 = count
        cacheIdentity = ReadingSkillIdentity.digest(try ReadingSkillIdentity.data(identity))
    }
    public func requireConsent(_ consent: ReadingSkillConsent) throws {
        guard consent.taskID == taskID, consent.planFingerprint == confirmationFingerprint else { throw ReadingSkillFailure.consent }
    }
    public func sourceReference(id: String) -> ReadingSkillSourceReference? { sources.first { $0.id == id } }
}
extension ReadingSkillIdentity {
    public static func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
    public static func matches<T: Encodable>(_ lhs: T, _ rhs: T) -> Bool {
        guard let a = try? data(lhs), let b = try? data(rhs) else { return false }; return a == b
    }
}
