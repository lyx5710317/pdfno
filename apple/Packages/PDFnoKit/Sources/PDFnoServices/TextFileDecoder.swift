// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

public struct DecodedTextFile: Sendable {
    public let text: String
    public let encoding: String
    public let engineFormat: TextFileFormat
    public let warnings: [String]
    public init(text: String, encoding: String, engineFormat: TextFileFormat, warnings: [String] = []) {
        self.text = text; self.encoding = encoding; self.engineFormat = engineFormat; self.warnings = warnings
    }
}
public enum TextFileDecoder {
    public static func decode(_ data: Data, format: TextFileFormat) throws -> DecodedTextFile {
        if format == .mhtml { return try MHTMLArchive.decode(data) }
        guard !data.isEmpty, data.count <= 4 * 1024 * 1024 else { throw TextFormatError.resourceLimit }
        let bytes = [UInt8](data.prefix(4))
        guard !bytes.starts(with: [0,0,0xfe,0xff]), !bytes.starts(with: [0xff,0xfe,0,0]) else { throw TextFormatError.encoding }
        let text: String?, encoding: String
        if bytes.starts(with: [0xff,0xfe]) || bytes.starts(with: [0xfe,0xff]) {
            let little = bytes[0] == 0xff
            let body = [UInt8](data.dropFirst(2)); guard body.count % 2 == 0 else { throw TextFormatError.encoding }
            let units = stride(from: 0, to: body.count, by: 2).map { i in
                little ? UInt16(body[i]) | UInt16(body[i+1]) << 8 : UInt16(body[i]) << 8 | UInt16(body[i+1])
            }
            var i = 0
            while i < units.count {
                let u = units[i]
                if (0xd800...0xdbff).contains(u) {
                    guard i+1 < units.count, (0xdc00...0xdfff).contains(units[i+1]) else { throw TextFormatError.encoding }; i += 2
                } else { guard !(0xdc00...0xdfff).contains(u) else { throw TextFormatError.encoding }; i += 1 }
            }
            text = String(decoding: units, as: UTF16.self); encoding = little ? "utf-16le" : "utf-16be"
        } else {
            let body = bytes.starts(with: [0xef,0xbb,0xbf]) ? data.dropFirst(3) : data[...]
            text = String(data: Data(body), encoding: .utf8); encoding = "utf-8"
        }
        guard let text else { throw TextFormatError.encoding }
        guard text.utf16.count <= 1_000_000 else { throw TextFormatError.resourceLimit }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              text.unicodeScalars.allSatisfy({ $0.value >= 32 || [9,10,13].contains($0.value) }) else { throw TextFormatError.unsupportedContent }
        if format == .html {
            let expression = try NSRegularExpression(pattern: #"(?i)<meta\b[^>]*charset\s*=\s*["']?([a-z0-9_-]+)"#)
            for match in expression.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                guard let range = Range(match.range(at: 1), in: text) else { throw TextFormatError.encoding }
                let declared = text[range].lowercased()
                let permitted = encoding == "utf-8" ? ["utf-8","utf8"] : [encoding,"utf-16","utf16"]
                guard permitted.contains(declared) else { throw TextFormatError.encoding }
            }
        }
        if format == .xhtml || format == .xml {
            let html = try ReadableXML.html(text, encoding: encoding, requiresXHTML: format == .xhtml)
            return DecodedTextFile(text: html, encoding: encoding, engineFormat: .html, warnings: [
                "XML 按限定可读结构转换；DTD、实体声明、外部样式表和未知 schema 不支持。原件完整保留。",
                "网页归档只显示离线语义正文；图片、CSS、字体、链接目标与主动内容不加载。"
            ])
        }
        if format == .html {
            // Permit HTML's ordinary doctype, never XML/DTD/entity declarations.
            guard text.range(of: #"<!ENTITY|<!DOCTYPE[^>]*\[|<\?xml"#, options: [.regularExpression,.caseInsensitive]) == nil else { throw TextFormatError.unsupportedContent }
        }
        return DecodedTextFile(text: text, encoding: encoding, engineFormat: format)
    }
}
