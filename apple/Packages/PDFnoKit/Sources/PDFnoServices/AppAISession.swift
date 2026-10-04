// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import PDFnoDomain

/// Process-lifetime owner; recreating a window/model does not grant more sends.
/// This owner contains counters only, never credentials, drafts or document data.
public final class AppAISession: Sendable {
    public static let shared = AppAISession()
    public let probe = DeepSeekSelectionBudget(maxAttempts: DeepSeekSelfTest.maxAttempts)
    public let selection = DeepSeekSelectionBudget()
    public let chapter = DeepSeekSelectionBudget(maxAttempts: EPUBChapterTranslationPolicy.maxSessionRequests)
    public let page = DeepSeekSelectionBudget(maxAttempts: PDFPageTranslationPolicy.maxSessionRequests)
    public init() {}
}
