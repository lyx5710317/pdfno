// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public struct CBTEntry: Sendable {
    public let path: String
    public let payload: Range<Int>
}
/// Original strict POSIX USTAR parser. No extraction, external process, decompressor or fallback.
public struct CBTArchive: Sendable {
    public let data: Data
    public let entries: [CBTEntry]
    public let pages: [ComicPage]
    public init(data: Data) throws {
        let entries = try Self.index(data)
        var pages: [ComicPage] = [], pixels = 0
        for entry in entries {
            try Task.checkCancellation()
            if let page = try CBZArchive.admit(data.subdata(in: entry.payload), path: entry.path) {
                pixels += page.width * page.height
                guard pixels <= ComicLimits.totalImagePixels else { throw ComicError.resourceLimit }
                pages.append(page)
            }
        }
        guard !pages.isEmpty else { throw ComicError.noPages }
        self.data = data; self.entries = entries
        self.pages = pages.sorted { ComicPageOrder.precedes($0.path, $1.path) }
    }
    public func pagePNG(at index: Int) throws -> Data {
        guard pages.indices.contains(index), let entry = entries.first(where: { $0.path == pages[index].path }) else { throw ComicError.sourceMismatch }
        return try CBZArchive.thumbnail(data.subdata(in: entry.payload))
    }
    public static func index(_ data: Data) throws -> [CBTEntry] {
        guard data.count <= ComicLimits.archiveBytes else { throw ComicError.resourceLimit }
        guard data.count >= 1024, data.count.isMultiple(of: 512) else { throw ComicError.invalidTAR }
        // Index the bounded input without creating a second archive-sized byte array.
        return try data.withUnsafeBytes { raw in
            let bytes = raw.bindMemory(to: UInt8.self)
            func text(_ offset: Int, _ length: Int) throws -> String {
                let field = bytes[offset..<(offset + length)]
                let end = field.firstIndex(of: 0) ?? field.endIndex
                guard field[end...].allSatisfy({ $0 == 0 }), let value = String(bytes: field[..<end], encoding: .utf8) else { throw ComicError.invalidTAR }
                return value
            }
            func octal(_ offset: Int, _ length: Int, emptyAllowed: Bool = false) throws -> Int {
                let field = Array(bytes[offset..<(offset + length)])
                var first = 0, end = field.count
                while first < end && (field[first] == 0 || field[first] == 32) { first += 1 }
                while end > first && (field[end - 1] == 0 || field[end - 1] == 32) { end -= 1 }
                guard first < end || emptyAllowed else { throw ComicError.invalidTAR }
                var value = 0
                for digit in field[first..<end] {
                    guard (48...55).contains(digit), value <= (Int.max - Int(digit - 48)) / 8 else { throw ComicError.invalidTAR }
                    value = value * 8 + Int(digit - 48)
                }
                return value
            }
            var offset = 0, total = 0, entries: [CBTEntry] = [], names = Set<String>()
            while offset + 512 <= bytes.count {
                try Task.checkCancellation()
                let header = bytes[offset..<(offset + 512)]
                if header.allSatisfy({ $0 == 0 }) {
                    // Two zero records terminate exactly one archive; any trailing records must also be zero.
                    guard bytes.count - offset >= 1024, bytes[offset...].allSatisfy({ $0 == 0 }) else { throw ComicError.invalidTAR }
                    return entries
                }
                guard entries.count < ComicLimits.entries else { throw ComicError.resourceLimit }
                guard Array(bytes[(offset + 257)..<(offset + 263)]) == Array("ustar\0".utf8),
                      Array(bytes[(offset + 263)..<(offset + 265)]) == Array("00".utf8),
                      bytes[(offset + 500)..<(offset + 512)].allSatisfy({ $0 == 0 }) else { throw ComicError.invalidTAR }
                let checksum = try octal(offset + 148, 8)
                let sum = header.enumerated().reduce(0) { $0 + ((148..<156).contains($1.offset) ? 32 : Int($1.element)) }
                guard checksum == sum else { throw ComicError.invalidTAR }
                let name = try text(offset, 100), prefix = try text(offset + 345, 155)
                let path = prefix.isEmpty ? name : prefix + "/" + name
                let type = bytes[offset + 156], isDirectory = type == 53
                guard !name.isEmpty, EPUBArchive.isSafePath(path),
                      names.insert(path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).precomposedStringWithCanonicalMapping.lowercased()).inserted,
                      [0, 48, 53].contains(type), try text(offset + 157, 100).isEmpty,
                      isDirectory || !path.hasSuffix("/") else { throw ComicError.invalidTAR }
                // Validate every numeric field, including ignored metadata. Base-256/GNU numbers are rejected.
                _ = try octal(offset + 100, 8); _ = try octal(offset + 108, 8); _ = try octal(offset + 116, 8)
                _ = try octal(offset + 136, 12)
                guard try octal(offset + 329, 8, emptyAllowed: true) == 0,
                      try octal(offset + 337, 8, emptyAllowed: true) == 0 else { throw ComicError.invalidTAR }
                _ = try text(offset + 265, 32); _ = try text(offset + 297, 32)
                let size = try octal(offset + 124, 12)
                guard !isDirectory || size == 0 else { throw ComicError.invalidTAR }
                guard size <= ComicLimits.entryBytes else { throw ComicError.resourceLimit }
                total += size; guard total <= ComicLimits.expandedBytes else { throw ComicError.resourceLimit }
                let start = offset + 512, padded = ((size + 511) / 512) * 512
                guard padded <= bytes.count - start,
                      bytes[(start + size)..<(start + padded)].allSatisfy({ $0 == 0 }) else { throw ComicError.invalidTAR }
                entries.append(CBTEntry(path: isDirectory && !path.hasSuffix("/") ? path + "/" : path, payload: start..<(start + size)))
                offset = start + padded
            }
            throw ComicError.invalidTAR
        }
    }
}
