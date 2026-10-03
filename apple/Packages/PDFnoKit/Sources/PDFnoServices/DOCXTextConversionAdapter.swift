// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Body text only: intentionally does not interpret layout, run styles, assets or external relationships.
public struct DOCXTextConversionAdapter: DocumentConversionAdapter {
    public static let adapterID = "docx-body-text-1"
    public init() {}
    public var capabilities: [ConversionCapability] {
        [.plainText, .html].map { ConversionCapability(input: .docx, output: $0, adapterID: Self.adapterID) }
    }
    public func convert(_ source: Data, to output: ConversionFormat,
                        progress: @Sendable (ConversionPhase) -> Void = { _ in }) throws -> ConvertedDocument {
        guard output == .plainText || output == .html else { throw ConversionError.unsupportedDirection }
        let archive = try DOCXConversionArchive(source)
        let contentTypes = PackageMetadataReader(kind: .contentTypes)
        try contentTypes.parse(archive.read("[Content_Types].xml"))
        let relationships = PackageMetadataReader(kind: .relationships)
        try relationships.parse(archive.read("_rels/.rels"))
        guard contentTypes.matched, relationships.matched else { throw ConversionError.invalidDocument }
        progress(.converting); try Task.checkCancellation()
        let reader = BodyTextReader()
        try reader.parse(archive.read("word/document.xml"))
        guard reader.foundDocument, reader.foundBody else { throw ConversionError.invalidDocument }
        try Task.checkCancellation()
        let rendered: String
        if output == .plainText { rendered = reader.text }
        else {
            let escaped = reader.text.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;").replacingOccurrences(of: "'", with: "&#39;")
            rendered = "<!doctype html>\n<html><head><meta charset=\"utf-8\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; base-uri 'none'; form-action 'none'\"><title>DOCX 正文副本</title></head><body><pre>" + escaped + "</pre></body></html>\n"
        }
        try Task.checkCancellation()
        return ConvertedDocument(data: Data(rendered.utf8), warnings: [.bodyOnly, .simplifiedLayout])
    }
}

/// Reject DTD/entities before XMLParser sees them, including internal expansion. Only UTF-8 XML is accepted.
private class BoundedXMLReader: NSObject, XMLParserDelegate {
    var stack: [(namespace: String, name: String)] = []
    var failure: Error?
    private var events = 0
    func parse(_ data: Data) throws {
        guard data.count <= DOCXConversionArchive.entryLimit, let xml = String(data: data, encoding: .utf8),
              !xml.contains("\0"), !xml.uppercased().contains("<!DOCTYPE"), !xml.uppercased().contains("<!ENTITY") else {
            throw ConversionError.invalidDocument
        }
        let prefix = xml.drop(while: { $0 == "\u{FEFF}" })
        if prefix.hasPrefix("<?xml"), let end = prefix.range(of: "?>") {
            let declaration = String(prefix[..<end.lowerBound]) as NSString
            let pattern = try NSRegularExpression(pattern: #"encoding\s*=\s*["']([^"']+)["']"#, options: .caseInsensitive)
            if let match = pattern.firstMatch(in: declaration as String, range: NSRange(location: 0, length: declaration.length)) {
                guard ["utf-8", "utf8"].contains(declaration.substring(with: match.range(at: 1)).lowercased()) else {
                    throw ConversionError.invalidDocument
                }
            }
        }
        let parser = XMLParser(data: data)
        parser.shouldProcessNamespaces = true; parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never; parser.delegate = self
        let parsed = parser.parse()
        if let failure { throw failure }
        guard parsed else { throw ConversionError.invalidDocument }
    }
    func start(_ namespace: String, _ name: String, _ attributes: [String: String]) throws {}
    func end(_ namespace: String, _ name: String) throws {}
    func characters(_ string: String) throws {}
    private func consume(_ parser: XMLParser, _ action: () throws -> Void) {
        do {
            try Task.checkCancellation()
            events += 1
            guard events <= 200_000, stack.count <= 256 else { throw ConversionError.resourceLimit }
            try action()
        } catch { failure = error; parser.abortParsing() }
    }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        consume(parser) {
            stack.append((namespaceURI ?? "", elementName))
            guard stack.count <= 256 else { throw ConversionError.resourceLimit }
            try start(namespaceURI ?? "", elementName, attributes)
        }
    }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName: String?) {
        consume(parser) { try end(namespaceURI ?? "", elementName); stack.removeLast() }
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { consume(parser) { try characters(string) } }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        consume(parser) {
            guard let value = String(data: CDATABlock, encoding: .utf8) else { throw ConversionError.invalidDocument }
            try characters(value)
        }
    }
}

