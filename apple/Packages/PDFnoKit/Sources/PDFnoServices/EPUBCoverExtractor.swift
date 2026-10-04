// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFnoDomain

/// Read only explicitly declared EPUB 3 cover-image or EPUB 2 meta/guide cover resources.
/// Uses the existing archive path/size checks and CRC-verified bounded inflater; no WebView or network.
enum EPUBCoverExtractor {
    static func extract(_ data: Data) throws -> (Data, String)? {
        _ = try EPUBArchive.validate(data)
        let entries = try CBZArchive.index(data)
        func read(_ path: String) throws -> Data {
            guard let entry = entries.first(where: { $0.path == path }) else { throw CoverError.invalidEPUB }
            return try CBZArchive.expand(entry, from: data)
        }
        let container = try CoverXML.parse(read("META-INF/container.xml"))
        guard let packagePath = container.first(where: { $0.name == "rootfile" && $0.attributes["media-type"] == "application/oebps-package+xml" })?.attributes["full-path"],
              EPUBArchive.isSafePath(packagePath) else { throw CoverError.invalidEPUB }
        let package = try CoverXML.parse(read(packagePath))
        let items = package.filter { $0.name == "item" }
        let metaID = package.first(where: { $0.name == "meta" && $0.attributes["name"] == "cover" })?.attributes["content"]
        let item = items.first(where: { ($0.attributes["properties"] ?? "").split(whereSeparator: \.isWhitespace).contains("cover-image") })
            ?? items.first(where: { metaID != nil && $0.attributes["id"] == metaID })
        if let item, let href = item.attributes["href"], item.attributes["media-type"]?.hasPrefix("image/") == true {
            let path = try resolve(href, relativeTo: packagePath)
            return (try read(path), path)
        }
        // EPUB 2 guide can point to a local raster or a simple XHTML image wrapper.
        guard let href = package.first(where: { $0.name == "reference" && ($0.attributes["type"] ?? "").split(whereSeparator: \.isWhitespace).contains("cover") })?.attributes["href"] else { return nil }
        let path = try resolve(href, relativeTo: packagePath)
        if ["png", "jpg", "jpeg", "heic", "tif", "tiff"].contains(URL(fileURLWithPath: path).pathExtension.lowercased()) { return (try read(path), path) }
        let wrapper = try CoverXML.parse(read(path))
        guard let image = wrapper.first(where: { $0.name == "img" || $0.name == "image" }),
              let src = image.attributes["src"] ?? image.attributes["href"] ?? image.attributes["xlink:href"] else { return nil }
        let imagePath = try resolve(src, relativeTo: path)
        return (try read(imagePath), imagePath)
    }
    static func resolve(_ href: String, relativeTo base: String) throws -> String {
        let local = String(href.split(separator: "#", maxSplits: 1, omittingEmptySubsequences: false)[0])
        guard !local.isEmpty, !local.hasPrefix("/"), !local.contains(":"), !local.contains("\\"), !local.contains("%"), !local.contains("?") else { throw CoverError.invalidEPUB }
        var parts = base.split(separator: "/").dropLast().map(String.init)
        for part in local.split(separator: "/", omittingEmptySubsequences: false) {
            if part == "." { continue }
            if part == ".." { guard !parts.isEmpty else { throw CoverError.invalidEPUB }; parts.removeLast() }
            else { guard !part.isEmpty else { throw CoverError.invalidEPUB }; parts.append(String(part)) }
        }
        let result = parts.joined(separator: "/")
        guard EPUBArchive.isSafePath(result) else { throw CoverError.invalidEPUB }; return result
    }
}
private final class CoverXML: NSObject, XMLParserDelegate {
    struct Element { let name: String; let attributes: [String: String] }
    var elements: [Element] = []
    var depth = 0
    var failed = false
    static func parse(_ data: Data) throws -> [Element] {
        guard data.count <= 4 * 1024 * 1024, let text = String(data: data, encoding: .utf8),
              !text.uppercased().contains("<!DOCTYPE"), !text.uppercased().contains("<!ENTITY") else { throw CoverError.invalidEPUB }
        let delegate = CoverXML(), parser = XMLParser(data: data)
        parser.delegate = delegate; parser.shouldResolveExternalEntities = false
        guard parser.parse(), !delegate.failed else { throw CoverError.invalidEPUB }; return delegate.elements
    }
    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String]) {
        depth += 1
        guard depth <= 64, elements.count < 10000 else { failed = true; parser.abortParsing(); return }
        elements.append(Element(name: String(name.split(separator: ":").last ?? ""), attributes: attributes))
    }
    func parser(_ parser: XMLParser, didEndElement: String, namespaceURI: String?, qualifiedName: String?) { depth -= 1 }
    func parser(_ parser: XMLParser, resolveExternalEntityName: String, systemID: String?) -> Data? { failed = true; parser.abortParsing(); return nil }
}
