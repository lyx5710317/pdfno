// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import PDFKit
import SwiftUI
import PDFnoDomain

public struct OutlineItem: Identifiable {
    public let id = UUID()
    public let title: String
    public let pageIndex: Int
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
    private var restoringView = false
    public init() {}
    public func open(data: Data, book: BookRecord) throws {
        guard let pdf = PDFDocument(data: data), !pdf.isLocked, pdf.pageCount == book.pageCount else {
            throw ReaderError.invalidPDF
        }
        readerSessionID = UUID(); self.document = pdf; self.book = book; pageIndex = book.lastPageIndex
        capturedSelection = nil; searchMatches = []; projected = []; outline = []
        func walk(_ node: PDFOutline) {
            for index in 0..<node.numberOfChildren {
                guard let child = node.child(at: index) else { continue }
                if let page = child.destination?.page {
                    outline.append(OutlineItem(title: child.label ?? "章节", pageIndex: pdf.index(for: page)))
                }
                walk(child)
            }
        }
        if let root = pdf.outlineRoot { walk(root) }
    }
    public func attach(_ view: PDFView) {
        self.view = view
        if view.document !== document {
            let target = pageIndex
            restoringView = true
            view.document = document
            let opened = document
            // Installing a document emits an initial page-0 notification. Ignore it;
            // restore after the native view has entered SwiftUI's layout cycle.
            Task { @MainActor [weak self, weak view] in
                await Task.yield()
                guard let self, let view, self.document === opened, view.document === opened else { return }
                if let page = opened?.page(at: target) { view.go(to: page) }
                self.pageIndex = target
                self.restoringView = false
            }
        }
    }
    public func updatePage() {
        guard !restoringView, let page = view?.currentPage, let document else { return }
        pageIndex = document.index(for: page)
    }
    public func go(to index: Int) {
        guard let page = document?.page(at: index) else { return }
        view?.go(to: page); pageIndex = index
    }
    public func search(_ text: String) {
        guard document?.allowsCopying == true, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchMatches = []; return
        }
        // Bounded local synchronous search; large-document incremental search remains future work.
        searchMatches = Array((document?.findString(text, withOptions: .caseInsensitive) ?? []).prefix(100))
    }
    public func show(_ selection: PDFSelection) {
        view?.setCurrentSelection(selection, animate: true); view?.go(to: selection); updatePage()
    }
    public func captureSelection() {
        guard let book, let document, document.allowsCopying,
              let selection = view?.currentSelection, let quote = selection.string, !quote.isEmpty else {
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
    public func resolution(of anchor: PDFSourceAnchor) -> AnchorResolution {
        guard let book, let document else { return .sourceMissing }
        guard anchor.editionID == book.editionID, anchor.fileSHA256 == book.fileSHA256,
              anchor.schemaVersion == 1, anchor.extractionVersion == "pdfkit-selection-1" else { return .needsRebind }
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
        view?.go(to: CGRect(x: first.x, y: first.y, width: first.width, height: first.height), on: page)
        pageIndex = first.pageIndex
        if let selection = page.selection(for: CGRect(x: first.x, y: first.y, width: first.width, height: first.height)) {
            view?.setCurrentSelection(selection, animate: true)
        }
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
