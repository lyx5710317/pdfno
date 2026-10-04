// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Restricted RFC 2557 input adapter. No resource URL is loaded or installed, and no
/// mhtml2html/browser archive API is involved. Preserve the entire original externally.
enum MHTMLArchive {
    private struct Part { let headers: [String: String]; let type: String; let parameters: [String: String]; let body: Data }
    static func decode(_ data: Data) throws -> DecodedTextFile {
        guard !data.isEmpty, data.count <= 4 * 1024 * 1024 else { throw TextFormatError.resourceLimit }
        // One-to-one byte view, independent of the HTML part's character encoding.
        let source = String(String.UnicodeScalarView(data.map { UnicodeScalar($0) }))
        let (headers, body) = try entity(source)
        guard headers["mime-version"] == "1.0", headers["content-transfer-encoding"] == nil,
              headers["content-disposition"] == nil else { throw TextFormatError.unsupportedContent }
        let (type, parameters) = try contentType(headers["content-type"])
        guard type == "multipart/related", Set(parameters.keys).isSubset(of: ["boundary", "type", "start"]),
              parameters["type"] == nil || parameters["type"]?.lowercased() == "text/html",
              let boundary = parameters["boundary"], boundary.range(of: #"^[A-Za-z0-9'()+_,./:=?-]{1,70}$"#, options: .regularExpression) != nil else {
            throw TextFormatError.unsupportedContent
        }
        let chunks = try split(body, boundary: boundary)
        var parts: [Part] = [], total = 0
        for chunk in chunks {
            try Task.checkCancellation()
            let (partHeaders, payload) = try entity(chunk)
            let (partType, partParameters) = try contentType(partHeaders["content-type"])
            guard Set(partParameters.keys).isSubset(of: ["charset"]),
                  ["text/html", "text/css", "image/png", "image/jpeg"].contains(partType),
                  partHeaders["content-disposition"] == nil || partHeaders["content-disposition"]?.lowercased() == "inline" else {
                throw TextFormatError.unsupportedContent
            }
            let decoded = try transfer(payload, encoding: partHeaders["content-transfer-encoding"] ?? "7bit")
            total += decoded.count
            guard !decoded.isEmpty, decoded.count <= 1024 * 1024, total <= 4 * 1024 * 1024 else { throw TextFormatError.resourceLimit }
            if partType == "image/png" {
                guard partParameters.isEmpty, decoded.starts(with: [137,80,78,71,13,10,26,10]) else { throw TextFormatError.unsupportedContent }
            } else if partType == "image/jpeg" {
                guard partParameters.isEmpty, decoded.starts(with: [255,216,255]) else { throw TextFormatError.unsupportedContent }
            }
            parts.append(Part(headers: partHeaders, type: partType, parameters: partParameters, body: decoded))
        }
        var ids: [String: Int] = [:]
        for (index, part) in parts.enumerated() {
            if let rawID = part.headers["content-id"] {
                let id = try contentID(rawID)
                guard ids.updateValue(index, forKey: id) == nil else { throw TextFormatError.unsupportedContent }
            }
        }
        let root: Int
        if let start = parameters["start"] {
            guard let index = ids[try contentID(start)] else { throw TextFormatError.unsupportedContent }; root = index
        } else { root = 0 }
        guard parts[root].type == "text/html", parts.filter({ $0.type == "text/html" }).count == 1 else { throw TextFormatError.unsupportedContent }
        // Map identities to detect ambiguous duplicate locations; mapping never grants resource access.
        let base = try location(parts[root].headers["content-location"] ?? "https://pdfno.invalid/archive/index.html", base: nil)
        var locations = Set<String>()
        for part in parts {
            if let raw = part.headers["content-location"] {
                guard locations.insert(try location(raw, base: base).absoluteString).inserted else { throw TextFormatError.unsupportedContent }
            }
        }
        var html: DecodedTextFile?
        for (index, part) in parts.enumerated() where part.type.hasPrefix("text/") {
            let decoded = try text(part.body, charset: part.parameters["charset"])
            if index == root {
                html = try TextFileDecoder.decode(part.body, format: .html)
                // MIME charset and actual bytes are both authoritative; no heuristic/fallback.
                guard html?.text.utf16.elementsEqual(decoded.text.utf16) == true else { throw TextFormatError.encoding }
            }
        }
        guard let html else { throw TextFormatError.unsupportedContent }
        return DecodedTextFile(text: html.text, encoding: html.encoding, engineFormat: .html, warnings: [
            "MHTML 仅显示一个离线 HTML 正文；归档图片、CSS、字体、链接与外部原页面均不加载。",
            "MHTML 仅支持平面 multipart/related、7bit／8bit／base64／quoted-printable 和严格 UTF-8／BOM UTF-16；其他 part 会被拒绝。"
        ])
    }
    private static func entity(_ source: String) throws -> ([String: String], String) {
        // Prefer the earliest header/body separator; CRLF and LF archives are accepted.
        let separators = [source.range(of: "\r\n\r\n"), source.range(of: "\n\n")].compactMap { $0 }
        guard let separator = separators.min(by: { $0.lowerBound < $1.lowerBound }) else { throw TextFormatError.unsupportedContent }
        let raw = String(source[..<separator.lowerBound])
        guard raw.utf16.count <= 65536 else { throw TextFormatError.resourceLimit }
        let lines = raw.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false)
        var fields: [String] = []
        for line in lines {
            guard line.utf16.count <= 998, line.unicodeScalars.allSatisfy({ ($0.value >= 32 && $0.value < 127) || $0.value == 9 }) else { throw TextFormatError.unsupportedContent }
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                guard !fields.isEmpty else { throw TextFormatError.unsupportedContent }
                fields[fields.count - 1] += " " + line.trimmingCharacters(in: .whitespaces)
            } else { fields.append(String(line)) }
            guard fields.count <= 128 else { throw TextFormatError.resourceLimit }
        }
        var headers: [String: String] = [:]
        for field in fields {
            guard let colon = field.firstIndex(of: ":") else { throw TextFormatError.unsupportedContent }
            let name = String(field[..<colon]).lowercased()
            guard name.range(of: #"^[a-z0-9-]+$"#, options: .regularExpression) != nil,
                  headers[name] == nil else { throw TextFormatError.unsupportedContent }
            if name.hasPrefix("content-") && !["content-type", "content-transfer-encoding", "content-location", "content-id", "content-disposition"].contains(name) {
                throw TextFormatError.unsupportedContent
            }
            headers[name] = field[field.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        }
        return (headers, String(source[separator.upperBound...]))
    }
    private static func contentType(_ raw: String?) throws -> (String, [String: String]) {
        guard let raw else { throw TextFormatError.unsupportedContent }
        // Small strict quoted-parameter lexer. Escaped quotes/comments/RFC2231 continuations
        // and duplicate parameters are outside this profile, never repaired heuristically.
        var chunks: [String] = [], current = "", quoted = false
        for c in raw {
            guard c != "\\" else { throw TextFormatError.unsupportedContent }
            if c == "\"" { quoted.toggle(); current.append(c) }
            else if c == ";" && !quoted { chunks.append(current); current = "" }
            else { current.append(c) }
        }
        guard !quoted else { throw TextFormatError.unsupportedContent }; chunks.append(current)
        let type = chunks.removeFirst().trimmingCharacters(in: .whitespaces).lowercased()
        guard type.range(of: #"^[a-z0-9.+-]+/[a-z0-9.+-]+$"#, options: .regularExpression) != nil else { throw TextFormatError.unsupportedContent }
        var parameters: [String: String] = [:]
        for chunk in chunks {
            guard let equals = chunk.firstIndex(of: "=") else { throw TextFormatError.unsupportedContent }
            let key = chunk[..<equals].trimmingCharacters(in: .whitespaces).lowercased()
            var value = chunk[chunk.index(after: equals)...].trimmingCharacters(in: .whitespaces)
            guard key.range(of: #"^[a-z0-9-]+$"#, options: .regularExpression) != nil, parameters[key] == nil, !value.isEmpty else { throw TextFormatError.unsupportedContent }
            if value.hasPrefix("\"") && value.hasSuffix("\"") { value = String(value.dropFirst().dropLast()) }
            else { guard value.range(of: #"^[A-Za-z0-9!#$%&'*+.^_`|~/-]+$"#, options: .regularExpression) != nil else { throw TextFormatError.unsupportedContent } }
            guard !value.isEmpty, !value.contains("\"") else { throw TextFormatError.unsupportedContent }
            parameters[key] = value
        }
        return (type, parameters)
    }
    private static func split(_ source: String, boundary: String) throws -> [String] {
        let lines = source.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        let marker = "--" + boundary
        var parts: [String] = [], current: [String] = [], started = false, closed = false
        for line in lines {
            try Task.checkCancellation()
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Delimiters must begin at column zero; optional trailing transport padding only.
            let delimiter = line.hasPrefix(marker) && (trimmed == marker || trimmed == marker + "--")
            if delimiter {
                guard !closed else { throw TextFormatError.unsupportedContent }
                if started {
                    guard parts.count < 64 else { throw TextFormatError.resourceLimit }
                    parts.append(current.joined(separator: "\n")); current = []
                }
                started = true
                if trimmed == marker + "--" { closed = true }
            } else if !started || closed {
                guard trimmed.isEmpty else { throw TextFormatError.unsupportedContent } // bounded strict empty preamble/epilogue
            } else { current.append(line) }
        }
        guard closed, !parts.isEmpty else { throw TextFormatError.unsupportedContent }
        return parts
    }
    private static func transfer(_ payload: String, encoding: String) throws -> Data {
        let bytes = payload.utf16.map { UInt8($0) }
        switch encoding.lowercased() {
        case "7bit", "8bit":
            guard !bytes.contains(where: { $0 < 32 && ![9,10,13].contains($0) }),
                  encoding.lowercased() != "7bit" || bytes.allSatisfy({ $0 < 128 }) else { throw TextFormatError.encoding }
            return Data(bytes)
        case "base64":
            let compact = bytes.filter { ![9,10,13,32].contains($0) }
            guard compact.count % 4 == 0, compact.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || [43,47,61].contains($0) }),
                  let result = Data(base64Encoded: Data(compact)), result.base64EncodedData() == Data(compact) else { throw TextFormatError.encoding }
            return result
        case "quoted-printable":
            var result = Data(), i = 0
            func hex(_ b: UInt8) -> UInt8? {
                if (48...57).contains(b) { return b - 48 }
                if (65...70).contains(b) { return b - 55 }
                if (97...102).contains(b) { return b - 87 }; return nil
            }
            while i < bytes.count {
                if bytes[i] == 61 {
                    if i + 1 < bytes.count && bytes[i+1] == 10 { i += 2; continue }
                    if i + 2 < bytes.count && bytes[i+1] == 13 && bytes[i+2] == 10 { i += 3; continue }
                    guard i + 2 < bytes.count, let high = hex(bytes[i+1]), let low = hex(bytes[i+2]) else { throw TextFormatError.encoding }
                    result.append(high * 16 + low); i += 3
                } else {
                    guard (32...126).contains(bytes[i]) || [9,10,13].contains(bytes[i]) else { throw TextFormatError.encoding }
                    result.append(bytes[i]); i += 1
                }
            }
            return result
        default: throw TextFormatError.unsupportedContent
        }
    }
    private static func text(_ data: Data, charset: String?) throws -> DecodedTextFile {
        let charset = (charset ?? "us-ascii").lowercased()
        guard ["utf-8", "utf8", "utf-16", "utf16", "utf-16le", "utf-16be", "us-ascii"].contains(charset) else { throw TextFormatError.encoding }
        let decoded = try TextFileDecoder.decode(data, format: .txt)
        if charset == "us-ascii" {
            guard data.allSatisfy({ $0 < 128 }), decoded.encoding == "utf-8" else { throw TextFormatError.encoding }
        } else if ["utf-16", "utf16"].contains(charset) {
            guard decoded.encoding.hasPrefix("utf-16") else { throw TextFormatError.encoding }
        } else { guard decoded.encoding == (charset == "utf8" ? "utf-8" : charset) else { throw TextFormatError.encoding } }
        return decoded
    }
    private static func contentID(_ raw: String) throws -> String {
        guard raw.hasPrefix("<"), raw.hasSuffix(">"), raw.count >= 3, raw.count <= 1024 else { throw TextFormatError.unsupportedContent }
        let value = String(raw.dropFirst().dropLast())
        guard value.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value < 127 && ![60,62].contains($0.value) }) else { throw TextFormatError.unsupportedContent }
        return value
    }
    private static func location(_ raw: String, base: URL?) throws -> URL {
        guard raw.utf16.count <= 2048, raw.unicodeScalars.allSatisfy({ $0.value > 32 && $0.value < 127 }),
              !raw.contains("\\"), let url = URL(string: raw, relativeTo: base ?? URL(string: "https://pdfno.invalid/archive/"))?.absoluteURL,
              var components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              ["http", "https"].contains(components.scheme?.lowercased() ?? ""), components.host != nil,
              components.user == nil, components.password == nil else { throw TextFormatError.unsupportedContent }
        components.scheme = components.scheme?.lowercased(); components.host = components.host?.lowercased(); components.fragment = nil
        guard let normalized = components.url?.standardized else { throw TextFormatError.unsupportedContent }; return normalized
    }
}
