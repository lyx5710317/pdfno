// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import CryptoKit
import SwiftUI
import WebKit
import PDFnoDomain

@MainActor private final class DOCXMessages: NSObject, WKScriptMessageHandler {
    weak var session: DOCXReaderSession?
    init(_ session: DOCXReaderSession) { self.session = session }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) { session?.received(message) }
}
@MainActor public final class DOCXReaderSession: NSObject, ObservableObject, WKNavigationDelegate {
    @Published public private(set) var book: DOCXBook?
    @Published public private(set) var document: DOCXDocument?
    @Published public private(set) var webView: WKWebView?
    @Published public private(set) var selection: DOCXAnchor?
    @Published public private(set) var progress: DOCXAnchor?
    @Published public private(set) var error: String?
    @Published public private(set) var ready = false
    @Published public private(set) var highlightsSupported = false
    public private(set) var readerSessionID = UUID()
    private var notes: [DOCXNote] = []
    private var readinessTimeout: Task<Void, Never>?
    private var initialLoad = false
    public func close() {
        readinessTimeout?.cancel(); readinessTimeout = nil; readerSessionID = UUID()
        webView?.stopLoading(); webView?.configuration.userContentController.removeScriptMessageHandler(forName: "docx")
        webView?.navigationDelegate = nil; webView = nil; book = nil; document = nil; notes = []
        selection = nil; progress = nil; error = nil; ready = false; highlightsSupported = false; initialLoad = false
    }
    public func open(data: Data, document: DOCXDocument, book: DOCXBook, notes: [DOCXNote]) throws {
        guard SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == book.fileSHA256,
              document.blocks.count <= 10000, document.text.utf16.count <= 1_000_000 else { throw DOCXError.sourceMismatch }
        close(); self.book = book; self.document = document
        self.notes = notes.filter { $0.bookID == book.id && book.accepts($0.anchor) && document.resolves($0.anchor) }
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.userContentController.add(DOCXMessages(self), name: "docx")
        let web = WKWebView(frame: .zero, configuration: config); web.navigationDelegate = self
        web.allowsBackForwardNavigationGestures = false; webView = web
        let token = readerSessionID
        readinessTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled, let self, self.readerSessionID == token, !self.ready else { return }
            self.fail("DOCX 阅读页面加载超时，请重新打开。")
        }
        web.loadHTMLString(DOCXHTML.render(document, sessionID: token), baseURL: nil)
    }
    private func fail(_ message: String) { let failedBook = book; close(); book = failedBook; error = message }
    func received(_ message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.webView === webView,
              let payload = message.body as? [String: Any], payload["session"] as? String == readerSessionID.uuidString,
              let action = payload["action"] as? String, let book, let document else { return }
        switch action {
        case "ready":
            guard !ready else { return }; ready = true; highlightsSupported = payload["highlights"] as? Bool == true; readinessTimeout?.cancel(); readinessTimeout = nil
            project(notes)
            if let anchor = book.progress, book.accepts(anchor), document.resolves(anchor) { Task { _ = await self.navigate(to: anchor) } }
        case "clear": selection = nil
        case "selection":
            guard ready, let start = payload["start"] as? Int, let end = payload["end"] as? Int,
                  let quote = payload["quote"] as? String, let anchor = document.anchor(book: book, start: start, end: end),
                  anchor.quote.utf16.elementsEqual(quote.utf16) else { selection = nil; return }
            selection = anchor
        case "progress":
            guard ready, let start = payload["start"] as? Int, let block = document.blocks.first(where: { $0.start == start }),
                  let scalar = block.text.unicodeScalars.first else { return }
            progress = document.anchor(book: book, start: start, end: start + (scalar.value > 0xffff ? 2 : 1))
        default: break
        }
    }
    public func navigate(to anchor: DOCXAnchor) async -> Bool {
        guard ready, let book, book.accepts(anchor), document?.resolves(anchor) == true,
              let bytes = try? JSONEncoder().encode(anchor), let json = String(data: bytes, encoding: .utf8), let webView else { return false }
        let token = readerSessionID
        do {
            let result = try await webView.evaluateJavaScript("window.pdfnoDOCX.navigate(\(json))")
            guard token == readerSessionID, (result as? Bool) == true else { return false }
            progress = anchor; return true
        } catch { return false }
    }
    public func navigate(blockID: Int) async -> Bool {
        guard let book, let document, let block = document.blocks.first(where: { $0.id == blockID }),
              let scalar = block.text.unicodeScalars.first,
              let anchor = document.anchor(book: book, start: block.start, end: block.start + (scalar.value > 0xffff ? 2 : 1)) else { return false }
        return await navigate(to: anchor)
    }
    public func project(_ notes: [DOCXNote]) {
        guard let book, let document else { return }
        self.notes = notes.filter { $0.bookID == book.id && book.accepts($0.anchor) && document.resolves($0.anchor) }
        guard ready, let bytes = try? JSONEncoder().encode(self.notes.map(\.anchor)), let json = String(data: bytes, encoding: .utf8) else { return }
        webView?.evaluateJavaScript("window.pdfnoDOCX.notes(\(json))", completionHandler: nil)
    }
    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
        // Exactly one initial, local HTML load. No links, frames, downloads or external navigation.
        let permitted = webView === self.webView && !initialLoad && action.targetFrame?.isMainFrame == true && action.request.url?.absoluteString == "about:blank"
        if permitted { initialLoad = true }
        decisionHandler(permitted ? .allow : .cancel)
    }
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { if webView === self.webView { fail("DOCX 阅读页面加载失败，请重新打开。") } }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if webView === self.webView { fail("DOCX 阅读页面加载失败，请重新打开。") } }
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { if webView === self.webView { fail("DOCX 阅读进程已结束，请重新打开。") } }
}
public struct DOCXCanvas: NSViewRepresentable {
    @ObservedObject public var session: DOCXReaderSession
    public init(session: DOCXReaderSession) { self.session = session }
    public func makeNSView(context: Context) -> NSView { NSView() }
    public func updateNSView(_ view: NSView, context: Context) {
        guard let web = session.webView else { view.subviews.forEach { $0.removeFromSuperview() }; return }
        if web.superview !== view {
            view.subviews.forEach { $0.removeFromSuperview() }; view.addSubview(web)
            web.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([web.leadingAnchor.constraint(equalTo: view.leadingAnchor), web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                         web.topAnchor.constraint(equalTo: view.topAnchor), web.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        }
    }
}
#endif
