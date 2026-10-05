// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// No arbitrary JSON payload and no decoding path that can assert host validation.
public enum ReadingSkillPayload: Sendable {
    case text(AIResult), japanese(JapaneseLearningReview), english(EnglishLearningReview)
}
public enum ReadingSkillValidation: String, Sendable { case sourceAndStructure, candidatesNeedReview, trustedSourceOnly }
public enum ReadingSkillUsage: String, Sendable { case unknown, localSynthetic, cacheWithoutNetwork }
/// Ephemeral adapter view, never a replacement for learning-v1 / Japanese / English note files.
/// Language quality, current-file navigation and save success are not inferred from this envelope.
public struct ReadingSkillResultEnvelope: Sendable {
    public let taskID: UUID
    public let manifest: ReadingSkillManifest
    public let promptVersion: String
    public let provider: AIProviderConfig
    public let sources: [ReadingSkillSourceReference]
    public let inputAndParametersSHA256: String
    public let payload: ReadingSkillPayload
    public let validation: ReadingSkillValidation
    public let usage: ReadingSkillUsage
    public let fromCache: Bool
    init(plan: ReadingSkillInputPlan, payload: ReadingSkillPayload) throws {
        guard plan.manifest.routing == .selectionAdapter, plan.sources.count == 1 else { throw ReadingSkillFailure.scope }
        let source: AISourceSnapshot, provider: AIProviderConfig, prompt: String, requestID: UUID
        let validation: ReadingSkillValidation, fromCache: Bool
        switch (plan.request, payload) {
        case (.text, .text(let result)):
            guard !result.text.isEmpty, result.text.utf16.count <= 16000,
                  case .text(let request) = plan.request, result.kind == request.kind else { throw ReadingSkillFailure.result }
            source = result.source; provider = result.provider; prompt = result.promptVersion; requestID = result.requestID
            validation = .sourceAndStructure; fromCache = result.fromCache
        case (.japanese(let request), .japanese(let result)):
            guard ReadingSkillIdentity.matches(result.authorReadings, request.authorReadings) else { throw ReadingSkillFailure.result }
            if result.status == .unavailable {
                // Exact host fallback only: no unverified output, span or model warning survives.
                guard ReadingSkillIdentity.matches(result, JapaneseLearningValidator.validate(Data(), request: request)) else { throw ReadingSkillFailure.result }
                validation = .trustedSourceOnly
            } else {
                guard result.isPersistable else { throw ReadingSkillFailure.result }; validation = .candidatesNeedReview
            }
            source = result.source; provider = result.provider; prompt = result.promptVersion; requestID = result.requestID
            fromCache = false
        case (.english(let request), .english(let result)):
            if result.status == .unavailable {
                guard ReadingSkillIdentity.matches(result, EnglishLearningValidator.validate(Data(), request: request)) else { throw ReadingSkillFailure.result }
                validation = .trustedSourceOnly
            } else {
                guard result.isPersistable else { throw ReadingSkillFailure.result }; validation = .candidatesNeedReview
            }
            source = result.source; provider = result.provider; prompt = result.promptVersion; requestID = result.requestID
            fromCache = false
        default: throw ReadingSkillFailure.result
        }
        guard requestID == plan.taskID, prompt == plan.promptVersion, plan.manifest.result.promptVersions.contains(prompt),
              ReadingSkillIdentity.matches(source, plan.sources[0].source), ReadingSkillIdentity.matches(provider, plan.provider) else { throw ReadingSkillFailure.result }
        taskID = plan.taskID; manifest = plan.manifest; promptVersion = prompt; self.provider = provider; sources = plan.sources
        inputAndParametersSHA256 = plan.cacheIdentity; self.payload = payload; self.validation = validation; self.fromCache = fromCache
        usage = fromCache ? .cacheWithoutNetwork : provider.mode == .mock ? .localSynthetic : .unknown
    }
}
