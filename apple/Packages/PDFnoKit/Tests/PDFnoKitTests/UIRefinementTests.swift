// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import Foundation
import SwiftUI
import Testing
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

private actor RefinementNoNetwork: AIHTTPTransport {
    private(set) var count = 0
    func send(_ request: URLRequest) throws -> AIHTTPResponse {
        count += 1
        throw AIFailure.network
    }
}

@MainActor private final class RefinementLayout: ObservableObject {
    @Published var panels = PDFnoReaderPanels()
    @Published var scheme = ColorScheme.light
    @Published var width: CGFloat = 760
}

/// Native hosts are never ordered on screen. All data and stores are original/temporary.
@Suite(.serialized) @MainActor
struct UIRefinementTests {
    private let unicode = "Original reading · 原文 日本語 か\u{3099} cafe\u{301} 👩🏽‍🚀\n"

    @Test func longStatesActionsAndTextRenderInNarrowLightAndDarkHosts() async throws {
        for scheme in [ColorScheme.light, .dark] {
            let content = VStack(alignment: .leading, spacing: PDFnoDesign.Space.regular) {
                PDFnoEmptyState(title: "尚未选择原文", detail: "选择原文后保存；来源与草稿分别保留。")
                PDFnoStatusMessage(text: "正在处理固定原文，可以取消。", kind: .busy)
                PDFnoStatusMessage(text: "请求已取消 · 已有结果可审阅")
                PDFnoStatusMessage(text: "保存失败 · 原创草稿保留，可手动重试。", kind: .error)
                PDFnoStatusMessage(text: "学习笔记已保存到本地", kind: .success)
                PDFnoTextViewport(text: String(repeating: unicode, count: 20), identifier: "original-refinement-quote")
                PDFnoAdaptiveActions {
                    Button("保存此段到学习笔记") {}.buttonStyle(PDFnoActionStyle(role: .primary))
                    Button("引用 · 回到此段原文") {}.buttonStyle(PDFnoActionStyle())
                }
            }.padding(PDFnoDesign.Space.section).background(PDFnoDesign.Palette.chrome)
                .frame(width: 320).preferredColorScheme(scheme)
            let host = NSHostingView(rootView: content)
            let window = hiddenWindow(host, width: 320, height: 920)
            defer { window.close() }
            host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(80))
            #expect(!window.isVisible && host.fittingSize.width <= 320)
            #expect(host.fittingSize.height.isFinite && host.fittingSize.height > 500 && host.fittingSize.height < 920)
            if let directory = ProcessInfo.processInfo.environment["PDFNO_UI_REFINEMENT_PREVIEW"] {
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let png = try #require(bitmap.representation(using: .png, properties: [:]))
                try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent(scheme == .light ? "components-light.png" : "components-dark.png"))
            }
        }
    }

    @Test func nativePDFResizeThemeAndPanelChangesRetainSourceResultAndDraft() async throws {
        let root = temporaryRoot(), transport = RefinementNoNetwork()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: transport)
        let data = try originalSample()
        let book = BookRecord(title: "Original refinement PDF", fileSHA256: LibraryRepository.digest(data), originalFilename: "original.pdf", pageCount: 2)
        try library.reader.open(data: data, book: book)
        let layout = RefinementLayout()
        layout.width = 1100
        let host = NSHostingView(rootView: RefinementPDFHost(library: library, layout: layout))
        let window = hiddenWindow(host, width: 1100, height: 680)
        defer { window.close() }
        host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(80))
        library.reader.search("window")
        library.reader.show(try #require(library.reader.searchMatches.first)); library.reader.captureSelection()
        let anchor = try #require(library.reader.capturedSelection)
        let source = try #require(library.captureAISource())
        library.learning.prepare(source)
        let result = AIResult(request: AIRequest(source: source, provider: library.learning.config, kind: .translate), text: String(repeating: unicode, count: 12), fromCache: false)
        library.learning.result = result; library.learning.userText = unicode + "Original unsaved draft"
        let native = try #require(library.reader.view), document = try #require(library.reader.document)
        let identity = library.reader.readerSessionID
        for width in [CGFloat(1100), 880, 440, 1100] {
            for scheme in [ColorScheme.light, .dark] {
                layout.scheme = scheme; layout.width = width
                layout.panels.toggle(.navigation, width: width); layout.panels.toggle(.notes, width: width)
                window.setContentSize(NSSize(width: width, height: 680)); host.frame.size.width = width
                host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(80))
                #expect(!window.isVisible)
                #expect(library.reader.view === native && library.reader.document === document && library.reader.readerSessionID == identity)
                #expect(library.reader.capturedSelection == anchor && library.reader.resolution(of: anchor) == .exact)
                #expect(library.learning.source == source && library.learning.result == result)
                #expect(library.learning.userText == unicode + "Original unsaved draft")
                #expect(abs(native.frame.width - layout.panels.placement(width: width).canvasWidth) < 1)
            }
        }
        #expect(await transport.count == 0)
        #expect(library.notes.isEmpty && library.learning.notes.isEmpty && !library.learning.hasSessionCredential)
        #expect(data == (try originalSample()))
    }

    @Test func actualLearningSheetRetainsExactLongContentWithoutSendingOrSaving() async throws {
        let root = temporaryRoot(), transport = RefinementNoNetwork()
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: transport)
        let quote = String(repeating: unicode, count: 5)
        let anchor = PDFSourceAnchor(editionID: UUID(), fileSHA256: String(repeating: "a", count: 64), quote: quote,
            regions: [PageRegion(pageIndex: 0, x: 1, y: 2, width: 100, height: 20, quote: quote)])
        let source = AISourceSnapshot(bookID: UUID(), readerSessionID: UUID(), documentVersion: 0, anchor: .pdf(anchor))
        library.learning.prepare(source)
        library.learning.config.mode = .mock
        let result = AIResult(request: AIRequest(source: source, provider: library.learning.config, kind: .translate), text: String(repeating: unicode, count: 30), fromCache: false)
        let layout = RefinementLayout()
        let host = NSHostingView(rootView: RefinementLearningHost(library: library, layout: layout))
        let window = hiddenWindow(host, width: 760, height: 840)
        defer { window.close() }
        host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(80))
        library.learning.result = result; library.learning.userText = unicode
        library.learning.error = "Original cancelled request · 未保存草稿保留"
        for width in [CGFloat(360), 760] {
            for scheme in [ColorScheme.light, .dark] {
                layout.width = width; layout.scheme = scheme
                window.setContentSize(NSSize(width: width, height: 840)); host.frame.size.width = width
                host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(80))
                #expect(!window.isVisible && host.fittingSize.width <= width)
                #expect(library.learning.source == source && library.learning.result == result)
                #expect(library.learning.userText.utf8.elementsEqual(unicode.utf8))
                #expect(library.learning.error == "Original cancelled request · 未保存草稿保留")
            }
        }
        #expect(library.learning.notes.isEmpty && !library.learning.busy)
        #expect(await transport.count == 0)
    }

    private func temporaryRoot() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-UIRefinement-" + UUID().uuidString)
    }
    private func hiddenWindow<V: View>(_ host: NSHostingView<V>, width: CGFloat, height: CGFloat) -> NSWindow {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        return window
    }
}

private struct RefinementPDFHost: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var layout: RefinementLayout
    var body: some View {
        PDFnoReaderShell(panels: layout.panels) { PDFCanvas(session: library.reader) } navigation: {
            PDFnoPanel(title: "导航与搜索", icon: "list.bullet", closeIdentifier: "original-refinement-nav", close: {}) { Text("原创搜索") }
        } notes: {
            PDFnoPanel(title: "高亮与笔记", icon: "note.text", closeIdentifier: "original-refinement-notes", close: {}) {
                VStack {
                    PDFnoTextViewport(text: library.learning.source?.anchor.quote ?? "")
                    PDFnoTextViewport(text: library.learning.result?.text ?? "")
                    TextField("原创草稿", text: Binding(get: { library.learning.userText }, set: { library.learning.userText = $0 }), axis: .vertical)
                }.padding(PDFnoDesign.Space.regular)
            }
        }.frame(width: layout.width, height: 680).preferredColorScheme(layout.scheme)
    }
}

private struct RefinementLearningHost: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var layout: RefinementLayout
    var body: some View {
        AILearningWorkspace(library: library, learning: library.learning)
            .frame(width: layout.width, height: 840).preferredColorScheme(layout.scheme)
    }
}
#endif
