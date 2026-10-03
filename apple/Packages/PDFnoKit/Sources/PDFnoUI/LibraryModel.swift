// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import SwiftUI
import PDFKit
import PDFnoDomain
import PDFnoServices
import PDFnoReaders

@MainActor
public final class LibraryModel: ObservableObject {
    @Published var books: [BookRecord] = []
    @Published var notes: [ReadingNote] = []
    @Published var isBusy = false
    @Published var error: String?
    @Published var status = "本地书库 · 云同步未启用"
    @Published var canImport = false
    public let reader = PDFReaderSession()
    let repository: LibraryRepository
    let epubRepository: EPUBRepository
    public let learning: AILearningModel
    @Published var epubBooks: [EPUBBook] = []
    @Published var epubNotes: [EPUBNote] = []
    @Published var readingEPUB = false
    #if os(macOS)
    public let epub = EPUBReaderSession()
    #endif
    public init() {
        // UI smoke runs use an isolated store, never the user's library.
        let root: URL
        if let token = ProcessInfo.processInfo.environment["PDFNO_UI_TEST_SESSION"] {
            // A malformed test token still gets a fresh isolated directory;
            // it must never fall through to the real user library.
            let value = UUID(uuidString: token) ?? UUID()
            root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-UITests-" + value.uuidString)
        } else if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let arguments = ProcessInfo.processInfo.arguments
            let value = arguments.firstIndex(of: "--ui-test-session").flatMap { index in
                arguments.indices.contains(index + 1) ? UUID(uuidString: arguments[index + 1]) : nil
            } ?? UUID()
            root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-UITests-" + value.uuidString)
        } else { root = LibraryRepository.defaultRoot() }
        repository = LibraryRepository(root: root)
        epubRepository = EPUBRepository(root: root)
        #if DEBUG
        if let token = ProcessInfo.processInfo.environment["PDFNO_UI_TEST_SESSION"], UUID(uuidString: token) != nil,
           ProcessInfo.processInfo.environment["PDFNO_UI_TEST_DEEPSEEK"] == "offline" {
            learning = AILearningModel(root: root, transport: OfflineSelectionUITestTransport(), offlineTransport: true)
        } else { learning = AILearningModel(root: root) }
        #else
        learning = AILearningModel(root: root)
        #endif
    }
    func load() async {
        do {
            let state = try await repository.load(); books = state.books; notes = state.notes; canImport = true
            let epubState = try await epubRepository.load(); epubBooks = epubState.books; epubNotes = epubState.notes
            await learning.load()
        } catch { self.error = error.localizedDescription; canImport = false }
    }
    func importFile(_ url: URL) async {
        learning.cancel()
        if url.pathExtension.lowercased() == "epub" { await importEPUB(url); return }
        guard canImport, !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let size = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard size.isRegularFile == true else { throw LibraryError.invalidDocument }
            guard let bytes = size.fileSize, bytes <= 200 * 1024 * 1024 else { throw LibraryError.fileTooLarge }
            let data = try await Task.detached { try Data(contentsOf: url) }.value
            guard let document = PDFDocument(data: data), !document.isLocked, document.pageCount > 0 else { throw ReaderError.invalidPDF }
            let book = try await repository.importPDF(data, filename: url.lastPathComponent, pageCount: document.pageCount)
            await load(); try reader.open(data: data, book: book); reader.project(notes)
            #if os(macOS)
            epub.close()
            #endif
            readingEPUB = false
            status = "已保存到本地 · 原文件未改写"
        } catch { self.error = error.localizedDescription }
    }
    func open(_ book: BookRecord) async {
        learning.cancel()
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        do {
            let data = try await repository.readAsset(for: book)
            try reader.open(data: data, book: book); reader.project(notes)
            #if os(macOS)
            epub.close()
            #endif
            readingEPUB = false
        } catch { self.error = error.localizedDescription }
    }
    func openSample() async {
        guard let url = Bundle.module.url(forResource: "study-sample", withExtension: "pdf") else {
            error = "随应用提供的测试 PDF 缺失。"; return
        }
        await importFile(url)
    }
    func saveNote(anchor: PDFSourceAnchor, text: String) async -> Bool {
        guard let book = reader.book, reader.resolution(of: anchor) == .exact else {
            error = LibraryError.sourceMismatch.localizedDescription; return false
        }
        do {
            try await repository.saveNote(ReadingNote(bookID: book.id, anchor: anchor, userText: text))
            await load(); reader.project(notes); status = "高亮与笔记已保存到本地"; return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func saveProgress() async {
        guard let book = reader.book else { return }
        do { try await repository.saveProgress(bookID: book.id, pageIndex: reader.pageIndex) }
        catch { self.error = error.localizedDescription }
    }
    func importEPUB(_ url: URL) async {
        learning.cancel()
        #if os(macOS)
        guard canImport, !isBusy else { return }; isBusy = true; defer { isBusy = false }
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let info = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard info.isRegularFile == true, let size = info.fileSize, size <= 20 * 1024 * 1024 else { throw EPUBError.resourceLimit }
            let data = try await Task.detached { try Data(contentsOf: url) }.value
            let book = try await epubRepository.importBook(data, filename: url.lastPathComponent)
            await load(); readingEPUB = true; try await epub.open(data: data, book: book, notes: epubNotes)
        } catch { self.error = error.localizedDescription }
        #else
        error = EPUBError.unavailable.localizedDescription
        #endif
    }
    func openEPUB(_ book: EPUBBook) async {
        learning.cancel()
        #if os(macOS)
        guard !isBusy else { return }; isBusy = true; defer { isBusy = false }
        do {
            let state = try await epubRepository.load()
            guard let current = state.books.first(where: { $0.id == book.id }) else { throw EPUBError.sourceMismatch }
            let data = try await epubRepository.read(current); readingEPUB = true
            try await epub.open(data: data, book: current, notes: state.notes)
        }
        catch { self.error = error.localizedDescription }
        #else
        error = EPUBError.unavailable.localizedDescription
        #endif
    }
    func openEPUBSample() async {
        if let url = Bundle.module.url(forResource: "study-sample", withExtension: "epub") { await importEPUB(url) }
    }
    #if os(macOS)
    var currentAIBookID: UUID? { readingEPUB ? epub.book?.id : reader.book?.id }
    func captureAISource() -> AISourceSnapshot? {
        if readingEPUB {
            guard let book = epub.book, let anchor = epub.selection, book.accepts(anchor) else { return nil }
            return AISourceSnapshot(bookID: book.id, readerSessionID: epub.readerSessionID, documentVersion: epub.documentVersion, anchor: .epub(anchor))
        }
        reader.captureSelection()
        guard let book = reader.book, let anchor = reader.capturedSelection, reader.resolution(of: anchor) == .exact else { return nil }
        return AISourceSnapshot(bookID: book.id, readerSessionID: reader.readerSessionID, documentVersion: 0, anchor: .pdf(anchor))
    }
    func isCurrentAISource(_ source: AISourceSnapshot) -> Bool {
        guard source.isValid else { return false }
        switch source.anchor {
        case .pdf(let anchor): return !readingEPUB && source.bookID == reader.book?.id && source.readerSessionID == reader.readerSessionID && source.documentVersion == 0 && reader.resolution(of: anchor) == .exact
        case .epub(let anchor): return readingEPUB && source.bookID == epub.book?.id && source.readerSessionID == epub.readerSessionID && source.documentVersion == epub.documentVersion && epub.book?.accepts(anchor) == true
        }
    }
    func returnToAISource(_ source: AISourceSnapshot) async -> Bool {
        switch source.anchor {
        case .pdf(let anchor):
            guard !readingEPUB, reader.book?.id == source.bookID, reader.navigate(to: anchor) == .exact else { learning.error = AIFailure.stale.localizedDescription; return false }; return true
        case .epub(let anchor):
            guard readingEPUB, epub.book?.id == source.bookID, epub.book?.accepts(anchor) == true, await epub.command("navigate", anchor: anchor) else { learning.error = AIFailure.stale.localizedDescription; return false }; return true
        }
    }
    func saveEPUBNote(_ anchor: EPUBAnchor, text: String) async -> Bool {
        guard let book = epub.book, book.accepts(anchor) else { return false }
        do {
            try await epubRepository.saveNote(EPUBNote(bookID: book.id, anchor: anchor, userText: text))
            await load(); _ = await epub.command("notes", notes: epubNotes.filter { $0.bookID == book.id }); return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func saveEPUBProgress(_ anchor: EPUBAnchor) async {
        guard let book = epub.book, book.accepts(anchor) else { return }
        do { try await epubRepository.saveProgress(anchor, bookID: book.id) }
        catch { self.error = error.localizedDescription }
    }
    #endif
}
