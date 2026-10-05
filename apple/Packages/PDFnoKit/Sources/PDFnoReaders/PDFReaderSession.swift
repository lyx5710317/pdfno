// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFKit
import SwiftUI
import PDFnoDomain

public struct OutlineItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let pageIndex: Int
    public let readerSessionID: UUID
}

@MainActor
public final class PDFReaderSession: ObservableObject {
    @Published public private(set) var readerSessionID = UUID()
    @Published public private(set) var document: PDFDocument?
    @Published public private(set) var book: BookRecord?
    @Published public private(set) var pageIndex = 0
    @Published public private(set) var capturedSelection: PDFSourceAnchor?
    @Published public private(set) var searchMatches: [PDFSelection] = []
    @Published public private(set) var outline: [OutlineItem] = []
    public weak var view: PDFView?
    private var projected: [(PDFPage, PDFAnnotation)] = []
    @Published public private(set) var canReturnToPreviousLocation = false
    private var navigationHistory = ReaderNavigationHistory<Int>()
    private var restorationID: UUID?
    private var restorationTask: Task<Void, Never>?
    var isRestoringPosition: Bool { restorationID != nil }
    private func cancelRestoration() {
        restorationTask?.cancel(); restorationTask = nil; restorationID = nil
    }
    private func clearNavigation() {
        navigationHistory.clear(); canReturnToPreviousLocation = false
    }
    private func recordJump(from origin: Int, to target: Int) {
        navigationHistory.record(origin, destination: target)
        canReturnToPreviousLocation = navigationHistory.previous != nil
    }
    public init() {}
    public func close() {
        cancelRestoration(); clearNavigation()
        for (page, annotation) in projected { page.removeAnnotation(annotation) }
        projected = []; document = nil; book = nil; capturedSelection = nil
        searchMatches = []; outline = []; pageIndex = 0
        readerSessionID = UUID(); view?.document = nil
    }
    public func open(data: Data, book: BookRecord) throws {
        guard let pdf = PDFDocument(data: data), !pdf.isLocked, pdf.pageCount == book.pageCount,
              (0..<pdf.pageCount).contains(book.lastPageIndex) else {
            throw ReaderError.invalidPDF
        }
        cancelRestoration(); clearNavigation()
        readerSessionID = UUID(); self.document = pdf; self.book = book; pageIndex = book.lastPageIndex
        capturedSelection = nil; searchMatches = []; projected = []; outline = []
        func walk(_ node: PDFOutline) {
            for index in 0..<node.numberOfChildren {
                guard let child = node.child(at: index) else { continue }
                if let page = child.destination?.page {
                    outline.append(OutlineItem(title: child.label ?? "章节", pageIndex: pdf.index(for: page), readerSessionID: readerSessionID))
                }
                walk(child)
            }
        }
        if let root = pdf.outlineRoot { walk(root) }
    }
    public func attach(_ view: PDFView) {
        let changedView = self.view !== view
        if changedView { cancelRestoration() }
        self.view = view
        if view.document !== document {
            cancelRestoration()
            guard let opened = document else { view.document = nil; return }
            let target = pageIndex, token = UUID(), sessionID = readerSessionID
            restorationID = token
            view.document = opened
            // Ignore the initial page-0 notification. A newer user jump, host or book
            // invalidates this deferred restoration before it can change progress.
            restorationTask = Task { @MainActor [weak self, weak view] in
                await Task.yield()
                guard !Task.isCancelled, let self, let view, self.restorationID == token,
                      self.readerSessionID == sessionID, self.view === view,
                      self.document === opened, view.document === opened else { return }
                if let page = opened.page(at: target) { view.go(to: page) }
                self.pageIndex = target
                self.restorationID = nil; self.restorationTask = nil
            }
        }
    }
    public func detach(_ view: PDFView) {
        guard self.view === view else { return }
        cancelRestoration(); self.view = nil
    }
    public func updatePage() {
        guard !isRestoringPosition, let view, let document, view.document === document,
              let page = view.currentPage else { return }
        let index = document.index(for: page)
        if (0..<document.pageCount).contains(index) { pageIndex = index }
    }
    @discardableResult public func go(to index: Int) -> Bool {
        guard let document, let page = document.page(at: index) else { return false }
        cancelRestoration()
        if let view, view.document === document { view.go(to: page) }
        pageIndex = index
        return true
    }
    /// Explicit TOC/page-list jump; normal next/previous page turns do not grow history.
    @discardableResult public func jump(to index: Int) -> Bool {
        let origin = pageIndex
        guard go(to: index) else { return false }
        recordJump(from: origin, to: index)
        return true
    }
    @discardableResult public func jump(to index: Int, in sessionID: UUID) -> Bool {
        guard readerSessionID == sessionID else { return false }
        return jump(to: index)
    }
    @discardableResult public func jump(to item: OutlineItem) -> Bool {
        guard item.readerSessionID == readerSessionID else { return false }
        return jump(to: item.pageIndex)
    }
    @discardableResult public func returnToPreviousLocation() -> Bool {
        guard let previous = navigationHistory.previous, go(to: previous) else { return false }
        navigationHistory.returned(to: previous)
        canReturnToPreviousLocation = navigationHistory.previous != nil
        return true
    }
    public func search(_ text: String) {
        guard document?.allowsCopying == true, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchMatches = []; return
        }
        // Bounded local synchronous search; large-document incremental search remains future work.
        searchMatches = Array((document?.findString(text, withOptions: .caseInsensitive) ?? []).prefix(100))
    }
    @discardableResult public func show(_ selection: PDFSelection) -> Bool {
        guard let document, !selection.pages.isEmpty,
              selection.pages.allSatisfy({ (0..<document.pageCount).contains(document.index(for: $0)) }),
              let first = selection.pages.first else { return false }
        let target = document.index(for: first), origin = pageIndex
        cancelRestoration()
        if let view, view.document === document {
            view.setCurrentSelection(selection, animate: true); view.go(to: selection)
        }
        pageIndex = target; recordJump(from: origin, to: target)
        return true
    }
    public func captureSelection() {
        guard let book, let document, document.allowsCopying, let view, view.document === document,
              let selection = view.currentSelection, let quote = selection.string, !quote.isEmpty else {
            return // Retain the immutable snapshot when focus moves to the notes sheet.
        }
        var regions: [PageRegion] = []
        for line in selection.selectionsByLine() {
            guard let lineQuote = line.string, !lineQuote.isEmpty else { continue }
            for page in line.pages {
                let rect = line.bounds(for: page)
                guard !rect.isEmpty, !rect.isInfinite, !rect.isNull else { continue }
                regions.append(PageRegion(pageIndex: document.index(for: page), x: rect.minX, y: rect.minY,
                                          width: rect.width, height: rect.height, quote: lineQuote))
            }
        }
        capturedSelection = regions.isEmpty ? nil : PDFSourceAnchor(editionID: book.editionID,
            fileSHA256: book.fileSHA256, quote: quote, regions: regions)
    }
    public func currentPageTextSnapshot() throws -> PDFPageTextSnapshot {
        guard let book, let document, let page = document.page(at: pageIndex) else { throw PDFPageTranslationFailure.invalidSource }
        guard document.allowsCopying else { throw PDFPageTranslationFailure.copyingRestricted }
        guard let text = page.string, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw PDFPageTranslationFailure.noText }
        return PDFPageTextSnapshot(bookID: book.id, readerSessionID: readerSessionID, editionID: book.editionID,
                                   fileSHA256: book.fileSHA256, pageIndex: pageIndex, text: text)
    }
    public func resolution(of anchor: PDFPageTextAnchor) -> AnchorResolution {
        guard let book, let document else { return .sourceMissing }
        guard anchor.isValid, anchor.editionID == book.editionID, anchor.fileSHA256 == book.fileSHA256,
              document.allowsCopying, let text = document.page(at: anchor.pageIndex)?.string,
              text.unicodeScalars.elementsEqual(anchor.pageText.unicodeScalars) else { return .needsRebind }
        return .exact
    }
    @discardableResult public func navigate(to anchor: PDFPageTextAnchor) -> AnchorResolution {
        let result = resolution(of: anchor)
        if result == .exact { jump(to: anchor.pageIndex) }
        return result
    }
    public func resolution(of anchor: PDFSourceAnchor) -> AnchorResolution {
        guard let book, let document else { return .sourceMissing }
        guard anchor.editionID == book.editionID, anchor.fileSHA256 == book.fileSHA256,
              anchor.schemaVersion == 1, anchor.extractionVersion == "pdfkit-selection-1", anchor.hasConsistentQuote else { return .needsRebind }
        for region in anchor.regions {
            guard let page = document.page(at: region.pageIndex),
                  let selected = page.selection(for: CGRect(x: region.x, y: region.y, width: region.width, height: region.height)),
                  let quote = selected.string, quote.unicodeScalars.elementsEqual(region.quote.unicodeScalars) else { return .needsRebind }
        }
        return anchor.regions.isEmpty ? .needsRebind : .exact
    }
    @discardableResult public func navigate(to anchor: PDFSourceAnchor) -> AnchorResolution {
        let result = resolution(of: anchor)
        guard result == .exact, let first = anchor.regions.first, let page = document?.page(at: first.pageIndex) else { return result }
        let origin = pageIndex
        cancelRestoration()
        if let view, view.document === document {
            view.go(to: CGRect(x: first.x, y: first.y, width: first.width, height: first.height), on: page)
            if let selection = page.selection(for: CGRect(x: first.x, y: first.y, width: first.width, height: first.height)) {
                view.setCurrentSelection(selection, animate: true)
            }
        }
        pageIndex = first.pageIndex; recordJump(from: origin, to: first.pageIndex)
        return result
    }
    public func project(_ notes: [ReadingNote]) {
        projected.forEach { $0.0.removeAnnotation($0.1) }; projected = []
        for note in notes where note.bookID == book?.id && resolution(of: note.anchor) == .exact {
            for region in note.anchor.regions {
                guard let page = document?.page(at: region.pageIndex) else { continue }
                let mark = PDFAnnotation(bounds: CGRect(x: region.x, y: region.y, width: region.width, height: region.height),
                                         forType: .highlight, withProperties: nil)
                #if os(macOS)
                mark.color = NSColor.systemYellow.withAlphaComponent(0.35)
                #else
                mark.color = UIColor.systemYellow.withAlphaComponent(0.35)
                #endif
                page.addAnnotation(mark); projected.append((page, mark))
            }
        }
        // Projection is in memory only. Never write user originals.
    }
}

public enum ReaderError: LocalizedError {
    case invalidPDF
    public var errorDescription: String? { "PDF 无法打开或需要密码。当前版本不处理加密文件，请使用已解锁副本。" }
}

/// Minimal candidate-comparison contract. The current Mac reader uses EPUBReaderSession.
public protocol EPUBEngineAdapter: Sendable {
    var engineIdentifier: String { get }
    var capability: ReaderCapability { get }
    func validateLocator(_ locator: EPUBLocator) async -> Bool
}
