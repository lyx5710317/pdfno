// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// A finite compiled dispatch table. No downloaded prompts, scripts or executable tools.
/// Conversation version 1 explicitly permits only this thread's bounded user/assistant turns.
/// The existing ReadingSkillInputPlan and its empty-context contracts remain unchanged.
public enum ReadingConversationTask: String, Codable, Sendable, CaseIterable {
    case explain, translate, summarize, japanese, english
    public var title: String {
        switch self { case .explain: "解释"; case .translate: "翻译"; case .summarize: "总结"; case .japanese: "日语学习"; case .english: "英语学习" }
    }
    public var skillID: ReadingSkillID {
        switch self {
        case .explain: .explainSelection
        case .translate: .translateSelection
        case .summarize: .summarizeSelection
        case .japanese: .japaneseSelection
        case .english: .englishSelection
        }
    }
    public var legacyKind: AILearningKind {
        switch self { case .translate: .translate; case .summarize: .summarize; default: .explain }
    }
    public var initialQuestion: String { "请" + title + "这段选文。" }
    public var instruction: String {
        switch self {
        case .explain: "Explain the selected text in Simplified Chinese. Separate literal meaning, reasoning and ambiguity. Ground each claim in the selection; explicitly mark uncertainty."
        case .translate: "Translate only the selected text faithfully into Simplified Chinese. Preserve qualifications and names. On follow-up, explain translation choices without adding source facts."
        case .summarize: "Summarize only the selection's key claims, evidence and qualifications in Simplified Chinese. Do not infer the rest of the book or invent conclusions."
        case .japanese: "Teach the Japanese selection in Simplified Chinese: meaning, sentence structure, particles and vocabulary. Any suggested pronunciation is an AI suggestion requiring review, never author ruby. Preserve supplied author readings and distinguish them from generated suggestions. Do not invent lexical citations."
        case .english: "Teach the English selection in Simplified Chinese: faithful meaning, clauses, subject/verb/object, tense and relevant grammar. Label uncertain parses as candidates. Give source-grounded explanations and mark generated examples as examples."
        }
    }
    public init(_ kind: AILearningKind) {
        switch kind { case .explain: self = .explain; case .translate: self = .translate; case .summarize: self = .summarize }
    }
}
public struct ReadingConversationTurn: Codable, Sendable, Equatable, Identifiable {
    public enum Role: String, Codable, Sendable { case user, assistant }
    public let id: UUID
    public let role: Role
    public let text: String
    public let conversationID: UUID
    public let sourceIdentity: String
    public init(id: UUID = UUID(), role: Role, text: String, conversationID: UUID, source: AISourceSnapshot) throws {
        self.id = id; self.role = role; self.text = text; self.conversationID = conversationID
        sourceIdentity = ReadingSkillIdentity.digest(try ReadingSkillIdentity.data(source))
    }
}
public struct ReadingConversationMetadata: Codable, Sendable, Equatable {
    public let conversationID: UUID
    public let answerID: UUID
    public let task: ReadingConversationTask
    public let question: String
    public var skillID: ReadingSkillID { task.skillID }
    public init(conversationID: UUID, answerID: UUID, task: ReadingConversationTask, question: String) {
        self.conversationID = conversationID; self.answerID = answerID; self.task = task; self.question = question
    }
    public var isValid: Bool { !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && question.utf16.count <= ReadingConversationPlan.maxQuestionUTF16 }
}
public struct ReadingConversationPlan: Sendable {
    public static let promptVersion = "selection-conversation-1"
    public static let maxQuestionUTF16 = 1500
    public static let maxHistoryUTF16 = 10000
    public static let maxTurns = 12
    public let requestID: UUID
    public let conversationID: UUID
    public let answerID: UUID
    public let task: ReadingConversationTask
    public let source: AISourceSnapshot
    public let provider: AIProviderConfig
    public let history: [ReadingConversationTurn]
    public let question: String
    public let authorReadings: [JapaneseAuthorReading]
    public let timeoutSeconds: Double
    public let receiverURL: URL?
    public let fingerprint: String
    public let maxOutputTokens: Int
    public init(requestID: UUID = UUID(), conversationID: UUID, answerID: UUID = UUID(), task: ReadingConversationTask,
                source: AISourceSnapshot, provider: AIProviderConfig, history: [ReadingConversationTurn] = [], question: String,
                authorReadings: [JapaneseAuthorReading] = [], timeoutSeconds: Double = 30,
                registry: ReadingSkillRegistry = .builtin) throws {
        let manifest = try registry.manifest(for: task.skillID)
        guard manifest.scope == .selection, manifest.routing == .selectionAdapter,
              manifest.tools.isEmpty, !manifest.automaticSave else { throw ReadingSkillFailure.scope }
        switch source.anchor { case .pdf, .epub: break; default: throw ReadingSkillFailure.scope }
        guard source.isValid, source.anchor.quote.utf16.count <= manifest.maxInputUTF16 else { throw AIFailure.remoteInputLimit }
        guard provider.isValid, provider.mode != .unconfigured else { throw AIFailure.unconfigured }
        guard timeoutSeconds.isFinite, timeoutSeconds > 0, timeoutSeconds <= 30 else { throw AIFailure.configuration }
        let sourceIdentity = ReadingSkillIdentity.digest(try ReadingSkillIdentity.data(source))
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, question.utf16.count <= Self.maxQuestionUTF16,
              history.count <= Self.maxTurns, history.count.isMultiple(of: 2),
              history.reduce(0, { $0 + $1.text.utf16.count }) <= Self.maxHistoryUTF16,
              Set(history.map(\.id)).count == history.count,
              history.enumerated().allSatisfy({ index, turn in
                  turn.conversationID == conversationID && turn.sourceIdentity == sourceIdentity &&
                  turn.role == (index.isMultiple(of: 2) ? .user : .assistant) && !turn.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && turn.text.utf16.count <= 16000
              }) else { throw ReadingSkillFailure.input }
        // Author readings are data from the existing canonical source extractor, not model authority.
        guard authorReadings.isEmpty || task == .japanese else { throw ReadingSkillFailure.input }
        guard authorReadings.count <= JapaneseLearningPolicy.maxReadings,
              authorReadings.allSatisfy({ $0.span.isValid(in: source.anchor.quote) && !$0.reading.isEmpty && $0.reading.utf16.count <= 100 }) else { throw ReadingSkillFailure.input }
        self.requestID = requestID; self.conversationID = conversationID; self.answerID = answerID
        self.task = task; self.source = source; self.provider = provider; self.history = history
        self.question = question; self.authorReadings = authorReadings; self.timeoutSeconds = timeoutSeconds
        receiverURL = provider.mode == .mock ? nil : try ConfiguredAPISelectionPolicy.finalURL(provider)
        maxOutputTokens = manifest.budget.maxOutputTokensPerRequest
        struct Identity: Encodable {
            let version: String; let requestID: UUID; let conversationID: UUID; let answerID: UUID
            let skillID: ReadingSkillID; let source: AISourceSnapshot; let provider: AIProviderConfig
            let history: [ReadingConversationTurn]; let question: String; let readings: [JapaneseAuthorReading]; let timeout: Double
        }
        fingerprint = ReadingSkillIdentity.digest(try ReadingSkillIdentity.data(Identity(version: Self.promptVersion, requestID: requestID,
            conversationID: conversationID, answerID: answerID, skillID: task.skillID, source: source, provider: provider,
            history: history, question: question, readings: authorReadings, timeout: timeoutSeconds)))
    }
    public func requireConsent(_ consent: ReadingSkillConsent) throws {
        guard consent.taskID == requestID, consent.planFingerprint.utf8.elementsEqual(fingerprint.utf8) else { throw ReadingSkillFailure.consent }
    }
    public func result(_ text: String) throws -> AIResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, text.utf16.count <= 16000 else { throw AIFailure.output }
        return AIResult(conversation: ReadingConversationMetadata(conversationID: conversationID, answerID: answerID, task: task, question: question),
                        source: source, provider: provider, text: text)
    }
}