private final class PackageMetadataReader: BoundedXMLReader {
    enum Kind { case contentTypes, relationships }
    let kind: Kind
    var matched = false
    init(kind: Kind) { self.kind = kind }
    override func start(_ namespace: String, _ name: String, _ attributes: [String: String]) throws {
        if kind == .contentTypes {
            guard namespace == "http://schemas.openxmlformats.org/package/2006/content-types" else { throw ConversionError.invalidDocument }
            if stack.count == 1 { guard name == "Types" else { throw ConversionError.invalidDocument } }
            if name == "Override", attributes["PartName"] == "/word/document.xml" {
                guard !matched, attributes["ContentType"] == "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml" else {
                    throw ConversionError.unsupportedDocument
                }
                matched = true
            }
        } else {
            guard namespace == "http://schemas.openxmlformats.org/package/2006/relationships" else { throw ConversionError.invalidDocument }
            if stack.count == 1 { guard name == "Relationships" else { throw ConversionError.invalidDocument } }
            if name == "Relationship", let type = attributes["Type"],
               ["http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument",
                "http://purl.oclc.org/ooxml/officeDocument/relationships/officeDocument"].contains(type) {
                guard !matched, attributes["TargetMode"] == nil || attributes["TargetMode"] == "Internal",
                      ["word/document.xml", "/word/document.xml"].contains(attributes["Target"] ?? "") else {
                    throw ConversionError.unsupportedDocument
                }
                matched = true
            }
        }
    }
}

private final class BodyTextReader: BoundedXMLReader {
    private let wordNamespaces = ["http://schemas.openxmlformats.org/wordprocessingml/2006/main", "http://purl.oclc.org/ooxml/wordprocessingml/main"]
    private var wordNamespace = ""
    private var byteCount = 0
    var text = ""
    var foundDocument = false
    var foundBody = false
    private var inBody: Bool { stack.contains { $0.namespace == wordNamespace && $0.name == "body" } }
    private var excluded: Bool {
        stack.contains { $0.namespace == wordNamespace && ["del", "moveFrom", "rt", "drawing", "object", "pict", "txbxContent"].contains($0.name) }
    }
    private func append(_ value: String) throws {
        byteCount += value.utf8.count
        guard byteCount <= DOCXConversionArchive.entryLimit else { throw ConversionError.resourceLimit }
        text.append(value)
    }
    override func start(_ namespace: String, _ name: String, _ attributes: [String: String]) throws {
        if stack.count == 1 {
            guard name == "document", wordNamespaces.contains(namespace) else { throw ConversionError.invalidDocument }
            wordNamespace = namespace; foundDocument = true
        }
        if namespace == wordNamespace, name == "body" {
            guard stack.count == 2, !foundBody else { throw ConversionError.invalidDocument }
            foundBody = true
        }
        guard inBody else { return }
        if namespace == wordNamespace, name == "altChunk" || name == "subDoc" { throw ConversionError.unsupportedDocument }
        if namespace == "http://schemas.openxmlformats.org/markup-compatibility/2006", name == "AlternateContent" {
            throw ConversionError.unsupportedDocument
        }
        guard !excluded, namespace == wordNamespace, stack.contains(where: { $0.namespace == wordNamespace && $0.name == "r" }),
              !stack.contains(where: { $0.namespace == wordNamespace && $0.name == "rPr" }) else { return }
        if name == "tab" { try append("\t") }
        if name == "br" || name == "cr" { try append("\n") }
        if name == "noBreakHyphen" { try append("\u{2011}") }
        if name == "softHyphen" { try append("\u{00AD}") }
    }
    override func characters(_ string: String) throws {
        guard inBody, !excluded, let current = stack.last, current.namespace == wordNamespace, current.name == "t",
              stack.count >= 2, stack[stack.count - 2].namespace == wordNamespace, stack[stack.count - 2].name == "r" else { return }
        try append(string)
    }
    override func end(_ namespace: String, _ name: String) throws {
        guard inBody, !excluded, namespace == wordNamespace else { return }
        if name == "p" { try append("\n") }
        if name == "tc" {
            if text.hasSuffix("\n") { text.removeLast(); byteCount -= 1 }
            try append("\t")
        }
        if name == "tr" {
            if text.hasSuffix("\t") { text.removeLast(); byteCount -= 1 }
            try append("\n")
        }
    }
}
