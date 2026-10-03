// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import zlib
import PDFnoDomain
@testable import PDFnoServices
@testable import PDFnoUI

/// Original synthetic OOXML/ZIP fixtures are generated in memory; no user or third-party documents.
private enum ConversionFixture {
    static let wordNS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
    static let types = "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Default Extension=\"xml\" ContentType=\"application/xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>"
    static let relationships = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"rId1\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>"
    static func document(_ body: String, namespace: String = wordNS) -> String { "<w:document xmlns:w=\"" + namespace + "\"><w:body>" + body + "</w:body></w:document>" }
    static func members(_ xml: String = document("<w:p><w:r><w:t>Original 日本語🌸 café</w:t></w:r></w:p>")) -> [(String, Data)] {
        [("[Content_Types].xml", Data(types.utf8)), ("_rels/.rels", Data(relationships.utf8)), ("word/document.xml", Data(xml.utf8))]
    }
    static func append(_ value: Int, width: Int, to data: inout Data) {
        for shift in 0..<width { data.append(UInt8(truncatingIfNeeded: value >> (8 * shift))) }
    }
    static func set(_ value: Int, width: Int, at offset: Int, in data: inout Data) {
        for shift in 0..<width { data[offset + shift] = UInt8(truncatingIfNeeded: value >> (8 * shift)) }
    }
    static func rawDeflate(_ data: Data) throws -> Data {
        var compressed = [UInt8](repeating: 0, count: Int(compressBound(uLong(data.count))))
        var count = uLongf(compressed.count)
        let status = data.withUnsafeBytes { input in
            compressed.withUnsafeMutableBufferPointer { output in
                compress2(output.baseAddress, &count, input.bindMemory(to: Bytef.self).baseAddress, uLong(input.count), Z_BEST_COMPRESSION)
            }
        }
        guard status == Z_OK else { throw ConversionError.invalidArchive }
        return Data(compressed[2..<(Int(count) - 4)])
    }
    static func zip(_ members: [(String, Data)] = members(), deflated: Bool = true, descriptor: Bool = false) throws -> Data {
        var local = Data(), central = Data()
        for (name, body) in members {
            let nameBytes = Data(name.utf8), offset = local.count, compressed = try deflated ? rawDeflate(body) : body
            let crc = body.withUnsafeBytes { crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt($0.count)) }
            let flags = 0x0800 | (descriptor ? 8 : 0), method = deflated ? 8 : 0
            append(0x04034b50, width: 4, to: &local)
            for value in [20, flags, method, 0, 0] { append(value, width: 2, to: &local) }
            for value in [descriptor ? 0 : Int(crc), descriptor ? 0 : compressed.count, descriptor ? 0 : body.count] { append(value, width: 4, to: &local) }
            append(nameBytes.count, width: 2, to: &local); append(0, width: 2, to: &local)
            local.append(nameBytes); local.append(compressed)
            if descriptor {
                for value in [0x08074b50, Int(crc), compressed.count, body.count] { append(value, width: 4, to: &local) }
            }
            append(0x02014b50, width: 4, to: &central)
            for value in [20, 20, flags, method, 0, 0] { append(value, width: 2, to: &central) }
            for value in [Int(crc), compressed.count, body.count] { append(value, width: 4, to: &central) }
            for value in [nameBytes.count, 0, 0, 0, 0] { append(value, width: 2, to: &central) }
            append(0, width: 4, to: &central); append(offset, width: 4, to: &central); central.append(nameBytes)
        }
        let start = local.count; local.append(central)
        append(0x06054b50, width: 4, to: &local)
        for value in [0, 0, members.count, members.count] { append(value, width: 2, to: &local) }
        append(central.count, width: 4, to: &local); append(start, width: 4, to: &local); append(0, width: 2, to: &local)
        return local
    }
    static func centralOffsets(_ data: Data) -> [Int] {
        var offsets: [Int] = []
        for p in 0..<(data.count - 4) where Array(data[p..<(p + 4)]) == [0x50, 0x4b, 0x01, 0x02] { offsets.append(p) }
        return offsets
    }
    static func temporaryRoot() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Conversion-Tests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
}

private final class ConversionCancellationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var entered = false
    private let release = DispatchSemaphore(value: 0)
    var hasEntered: Bool { lock.withLock { entered } }
    func enter() { lock.withLock { entered = true }; release.wait() }
    func resume() { release.signal() }
}

