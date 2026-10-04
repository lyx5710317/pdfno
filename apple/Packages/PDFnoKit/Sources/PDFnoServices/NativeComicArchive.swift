// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain
import PDFnoComicCodecs
import zlib

/// An in-memory, explicitly admitted 7z/RAR container. Only original input and page metadata persist.
/// Decompressed entries are consumed one at a time; only the displayed PNG thumbnails reach Kookit.
public struct NativeComicArchive: Sendable {
    public let data: Data
    public let format: ComicArchiveFormat
    public let pages: [ComicPage]
    public let decoderPeakBytes: Int
    private let decoderFormat: Int32
    private let memoryLimit: Int
    public init(data: Data, format: ComicArchiveFormat, workingMemoryLimit: Int = ComicLimits.decoderBytes) throws {
        guard workingMemoryLimit > 0, workingMemoryLimit <= ComicLimits.decoderBytes else { throw ComicError.resourceLimit }
        let decoderFormat = try ComicContainerProfile.validate(data, format: format)
        var pages: [ComicPage] = [], pixels = 0
        let peak = try Self.walk(data, decoderFormat: decoderFormat, limit: workingMemoryLimit) { path, bytes in
            if let page = try CBZArchive.admit(bytes, path: path) {
                pixels += page.width * page.height
                guard pixels <= ComicLimits.totalImagePixels else { throw ComicError.resourceLimit }
                pages.append(page)
            }
        }
        guard !pages.isEmpty else { throw ComicError.noPages }
        self.data = data; self.format = format; self.decoderFormat = decoderFormat; memoryLimit = workingMemoryLimit
        self.pages = pages.sorted { ComicPageOrder.precedes($0.path, $1.path) }; decoderPeakBytes = peak
    }
    public func pagePNG(at index: Int) throws -> Data {
        guard pages.indices.contains(index) else { throw ComicError.sourceMismatch }
        var selected: Data?
        // Reopen immutable input. No expanded-book cache; every preceding payload is bounded/checked again.
        _ = try Self.walk(data, decoderFormat: decoderFormat, limit: memoryLimit) { path, bytes in
            if path == pages[index].path { selected = try CBZArchive.thumbnail(bytes) }
        }
        guard let selected else { throw ComicError.sourceMismatch }; return selected
    }
    private static func checked(_ status: Int) throws {
        if status == -2 { throw ComicError.resourceLimit }
        if status < 0 { throw ComicError.invalidNativeArchive }
    }
    private static func walk(_ data: Data, decoderFormat: Int32, limit: Int, consume: (String, Data) throws -> Void) throws -> Int {
        try data.withUnsafeBytes { input in
            var status: Int32 = 0
            guard let decoder = pdfno_comic_open(input.baseAddress, input.count, decoderFormat, limit, &status) else {
                try checked(Int(status)); throw ComicError.invalidNativeArchive
            }
            defer { pdfno_comic_close(decoder) }
            var entry = PDFnoComicEntry(), count = 0, total = 0, names = Set<String>()
            var buffer = [UInt8](repeating: 0, count: 64 * 1024)
            while true {
                try Task.checkCancellation()
                let next = Int(pdfno_comic_next(decoder, &entry)); try checked(next)
                if next == 0 { break }
                count += 1; guard count <= ComicLimits.entries else { throw ComicError.resourceLimit }
                guard let pointer = entry.path, let name = String(validatingCString: pointer), name.utf8.count <= 1024,
                      EPUBArchive.isSafePath(name),
                      names.insert(name.trimmingCharacters(in: CharacterSet(charactersIn: "/")).precomposedStringWithCanonicalMapping.lowercased()).inserted else { throw ComicError.invalidNativeArchive }
                let size = Int(entry.size)
                guard size >= 0, size <= ComicLimits.entryBytes else { throw ComicError.resourceLimit }
                total += size; guard total <= ComicLimits.expandedBytes else { throw ComicError.resourceLimit }
                var bytes = Data(); bytes.reserveCapacity(size)
                while true {
                    try Task.checkCancellation()
                    let n = Int(buffer.withUnsafeMutableBytes { pdfno_comic_read(decoder, $0.baseAddress, $0.count) })
                    try checked(n); if n == 0 { break }
                    guard n <= buffer.count, n <= size - bytes.count else { throw ComicError.invalidNativeArchive }
                    bytes.append(contentsOf: buffer.prefix(n))
                }
                guard bytes.count == size, entry.directory == 0 || size == 0 else { throw ComicError.invalidNativeArchive }
                let path = entry.directory != 0 && !name.hasSuffix("/") ? name + "/" : name
                try consume(path, bytes)
            }
            guard count > 0 else { throw ComicError.noPages }
            return Int(pdfno_comic_peak(decoder))
        }
    }
}

