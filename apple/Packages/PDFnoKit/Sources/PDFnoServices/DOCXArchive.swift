// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import zlib
import PDFnoDomain

/// A bounded read-only ZIP profile. No entries are extracted to the filesystem.
struct DOCXArchive {
    struct Entry {
        let name: String
        let method: Int
        let crc: UInt32
        let expanded: Int
        let payload: Range<Int>
    }
    private let bytes: [UInt8]
    let entries: [String: Entry]
    static let entryLimit = 4 * 1024 * 1024

    init(_ data: Data) throws {
        guard data.count <= 20 * 1024 * 1024 else { throw ConversionError.resourceLimit }
        let b = Array(data)
        guard b.count >= 22 else { throw ConversionError.invalidArchive }
        func u16(_ p: Int) -> Int { Int(b[p]) | Int(b[p + 1]) << 8 }
        func u32(_ p: Int) -> Int { u16(p) | u16(p + 2) << 16 }
        guard let end = stride(from: b.count - 22, through: max(0, b.count - 65557), by: -1).first(where: {
            u32($0) == 0x06054b50 && $0 + 22 + u16($0 + 20) == b.count
        }), u16(end + 4) == 0, u16(end + 6) == 0, u16(end + 8) == u16(end + 10) else { throw ConversionError.invalidArchive }
        let count = u16(end + 10), start = u32(end + 16)
        guard count > 0, count <= 1000 else { throw ConversionError.resourceLimit }
        guard start + u32(end + 12) == end else { throw ConversionError.invalidArchive }
        var p = start, total = 0, found: [String: Entry] = [:], names = Set<String>(), ranges: [Range<Int>] = []
        for _ in 0..<count {
            try Task.checkCancellation()
            guard p + 46 <= end, u32(p) == 0x02014b50 else { throw ConversionError.invalidArchive }
            let flags = u16(p + 8), method = u16(p + 10), crc = u32(p + 16), compressed = u32(p + 20), expanded = u32(p + 24)
            let n = u16(p + 28), extra = u16(p + 30), comment = u16(p + 32), local = u32(p + 42)
            guard p + 46 + n + extra + comment <= end, n > 0, flags & ~0x0808 == 0,
                  method == 0 || method == 8, u16(p + 6) <= 20, u16(p + 34) == 0,
                  (u32(p + 38) >> 16) & 0xf000 != 0xa000,
                  let name = String(bytes: b[(p + 46)..<(p + 46 + n)], encoding: .utf8), EPUBArchive.isSafePath(name),
                  names.insert(name.precomposedStringWithCanonicalMapping.lowercased()).inserted else { throw ConversionError.invalidArchive }
            guard expanded <= Self.entryLimit, compressed <= b.count else { throw ConversionError.resourceLimit }
            total += expanded; guard total <= 50 * 1024 * 1024 else { throw ConversionError.resourceLimit }
            guard local + 30 <= start, u32(local) == 0x04034b50, u16(local + 4) <= 20,
                  u16(local + 6) == flags, u16(local + 8) == method, u16(local + 26) == n else { throw ConversionError.invalidArchive }
            let payload = local + 30 + n + u16(local + 28), payloadEnd = payload + compressed
            guard payload <= start, payloadEnd <= start,
                  Array(b[(local + 30)..<(local + 30 + n)]) == Array(b[(p + 46)..<(p + 46 + n)]),
                  flags & 8 != 0 || (u32(local + 14) == crc && u32(local + 18) == compressed && u32(local + 22) == expanded) else {
                throw ConversionError.invalidArchive
            }
            var rangeEnd = payloadEnd
            if flags & 8 != 0 {
                guard payloadEnd + 12 <= start else { throw ConversionError.invalidArchive }
                let descriptor = payloadEnd + (u32(payloadEnd) == 0x08074b50 ? 4 : 0)
                guard descriptor + 12 <= start, u32(descriptor) == crc, u32(descriptor + 4) == compressed,
                      u32(descriptor + 8) == expanded else { throw ConversionError.invalidArchive }
                rangeEnd = descriptor + 12
            }
            let range = local..<rangeEnd
            guard !ranges.contains(where: { $0.overlaps(range) }) else { throw ConversionError.invalidArchive }
            ranges.append(range)
            if name.lowercased().hasSuffix("vbaproject.bin") { throw ConversionError.unsupportedDocument }
            found[name] = Entry(name: name, method: method, crc: UInt32(crc), expanded: expanded, payload: payload..<payloadEnd)
            p += 46 + n + extra + comment
        }
        guard p == end else { throw ConversionError.invalidArchive }
        bytes = b; entries = found
    }

    func read(_ name: String) throws -> Data {
        guard let entry = entries[name] else { throw ConversionError.invalidDocument }
        try Task.checkCancellation()
        let compressed = Array(bytes[entry.payload])
        let output: Data
        if entry.method == 0 { output = Data(compressed) }
        else {
            var stream = z_stream()
            guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else {
                throw ConversionError.invalidArchive
            }
            defer { inflateEnd(&stream) }
            output = try compressed.withUnsafeBufferPointer { input in
                stream.next_in = UnsafeMutablePointer(mutating: input.baseAddress)
                stream.avail_in = uInt(input.count)
                var result = Data(), chunk = [UInt8](repeating: 0, count: 32 * 1024)
                while true {
                    try Task.checkCancellation()
                    let status = chunk.withUnsafeMutableBufferPointer { buffer in
                        stream.next_out = buffer.baseAddress; stream.avail_out = uInt(buffer.count)
                        return inflate(&stream, Z_NO_FLUSH)
                    }
                    let produced = chunk.count - Int(stream.avail_out)
                    guard result.count + produced <= Self.entryLimit else { throw ConversionError.resourceLimit }
                    result.append(contentsOf: chunk.prefix(produced))
                    if status == Z_STREAM_END {
                        guard stream.avail_in == 0 else { throw ConversionError.invalidArchive }
                        break
                    }
                    guard status == Z_OK, produced > 0 else { throw ConversionError.invalidArchive }
                }
                return result
            }
        }
        guard output.count == entry.expanded else { throw ConversionError.invalidArchive }
        let checksum = output.withUnsafeBytes { raw in crc32(0, raw.bindMemory(to: Bytef.self).baseAddress, uInt(raw.count)) }
        guard UInt32(checksum) == entry.crc else { throw ConversionError.invalidArchive }
        return output
    }
}
