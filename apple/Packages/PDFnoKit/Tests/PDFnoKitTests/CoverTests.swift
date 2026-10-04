// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import PDFKit
import Testing
import PDFnoDomain
@testable import PDFnoServices
@testable import PDFnoUI

/// Fresh roots and generated original documents/images only. No app, remote transport or private library.
private enum CoverFixture {
    static func root() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Covers-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true); return url
    }
    static func png(width: Int = 40, height: Int = 60, red: Bool = true) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: red ? 1 : 0, green: 0.2, blue: red ? 0 : 1, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return try CoverRaster.encode(#require(context.makeImage())).png
    }
    static func pdf() throws -> Data {
        let out = NSMutableData(), consumer = try #require(CGDataConsumer(data: out))
        var box = CGRect(x: 0, y: 0, width: 200, height: 300)
        let context = try #require(CGContext(consumer: consumer, mediaBox: &box, nil))
        for red in [true, false] {
            context.beginPDFPage(nil); context.setFillColor(CGColor(red: red ? 1 : 0, green: 0.2, blue: red ? 0 : 1, alpha: 1))
            context.fill(box); context.endPDFPage()
        }
        context.closePDF(); return out as Data
    }
    static func zip(_ entries: [(String, Data)]) -> Data {
        func u16(_ n: Int) -> Data { Data([UInt8(n & 255), UInt8((n >> 8) & 255)]) }
        func u32(_ n: Int) -> Data { u16(n & 65535) + u16((n >> 16) & 65535) }
        func crc(_ bytes: Data) -> Int {
            var value = UInt32.max
            for byte in bytes { value ^= UInt32(byte); for _ in 0..<8 { value = value & 1 == 0 ? value >> 1 : (value >> 1) ^ 0xedb88320 } }
            return Int(value ^ UInt32.max)
        }
        var local = Data(), central = Data()
        for (path, data) in entries {
            let name = Data(path.utf8), offset = local.count, checksum = crc(data)
            for field in [u32(0x04034b50), u16(20), u16(0x0800), u16(0), u16(0), u16(0), u32(checksum), u32(data.count), u32(data.count), u16(name.count), u16(0), name, data] { local.append(field) }
            for field in [u32(0x02014b50), u16(0x0314), u16(20), u16(0x0800), u16(0), u16(0), u16(0), u32(checksum), u32(data.count), u32(data.count), u16(name.count), u16(0), u16(0), u16(0), u16(0), u32(0x8000 << 16), u32(offset), name] { central.append(field) }
        }
        let start = local.count; local.append(central)
        for field in [u32(0x06054b50), u16(0), u16(0), u16(entries.count), u16(entries.count), u32(central.count), u32(start), u16(0)] { local.append(field) }
        return local
    }
    static func epub(mode: Int, image: Data) -> Data {
        let declaration: String
        switch mode {
        case 2: declaration = "<metadata><meta name='cover' content='art'/></metadata><manifest><item id='art' href='../Images/花.png' media-type='image/png'/></manifest>"
        case 1: declaration = "<manifest><item id='wrap' href='cover.xhtml' media-type='application/xhtml+xml'/></manifest><guide><reference type='cover' href='cover.xhtml#top'/></guide>"
        case 0: declaration = "<manifest/>"
        default: declaration = "<manifest><item id='art' href='../Images/花.png' media-type='image/png' properties='cover-image'/></manifest>"
        }
        return zip([("mimetype", Data("application/epub+zip".utf8)),
            ("META-INF/container.xml", Data("<container><rootfiles><rootfile full-path='OPS/Book/package.opf' media-type='application/oebps-package+xml'/></rootfiles></container>".utf8)),
            ("OPS/Book/package.opf", Data(("<package>" + declaration + "</package>").utf8)),
            ("OPS/Book/cover.xhtml", Data("<html><body><img src='../Images/花.png'/></body></html>".utf8)), ("OPS/Images/花.png", image)])
    }
    static func dimensions(_ png: Data) throws -> (Int, Int) {
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        return (try #require(properties[kCGImagePropertyPixelWidth] as? Int), try #require(properties[kCGImagePropertyPixelHeight] as? Int))
    }
    static func red(_ png: Data) throws -> Bool {
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil)), image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let context = try #require(CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let bytes = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        return bytes[0] > bytes[2]
    }
}

