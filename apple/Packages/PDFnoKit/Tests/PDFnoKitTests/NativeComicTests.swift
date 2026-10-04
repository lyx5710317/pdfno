// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import ImageIO
import PDFnoDomain
@testable import PDFnoServices

enum NativeComicFixture {
    static func load(_ name: String) throws -> Data {
        let url = try #require(Bundle.module.url(forResource: name, withExtension: "hex", subdirectory: "Fixtures/Comics"))
        let hex = try String(contentsOf: url, encoding: .utf8).filter { !$0.isWhitespace }
        var bytes = Data(); var p = hex.startIndex
        while p < hex.endIndex { let end = hex.index(p, offsetBy: 2); bytes.append(try #require(UInt8(hex[p..<end], radix: 16))); p = end }
        return bytes
    }
    static func crc(_ data: Data) -> Int { ComicFixture.crc(data) }
    static func patch7(_ input: Data, at: Int, bytes: Data) -> Data {
        var data = ComicFixture.patch(input, at: at, bytes: bytes)
        let start = 32 + Int(data[12]) + (Int(data[13]) << 8)
        data = ComicFixture.patch(data, at: 28, bytes: ComicFixture.u32(crc(data.subdata(in: start..<data.count))))
        return ComicFixture.patch(data, at: 8, bytes: ComicFixture.u32(crc(data.subdata(in: 12..<32))))
    }
    static func rar4(_ entries: [(String,Data)], mainFlags: Int = 0, fileFlags: Int = 0x8000, method: UInt8 = 0x30) -> Data {
        func header(_ type: UInt8, flags: Int, body: Data) -> Data {
            let b = Data([type]) + ComicFixture.u16(flags) + ComicFixture.u16(body.count + 7) + body
            return ComicFixture.u16(Int(crc(b) & 0xffff)) + b
        }
        var result = Data([0x52,0x61,0x72,0x21,0x1a,0x07,0]) + header(0x73, flags: mainFlags, body: Data(repeating: 0, count: 6))
        for (name, bytes) in entries {
            var b = ComicFixture.u32(bytes.count) + ComicFixture.u32(bytes.count) + Data([3]) + ComicFixture.u32(crc(bytes))
            for part in [ComicFixture.u32(0), Data([29,method]), ComicFixture.u16(name.utf8.count), ComicFixture.u32(0o100644), Data(name.utf8)] { b += part }
            result += header(0x74, flags: fileFlags, body: b) + bytes
        }
        return result + header(0x7b, flags: 0, body: Data())
    }
}

struct NativeComicTests {
    @Test func realContainersOrderLandscapeAndThumbnails() throws {
        for (name,format) in [("original-copy.cb7",ComicArchiveFormat.cb7),("original-lzma.cb7",.cb7),("original-lzma2.cb7",.cb7),("original-rar4.cbr",.cbr),("original-rar5.cbr",.cbr)] {
            let data = try NativeComicFixture.load(name), archive = try NativeComicArchive(data: data, format: format)
            #expect(archive.pages.map(\.path) == ["pages/1.png","pages/2.png","pages/10.PNG"])
            #expect(archive.pages[1].width == 30 && archive.pages[1].height == 10)
            #expect(archive.decoderPeakBytes > 0 && archive.decoderPeakBytes <= ComicLimits.decoderBytes)
            let png = try archive.pagePNG(at: 1)
            let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))
            let info = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
            #expect(info[kCGImagePropertyPixelWidth] as? Int == 30)
            print("CODEC_METRIC \(name) input=\(data.count) peak=\(archive.decoderPeakBytes)")
        }
    }
    @Test func measuredSmallOriginalDecodePerformance() throws {
        for (name,format) in [("original-lzma2.cb7",ComicArchiveFormat.cb7),("original-rar5.cbr",.cbr)] {
            let data = try NativeComicFixture.load(name)
            var measurements: [UInt64] = []
            for _ in 0..<10 {
                let start = DispatchTime.now().uptimeNanoseconds
                let archive = try NativeComicArchive(data: data, format: format)
                #expect(archive.pages.count == 3)
                measurements.append(DispatchTime.now().uptimeNanoseconds - start)
            }
            print("CODEC_PERF \(name) pages=3 median_ns=\(measurements.sorted()[5]) samples=10")
        }
    }
    @Test func byteAdmissionCorruptionTruncationSFXAndRenameRefused() throws {
        let seven = try NativeComicFixture.load("original-copy.cb7"), rar = try NativeComicFixture.load("original-rar4.cbr")
        for (data,format) in [(seven,ComicArchiveFormat.cbr),(rar,.cb7),(try ComicFixture.book(),.cb7),(try CBTFixture.book(),.cbr)] {
            #expect(throws: ComicError.self) { try NativeComicArchive(data: data, format: format) }
        }
        for (data,format) in [(seven,ComicArchiveFormat.cb7),(rar,.cbr),(try NativeComicFixture.load("original-rar5.cbr"),.cbr)] {
            for bad in [Data(data.dropLast()),Data([0])+data,data+Data([0]),ComicFixture.patch(data, at: 40, bytes: Data([255]))] {
                #expect(throws: ComicError.self) { try NativeComicArchive(data: bad, format: format) }
            }
        }
        #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.patch7(seven, at: 40, bytes: Data([255])), format: .cb7) }
        let header = 32 + Int(seven[12]) + (Int(seven[13]) << 8)
        // Ignored XML also needs a valid actual payload CRC, independent of image admission.
        #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.patch7(seven, at: header - 1, bytes: Data([255])), format: .cb7) }
        let nonzeroSlice = (Data([0]) + seven).dropFirst()
        #expect(throws: ComicError.self) { try NativeComicArchive(data: nonzeroSlice, format: .cb7) }
    }
    @Test func allocatorEnforcesLimitIncludingDictionaryBeforeExpansion() throws {
        let data = try NativeComicFixture.load("original-lzma.cb7")
        do { _ = try NativeComicArchive(data: data, format: .cb7, workingMemoryLimit: 128); Issue.record("tiny budget accepted") }
        catch ComicError.resourceLimit {}
        let property = try #require(data.range(of: Data([0x5d,0,0,1,0]))?.lowerBound)
        let oversized = NativeComicFixture.patch7(data, at: property + 1, bytes: Data([0xff,0xff,0xff,0x7f]))
        do { _ = try NativeComicArchive(data: oversized, format: .cb7); Issue.record("huge dictionary accepted") }
        catch ComicError.resourceLimit {}
    }
    @Test func solidAndUnselected7zCodersRefused() throws {
        #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.load("refused-solid.cb7"), format: .cb7) }
        let data = try NativeComicFixture.load("original-lzma2.cb7")
        let coder = try #require(data.range(of: Data([0x21,0x21,1,8]))?.lowerBound)
        for code: UInt8 in [0x04,0x06,0x09] { // unsupported coder IDs, not fallback decoding
            #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.patch7(data, at: coder + 1, bytes: Data([code])), format: .cb7) }
        }
        let start = 32 + Int(data[12]) + (Int(data[13]) << 8)
        #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.patch7(data, at: start, bytes: Data([0x17])), format: .cb7) }
    }
    @Test func rarEncryptionVolumesSolidCompressedAndUnsafeNamesRefused() throws {
        let png = try ComicFixture.png(), entries = [("1.png",png)]
        for flags in [1,8,0x80,0x100,0x200] {
            #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.rar4(entries, mainFlags: flags), format: .cbr) }
        }
        for flags in [0x8001,0x8002,0x8004,0x8010,0x8200,0x8100] {
            #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.rar4(entries, fileFlags: flags), format: .cbr) }
        }
        #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.rar4(entries, method: 0x33), format: .cbr) }
        for names in [["../1.png"],["/1.png"],["a\\1.png"],["a/%2e%2e/1.png"],["A.png","a.png"]] {
            #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.rar4(names.map { ($0,png) }), format: .cbr) }
        }
    }
    @Test func entryCountSizesAndActualImageLimits() throws {
        #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.rar4((0..<2001).map { ("\($0).txt",Data([0])) }), format: .cbr) }
        #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.rar4([("1.txt",Data(repeating: 0,count: ComicLimits.entryBytes + 1))]), format: .cbr) }
        for (name,bytes) in [("1.png",Data("broken".utf8)),("1.gif",Data("inert".utf8)),("info.txt",Data("original".utf8)),("1.png",try ComicFixture.png(width:16001,height:1))] {
            #expect(throws: ComicError.self) { try NativeComicArchive(data: NativeComicFixture.rar4([(name,bytes)]), format: .cbr) }
        }
    }
    @Test func mixedStoreRestartDirectionLayoutCoverAndOriginalPreservation() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Native-Comics-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ComicRepository(root: root)
        _ = try await repository.importBook(ComicFixture.book(),filename:"original.cbz")
        _ = try await repository.importBook(CBTFixture.book(),filename:"original.cbt")
        let old = try Data(contentsOf:root.appendingPathComponent("comics-v1.json")), tar = try Data(contentsOf:root.appendingPathComponent("comics-cbt-v1.json"))
        for name in ["original-lzma2.cb7","original-rar5.cbr"] {
            let data = try NativeComicFixture.load(name), book = try await repository.importBook(data,filename:name)
            #expect(try await repository.importBook(data,filename:"renamed."+book.archiveFormat!.rawValue).id == book.id)
            let p = ComicProgress(editionID:book.editionID,fileSHA256:book.fileSHA256,pageIndex:2,pagePath:book.pages[2].path,direction:.rightToLeft,layout:.double)
            try await repository.saveProgress(p,bookID:book.id)
            let reopened = ComicRepository(root:root), restored = try #require(try await reopened.load().books.first { $0.id == book.id })
            #expect(restored.progress == p)
            #expect(try await reopened.read(restored).pages == book.pages)
            #expect(try Data(contentsOf:root.appendingPathComponent("Originals/"+book.fileSHA256+"."+book.archiveFormat!.rawValue)) == data)
            #expect(ComicPagination.visualOrder([1,2],direction:p.direction) == [2,1])
        }
        #expect(try await repository.load().books.count == 4)
        #expect(try Data(contentsOf:root.appendingPathComponent("comics-v1.json")) == old)
        #expect(try Data(contentsOf:root.appendingPathComponent("comics-cbt-v1.json")) == tar)
    }
    @Test @MainActor func nativeCoverOriginAndRestore() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Native-Covers-"+UUID().uuidString)
        defer { try? FileManager.default.removeItem(at:root) }
        for (name,origin) in [("original-copy.cb7",CoverOrigin.cb7FirstImage),("original-rar4.cbr",.cbrFirstImage)] {
            let book = try await ComicRepository(root:root).importBook(NativeComicFixture.load(name),filename:name)
            let covers = CoverRepository(root:root), identity = CoverIdentity(book)
            let thumbnail = try await covers.thumbnail(for: identity)
            let cover = thumbnail.record
            #expect(cover.origin == origin && cover.resourcePath == "pages/1.png")
            #expect(try await CoverRepository(root: root).thumbnail(for: identity).record.identity == identity)
        }
    }
}
