// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import zlib
import Testing
import PDFnoDomain
import PDFnoServices
#if os(macOS)
import AppKit
import WebKit
import PDFnoReaders
#endif

/// All images and ZIP records are generated here. No user documents, external archiver or binary fixture.
private enum ComicFixture {
    struct Entry {
        let name: String
        let data: Data
        var deflated = false
        var declared: Int? = nil
        var flags = 0x0800
        var unixMode = 0x8000
        var descriptorSignature = true
        var extra = Data()
    }
    static func u16(_ n: Int) -> Data { Data([UInt8(n & 255), UInt8((n >> 8) & 255)]) }
    static func u32(_ n: Int) -> Data { u16(n & 65535) + u16((n >> 16) & 65535) }
    static func crc(_ data: Data) -> Int {
        data.withUnsafeBytes { Int(crc32(0, $0.bindMemory(to: UInt8.self).baseAddress, uInt(data.count))) }
    }
    static func deflateRaw(_ data: Data) throws -> Data {
        var stream = z_stream()
        guard deflateInit2_(&stream, Z_DEFAULT_COMPRESSION, Z_DEFLATED, -MAX_WBITS, 8, Z_DEFAULT_STRATEGY,
                            ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw ComicError.invalidArchive }
        defer { deflateEnd(&stream) }
        let capacity = Int(deflateBound(&stream, uLong(data.count)))
        var buffer = [UInt8](repeating: 0, count: capacity)
        let result = data.withUnsafeBytes { raw in buffer.withUnsafeMutableBytes { out in
            stream.next_in = UnsafeMutablePointer(mutating: raw.bindMemory(to: UInt8.self).baseAddress); stream.avail_in = uInt(data.count)
            stream.next_out = out.bindMemory(to: UInt8.self).baseAddress; stream.avail_out = uInt(capacity)
            return deflate(&stream, Z_FINISH)
        } }
        guard result == Z_STREAM_END else { throw ComicError.invalidArchive }
        return Data(buffer.prefix(Int(stream.total_out)))
    }
    static func zip(_ entries: [Entry]) throws -> Data {
        var locals = Data(), central = Data()
        for entry in entries {
            let name = Data(entry.name.utf8), payload = try entry.deflated ? deflateRaw(entry.data) : entry.data
            let method = entry.deflated ? 8 : 0, crc = crc(entry.data), expanded = entry.declared ?? entry.data.count
            let descriptor = entry.flags & 8 != 0, offset = locals.count
            for field in [u32(0x04034b50), u16(20), u16(entry.flags), u16(method), u16(0), u16(0),
                          u32(descriptor ? 0 : crc), u32(descriptor ? 0 : payload.count), u32(descriptor ? 0 : expanded),
                          u16(name.count), u16(entry.extra.count), name, entry.extra, payload] { locals.append(field) }
            if descriptor {
                for field in [entry.descriptorSignature ? u32(0x08074b50) : Data(), u32(crc), u32(payload.count), u32(expanded)] {
                    locals.append(field)
                }
            }
            for field in [u32(0x02014b50), u16(0x0314), u16(20), u16(entry.flags), u16(method), u16(0), u16(0),
                          u32(crc), u32(payload.count), u32(expanded), u16(name.count), u16(entry.extra.count), u16(0),
                          u16(0), u16(0), u32(entry.unixMode << 16), u32(offset), name, entry.extra] { central.append(field) }
        }
        let centralOffset = locals.count
        locals.append(central)
        for field in [u32(0x06054b50), u16(0), u16(0), u16(entries.count), u16(entries.count),
                      u32(central.count), u32(centralOffset), u16(0)] { locals.append(field) }
        return locals
    }
    static func png(width: Int = 12, height: Int = 20) throws -> Data {
        let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                         space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.8, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.8, green: 0.5, blue: 0.2, alpha: 1)); context.fill(CGRect(x: 2, y: 2, width: width / 2, height: height / 2))
        let image = try #require(context.makeImage()), output = NSMutableData()
        let target = try #require(CGImageDestinationCreateWithData(output, UTType.png.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(target, image, nil); #expect(CGImageDestinationFinalize(target)); return output as Data
    }
    static func book() throws -> Data {
        let image = try png()
        return try zip([Entry(name: "pages/10.PNG", data: image, deflated: true), Entry(name: "pages/2.png", data: image),
                        Entry(name: "pages/1.png", data: image), Entry(name: "ComicInfo.xml", data: Data("<ComicInfo/>".utf8)),
                        Entry(name: "__MACOSX/._page.png", data: Data("metadata".utf8))])
    }
    static func central(_ data: Data) throws -> Int { try #require(data.range(of: u32(0x02014b50))?.lowerBound) }
    static func patch(_ data: Data, at offset: Int, bytes: Data) -> Data {
        var result = data; result.replaceSubrange(offset..<(offset + bytes.count), with: bytes); return result
    }
}

