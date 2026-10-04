// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

/// Entirely original text and opaque resource fixtures; never downloaded books/pages.
enum OriginalWebArchiveFixtures {
    static let html = "<h1>Chapter 1</h1><p><strong>window</strong> original 日本語🌸 café &amp; literal</p><h2>Chapter 2</h2><p>window second</p><script>window.sourceExecuted=true</script><img src='cid:picture' alt='Original image'/><style>@import 'https://example.invalid/private';</style>"
    static let xhtml = "<?xml version='1.0' encoding='UTF-8'?><x:html xmlns:x='http://www.w3.org/1999/xhtml'><x:head><x:title>Not a chapter</x:title></x:head><x:body><x:h1>Chapter 1</x:h1><x:p onclick='active()'><x:strong>window</x:strong> original 日本語🌸 café &amp; literal</x:p><x:h2>Chapter 2</x:h2><x:p>window second</x:p><x:script>window.sourceExecuted=true</x:script><x:img src='https://example.invalid/private' alt='Original image'/></x:body></x:html>"
    static let xml = "<?xml version='1.0' encoding='UTF-8'?><document><title>Chapter 1</title><p><bold>window</bold> original 日本語🌸 café &amp; literal</p><section><title>Chapter 2</title><p>window second</p><p><![CDATA[<script>literal only</script>]]></p></section></document>"
    static func part(_ bytes: Data, type: String = "text/html; charset=utf-8", encoding: String = "base64", id: String = "root", location: String = "https://example.invalid/archive/index.html") -> String {
        let payload = encoding == "base64" ? bytes.base64EncodedString() : String(decoding: bytes, as: UTF8.self)
        return "Content-Type: \(type)\r\nContent-Transfer-Encoding: \(encoding)\r\nContent-ID: <\(id)>\r\nContent-Location: \(location)\r\n\r\n\(payload)"
    }
    static func archive(_ parts: [String], start: String? = nil) -> Data {
        let selector = start.map { "; start=\"<\($0)>\"" } ?? ""
        return Data(("MIME-Version: 1.0\r\nContent-Type: multipart/related;\r\n boundary=\"OriginalBoundary\"; type=\"text/html\"\(selector)\r\n\r\n" + parts.map { "--OriginalBoundary\r\n" + $0 + "\r\n" }.joined() + "--OriginalBoundary--\r\n").utf8)
    }
    static var mhtml: Data { archive([part(Data(html.utf8)), part(Data("p { color: blue }".utf8), type: "text/css; charset=utf-8", id: "style", location: "original.css")]) }
    static func utf16(_ source: String, little: Bool) -> Data {
        var data = Data(little ? [255,254] : [254,255])
        for u in source.utf16 { data.append(contentsOf: little ? [UInt8(u & 255), UInt8(u >> 8)] : [UInt8(u >> 8), UInt8(u & 255)]) }; return data
    }
}