private struct CancellationProbeAdapter: DocumentConversionAdapter {
    let gate: ConversionCancellationGate
    var capabilities: [ConversionCapability] { [ConversionCapability(input: .docx, output: .plainText, adapterID: "test-cancellation-probe")] }
    func convert(_ source: Data, to output: ConversionFormat, progress: @Sendable (ConversionPhase) -> Void) throws -> ConvertedDocument {
        gate.enter()
        try Task.checkCancellation()
        return ConvertedDocument(data: Data("synthetic output".utf8), warnings: [])
    }
}

struct ConversionTests {
    @Test func supportedDirectionsAreExplicit() async throws {
        let service = DocumentConversionService()
        #expect(service.capabilities.count == 2)
        #expect(service.capabilities.allSatisfy { $0.input == .docx && [.plainText, .html].contains($0.output) })
        await #expect(throws: ConversionError.unsupportedDirection) {
            try await service.convert(ConversionRequest(source: URL(fileURLWithPath: "/tmp/input.pdf"), destination: URL(fileURLWithPath: "/tmp/output.docx"), input: .html, output: .docx))
        }
    }

    @Test(arguments: [false, true]) func storedAndDeflatedDOCXPreserveUnicode(deflated: Bool) throws {
        let data = try DOCXTextConversionAdapter().convert(ConversionFixture.zip(deflated: deflated), to: .plainText)
        #expect(String(decoding: data.data, as: UTF8.self) == "Original 日本語🌸 café\n")
        #expect(data.warnings == [.bodyOnly, .simplifiedLayout])
    }

    @Test func descriptorZIPAndStrictNamespacesWork() throws {
        let xml = ConversionFixture.document("<w:p><w:r><w:t>Strict text</w:t></w:r></w:p>", namespace: "http://purl.oclc.org/ooxml/wordprocessingml/main")
        let output = try DOCXTextConversionAdapter().convert(ConversionFixture.zip(ConversionFixture.members(xml), descriptor: true), to: .plainText)
        #expect(String(decoding: output.data, as: UTF8.self) == "Strict text\n")
    }

    @Test func paragraphsTablesRevisionsRubyAndFieldsHaveDocumentedTextSemantics() throws {
        let body = """
        <w:p><w:r><w:t xml:space="preserve"> One </w:t><w:tab/><w:t>Two</w:t><w:br/><w:t>Three</w:t></w:r></w:p>
        <w:p><w:del><w:r><w:t>Deleted</w:t></w:r></w:del><w:ins><w:r><w:t>Inserted</w:t></w:r></w:ins><w:r><w:instrText>HYPERLINK https://example.invalid</w:instrText><w:t>Cached field</w:t></w:r><w:ruby><w:rt><w:r><w:t>ほん</w:t></w:r></w:rt><w:rubyBase><w:r><w:t>本</w:t></w:r></w:rubyBase></w:ruby></w:p>
        <w:tbl><w:tr><w:tc><w:p><w:r><w:t>A</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>B</w:t></w:r></w:p><w:p><w:r><w:t>C</w:t></w:r></w:p></w:tc></w:tr></w:tbl>
        <w:p><w:r><w:drawing><w:txbxContent><w:p><w:r><w:t>Hidden textbox</w:t></w:r></w:p></w:txbxContent></w:drawing></w:r></w:p>
        """
        let converted = try DOCXTextConversionAdapter().convert(ConversionFixture.zip(ConversionFixture.members(ConversionFixture.document(body))), to: .plainText)
        #expect(String(decoding: converted.data, as: UTF8.self) == " One \tTwo\nThree\nInsertedCached field本\nA\tB\nC\n\n")
    }

    @Test func HTMLIsStandaloneEscapedTextWithNoActiveResources() throws {
        let xml = ConversionFixture.document("<w:p><w:r><w:t>&lt;script&gt;evil()&lt;/script&gt; &amp; &quot; &#39; 日本語</w:t></w:r></w:p>")
        let output = try DOCXTextConversionAdapter().convert(ConversionFixture.zip(ConversionFixture.members(xml)), to: .html)
        let html = String(decoding: output.data, as: UTF8.self)
        #expect(html.contains("<meta charset=\"utf-8\">")); #expect(html.contains("default-src 'none'"))
        #expect(html.contains("&lt;script&gt;evil()&lt;/script&gt; &amp; &quot; &#39; 日本語"))
        #expect(!html.contains("<script>")); #expect(!html.contains("src=\"")); #expect(!html.contains("href=\""))
    }

    @Test func unsafeXMLAndWrongNamespacesAreRefused() throws {
        let unsafe = [
            "<!DOCTYPE w:document [<!ENTITY x SYSTEM 'file:///etc/passwd'>]>" + ConversionFixture.document("<w:p><w:r><w:t>&x;</w:t></w:r></w:p>"),
            "<!DOCTYPE w:document [<!ENTITY x 'expanded'>]>" + ConversionFixture.document("<w:p><w:r><w:t>&x;</w:t></w:r></w:p>"),
            "<w:document", "<?xml version='1.0' encoding='ISO-8859-1'?>" + ConversionFixture.document("<w:p><w:r><w:t>café</w:t></w:r></w:p>"),
            ConversionFixture.document("<w:p/>", namespace: "https://example.invalid/word"),
            "<w:document xmlns:w=\"" + ConversionFixture.wordNS + "\"><w:body/><w:body/></w:document>"]
        for xml in unsafe {
            #expect(throws: ConversionError.invalidDocument) { try DOCXTextConversionAdapter().convert(ConversionFixture.zip(ConversionFixture.members(xml)), to: .plainText) }
        }
        var utf16 = ConversionFixture.members(); utf16[2].1 = ConversionFixture.document("<w:p/>").data(using: .utf16)!
        #expect(throws: ConversionError.invalidDocument) { try DOCXTextConversionAdapter().convert(ConversionFixture.zip(utf16), to: .plainText) }
    }

    @Test func macroExternalMainPartAlternateContentAndMissingPartsAreRefused() throws {
        var macro = ConversionFixture.members(); macro[0].1 = Data(ConversionFixture.types.replacingOccurrences(of: "wordprocessingml.document.main+xml", with: "ms-word.document.macroEnabled.main+xml").utf8)
        var external = ConversionFixture.members(); external[1].1 = Data(ConversionFixture.relationships.replacingOccurrences(of: "Target=", with: "TargetMode=\"External\" Target=").utf8)
        var alternate = ConversionFixture.members(ConversionFixture.document("<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"/>"))
        alternate.append(("word/vbaProject.bin", Data("synthetic".utf8)))
        for members in [macro, external, alternate, ConversionFixture.members(ConversionFixture.document("<w:altChunk/>")),
                        ConversionFixture.members(ConversionFixture.document("<w:subDoc/>")),
                        ConversionFixture.members(ConversionFixture.document("<mc:AlternateContent xmlns:mc=\"http://schemas.openxmlformats.org/markup-compatibility/2006\"/>"))] {
            #expect(throws: ConversionError.unsupportedDocument) { try DOCXTextConversionAdapter().convert(ConversionFixture.zip(members), to: .plainText) }
        }
        #expect(throws: ConversionError.invalidDocument) { try DOCXTextConversionAdapter().convert(ConversionFixture.zip(Array(ConversionFixture.members().dropLast())), to: .plainText) }
    }

    @Test func ZIPPathsFlagsMethodsDuplicatesCRCAndLocalNamesAreChecked() throws {
        let valid = try ConversionFixture.zip(deflated: false), central = ConversionFixture.centralOffsets(valid)
        var encrypted = valid; ConversionFixture.set(0x0801, width: 2, at: 6, in: &encrypted); ConversionFixture.set(0x0801, width: 2, at: central[0] + 8, in: &encrypted)
        var method = valid; ConversionFixture.set(99, width: 2, at: 8, in: &method); ConversionFixture.set(99, width: 2, at: central[0] + 10, in: &method)
        var localName = valid; localName[30] = UInt8(ascii: "X")
        var crc = valid; ConversionFixture.set(0, width: 4, at: 14, in: &crc); ConversionFixture.set(0, width: 4, at: central[0] + 16, in: &crc)
        var symlink = valid; ConversionFixture.set(0xa000 << 16, width: 4, at: central[0] + 38, in: &symlink)
        var overlap = valid; ConversionFixture.set(0, width: 4, at: central[1] + 42, in: &overlap)
        for bytes in [encrypted, method, localName, crc, symlink, overlap,
                      try ConversionFixture.zip(ConversionFixture.members() + [("../escape", Data())]),
                      try ConversionFixture.zip(ConversionFixture.members() + [("WORD/document.xml", Data())])] {
            #expect(throws: ConversionError.invalidArchive) { try DOCXTextConversionAdapter().convert(bytes, to: .plainText) }
        }
    }

    @Test func compressedBombIsStoppedByActualBytesEvenWithLyingHeaders() throws {
        let xml = ConversionFixture.document("<w:p><w:r><w:t>" + String(repeating: "A", count: DOCXConversionArchive.entryLimit + 1) + "</w:t></w:r></w:p>")
        var zip = try ConversionFixture.zip(ConversionFixture.members(xml))
        let central = ConversionFixture.centralOffsets(zip)[2]
        func u32(_ offset: Int) -> Int { (0..<4).reduce(0) { $0 | Int(zip[offset + $1]) << (8 * $1) } }
        let local = u32(central + 42)
        ConversionFixture.set(1, width: 4, at: central + 24, in: &zip); ConversionFixture.set(1, width: 4, at: local + 22, in: &zip)
        #expect(throws: ConversionError.resourceLimit) { try DOCXTextConversionAdapter().convert(zip, to: .plainText) }
        var tooMany = try ConversionFixture.zip(); let end = tooMany.count - 22
        ConversionFixture.set(1001, width: 2, at: end + 8, in: &tooMany); ConversionFixture.set(1001, width: 2, at: end + 10, in: &tooMany)
        #expect(throws: ConversionError.resourceLimit) { try DOCXTextConversionAdapter().convert(tooMany, to: .plainText) }
        let nested = ConversionFixture.document(String(repeating: "<w:sdt>", count: 256) + String(repeating: "</w:sdt>", count: 256))
        #expect(throws: ConversionError.resourceLimit) { try DOCXTextConversionAdapter().convert(ConversionFixture.zip(ConversionFixture.members(nested)), to: .plainText) }
    }

    @Test func realServiceExportsWithoutChangingOriginalOrExistingFiles() async throws {
        let root = try ConversionFixture.temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.docx"), destination = root.appendingPathComponent("copy.txt"), bytes = try ConversionFixture.zip()
        try bytes.write(to: source)
        let result = try await DocumentConversionService().convert(ConversionRequest(source: source, destination: destination, output: .plainText))
        #expect(result.destination == destination); #expect(result.byteCount > 0)
        #expect(try Data(contentsOf: source) == bytes)
        #expect(try String(contentsOf: destination, encoding: .utf8) == "Original 日本語🌸 café\n")
        await #expect(throws: ConversionError.destinationExists) { try await DocumentConversionService().convert(ConversionRequest(source: source, destination: destination, output: .plainText)) }
        #expect(try String(contentsOf: destination, encoding: .utf8) == "Original 日本語🌸 café\n")
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == ["copy.txt", "original.docx"])
    }

    @Test func lateDestinationRaceCleansStagingFileAndRetrySucceeds() async throws {
        let root = try ConversionFixture.temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.docx"), output = root.appendingPathComponent("copy.txt")
        try ConversionFixture.zip().write(to: source)
        await #expect(throws: ConversionError.destinationExists) {
            try await DocumentConversionService().convert(ConversionRequest(source: source, destination: output, output: .plainText)) { phase in
                if phase == .writing { try? Data("existing".utf8).write(to: output) }
            }
        }
        #expect(try String(contentsOf: output, encoding: .utf8) == "existing")
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).count == 2)
        let retry = root.appendingPathComponent("retry.html")
        let result = try await DocumentConversionService().convert(ConversionRequest(source: source, destination: retry, output: .html))
        #expect(result.destination == retry); #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).count == 3)
    }

    @Test(arguments: [ConversionPhase.reading, .validating, .converting, .writing])
    func cancellationLeavesNoOutputAndAllowsRetry(phase: ConversionPhase) async throws {
        let root = try ConversionFixture.temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.docx"), output = root.appendingPathComponent("copy.txt"), bytes = try ConversionFixture.zip()
        try bytes.write(to: source)
        await #expect(throws: CancellationError.self) {
            try await DocumentConversionService().convert(ConversionRequest(source: source, destination: output, output: .plainText)) { event in
                if event == phase { withUnsafeCurrentTask { $0?.cancel() } }
            }
        }
        #expect(try Data(contentsOf: source) == bytes)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["original.docx"])
        _ = try await DocumentConversionService().convert(ConversionRequest(source: source, destination: output, output: .plainText))
        #expect(FileManager.default.fileExists(atPath: output.path))
    }

    @Test func cancellationAfterCommitReportsCompletion() async throws {
        let root = try ConversionFixture.temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.docx"), output = root.appendingPathComponent("copy.txt")
        try ConversionFixture.zip().write(to: source)
        let result = try await DocumentConversionService().convert(ConversionRequest(source: source, destination: output, output: .plainText)) { phase in
            if phase == .completed { withUnsafeCurrentTask { $0?.cancel() } }
        }
        #expect(result.byteCount == (try Data(contentsOf: output)).count)
    }

    @Test func callerCancellationPropagatesIntoDetachedWorker() async throws {
        let root = try ConversionFixture.temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.docx"), output = root.appendingPathComponent("copy.txt")
        try ConversionFixture.zip().write(to: source)
        let gate = ConversionCancellationGate()
        let service = DocumentConversionService(adapters: [CancellationProbeAdapter(gate: gate)])
        let caller = Task { try await service.convert(ConversionRequest(source: source, destination: output, output: .plainText)) }
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !gate.hasEntered, ContinuousClock.now < deadline { await Task.yield() }
        #expect(gate.hasEntered)
        caller.cancel(); gate.resume()
        await #expect(throws: CancellationError.self) { try await caller.value }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["original.docx"])
    }

    @Test func symbolicLinksOriginalPathWrongExtensionsAndNonFilesAreRefused() async throws {
        let root = try ConversionFixture.temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.docx"), output = root.appendingPathComponent("copy.txt"), bytes = try ConversionFixture.zip()
        try bytes.write(to: source)
        let sourceLink = root.appendingPathComponent("alias.docx")
        try FileManager.default.createSymbolicLink(at: sourceLink, withDestinationURL: source)
        await #expect(throws: ConversionError.invalidSource) { try await DocumentConversionService().convert(ConversionRequest(source: sourceLink, destination: output, output: .plainText)) }
        let outputLink = root.appendingPathComponent("alias.txt")
        try FileManager.default.createSymbolicLink(at: outputLink, withDestinationURL: source)
        await #expect(throws: ConversionError.invalidDestination) { try await DocumentConversionService().convert(ConversionRequest(source: source, destination: outputLink, output: .plainText)) }
        let dangling = root.appendingPathComponent("dangling.txt")
        try FileManager.default.createSymbolicLink(at: dangling, withDestinationURL: root.appendingPathComponent("absent"))
        await #expect(throws: ConversionError.destinationExists) { try await DocumentConversionService().convert(ConversionRequest(source: source, destination: dangling, output: .plainText)) }
        await #expect(throws: ConversionError.invalidDestination) { try await DocumentConversionService().convert(ConversionRequest(source: source, destination: source, output: .plainText)) }
        let directory = root.appendingPathComponent("directory.docx"); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        await #expect(throws: ConversionError.invalidSource) { try await DocumentConversionService().convert(ConversionRequest(source: directory, destination: output, output: .plainText)) }
        #expect(try Data(contentsOf: source) == bytes)
    }

    @Test func invalidDocumentFailureCanBeRetriedWithValidSource() async throws {
        let root = try ConversionFixture.temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.docx"), output = root.appendingPathComponent("copy.txt")
        try Data("not DOCX".utf8).write(to: source)
        await #expect(throws: ConversionError.invalidArchive) { try await DocumentConversionService().convert(ConversionRequest(source: source, destination: output, output: .plainText)) }
        #expect(!FileManager.default.fileExists(atPath: output.path))
        try ConversionFixture.zip().write(to: source)
        _ = try await DocumentConversionService().convert(ConversionRequest(source: source, destination: output, output: .plainText))
        #expect(FileManager.default.fileExists(atPath: output.path))
    }

    #if os(macOS)
    @MainActor @Test func MacModelReturnsToReadyAfterFailureAndSuccessfulRetry() async throws {
        let root = try ConversionFixture.temporaryRoot(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("original.docx"), output = root.appendingPathComponent("copy.txt")
        try ConversionFixture.zip().write(to: source); try Data("existing".utf8).write(to: output)
        let model = ConversionModel(); model.select(source)
        model.start(source: source, destination: output, output: .plainText)
        while model.isRunning { await Task.yield() }
        #expect(model.result == nil); #expect(model.status.contains("输出位置已有文件")); #expect(!model.isBusy)
        let retry = root.appendingPathComponent("retry.txt")
        model.start(source: source, destination: retry, output: .plainText)
        while model.isRunning { await Task.yield() }
        #expect(model.result?.destination == retry); #expect(model.phase == .completed); #expect(!model.isBusy)
    }
    #endif
}
