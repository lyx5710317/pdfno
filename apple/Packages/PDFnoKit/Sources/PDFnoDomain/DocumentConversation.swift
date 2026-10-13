// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum DocumentConversationFailure: LocalizedError, Sendable, Equatable {
    case tooLarge, incomplete, historyLimit, cancelled
    public var errorDescription: String? {
        switch self {
        case .tooLarge: "全文超过 60000 UTF-16 字符上限，未发送。可使用选文或阅读翻译。"
        case .incomplete: "无法提取完整正文，未发送。当前不支持含扫描页或无文字的全文对话。"
        case .historyLimit: "本会话内容过长，请开始新的全文对话。"
        case .cancelled: "文档或连接已变化，请重新确认。"
        }
    }
}
/// A whole document has its own identity; it is never forged as a selection anchor.
public struct DocumentConversationSource: Codable, Sendable, Equatable {
    public static let maxTextUTF16 = 60_000
    public let bookID: UUID
    public let readerSessionID: UUID
    public let fileSHA256: String
    public let format: String
    public let text: String
    public init(bookID: UUID, readerSessionID: UUID, fileSHA256: String, format: String, text: String) throws {
        guard ["PDF", "EPUB"].contains(format), fileSHA256.count == 64,
              fileSHA256.allSatisfy({ "0123456789abcdef".contains($0) }),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw DocumentConversationFailure.incomplete }
        guard text.utf16.count <= Self.maxTextUTF16 else { throw DocumentConversationFailure.tooLarge }
        self.bookID = bookID; self.readerSessionID = readerSessionID; self.fileSHA256 = fileSHA256
        self.format = format; self.text = text
    }
    public var identity: String { ReadingSkillIdentity.digest((try? ReadingSkillIdentity.data(self)) ?? Data()) }
}
public struct DocumentConversationTurn: Codable, Sendable, Equatable {
    public enum Role: String, Codable, Sendable { case user, assistant }
    public let role: Role
    public let text: String
    public let sourceIdentity: String
    public init(role: Role, text: String, sourceIdentity: String) {
        self.role = role; self.text = text; self.sourceIdentity = sourceIdentity
    }
}
public struct DocumentConversationPlan: Sendable {
    public let source: DocumentConversationSource
    public let provider: AIProviderConfig
    public let history: [DocumentConversationTurn]
    public let question: String
    public let receiverURL: URL?
    public init(source: DocumentConversationSource, provider: AIProviderConfig,
                history: [DocumentConversationTurn], question: String) throws {
        guard provider.isValid, provider.mode != .unconfigured else { throw AIFailure.configuration }
        guard source.text.utf16.count <= DocumentConversationSource.maxTextUTF16 else { throw DocumentConversationFailure.tooLarge }
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              question.utf16.count <= 4000, history.count <= 20, history.count.isMultiple(of: 2),
              history.reduce(0, { $0 + $1.text.utf16.count }) <= 24000,
              history.enumerated().allSatisfy({ index, turn in
                  turn.sourceIdentity == source.identity && turn.role == (index.isMultiple(of: 2) ? .user : .assistant)
              }) else { throw DocumentConversationFailure.historyLimit }
        self.source = source; self.provider = provider; self.history = history; self.question = question
        receiverURL = provider.mode == .mock ? nil : try ConfiguredAPISelectionPolicy.finalURL(provider)
    }
}
