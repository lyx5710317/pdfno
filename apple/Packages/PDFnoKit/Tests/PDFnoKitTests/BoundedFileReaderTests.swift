// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Darwin
import Testing
import PDFnoDomain
@testable import PDFnoServices

struct BoundedFileReaderTests {
    @Test func repositoriesBoundManifestsBackupsAndAssetsBeforeHashing() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        func oversized(_ name: String, _ limit: Int) throws -> URL {
            let url = root.appendingPathComponent(name)
            try Data().write(to: url)
            let handle = try FileHandle(forWritingTo: url);defer { try? handle.close() }
            try handle.truncate(atOffset: UInt64(limit + 1));return url
        }
        for (name,limit) in [("library-v1.json",10),("epub-v1.json",10),("comics-v1.json",10),("docx-mammoth-v1.json",10),("learning-v1.json",5)] {
            let url = try oversized(name,limit * 1024 * 1024),backup = url.appendingPathExtension("backup")
            try Data("Original backup sentinel".utf8).write(to: backup)
            if name == "library-v1.json" {
                await #expect(throws: BoundedFileReadError.resourceLimit) { try await LibraryRepository(root: root).load() }
                await #expect(throws: BoundedFileReadError.resourceLimit) { try await LibraryRepository(root: root).importPDF(originalSample(),filename: "original.pdf",pageCount: 2) }
            } else if name == "epub-v1.json" { await #expect(throws: BoundedFileReadError.resourceLimit) { try await EPUBRepository(root: root).load() } }
            else if name == "comics-v1.json" { await #expect(throws: BoundedFileReadError.resourceLimit) { try await ComicRepository(root: root).load() } }
            else if name == "docx-mammoth-v1.json" { await #expect(throws: DOCXError.resourceLimit) { try await DOCXRepository(root: root).load() } }
            else { await #expect(throws: BoundedFileReadError.resourceLimit) { try await AILearningRepository(root: root).load() } }
            #expect(try url.resourceValues(forKeys: [.fileSizeKey]).fileSize == limit * 1024 * 1024 + 1)
            #expect(try Data(contentsOf: backup) == Data("Original backup sentinel".utf8))
            try FileManager.default.removeItem(at: url)
        }
        let pdf = LibraryRepository(root: root),data = try originalSample(),book = try await pdf.importPDF(data,filename: "original.pdf",pageCount: 2)
        _ = try oversized("Originals/" + book.fileSHA256 + ".pdf",200 * 1024 * 1024)
        await #expect(throws: BoundedFileReadError.resourceLimit) { try await pdf.readAsset(for: book) }
        let epub = EPUBRepository(root: root),url = try #require(Bundle.module.url(forResource: "study-sample",withExtension: "epub",subdirectory: "Fixtures"))
        let item = try await epub.importBook(Data(contentsOf: url),filename: "original.epub")
        _ = try oversized("Originals/" + item.fileSHA256 + ".epub",20 * 1024 * 1024)
        await #expect(throws: BoundedFileReadError.resourceLimit) { try await epub.read(item) }
    }
    @Test func limitAndSpecialFilesAreRejectedBeforeReading() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let original = root.appendingPathComponent("original"), alias = root.appendingPathComponent("alias"), fifo = root.appendingPathComponent("fifo")
        try Data(repeating: 65, count: 1025).write(to: original)
        #expect(throws: BoundedFileReadError.resourceLimit) { try BoundedFileReader.read(original, limit: 1024) }
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: original)
        #expect(throws: BoundedFileReadError.unreadable) { try BoundedFileReader.read(alias, limit: 2048) }
        #expect(mkfifo(fifo.path, 0o600) == 0)
        #expect(throws: BoundedFileReadError.invalidFile) { try BoundedFileReader.read(fifo, limit: 2048) }
        #expect(throws: BoundedFileReadError.invalidFile) { try BoundedFileReader.read(root, limit: 2048) }
        #expect(try BoundedFileReader.read(original, limit: 1025).count == 1025)
    }
    @Test func growthIsBoundedAndPathReplacementCannotChangeOpenedFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("file"), moved = root.appendingPathComponent("moved")
        let original = Data(repeating: 65, count: 128 * 1024)
        try original.write(to: url)
        #expect(throws: BoundedFileReadError.resourceLimit) {
            try BoundedFileReader.read(url, limit: original.count) { count in
                if count == 64 * 1024 {
                    let handle = try FileHandle(forWritingTo: url); defer { try? handle.close() }
                    try handle.seekToEnd(); try handle.write(contentsOf: Data([66]))
                }
            }
        }
        try original.write(to: url)
        let read = try BoundedFileReader.read(url, limit: original.count) { count in
            if count == 64 * 1024 {
                try FileManager.default.moveItem(at: url, to: moved)
                try Data("replacement".utf8).write(to: url)
            }
        }
        #expect(read == original)
        #expect(try Data(contentsOf: url) == Data("replacement".utf8))
    }
}
