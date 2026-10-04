// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Validate bytes before untrusted data enters the fixed parser. No DRM or resource decoding.
public enum EbookPreflight {
    public static func validate(_ data: Data, format: EbookFormat) throws -> EbookContentKind {
        guard !data.isEmpty, data.count <= 8 * 1024 * 1024 else { throw EbookError.resourceLimit }
        if format == .fb2 { try validateFB2(data); return .fb2 }
        let b = Array(data)
        func u16(_ p: Int) -> Int { Int(b[p]) << 8 | Int(b[p + 1]) }
        func u32(_ p: Int) -> Int { u16(p) << 16 | u16(p + 2) }
        guard b.count >= 78, String(bytes: b[60..<68], encoding: .ascii) == "BOOKMOBI" else { throw EbookError.invalidDocument }
        let count = u16(76)
        guard (2...1000).contains(count), 78 + count * 8 + 2 <= b.count else { throw EbookError.resourceLimit }
        var offsets: [Int] = []
        for i in 0..<count {
            let offset = u32(78 + i * 8)
            guard offset >= 78 + count * 8 + 2, offset < b.count,
                  offsets.last.map({ offset > $0 }) ?? true else { throw EbookError.invalidDocument }
            offsets.append(offset)
        }
        offsets.append(b.count)
        let r = offsets[0], size = offsets[1] - r
        guard size >= 264, String(bytes: b[(r + 16)..<(r + 20)], encoding: .ascii) == "MOBI" else { throw EbookError.invalidDocument }
        guard u16(r + 12) == 0 else { throw EbookError.drm }
        let compression = u16(r), n = u16(r + 8), textLength = u32(r + 4), headerLength = u32(r + 20), version = u32(r + 36)
        guard compression == 1 || compression == 2 else { throw EbookError.unsupportedContent }
        guard version == 6 || version == 8, format != .azw3 || version == 8,
              [1252, 65001].contains(u32(r + 28)), u32(r + 24) == 2,
              (248...512).contains(headerLength), 16 + headerLength <= size,
              u32(r + 240) == 0, u32(r + 244) == 0xffffffff else { throw EbookError.unsupportedContent }
        guard (1..<count).contains(n), (1...4 * 1024 * 1024).contains(textLength),
              (1...4096).contains(u16(r + 10)) else { throw EbookError.resourceLimit }
        let title = u32(r + 84), titleLength = u32(r + 88)
        guard title >= 16 + headerLength, titleLength <= 4096, title <= size - titleLength else { throw EbookError.invalidDocument }
        if u32(r + 128) & 64 != 0 {
            let p = r + 16 + headerLength
            guard p + 12 <= offsets[1], String(bytes: b[p..<(p + 4)], encoding: .ascii) == "EXTH" else { throw EbookError.invalidDocument }
            let length = u32(p + 4), entries = u32(p + 8)
            guard length >= 12, p + length <= offsets[1], entries <= 1000 else { throw EbookError.resourceLimit }
            var q = p + 12
            for _ in 0..<entries {
                guard q + 8 <= p + length else { throw EbookError.invalidDocument }
                let type = u32(q), size = u32(q + 4)
                guard size >= 8, q + size <= p + length else { throw EbookError.invalidDocument }
                // Combo boundaries and fixed-layout/media structures are outside this reflow slice.
                guard ![121, 122, 125, 126, 132].contains(type) else { throw EbookError.unsupportedContent }
                q += size
            }
            guard q <= p + length else { throw EbookError.invalidDocument }
        } else if version == 8 { throw EbookError.invalidDocument }
        var actual = 0
        for i in 1...n {
            let bytes = Array(b[offsets[i]..<offsets[i + 1]])
            guard bytes.count <= 64 * 1024 else { throw EbookError.resourceLimit }
            let expanded = compression == 1 ? bytes : try palmDOC(bytes)
            guard expanded.count <= 4096 else { throw EbookError.resourceLimit }
            actual += expanded.count
        }
        guard actual == textLength else { throw EbookError.invalidDocument }
        // Only index records are admitted to the upstream INDX reader; count, masks and offsets
        // are checked here, and variable-length values/semantic ranges are checked in JS.
        for i in (n + 1)..<count where offsets[i + 1] - offsets[i] >= 4 && String(bytes: b[offsets[i]..<(offsets[i] + 4)], encoding: .ascii) == "INDX" {
            let p = offsets[i], end = offsets[i + 1]
            guard end - p >= 56 else { throw EbookError.invalidDocument }
            let length = u32(p + 4), records = u32(p + 24), cncx = u32(p + 52)
            guard length >= 56, p + length <= end, records <= 1000, cncx <= 1000 else { throw EbookError.resourceLimit }
            let tag = p + length
            if tag + 12 <= end, String(bytes: b[tag..<(tag + 4)], encoding: .ascii) == "TAGX" {
                let length = u32(tag + 4), controls = u32(tag + 8)
                guard length >= 12, length <= 1024, (length - 12) % 4 == 0, tag + length <= end, (1...8).contains(controls) else { throw EbookError.invalidDocument }
                for q in stride(from: tag + 12, to: tag + length, by: 4) {
                    guard (1...8).contains(Int(b[q + 1])), b[q + 2] > 0 else { throw EbookError.invalidDocument }
                }
            } else {
                let idxt = p + u32(p + 20)
                guard idxt >= p + length, idxt + 4 + records * 2 <= end,
                      String(bytes: b[idxt..<(idxt + 4)], encoding: .ascii) == "IDXT" else { throw EbookError.invalidDocument }
                for j in 0..<records {
                    let entry = p + u16(idxt + 4 + j * 2)
                    guard entry >= p + length, entry < idxt, entry + 1 + Int(b[entry]) < idxt else { throw EbookError.invalidDocument }
                }
            }
        }
        if version == 8 {
            guard u32(r + 260) == 0xffffffff, headerLength >= 264 else { throw EbookError.invalidDocument }
            for field in [248, 252] {
                let i = u32(r + field)
                guard i > n, i < count, offsets[i + 1] - offsets[i] >= 56,
                      String(bytes: b[offsets[i]..<(offsets[i] + 4)], encoding: .ascii) == "INDX" else { throw EbookError.invalidDocument }
            }
        }
        return version == 8 ? .kf8 : .mobi6
    }
    private static func palmDOC(_ b: [UInt8]) throws -> [UInt8] {
        var out: [UInt8] = [], i = 0
        while i < b.count {
            let x = Int(b[i]); i += 1
            if x == 0 { out.append(0) }
            else if x <= 8 {
                guard i + x <= b.count else { throw EbookError.invalidDocument }; out.append(contentsOf: b[i..<(i + x)]); i += x
            } else if x <= 127 { out.append(UInt8(x)) }
            else if x <= 191 {
                guard i < b.count else { throw EbookError.invalidDocument }
                let pair = x << 8 | Int(b[i]); i += 1
                let distance = (pair & 0x3fff) >> 3, length = (pair & 7) + 3
                guard distance > 0, distance <= out.count else { throw EbookError.invalidDocument }
                for _ in 0..<length { out.append(out[out.count - distance]) }
            } else { out.append(32); out.append(UInt8(x ^ 128)) }
            guard out.count <= 4096 else { throw EbookError.resourceLimit }
        }
        return out
    }
    private static func validateFB2(_ data: Data) throws {
        guard let text = String(data: data, encoding: .utf8), !text.contains("\0"),
              text.range(of: "<!DOCTYPE|<!ENTITY", options: [.regularExpression, .caseInsensitive]) == nil,
              text.range(of: "encoding\\s*=\\s*[\"'](?!utf-8[\"'])", options: [.regularExpression, .caseInsensitive]) == nil else { throw EbookError.unsupportedContent }
        let delegate = FB2Validation(); let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true; parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        guard parser.parse(), delegate.valid, delegate.body, delegate.depth == 0 else { throw EbookError.invalidDocument }
    }
}
private final class FB2Validation: NSObject, XMLParserDelegate {
    var valid = true, body = false, depth = 0, nodes = 0, sections = 0, bodies = 0
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        depth += 1; nodes += 1
        if depth == 1 && (name != "FictionBook" || namespaceURI != "http://www.gribuser.ru/xml/fictionbook/2.0") { valid = false }
        if name == "body" {
            bodies += 1; if depth == 2 { body = true } else { valid = false }
        }
        if depth == 3 { sections += 1 }
        if name == "binary" { valid = false }
        if sections > 1000 || bodies > 1000 { valid = false; parser.abortParsing() }
        if depth > 48 || nodes > 100000 { valid = false; parser.abortParsing() }
    }
    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) { depth -= 1 }
}
