// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Foundation
import SwiftUI
import WebKit
import PDFnoDomain
import PDFnoServices

private final class ComicAssets: NSObject, WKURLSchemeHandler {
    func webView(_ view: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url, url.host == "app", ["/index.html", "/engine.js"].contains(url.path),
              let root = Bundle.module.url(forResource: "Comics", withExtension: nil),
              let data = try? Data(contentsOf: root.appendingPathComponent(String(url.path.dropFirst()))) else {
            task.didFailWithError(ComicError.bridge); return
        }
        task.didReceive(URLResponse(url: url, mimeType: url.path.hasSuffix(".js") ? "application/javascript" : "text/html",
                                   expectedContentLength: data.count, textEncodingName: "utf-8"))
        task.didReceive(data); task.didFinish()
    }
    func webView(_ view: WKWebView, stop task: any WKURLSchemeTask) {}
}
@MainActor private final class ComicMessages: NSObject, WKScriptMessageHandler {
    weak var session: ComicReaderSession?
    init(_ session: ComicReaderSession) { self.session = session }
    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) { session?.received(message) }
}
private struct ComicThumbnail: Sendable { let index: Int; let data: String }
@MainActor public final class ComicReaderSession: NSObject, ObservableObject, WKNavigationDelegate {
    @Published public private(set) var book: ComicBook?
    @Published public private(set) var webView: WKWebView?
    @Published public private(set) var pageIndex = 0
    @Published public private(set) var visibleIndices: [Int] = []
    @Published public private(set) var direction: ComicDirection = .leftToRight
    @Published public private(set) var layout: ComicLayout = .automatic
    @Published public private(set) var progress: ComicProgress?
    @Published public private(set) var busy = false
    @Published public private(set) var error: String?
    public var persist: ((UUID, ComicProgress) async throws -> Void)?
    private var archive: ComicArchive?
    private var generation = UUID()
    private var waitingForReady = false
    private var pending: [UUID: CheckedContinuation<String, Error>] = [:]
    private var width = 1000.0, height = 700.0
    private var requestTask: Task<Void, Never>?
    private var decodeTask: Task<[ComicThumbnail], Error>?
    public var hasPrevious: Bool { (visibleIndices.min() ?? pageIndex) > 0 }
    public var hasNext: Bool { (visibleIndices.max() ?? pageIndex) + 1 < (book?.pages.count ?? 0) }
    public var position: String {
        guard book != nil else { return "没有打开的漫画" }
        let indices = visibleIndices.sorted()
        let text = indices.count == 2 ? "\(indices[0] + 1)–\(indices[1] + 1)" : "\(pageIndex + 1)"
        return "第 \(text) / \(book?.pages.count ?? 0) 页"
    }
    public func close() {
        generation = UUID(); requestTask?.cancel(); requestTask = nil; decodeTask?.cancel(); decodeTask = nil
        let requests = pending; pending.removeAll()
        for continuation in requests.values { continuation.resume(throwing: ComicError.cancelled) }
        webView?.stopLoading(); webView?.configuration.userContentController.removeScriptMessageHandler(forName: "comic")
        webView?.navigationDelegate = nil; webView = nil; archive = nil; book = nil
        progress = nil; visibleIndices = []; busy = false; waitingForReady = false
    }
    public func open(archive: CBZArchive, book: ComicBook) async throws {
        try await open(archive: .cbz(archive), book: book)
    }
    public func open(archive: ComicArchive, book: ComicBook) async throws {
        guard archive.format == book.archiveFormat, archive.pages == book.pages, book.progress.map(book.accepts) ?? true else { throw ComicError.sourceMismatch }
        close(); error = nil; busy = true; self.archive = archive; self.book = book
        pageIndex = book.progress?.pageIndex ?? 0; direction = book.progress?.direction ?? .leftToRight; layout = book.progress?.layout ?? .automatic
        let token = generation
        do {
            let config = WKWebViewConfiguration(); config.websiteDataStore = .nonPersistent()
            config.setURLSchemeHandler(ComicAssets(), forURLScheme: "pdfno-comic")
            config.userContentController.add(ComicMessages(self), name: "comic")
            let rules = ["http", "https", "file", "ftp", "data", "ws", "wss"].map {
                ["trigger": ["url-filter": "^" + $0 + ":"], "action": ["type": "block"]]
            }
            let list: WKContentRuleList = try await withCheckedThrowingContinuation { c in
                WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "PDFnoComicNoNetwork-v1",
                    encodedContentRuleList: String(decoding: try! JSONSerialization.data(withJSONObject: rules), as: UTF8.self)) { list, error in
                    if let list { c.resume(returning: list) } else { c.resume(throwing: error ?? ComicError.bridge) }
                }
            }
            guard generation == token else { throw ComicError.cancelled }
            config.userContentController.add(list)
            let view = WKWebView(frame: .zero, configuration: config); view.navigationDelegate = self
            view.setAccessibilityIdentifier("comic-content"); webView = view; waitingForReady = true
            view.load(URLRequest(url: URL(string: "pdfno-comic://app/index.html")!))
            requestTask = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(20)) } catch { return }
                guard let self, self.generation == token, self.waitingForReady else { return }
                self.fail(ComicError.bridge)
            }
        } catch { if generation == token { fail(error) }; throw error }
    }
    fileprivate func received(_ message: WKScriptMessage) {
        guard waitingForReady, message.frameInfo.isMainFrame, message.frameInfo.request.url?.scheme == "pdfno-comic",
              message.frameInfo.request.url?.host == "app", message.body as? String == "ready" else { return }
        waitingForReady = false; requestTask?.cancel()
        requestTask = Task { [weak self] in guard let self else { return }; await self.render(index: self.pageIndex, direction: self.direction, layout: self.layout) }
    }
    private func render(index: Int, direction: ComicDirection, layout: ComicLayout) async {
        guard let book, let archive, let view = webView, book.pages.indices.contains(index) else { return }
        let token = generation, renderWidth = width, renderHeight = height
        busy = true; error = nil
        let logical = ComicPagination.spread(containing: index, pages: book.pages, layout: layout, width: width, height: height)
        let visual = ComicPagination.visualOrder(logical, direction: direction)
        do {
            // Decode away from the UI, retaining only at most two downsampled pages.
            let job = Task.detached { () throws -> [ComicThumbnail] in
                try visual.map { i in try Task.checkCancellation(); return ComicThumbnail(index: i, data: try archive.pagePNG(at: i).base64EncodedString()) }
            }
            decodeTask = job
            let pages = try await job.value
            guard generation == token, !Task.isCancelled else { throw ComicError.cancelled }
            let requestID = UUID().uuidString
            // Controlled lowercase aliases avoid upstream extension-case assumptions. Identity remains the native full path.
            let message: [String: Any] = ["v": 1, "command": "render", "requestID": requestID, "session": token.uuidString,
                "bookID": book.id.uuidString, "editionID": book.editionID.uuidString, "fileSHA256": book.fileSHA256,
                "names": book.pages.indices.map { "page-\($0).png" }, "pages": pages.map { ["index": $0.index, "data": $0.data] }]
            let result = try await request(view: view, message: message, token: token)
            guard generation == token, result.utf8.count <= 4096,
                  let response = try JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any],
                  response["v"] as? Int == 1, response["requestID"] as? String == requestID,
                  response["session"] as? String == token.uuidString, response["bookID"] as? String == book.id.uuidString,
                  response["editionID"] as? String == book.editionID.uuidString,
                  response["fileSHA256"] as? String == book.fileSHA256, response["indices"] as? [Int] == visual else { throw ComicError.bridge }
            self.pageIndex = index; self.direction = direction; self.layout = layout; visibleIndices = visual
            let progress = ComicProgress(editionID: book.editionID, fileSHA256: book.fileSHA256, pageIndex: index,
                pagePath: book.pages[index].path, direction: direction, layout: layout)
            self.progress = progress
            do { try await persist?(book.id, progress) } catch { if generation == token { self.error = error.localizedDescription } }
        } catch {
            if generation == token { self.error = (error as? ComicError)?.localizedDescription ?? ComicError.bridge.localizedDescription }
        }
        guard generation == token else { return }
        decodeTask = nil; busy = false
        if renderWidth != width || renderHeight != height { await render(index: pageIndex, direction: self.direction, layout: self.layout) }
    }
    private func request(view: WKWebView, message: [String: Any], token: UUID) async throws -> String {
        let id = UUID()
        return try await withCheckedThrowingContinuation { c in
            pending[id] = c
            view.callAsyncJavaScript("return await window.PDFnoComic.command(message)", arguments: ["message": message], in: nil, in: .page) { [weak self] result in
                guard let continuation = self?.pending.removeValue(forKey: id) else { return }
                switch result {
                case .success(let value):
                    if let text = value as? String { continuation.resume(returning: text) }
                    else { continuation.resume(throwing: ComicError.bridge) }
                case .failure(let error): continuation.resume(throwing: error)
                }
            }
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(25))
                guard let self, self.generation == token, self.pending[id] != nil else { return }
                self.fail(ComicError.bridge)
            }
        }
    }
    public func next() async {
        guard !busy, hasNext else { return }; await render(index: (visibleIndices.max() ?? pageIndex) + 1, direction: direction, layout: layout)
    }
    public func previous() async {
        guard !busy, hasPrevious, let book else { return }
        let spread = ComicPagination.spread(containing: (visibleIndices.min() ?? pageIndex) - 1, pages: book.pages, layout: layout, width: width, height: height)
        if let index = spread.first { await render(index: index, direction: direction, layout: layout) }
    }
    public func go(to index: Int) async { guard !busy else { return }; await render(index: index, direction: direction, layout: layout) }
    public func setDirection(_ value: ComicDirection) async { guard !busy else { return }; await render(index: pageIndex, direction: value, layout: layout) }
    public func setLayout(_ value: ComicLayout) async { guard !busy else { return }; await render(index: pageIndex, direction: direction, layout: value) }
    public func resize(width: Double, height: Double) async {
        guard width > 100, height > 100 else { return }; self.width = width; self.height = height
        if !busy { await render(index: pageIndex, direction: direction, layout: layout) }
    }
    private func fail(_ error: Error) { close(); self.error = (error as? ComicError)?.localizedDescription ?? ComicError.bridge.localizedDescription }
    public func webViewWebContentProcessDidTerminate(_ view: WKWebView) { fail(ComicError.bridge) }
    public func webView(_ view: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    public func webView(_ view: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        let url = action.request.url
        return (url?.scheme == "pdfno-comic" && url?.host == "app" && url?.path == "/index.html") || (action.targetFrame?.isMainFrame == false && (url?.scheme == "blob" || url?.absoluteString == "about:blank")) ? .allow : .cancel
    }
}
public struct ComicCanvas: NSViewRepresentable {
    @ObservedObject public var session: ComicReaderSession
    public init(session: ComicReaderSession) { self.session = session }
    public func makeNSView(context: Context) -> NSView { ComicContainer(session: session) }
    public func updateNSView(_ host: NSView, context: Context) {
        guard let web = session.webView else { host.subviews.forEach { $0.removeFromSuperview() }; return }
        if web.superview !== host { host.subviews.forEach { $0.removeFromSuperview() }; web.frame = host.bounds; web.autoresizingMask = [.width, .height]; host.addSubview(web) }
    }
}
@MainActor private final class ComicContainer: NSView {
    weak var session: ComicReaderSession?
    private var resizing: Task<Void, Never>?
    init(session: ComicReaderSession) { self.session = session; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError("Programmatic host only") }
    override func setFrameSize(_ size: NSSize) {
        let changed = size != frame.size; super.setFrameSize(size)
        guard changed, size.width > 100, size.height > 100 else { return }; resizing?.cancel()
        resizing = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
            await self?.session?.resize(width: size.width, height: size.height)
        }
    }
}
#endif