#if os(macOS)
@Suite(.serialized)
struct ComicWebKitTests {
    @MainActor private func ready(_ session: ComicReaderSession) async throws {
        let limit = Date().addingTimeInterval(25)
        while session.busy && Date() < limit { try await Task.sleep(for: .milliseconds(50)) }
        #expect(session.error == nil)
        _ = try #require(session.progress)
    }
    @MainActor private func opened(_ archive: CBZArchive, _ book: ComicBook, repository: ComicRepository) async throws -> (ComicReaderSession, NSWindow) {
        _ = NSApplication.shared
        let session = ComicReaderSession()
        session.persist = { id, progress in try await repository.saveProgress(progress, bookID: id) }
        try await session.open(archive: archive, book: book)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = session.webView
        session.webView?.frame = NSRect(x: 0, y: 0, width: 1000, height: 700)
        do { try await ready(session) } catch { session.close(); window.close(); throw error }
        return (session, window)
    }
    @MainActor private func probe(_ session: ComicReaderSession, _ code: String) async throws -> String {
        let view = try #require(session.webView)
        return try #require(try await view.callAsyncJavaScript(code, arguments: [:], in: nil, contentWorld: .page) as? String)
    }
    @Test @MainActor func actualRasterSpreadsDirectionResizeAndRestart() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Comics-WebKit-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = try ComicFixture.zip((0..<7).map { index in
            ComicFixture.Entry(name: "pages/\(index + 1).PNG", data: try ComicFixture.png(width: index == 3 ? 30 : 12, height: index == 3 ? 10 : 20), deflated: true)
        })
        let repository = ComicRepository(root: root), book = try await repository.importBook(data, filename: "original.cbz")
        let archive = try await repository.read(book)
        let (session, window) = try await opened(archive, book, repository: repository)
        defer { session.close(); window.close() }
        #expect(session.visibleIndices == [0])
        let raster = try await probe(session, "return JSON.stringify([...document.querySelectorAll('iframe')].map(f=>{const i=f.contentDocument.querySelector('img');return {title:f.title,width:i.naturalWidth,height:i.naturalHeight,source:i.src.startsWith('blob:'),sandbox:f.getAttribute('sandbox')};}));")
        #expect(raster.contains("\"width\":12")); #expect(raster.contains("\"height\":20"))
        #expect(raster.contains("allow-same-origin")); #expect(raster.contains("\"source\":true"))
        await session.next(); #expect(session.visibleIndices == [1,2])
        #expect(try await probe(session, "return [...document.querySelectorAll('iframe')].map(f=>f.title).join(',');") == "第 2 页,第 3 页")
        await session.setDirection(.rightToLeft); #expect(session.visibleIndices == [2,1])
        #expect(try await probe(session, "return [...document.querySelectorAll('iframe')].map(f=>f.title).join(',');") == "第 3 页,第 2 页")
        await session.resize(width: 600, height: 900); #expect(session.visibleIndices == [1])
        await session.resize(width: 1000, height: 700); #expect(session.visibleIndices == [2,1])
        await session.next(); #expect(session.visibleIndices == [3])
        await session.next(); #expect(session.visibleIndices == [5,4])
        await session.next(); #expect(session.visibleIndices == [6]); #expect(!session.hasNext)
        await session.previous(); #expect(session.visibleIndices == [5,4])
        await session.setLayout(.single); #expect(session.visibleIndices == [4])
        let saved = try #require(try await repository.load().books.first?.progress)
        #expect(saved.pagePath == "pages/5.PNG"); #expect(saved.direction == .rightToLeft); #expect(saved.layout == .single)
        session.close(); window.close()
        let current = try #require(try await ComicRepository(root: root).load().books.first)
        let (reopened, secondWindow) = try await opened(archive, current, repository: repository)
        defer { reopened.close(); secondWindow.close() }
        #expect(reopened.pageIndex == 4); #expect(reopened.direction == .rightToLeft); #expect(reopened.layout == .single)
        #expect(reopened.visibleIndices == [4]); #expect(reopened.progress == saved)
    }
    @Test @MainActor func realWebKitRefusesNetworkScriptsAndStaleCommands() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Comics-WebKit-Security-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ComicRepository(root: root), book = try await repository.importBook(ComicFixture.book(), filename: "original.cbz")
        let (session, window) = try await opened(try await repository.read(book), book, repository: repository)
        defer { session.close(); window.close() }
        #expect(try await probe(session, "try{await fetch('https://example.invalid/must-never-load');return 'loaded'}catch{return 'blocked'}") == "blocked")
        #expect(try await probe(session, "const d=document.querySelector('iframe').contentDocument;const s=d.createElement('script');s.textContent='window.PDFNO_COMIC_SCRIPT=1';d.body.append(s);return String(!!d.defaultView.PDFNO_COMIC_SCRIPT);") == "false")
        #expect(try await probe(session, "try{await window.PDFnoComic.command({v:1,command:'render',requestID:'stale',session:'wrong'});return 'accepted'}catch{return 'rejected'}") == "rejected")
        let prior = session.progress
        await session.go(to: -1); #expect(session.progress == prior)
        session.close(); #expect(session.webView == nil); #expect(session.progress == nil)
        await session.next(); #expect(session.webView == nil)
    }
}
#endif

