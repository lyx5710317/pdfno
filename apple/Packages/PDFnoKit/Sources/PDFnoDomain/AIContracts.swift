// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum AIProviderMode: String, Codable, Sendable { case unconfigured, mock, openAICompatible }
public struct AIProviderConfig: Codable, Sendable, Equatable {
    public var id = UUID()
    public var generation = 1
    public var mode: AIProviderMode = .unconfigured
    public var label = "未配置"
    public var endpoint = ""
    public var model = ""
    public init() {}
    public var isValid: Bool {
        generation > 0 && generation < Int.max && label.utf16.count <= 100 && model.utf16.count <= 200 && endpoint.utf8.count <= 2048 &&
        (mode != .openAICompatible || ProviderValidation.validate(endpoint: endpoint, model: model))
    }
}
public enum AISelectionAnchor: Codable, Sendable, Equatable {
    case pdf(PDFSourceAnchor), epub(EPUBAnchor), pdfPage(PDFPageTextAnchor)
    public var quote: String { switch self { case .pdf(let a): a.quote; case .epub(let a): a.quote; case .pdfPage(let a): a.quote } }
    public var editionID: UUID { switch self { case .pdf(let a): a.editionID; case .epub(let a): a.editionID; case .pdfPage(let a): a.editionID } }
    public var fileSHA256: String { switch self { case .pdf(let a): a.fileSHA256; case .epub(let a): a.fileSHA256; case .pdfPage(let a): a.fileSHA256 } }
    public var locationLabel: String {
        switch self {
        case .pdf(let a): "PDF · 第 \((a.regions.first?.pageIndex ?? 0) + 1) 页"
        case .pdfPage(let a): "PDF · 第 \(a.pageIndex + 1) 页 · 原文 UTF-16 \(a.start)–\(a.end)"
        case .epub(let a): "EPUB · 第 \(a.spineIndex + 1) 章 · 原文 UTF-16 \(a.start)–\(a.end)"
        }
    }
    public var isValid: Bool {
        switch self {
        case .epub(let a): a.isValid
        case .pdfPage(let a): a.isValid
        case .pdf(let a):
            a.schemaVersion == 1 && a.extractionVersion == "pdfkit-selection-1" && a.hasConsistentQuote &&
            a.fileSHA256.count == 64 && a.fileSHA256.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } &&
            !a.regions.isEmpty && a.regions.count <= 100 && a.regions.allSatisfy {
                $0.pageIndex >= 0 && !$0.quote.isEmpty && [$0.x, $0.y, $0.width, $0.height].allSatisfy(\.isFinite) && $0.width > 0 && $0.height > 0
            }
        }
    }
}
public struct AISourceSnapshot: Codable, Sendable, Equatable {
    public let bookID: UUID
    public let readerSessionID: UUID
    public let documentVersion: Int
    public let anchor: AISelectionAnchor
    public init(bookID: UUID, readerSessionID: UUID, documentVersion: Int, anchor: AISelectionAnchor) {
        self.bookID = bookID; self.readerSessionID = readerSessionID; self.documentVersion = documentVersion; self.anchor = anchor
    }
    public var isValid: Bool { anchor.isValid && documentVersion >= 0 && !anchor.quote.isEmpty && anchor.quote.utf16.count <= 8000 }
}
public enum AILearningKind: String, Codable, Sendable, CaseIterable { case translate, explain }
public struct AIRequest: Sendable {
    public let id: UUID
    public let source: AISourceSnapshot
    public let provider: AIProviderConfig
    public let kind: AILearningKind
    public let timeoutSeconds: Double
    public init(id: UUID = UUID(), source: AISourceSnapshot, provider: AIProviderConfig, kind: AILearningKind, timeoutSeconds: Double = 30) {
        self.id = id; self.source = source; self.provider = provider; self.kind = kind; self.timeoutSeconds = timeoutSeconds
    }
}
extension AIRequest {
    public var promptVersion: String {
        if case .pdfPage = source.anchor { return PDFPageTranslationPolicy.promptVersion }
        return DeepSeekSelectionPolicy.supports(provider) ? DeepSeekSelectionPolicy.promptVersion : "selection-1"
    }
}
public struct AIConsent: Sendable {
    public let requestID: UUID
    public let scopeFingerprint: String
    public init(requestID: UUID, scopeFingerprint: String) { self.requestID = requestID; self.scopeFingerprint = scopeFingerprint }
}
public struct AIProviderOutput: Sendable {
    public let sourceQuote: String
    public let text: String
    public init(sourceQuote: String, text: String) { self.sourceQuote = sourceQuote; self.text = text }
}
public struct AIResult: Codable, Sendable, Equatable {
    public let requestID: UUID
    public let source: AISourceSnapshot
    public let provider: AIProviderConfig
    public let kind: AILearningKind
    public let text: String
    public let promptVersion: String
    public let fromCache: Bool
    public init(request: AIRequest, text: String, fromCache: Bool) {
        requestID = request.id; source = request.source; provider = request.provider; kind = request.kind
        self.text = text; promptVersion = request.promptVersion; self.fromCache = fromCache
    }
}
public struct AILearningNote: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public let result: AIResult
    public let userText: String
    public init(id: UUID = UUID(), result: AIResult, userText: String) { self.id = id; self.result = result; self.userText = userText }
}
public enum AIFailure: String, LocalizedError, Sendable {
    case unconfigured, configuration, consent, inputLimit, credentials, authentication, rateLimit, quota, timeout, cancelled, stale, network, redirect, server, output, store, remoteInputLimit, attemptLimit, truncated
    public var errorDescription: String? {
        switch self {
        case .unconfigured: "服务未配置。可明确选择本地 mock 演示；不会自动切换服务。"
        case .configuration: "服务地址或模型配置无效。使用 HTTPS 或明确的本机 loopback HTTP；地址不能包含凭据、查询或片段。"
        case .consent: "请先确认本次选文、服务、模型和处理范围。"
        case .inputLimit: "选文为空或超过本片 8000 UTF-16 单位上限；请缩小选区。"
        case .credentials: "当前会话密钥未配置或已清除；请在模型设置中手动输入。本片不保存持久密钥。"
        case .authentication: "HTTP 401 / 403：服务拒绝认证；请自行检查当前会话密钥。"
        case .rateLimit: "HTTP 429：服务限流；本次不会自动重发。"
        case .quota: "HTTP 402：服务额度不足；本次不会自动重发。"
        case .timeout: "请求已超时并取消；迟到结果不会写入当前文档。"
        case .cancelled: "请求已取消；没有保存新笔记。"
        case .stale: "文档、选区或服务配置已改变；请重新确认来源。"
        case .network: "连接失败；本次不会自动重发或切换服务。"
        case .redirect: "已拒绝重定向；凭据不会转发到其他地址。"
        case .server: "服务返回错误；响应正文不会进入日志。"
        case .output: "结果结构或来源引文无法验证；不会接受模型自造引用。"
        case .store: "学习数据无法验证；现有数据不会被覆盖。"
        case .remoteInputLimit: "DeepSeek 首片只接受最多500 UTF-16单位选文；请缩小选区，不会自动截断或扩大范围。"
        case .attemptLimit: "本次应用会话的三次阅读请求额度已用完；失败或取消也占次数，不会自动重试。"
        case .truncated: "服务输出达到本次上限而截断；未计为成功，不会自动重试或保存。"
        }
    }
}
