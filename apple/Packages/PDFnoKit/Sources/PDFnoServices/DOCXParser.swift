// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

private let wordNS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
private let relNS = "http://schemas.openxmlformats.org/package/2006/relationships"
private let contentNS = "http://schemas.openxmlformats.org/package/2006/content-types"

private final class DOCXElement {
    let name: String
    let namespace: String
    let attributes: [String: String]
    var text = ""
    var children: [DOCXElement] = []
    init(_ name: String, namespace: String, attributes: [String: String]) {
        self.name = name; self.namespace = namespace; self.attributes = attributes
    }
    func child(_ name: String) -> DOCXElement? { children.first { $0.name == name && $0.namespace == wordNS } }
    func value(_ name: String = "val") -> String? { attributes["{\(wordNS)}\(name)"] }
}
private final class DOCXXML: NSObject, XMLParserDelegate {
    var root: DOCXElement?
    var stack: [DOCXElement] = []
    var namespaces: [String: [String]] = [:]
    var count = 0
    var failure: DOCXError?
    func fail(_ parser: XMLParser, _ error: DOCXError = .invalidXML) { failure = error; parser.abortParsing() }
    static func parse(_ data: Data) throws -> DOCXElement {
        guard let string = String(data: data, encoding: .utf8), !string.contains("\0"),
              !string.uppercased().contains("<!DOCTYPE"), !string.uppercased().contains("<!ENTITY") else { throw DOCXError.invalidXML }
        let prolog = string.hasPrefix("\u{FEFF}") ? String(string.dropFirst()) : string
        if prolog.range(of: #"^<\?xml\s"#, options: .regularExpression) != nil, let end = prolog.range(of: "?>") {
            let declaration = String(prolog[..<end.lowerBound])
            if let encoding = declaration.range(of: #"(?i)encoding\s*=\s*['"][^'"]+['"]"#, options: .regularExpression) {
                let assignment = declaration[encoding].split(separator: "=", maxSplits: 1)[1]
                let value = assignment.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                guard value.lowercased() == "utf-8" else { throw DOCXError.invalidXML }
            }
        }
        // UTF-16/other encodings are outside this profile, preventing byte-scan bypasses.
        let parser = XMLParser(data: data), delegate = DOCXXML()
        parser.shouldProcessNamespaces = true; parser.shouldReportNamespacePrefixes = true
        parser.shouldResolveExternalEntities = false; parser.delegate = delegate
        guard parser.parse(), delegate.failure == nil, let root = delegate.root else { throw delegate.failure ?? DOCXError.invalidXML }
        return root
    }
    func parser(_ parser: XMLParser, didStartMappingPrefix prefix: String, toURI namespaceURI: String) {
        namespaces[prefix, default: []].append(namespaceURI)
    }
    func parser(_ parser: XMLParser, didEndMappingPrefix prefix: String) { _ = namespaces[prefix]?.popLast() }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        count += 1
        guard count <= 100000, stack.count < 64, attributes.count <= 64 else { fail(parser, .resourceLimit); return }
        var resolved: [String: String] = [:]
        for (key, value) in attributes {
            let parts = key.split(separator: ":", maxSplits: 1)
            let name = parts.count == 2 ? "{\(namespaces[String(parts[0])]?.last ?? "")}\(parts[1])" : key
            resolved[name] = value
        }
        let element = DOCXElement(elementName, namespace: namespaceURI ?? "", attributes: resolved)
        if let parent = stack.last { parent.children.append(element) } else if root == nil { root = element }
        else { fail(parser); return }
        stack.append(element)
    }
    func parser(_ parser: XMLParser, foundCharacters string: String) { stack.last?.text += string }
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard let string = String(data: CDATABlock, encoding: .utf8) else { fail(parser); return }; stack.last?.text += string
    }
    func parser(_ parser: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName: String?) { _ = stack.popLast() }
    func parser(_ parser: XMLParser, resolveExternalEntityName: String, systemID: String?) -> Data? { fail(parser); return nil }
    func parser(_ parser: XMLParser, foundInternalEntityDeclarationWithName: String, value: String?) { fail(parser) }
    func parser(_ parser: XMLParser, foundExternalEntityDeclarationWithName: String, publicID: String?, systemID: String?) { fail(parser) }
}

