// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoDomain
import PDFnoServices

/// Deterministic original POSIX USTAR records and original PNGs; no decoder executable or user comic.
enum CBTFixture {
    struct Entry {
        let path: String
        var data = Data()
        var type: UInt8 = 48
        var prefix = ""
        var declaredSize: Int? = nil
        var link = ""
    }
    static func octal(_ value: Int, count: Int) -> [UInt8] {
        let digits = String(value, radix: 8)
        return Array((String(repeating: "0", count: count - digits.count - 1) + digits + "\0").utf8)
    }
    static func checksum(_ header: inout [UInt8]) {
        header.replaceSubrange(148..<156, with: [UInt8](repeating: 32, count: 8))
        let sum = header.reduce(0) { $0 + Int($1) }, digits = String(sum, radix: 8)
        header.replaceSubrange(148..<156, with: Array((String(repeating: "0", count: 6 - digits.count) + digits + "\0 ").utf8))
    }
    static func tar(_ entries: [Entry]) -> Data {
        var archive = Data()
        for entry in entries {
            var header = [UInt8](repeating: 0, count: 512)
            func text(_ value: String, at offset: Int) { header.replaceSubrange(offset..<(offset + value.utf8.count), with: value.utf8) }
            text(entry.path, at: 0); text(entry.prefix, at: 345); text(entry.link, at: 157)
            for (offset, count, value) in [(100, 8, 0o644), (108, 8, 0), (116, 8, 0),
                (124, 12, entry.declaredSize ?? entry.data.count), (136, 12, 0), (329, 8, 0), (337, 8, 0)] {
                header.replaceSubrange(offset..<(offset + count), with: octal(value, count: count))
            }
            header[156] = entry.type; text("ustar\0", at: 257); text("00", at: 263)
            checksum(&header); archive.append(contentsOf: header); archive.append(entry.data)
            archive.append(Data(repeating: 0, count: (512 - entry.data.count % 512) % 512))
        }
        archive.append(Data(repeating: 0, count: 1024)); return archive
    }
    static func book() throws -> Data {
        let image = try ComicFixture.png()
        return tar([Entry(path: "pages/", type: 53), Entry(path: "10.PNG", data: image, prefix: "pages"),
                    Entry(path: "2.png", data: image, prefix: "pages"), Entry(path: "1.png", data: image, prefix: "pages"),
                    Entry(path: "ComicInfo.xml", data: Data("<ComicInfo/>".utf8)),
                    Entry(path: "__MACOSX/._page.png", data: Data("Original metadata".utf8))])
    }
    static func patchHeader(_ archive: Data, offset: Int = 0, change: (inout [UInt8]) -> Void) -> Data {
        var header = Array(archive[offset..<(offset + 512)]); change(&header); checksum(&header)
        var result = archive; result.replaceSubrange(offset..<(offset + 512), with: header); return result
    }
}
struct CBTTests {
    @Test func independentPythonUSTARWriterFixture() throws {
        let root = try #require(Bundle.module.url(forResource: "Fixtures", withExtension: nil))
        let hex = try String(contentsOf: root.appendingPathComponent("Comics/original-ustar.cbt.hex"), encoding: .utf8)
        let source = hex.filter { !$0.isWhitespace }; #expect(source.count.isMultiple(of: 2))
        var data = Data(), index = source.startIndex
        while index < source.endIndex {
            let next = source.index(index, offsetBy: 2)
            data.append(try #require(UInt8(source[index..<next], radix: 16))); index = next
        }
        let archive = try CBTArchive(data: data)
        #expect(data.count == 10240)
        #expect(archive.pages.map(\.path) == ["pages/1.png", "pages/2.png", "pages/10.PNG"])
        #expect(archive.pages.last?.width == 30); #expect(archive.pages.last?.height == 10)
        #expect(try archive.pagePNG(at: 0).count > 0)
    }
    @Test func realUSTARPrefixNumericOrderAndRasterMatchCBZ() throws {
        let bytes = try CBTFixture.book(), tar = try CBTArchive(data: bytes)
        #expect(String(decoding: bytes[257..<263], as: UTF8.self) == "ustar\0")
        #expect(tar.entries.count == 6)
        #expect(tar.pages.map(\.path) == ["pages/1.png", "pages/2.png", "pages/10.PNG"])
        let zip = try CBZArchive(data: ComicFixture.book())
        #expect(tar.pages == zip.pages)
        for i in tar.pages.indices { #expect(try tar.pagePNG(at: i) == zip.pagePNG(at: i)) }
    }
    @Test func zeroTypeUTF8NamesAndTrailingZeroRecordAccepted() throws {
        let bytes = CBTFixture.tar([.init(path: "花/1.png", data: try ComicFixture.png(), type: 0)]) + Data(repeating: 0, count: 512)
        #expect(try CBTArchive(data: bytes).pages.first?.path == "花/1.png")
    }
    @Test func checksumTruncationTerminationAndPaddingRefused() throws {
        let bytes = try CBTFixture.book()
        var corrupt = bytes; corrupt[0] ^= 1
        var padded = CBTFixture.tar([.init(path: "info.txt", data: Data([1]))]); padded[513] = 1
        for invalid in [corrupt, Data(bytes.dropLast()), Data(bytes.dropLast(512)), bytes + bytes, padded] {
            #expect(throws: ComicError.self) { try CBTArchive.index(invalid) }
        }
    }
    @Test(arguments: [UInt8(49), 50, 51, 52, 54, 55, 76, 75, 83, 120, 103, 77])
    func unsupportedLinksDevicesGNUAndPAXRefused(type: UInt8) throws {
        #expect(throws: ComicError.self) { try CBTArchive.index(CBTFixture.tar([.init(path: "page.png", type: type)])) }
    }
    @Test func pathsDuplicatesMagicAndNumericVariantsRefused() throws {
        let image = try ComicFixture.png()
        for path in ["../1.png", "/1.png", "C:/1.png", "a\\1.png", "a/%2e/1.png", "a/./1.png", "a/../1.png"] {
            #expect(throws: ComicError.self) { try CBTArchive(data: CBTFixture.tar([.init(path: path, data: image)])) }
        }
        for entries in [[CBTFixture.Entry(path: "1.png", data: image), .init(path: "1.PNG", data: image)],
                        [.init(path: "é.png", data: image), .init(path: "é.png", data: image)],
                        [.init(path: "pages/", type: 53), .init(path: "pages", type: 53)],
                        [.init(path: "1.png", data: image, link: "other")], [.init(path: "pages/", data: image, type: 53)]] {
            #expect(throws: ComicError.self) { try CBTArchive.index(CBTFixture.tar(entries)) }
        }
        let bytes = try CBTFixture.book()
        for patched in [CBTFixture.patchHeader(bytes) { $0[257] = 0 }, CBTFixture.patchHeader(bytes) { $0[124] = 128 },
                        CBTFixture.patchHeader(bytes) { $0[136] = 57 }, CBTFixture.patchHeader(bytes) { $0[500] = 1 }] {
            #expect(throws: ComicError.self) { try CBTArchive.index(patched) }
        }
    }
    @Test func limitsEmptyBookAndUnsupportedRasterRefused() throws {
        #expect(throws: ComicError.self) { try CBTArchive.index(CBTFixture.tar([.init(path: "info", declaredSize: ComicLimits.entryBytes + 1)])) }
        #expect(throws: ComicError.self) { try CBTArchive.index(CBTFixture.tar((0...ComicLimits.entries).map { .init(path: "dir-\($0)/", type: 53) })) }
        #expect(throws: ComicError.self) { try CBTArchive(data: CBTFixture.tar([.init(path: "info", data: Data("Original text".utf8))])) }
        #expect(throws: ComicError.self) { try CBTArchive(data: CBTFixture.tar([.init(path: "1.gif", data: Data("Original inert GIF".utf8))])) }
        #expect(throws: ComicError.self) { try CBTArchive(data: CBTFixture.tar([.init(path: "1.png", data: Data("broken".utf8))])) }
        #expect(throws: ComicError.self) { try CBTArchive.index(Data(repeating: 0, count: ComicLimits.archiveBytes + 1)) }
    }
    @Test func matchingContainerRequiredAndTruncatedCB7CBRRejected() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-CBT-Rejection-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ComicRepository(root: root), tar = try CBTFixture.book(), zip = try ComicFixture.book()
        await #expect(throws: ComicError.self) { try await repository.importBook(zip, filename: "renamed.cbt") }
        await #expect(throws: ComicError.self) { try await repository.importBook(tar, filename: "renamed.cbz") }
        // These are original inert format signatures, not claimed readable 7z/RAR fixtures.
        for (name, signature) in [("blocked.cb7", Data([0x37, 0x7a, 0xbc, 0xaf, 0x27, 0x1c])),
                                  ("blocked.cbr", Data([0x52, 0x61, 0x72, 0x21, 0x1a, 0x07, 0]))] {
            await #expect(throws: ComicError.self) { try await repository.importBook(signature, filename: name) }
            await #expect(throws: ComicError.self) { try await repository.importBook(zip, filename: name) }
        }
        #expect(!FileManager.default.fileExists(atPath: root.path))
    }
    @Test func importMixedLibraryProgressAndOriginalImmutability() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-CBT-Library-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ComicRepository(root: root), zip = try ComicFixture.book(), tar = try CBTFixture.book()
        let cbz = try await repository.importBook(zip, filename: "Original.cbz")
        let oldManifest = try Data(contentsOf: root.appendingPathComponent("comics-v1.json"))
        let cbt = try await repository.importBook(tar, filename: "Original.CBT")
        #expect(try Data(contentsOf: root.appendingPathComponent("comics-v1.json")) == oldManifest)
        #expect(try await repository.importBook(tar, filename: "Renamed.cbt").id == cbt.id)
        let progress = ComicProgress(editionID: cbt.editionID, fileSHA256: cbt.fileSHA256, pageIndex: 2,
            pagePath: cbt.pages[2].path, direction: .rightToLeft, layout: .double)
        try await repository.saveProgress(progress, bookID: cbt.id)
        let reopened = ComicRepository(root: root), state = try await reopened.load()
        #expect(state.books.count == 2); #expect(state.books.first(where: { $0.id == cbt.id })?.progress == progress)
        #expect(try await reopened.read(cbt).data == tar); #expect(try await reopened.read(cbz).data == zip)
        #expect(try Data(contentsOf: root.appendingPathComponent("comics-v1.json")) == oldManifest)
        #expect(FileManager.default.fileExists(atPath: root.appendingPathComponent("comics-cbt-v1.json.backup").path))
        let original = root.appendingPathComponent("Originals/" + cbt.fileSHA256 + ".cbt")
        #expect(try Data(contentsOf: original) == tar)
        #expect(ComicPagination.visualOrder([1, 2], direction: .rightToLeft) == [2, 1])
        #expect(ComicPagination.spread(containing: 1, pages: cbt.pages, layout: .double, width: 1000, height: 700) == [1, 2])
        let cover = try await CoverRepository(root: root).thumbnail(for: CoverIdentity(cbt))
        #expect(cover.record.identity.format == .cbt); #expect(cover.record.origin == .cbtFirstImage)
        #expect(cover.record.resourcePath == "pages/1.png"); #expect(cover.png != nil)
        #expect(try Data(contentsOf: original) == tar)
    }
    @Test func wrongPositionsAndCorruptStoreNeverOverwrite() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-CBT-Store-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ComicRepository(root: root), tar = try CBTFixture.book()
        let book = try await repository.importBook(tar, filename: "Original.cbt")
        let wrong = ComicProgress(editionID: book.editionID, fileSHA256: book.fileSHA256, pageIndex: 1,
            pagePath: book.pages[0].path, direction: .leftToRight, layout: .single)
        await #expect(throws: ComicError.self) { try await repository.saveProgress(wrong, bookID: book.id) }
        let manifest = root.appendingPathComponent("comics-cbt-v1.json")
        for invalid in [Data("corrupt".utf8), Data(#"{"schemaVersion":2,"books":[]}"#.utf8)] {
            try invalid.write(to: manifest)
            await #expect(throws: ComicError.self) { try await repository.importBook(tar, filename: "Other.cbt") }
            #expect(try Data(contentsOf: manifest) == invalid)
        }
    }
    @Test func orphanOriginalCollisionRefusedAndEqualOriginalRecovered() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-CBT-Orphan-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = ComicRepository(root: root), tar = try CBTFixture.book()
        let book = try await repository.importBook(tar, filename: "Original.cbt")
        try FileManager.default.removeItem(at: root.appendingPathComponent("comics-cbt-v1.json"))
        #expect(try await repository.importBook(tar, filename: "Recovered.cbt").fileSHA256 == book.fileSHA256)
        try FileManager.default.removeItem(at: root.appendingPathComponent("comics-cbt-v1.json"))
        let original = root.appendingPathComponent("Originals/" + book.fileSHA256 + ".cbt"), changed = Data("Original collision fixture".utf8)
        try changed.write(to: original)
        await #expect(throws: ComicError.self) { try await repository.importBook(tar, filename: "Collision.cbt") }
        #expect(try Data(contentsOf: original) == changed)
        #expect(!FileManager.default.fileExists(atPath: root.appendingPathComponent("comics-cbt-v1.json").path))
    }
}
