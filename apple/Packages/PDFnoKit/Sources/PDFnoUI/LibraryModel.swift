// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import SwiftUI
import Combine
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
    let comicRepository: ComicRepository
    @Published var comicBooks: [ComicBook] = []
    @Published var readingComic = false
    public let learning: AILearningModel
    public let pageTranslation: PDFPageTranslationModel
    @Published var epubBooks: [EPUBBook] = []
    @Published var epubNotes: [EPUBNote] = []
    @Published var readingEPUB = false
    #if os(macOS)
    public let epub = EPUBReaderSession()
    public let comic = ComicReaderSession()
    public let docx: DOCXLibraryModel
    private var docxChanges: AnyCancellable?
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
        comicRepository = ComicRepository(root: root)
        #if os(macOS)
        docx = DOCXLibraryModel(root: root)
        #endif
        #if DEBUG
        if let token = ProcessInfo.processInfo.environment["PDFNO_UI_TEST_SESSION"], UUID(uuidString: token) != nil,
           ProcessInfo.processInfo.environment["PDFNO_UI_TEST_DEEPSEEK"] == "offline" {
            learning = AILearningModel(root: root, transport: OfflineSelectionUITestTransport(), offlineTransport: true)
            pageTranslation = PDFPageTranslationModel(transport: OfflineSelectionUITestTransport(pageScenario: ProcessInfo.processInfo.environment["PDFNO_UI_TEST_PAGE_RESPONSE"]), offlineTransport: true)
        } else { learning = AILearningModel(root: root); pageTranslation = PDFPageTranslationModel() }
        #else
        learning = AILearningModel(root: root); pageTranslation = PDFPageTranslationModel()
        #endif
        #if os(macOS)
        // The sidebar reads this nested model even while its reader is inactive.
        // Forward asynchronous load/restart changes as well as routed imports.
        docxChanges = docx.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        #endif
    }
    func load() async {
        #if os(macOS)
        comic.persist = { [comicRepository] bookID, progress in try await comicRepository.saveProgress(progress, bookID: bookID) }
        #endif
        do {
            let state = try await repository.load(); books = state.books; notes = state.notes; canImport = true
            let epubState = try await epubRepository.load(); epubBooks = epubState.books; epubNotes = epubState.notes
            comicBooks = try await comicRepository.load().books
            #if os(macOS)
            try await docx.load()
            #endif
            await learning.load()
        } catch { self.error = error.localizedDescription; canImport = false }
    }
    func importFile(_ url: URL) async {
        learning.cancel(); pageTranslation.cancel()
        if url.pathExtension.lowercased() == "doc" { error = DOCXError.legacyDOC.localizedDescription; return }
        #if os(macOS)
        if url.pathExtension.lowercased() == "docx" { await importDOCX(url); return }
        #endif
        if ["cbz", "cbr"].contains(url.pathExtension.lowercased()) { await importComic(url); return }
        if url.pathExtension.lowercased() == "epub" { await importEPUB(url); return }
        guard url.pathExtension.lowercased() == "pdf" else { error = "此格式尚未接入。"; return }
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
            epub.close(); comic.close(); docx.deactivate()
            #endif
            readingEPUB = false; readingComic = false
            status = "已保存到本地 · 原文件未改写"
        } catch { self.error = error.localizedDescription }
    }
    func open(_ book: BookRecord) async {
        learning.cancel(); pageTranslation.cancel()
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        do {
            let data = try await repository.readAsset(for: book)
            try reader.open(data: data, book: book); reader.project(notes)
            #if os(macOS)
            epub.close(); comic.close(); docx.deactivate()
            #endif
            readingEPUB = false; readingComic = false
        } catch { self.error = error.localizedDescription }
    }
    func openSample() async {
        #if DEBUG
        if let token = ProcessInfo.processInfo.environment["PDFNO_UI_TEST_SESSION"], UUID(uuidString: token) != nil,
           ProcessInfo.processInfo.environment["PDFNO_UI_TEST_DEEPSEEK"] == "offline",
           let mode = ProcessInfo.processInfo.environment["PDFNO_UI_TEST_PAGE_FIXTURE"],
           let data = OriginalPageTranslationUITestPDF.data(mode: mode) {
            learning.cancel(); pageTranslation.cancel()
            guard canImport, !isBusy else { return }; isBusy = true; defer { isBusy = false }
            do {
                let book = try await repository.importPDF(data, filename: "original-page-fixture.pdf", pageCount: 1)
                await load(); try reader.open(data: data, book: book); reader.project(notes)
                #if os(macOS)
                epub.close(); comic.close(); docx.deactivate()
                #endif
                readingEPUB = false; readingComic = false
            } catch { self.error = error.localizedDescription }
            return
        }
        #endif
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
        learning.cancel(); pageTranslation.cancel()
        #if os(macOS)
        guard canImport, !isBusy else { return }; isBusy = true; defer { isBusy = false }
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let info = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard info.isRegularFile == true, let size = info.fileSize, size <= 20 * 1024 * 1024 else { throw EPUBError.resourceLimit }
            let data = try await Task.detached { try Data(contentsOf: url) }.value
            let book = try await epubRepository.importBook(data, filename: url.lastPathComponent)
            await load(); try await epub.open(data: data, book: book, notes: epubNotes)
            comic.close(); docx.deactivate(); readingComic = false; readingEPUB = true
        } catch { self.error = error.localizedDescription }
        #else
        error = EPUBError.unavailable.localizedDescription
        #endif
    }
    func openEPUB(_ book: EPUBBook) async {
        learning.cancel(); pageTranslation.cancel()
        #if os(macOS)
        guard !isBusy else { return }; isBusy = true; defer { isBusy = false }
        do {
            let state = try await epubRepository.load()
            guard let current = state.books.first(where: { $0.id == book.id }) else { throw EPUBError.sourceMismatch }
            let data = try await epubRepository.read(current)
            try await epub.open(data: data, book: current, notes: state.notes)
            comic.close(); docx.deactivate(); readingComic = false; readingEPUB = true
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
    func importDOCX(_ url: URL) async {
        learning.cancel(); pageTranslation.cancel()
        guard canImport, !isBusy else { return }; isBusy = true; defer { isBusy = false }
        do {
            try await docx.importFile(url); epub.close(); comic.close(); readingComic = false; readingEPUB = false
            status = "DOCX 已保存到本地 · 语义重排阅读"
        } catch { self.error = error.localizedDescription }
    }
    func openDOCXSample() async {
        if let url = Bundle.module.url(forResource: "study-sample", withExtension: "docx") { await importDOCX(url) }
    }
    func openDOCX(_ book: DOCXBook) async {
        learning.cancel(); pageTranslation.cancel()
        guard !isBusy else { return }; isBusy = true; defer { isBusy = false }
        do { try await docx.open(book); epub.close(); comic.close(); readingComic = false; readingEPUB = false }
        catch { self.error = error.localizedDescription }
    }
    var currentAIBookID: UUID? { if readingComic || docx.isActive { return nil }; return readingEPUB ? epub.book?.id : reader.book?.id }
    func preparePageTranslation() {
        guard !readingEPUB, !readingComic, !docx.isActive else { pageTranslation.rejectPreparation(PDFPageTranslationFailure.invalidSource); return }
        do { pageTranslation.prepare(try reader.currentPageTextSnapshot()) }
        catch { pageTranslation.rejectPreparation(error) }
    }
    func captureAISource() -> AISourceSnapshot? {
        guard !readingComic, !docx.isActive else { return nil }
        if readingEPUB {
            guard let book = epub.book, let anchor = epub.selection, book.accepts(anchor) else { return nil }
            return AISourceSnapshot(bookID: book.id, readerSessionID: epub.readerSessionID, documentVersion: epub.documentVersion, anchor: .epub(anchor))
        }
        reader.captureSelection()
        guard let book = reader.book, let anchor = reader.capturedSelection, reader.resolution(of: anchor) == .exact else { return nil }
        return AISourceSnapshot(bookID: book.id, readerSessionID: reader.readerSessionID, documentVersion: 0, anchor: .pdf(anchor))
    }
    func isCurrentAISource(_ source: AISourceSnapshot) -> Bool {
        guard !readingComic, !docx.isActive, source.isValid else { return false }
        switch source.anchor {
        case .pdfPage(let anchor): return !readingEPUB && source.bookID == reader.book?.id && source.readerSessionID == reader.readerSessionID && source.documentVersion == 0 && reader.resolution(of: anchor) == .exact
        case .pdf(let anchor): return !readingEPUB && source.bookID == reader.book?.id && source.readerSessionID == reader.readerSessionID && source.documentVersion == 0 && reader.resolution(of: anchor) == .exact
        case .epub(let anchor): return readingEPUB && source.bookID == epub.book?.id && source.readerSessionID == epub.readerSessionID && source.documentVersion == epub.documentVersion && epub.book?.accepts(anchor) == true
        }
    }
    func returnToAISource(_ source: AISourceSnapshot) async -> Bool {
        guard !readingComic, !docx.isActive else { learning.error = AIFailure.stale.localizedDescription; return false }
        switch source.anchor {
        case .pdfPage(let anchor):
            guard !readingEPUB, reader.book?.id == source.bookID, reader.navigate(to: anchor) == .exact else { learning.error = AIFailure.stale.localizedDescription; return false }; return true
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
