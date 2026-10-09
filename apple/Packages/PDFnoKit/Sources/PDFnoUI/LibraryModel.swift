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
    var lastCreatedImport: BundledExampleIdentity?
    @Published var bundledExamples: [BundledExampleRecord] = []
    @Published var isBusy = false
    @Published var storageMaintenance = false
    let storeWriteGate: LocalStoreWriteGate
    @Published var error: String?
    @Published var status = "本地书库 · 云同步未启用"
    @Published var canImport = false
    public let reader = PDFReaderSession()
    let covers: CoverLibraryModel
    let repository: LibraryRepository
    let epubRepository: EPUBRepository
    let comicRepository: ComicRepository
    @Published var comicBooks: [ComicBook] = []
    @Published var readingComic = false
    public let learning: AILearningModel
    public let pageTranslation: PDFPageTranslationModel
    let noteEditing: NoteEditingModel
    public let chapterTranslation: EPUBChapterTranslationModel
    @Published var epubBooks: [EPUBBook] = []
    @Published var epubNotes: [EPUBNote] = []
    @Published var readingEPUB = false
    #if os(macOS)
    public let epub = EPUBReaderSession()
    public let comic = ComicReaderSession()
    public let docx: DOCXLibraryModel
    public let textFormats: TextFormatLibraryModel
    let japaneseRepository: JapaneseLearningRepository
    let englishRepository: EnglishLearningRepository
    @Published var japaneseNotes: [JapaneseLearningNote] = []
    @Published var englishNotes: [EnglishLearningNote] = []
    @Published var englishStoreError: String?
    lazy var englishLearning = makeEnglishLearningModel()
    var englishCommitFence: EnglishLearningSourceCommitFence?
    var needsRecoveryDraftReview = false
    var startupRecoveryCompleted = false
    var startupRecoveryTask: Task<Bool, Never>?
    weak var activeSavedSearch: SavedRecordSearchModel?
    var searchDocumentDidOpen: (@MainActor () -> Void)?
    var recoveryManagement: LocalRecoveryManagementModel?
    var documentVisibleDrafts: Set<String> = []
    @Published var japaneseStoreError: String?
    lazy var japaneseLearning = makeJapaneseLearningModel()
    let recordRoot: URL
    lazy var recordEditing = RecordEditingAdapter(root: recordRoot, library: self)
    let byok: BYOKSettingsModel
    let byokOfflineTransport: Bool
    var byokSource: AISourceSnapshot?
    @Published var byokUserText = ""
    @Published var byokSaveStatus: String?
    private var japanesePDFSelectionChanges: AnyCancellable?
    private var japanesePDFSessionChanges: AnyCancellable?
    private var japaneseEPUBSelectionChanges: AnyCancellable?
    let booknoPreview: BooknoPreviewModel
    private var textChanges: AnyCancellable?
    public let ebook: EbookLibraryModel
    private var ebookChanges: AnyCancellable?
    private var docxChanges: AnyCancellable?
    #endif
    public convenience init() {
        // UI smoke runs use an isolated store, never the user's library.
        let root: URL
        if let token = ProcessInfo.processInfo.environment["PDFNO_UI_TEST_SESSION"] {
            // A malformed test token still gets a fresh isolated directory;
            // it must never fall through to the real user library.
            let value = UUID(uuidString: token) ?? UUID()
            root = Self.isolatedUITestRoot(value)
        } else if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let arguments = ProcessInfo.processInfo.arguments
            let value = arguments.firstIndex(of: "--ui-test-session").flatMap { index in
                arguments.indices.contains(index + 1) ? UUID(uuidString: arguments[index + 1]) : nil
            } ?? UUID()
            root = Self.isolatedUITestRoot(value)
        } else { root = LibraryRepository.defaultRoot() }
        self.init(root: root)
    }
    // Internal injection keeps native source/storage regressions in fresh test
    // directories without configuring or accessing the user's real library.
    init(root: URL, aiSession: AppAISession = .shared, learningTransport: (any AIHTTPTransport)? = nil, byokSession: BYOKProviderSession? = nil) {
        storeWriteGate = LocalStoreWriteGate.shared(root: root)
        covers = CoverLibraryModel.shared(root: root)
        repository = LibraryRepository(root: root)
        epubRepository = EPUBRepository(root: root)
        comicRepository = ComicRepository(root: root)
        #if os(macOS)
        japaneseRepository = JapaneseLearningRepository(root: root)
        englishRepository = EnglishLearningRepository(root: root)
        docx = DOCXLibraryModel(root: root)
        textFormats = TextFormatLibraryModel(root: root)
        booknoPreview = BooknoPreviewModel(repository: BooknoLibraryPreviewRepository(root: root))
        ebook = EbookLibraryModel(root: root)
        recordRoot = root
        #if DEBUG
        if let learningTransport {
            byok = BYOKSettingsModel(session: byokSession ?? BYOKProviderSession(), transport: learningTransport, aiSession: aiSession)
            byokOfflineTransport = true
        } else if let token = ProcessInfo.processInfo.environment["PDFNO_UI_TEST_SESSION"], UUID(uuidString: token) != nil,
                  ProcessInfo.processInfo.environment["PDFNO_UI_TEST_DEEPSEEK"] == "offline" {
            byok = BYOKSettingsModel(session: byokSession ?? BYOKProviderSession(), transport: OfflineSelectionUITestTransport(), aiSession: aiSession)
            byokOfflineTransport = true
        } else {
            byok = BYOKSettingsModel(session: byokSession ?? BYOKProviderSession(), aiSession: aiSession); byokOfflineTransport = false
        }
        #else
        byok = BYOKSettingsModel(session: byokSession ?? BYOKProviderSession(), transport: learningTransport ?? URLSessionAITransport(), aiSession: aiSession)
        byokOfflineTransport = learningTransport != nil
        #endif
        #endif
        #if DEBUG
        if let learningTransport {
            learning = AILearningModel(root: root, transport: learningTransport, offlineTransport: true, aiSession: aiSession)
            pageTranslation = PDFPageTranslationModel(aiSession: aiSession); chapterTranslation = EPUBChapterTranslationModel(aiSession: aiSession)
        } else if let token = ProcessInfo.processInfo.environment["PDFNO_UI_TEST_SESSION"], UUID(uuidString: token) != nil,
           ProcessInfo.processInfo.environment["PDFNO_UI_TEST_DEEPSEEK"] == "offline" {
            learning = AILearningModel(root: root, transport: OfflineSelectionUITestTransport(), offlineTransport: true, aiSession: aiSession)
            chapterTranslation = EPUBChapterTranslationModel(transport: OfflineSelectionUITestTransport(pageScenario: ProcessInfo.processInfo.environment["PDFNO_UI_TEST_CHAPTER_RESPONSE"]), offlineTransport: true, aiSession: aiSession)
            pageTranslation = PDFPageTranslationModel(transport: OfflineSelectionUITestTransport(pageScenario: ProcessInfo.processInfo.environment["PDFNO_UI_TEST_PAGE_RESPONSE"]), offlineTransport: true, aiSession: aiSession)
        } else { learning = AILearningModel(root: root, aiSession: aiSession); pageTranslation = PDFPageTranslationModel(aiSession: aiSession); chapterTranslation = EPUBChapterTranslationModel(aiSession: aiSession) }
        #else
        learning = AILearningModel(root: root, transport: learningTransport ?? URLSessionAITransport(), offlineTransport: learningTransport != nil, aiSession: aiSession); pageTranslation = PDFPageTranslationModel(aiSession: aiSession); chapterTranslation = EPUBChapterTranslationModel(aiSession: aiSession)
        #endif
        #if DEBUG && os(macOS)
        let failureFixture = NoteEditingFilesystemUITestFixture(root: root)
        let beforePDFBodySave: @MainActor () throws -> Void = { try failureFixture?.prepareAttempt() }
        #else
        let beforePDFBodySave: @MainActor () throws -> Void = {}
        #endif
        noteEditing = NoteEditingModel(root: root) { [repository, epubRepository, learningRepository = learning.repository, gate = storeWriteGate] snapshot, text in
            let operation = try gate.beginWrite(); defer { operation.finish() }
            switch snapshot {
            case .pdf(let note):
                try beforePDFBodySave()
                return .pdf(try await repository.updateNoteBody(expected: note, text: text))
            case .epub(let note): return .epub(try await epubRepository.updateNoteBody(expected: note, text: text))
            case .learning(let note): return .learning(try await learningRepository.updateNoteBody(expected: note, text: text))
            }
        }
        #if os(macOS)
        // The sidebar reads this nested model even while its reader is inactive.
        // Forward asynchronous load/restart changes as well as routed imports.
        ebookChanges = ebook.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        // The independent BYOK owner has its own source/session/configuration fences.
        // Hiding or cancelling the reading provider must not revoke a BYOK result.
        learning.japaneseScopeDidInvalidate = { [weak self] in self?.invalidateJapaneseLearning(); self?.invalidateEnglishLearning() }
        epub.translationScopeDidChange = { [weak self] in self?.learning.invalidateParagraphSource(); self?.chapterTranslation.cancel(); self?.invalidateJapaneseLearning(); self?.invalidateEnglishLearning(); self?.invalidateBYOKSelection() }
        japanesePDFSessionChanges = reader.$readerSessionID.dropFirst().sink { [weak self] _ in self?.learning.invalidateParagraphSource(); self?.invalidateJapaneseLearning(); self?.invalidateEnglishLearning(); self?.invalidateBYOKSelection() }
        japanesePDFSelectionChanges = reader.$capturedSelection.dropFirst().sink { [weak self] anchor in
            self?.japaneseSelectionDidChange(anchor.map(AISelectionAnchor.pdf)); self?.byokSelectionDidChange(anchor.map(AISelectionAnchor.pdf))
            self?.englishSelectionDidChange(anchor.map(AISelectionAnchor.pdf)); self?.paragraphSelectionDidChange(anchor.map(AISelectionAnchor.pdf))
        }
        japaneseEPUBSelectionChanges = epub.$selection.dropFirst().sink { [weak self] anchor in
            self?.japaneseSelectionDidChange(anchor.map(AISelectionAnchor.epub)); self?.byokSelectionDidChange(anchor.map(AISelectionAnchor.epub))
            self?.englishSelectionDidChange(anchor.map(AISelectionAnchor.epub)); self?.paragraphSelectionDidChange(anchor.map(AISelectionAnchor.epub))
        }
        docxChanges = docx.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        textChanges = textFormats.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        LibraryMaintenanceOwners.register(self, root: root)
        #endif
    }
    private static func isolatedUITestRoot(_ value: UUID) -> URL {
        #if os(macOS)
        // XCTest's runner and the launched app can have different TMPDIR values.
        // A fresh, private UUID directory is shared only by this isolated test.
        let parent = URL(fileURLWithPath: "/tmp", isDirectory: true)
        let root = parent.appendingPathComponent("PDFno-UITests-" + value.uuidString)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        return root
        #else
        return FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-UITests-" + value.uuidString)
        #endif
    }
    var progressSequence = 0
    func load() async {
        #if os(macOS)
        if !startupRecoveryCompleted { guard await recoverStorageOnStartup() else { return } }
        #endif
        await reloadStoredLibrary()
    }
    func reloadStoredLibrary() async {
        #if os(macOS)
        comic.persist = { [weak self, comicRepository, gate = storeWriteGate, epoch = storeWriteGate.snapshot.epoch] bookID, progress in
            guard let self, !storageMaintenance, readingComic, comic.book?.id == bookID else { throw ComicError.cancelled }
            let operation = try gate.beginWrite(expectedEpoch: epoch); defer { operation.finish() }
            try Task.checkCancellation(); try await comicRepository.saveProgress(progress, bookID: bookID)
        }
        #endif
        do {
            let state = try await repository.load()
            // Resolve the example partition before publishing any book rows.
            // A row must not appear as personal and disappear during reload.
            bundledExamples = try await BundledExampleRepository(root: repository.root).load().records
            books = state.books; notes = state.notes; canImport = true
            let epubState = try await epubRepository.load(); epubBooks = epubState.books; epubNotes = epubState.notes
            comicBooks = try await comicRepository.load().books
            #if os(macOS)
            try await docx.load()
            try await textFormats.load()
            try await ebook.load()
            #endif
            await learning.load()
            #if os(macOS)
            await loadJapaneseLearningNotes()
            await loadEnglishLearningNotes()
            #endif
        } catch { self.error = error.localizedDescription; canImport = false }
    }
    func importFile(_ url: URL) async {
        lastCreatedImport = nil
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return  }
        defer { hostOperation.finish() }
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        await saveProgress()
        if url.pathExtension.lowercased() == "doc" { error = DOCXError.legacyDOC.localizedDescription; return }
        #if os(macOS)
        if TextFileFormat.from(filename: url.lastPathComponent) != nil { await importTextFormat(url); return }
        if EbookFormat(rawValue: url.pathExtension.lowercased()) != nil { await importEbook(url); return }
        if url.pathExtension.lowercased() == "docx" { await importDOCX(url); return }
        #endif
        if ["cbz", "cbt", "cb7", "cbr"].contains(url.pathExtension.lowercased()) { await importComic(url); return }
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
            let data = try await Task.detached { try BoundedFileReader.read(url, limit: 200 * 1024 * 1024) }.value
            guard let document = PDFDocument(data: data), !document.isLocked, document.pageCount > 0 else { throw ReaderError.invalidPDF }
            let imported = try await repository.importPDFWithStatus(data, filename: url.lastPathComponent, pageCount: document.pageCount)
            let book = imported.book
            if imported.created { lastCreatedImport = .init(format: "pdf", bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256) }
            await load(); try reader.open(data: data, book: book); reader.project(notes)
            #if os(macOS)
            epub.close(); comic.close(); docx.deactivate(); textFormats.deactivate(); ebook.deactivate()
            #endif
            readingEPUB = false; readingComic = false
            status = "已保存到本地 · 原文件未改写"
        } catch { self.error = error.localizedDescription }
    }
    func open(_ book: BookRecord) async {
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return  }
        defer { hostOperation.finish() }
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        do {
            await saveProgress()
            let state = try await repository.load()
            guard let current = state.books.first(where: { $0.id == book.id }) else { throw LibraryError.sourceMismatch }
            let data = try await repository.readAsset(for: current)
            books = state.books; notes = state.notes
            try reader.open(data: data, book: current); reader.project(notes)
            #if os(macOS)
            epub.close(); comic.close(); docx.deactivate(); textFormats.deactivate(); ebook.deactivate()
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
            learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
            guard canImport, !isBusy else { return }; isBusy = true; defer { isBusy = false }
            do {
                let book = try await repository.importPDF(data, filename: "original-page-fixture.pdf", pageCount: 1)
                await load(); try reader.open(data: data, book: book); reader.project(notes)
                #if os(macOS)
                epub.close(); comic.close(); docx.deactivate(); textFormats.deactivate(); ebook.deactivate()
                #endif
                readingEPUB = false; readingComic = false
            } catch { self.error = error.localizedDescription }
            return
        }
        #endif
        guard let url = Bundle.module.url(forResource: "study-sample", withExtension: "pdf") else {
            error = "随应用提供的测试 PDF 缺失。"; return
        }
        await importBundledExample(url)
    }
    func saveNote(anchor: PDFSourceAnchor, text: String) async -> Bool {
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return false }
        defer { hostOperation.finish() }
        guard let book = reader.book, reader.resolution(of: anchor) == .exact else {
            error = LibraryError.sourceMismatch.localizedDescription; return false
        }
        do {
            try await repository.saveNote(ReadingNote(bookID: book.id, anchor: anchor, userText: text))
            await load(); reader.project(notes); status = "高亮与笔记已保存到本地"; return true
        } catch { self.error = error.localizedDescription; return false }
    }
    /// A local Save button returns only after the note's atomic manifest commit.
    /// Source validation and the host lease remain on the main actor throughout.
    func savePDFNoteImmediately(anchor: PDFSourceAnchor, text: String) -> Bool {
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return false }
        defer { hostOperation.finish() }
        guard let book = reader.book, reader.resolution(of: anchor) == .exact else {
            error = LibraryError.sourceMismatch.localizedDescription; return false
        }
        do {
            let state = try repository.saveNoteImmediately(ReadingNote(bookID: book.id, anchor: anchor, userText: text))
            books = state.books; notes = state.notes; reader.project(notes)
            status = "高亮与笔记已保存到本地"; return true
        } catch { self.error = error.localizedDescription; return false }
    }
    struct PDFProgressSnapshot {
        let bookID: UUID
        let sessionID: UUID
        let pageIndex: Int
        let sequence: Int
    }
    func capturePDFProgress() -> PDFProgressSnapshot? {
        guard !readingEPUB, !readingComic, let book = reader.book else { return nil }
        #if os(macOS)
        guard !docx.isActive, !textFormats.isActive, !ebook.isActive else { return nil }
        #endif
        progressSequence += 1
        return PDFProgressSnapshot(bookID: book.id, sessionID: reader.readerSessionID, pageIndex: reader.pageIndex, sequence: progressSequence)
    }
    func saveProgress() async {
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return  }
        defer { hostOperation.finish() }
        #if os(macOS)
        if textFormats.isActive, let anchor = textFormats.reader.progress { await textFormats.saveProgress(anchor); return }
        if ebook.isActive, let anchor = ebook.reader.progress { await ebook.saveProgress(anchor); return }
        #endif
        if let snapshot = capturePDFProgress() { await saveProgress(snapshot) }
    }
    func saveProgress(_ snapshot: PDFProgressSnapshot) async {
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return  }
        defer { hostOperation.finish() }
        guard snapshot.sequence == progressSequence, snapshot.sessionID == reader.readerSessionID, snapshot.bookID == reader.book?.id else { return }
        do {
            try await repository.saveProgress(bookID: snapshot.bookID, pageIndex: snapshot.pageIndex)
            books = try await repository.load().books
        }
        catch { self.error = error.localizedDescription }
    }
    func importEPUB(_ url: URL) async {
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return  }
        defer { hostOperation.finish() }
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        #if os(macOS)
        guard canImport, !isBusy else { return }; isBusy = true; defer { isBusy = false }
        await saveProgress()
        let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            let info = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard info.isRegularFile == true, let size = info.fileSize, size <= 20 * 1024 * 1024 else { throw EPUBError.resourceLimit }
            let data = try await Task.detached { try BoundedFileReader.read(url, limit: 20 * 1024 * 1024) }.value
            let imported = try await epubRepository.importBookWithStatus(data, filename: url.lastPathComponent)
            let book = imported.book
            if imported.created { lastCreatedImport = .init(format: "epub", bookID: book.id, editionID: book.editionID, fileSHA256: book.fileSHA256) }
            await load(); try await epub.open(data: data, book: book, notes: epubNotes)
            comic.close(); docx.deactivate(); textFormats.deactivate(); ebook.deactivate(); readingComic = false; readingEPUB = true
        } catch { self.error = error.localizedDescription }
        #else
        error = EPUBError.unavailable.localizedDescription
        #endif
    }
    func openEPUB(_ book: EPUBBook) async {
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return  }
        defer { hostOperation.finish() }
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        #if os(macOS)
        guard !isBusy else { return }; isBusy = true; defer { isBusy = false }
        await saveProgress()
        do {
            let state = try await epubRepository.load()
            guard let current = state.books.first(where: { $0.id == book.id }) else { throw EPUBError.sourceMismatch }
            let data = try await epubRepository.read(current)
            try await epub.open(data: data, book: current, notes: state.notes)
            comic.close(); docx.deactivate(); textFormats.deactivate(); ebook.deactivate(); readingComic = false; readingEPUB = true
        }
        catch { self.error = error.localizedDescription }
        #else
        error = EPUBError.unavailable.localizedDescription
        #endif
    }
    func openEPUBSample() async {
        if let url = Bundle.module.url(forResource: "study-sample", withExtension: "epub") { await importBundledExample(url) }
    }
    #if os(macOS)
    func importDOCX(_ url: URL) async {
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return  }
        defer { hostOperation.finish() }
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        guard canImport, !isBusy else { return }; isBusy = true; defer { isBusy = false }
        await saveProgress()
        do {
            try await docx.importFile(url); lastCreatedImport = docx.lastCreatedImport; textFormats.deactivate(); ebook.deactivate(); epub.close(); comic.close(); readingComic = false; readingEPUB = false
            status = "DOCX 已保存到本地 · 语义重排阅读"
        } catch { self.error = error.localizedDescription }
    }
    func openDOCXSample() async {
        if let url = Bundle.module.url(forResource: "study-sample", withExtension: "docx") { await importBundledExample(url) }
    }
    func openDOCX(_ book: DOCXBook) async {
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return  }
        defer { hostOperation.finish() }
        learning.cancel(); pageTranslation.cancel(); chapterTranslation.cancel()
        guard !isBusy else { return }; isBusy = true; defer { isBusy = false }
        await saveProgress()
        do { try await docx.open(book); textFormats.deactivate(); ebook.deactivate(); epub.close(); comic.close(); readingComic = false; readingEPUB = false }
        catch { self.error = error.localizedDescription }
    }
    var currentAIBookID: UUID? { if readingComic || docx.isActive || textFormats.isActive || ebook.isActive { return nil }; return readingEPUB ? epub.book?.id : reader.book?.id }
    func preparePageTranslation() {
        guard !readingEPUB, !readingComic, !docx.isActive, !textFormats.isActive, !ebook.isActive else { pageTranslation.rejectPreparation(PDFPageTranslationFailure.invalidSource); return }
        do { pageTranslation.prepare(try reader.currentPageTextSnapshot()) }
        catch { pageTranslation.rejectPreparation(error) }
    }
    func prepareChapterTranslation() async {
        guard readingEPUB, !readingComic, !docx.isActive, !textFormats.isActive, !ebook.isActive else { chapterTranslation.rejectPreparation(EPUBChapterTranslationFailure.invalidSource); return }
        do { chapterTranslation.prepare(try await epub.currentChapterTextSnapshot()) }
        catch { chapterTranslation.rejectPreparation(error) }
    }
    func validateChapterSource(_ source: AISourceSnapshot) async -> Bool {
        guard readingEPUB, !readingComic, !docx.isActive, !textFormats.isActive, !ebook.isActive, source.isValid,
              case .epubChapter(let anchor) = source.anchor, source.bookID == epub.book?.id,
              epub.book?.accepts(anchor) == true else { return false }
        return await epub.validateChapterAnchor(anchor)
    }
    func captureAISource() -> AISourceSnapshot? {
        guard !readingComic, !docx.isActive, !textFormats.isActive, !ebook.isActive else { return nil }
        if readingEPUB {
            guard let book = epub.book, let anchor = epub.selection, book.accepts(anchor) else { return nil }
            return AISourceSnapshot(bookID: book.id, readerSessionID: epub.readerSessionID, documentVersion: epub.documentVersion, anchor: .epub(anchor))
        }
        reader.captureSelection()
        guard let book = reader.book, let anchor = reader.capturedSelection, reader.resolution(of: anchor) == .exact else { return nil }
        return AISourceSnapshot(bookID: book.id, readerSessionID: reader.readerSessionID, documentVersion: 0, anchor: .pdf(anchor))
    }
    func isCurrentAISource(_ source: AISourceSnapshot) -> Bool {
        guard !readingComic, !docx.isActive, !textFormats.isActive, !ebook.isActive, source.isValid else { return false }
        switch source.anchor {
        case .pdfPage(let anchor): return !readingEPUB && source.bookID == reader.book?.id && source.readerSessionID == reader.readerSessionID && source.documentVersion == 0 && reader.resolution(of: anchor) == .exact
        case .pdf(let anchor): return !readingEPUB && source.bookID == reader.book?.id && source.readerSessionID == reader.readerSessionID && source.documentVersion == 0 && reader.resolution(of: anchor) == .exact
        case .epubChapter(let anchor): return readingEPUB && !epub.busy && source.bookID == epub.book?.id && source.readerSessionID == epub.readerSessionID && source.documentVersion == epub.documentVersion && anchor.spineIndex == epub.spineIndex && epub.book?.accepts(anchor) == true
        case .epub(let anchor): return readingEPUB && source.bookID == epub.book?.id && source.readerSessionID == epub.readerSessionID && source.documentVersion == epub.documentVersion && epub.book?.accepts(anchor) == true
        }
    }
    func returnToAISource(_ source: AISourceSnapshot) async -> Bool {
        guard !readingComic, !docx.isActive, !textFormats.isActive, !ebook.isActive else { learning.error = AIFailure.stale.localizedDescription; return false }
        switch source.anchor {
        case .pdfPage(let anchor):
            guard !readingEPUB, reader.book?.id == source.bookID, reader.navigate(to: anchor) == .exact else { learning.error = AIFailure.stale.localizedDescription; return false }; return true
        case .pdf(let anchor):
            guard !readingEPUB, reader.book?.id == source.bookID, reader.navigate(to: anchor) == .exact else { learning.error = AIFailure.stale.localizedDescription; return false }; return true
        case .epub(let anchor), .epubChapter(let anchor):
            guard readingEPUB, epub.book?.id == source.bookID, epub.book?.accepts(anchor) == true, await epub.command("navigate", anchor: anchor) else { learning.error = AIFailure.stale.localizedDescription; return false }; return true
        }
    }
    func saveEPUBNote(_ anchor: EPUBAnchor, text: String) async -> Bool {
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return false }
        defer { hostOperation.finish() }
        guard let book = epub.book, book.accepts(anchor) else { return false }
        do {
            try await epubRepository.saveNote(EPUBNote(bookID: book.id, anchor: anchor, userText: text))
            await load(); _ = await epub.command("notes", notes: epubNotes.filter { $0.bookID == book.id }); return true
        } catch { self.error = error.localizedDescription; return false }
    }
    func saveEPUBProgress(_ anchor: EPUBAnchor) async {
        guard let hostOperation = try? storeWriteGate.beginWrite() else { return  }
        defer { hostOperation.finish() }
        guard let book = epub.book, book.accepts(anchor) else { return }
        do { try await epubRepository.saveProgress(anchor, bookID: book.id) }
        catch { self.error = error.localizedDescription }
    }
    #endif
}
