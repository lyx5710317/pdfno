// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Explicit forwarding seam, not a new runtime or authority owner. The caller supplies:
/// - the existing coordinator (including its cache/cancel lifecycle),
/// - the host's already-bound provider using the SAME AppAISession.selection,
/// - both the displayed Skills-plan confirmation and the original host confirmation,
/// - current source AND provider/credential-generation validation before and after work.
/// No default provider, transport, credentials, budget, retry, save, or batch execution path.
/// Existing UI buttons do not route here until a separately reviewed host integration.
public enum ReadingSkillSelectionAdapter {
    public typealias CurrentSourceCheck = @Sendable (AISourceSnapshot, AIProviderConfig) async -> Bool
    public static func runText(_ plan: ReadingSkillInputPlan, consent: ReadingSkillConsent, hostConsent: AIConsent,
                               coordinator: AIJobCoordinator, provider: any AIProvider,
                               sourceAndConfigurationAreCurrent: CurrentSourceCheck) async throws -> ReadingSkillResultEnvelope {
        try await preflight(plan, consent: consent, current: sourceAndConfigurationAreCurrent)
        guard case .text(let request) = plan.request else { throw ReadingSkillFailure.scope }
        // Host consent is never synthesized or broadened by this adapter.
        let result = try await coordinator.run(request, consent: hostConsent, provider: provider)
        try await postflight(plan, current: sourceAndConfigurationAreCurrent)
        return try ReadingSkillResultEnvelope(plan: plan, payload: .text(result))
    }
    public static func runJapanese(_ plan: ReadingSkillInputPlan, consent: ReadingSkillConsent, hostConsent: AIConsent,
                                   coordinator: JapaneseLearningCoordinator, provider: any JapaneseLearningProvider,
                                   sourceAndConfigurationAreCurrent: CurrentSourceCheck) async throws -> ReadingSkillResultEnvelope {
        try await preflight(plan, consent: consent, current: sourceAndConfigurationAreCurrent)
        guard case .japanese(let request) = plan.request else { throw ReadingSkillFailure.scope }
        let result = try await coordinator.run(request, consent: hostConsent, provider: provider)
        try await postflight(plan, current: sourceAndConfigurationAreCurrent)
        return try ReadingSkillResultEnvelope(plan: plan, payload: .japanese(result))
    }
    public static func runEnglish(_ plan: ReadingSkillInputPlan, consent: ReadingSkillConsent, hostConsent: AIConsent,
                                  coordinator: EnglishLearningCoordinator, provider: any EnglishLearningProvider,
                                  sourceAndConfigurationAreCurrent: CurrentSourceCheck) async throws -> ReadingSkillResultEnvelope {
        try await preflight(plan, consent: consent, current: sourceAndConfigurationAreCurrent)
        guard case .english(let request) = plan.request else { throw ReadingSkillFailure.scope }
        let result = try await coordinator.run(request, consent: hostConsent, provider: provider)
        try await postflight(plan, current: sourceAndConfigurationAreCurrent)
        return try ReadingSkillResultEnvelope(plan: plan, payload: .english(result))
    }
    private static func preflight(_ plan: ReadingSkillInputPlan, consent: ReadingSkillConsent,
                                  current: CurrentSourceCheck) async throws {
        try Task.checkCancellation(); try plan.requireConsent(consent)
        guard plan.manifest.routing == .selectionAdapter else { throw ReadingSkillFailure.scope }
        try await postflight(plan, current: current)
    }
    private static func postflight(_ plan: ReadingSkillInputPlan, current: CurrentSourceCheck) async throws {
        try Task.checkCancellation()
        for reference in plan.sources {
            guard await current(reference.source, plan.provider) else { throw ReadingSkillFailure.staleSource }
            try Task.checkCancellation()
        }
    }
}
