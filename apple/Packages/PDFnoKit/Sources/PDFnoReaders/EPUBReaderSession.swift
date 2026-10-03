// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import SwiftUI
import WebKit
import PDFnoDomain

public struct EPUBOutlineItem: Identifiable {
    public var id: Int { index }
    public let title: String
    public let index: Int
}
private final class EPUBAssets: NSObject, WKURLSchemeHandler {
    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url, url.host == "app", ["/index.html", "/engine.js"].contains(url.path),
              let root = Bundle.module.url(forResource: "EPUB", withExtension: nil),
              let data = try? Data(contentsOf: root.appendingPathComponent(String(url.path.dropFirst()))) else {
            task.didFailWithError(EPUBError.bridge); return
        }
        let response = URLResponse(url: url, mimeType: url.path.hasSuffix(".js") ? "application/javascript" : "text/html",
                                   expectedContentLength: data.count, textEncodingName: "utf-8")
        task.didReceive(response); task.didReceive(data); task.didFinish()
    }
    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}
@MainActor
private final class EPUBMessages: NSObject, WKScriptMessageHandler {
    weak var session: EPUBReaderSession?
    init(_ session: EPUBReaderSession) { self.session = session }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        session?.received(message)
    }
}
@MainActor
public final class EPUBReaderSession: NSObject, ObservableObject, WKNavigationDelegate {
    @Published public private(set) var book: EPUBBook?
    @Published public private(set) var webView: WKWebView?
    @Published public private(set) var selection: EPUBAnchor?
    @Published public private(set) var progress: EPUBAnchor?
    @Published public private(set) var outline: [EPUBOutlineItem] = []
    @Published public private(set) var position = ""
    @Published public private(set) var vertical = false
    @Published public private(set) var busy = false
    @Published public private(set) var error: String?
    private var generation = UUID()
    private var documentVersion = 0
    private var pendingOpen: [String: Any]?
    private var pending: [UUID: CheckedContinuation<String, Error>] = [:]
    public func close() {
        generation = UUID(); pendingOpen = nil
        let requests = pending; pending.removeAll()
        for continuation in requests.values { continuation.resume(throwing: EPUBError.cancelled) }
        webView?.stopLoading(); webView?.configuration.userContentController.removeScriptMessageHandler(forName: "epub")
        webView?.navigationDelegate = nil; webView = nil; book = nil
        selection = nil; progress = nil; outline = []; position = ""; busy = false; documentVersion = 0
    }
    public func open(data: Data, book: EPUBBook, notes: [EPUBNote]) async throws {
        let names = try EPUBArchive.validate(data)
        close(); self.book = book; error = nil; busy = true; let token = generation
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.setURLSchemeHandler(EPUBAssets(), forURLScheme: "pdfno-reader")
        configuration.userContentController.add(EPUBMessages(self), name: "epub")
        let ruleObjects = ["http", "https", "ftp", "file", "data", "ws", "wss"].map {
            ["trigger": ["url-filter": "^" + $0 + ":"], "action": ["type": "block"]]
        }
        let rules = String(decoding: try JSONSerialization.data(withJSONObject: ruleObjects), as: UTF8.self)
        let list: WKContentRuleList = try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "PDFnoEPUBNoNetwork-v1", encodedContentRuleList: rules) { list, error in
                if let list { continuation.resume(returning: list) }
                else { continuation.resume(throwing: error ?? EPUBError.bridge) }
            }
        }
        guard token == generation else { throw EPUBError.cancelled }
        configuration.userContentController.add(list)
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = self; view.setAccessibilityIdentifier("epub-content")
        webView = view
        pendingOpen = ["data": data.base64EncodedString(), "names": names,
                       "notes": try json(notes.filter { $0.bookID == book.id }), "progress": try book.progress.map(json) ?? NSNull()]
        view.load(URLRequest(url: URL(string: "pdfno-reader://app/index.html")!))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(20))
            guard let self, self.generation == token, self.busy, self.pendingOpen != nil else { return }
            self.fail(EPUBError.bridge)
        }
    }
    private func json<T: Encodable>(_ value: T) throws -> Any { try JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) }
    private func identity() throws -> [String: Any] {
        guard let book else { throw EPUBError.cancelled }
        return ["v": 1, "session": generation.uuidString, "bookID": book.id.uuidString,
                "editionID": book.editionID.uuidString, "fileSHA256": book.fileSHA256, "documentVersion": documentVersion]
    }
    private func matches(_ object: [String: Any]) -> Bool {
        guard let book else { return false }
        return object["v"] as? Int == 1 && object["session"] as? String == generation.uuidString &&
        object["bookID"] as? String == book.id.uuidString && object["editionID"] as? String == book.editionID.uuidString &&
        object["fileSHA256"] as? String == book.fileSHA256
    }
    private func request(_ command: String, payload: [String: Any] = [:]) async throws {
        guard let view = webView else { throw EPUBError.cancelled }
        let token = generation, id = UUID(); var message = try identity()
        message["requestID"] = id.uuidString; message["command"] = command; message["payload"] = payload
        let data = try JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])
        guard data.count <= 32 * 1024 * 1024 else { throw EPUBError.resourceLimit }
        let result: String = try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            view.callAsyncJavaScript("return await window.PDFno.command(message)", arguments: ["message": message], in: nil, in: .page) { [weak self] result in
                guard let self, let current = self.pending.removeValue(forKey: id) else { return }
                switch result {
                case .failure(let error): current.resume(throwing: error)
                case .success(let value):
                    if let text = value as? String { current.resume(returning: text) }
                    else { current.resume(throwing: EPUBError.bridge) }
                }
            }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(15))
                guard let self, self.generation == token, self.pending[id] != nil else { return }
                self.fail(EPUBError.bridge)
            }
        }
        guard generation == token else { throw EPUBError.cancelled }
        let object = try decode(result)
        guard matches(object), object["requestID"] as? String == id.uuidString,
              let version = object["documentVersion"] as? Int, version >= documentVersion,
              let state = object["payload"] as? [String: Any], state["kind"] as? String == "state" else { throw EPUBError.bridge }
        documentVersion = version; selection = nil
        if let anchor = state["progress"] as? [String: Any] { progress = try anchorValue(anchor) }
        vertical = state["vertical"] as? Bool ?? false
        let chapter = state["spineIndex"] as? Int ?? 0, page = state["page"] as? String ?? "1"
        position = "第 \(chapter + 1) 章 · 第 \(page) 页" + (vertical ? " · 竖排" : "")
        outline = (state["outline"] as? [[String: Any]] ?? []).prefix(1000).compactMap {
            guard let title = $0["title"] as? String, title.utf8.count < 4096, let index = $0["index"] as? Int, (0..<1000).contains(index) else { return nil }
            return EPUBOutlineItem(title: title, index: index)
        }
    }
    private func decode(_ text: String) throws -> [String: Any] {
        guard text.utf8.count <= 1024 * 1024, let data = text.data(using: .utf8),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw EPUBError.bridge }
        return object
    }
    private func anchorValue(_ value: [String: Any]) throws -> EPUBAnchor {
        let anchor = try JSONDecoder().decode(EPUBAnchor.self, from: JSONSerialization.data(withJSONObject: value))
        guard book?.accepts(anchor) == true else { throw EPUBError.sourceMismatch }; return anchor
    }
    fileprivate func received(_ message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame, message.frameInfo.request.url?.scheme == "pdfno-reader",
              message.frameInfo.request.url?.host == "app", let text = message.body as? String,
              let object = try? decode(text), let payload = object["payload"] as? [String: Any] else { return }
        if payload["kind"] as? String == "ready", let initial = pendingOpen {
            pendingOpen = nil
            let token = generation
            Task {
                do { try await request("open", payload: initial); if generation == token { busy = false } }
                catch { if generation == token { fail(error) } }
            }
        } else if !busy, matches(object), object["documentVersion"] as? Int == documentVersion,
                  payload["kind"] as? String == "selection", let value = payload["anchor"] as? [String: Any] {
            selection = try? anchorValue(value)
        }
    }
    public func command(_ name: String, index: Int? = nil, anchor: EPUBAnchor? = nil, notes: [EPUBNote]? = nil) async -> Bool {
        guard !busy else { return false }; let token = generation
        busy = true; defer { if generation == token { busy = false } }
        do {
            var payload: [String: Any] = [:]
            if let index { payload["index"] = index }
            if let anchor { guard book?.accepts(anchor) == true else { throw EPUBError.sourceMismatch }; payload["anchor"] = try json(anchor) }
            if let notes { payload["notes"] = try json(notes) }
            try await request(name, payload: payload); return true
        } catch {
            if generation == token { self.error = (error as? EPUBError)?.localizedDescription ?? EPUBError.bridge.localizedDescription }
            return false
        }
    }
    private func fail(_ error: Error) {
        close(); self.error = (error as? EPUBError)?.localizedDescription ?? EPUBError.bridge.localizedDescription
    }
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { fail(EPUBError.bridge) }
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        let url = action.request.url
        return url?.scheme == "pdfno-reader" && url?.host == "app" && url?.path == "/index.html" || url?.absoluteString == "about:blank" ? .allow : .cancel
    }
}
public struct EPUBCanvas: NSViewRepresentable {
    @ObservedObject public var session: EPUBReaderSession
    public init(session: EPUBReaderSession) { self.session = session }
    public func makeNSView(context: Context) -> NSView { EPUBContainer(session: session) }
    public func updateNSView(_ host: NSView, context: Context) {
        guard let web = session.webView else { host.subviews.forEach { $0.removeFromSuperview() }; return }
        if web.superview !== host {
            host.subviews.forEach { $0.removeFromSuperview() }; web.frame = host.bounds
            web.autoresizingMask = [.width, .height]; host.addSubview(web)
        }
    }
}
@MainActor private final class EPUBContainer: NSView {
    weak var session: EPUBReaderSession?
    private var resize: Task<Void, Never>?
    init(session: EPUBReaderSession) { self.session = session; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("Programmatic host only") }
    override func setFrameSize(_ newSize: NSSize) {
        let changed = newSize != frame.size
        super.setFrameSize(newSize)
        guard changed, newSize.width > 100, newSize.height > 100 else { return }
        resize?.cancel()
        resize = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            if let session = self?.session, session.progress != nil { _ = await session.command("resize") }
        }
    }
}
#endif
