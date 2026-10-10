// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum ReadingPageMode: String, Codable, CaseIterable, Sendable {
    case single, double, scroll
    public var title: String { switch self { case .single: "单栏"; case .double: "双栏"; case .scroll: "滚动" } }
}
public struct ReadingLayout: Codable, Equatable, Sendable {
    public var fontSize: Int
    public var mode: ReadingPageMode
    public var vertical: Bool
    public init(fontSize: Int = 20,mode: ReadingPageMode = .scroll,vertical: Bool = false) {
        self.fontSize=fontSize;self.mode=mode;self.vertical=vertical
    }
    public var isValid: Bool { (12...36).contains(fontSize) }
    public func permitted(for language: DocumentWritingLanguage) -> Self {
        var result=self;if !language.permitsVerticalReflow { result.vertical=false };return result
    }
}
/// The validated reader path determines capability; filename suffixes and
/// intermediate semantic conversions are not evidence of ebook capability.
public enum ReadingFormatCapability: Equatable, Sendable {
    case reflowEPUB, ebook(EbookFormat), flowingText(TextFileFormat), pdf, word, comic, fixedEPUB, unavailable
    public var allowsAa: Bool { switch self { case .reflowEPUB,.ebook,.flowingText: true; default: false } }
    public var allowsBottomPaging: Bool { allowsAa || self == .comic }
}
