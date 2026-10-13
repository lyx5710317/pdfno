// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Process-lifetime owner; recreating a window/model does not grant more sends.
/// This owner contains counters only, never credentials, drafts or document data.
public final class AppAISession: Sendable {
    public static let shared: AppAISession = {
        let unlimited = permitsUnlimitedReadingQA(bundleIdentifier: Bundle.main.bundleIdentifier,
                                                 arguments: ProcessInfo.processInfo.arguments)
        if unlimited { recordQAEvent("unlimited_selection_session") }
        return unlimited ? AppAISession(selectionBudget: .unlimitedForExplicitQA()) : AppAISession()
    }()
    public let probe = DeepSeekSelectionBudget(maxAttempts: DeepSeekSelfTest.maxAttempts)
    public let selection: DeepSeekSelectionBudget
    public let chapter = DeepSeekSelectionBudget(maxAttempts: EPUBChapterTranslationPolicy.maxSessionRequests)
    public let page = DeepSeekSelectionBudget(maxAttempts: PDFPageTranslationPolicy.maxSessionRequests)
    public init(selectionBudget: DeepSeekSelectionBudget = DeepSeekSelectionBudget()) {
        selection = selectionBudget
    }
    /// Requires an isolated QA bundle, a valid synthetic Library session, and an
    /// explicit launch option. It changes only QA selection sends, never billing.
    public static func permitsUnlimitedReadingQA(bundleIdentifier: String?, arguments: [String]) -> Bool {
        guard bundleIdentifier?.hasPrefix("org.pdfno.integration.professionala20261007.qa") == true,
              arguments.contains("--ui-testing"), arguments.contains("--ui-test-unlimited-reading-requests"),
              let sessionIndex = arguments.firstIndex(of: "--ui-test-session"),
              arguments.indices.contains(sessionIndex + 1), UUID(uuidString: arguments[sessionIndex + 1]) != nil else { return false }
        return true
    }
    /// Fixed metadata in the explicit QA App's redirected stdout only. No source,
    /// credential, HTTP body or response content enters this test receipt.
    static func recordQAEvent(_ event: String, requestID: UUID? = nil, status: Int? = nil) {
        guard permitsUnlimitedReadingQA(bundleIdentifier: Bundle.main.bundleIdentifier,
                                        arguments: ProcessInfo.processInfo.arguments) else { return }
        var record: [String: Any] = ["event": event, "atUTC": ISO8601DateFormatter().string(from: Date())]
        if let requestID { record["requestID"] = requestID.uuidString }
        if let status { record["httpStatus"] = status }
        guard var bytes = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]) else { return }
        bytes.append(0x0a); FileHandle.standardOutput.write(bytes)
    }
}
