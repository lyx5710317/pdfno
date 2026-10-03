// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain
import PDFnoDOCXZIP

/// ZIP32 only; CRC/consumed input/actual output are verified before any XML reaches WebKit.
/// Entries are read in memory, never extracted to a filesystem path.
enum DOCXArchive {
    static func read(_ data: Data) throws -> [String: Data] {
        guard data.count <= 20 * 1024 * 1024 else { throw DOCXError.resourceLimit }
        let b = Array(data)
        guard b.count >= 22 else { throw DOCXError.invalidArchive }
        func u16(_ p: Int) -> Int { Int(b[p]) | Int(b[p + 1]) << 8 }
        func u32(_ p: Int) -> Int { u16(p) | u16(p + 2) << 16 }
        guard let end = stride(from: b.count - 22, through: max(0, b.count - 65557), by: -1).first(where: {
            u32($0) == 0x06054b50 && $0 + 22 + u16($0 + 20) == b.count
        }), u16(end + 4) == 0, u16(end + 6) == 0, u16(end + 8) == u16(end + 10) else { throw DOCXError.invalidArchive }
        let count = u16(end + 10), centralSize = u32(end + 12), centralStart = u32(end + 16)
        guard count > 0, count <= 1000 else { throw DOCXError.resourceLimit }
        guard centralStart + centralSize == end else { throw DOCXError.invalidArchive }
        func checkExtra(_ start: Int, _ size: Int) throws {
            var p = start
            while p < start + size {
                guard p + 4 <= start + size, u16(p) != 1, p + 4 + u16(p + 2) <= start + size else { throw DOCXError.invalidArchive }
                p += 4 + u16(p + 2)
            }
        }
        var p = centralStart, total = 0, names = Set<String>(), ranges: [Range<Int>] = [], result: [String: Data] = [:]
        for _ in 0..<count {
            guard p + 46 <= end, u32(p) == 0x02014b50, u16(p + 6) <= 20 else { throw DOCXError.invalidArchive }
            let flags = u16(p + 8), method = u16(p + 10), crc = u32(p + 16)
            let compressed = u32(p + 20), expanded = u32(p + 24), n = u16(p + 28)
            let extra = u16(p + 30), comment = u16(p + 32), local = u32(p + 42)
            guard n > 0, p + 46 + n + extra + comment <= end, flags & ~0x0808 == 0,
                  [0, 8].contains(method), u16(p + 34) == 0,
                  ![0xa000, 0x6000, 0x2000, 0x1000].contains((u32(p + 38) >> 16) & 0xf000),
                  let name = String(bytes: b[(p + 46)..<(p + 46 + n)], encoding: .utf8), EPUBArchive.isSafePath(name),
                  names.insert(name.precomposedStringWithCanonicalMapping.lowercased()).inserted else { throw DOCXError.invalidArchive }
            let lower = name.lowercased()
            guard !lower.contains("vbaproject"), !lower.hasPrefix("word/embeddings/"),
                  !["js", "html", "htm", "exe", "dll", "wasm"].contains(URL(fileURLWithPath: lower).pathExtension) else { throw DOCXError.unsupportedContent }
            guard expanded <= 4 * 1024 * 1024, compressed <= data.count,
                  expanded <= max(1024 * 1024, compressed * 1000) else { throw DOCXError.resourceLimit }
            total += expanded; guard total <= 50 * 1024 * 1024 else { throw DOCXError.resourceLimit }
            try checkExtra(p + 46 + n, extra)
            guard local + 30 <= centralStart, u32(local) == 0x04034b50, u16(local + 4) <= 20,
                  u16(local + 6) == flags, u16(local + 8) == method, u16(local + 26) == n else { throw DOCXError.invalidArchive }
            let localExtra = u16(local + 28), payload = local + 30 + n + localExtra
            guard payload <= centralStart, payload + compressed <= centralStart,
                  b[(local + 30)..<(local + 30 + n)].elementsEqual(b[(p + 46)..<(p + 46 + n)]) else { throw DOCXError.invalidArchive }
            try checkExtra(local + 30 + n, localExtra)
            var finish = payload + compressed
            if flags & 8 == 0 {
                guard u32(local + 14) == crc, u32(local + 18) == compressed, u32(local + 22) == expanded else { throw DOCXError.invalidArchive }
            } else {
                guard finish + 12 <= centralStart else { throw DOCXError.invalidArchive }
                if u32(finish) == 0x08074b50 { finish += 4 }
                guard finish + 12 <= centralStart, u32(finish) == crc,
                      u32(finish + 4) == compressed, u32(finish + 8) == expanded else { throw DOCXError.invalidArchive }
                finish += 12
            }
            ranges.append(local..<finish)
            let input = Array(b[payload..<(payload + compressed)])
            var output: [UInt8]
            if method == 0 {
                guard compressed == expanded else { throw DOCXError.invalidArchive }; output = input
            } else {
                output = [UInt8](repeating: 0, count: expanded)
                let valid = input.withUnsafeBufferPointer { source in
                    output.withUnsafeMutableBufferPointer { destination in
                        pdfno_docx_inflate(source.baseAddress, source.count, destination.baseAddress, destination.count)
                    }
                }
                guard valid == 1 else { throw DOCXError.invalidArchive }
            }
            guard output.withUnsafeBufferPointer({ pdfno_docx_crc($0.baseAddress, $0.count) }) == UInt32(crc),
                  !name.hasSuffix("/") || expanded == 0 else { throw DOCXError.invalidArchive }
            result[name] = Data(output); p += 46 + n + extra + comment
        }
        guard p == end else { throw DOCXError.invalidArchive }
        // Reject overlaps, hidden local entries, executable prefixes and descriptor ambiguity.
        var last = 0
        for range in ranges.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            guard range.lowerBound == last else { throw DOCXError.invalidArchive }; last = range.upperBound
        }
        guard last == centralStart, result["[Content_Types].xml"] != nil, result["_rels/.rels"] != nil,
              result["word/document.xml"] != nil else { throw DOCXError.invalidArchive }
        return result
    }
}
