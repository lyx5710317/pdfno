// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public struct PDFBookmarkPosition: Codable, Sendable, Equatable {
    public let editionID: UUID
    public let fileSHA256: String
    public let pageIndex: Int
    public let x: Double
    public let y: Double
    public init(editionID: UUID,fileSHA256: String,pageIndex: Int,x: Double,y: Double) {
        self.editionID=editionID;self.fileSHA256=fileSHA256;self.pageIndex=pageIndex;self.x=x;self.y=y
    }
    public var isValid: Bool { fileSHA256.count == 64 && fileSHA256.allSatisfy { "0123456789abcdef".contains($0) } && (0..<100000).contains(pageIndex) && x.isFinite && y.isFinite && abs(x)<10_000_000 && abs(y)<10_000_000 }
}
public enum BookmarkLocation: Codable, Sendable, Equatable {
    case pdf(PDFBookmarkPosition), epub(EPUBAnchor)
    public var isValid: Bool { switch self { case .pdf(let value): value.isValid;case .epub(let value): value.isValid } }
    public var label: String { switch self { case .pdf(let value): "第 \(value.pageIndex+1) 页";case .epub(let value): "第 \(value.spineIndex+1) 个文档 · 位置 \(value.start+1)" } }
    public func isSamePosition(as other: Self) -> Bool {
        switch (self,other) {
        case (.pdf(let a),.pdf(let b)): return a.editionID==b.editionID && a.fileSHA256==b.fileSHA256 && a.pageIndex==b.pageIndex && abs(a.x-b.x)<0.5 && abs(a.y-b.y)<0.5
        case (.epub(let a),.epub(let b)): return AnnotationAnchor.epub(a).isSameSource(as: .epub(b))
        default: return false
        }
    }
}
public struct ReadingBookmark: Codable, Sendable, Equatable, Identifiable {
    public let id: UUID
    public let bookID: UUID
    public let location: BookmarkLocation
    public var title: String
    public var revision: Int
    public let createdAt: Date
    public var updatedAt: Date
    public init(id: UUID=UUID(),bookID: UUID,location: BookmarkLocation,title: String,revision: Int=1,createdAt: Date=Date(),updatedAt: Date=Date()) {
        self.id=id;self.bookID=bookID;self.location=location;self.title=title;self.revision=revision;self.createdAt=createdAt;self.updatedAt=updatedAt
    }
    public var isValid: Bool { location.isValid && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.utf16.count<=128 && !title.contains("\n") && revision>0 && revision<Int.max && createdAt.timeIntervalSince1970.isFinite && updatedAt.timeIntervalSince1970.isFinite }
}
