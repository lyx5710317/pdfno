// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import SwiftUI
import PDFnoDomain
import PDFnoReaders
import PDFnoServices
@testable import PDFnoUI
#if os(macOS)
import AppKit
#endif

@MainActor
struct UIFoundationTests {
    @Test func wideReaderKeepsBothPanelsAndReadableCanvas() {
        var panels = PDFnoReaderPanels()
        panels.toggle(.navigation, width: 1100)
        panels.toggle(.notes, width: 1100)
        let layout = panels.placement(width: 1100)
        #expect(layout.showNavigation && layout.showNotes && !layout.overlay)
        #expect(layout.canvasWidth >= 420)
        #expect(layout.leading + layout.canvasWidth + layout.trailing == 1100)
    }
    @Test func narrowReaderShowsLastPanelAndCanReturnToHiddenPanel() {
        var panels = PDFnoReaderPanels()
        panels.toggle(.navigation, width: 880)
        panels.toggle(.notes, width: 880)
        #expect(!panels.placement(width: 880).showNavigation && panels.placement(width: 880).showNotes)
        #expect(panels.navigation && panels.notes)
        panels.toggle(.navigation, width: 880)
        #expect(panels.placement(width: 880).showNavigation && !panels.placement(width: 880).showNotes)
        panels.toggle(.navigation, width: 880)
        #expect(!panels.navigation && panels.placement(width: 880).showNotes)
        #expect(panels.placement(width: 440).overlay && panels.placement(width: 440).canvasWidth == 440)
    }
    @Test func allWidthsBoundPanelsAndOnlyDockWhenReadingAreaFits() {
        for width in stride(from: CGFloat(0), through: 1600, by: 1) {
            for preferred in [PDFnoReaderPanel.navigation, .notes] {
                let layout = PDFnoReaderPlacement(width: width, navigation: true, notes: true, preferred: preferred)
                #expect(layout.navigationWidth <= width && layout.notesWidth <= width)
                #expect(layout.canvasWidth >= 0 && layout.canvasWidth <= width)
                #expect(layout.overlay || layout.canvasWidth >= 420)
                #expect(!(layout.showNavigation && layout.showNotes) || width >= 980)
                #expect(layout.notesOffset >= 0 && layout.notesOffset + layout.notesWidth <= width)
            }
        }
    }
    @Test func closingPanelsRestoresCanvasAndInvalidProposalIsBounded() {
        var panels = PDFnoReaderPanels()
        panels.toggle(.notes, width: 440)
        panels.toggle(.notes, width: 440)
        #expect(!panels.notes && panels.placement(width: 440).canvasWidth == 440)
        for width in [CGFloat.nan, .infinity, -10] {
            let layout = PDFnoReaderPlacement(width: width, navigation: true, notes: true, preferred: .notes)
            #expect(layout.width == 0 && layout.canvasWidth == 0 && layout.notesWidth == 0)
        }
    }
    #if os(macOS)
    @Test func originalComponentsFitNarrowLightAndDarkSurfaces() async throws {
        _ = NSApplication.shared
        for scheme in [ColorScheme.light, .dark] {
            let host = NSHostingView(rootView:
                PDFnoPanel(title: "高亮与笔记", icon: "highlighter", closeIdentifier: "original-component-close", close: {}) {
                    VStack(alignment: .leading, spacing: PDFnoDesign.Space.regular) {
                        PDFnoLibraryLayoutPicker(grid: .constant(true))
                        Text("原创长书名 · Reading 日本語 か\u{3099} 👩🏽‍🚀").font(PDFnoDesign.TypeStyle.title)
                        Text(String(repeating: "原文与来源保留，窄面板中的说明自动换行。", count: 6))
                            .font(PDFnoDesign.TypeStyle.body).fixedSize(horizontal: false, vertical: true)
                        Button("保存高亮与笔记") {}.buttonStyle(PDFnoActionStyle(role: .primary))
                        Button("暂不可用") {}.buttonStyle(PDFnoActionStyle()).disabled(true)
                        Button("回到原文") {}.buttonStyle(PDFnoActionStyle(role: .quiet))
                        Spacer(minLength: 0)
                    }.padding(PDFnoDesign.Space.regular)
                }.frame(width: 320, height: 620).preferredColorScheme(scheme))
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 320, height: 620), styleMask: [], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = host
            defer { window.close() }
            host.frame = NSRect(x: 0, y: 0, width: 320, height: 620)
            host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(50))
            #expect(host.fittingSize.width <= 320)
            if let output = ProcessInfo.processInfo.environment["PDFNO_UI_FOUNDATION_PREVIEW"], !output.isEmpty {
                let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let suffix = scheme == .light ? "light" : "dark"
                try #require(bitmap.representation(using: .png, properties: [:]))
                    .write(to: URL(fileURLWithPath: output + "-" + suffix + ".png"))
            }
        }
    }
    @Test func shellResizeAndPanelSwitchKeepNativePDFViewSelectionSourceAndDraft() async throws {
        _ = NSApplication.shared
        let data = try originalSample()
        let book = BookRecord(title: "Original shell fixture", fileSHA256: LibraryRepository.digest(data), originalFilename: "original.pdf", pageCount: 2)
        let session = PDFReaderSession(); try session.open(data: data, book: book)
        let state = OriginalShellState()
        let host = NSHostingView(rootView: OriginalShellFixture(session: session, state: state))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 620), styleMask: [], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false; window.contentView = host
        defer { window.close() }
        host.frame = NSRect(x: 0, y: 0, width: 1100, height: 620)
        host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(50))
        let native = try #require(session.view), document = try #require(session.document)
        session.search("window"); session.show(try #require(session.searchMatches.first)); session.captureSelection()
        let anchor = try #require(session.capturedSelection), identity = session.readerSessionID
        state.draft = "Original unsaved 日本語 cafe\u{301} 👩🏽‍🚀"
        for width in [CGFloat(1100), 880, 440, 1100] {
            state.panels.toggle(.navigation, width: width)
            state.panels.toggle(.notes, width: width)
            host.frame.size.width = width
            host.layoutSubtreeIfNeeded(); try await Task.sleep(for: .milliseconds(50))
            let layout = state.panels.placement(width: width)
            #expect(session.view === native && session.document === document && session.readerSessionID == identity)
            #expect(abs(native.frame.width - layout.canvasWidth) < 1)
            #expect(session.capturedSelection == anchor && session.resolution(of: anchor) == .exact)
            #expect(state.draft == "Original unsaved 日本語 cafe\u{301} 👩🏽‍🚀" && state.search == "window")
        }
        #expect(data == (try originalSample()))
    }
    #endif
}
#if os(macOS)
@MainActor private final class OriginalShellState: ObservableObject {
    @Published var panels = PDFnoReaderPanels()
    @Published var draft = ""
    @Published var search = "window"
}
private struct OriginalShellFixture: View {
    @ObservedObject var session: PDFReaderSession
    @ObservedObject var state: OriginalShellState
    var body: some View {
        PDFnoReaderShell(panels: state.panels) {
            PDFCanvas(session: session)
        } navigation: {
            PDFnoPanel(title: "导航与搜索", icon: "list.bullet", closeIdentifier: "original-nav-close", close: { state.panels.navigation = false }) {
                TextField("原创查询", text: $state.search).padding()
            }
        } notes: {
            PDFnoPanel(title: "高亮与笔记", icon: "highlighter", closeIdentifier: "original-notes-close", close: { state.panels.notes = false }) {
                VStack {
                    Text(session.capturedSelection?.quote ?? "")
                    TextField("原创草稿", text: $state.draft, axis: .vertical)
                }.padding()
            }
        }
    }
}
#endif
