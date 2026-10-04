// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import AppKit
import PDFKit
import CryptoKit
import Testing
import PDFnoDomain
import PDFnoServices
import PDFnoUI
@testable import PDFnoReaders

private final class ReadingPDFPhases: @unchecked Sendable {
    private let lock = NSLock()
    private var events: [ConversionPhase] = []
    var values: [ConversionPhase] { lock.withLock { events } }
    func record(_ phase: ConversionPhase) { lock.withLock { events.append(phase) } }
}

/// Original in-memory DOCX; no external sample, real app, visible window, store or network.
@Suite(.serialized)
struct DOCXReadingPDFTests {
    private static func fixture(paragraphs: Int = 85) throws -> Data {
        let paragraph = "原创中文段落。日本語の本文を読みます。Plain reading text café."
        let body = "<w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr><w:r><w:t>原创阅读版 / 日本語</w:t></w:r></w:p>" +
            "<w:p><w:r><w:rPr><w:b/></w:rPr><w:t>Bold original</w:t></w:r><w:r><w:rPr><w:i/></w:rPr><w:t> and italic original</w:t></w:r></w:p>" +
            "<w:p><w:pPr><w:numPr><w:ilvl w:val=\"0\"/><w:numId w:val=\"1\"/></w:numPr></w:pPr><w:r><w:t>Original list item</w:t></w:r></w:p>" +
            "<w:tbl><w:tr><w:tc><w:p><w:r><w:t>表格甲 / セル一</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>表格乙 / セル二</w:t></w:r></w:p></w:tc></w:tr></w:tbl>" +
            (0..<paragraphs).map { "<w:p><w:r><w:t>Row\($0)-start " + String(repeating: paragraph, count: 4) + " Row\($0)-end</w:t></w:r></w:p>" }.joined()
        var members = ConversionFixture.members(ConversionFixture.document(body))
        let ns = ConversionFixture.wordNS
        members.append(("word/styles.xml", Data("<w:styles xmlns:w=\"\(ns)\"><w:style w:type=\"paragraph\" w:styleId=\"Heading1\"><w:name w:val=\"heading 1\"/></w:style></w:styles>".utf8)))
        members.append(("word/numbering.xml", Data("<w:numbering xmlns:w=\"\(ns)\"><w:abstractNum w:abstractNumId=\"0\"><w:lvl w:ilvl=\"0\"><w:start w:val=\"1\"/><w:numFmt w:val=\"decimal\"/><w:lvlText w:val=\"%1.\"/></w:lvl></w:abstractNum><w:num w:numId=\"1\"><w:abstractNumId w:val=\"0\"/></w:num></w:numbering>".utf8)))
        members.append(("word/_rels/document.xml.rels", Data("<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"styles\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/><Relationship Id=\"numbering\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/numbering\" Target=\"numbering.xml\"/></Relationships>".utf8)))
        return try ConversionFixture.zip(members)
    }
    private func directory() throws -> URL { try ConversionFixture.temporaryRoot() }
    @MainActor private func prohibitWindows() -> Int {
        NSApplication.shared.setActivationPolicy(.prohibited)
        return NSApplication.shared.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count
    }

