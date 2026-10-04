// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// A bounded input adapter to the existing Kookit HTML route, never a general XML renderer.
/// XHTML requires its real namespace. Other XML accepts only the documented, unnamespaced
/// document/section/title/paragraph vocabulary. Source attributes never enter the reading DOM.
enum ReadableXML {
    static func html(_ source: String, encoding: String, requiresXHTML: Bool) throws -> String {
        guard source.range(of: #"<!DOCTYPE|<!ENTITY"#, options: [.regularExpression, .caseInsensitive]) == nil else {
            throw TextFormatError.unsupportedContent
        }
        var input = source
        if input.hasPrefix("<?xml"), let end = input.range(of: "?>") {
            let declaration = String(input[..<end.upperBound])
            let regex = try NSRegularExpression(pattern: #"\bencoding\s*=\s*['"]([^'"]+)['"]"#)
            for match in regex.matches(in: declaration, range: NSRange(declaration.startIndex..., in: declaration)) {
                guard let range = Range(match.range(at: 1), in: declaration) else { throw TextFormatError.encoding }
                let allowed = encoding == "utf-8" ? ["utf-8", "utf8"] : [encoding, "utf-16", "utf16"]
                guard allowed.contains(declaration[range].lowercased()) else { throw TextFormatError.encoding }
            }
            // Keep XML grammar validation, but feed UTF-8 bytes after the strict original decoding.
            input = declaration.replacingOccurrences(of: #"encoding\s*=\s*['"][^'"]+['"]"#,
                with: "encoding=\"UTF-8\"", options: .regularExpression) + input[end.upperBound...]
        }
        let delegate = ReadableXMLParser(requiresXHTML: requiresXHTML, encoding: encoding)
        let parser = XMLParser(data: Data(input.utf8))
        parser.shouldProcessNamespaces = true; parser.shouldResolveExternalEntities = false
        parser.delegate = delegate
        guard parser.parse(), delegate.failure == nil, delegate.finished else {
            throw delegate.failure ?? TextFormatError.unsupportedContent
        }
        return delegate.output
    }
}

private final class ReadableXMLParser: NSObject, XMLParserDelegate {
    private struct Frame { let name: String; let tag: String; let suppressed: Bool }
    private static let namespace = "http://www.w3.org/1999/xhtml"
    private static let passive = Set("html head body title div section article main header footer nav aside p h1 h2 h3 h4 h5 h6 strong b em i u s sup sub br hr table thead tbody tfoot tr td th ul ol li blockquote pre code span a ruby rt rp dl dt dd figure figcaption img address details summary".split(separator: " ").map(String.init))
    private static let inactive = Set("script style iframe frame frameset object embed form input button link meta base audio video noscript template canvas applet".split(separator: " ").map(String.init))
    private static let documentTags = Set("document section title p para h1 h2 h3 h4 h5 h6 strong b bold em i italic br list item ul ol li blockquote pre code span a table tr td th ruby rt rp".split(separator: " ").map(String.init))
    private var stack: [Frame] = []
    private var nodes = 0
    private var textLength = 0
    private var outputLength = 0
    private var xhtml = false
    private var sawRoot = false
    private var readable = false
    private var bodies = 0
    private var heads = 0
    private let requiresXHTML: Bool
    private let encoding: String
    private(set) var output = ""
    private(set) var failure: TextFormatError?
    private(set) var finished = false
    init(requiresXHTML: Bool, encoding: String) { self.requiresXHTML = requiresXHTML; self.encoding = encoding }
    private func fail(_ parser: XMLParser, _ error: TextFormatError = .unsupportedContent) {
        if failure == nil { failure = error }; parser.abortParsing()
    }
    private func count(_ parser: XMLParser) -> Bool {
        nodes += 1
        if Task.isCancelled { fail(parser, .cancelled); return false }
        guard nodes <= 100000 else { fail(parser, .resourceLimit); return false }; return true
    }
    private func append(_ value: String, parser: XMLParser) {
        outputLength += value.utf16.count
        guard outputLength <= 4 * 1024 * 1024 else { fail(parser, .resourceLimit); return }
        output += value
    }
    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        guard count(parser), stack.count < 64, attributes.count <= 64 else { fail(parser, .resourceLimit); return }
        if !sawRoot {
            sawRoot = true
            xhtml = name == "html" && namespaceURI == Self.namespace
            guard xhtml || (!requiresXHTML && name == "document" && (namespaceURI ?? "").isEmpty) else { fail(parser); return }
        }
        guard (xhtml ? namespaceURI == Self.namespace : (namespaceURI ?? "").isEmpty),
              (xhtml ? Self.passive.union(Self.inactive) : Self.documentTags).contains(name) else { fail(parser); return }
        if xhtml && stack.count == 1 {
            guard ["head", "body"].contains(name) else { fail(parser); return }
            if name == "body" { bodies += 1 } else { heads += 1 }
            guard bodies <= 1 && heads <= 1 else { fail(parser); return }
        } else if xhtml && ["html", "head", "body"].contains(name) && !stack.isEmpty { fail(parser); return }
        if !xhtml && name == "document" && !stack.isEmpty { fail(parser); return }
        if xhtml && name == "meta" {
            let allowed = encoding == "utf-8" ? ["utf-8", "utf8"] : [encoding, "utf-16", "utf16"]
            if let charset = attributes["charset"], !allowed.contains(charset.lowercased()) { fail(parser, .encoding); return }
            if let content = attributes["content"],
               let regex = try? NSRegularExpression(pattern: #"(?i)charset\s*=\s*['"]?([a-z0-9_-]+)"#) {
                for match in regex.matches(in: content, range: NSRange(content.startIndex..., in: content)) {
                    guard let range = Range(match.range(at: 1), in: content), allowed.contains(content[range].lowercased()) else { fail(parser, .encoding); return }
                }
            }
        }
        let suppressed = stack.last?.suppressed == true || (xhtml && (name == "head" || Self.inactive.contains(name)))
        var tag = name
        if !xhtml {
            switch name {
            case "document": tag = "article"
            case "title": tag = "h\(min(6, 1 + stack.filter { $0.name == "section" }.count))"
            case "para": tag = "p"
            case "bold": tag = "strong"
            case "italic": tag = "em"
            case "list": tag = "ul"
            case "item": tag = "li"
            default: break
            }
            if name == "title" && !["document", "section"].contains(stack.last?.name ?? "") { fail(parser); return }
        }
        if !suppressed {
            if name == "img" {
                // Alt is ordinary escaped text; src and all other attributes are discarded.
                append("<span>[" + escape(attributes["alt"] ?? "图片未显示") + "]</span>", parser: parser); tag = ""; readable = true
            } else { append("<" + tag + ">", parser: parser) }
        }
        stack.append(Frame(name: name, tag: tag, suppressed: suppressed))
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard count(parser) else { return }
        textLength += string.utf16.count
        guard textLength <= 1_000_000 else { fail(parser, .resourceLimit); return }
        if let frame = stack.last, !frame.suppressed {
            if !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { readable = true }
            append(escape(string), parser: parser)
        }
    }
    func parser(_ parser: XMLParser, foundCDATA data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { fail(parser); return }
        self.parser(parser, foundCharacters: text)
    }
    func parser(_ parser: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName: String?) {
        guard let frame = stack.popLast() else { fail(parser); return }
        if !frame.suppressed && !frame.tag.isEmpty && !["br", "hr"].contains(frame.tag) { append("</" + frame.tag + ">", parser: parser) }
    }
    func parserDidEndDocument(_ parser: XMLParser) { finished = sawRoot && readable && stack.isEmpty && (!xhtml || bodies == 1) }
    func parser(_ parser: XMLParser, foundComment: String) { _ = count(parser) }
    func parser(_ parser: XMLParser, foundProcessingInstructionWithTarget: String, data: String?) { fail(parser) }
    func parser(_ parser: XMLParser, resolveExternalEntityName: String, systemID: String?) -> Data? { fail(parser); return nil }
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName: String, value: String?) { fail(parser) }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName: String, publicID: String?, systemID: String?) { fail(parser) }
}
