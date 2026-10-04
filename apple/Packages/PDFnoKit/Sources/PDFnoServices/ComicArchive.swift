// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// An explicit container route. The extension must match its real parser; there is no sniff/fallback rename.
public enum ComicArchive: Sendable {
    case cbz(CBZArchive), cbt(CBTArchive), native(NativeComicArchive)
    public init(data: Data, format: ComicArchiveFormat) throws {
        switch format {
        case .cbz: self = .cbz(try CBZArchive(data: data))
        case .cbt: self = .cbt(try CBTArchive(data: data))
        case .cb7, .cbr: self = .native(try NativeComicArchive(data: data, format: format))
        }
    }
    public var format: ComicArchiveFormat { switch self { case .cbz: .cbz; case .cbt: .cbt; case .native(let archive): archive.format } }
    public var data: Data { switch self { case .cbz(let archive): archive.data; case .cbt(let archive): archive.data; case .native(let archive): archive.data } }
    public var pages: [ComicPage] { switch self { case .cbz(let archive): archive.pages; case .cbt(let archive): archive.pages; case .native(let archive): archive.pages } }
    public func pagePNG(at index: Int) throws -> Data {
        switch self { case .cbz(let archive): try archive.pagePNG(at: index); case .cbt(let archive): try archive.pagePNG(at: index); case .native(let archive): try archive.pagePNG(at: index) }
    }
}