/// Original strict envelope preflight prevents sniffing, SFX, concatenation, volumes and unsupported RAR headers.
enum ComicContainerProfile {
    static func validate(_ data: Data, format: ComicArchiveFormat) throws -> Int32 {
        guard data.startIndex == 0 else { throw ComicError.invalidNativeArchive }
        guard data.count <= ComicLimits.archiveBytes else { throw ComicError.resourceLimit }
        switch format {
        case .cb7: try sevenZip(data); return 7
        case .cbr:
            if data.starts(with: [0x52,0x61,0x72,0x21,0x1a,0x07,0]) { try rar4(data); return 4 }
            if data.starts(with: [0x52,0x61,0x72,0x21,0x1a,0x07,1,0]) { try rar5(data); return 5 }
            throw ComicError.invalidNativeArchive
        default: throw ComicError.invalidNativeArchive
        }
    }
    private static func crc(_ data: Data) -> UInt32 { data.withUnsafeBytes { UInt32(crc32(0, $0.bindMemory(to: UInt8.self).baseAddress, uInt($0.count))) } }
    private static func sevenZip(_ data: Data) throws {
        guard data.count >= 33, data.starts(with: [0x37,0x7a,0xbc,0xaf,0x27,0x1c]), data[6] == 0, data[7] == 4 else { throw ComicError.invalidNativeArchive }
        let r = Bytes(data)
        let offset = try r.integer(12, 8), length = try r.integer(20, 8)
        guard crc(data.subdata(in: 12..<32)) == UInt32(try r.integer(8, 4)),
              offset <= data.count - 32, length > 0, length <= ComicLimits.headerBytes,
              length == data.count - 32 - offset else { throw ComicError.invalidNativeArchive }
        let start = 32 + offset
        // Encoded headers are closed until separately budgeted/admitted. Payload LZMA remains supported.
        guard data[start] == 1, crc(data.subdata(in: start..<data.count)) == UInt32(try r.integer(28, 4)) else { throw ComicError.invalidNativeArchive }
    }
    private static func rar4(_ data: Data) throws {
        let r = Bytes(data); var p = 7, main = false, count = 0, total = 0
        while p < data.count {
            try Task.checkCancellation()
            let size = try r.integer(p + 5, 2), flags = try r.integer(p + 3, 2), type = try r.integer(p + 2, 1)
            guard size >= 7, size <= data.count - p,
                  Int(crc(data.subdata(in: (p + 2)..<(p + size))) & 0xffff) == (try r.integer(p, 2)) else { throw ComicError.invalidNativeArchive }
            if type == 0x73 {
                guard !main, p == 7, size == 13, flags == 0 || flags == 0x10 else { throw ComicError.invalidNativeArchive }
                main = true; p += size
            } else if type == 0x74 {
                guard main, size >= 32, flags == 0x8000, try r.integer(p + 24, 1) == 29,
                      try r.integer(p + 25, 1) == 0x30 else { throw ComicError.invalidNativeArchive }
                let packed = try r.integer(p + 7, 4), unpacked = try r.integer(p + 11, 4), nameSize = try r.integer(p + 26, 2)
                let host = try r.integer(p + 15, 1), attributes = try r.integer(p + 28, 4)
                guard packed == unpacked, nameSize > 0, nameSize <= 1024, size == 32 + nameSize,
                      packed <= data.count - p - size, [0,3].contains(host),
                      ((host == 0 && attributes & 0x10 == 0) || (host == 3 && attributes & 0xf000 == 0x8000)),
                      data[(p + 32)..<(p + size)].allSatisfy({ $0 > 0 && $0 < 128 }),
                      let name = String(data: data.subdata(in: (p + 32)..<(p + size)), encoding: .ascii), EPUBArchive.isSafePath(name) else { throw ComicError.invalidNativeArchive }
                count += 1; total += unpacked; try budget(count: count, size: unpacked, total: total)
                guard crc(data.subdata(in: (p + size)..<(p + size + packed))) == UInt32(try r.integer(p + 16, 4)) else { throw ComicError.invalidNativeArchive }
                p += size + packed
            } else if type == 0x7b {
                guard main, size == 7, flags == 0, p + size == data.count else { throw ComicError.invalidNativeArchive }; return
            } else { throw ComicError.invalidNativeArchive }
        }
        throw ComicError.invalidNativeArchive
    }
    private static func rar5(_ data: Data) throws {
        let r = Bytes(data); var p = 8, main = false, count = 0, total = 0
        while p < data.count {
            try Task.checkCancellation()
            let start = p; let expectedCRC = try r.integer(p, 4); p += 4
            let headerSize = try r.variable(&p, end: data.count), body = p
            guard headerSize <= ComicLimits.headerBytes, headerSize > 0, headerSize <= data.count - p else { throw ComicError.invalidNativeArchive }
            let end = p + headerSize
            guard crc(data.subdata(in: (start + 4)..<end)) == UInt32(expectedCRC) else { throw ComicError.invalidNativeArchive }
            let type = try r.variable(&p, end: end), flags = try r.variable(&p, end: end)
            if type == 1 {
                guard !main, start == 8, flags == 0, try r.variable(&p, end: end) == 0, p == end else { throw ComicError.invalidNativeArchive }
                main = true; p = end
            } else if type == 2 {
                guard main, flags == 2 else { throw ComicError.invalidNativeArchive } // no extras/splits/encryption
                let packed = try r.variable(&p, end: end), fileFlags = try r.variable(&p, end: end)
                let size = try r.variable(&p, end: end), attributes = try r.variable(&p, end: end)
                guard fileFlags == 4 || fileFlags == 6, packed == size, packed <= data.count - end else { throw ComicError.invalidNativeArchive }
                if fileFlags == 6 { _ = try r.integer(p, 4); p += 4 }
                let fileCRC = try r.integer(p, 4); p += 4
                let compression = try r.variable(&p, end: end), host = try r.variable(&p, end: end)
                let nameSize = try r.variable(&p, end: end)
                guard compression == 0, [0,1].contains(host), nameSize > 0, nameSize <= 1024, nameSize == end - p,
                      (host == 0 && attributes & 0x10 == 0) || (host == 1 && attributes & 0xf000 == 0x8000),
                      let name = String(data: data.subdata(in: p..<end), encoding: .utf8), EPUBArchive.isSafePath(name) else { throw ComicError.invalidNativeArchive }
                count += 1; total += size; try budget(count: count, size: size, total: total)
                guard crc(data.subdata(in: end..<(end + packed))) == UInt32(fileCRC) else { throw ComicError.invalidNativeArchive }
                p = end + packed
            } else if type == 5 {
                guard main, flags == 0, try r.variable(&p, end: end) == 0, p == end, end == data.count else { throw ComicError.invalidNativeArchive }; return
            } else { throw ComicError.invalidNativeArchive }
            guard p > body else { throw ComicError.invalidNativeArchive }
        }
        throw ComicError.invalidNativeArchive
    }
    private static func budget(count: Int, size: Int, total: Int) throws {
        guard count <= ComicLimits.entries, size <= ComicLimits.entryBytes, total <= ComicLimits.expandedBytes else { throw ComicError.resourceLimit }
    }
    private struct Bytes {
        let data: Data
        init(_ data: Data) { self.data = data }
        func integer(_ offset: Int, _ width: Int) throws -> Int {
            guard offset >= 0, width > 0, width <= 8, offset <= data.count - width else { throw ComicError.invalidNativeArchive }
            var result: UInt64 = 0
            for i in 0..<width { result |= UInt64(data[offset + i]) << (i * 8) }
            guard result <= UInt64(Int.max) else { throw ComicError.invalidNativeArchive }; return Int(result)
        }
        func variable(_ offset: inout Int, end: Int) throws -> Int {
            var result: UInt64 = 0
            for i in 0..<9 {
                guard offset < end else { throw ComicError.invalidNativeArchive }
                let byte = data[offset]; offset += 1; result |= UInt64(byte & 0x7f) << (i * 7)
                if byte & 0x80 == 0 {
                    guard (i == 0 || byte != 0), result <= UInt64(Int.max) else { throw ComicError.invalidNativeArchive }; return Int(result)
                }
            }
            throw ComicError.invalidNativeArchive
        }
    }
}
