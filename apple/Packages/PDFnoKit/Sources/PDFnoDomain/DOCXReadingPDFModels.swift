// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

/// Fixed, finite reading layout. This is not a Word page-layout or fidelity contract.
public struct DOCXReadingPDFSettings: Sendable, Equatable {
    public let pageWidth = 595.28
    public let pageHeight = 841.89
    public let margin = 48.0
    public let bodyFontSize = 12.0
    public let maximumPages = 300
    public init() {}
    public static let lossWarnings = [
        "阅读版PDF重新分页，不能还原 Word 原版式、原页码、原字体或编辑能力。",
        "仅导出现有 Mammoth 语义阅读内容：基本标题、段落、粗体／斜体、列表层级；表格按行／单元格顺序展开，编号统一为项目符号。",
        "图片仅保留阅读器已有的文字占位；页眉页脚、批注、修订、域值、脚注、公式、ruby 与复杂对象不保证完整或保真，外部资源和链接地址不导出。",
        "PDF保留Quartz的原文ActualText；部分第三方提取器会忽略它，把中日文同形字提取为兼容部首，不能将提取的文字用于DOCX旧锚点。",
        "使用本机系统字体及中日文字体回退；检测到缺失字形、超过300页或16 MiB输出时停止，不自动换引擎或上传。原文来源与旧笔记锚点保留，PDF不继承DOCX锚点。"
    ]
}

public struct DOCXReadingPDFReport: Sendable, Equatable {
    public let sourceSHA256: String
    public let semanticEngineID: String
    public let extractionVersion: String
    public let rendererID: String
    public let pageCount: Int
    public let semanticBlockCount: Int
    public let canonicalUTF16Count: Int
    public let fonts: [String]
    public let settings: DOCXReadingPDFSettings
    public let semanticWarnings: [String]
    public var lossWarnings: [String] { DOCXReadingPDFSettings.lossWarnings }
    public init(sourceSHA256: String, pageCount: Int, semanticBlockCount: Int, canonicalUTF16Count: Int,
                fonts: [String], settings: DOCXReadingPDFSettings, semanticWarnings: [String]) {
        self.sourceSHA256 = sourceSHA256; semanticEngineID = "kookit-mammoth-1.13.0"
        extractionVersion = DOCXDocument.extractionVersion; rendererID = "apple-coretext-reading-pdf-1"
        self.pageCount = pageCount; self.semanticBlockCount = semanticBlockCount
        self.canonicalUTF16Count = canonicalUTF16Count; self.fonts = fonts; self.settings = settings
        self.semanticWarnings = semanticWarnings
    }
}

public enum DOCXReadingPDFError: Error, LocalizedError, Equatable {
    case invalidSemanticDocument, missingGlyph, layoutFailure, resourceLimit
    public var errorDescription: String? {
        switch self {
        case .invalidSemanticDocument: "DOCX 语义正文无效，未生成阅读版PDF。"
        case .missingGlyph: "本机字体无法显示部分正文字符，已停止导出；未生成阅读版PDF。"
        case .layoutFailure: "正文无法在阅读版PDF页边距内完整分页，已停止导出。"
        case .resourceLimit: "阅读版PDF超过300页或16 MiB限额，已停止导出。"
        }
    }
}
