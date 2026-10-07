// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import Testing
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI

private actor ProfessionalNoNetwork: AIHTTPTransport {
    private(set) var attempts = 0
    func send(_ request: URLRequest) throws -> AIHTTPResponse { attempts += 1; throw AIFailure.network }
}

@Suite(.serialized) @MainActor
struct ProfessionalReaderLayoutTests {
    @Test func professionalDensityKeepsReadableCanvasAndBoundedOverlayAtAllWidths() {
        for width in stride(from: CGFloat(0), through: 1600, by: 4) {
            for preferred in [PDFnoReaderPanel.navigation, .notes] {
                let layout = PDFnoReaderPlacement(width: width, navigation: true, notes: true, preferred: preferred, profile: .professional)
                #expect(layout.navigationWidth <= width && layout.notesWidth <= width)
                #expect(layout.overlay || layout.canvasWidth >= 420)
                #expect(!(layout.showNavigation && layout.showNotes) || width >= 930)
                #expect(layout.canvasWidth <= width && layout.canvasWidth >= 0)
            }
        }
        let desktop = PDFnoReaderPlacement(width: 940, navigation: true, notes: true, preferred: .notes, profile: .professional)
        #expect(desktop.showNavigation && desktop.showNotes && desktop.canvasWidth == 430)
    }
    @Test func explicitPanelOpeningRestoresHiddenPanelWithoutDiscardingOtherRequest() {
        var panels = PDFnoReaderPanels()
        panels.show(.navigation); panels.show(.notes)
        #expect(panels.navigation && panels.notes)
        #expect(panels.placement(width: 662).showNotes && !panels.placement(width: 662).showNavigation)
        panels.show(.navigation)
        #expect(panels.placement(width: 662).showNavigation && !panels.placement(width: 662).showNotes)
        #expect(panels.navigation && panels.notes)
        #expect(panels.placement(width: 1222).showNavigation && panels.placement(width: 1222).showNotes)
        panels.navigation = false; panels.notes = false
        #expect(panels.placement(width: 662).canvasWidth == 662)
    }

    @Test func realPDFInsideProfessionalChromeRetainsNativeIdentitySelectionAndDrafts() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let data = try originalSample()
        let session = PDFReaderSession()
        try session.open(data: data, book: BookRecord(title: "Original A layout", fileSHA256: LibraryRepository.digest(data), originalFilename: "original.pdf", pageCount: 2))
        let state = ProfessionalFixtureState()
        let host = NSHostingView(rootView: ProfessionalPDFHost(session: session, state: state))
        let window = hiddenWindow(host)
        defer { window.close() }
        await settle(host)
        session.search("window"); session.show(try #require(session.searchMatches.first)); session.captureSelection()
        let native = try #require(session.view), document = try #require(session.document), anchor = try #require(session.capturedSelection)
        let identity = session.readerSessionID
        state.draft = "Original draft 日本語 cafe\u{301} 👩🏽‍🚀"
        for width in [CGFloat(1280), 720, 1280] {
            for scheme in [ColorScheme.light, .dark] {
                state.width = width; state.scheme = scheme
                state.panels.show(.navigation); state.panels.show(.notes)
                host.frame.size.width = width; window.setContentSize(NSSize(width: width, height: 520))
                await settle(host)
                #expect(!window.isVisible && !window.isKeyWindow)
                #expect(session.view === native && session.document === document && session.readerSessionID == identity)
                #expect(session.capturedSelection == anchor && session.resolution(of: anchor) == .exact)
                #expect(state.draft.utf8.elementsEqual("Original draft 日本語 cafe\u{301} 👩🏽‍🚀".utf8))
                #expect(state.search == "window" && native.frame.width >= 0 && native.frame.width <= width - 58)
            }
        }
        #expect(data == (try originalSample()))
    }

