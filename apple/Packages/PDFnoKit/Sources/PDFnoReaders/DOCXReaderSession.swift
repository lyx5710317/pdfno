// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import CryptoKit
import SwiftUI
import WebKit
import PDFnoDomain
import PDFnoServices

private final class DOCXAssets: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url, url.host == "app", url.path == "/engine.js", url.query == nil,
              let root = Bundle.module.url(forResource: "DOCX", withExtension: nil),
              let bytes = try? Data(contentsOf: root.appendingPathComponent("engine.js")) else {
            task.didFailWithError(DOCXError.bridge); return
        }
        task.didReceive(URLResponse(url: url, mimeType: "application/javascript", expectedContentLength: bytes.count, textEncodingName: "utf-8"))
        task.didReceive(bytes); task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}
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
    private var waitingReady: CheckedContinuation<Void, Error>?
    private var waitingConversion: CheckedContinuation<String, Error>?
    public func close() {
        readinessTimeout?.cancel(); readinessTimeout = nil; readerSessionID = UUID()
        let readyRequest = waitingReady; waitingReady = nil; readyRequest?.resume(throwing: DOCXError.cancelled)
        let conversion = waitingConversion; waitingConversion = nil; conversion?.resume(throwing: DOCXError.cancelled)
        webView?.stopLoading(); webView?.configuration.userContentController.removeScriptMessageHandler(forName: "docx")
        webView?.navigationDelegate = nil; webView = nil; book = nil; document = nil; notes = []
        selection = nil; progress = nil; error = nil; ready = false; highlightsSupported = false; initialLoad = false
    }
    private func fail(_ message: String) { let failedBook = book; close(); book = failedBook; error = message }
    /// Data must already pass native ZIP/XML preflight. Conversion never runs the native semantic candidate.
    public func open(data: Data, book: DOCXBook, notes: [DOCXNote]) async throws {
        guard data.count <= 20 * 1024 * 1024,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == book.fileSHA256 else { throw DOCXError.sourceMismatch }
        // Reserve the generation before any suspension: close/reopen during preflight must cancel this request too.
        close(); self.book = book; let token = readerSessionID
        _ = try await Task.detached { try DOCXParser.preflight(data) }.value
        guard token == readerSessionID, !Task.isCancelled else { throw DOCXError.cancelled }
        let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.setURLSchemeHandler(DOCXAssets(), forURLScheme: "pdfno-docx")
        config.userContentController.add(DOCXMessages(self), name: "docx")
        let rules = String(decoding: try JSONSerialization.data(withJSONObject: ["http", "https", "ftp", "file", "data", "ws", "wss"].map {
            ["trigger": ["url-filter": "^" + $0 + ":"], "action": ["type": "block"]]
        }), as: UTF8.self)
        let list: WKContentRuleList = try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "PDFnoDOCXNoNetwork-v1", encodedContentRuleList: rules) { list, error in
                if let list { continuation.resume(returning: list) } else { continuation.resume(throwing: error ?? DOCXError.bridge) }
            }
        }
        guard token == readerSessionID else { throw DOCXError.cancelled }
        config.userContentController.add(list)
        let web = WKWebView(frame: .zero, configuration: config); web.navigationDelegate = self
        web.allowsBackForwardNavigationGestures = false; webView = web
        readinessTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard !Task.isCancelled, let self, self.readerSessionID == token, !self.ready else { return }
            self.fail(DOCXError.bridge.localizedDescription)
        }
        do {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                waitingReady = continuation
                web.loadHTMLString(DOCXHTML.render(DOCXDocument(blocks: []), sessionID: token, usesMammoth: true), baseURL: nil)
            }
            guard token == readerSessionID else { throw DOCXError.cancelled }
            let message: [String: Any] = ["v": 1, "session": token.uuidString, "bookID": book.id.uuidString,
                "editionID": book.editionID.uuidString, "fileSHA256": book.fileSHA256, "data": data.base64EncodedString()]
            let result: String = try await withCheckedThrowingContinuation { continuation in
                waitingConversion = continuation
                web.callAsyncJavaScript("return await window.PDFnoDOCXEngine.convert(message)", arguments: ["message": message], in: nil, in: .page) { [weak self] result in
                    guard let self, self.readerSessionID == token, self.webView === web, let pending = self.waitingConversion else { return }; self.waitingConversion = nil
                    switch result {
                    case .success(let value):
                        if let text = value as? String { pending.resume(returning: text) } else { pending.resume(throwing: DOCXError.bridge) }
                    case .failure(let error): pending.resume(throwing: error)
                    }
                }
            }
            guard token == readerSessionID, result.utf8.count <= 10 * 1024 * 1024,
                  let object = try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any],
                  object["v"] as? Int == 1, object["session"] as? String == token.uuidString,
                  object["bookID"] as? String == book.id.uuidString, object["editionID"] as? String == book.editionID.uuidString,
                  object["fileSHA256"] as? String == book.fileSHA256, object["engine"] as? String == "kookit-mammoth-1.13.0",
                  object["extractionVersion"] as? String == DOCXDocument.extractionVersion,
                  let html = object["html"] as? String, html.utf8.count <= 4 * 1024 * 1024,
                  let semantic = object["document"] as? [String: Any] else { throw DOCXError.bridge }
            let converted = try JSONDecoder().decode(DOCXDocument.self, from: JSONSerialization.data(withJSONObject: semantic))
            // Insert only the allowlisted Mammoth output and verify actual DOM text against its native canonical DTO.
            let installed = try await web.callAsyncJavaScript("return window.pdfnoDOCX.install(html, expected)", arguments: ["html": html, "expected": converted.text], in: nil, contentWorld: .page)
            guard token == readerSessionID, (installed as? Bool) == true else { throw DOCXError.bridge }
            document = converted; ready = true; readinessTimeout?.cancel(); readinessTimeout = nil
            project(notes)
            if let anchor = book.progress, book.accepts(anchor), converted.resolves(anchor) { _ = await navigate(to: anchor) }
        } catch {
            if token == readerSessionID { fail(error.localizedDescription) }; throw error
        }
    }
    func received(_ message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.webView === webView,
              let payload = message.body as? [String: Any], payload["session"] as? String == readerSessionID.uuidString,
              let action = payload["action"] as? String, let book else { return }
        if action == "ready" {
            highlightsSupported = payload["highlights"] as? Bool == true
            let continuation = waitingReady; waitingReady = nil; continuation?.resume(); return
        }
        guard ready, let document else { return }
        switch action {
        case "clear": selection = nil
        case "selection":
            guard let start = payload["start"] as? Int, let end = payload["end"] as? Int,
                  let quote = payload["quote"] as? String, let anchor = document.anchor(book: book, start: start, end: end),
                  anchor.quote.utf16.elementsEqual(quote.utf16) else { selection = nil; return }; selection = anchor
        case "progress":
            guard let start = payload["start"] as? Int, let block = document.blocks.first(where: { $0.start == start }),
                  let scalar = block.text.unicodeScalars.first else { return }
            progress = document.anchor(book: book, start: start, end: start + (scalar.value > 0xffff ? 2 : 1))
        default: break
        }
    }
    /// Resolve the real DOM selection before native toolbar focus/sheet changes.
    /// The bridge retains only a checked selection on blur; focused deselection clears it.
    public func captureSelection() async -> DOCXAnchor? {
        guard ready, let book, let document, let webView else { return nil }
        let token = readerSessionID
        do {
            let value = try await webView.evaluateJavaScript("window.pdfnoDOCX.captureSelection()")
            guard token == readerSessionID, ready else { return nil }
            guard let payload = value as? [String: Any], let start = payload["start"] as? Int,
                  let end = payload["end"] as? Int, let quote = payload["quote"] as? String,
                  let anchor = document.anchor(book: book, start: start, end: end),
                  anchor.quote.utf16.elementsEqual(quote.utf16) else { selection = nil; return nil }
            selection = anchor; return anchor
        } catch { if token == readerSessionID { selection = nil }; return nil }
    }
    public func navigate(to anchor: DOCXAnchor) async -> Bool {
        guard ready, let book, book.accepts(anchor), document?.resolves(anchor) == true,
              let bytes = try? JSONEncoder().encode(anchor), let json = String(data: bytes, encoding: .utf8), let webView else { return false }
        let token = readerSessionID
        do {
            let result = try await webView.evaluateJavaScript("window.pdfnoDOCX.navigate(\(json))")
            guard token == readerSessionID, (result as? Bool) == true else { return false }; progress = anchor; return true
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
        let permitted = webView === self.webView && !initialLoad && action.targetFrame?.isMainFrame == true && action.request.url?.absoluteString == "about:blank"
        if permitted { initialLoad = true }; decisionHandler(permitted ? .allow : .cancel)
    }
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { if webView === self.webView { fail(DOCXError.bridge.localizedDescription) } }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { if webView === self.webView { fail(DOCXError.bridge.localizedDescription) } }
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { if webView === self.webView { fail(DOCXError.bridge.localizedDescription) } }
}
public struct DOCXCanvas: NSViewRepresentable {
    @ObservedObject public var session: DOCXReaderSession
    public init(session: DOCXReaderSession) { self.session = session }
    public func makeNSView(context: Context) -> NSView { NSView() }
    public func updateNSView(_ view: NSView, context: Context) {
        guard let web = session.webView else { view.subviews.forEach { $0.removeFromSuperview() }; return }
        if web.superview !== view {
            view.subviews.forEach { $0.removeFromSuperview() }; view.addSubview(web); web.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([web.leadingAnchor.constraint(equalTo: view.leadingAnchor), web.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                                         web.topAnchor.constraint(equalTo: view.topAnchor), web.bottomAnchor.constraint(equalTo: view.bottomAnchor)])
        }
    }
}
#endif