/// Restricted OOXML Transitional semantic profile. No document HTML, CSS, URLs or code are passed through.
public enum DOCXParser {
    /// Safety preflight only. Product semantics come from the pinned Kookit/Mammoth chain.
    /// Ordinary external hyperlinks remain inert text; other external relationships fail closed.
    public static func preflight(_ data: Data) throws -> [String] {
        let entries = try DOCXArchive.read(data)
        var types: DOCXElement?, main: DOCXElement?, styles: DOCXElement?
        for name in entries.keys.sorted() where name.lowercased().hasSuffix(".xml") || name.lowercased().hasSuffix(".rels") {
            let root = try DOCXXML.parse(entries[name]!)
            if name == "[Content_Types].xml" { types = root }
            if name == "word/document.xml" { main = root }
            if name == "word/styles.xml" { styles = root }
            if name.lowercased().hasSuffix(".rels") { try validateRelationships(root, name: name, entries: entries, allowExternalHyperlinks: true) }
            var paragraphs = 0, textUnits = 0
            func check(_ node: DOCXElement) throws {
                if node.namespace == wordNS {
                    if ["object", "altChunk", "subDoc"].contains(node.name) { throw DOCXError.unsupportedContent }
                    if node.name == "p" { paragraphs += 1 }
                    if node.name == "t" { textUnits += node.text.utf16.count }
                }
                guard paragraphs <= 10000, textUnits <= 1_000_000 else { throw DOCXError.resourceLimit }
                for child in node.children { try check(child) }
            }
            try check(root)
        }
        guard let types, types.name == "Types", types.namespace == contentNS,
              types.children.contains(where: {
                  $0.name == "Override" && $0.namespace == contentNS && $0.attributes["PartName"] == "/word/document.xml" &&
                  $0.attributes["ContentType"] == "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"
              }), !types.children.contains(where: {
                  let type = ($0.attributes["ContentType"] ?? "").lowercased()
                  return type.contains("macro") || type.contains("vba") || type.contains("oleobject")
              }), let main, main.name == "document", main.namespace == wordNS, main.child("body") != nil else { throw DOCXError.unsupportedContent }
        _ = try headingStyles(styles) // Cycle/depth guard, not a replacement for Mammoth semantics.
        return entries.keys.sorted()
    }
    /// Retained native candidate for comparison tests; not used by the product import/render path.
    public static func parse(_ data: Data) throws -> DOCXDocument {
        let entries = try DOCXArchive.read(data)
        var roots: [String: DOCXElement] = [:]
        for name in entries.keys.sorted() where name.lowercased().hasSuffix(".xml") || name.lowercased().hasSuffix(".rels") {
            let root = try DOCXXML.parse(entries[name]!)
            if name == "[Content_Types].xml" || name == "word/document.xml" || name == "word/styles.xml" { roots[name] = root }
            if name.lowercased().hasSuffix(".rels") { try validateRelationships(root, name: name, entries: entries) }
        }
        guard let types = roots["[Content_Types].xml"], types.name == "Types", types.namespace == contentNS,
              types.children.contains(where: {
                  $0.name == "Override" && $0.namespace == contentNS && $0.attributes["PartName"] == "/word/document.xml" &&
                  $0.attributes["ContentType"] == "application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"
              }), !types.children.contains(where: {
                  let type = ($0.attributes["ContentType"] ?? "").lowercased()
                  return type.contains("macro") || type.contains("vba") || type.contains("oleobject")
              }),
              let root = roots["word/document.xml"], root.name == "document", root.namespace == wordNS,
              let body = root.child("body") else { throw DOCXError.unsupportedContent }
        let headings = try headingStyles(roots["word/styles.xml"])
        var blocks: [DOCXBlock] = [], warnings = Set<String>(), start = 0, tableID = 0
        func append(_ p: DOCXElement, table: Int? = nil, row: Int? = nil, cell: Int? = nil) throws {
            guard blocks.count < 10000 else { throw DOCXError.resourceLimit }
            let props = p.child("pPr")
            let explicit = props?.child("outlineLvl")?.value().flatMap(Int.init)
            let heading = explicit.map { (0..<9).contains($0) ? $0 + 1 : nil } ?? headings[props?.child("pStyle")?.value() ?? ""]
            let numbered = props?.child("numPr")
            let list = numbered == nil ? nil : min(8, max(0, numbered?.child("ilvl")?.value().flatMap(Int.init) ?? 0))
            var runs: [DOCXRun] = []
            func inline(_ node: DOCXElement, bold: Bool = false, italic: Bool = false) throws {
                guard node.namespace == wordNS else {
                    warnings.insert("图片、图形与扩展内容未显示。"); return
                }
                switch node.name {
                case "r":
                    let rPr = node.child("rPr")
                    func on(_ prop: DOCXElement?) -> Bool { prop.map { !["0", "false", "off"].contains($0.value() ?? "1") } ?? false }
                    if on(rPr?.child("vanish")) { warnings.insert("隐藏文字未显示。"); return }
                    for child in node.children where child.name != "rPr" { try inline(child, bold: on(rPr?.child("b")), italic: on(rPr?.child("i"))) }
                case "t": runs.append(DOCXRun(node.text, bold: bold, italic: italic))
                case "tab": runs.append(DOCXRun("\t", bold: bold, italic: italic))
                case "br", "cr": runs.append(DOCXRun("\n", bold: bold, italic: italic))
                case "hyperlink", "ins", "smartTag": for child in node.children { try inline(child, bold: bold, italic: italic) }
                case "del", "moveFrom": warnings.insert("修订按当前正文显示；删除内容未显示。")
                case "drawing", "pict": warnings.insert("图片、图形与扩展内容未显示。")
                case "object", "altChunk", "subDoc": throw DOCXError.unsupportedContent
                case "fldSimple", "instrText", "fldChar": warnings.insert("动态域未计算，仅保留已有显示文字。")
                    if node.name == "fldSimple" { for child in node.children { try inline(child) } }
                case "footnoteReference", "endnoteReference", "commentReference": warnings.insert("脚注、尾注与原文批注未显示。")
                case "pPr", "bookmarkStart", "bookmarkEnd", "proofErr", "lastRenderedPageBreak": break
                default: warnings.insert("部分扩展内容未显示。")
                }
            }
            for child in p.children { try inline(child) }
            let length = runs.reduce(0) { $0 + $1.text.utf16.count }
            guard start + length <= 1_000_000 else { throw DOCXError.resourceLimit }
            blocks.append(DOCXBlock(id: blocks.count, runs: runs, headingLevel: heading, listLevel: list,
                                    table: table, row: row, cell: cell, start: start))
            start += length + 1
            if list != nil { warnings.insert("列表以层级项目显示，原编号样式未复现。") }
        }
        func walk(_ nodes: [DOCXElement]) throws {
            for node in nodes {
                guard node.namespace == wordNS else { warnings.insert("部分扩展内容未显示。"); continue }
                switch node.name {
                case "p": try append(node)
                case "tbl":
                    let id = tableID; tableID += 1
                    for (row, tr) in node.children.filter({ $0.name == "tr" && $0.namespace == wordNS }).enumerated() {
                        for (cell, tc) in tr.children.filter({ $0.name == "tc" && $0.namespace == wordNS }).enumerated() {
                            for child in tc.children where child.name == "p" && child.namespace == wordNS { try append(child, table: id, row: row, cell: cell) }
                            if tc.children.contains(where: { $0.name == "tbl" }) { warnings.insert("嵌套表格未显示。") }
                        }
                    }
                    warnings.insert("表格按普通网格显示，合并单元格与尺寸未复现。")
                case "sdt": if let content = node.child("sdtContent") { try walk(content.children) }
                case "sectPr": warnings.insert("页眉、页脚、分页、栏与页面尺寸未复现。")
                case "altChunk", "object", "subDoc": throw DOCXError.unsupportedContent
                default: warnings.insert("部分扩展内容未显示。")
                }
            }
        }
        try walk(body.children)
        guard blocks.contains(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { throw DOCXError.unsupportedContent }
        if entries.keys.contains(where: { $0.hasPrefix("word/header") || $0.hasPrefix("word/footer") || $0 == "word/footnotes.xml" || $0 == "word/endnotes.xml" }) {
            warnings.insert("页眉、页脚、脚注与尾注未显示。")
        }
        return DOCXDocument(blocks: blocks, warnings: warnings.sorted())
    }
    private static func validateRelationships(_ root: DOCXElement, name: String, entries: [String: Data], allowExternalHyperlinks: Bool = false) throws {
        guard root.name == "Relationships", root.namespace == relNS else { throw DOCXError.invalidXML }
        let base: [String]
        if name == "_rels/.rels" { base = [] }
        else {
            let parts = name.split(separator: "/").map(String.init)
            guard parts.count >= 3, parts[parts.count - 2] == "_rels" else { throw DOCXError.invalidXML }
            base = Array(parts.dropLast(2))
        }
        var ids = Set<String>(), officeDocument = false
        for rel in root.children {
            guard rel.name == "Relationship", rel.namespace == relNS, let id = rel.attributes["Id"], !id.isEmpty,
                  ids.insert(id).inserted, let type = rel.attributes["Type"], let target = rel.attributes["Target"],
                  !["oleObject", "package", "aFChunk", "attachedTemplate"].contains(type.split(separator: "/").last.map(String.init) ?? ""),
                  !target.isEmpty, target.utf8.count <= 4096 else { throw DOCXError.unsupportedContent }
            if rel.attributes["TargetMode"] == "External" {
                guard allowExternalHyperlinks, type == "http://schemas.openxmlformats.org/officeDocument/2006/relationships/hyperlink" else { throw DOCXError.unsupportedContent }
                continue // Never resolve/open external hyperlink targets; renderer removes every href.
            }
            guard rel.attributes["TargetMode"] == nil || rel.attributes["TargetMode"] == "Internal",
                  !target.contains(":"), !target.contains("\\"), !target.contains("%"),
                  !target.contains("#"), !target.contains("?"), !target.contains("\0") else { throw DOCXError.unsupportedContent }
            var resolved = target.hasPrefix("/") ? [] : base
            for part in target.split(separator: "/") {
                if part == "." { continue }
                if part == ".." { guard !resolved.isEmpty else { throw DOCXError.unsupportedContent }; resolved.removeLast() }
                else { resolved.append(String(part)) }
            }
            let path = resolved.joined(separator: "/")
            guard EPUBArchive.isSafePath(path), entries[path] != nil else { throw DOCXError.unsupportedContent }
            if name == "_rels/.rels" && type == "http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" {
                guard path == "word/document.xml", !officeDocument else { throw DOCXError.unsupportedContent }; officeDocument = true
            }
        }
        if name == "_rels/.rels" && !officeDocument { throw DOCXError.unsupportedContent }
    }
    private static func headingStyles(_ root: DOCXElement?) throws -> [String: Int] {
        guard let root else { return Dictionary(uniqueKeysWithValues: (1...9).map { ("Heading\($0)", $0) }) }
        guard root.name == "styles", root.namespace == wordNS else { throw DOCXError.invalidXML }
        var styles: [String: DOCXElement] = [:]
        for node in root.children where node.name == "style" && node.namespace == wordNS {
            guard let id = node.value("styleId"), styles[id] == nil else { throw DOCXError.invalidXML }; styles[id] = node
        }
        func resolve(_ id: String, seen: Set<String> = []) throws -> Int? {
            guard !seen.contains(id), seen.count < 32 else { throw DOCXError.invalidXML }
            guard let style = styles[id] else { return nil }
            if let level = style.child("pPr")?.child("outlineLvl")?.value().flatMap(Int.init) { return (0..<9).contains(level) ? level + 1 : nil }
            let label = (style.child("name")?.value() ?? id).lowercased().replacingOccurrences(of: " ", with: "")
            if label.hasPrefix("heading"), let level = Int(label.dropFirst(7)), (1...9).contains(level) { return level }
            if let parent = style.child("basedOn")?.value() { return try resolve(parent, seen: seen.union([id])) }
            return nil
        }
        var result: [String: Int] = [:]
        for id in styles.keys { result[id] = try resolve(id) }
        return result
    }
}
