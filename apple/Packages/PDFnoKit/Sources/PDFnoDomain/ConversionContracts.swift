// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum ConversionFormat: String, Sendable, CaseIterable, Identifiable {
    case docx, plainText, html, readingPDF
    public var id: String { rawValue }
    public var fileExtension: String { self == .plainText ? "txt" : (self == .readingPDF ? "pdf" : rawValue) }
    public var title: String {
        switch self { case .docx: "DOCX"; case .plainText: "UTF-8 TXT"; case .html: "简化 HTML"; case .readingPDF: "阅读版PDF" }
    }
}

public struct ConversionCapability: Sendable, Equatable {
    public let input: ConversionFormat
    public let output: ConversionFormat
    public let adapterID: String
    public init(input: ConversionFormat, output: ConversionFormat, adapterID: String) {
        self.input = input; self.output = output; self.adapterID = adapterID
    }
}

public enum ConversionWarning: String, Sendable, CaseIterable {
    case bodyOnly, simplifiedLayout
    public var message: String {
        switch self {
        case .bodyOnly: "只导出正文文字；图片、页眉页脚、脚注、批注和链接地址不会导出，域值不会重新计算。"
        case .simplifiedLayout: "保留正文段落、换行和表格单元格顺序；字体、分页、编号与复杂版式不保真。修订使用插入后的文字，删除文字与 ruby 读音不导出。"
        }
    }
}

public enum ConversionPhase: String, Sendable {
    case reading, validating, converting, paginating, writing, completed
    public var title: String {
        switch self {
        case .reading: "读取原文件"; case .validating: "检查 DOCX"; case .converting: "提取正文"
        case .paginating: "分页阅读正文"; case .writing: "保存副本"; case .completed: "转换完成"
        }
    }
    public var fraction: Double {
        switch self { case .reading: 0.05; case .validating: 0.25; case .converting: 0.5; case .paginating: 0.7; case .writing: 0.9; case .completed: 1 }
    }
}

public struct ConversionRequest: Sendable {
    public let source: URL
    public let destination: URL
    public let input: ConversionFormat
    public let output: ConversionFormat
    public init(source: URL, destination: URL, input: ConversionFormat = .docx, output: ConversionFormat) {
        self.source = source; self.destination = destination; self.input = input; self.output = output
    }
}

public struct ConvertedDocument: Sendable {
    public let data: Data
    public let warnings: [ConversionWarning]
    public let readingPDFReport: DOCXReadingPDFReport?
    public init(data: Data, warnings: [ConversionWarning], readingPDFReport: DOCXReadingPDFReport? = nil) {
        self.data = data; self.warnings = warnings; self.readingPDFReport = readingPDFReport
    }
}

public struct ConversionResult: Sendable {
    public let destination: URL
    public let byteCount: Int
    public let adapterID: String
    public let warnings: [ConversionWarning]
    public let readingPDFReport: DOCXReadingPDFReport?
    public init(destination: URL, byteCount: Int, adapterID: String, warnings: [ConversionWarning], readingPDFReport: DOCXReadingPDFReport? = nil) {
        self.destination = destination; self.byteCount = byteCount; self.adapterID = adapterID; self.warnings = warnings
        self.readingPDFReport = readingPDFReport
    }
}

public enum ConversionError: Error, LocalizedError, Equatable {
    case unsupportedDirection, invalidSource, invalidArchive, invalidDocument, unsupportedDocument
    case resourceLimit, destinationExists, invalidDestination, ioFailure
    public var errorDescription: String? {
        switch self {
        case .unsupportedDirection: "此转换方向尚未支持。请使用当前入口列出的输出格式。"
        case .invalidSource: "请选择可读取的本地 DOCX 普通文件，不能使用符号链接。"
        case .invalidArchive: "DOCX 归档损坏、不安全、加密或含当前不支持的 ZIP 结构。"
        case .invalidDocument: "文件不是有效的 DOCX 正文文档，或 XML 内容无法安全解析。"
        case .unsupportedDocument: "此 DOCX 含不支持的宏、替代内容或非标准主文档位置；请使用普通 DOCX。"
        case .resourceLimit: "文件超出转换限额（20 MiB 原件、1000 项、4 MiB 单项、50 MiB 声明解压量）。"
        case .destinationExists: "输出位置已有文件。为保护原件和已有文件，请选择新的名称或位置。"
        case .invalidDestination: "请选择已存在目录中与所选格式匹配的新文件；不能覆盖原件。"
        case .ioFailure: "读取或保存失败。请检查文件权限与剩余空间，重新选择位置后再试。"
        }
    }
}