struct ComicTests {
    @Test func storedDeflateNaturalOrderUppercaseAndBoundedThumbnail() throws {
        let data = try ComicFixture.book(), archive = try CBZArchive(data: data)
        #expect(archive.pages.map(\.path) == ["pages/1.png", "pages/2.png", "pages/10.PNG"])
        #expect(archive.pages.allSatisfy { $0.width == 12 && $0.height == 20 })
        let png = try archive.pagePNG(at: 2)
        #expect(png.prefix(8) == Data([137,80,78,71,13,10,26,10]))
        #expect(throws: ComicError.self) { try archive.pagePNG(at: 3) }
        let huge = try ComicFixture.png(width: 3000, height: 2)
        let downsample = try CBZArchive(data: ComicFixture.zip([.init(name: "1.png", data: huge)])).pagePNG(at: 0)
        let source = try #require(CGImageSourceCreateWithData(downsample as CFData, nil))
        let info = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect((info[kCGImagePropertyPixelWidth] as? Int ?? 0) <= ComicLimits.thumbnailDimension)
    }
    @Test func signedAndUnsignedDataDescriptors() throws {
        let png = try ComicFixture.png()
        #expect(try CBZArchive(data: ComicFixture.zip([.init(name: "1.png", data: png, deflated: true, flags: 0x0802)])).pages.count == 1)
        for signed in [true, false] {
            let data = try ComicFixture.zip([.init(name: "1.png", data: png, deflated: true, flags: 0x0808, descriptorSignature: signed)])
            #expect(try CBZArchive(data: data).pages.count == 1)
            let entry = try #require(CBZArchive.index(data).first)
            let bad = ComicFixture.patch(data, at: entry.payload.upperBound + (signed ? 4 : 0), bytes: ComicFixture.u32(1))
            #expect(throws: ComicError.self) { try CBZArchive(data: bad) }
        }
    }
    @Test func refusesTraversalInOriginalCentralAndLocalNames() throws {
        let image = try ComicFixture.png()
        for path in ["../1.png", "/1.png", "a/../1.png", "C:1.png", "a\\1.png", "a/%2e%2e/1.png", "a//1.png", "\u{0}1.png", "a/./1.png"] {
            let data = try ComicFixture.zip([.init(name: path, data: image)])
            #expect(throws: ComicError.self) { try CBZArchive(data: data) }
        }
        let valid = try ComicFixture.zip([.init(name: "1.png", data: image)])
        #expect(throws: ComicError.self) { try CBZArchive(data: ComicFixture.patch(valid, at: 30, bytes: Data("/".utf8))) }
    }
    @Test func rejectsDuplicateCaseAndUnicodeNamesSymlinksEncryptionAndMultiDisk() throws {
        let image = try ComicFixture.png()
        for names in [["1.png", "1.png"], ["A.png", "a.png"], ["café.png", "cafe\u{301}.png"]] {
            #expect(throws: ComicError.self) { try CBZArchive(data: ComicFixture.zip(names.map { .init(name: $0, data: image) })) }
        }
        for entry in [ComicFixture.Entry(name: "1.png", data: image, unixMode: 0xa000),
                      ComicFixture.Entry(name: "1.png", data: image, flags: 0x0801)] {
            #expect(throws: ComicError.self) { try CBZArchive(data: ComicFixture.zip([entry])) }
        }
        let data = try ComicFixture.book()
        #expect(throws: ComicError.self) { try CBZArchive(data: ComicFixture.patch(data, at: data.count - 18, bytes: ComicFixture.u16(1))) }
    }
    @Test func zip64UnsupportedMethodsOverlapsAndTrailingGarbageAreRejected() throws {
        let data = try ComicFixture.book(), c = try ComicFixture.central(data)
        for (offset, bytes) in [(c + 42, ComicFixture.u32(0xffffffff)), (c + 10, ComicFixture.u16(12)),
                                (c + 20, ComicFixture.u32(0xffffffff)), (c + 34, ComicFixture.u16(1))] {
            #expect(throws: ComicError.self) { try CBZArchive(data: ComicFixture.patch(data, at: offset, bytes: bytes)) }
        }
        let image = try ComicFixture.png()
        let zip64 = ComicFixture.u16(1) + ComicFixture.u16(8) + Data(repeating: 0, count: 8)
        #expect(throws: ComicError.self) { try CBZArchive.index(ComicFixture.zip([.init(name: "1.png", data: image, extra: zip64)])) }
        let malformedExtra = ComicFixture.u16(12) + ComicFixture.u16(16) + Data([0])
        #expect(throws: ComicError.self) { try CBZArchive.index(ComicFixture.zip([.init(name: "1.png", data: image, extra: malformedExtra)])) }
        let inner = try ComicFixture.zip([.init(name: "2.png", data: image)])
        let nested = inner.prefix(try ComicFixture.central(inner))
        let overlapping = try ComicFixture.zip([.init(name: "1.png", data: Data(nested)), .init(name: "2.png", data: image)])
        let first = try #require(CBZArchive.index(overlapping).first), firstCentral = try ComicFixture.central(overlapping)
        let secondCentral = firstCentral + 46 + Data("1.png".utf8).count
        #expect(throws: ComicError.self) { try CBZArchive.index(ComicFixture.patch(overlapping, at: secondCentral + 42, bytes: ComicFixture.u32(first.payload.lowerBound))) }
        var bad = data; bad += Data("garbage".utf8)
        #expect(throws: ComicError.self) { try CBZArchive(data: bad) }
        #expect(throws: ComicError.self) { try CBZArchive(data: Data("Rar!\u{1a}\u{7}\u{0}".utf8)) }
        #expect(throws: ComicError.self) { try CBZArchive(data: Data()) }
    }
    @Test func CRCAndDishonestOutputSizesCannotBypassBudget() throws {
        let image = try ComicFixture.png(), data = try ComicFixture.zip([.init(name: "1.png", data: image)])
        let entry = try #require(CBZArchive.index(data).first)
        #expect(throws: ComicError.self) { try CBZArchive(data: ComicFixture.patch(data, at: entry.payload.lowerBound + 10, bytes: Data([255]))) }
        let bomb = Data(repeating: 65, count: 1024 * 1024)
        #expect(throws: ComicError.self) { try CBZArchive(data: ComicFixture.zip([.init(name: "1.png", data: bomb, deflated: true, declared: 1)])) }
        #expect(throws: ComicError.self) { try CBZArchive(data: ComicFixture.zip([.init(name: "1.png", data: image, declared: 1)])) }
        // An ignored metadata entry is also validated; it cannot hide a dishonest compressed output.
        #expect(throws: ComicError.self) { try CBZArchive(data: ComicFixture.zip([.init(name: "1.png", data: image), .init(name: "ComicInfo.xml", data: bomb, deflated: true, declared: 1)])) }
    }
    @Test func declaredEntryTotalArchiveAndCountBudgets() throws {
        let data = try ComicFixture.book(), c = try ComicFixture.central(data)
        #expect(throws: ComicError.self) { try CBZArchive.index(ComicFixture.patch(data, at: c + 24, bytes: ComicFixture.u32(ComicLimits.entryBytes + 1))) }
        #expect(throws: ComicError.self) { try CBZArchive.index(Data(repeating: 0, count: ComicLimits.archiveBytes + 1)) }
        let tiny = Data([0])
        #expect(throws: ComicError.self) { try CBZArchive.index(ComicFixture.zip((0..<33).map { .init(name: "\($0).png", data: tiny, declared: ComicLimits.entryBytes) })) }
        #expect(throws: ComicError.self) { try CBZArchive.index(ComicFixture.zip((0..<2001).map { .init(name: "\($0).png", data: tiny) })) }
    }
    @Test func unsupportedCorruptEmptyAndOversizedImagesFailDuringImport() throws {
        for entry in [ComicFixture.Entry(name: "1.svg", data: Data("<svg/>".utf8)),
                      ComicFixture.Entry(name: "1.png", data: Data("broken".utf8)),
                      ComicFixture.Entry(name: "notes.txt", data: Data("no image".utf8)),
                      ComicFixture.Entry(name: "1.png", data: try ComicFixture.png(width: 16001, height: 1))] {
            #expect(throws: ComicError.self) { try CBZArchive(data: ComicFixture.zip([entry])) }
        }
    }
    @Test func localeIndependentNumericPageOrdering() {
        let names = ["Chapter 10/1.png", "Chapter 2/10.png", "Chapter 2/2.png", "Chapter 2/01.png", "Chapter 2/1.png"]
        #expect(names.sorted(by: ComicPageOrder.precedes) == ["Chapter 2/01.png", "Chapter 2/1.png", "Chapter 2/2.png", "Chapter 2/10.png", "Chapter 10/1.png"])
        #expect(ComicPageOrder.precedes("2.png", String(repeating: "9", count: 100) + ".png"))
    }
    @Test func coverLandscapeOddPageAndDirectionsKeepEveryPageReachable() {
        let portrait = (0..<6).map { ComicPage(path: "\($0).png", width: 12, height: 20) }
        #expect(ComicPagination.spread(containing: 0, pages: portrait, layout: .double, width: 1000, height: 700) == [0])
        #expect(ComicPagination.spread(containing: 2, pages: portrait, layout: .double, width: 1000, height: 700) == [1,2])
        #expect(ComicPagination.spread(containing: 5, pages: portrait, layout: .double, width: 1000, height: 700) == [5])
        #expect(ComicPagination.spread(containing: 2, pages: portrait, layout: .automatic, width: 600, height: 900) == [2])
        #expect(ComicPagination.spread(containing: 2, pages: portrait, layout: .automatic, width: 1000, height: 700) == [1,2])
        #expect(ComicPagination.visualOrder([1,2], direction: .rightToLeft) == [2,1])
        let mixed = [portrait[0], portrait[1], ComicPage(path: "2.png", width: 20, height: 12), portrait[3], portrait[4], portrait[5]]
        #expect(ComicPagination.spread(containing: 1, pages: mixed, layout: .double, width: 1000, height: 700) == [1])
        #expect(ComicPagination.spread(containing: 2, pages: mixed, layout: .double, width: 1000, height: 700) == [2])
        #expect(ComicPagination.spread(containing: 4, pages: mixed, layout: .double, width: 1000, height: 700) == [3,4])
        for index in mixed.indices {
            #expect(ComicPagination.spread(containing: index, pages: mixed, layout: .double, width: 1000, height: 700).contains(index))
        }
    }
    @Test func isolatedPersistenceDuplicateRestoreDirectionLayoutAndForeignPositionRefusal() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Comics-Test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ComicRepository(root: root), data = try ComicFixture.book()
        let book = try await repository.importBook(data, filename: "original.cbz")
        #expect(try await repository.importBook(data, filename: "renamed.cbz").id == book.id)
        let progress = ComicProgress(editionID: book.editionID, fileSHA256: book.fileSHA256, pageIndex: 2,
            pagePath: book.pages[2].path, direction: .rightToLeft, layout: .double)
        try await repository.saveProgress(progress, bookID: book.id)
        let reopened = ComicRepository(root: root), state = try await reopened.load()
        #expect(state.books.first?.progress == progress)
        #expect(try await reopened.read(book).data == data)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("library-v1.json").path))
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("epub-v1.json").path))
        let wrong = ComicProgress(editionID: UUID(), fileSHA256: book.fileSHA256, pageIndex: 2,
            pagePath: book.pages[2].path, direction: .leftToRight, layout: .single)
        await #expect(throws: ComicError.self) { try await reopened.saveProgress(wrong, bookID: book.id) }
        let badPath = ComicProgress(editionID: book.editionID, fileSHA256: book.fileSHA256, pageIndex: 2,
            pagePath: book.pages[0].path, direction: .leftToRight, layout: .single)
        await #expect(throws: ComicError.self) { try await reopened.saveProgress(badPath, bookID: book.id) }
        await #expect(throws: ComicError.self) { try await reopened.importBook(data, filename: "unsupported.cbr") }
        let original = root.appendingPathComponent("Originals/" + book.fileSHA256 + ".cbz")
        try Data("replaced".utf8).write(to: original)
        await #expect(throws: ComicError.self) { try await reopened.read(book) }
    }
    @Test func futureCorruptAndUnknownFieldStorePreservedWithoutImportWrites() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Comics-Store-Test-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let manifest = root.appendingPathComponent("comics-v1.json"), repository = ComicRepository(root: root)
        for value in [#"{"schemaVersion":2,"books":[]}"#, #"{"schemaVersion":1,"books":[],"secret":"forbidden"}"#, "invalid"] {
            let bytes = Data(value.utf8); try bytes.write(to: manifest)
            await #expect(throws: ComicError.self) { try await repository.importBook(ComicFixture.book(), filename: "1.cbz") }
            #expect(try Data(contentsOf: manifest) == bytes)
            #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("Originals").path))
        }
    }
}