struct WebArchiveFormatTests {
    @Test func XMLProjectsOnlyReadableSchemaAndRealXHTMLNamespace() throws {
        let xhtml = try TextFileDecoder.decode(Data(OriginalWebArchiveFixtures.xhtml.utf8), format: .xhtml)
        #expect(xhtml.engineFormat == .html && xhtml.encoding == "utf-8" && !xhtml.warnings.isEmpty)
        #expect(xhtml.text.contains("<strong>window</strong>") && xhtml.text.contains("&amp; literal"))
        #expect(!xhtml.text.contains("sourceExecuted") && !xhtml.text.contains("onclick") && !xhtml.text.contains("https:"))
        #expect(xhtml.text.contains("[Original image]") && !xhtml.text.contains("Not a chapter"))
        let xml = try TextFileDecoder.decode(Data(OriginalWebArchiveFixtures.xml.utf8), format: .xml)
        #expect(xml.text.contains("<h1>Chapter 1</h1>") && xml.text.contains("<h2>Chapter 2</h2>"))
        #expect(xml.text.contains("&lt;script&gt;literal only&lt;/script&gt;"))
        #expect(try TextFileDecoder.decode(Data(OriginalWebArchiveFixtures.xhtml.utf8), format: .xml).text == xhtml.text)
        let literalMeta = "<document><p><![CDATA[<meta charset='shift_jis'>literal</meta>]]></p></document>"
        #expect(try TextFileDecoder.decode(Data(literalMeta.utf8), format: .xml).text.contains("&lt;meta charset='shift_jis'&gt;literal"))
        let wrongMeta = OriginalWebArchiveFixtures.xhtml.replacingOccurrences(of: "<x:head>", with: "<x:head><x:meta charset='shift_jis'/>")
        #expect(throws: TextFormatError.encoding) { try TextFileDecoder.decode(Data(wrongMeta.utf8), format: .xhtml) }
        for little in [true, false] {
            let input = OriginalWebArchiveFixtures.xhtml.replacingOccurrences(of: "UTF-8", with: "UTF-16")
            #expect(try TextFileDecoder.decode(OriginalWebArchiveFixtures.utf16(input, little: little), format: .xhtml).text == xhtml.text)
        }
    }
    @Test func XMLRefusesDTDUnknownDataMalformedNamespacesAndProcessingInstructions() {
        let sources = [
            "<!DOCTYPE html SYSTEM 'https://example.invalid/dtd'><html xmlns='http://www.w3.org/1999/xhtml'><body><p>x</p></body></html>",
            "<!DOCTYPE document [<!ENTITY data SYSTEM 'file:///private'>]><document><p>&data;</p></document>",
            "<?xml-stylesheet href='https://example.invalid/xsl'?><document><p>x</p></document>",
            "<document/>", "<document><section> </section></document>", "<document><document><p>nested root</p></document></document>",
            "<invoice><amount>100</amount></invoice>", "<document><amount>100</amount></document>",
            "<document xmlns='urn:unknown'><p>x</p></document>", "<document><p>mismatch</document>",
            "<html><body><p>Missing real namespace</p></body></html>",
            "<html xmlns='http://www.w3.org/1999/xhtml'><body><p>one</p></body><body>two</body></html>",
            "<html xmlns='http://www.w3.org/1999/xhtml'><p>Missing body</p></html>",
            "<document><p><title>wrong title position</title></p></document>",
            "<html xmlns='http://www.w3.org/1999/xhtml'><body><svg xmlns='http://www.w3.org/2000/svg'/></body></html>"
        ]
        for source in sources { #expect(throws: TextFormatError.self) { try TextFileDecoder.decode(Data(source.utf8), format: .xml) } }
        #expect(throws: TextFormatError.self) { try TextFileDecoder.decode(Data(OriginalWebArchiveFixtures.xml.utf8), format: .xhtml) }
        #expect(throws: TextFormatError.encoding) { try TextFileDecoder.decode(Data(OriginalWebArchiveFixtures.xhtml.replacingOccurrences(of: "UTF-8", with: "shift_jis").utf8), format: .xhtml) }
        #expect(throws: TextFormatError.resourceLimit) {
            try TextFileDecoder.decode(Data(("<document>" + String(repeating: "<section>", count: 64) + "<p>text</p>" + String(repeating: "</section>", count: 64) + "</document>").utf8), format: .xml)
        }
    }
    @Test func MIMEPlainRootEncodingAndExplicitStartAreDeterministic() throws {
        let root = OriginalWebArchiveFixtures.part(Data(OriginalWebArchiveFixtures.html.utf8))
        let css = OriginalWebArchiveFixtures.part(Data("p { color: red }".utf8), type: "text/css; charset=utf-8", id: "css", location: "style.css")
        // Self-authored 1x1 RGB PNG (#25517d), built from PNG chunks/CRC/zlib; never rendered.
        let originalPNG = try #require(Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGNQDawFAAGSAPRETYwVAAAAAElFTkSuQmCC"))
        let image = OriginalWebArchiveFixtures.part(originalPNG, type: "image/png", id: "picture", location: "original.png")
        #expect(try TextFileDecoder.decode(OriginalWebArchiveFixtures.archive([root, css, image]), format: .mhtml).text == OriginalWebArchiveFixtures.html)
        // JPEG resources are intentionally opaque signature checks, never pixel decoding.
        let opaqueJPEG = OriginalWebArchiveFixtures.part(Data([255,216,255,217]), type: "image/jpeg", id: "jpeg", location: "original.jpg")
        #expect(try TextFileDecoder.decode(OriginalWebArchiveFixtures.archive([root, opaqueJPEG]), format: .mhtml).text == OriginalWebArchiveFixtures.html)
        let expected = try TextFileDecoder.decode(OriginalWebArchiveFixtures.mhtml, format: .mhtml)
        #expect(expected.engineFormat == .html && expected.text == OriginalWebArchiveFixtures.html)
        #expect(expected.warnings.contains { $0.contains("外部原页面") })
        #expect(try TextFileDecoder.decode(OriginalWebArchiveFixtures.archive([css, root], start: "root"), format: .mhtml).text == expected.text)
        for encoding in ["8bit", "base64"] {
            #expect(try TextFileDecoder.decode(OriginalWebArchiveFixtures.archive([OriginalWebArchiveFixtures.part(Data(OriginalWebArchiveFixtures.html.utf8), encoding: encoding)]), format: .mhtml).text == expected.text)
        }
        let qp = Data("<h1>Original</h1><p>caf=C3=A9 =F0=9F=8C=B8</p>".utf8)
        #expect(try TextFileDecoder.decode(OriginalWebArchiveFixtures.archive([OriginalWebArchiveFixtures.part(qp, encoding: "quoted-printable")]), format: .mhtml).text == "<h1>Original</h1><p>café 🌸</p>")
        let soft = Data("<p>long=\r\ncontinued</p>".utf8)
        #expect(try TextFileDecoder.decode(OriginalWebArchiveFixtures.archive([OriginalWebArchiveFixtures.part(soft, encoding: "quoted-printable")]), format: .mhtml).text == "<p>longcontinued</p>")
        let ascii = OriginalWebArchiveFixtures.part(Data("<p>ASCII only</p>".utf8), type: "text/html", encoding: "7bit")
        #expect(try TextFileDecoder.decode(OriginalWebArchiveFixtures.archive([ascii]), format: .mhtml).text == "<p>ASCII only</p>")
        for little in [true, false] {
            let bytes = OriginalWebArchiveFixtures.utf16(OriginalWebArchiveFixtures.html, little: little)
            let part = OriginalWebArchiveFixtures.part(bytes, type: "text/html; charset=utf-16")
            #expect(try TextFileDecoder.decode(OriginalWebArchiveFixtures.archive([part]), format: .mhtml).text == expected.text)
        }
    }
    @Test func MIMERefusesAmbiguityNestedArchivesActiveResourcesAndWrongEncoding() {
        let root = OriginalWebArchiveFixtures.part(Data("<p>Original 🌸</p>".utf8))
        let css = OriginalWebArchiveFixtures.part(Data("p {}".utf8), type: "text/css; charset=utf-8", id: "css", location: "style.css")
        var rejected = [
            OriginalWebArchiveFixtures.archive([root, root]),
            OriginalWebArchiveFixtures.archive([root, css], start: "missing"),
            OriginalWebArchiveFixtures.archive([css, root]),
            OriginalWebArchiveFixtures.archive([root, css.replacingOccurrences(of: "<css>", with: "<root>")]),
            OriginalWebArchiveFixtures.archive([root, css.replacingOccurrences(of: "style.css", with: "https://example.invalid/archive/index.html")]),
            OriginalWebArchiveFixtures.archive([root.replacingOccurrences(of: "charset=utf-8", with: "charset=shift_jis")]),
            OriginalWebArchiveFixtures.archive([root.replacingOccurrences(of: "charset=utf-8", with: "charset=utf-16")]),
            OriginalWebArchiveFixtures.archive([root.replacingOccurrences(of: "charset=utf-8", with: "charset=utf-8; charset=utf-8")]),
            OriginalWebArchiveFixtures.archive([root.replacingOccurrences(of: "Content-ID:", with: "Content-Encoding: gzip\r\nContent-ID:")]),
            OriginalWebArchiveFixtures.archive([root.replacingOccurrences(of: "Content-ID:", with: "Content-Transfer-Encoding: base64\r\nContent-ID:")]),
            OriginalWebArchiveFixtures.archive([root.replacingOccurrences(of: "https://example.invalid/archive/index.html", with: "file:///private")])
        ]
        for type in ["application/javascript", "image/svg+xml", "application/octet-stream", "multipart/alternative", "message/rfc822", "font/woff2", "image/png", "image/jpeg"] {
            rejected.append(OriginalWebArchiveFixtures.archive([root, OriginalWebArchiveFixtures.part(Data("Unsupported".utf8), type: type, id: "resource", location: "resource")]))
        }
        let valid = String(decoding: OriginalWebArchiveFixtures.archive([root]), as: UTF8.self)
        rejected.append(Data(valid.replacingOccurrences(of: "--OriginalBoundary--", with: "--Missing--").utf8))
        rejected.append(Data(valid.replacingOccurrences(of: "boundary=\"OriginalBoundary\"", with: "boundary=\"OriginalBoundary\"; boundary=other").utf8))
        rejected.append(Data((valid + "nonempty epilogue").utf8))
        for data in rejected { #expect(throws: TextFormatError.self) { try TextFileDecoder.decode(data, format: .mhtml) } }
        for (encoding, bad) in [("quoted-printable", "<p>bad=QZ</p>"), ("quoted-printable", "<p>truncated="), ("base64", "%%%="), ("base64", "YQ"), ("binary", "body"), ("7bit", "🌸")] {
            let part = "Content-Type: text/html; charset=utf-8\r\nContent-Transfer-Encoding: \(encoding)\r\n\r\n\(bad)"
            #expect(throws: TextFormatError.self) { try TextFileDecoder.decode(OriginalWebArchiveFixtures.archive([part]), format: .mhtml) }
        }
    }
    @Test func MIMEEnforcesPartCountAndDecodedBudgets() {
        let root = OriginalWebArchiveFixtures.part(Data("<p>Original</p>".utf8))
        let resources = (0..<64).map { OriginalWebArchiveFixtures.part(Data("p {}".utf8), type: "text/css; charset=utf-8", id: "css\($0)", location: "style\($0).css") }
        #expect(throws: TextFormatError.resourceLimit) { try TextFileDecoder.decode(OriginalWebArchiveFixtures.archive([root] + resources), format: .mhtml) }
        let huge = OriginalWebArchiveFixtures.part(Data(repeating: 65, count: 1024 * 1024 + 1))
        #expect(throws: TextFormatError.resourceLimit) { try TextFileDecoder.decode(OriginalWebArchiveFixtures.archive([huge]), format: .mhtml) }
        #expect(throws: TextFormatError.resourceLimit) { try TextFileDecoder.decode(Data(repeating: 65, count: 4 * 1024 * 1024 + 1), format: .mhtml) }
    }
    @Test func OriginalsFormatIdentityAndRejectedImportRemainIsolated() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-WebArchive-Service-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = TextFormatRepository(root: root)
        await #expect(throws: TextFormatError.self) { try await repository.importBook(Data("<invoice/>".utf8), filename: "unsupported.xml") }
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("text-formats-v1.json").path))
        let data = Data(OriginalWebArchiveFixtures.xhtml.utf8)
        let xhtml = try await repository.importBook(data, filename: "Original.XHTML")
        let xml = try await repository.importBook(data, filename: "Original.XML")
        #expect(xhtml.id != xml.id && xhtml.fileSHA256 == xml.fileSHA256 && xhtml.editionID != xml.editionID)
        #expect(try await repository.importBook(data, filename: "renamed.xhtml").id == xhtml.id)
        #expect(try await repository.read(xhtml) == data)
        #expect(try await repository.read(xml) == data)
        let mhtml = try await repository.importBook(OriginalWebArchiveFixtures.mhtml, filename: "Original.MHTML")
        #expect(try await repository.read(mhtml) == OriginalWebArchiveFixtures.mhtml)
        #expect(try await TextFormatRepository(root: root).load().books.count == 3)
        for name in ["library-v1.json", "epub-v1.json", "docx-mammoth-v1.json", "learning-v1.json"] {
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent(name).path))
        }
    }
}