struct CoverTests {
    @Test func pdfFirstPageBoundedAndOriginalUnchanged() async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        let bytes = try CoverFixture.pdf(), source = LibraryRepository(root: root)
        let book = try await source.importPDF(bytes, filename: "Original.pdf", pageCount: 2)
        let covers = CoverRepository(root: root), result = try await covers.thumbnail(for: CoverIdentity(book))
        #expect(result.record.origin == .pdfFirstPage); #expect(result.record.mimeType == "image/png")
        #expect(result.record.byteLength > 0); #expect(result.record.identity.bookID == book.id)
        #expect(max(result.record.width, result.record.height) == CoverLimits.thumbnailDimension)
        #expect(try CoverFixture.red(#require(result.png)))
        #expect(try await source.readAsset(for: book) == bytes)
    }
    @Test func rotatedCropBoxPDFKeepsAspectAndBounds() throws {
        let document = try #require(PDFDocument(data: CoverFixture.pdf())), page = try #require(document.page(at: 0))
        page.setBounds(CGRect(x: 20, y: 30, width: 100, height: 200), for: .cropBox); page.rotation = 90
        let raster = try CoverRaster.pdf(#require(document.dataRepresentation()))
        #expect(raster.width == 512); #expect(raster.height == 256); #expect(try CoverFixture.red(raster.png))
    }
    @Test(arguments: [1, 2, 3]) func epub3MetaAndGuideResolveEmbeddedUnicodeCover(mode: Int) async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        let bytes = CoverFixture.epub(mode: mode, image: try CoverFixture.png()), source = EPUBRepository(root: root)
        let book = try await source.importBook(bytes, filename: "Original.epub")
        let result = try await CoverRepository(root: root).thumbnail(for: CoverIdentity(book))
        #expect(result.record.origin == .epubEmbedded); #expect(result.record.resourcePath == "OPS/Images/花.png")
        #expect(try CoverFixture.red(#require(result.png))); #expect(try await source.read(book) == bytes)
    }
    @Test func noEmbeddedCoverHasStablePlaceholderAcrossRestart() async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        let source = EPUBRepository(root: root), bytes = CoverFixture.epub(mode: 0, image: try CoverFixture.png())
        let book = try await source.importBook(bytes, filename: "Original no art.epub"), identity = CoverIdentity(book)
        let first = try await CoverRepository(root: root).thumbnail(for: identity)
        let second = try await CoverRepository(root: root).thumbnail(for: identity)
        #expect(first.record.origin == .placeholder); #expect(first.png == nil); #expect(first.record == second.record)
    }
    @Test func cbzCoverUsesNaturalFirstImageAndPreservesSource() async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        let bytes = CoverFixture.zip([("10.png", try CoverFixture.png(red: false)), ("2.png", try CoverFixture.png())])
        let source = ComicRepository(root: root), book = try await source.importBook(bytes, filename: "Original.cbz")
        let result = try await CoverRepository(root: root).thumbnail(for: CoverIdentity(book))
        #expect(result.record.origin == .cbzFirstImage); #expect(result.record.resourcePath == "2.png")
        #expect(try CoverFixture.red(#require(result.png))); #expect(try await source.read(book).data == bytes)
    }
    @Test func docxPlaceholderReplacementAndRestoreRemainStable() async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        // This original minimal package is used only by the cover service, which does not parse Word body content.
        let bytes = CoverFixture.zip([("word/document.xml", Data("<document><p>Original cover fixture</p></document>".utf8))])
        let book = DOCXBook(fileSHA256: LibraryRepository.digest(bytes), title: "Original Word", originalFilename: "Original.docx")
        let originals = root.appendingPathComponent("Originals"); try FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
        let asset = originals.appendingPathComponent(book.fileSHA256 + ".docx"); try bytes.write(to: asset)
        let identity = CoverIdentity(book), covers = CoverRepository(root: root)
        let placeholder = try await covers.thumbnail(for: identity)
        #expect(placeholder.record.origin == .placeholder); #expect(placeholder.png == nil)
        #expect(try await CoverRepository(root: root).thumbnail(for: identity).record == placeholder.record)
        let local = root.appendingPathComponent("original art.png"); try CoverFixture.png().write(to: local)
        _ = try await covers.replace(identity, withLocalImage: local)
        #expect(try await CoverRepository(root: root).thumbnail(for: identity).record.userEdited)
        #expect(try await covers.restoreAutomatic(identity).origin == .placeholder)
        #expect(try Data(contentsOf: asset) == bytes)
    }
    @Test func manualCoverReplacesCachedAutomaticSurvivesRestartAndRestore() async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        let bytes = try CoverFixture.pdf(), source = LibraryRepository(root: root)
        let book = try await source.importPDF(bytes, filename: "Original.pdf", pageCount: 2), identity = CoverIdentity(book)
        let manifest = root.appendingPathComponent("library-v1.json"), prior = try Data(contentsOf: manifest)
        let covers = CoverRepository(root: root), automatic = try await covers.thumbnail(for: identity)
        let local = root.appendingPathComponent("original blue art.png"), art = try CoverFixture.png(width: 2400, height: 1600, red: false)
        try art.write(to: local)
        let manual = try await covers.replace(identity, withLocalImage: local)
        #expect(manual.userEdited); #expect(manual.width == 1200); #expect(manual.revision == automatic.record.revision + 1)
        let first = try await covers.thumbnail(for: identity), restarted = try await CoverRepository(root: root).thumbnail(for: identity)
        #expect(first.record == manual); #expect(first.png == restarted.png); #expect(try !CoverFixture.red(#require(first.png)))
        let size = try CoverFixture.dimensions(#require(first.png)); #expect(size.0 == 512); #expect(size.1 <= 512)
        let restored = try await covers.restoreAutomatic(identity)
        #expect(restored.origin == .pdfFirstPage); #expect(restored.revision == manual.revision + 1)
        #expect(try CoverFixture.red(#require(try await covers.thumbnail(for: identity).png)))
        #expect(try Data(contentsOf: local) == art); #expect(try Data(contentsOf: manifest) == prior)
        #expect(try await source.readAsset(for: book) == bytes)
    }
    @Test func damagedDerivedCacheAndMissingAutoAssetRebuild() async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        let source = LibraryRepository(root: root), book = try await source.importPDF(CoverFixture.pdf(), filename: "Original.pdf", pageCount: 2)
        let identity = CoverIdentity(book), first = try await CoverRepository(root: root).thumbnail(for: identity)
        let folder = root.appendingPathComponent("Covers/Thumbnails")
        for url in try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) { try Data("original damaged cache fixture".utf8).write(to: url) }
        let rebuilt = try await CoverRepository(root: root).thumbnail(for: identity)
        #expect(rebuilt.png == first.png); #expect(rebuilt.record == first.record)
        let hash = try #require(first.record.imageSHA256)
        try FileManager.default.removeItem(at: root.appendingPathComponent("Covers/Assets/" + hash + ".png"))
        let recovered = try await CoverRepository(root: root).thumbnail(for: identity)
        #expect(recovered.png == first.png); #expect(recovered.record.revision == first.record.revision + 1)
    }
    @Test func changedSourceIdentityInvalidatesOldCover() async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        let source = LibraryRepository(root: root), book = try await source.importPDF(CoverFixture.pdf(), filename: "Original.pdf", pageCount: 2)
        let covers = CoverRepository(root: root); _ = try await covers.thumbnail(for: CoverIdentity(book))
        let newIdentity = CoverIdentity(bookID: book.id, editionID: UUID(), fileSHA256: book.fileSHA256, format: .pdf)
        #expect(try await covers.record(for: newIdentity) == nil)
        #expect(try await covers.thumbnail(for: newIdentity).record.identity == newIdentity)
    }
    @Test func newEditionAndExtractorVersionKeepUserChosenCover() async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        let source = LibraryRepository(root: root), book = try await source.importPDF(CoverFixture.pdf(), filename: "Original.pdf", pageCount: 2)
        let covers = CoverRepository(root: root), local = root.appendingPathComponent("original art.png")
        try CoverFixture.png(red: false).write(to: local)
        let manual = try await covers.replace(CoverIdentity(book), withLocalImage: local)
        let manifest = root.appendingPathComponent("covers-v1.json")
        var object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: manifest)) as? [String: Any])
        var records = try #require(object["records"] as? [[String: Any]]); records[0]["extractorVersion"] = "older-cover-fixture"
        object["records"] = records; try JSONSerialization.data(withJSONObject: object).write(to: manifest)
        let identity = CoverIdentity(bookID: book.id, editionID: UUID(), fileSHA256: book.fileSHA256, format: .pdf)
        let result = try await CoverRepository(root: root).thumbnail(for: identity)
        #expect(result.record.userEdited); #expect(result.record.identity == identity)
        #expect(result.record.imageSHA256 == manual.imageSHA256); #expect(try !CoverFixture.red(#require(result.png)))
        #expect(result.record.extractorVersion == "older-cover-fixture")
    }
    @Test func replacementFailureKeepsPriorCoverAndFutureStoreUntouched() async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        let source = LibraryRepository(root: root), book = try await source.importPDF(CoverFixture.pdf(), filename: "Original.pdf", pageCount: 2)
        let covers = CoverRepository(root: root), identity = CoverIdentity(book), prior = try await covers.thumbnail(for: identity)
        let local = root.appendingPathComponent("original bad art.png"); try Data("Original invalid image".utf8).write(to: local)
        await #expect(throws: CoverError.self) { try await covers.replace(identity, withLocalImage: local) }
        #expect(try await covers.record(for: identity) == prior.record)
        let manifest = root.appendingPathComponent("covers-v1.json"), future = Data(#"{"schemaVersion":2,"records":[]}"#.utf8)
        try future.write(to: manifest)
        await #expect(throws: CoverError.unsupportedSchema) { try await covers.restoreAutomatic(identity) }
        #expect(try Data(contentsOf: manifest) == future)
    }
    @Test func invalidDimensionAndMultiFrameAreRejectedBeforeRasterAllocation() throws {
        let data = try CoverFixture.png(width: 16001, height: 1)
        #expect(throws: CoverError.resourceLimit) { try CoverRaster.image(data, maximum: 512) }
        let imageSource = try #require(CGImageSourceCreateWithData(CoverFixture.png() as CFData, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(imageSource, 0, nil)), out = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(out, UTType.tiff.identifier as CFString, 2, nil))
        CGImageDestinationAddImage(destination, image, nil); CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        #expect(throws: CoverError.invalidImage) { try CoverRaster.image(out as Data, maximum: 512) }
    }
    @Test func derivedDiskCacheEvictsOldEntriesAtByteLimit() async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        let cache = root.appendingPathComponent("Covers/Thumbnails"); try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        let obsolete = cache.appendingPathComponent(String(repeating: "a", count: 64) + "-512-1.png")
        #expect(FileManager.default.createFile(atPath: obsolete.path, contents: Data()))
        let handle = try FileHandle(forWritingTo: obsolete); try handle.truncate(atOffset: UInt64(CoverLimits.diskCacheBytes + 1)); try handle.close()
        let unrelated = cache.appendingPathComponent("unrelated-file.png"), retained = Data("Original unrelated file".utf8); try retained.write(to: unrelated)
        let source = LibraryRepository(root: root), book = try await source.importPDF(CoverFixture.pdf(), filename: "Original.pdf", pageCount: 2)
        let result = try await CoverRepository(root: root).thumbnail(for: CoverIdentity(book))
        #expect(result.png != nil); #expect(!FileManager.default.fileExists(atPath: obsolete.path))
        #expect(try Data(contentsOf: unrelated) == retained)
        let generated = try FileManager.default.contentsOfDirectory(at: cache, includingPropertiesForKeys: [.fileSizeKey]).filter { $0 != unrelated }
        let count = try generated.reduce(0) { try $0 + ($1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0) }
        #expect(count <= CoverLimits.diskCacheBytes)
    }
    @Test @MainActor func nativeCoverModelRefreshesOnlyEditedBook() async throws {
        let root = try CoverFixture.root(); defer { try? FileManager.default.removeItem(at: root) }
        let source = LibraryRepository(root: root), book = try await source.importPDF(CoverFixture.pdf(), filename: "Original.pdf", pageCount: 2)
        let local = root.appendingPathComponent("original art.png"); try CoverFixture.png().write(to: local)
        let model = CoverLibraryModel.shared(root: root), secondWindow = CoverLibraryModel.shared(root: root); await model.replace(CoverIdentity(book), url: local)
        #expect(model.error == nil); #expect(!model.busy); #expect(model.generations == [book.id: 1]); #expect(secondWindow.generations == [book.id: 1])
        await model.restore(CoverIdentity(book)); #expect(model.generations == [book.id: 2]); #expect(model.error == nil)
    }
}