    @Test func actualProductReaderFitsRegularAndNarrowHiddenHosts() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Professional-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: ProfessionalNoNetwork())
        let data = try originalSample()
        try library.reader.open(data: data, book: BookRecord(title: String(repeating: "Original long title 日本語 · ", count: 5), fileSHA256: LibraryRepository.digest(data), originalFilename: "original.pdf", pageCount: 2))
        let state = ProfessionalFixtureState()
        let host = NSHostingView(rootView: ProfessionalActualWorkspace(library: library, state: state))
        let window = hiddenWindow(host)
        defer { window.close() }
        await settle(host)
        let native = try #require(library.reader.view)
        for width in [CGFloat(1280), 720] {
            for scheme in [ColorScheme.light, .dark] {
                state.width = width; state.scheme = scheme
                host.frame.size.width = width; window.setContentSize(NSSize(width: width, height: 520)); await settle(host)
                #expect(host.fittingSize.width <= width && !window.isVisible && !window.isKeyWindow)
                #expect(library.reader.view === native && library.reader.book?.pageCount == 2)
            }
        }
        print("Professional hidden-host AX children: \(host.accessibilityChildren()?.count ?? 0); system AX / pointer acceptance is separate")
    }

    @Test func embeddedLearningLayoutKeepsExactResultAndUserBodyWithoutSendOrSave() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Professional-Learning-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let transport = ProfessionalNoNetwork()
        let library = LibraryModel(root: root, aiSession: AppAISession(), learningTransport: transport)
        let quote = "Original immutable source 日本語 cafe\u{301} 👩🏽‍🚀"
        let anchor = PDFSourceAnchor(editionID: UUID(), fileSHA256: String(repeating: "a", count: 64), quote: quote, regions: [PageRegion(pageIndex: 0, x: 1, y: 2, width: 160, height: 20, quote: quote)])
        let source = AISourceSnapshot(bookID: UUID(), readerSessionID: UUID(), documentVersion: 0, anchor: .pdf(anchor))
        library.learning.prepare(source)
        let result = AIResult(request: AIRequest(source: source, provider: library.learning.config, kind: .translate), text: String(repeating: quote, count: 30), fromCache: false)
        library.learning.result = result; library.learning.userText = quote
        let state = ProfessionalFixtureState(); state.width = 300
        let host = NSHostingView(rootView: ProfessionalLearningHost(library: library, state: state))
        let window = hiddenWindow(host)
        defer { window.close() }
        for scheme in [ColorScheme.light, .dark] {
            state.scheme = scheme; await settle(host)
            #expect(host.fittingSize.width <= 300 && !window.isVisible && !window.isKeyWindow)
            #expect(library.learning.result == result && library.learning.source == source)
            #expect(library.learning.userText.utf8.elementsEqual(quote.utf8))
        }
        #expect(await transport.attempts == 0)
        #expect(library.learning.notes.isEmpty && !library.learning.busy && !library.learning.hasSessionCredential)
    }
    private func hiddenWindow<V: View>(_ host: NSHostingView<V>) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1280, height: 520), styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        return window
    }
    private func settle<V: View>(_ host: NSHostingView<V>) async {
        host.layoutSubtreeIfNeeded(); try? await Task.sleep(for: .milliseconds(100)); host.layoutSubtreeIfNeeded()
    }
}

@MainActor private final class ProfessionalFixtureState: ObservableObject {
    @Published var panels = PDFnoReaderPanels()
    @Published var width: CGFloat = 1280
    @Published var scheme = ColorScheme.light
    @Published var search = "window"
    @Published var draft = ""
}
private struct ProfessionalPDFHost: View {
    @ObservedObject var session: PDFReaderSession
    @ObservedObject var state: ProfessionalFixtureState
    var body: some View {
        PDFnoProfessionalReaderChrome(title: "Original A layout", format: "PDF") { Text("1 / 2") } actions: {
            PDFnoReaderRailButton(title: "目录", symbol: "list.bullet", identifier: "original-professional-nav") {}
        } content: {
            PDFnoReaderShell(panels: state.panels, profile: .professional) { PDFCanvas(session: session) } navigation: {
                TextField("Original query", text: $state.search)
            } notes: { TextField("Original draft", text: $state.draft) }
        }.frame(width: state.width, height: 520).preferredColorScheme(state.scheme)
    }
}
private struct ProfessionalActualWorkspace: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var state: ProfessionalFixtureState
    var body: some View { ReaderWorkspace(model: library, session: library.reader).frame(width: state.width, height: 520).preferredColorScheme(state.scheme) }
}
private struct ProfessionalLearningHost: View {
    @ObservedObject var library: LibraryModel
    @ObservedObject var state: ProfessionalFixtureState
    var body: some View { AILearningWorkspace(library: library, learning: library.learning, embedded: true, close: {}).frame(width: 300, height: 420).preferredColorScheme(state.scheme) }
}
#endif