    @Test @MainActor func actualMammothFileToPDFPreservesSourceExtractsCJKAndPaginatesInsideMargins() async throws {
        let windows = prohibitWindows(), root = try directory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("原创.docx"), destination = root.appendingPathComponent("阅读版.pdf")
        let original = try Self.fixture(); try original.write(to: source)
        let phases = ReadingPDFPhases()
        let result = try await DOCXReadingPDFService().convert(source: source, destination: destination) { phases.record($0) }
        let report = try #require(result.readingPDFReport)
        #expect(result.adapterID == DOCXReadingPDFConversionAdapter.adapterID)
        #expect(report.semanticEngineID == "kookit-mammoth-1.13.0" && report.extractionVersion == DOCXDocument.extractionVersion)
        #expect(report.sourceSHA256 == SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined())
        #expect(report.pageCount > 3 && report.semanticBlockCount == 90 && report.canonicalUTF16Count > 10000)
        #expect(report.fonts.contains { $0.contains("PingFang") || $0.contains("Hiragino") })
        let pdf = try #require(PDFDocument(url: destination))
        #expect(pdf.pageCount == report.pageCount && !pdf.isEncrypted)
        #expect((pdf.documentAttributes?[PDFDocumentAttribute.subjectAttribute] as? String)?.contains(report.sourceSHA256) == true)
        let text = try #require(pdf.string)
        #expect(text.contains("阅读版PDF") && text.contains("原创阅读版") && text.contains("日本語"))
        #expect(text.contains("Bold original") && text.contains("italic original") && text.contains("Original list item"))
        #expect(text.contains("表格甲") && text.contains("表格乙"))
        for row in 0..<85 { #expect(text.contains("Row\(row)-start") && text.contains("Row\(row)-end")) }
        for index in 0..<pdf.pageCount {
            let page = try #require(pdf.page(at: index)), box = page.bounds(for: .mediaBox)
            #expect(abs(box.width - report.settings.pageWidth) < 0.1 && abs(box.height - report.settings.pageHeight) < 0.1)
            let footer = try #require(page.selection(for: CGRect(x: 0, y: 20, width: box.width, height: 24))?.string)
            #expect(footer.trimmingCharacters(in: .whitespacesAndNewlines) == String(index + 1))
            for character in 0..<page.numberOfCharacters {
                let rect = page.characterBounds(at: character)
                if !rect.isEmpty {
                    #expect(rect.minX >= 46 && rect.maxX <= box.width - 46)
                    #expect(rect.minY >= 20 && rect.maxY <= box.height - 20)
                }
            }
        }
        #expect(phases.values.first == .reading && phases.values.contains(.validating) && phases.values.contains(.converting))
        #expect(phases.values.filter { $0 == .paginating }.count == report.pageCount + 1)
        #expect(phases.values.suffix(2) == [.writing, .completed])
        #expect(try Data(contentsOf: source) == original)
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted() == [source.lastPathComponent, destination.lastPathComponent].sorted())
        #expect(NSApplication.shared.windows.filter { $0.isVisible || $0.isKeyWindow || $0.isMainWindow }.count == windows)
        // Optional original-only evidence, constrained to the temporary directory and excluded from Git.
        if ProcessInfo.processInfo.environment["PDFNO_READING_PDF_EVIDENCE"] == "1" {
            let evidence = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-ReadingPDF-Evidence")
            try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
            try Data(contentsOf: destination).write(to: evidence.appendingPathComponent("original-reading.pdf"))
            for index in 0..<pdf.pageCount {
                let image = try #require(pdf.page(at: index)).thumbnail(of: NSSize(width: 800, height: 1132), for: .mediaBox)
                let tiff = try #require(image.tiffRepresentation), bitmap = try #require(NSBitmapImageRep(data: tiff))
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: evidence.appendingPathComponent("page-\(index + 1).png"))
            }
            print("Original reading PDF visual evidence:", evidence.path, "; pages:", report.pageCount, "; bytes:", result.byteCount, "; fonts:", report.fonts)
        }
    }

    @Test(arguments: [ConversionPhase.reading, .validating, .converting, .paginating, .writing])
    @MainActor func cancellationBeforeCommitLeavesOnlyOriginal(_ phase: ConversionPhase) async throws {
        _ = prohibitWindows()
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.docx"), destination = root.appendingPathComponent("cancelled.pdf")
        let original = try Self.fixture(paragraphs: 3); try original.write(to: source)
        await #expect(throws: CancellationError.self) {
            try await DOCXReadingPDFService().convert(source: source, destination: destination) { event in
                if event == phase { withUnsafeCurrentTask { $0?.cancel() } }
            }
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["source.docx"])
        #expect(try Data(contentsOf: source) == original)
    }

    @Test @MainActor func realPageCancellationAndPostCommitCancellationHaveDefinedOutcomes() async throws {
        _ = prohibitWindows()
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.docx"), destination = root.appendingPathComponent("cancelled.pdf")
        try Self.fixture().write(to: source)
        let phases = ReadingPDFPhases()
        await #expect(throws: CancellationError.self) {
            try await DOCXReadingPDFService().convert(source: source, destination: destination) { phase in
                phases.record(phase)
                if phases.values.filter({ $0 == .paginating }).count == 2 { withUnsafeCurrentTask { $0?.cancel() } }
            }
        }
        #expect(!FileManager.default.fileExists(atPath: destination.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["source.docx"])
        let result = try await DOCXReadingPDFService().convert(source: source, destination: destination) { phase in
            if phase == .completed { withUnsafeCurrentTask { $0?.cancel() } }
        }
        #expect(result.readingPDFReport?.pageCount ?? 0 > 0 && PDFDocument(url: destination) != nil)
    }

    @Test @MainActor func existingAndLateDestinationsRemainUnchangedAndModelCanRetry() async throws {
        _ = prohibitWindows()
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.docx"), destination = root.appendingPathComponent("existing.pdf")
        let original = try Self.fixture(paragraphs: 2), sentinel = Data("Original existing PDF sentinel".utf8)
        try original.write(to: source); try sentinel.write(to: destination)
        await #expect(throws: ConversionError.destinationExists) { try await DOCXReadingPDFService().convert(source: source, destination: destination) }
        #expect(try Data(contentsOf: destination) == sentinel)
        let late = root.appendingPathComponent("late.pdf")
        await #expect(throws: ConversionError.destinationExists) {
            try await DOCXReadingPDFService().convert(source: source, destination: late) { phase in
                if phase == .writing { try! sentinel.write(to: late) }
            }
        }
        #expect(try Data(contentsOf: late) == sentinel)
        let invalid = root.appendingPathComponent("invalid.docx"); try Data("Original invalid document".utf8).write(to: invalid)
        let output = root.appendingPathComponent("retry.pdf"), model = DOCXReadingPDFExportModel(source: invalid)
        model.start(source: invalid, destination: output)
        while model.isRunning { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.result == nil && !FileManager.default.fileExists(atPath: output.path))
        model.select(source); model.start(source: source, destination: output)
        while model.isRunning { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.result?.readingPDFReport != nil && model.status.contains("阅读版PDF"))
        #expect(try Data(contentsOf: source) == original)
        #expect(!(try FileManager.default.contentsOfDirectory(atPath: root.path)).contains { $0.hasPrefix(".pdfno-conversion-") })
    }

    @Test @MainActor func existingOriginalMammothFixtureExportsWithoutRewritingSource() async throws {
        _ = prohibitWindows()
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let fixture = try #require(Bundle.module.url(forResource: "mammoth-sample", withExtension: "docx", subdirectory: "Fixtures/DOCX"))
        let original = try Data(contentsOf: fixture)
        let source = root.appendingPathComponent("original.docx"), output = root.appendingPathComponent("original.pdf")
        try original.write(to: source)
        let result = try await DOCXReadingPDFService().convert(source: source, destination: output)
        let pdf = try #require(PDFDocument(url: output)), text = try #require(pdf.string)
        #expect(text.contains("Original DOCX chapter") && text.contains("Second heading"))
        #expect(text.contains("日本語") && text.contains("window") && text.contains("🌸"))
        let expectedURL = try #require(Bundle.module.url(forResource: "mammoth-extraction", withExtension: "json", subdirectory: "Fixtures/DOCX"))
        let expected = try JSONDecoder().decode(DOCXDocument.self, from: Data(contentsOf: expectedURL))
        let compact = String(text.filter { !$0.isWhitespace })
        for block in expected.blocks {
            #expect(compact.contains(String(block.text.filter { !$0.isWhitespace })), "Every original semantic block remains extractable")
        }
        #expect(result.readingPDFReport?.canonicalUTF16Count ?? 0 > 0)
        #expect(try Data(contentsOf: source) == original)
    }

    @Test @MainActor func callerCancellationReachesAsyncSemanticWorkerAndLeavesNoOutput() async throws {
        _ = prohibitWindows()
        let root = try directory(); defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("source.docx"), output = root.appendingPathComponent("cancelled.pdf")
        let original = try Self.fixture(); try original.write(to: source)
        let phases = ReadingPDFPhases()
        let task = Task { try await DOCXReadingPDFService().convert(source: source, destination: output) { phases.record($0) } }
        let deadline = Date().addingTimeInterval(5)
        while !phases.values.contains(.converting) && Date() < deadline { await Task.yield() }
        #expect(phases.values.contains(.converting))
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path) == ["source.docx"])
        #expect(try Data(contentsOf: source) == original)
    }

    @Test @MainActor func explicitLineBreakTabsLongTokensAndUnicodeRemainReadable() throws {
        let text = "Original first line\n中文\t日本語🌸 café " + String(repeating: "LongToken", count: 90) + " END"
        let document = DOCXDocument(blocks: [.init(id: 0, runs: [.init(text)], start: 0)])
        let result = try DOCXReadingPDFRenderer.render(document, sourceSHA256: String(repeating: "a", count: 64))
        let pdf = try #require(PDFDocument(data: result.data)), extracted = try #require(pdf.string)
        #expect(extracted.contains("Original first line") && extracted.contains("中文") && extracted.contains("日本語🌸"))
        #expect(String(extracted.filter { !$0.isWhitespace }).contains(String(repeating: "LongToken", count: 90) + "END"))
    }

    @Test func layoutBoundariesMissingGlyphAndPageBudgetFailExplicitly() throws {
        let hash = String(repeating: "a", count: 64)
        #expect(throws: DOCXReadingPDFError.invalidSemanticDocument) { try DOCXReadingPDFRenderer.render(.init(blocks: []), sourceSHA256: hash) }
        let missing = DOCXDocument(blocks: [.init(id: 0, runs: [.init("Original \u{10FFFF}")], start: 0)])
        #expect(throws: DOCXReadingPDFError.missingGlyph) { try DOCXReadingPDFRenderer.render(missing, sourceSHA256: hash) }
        var blocks: [DOCXBlock] = [], offset = 0
        for id in 0..<10000 {
            let text = "Original page budget paragraph \(id)"
            blocks.append(.init(id: id, runs: [.init(text)], start: offset)); offset += text.utf16.count + 1
        }
        #expect(throws: DOCXReadingPDFError.resourceLimit) { try DOCXReadingPDFRenderer.render(.init(blocks: blocks), sourceSHA256: hash) }
    }
}
#endif
