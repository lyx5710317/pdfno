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
    public init() {
        // UI smoke runs use an isolated store, never the user's library.
        let root: URL
        if ProcessInfo.processInfo.arguments.contains("--ui-testing") {
            let arguments = ProcessInfo.processInfo.arguments
            let value = arguments.firstIndex(of: "--ui-test-session").flatMap { index in
                arguments.indices.contains(index + 1) ? UUID(uuidString: arguments[index + 1]) : nil
            } ?? UUID()
            root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-UITests-" + value.uuidString)
        } else { root = LibraryRepository.defaultRoot() }
        repository = LibraryRepository(root: root)
    }
    func load() async {
        do {
            let state = try await repository.load(); books = state.books; notes = state.notes; canImport = true
        } catch { self.error = error.localizedDescription; canImport = false }
    }
    func importFile(_ url: URL) async {
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
            status = "已保存到本地 · 原文件未改写"
        } catch { self.error = error.localizedDescription }
    }
    func open(_ book: BookRecord) async {
        guard !isBusy else { return }
        isBusy = true; defer { isBusy = false }
        do {
            let data = try await repository.readAsset(for: book)
            try reader.open(data: data, book: book); reader.project(notes)
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
}
