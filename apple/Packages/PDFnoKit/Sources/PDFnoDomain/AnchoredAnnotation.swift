// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum AnnotationKind: String, Codable, Sendable, CaseIterable {
    case highlight, underline, note
    public var title: String { switch self { case .highlight: "高亮"; case .underline: "下划线"; case .note: "笔记" } }
    public var symbol: String { switch self { case .highlight: "highlighter"; case .underline: "underline"; case .note: "note.text" } }
}
/// A saved source, independent of AI requests and transient reader sessions.
public enum AnnotationAnchor: Codable, Sendable, Equatable {
    case pdf(PDFSourceAnchor), epub(EPUBAnchor), text(TextFormatAnchor), ebook(EbookAnchor), docx(DOCXAnchor)
    public var quote: String { switch self { case .pdf(let a): a.quote; case .epub(let a): a.quote; case .text(let a): a.quote; case .ebook(let a): a.quote; case .docx(let a): a.quote } }
    public var editionID: UUID { switch self { case .pdf(let a): a.editionID; case .epub(let a): a.editionID; case .text(let a): a.editionID; case .ebook(let a): a.editionID; case .docx(let a): a.editionID } }
    public var fileSHA256: String { switch self { case .pdf(let a): a.fileSHA256; case .epub(let a): a.fileSHA256; case .text(let a): a.fileSHA256; case .ebook(let a): a.fileSHA256; case .docx(let a): a.fileSHA256 } }
    public var format: String? { switch self { case .pdf: "pdf"; case .epub: "epub"; case .text: nil; case .ebook(let a): a.format.rawValue; case .docx: "docx" } }
    public var isValid: Bool {
        guard !quote.isEmpty, quote.utf16.count <= 16000 else { return false }
        switch self { case .pdf(let a): return AISelectionAnchor.pdf(a).isValid; case .epub(let a): return a.isValid; case .text(let a): return a.isValid; case .ebook(let a): return a.isValid; case .docx(let a): return a.isValid }
    }
    /// Orientation is presentation metadata, not a new excerpt or a new mark.
    public func isSameSource(as other: Self) -> Bool {
        func canonical(_ value: Self) -> Self {
            if case .epub(let a) = value {
                var anchor = EPUBAnchor(editionID: a.editionID, fileSHA256: a.fileSHA256, resourceHref: a.resourceHref, spineIndex: a.spineIndex, start: a.start, end: a.end, quote: a.quote, prefix: a.prefix, suffix: a.suffix, vertical: false)
                anchor.schemaVersion = a.schemaVersion; anchor.extractionVersion = a.extractionVersion
                return .epub(anchor)
            }
            return value
        }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        guard let first=try? encoder.encode(canonical(self)),let second=try? encoder.encode(canonical(other)) else { return false }
        return first==second
    }
}
/// AI results enter this sidecar only through a future explicit user-save flow.
/// No legacy record is inferred, migrated or relabelled by the manual tools.
public enum AnnotationOrigin: String, Codable, Sendable { case manual, explicitlySavedAI }
public struct AnchoredAnnotation: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let bookID: UUID
    public let anchor: AnnotationAnchor
    public let origin: AnnotationOrigin
    public let sourceRecordID: UUID?
    public var kind: AnnotationKind
    public var userText: String
    public var revision: Int
    public let createdAt: Date
    public var updatedAt: Date
    /// Revision zero exists only as an unsaved, source-bound editor baseline.
    public init(id: UUID = UUID(), bookID: UUID, anchor: AnnotationAnchor, kind: AnnotationKind, userText: String = "", origin: AnnotationOrigin = .manual, sourceRecordID: UUID? = nil, revision: Int = 0, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id; self.bookID = bookID; self.anchor = anchor; self.kind = kind; self.userText = userText
        self.origin=origin;self.sourceRecordID=sourceRecordID
        self.revision = revision; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
    public var isValid: Bool { (origin == .manual ? sourceRecordID == nil : sourceRecordID != nil) && anchor.isValid && userText.utf16.count <= 16000 && revision >= 0 && revision < Int.max && createdAt.timeIntervalSince1970.isFinite && updatedAt.timeIntervalSince1970.isFinite }
}
public struct AnnotationBodySnapshot: SavedBodySnapshot {
    public let annotation: AnchoredAnnotation
    public init(_ annotation: AnchoredAnnotation) { self.annotation = annotation }
    public static let draftFilename = "annotation-edit-drafts-v1.json"
    public var bookID: UUID { annotation.bookID }
    public var noteID: UUID { annotation.id }
    public var key: String { "annotation:" + bookID.uuidString + ":" + noteID.uuidString }
    public var userText: String { annotation.userText }
    public func accepts(_ text: String) -> Bool { text.utf16.count <= 16000 && annotation.isValid }
    public var limitDescription: String { "批注上限为 16,000 个 UTF-16 单位。" }
}

extension EPUBAnchor {
    public func withVertical(_ vertical: Bool) -> EPUBAnchor {
        var value=EPUBAnchor(editionID: editionID,fileSHA256: fileSHA256,resourceHref: resourceHref,spineIndex: spineIndex,start: start,end: end,quote: quote,prefix: prefix,suffix: suffix,vertical: vertical)
        value.schemaVersion=schemaVersion;value.extractionVersion=extractionVersion;return value
    }
}
