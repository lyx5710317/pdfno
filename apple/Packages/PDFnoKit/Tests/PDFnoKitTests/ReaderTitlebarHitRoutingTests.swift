// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import Testing
import PDFnoServices
@testable import PDFnoUI

@Suite(.serialized) @MainActor struct ReaderTitlebarHitRoutingTests {
    private final class DragRecordingWindow: NSWindow {
        var dragEvents: [NSEvent] = []
        override func performDrag(with event: NSEvent) { dragEvents.append(event) }
    }
    @Test func actualTabbedReaderKeepsBlankNativeTitlebarGapHittable() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("Original-Tabbed-Titlebar-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = LibraryModel(root: root, learningTransport: OfflineSelectionUITestTransport())
        await library.load(); await library.openSample()
        try #require(library.displayedDocumentID != nil && library.error == nil)
        let navigation = PDFnoWorkspaceNavigation(); navigation.showReader()
        let content = NSHostingView(rootView: MacTabbedWorkspace(model: library, navigation: navigation, settingsRequest: 0))
        let window = DragRecordingWindow(contentRect: NSRect(x: 95,y: 115,width: 1280,height: 800),
            styleMask: [.titled,.closable,.miniaturizable,.resizable,.fullSizeContentView],backing: .buffered,defer: false)
        window.isReleasedWhenClosed = false
        let toolbar = NSToolbar(identifier: "OriginalActualTabbedReaderQA")
        window.toolbar = toolbar; window.toolbarStyle = .unifiedCompact; window.contentView = content
        defer { library.epub.close(); window.close() }
        func descendants(_ view: NSView) -> [NSView] { view.subviews.flatMap { [$0] + descendants($0) } }
        var band: MacDocumentWindowToolbar.DocumentBandHost?
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            window.contentView?.superview?.layoutSubtreeIfNeeded(); content.layoutSubtreeIfNeeded()
            if let frame = window.contentView?.superview {
                band = descendants(frame).compactMap { $0 as? MacDocumentWindowToolbar.DocumentBandHost }.first
            }
            if (band?.controlFrames.count ?? 0) >= 5 { break }
            try await Task.sleep(for: .milliseconds(50))
        }
        let host = try #require(band), top = try #require(window.contentView?.superview)
        let frames = host.controlFrames.sorted { $0.minX < $1.minX }
        let add = try #require(frames.dropLast().last), more = try #require(frames.last)
        let gap = NSPoint(x: (add.maxX + more.minX)/2,y: add.midY)
        let route = top.hitTest(host.convert(gap,to: top.superview))
        print("PDFNO_ACTUAL_TABBED_TITLEBAR bounds=\(host.bounds) frames=\(frames) gap=\(gap) routed=\(route.map { String(reflecting: type(of: $0)) } ?? "nil")")
        #expect(host.bounds.contains(gap) && more.minX-add.maxX > 80)
        #expect(route === host)
        #expect(!window.isVisible && !window.isKeyWindow && window.toolbar === toolbar)
    }
    @Test func emptyAccessoryGapReachesNativeHostWithoutShowingWindow() async throws {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let content = HStack(spacing: 6) {
            Button("Home") {}.frame(width: 34, height: 32).pdfnoTitlebarControl()
            Button("Original document A") {}.frame(width: 180, height: 32).pdfnoTitlebarControl()
            Button("Original document B") {}.frame(width: 180, height: 32).pdfnoTitlebarControl()
            Button("+") {}.frame(width: 28, height: 30).pdfnoTitlebarControl()
            Spacer(minLength: 0)
            Button("More") {}.frame(width: 22, height: 28).pdfnoTitlebarControl()
        }.buttonStyle(.plain).padding(.horizontal, 2).frame(height: 34)
        let window = DragRecordingWindow(contentRect: NSRect(x: 200, y: 200, width: 1280, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1280, height: 800))
        let toolbar = NSToolbar(identifier: "OriginalHiddenTitlebarQA")
        window.toolbar = toolbar; window.toolbarStyle = .unifiedCompact
        let coordinator = MacDocumentWindowToolbar.Coordinator(content: AnyView(content), width: 1280)
        coordinator.attach(window)
        defer { coordinator.detach(); window.close() }
        for _ in 0..<6 {
            window.contentView?.superview?.layoutSubtreeIfNeeded()
            coordinator.host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(50))
        }
        let host = coordinator.host
        #expect(!window.isVisible && !window.isKeyWindow)
        #expect(window.toolbar === toolbar)
        let frames = host.controlFrames.sorted { $0.minX < $1.minX }
        let add = try #require(frames.dropLast().last)
        let more = try #require(frames.last)
        let gap = NSPoint(x: (add.maxX + more.minX) / 2, y: add.midY)
        let direct = host.hitTest(host.convert(gap, to: host.superview))
        let top = try #require(window.contentView?.superview)
        let route = top.hitTest(host.convert(gap, to: top.superview))
        print("PDFNO_HIDDEN_TITLEBAR mouseDownCanMoveWindow=\(host.mouseDownCanMoveWindow) isOpaque=\(host.isOpaque) bounds=\(host.bounds) frames=\(frames) gap=\(gap) direct=\(direct.map { String(reflecting: type(of: $0)) } ?? "nil") routed=\(route.map { String(reflecting: type(of: $0)) } ?? "nil")")
        #expect(more.minX - add.maxX > 80)
        #expect(host.bounds.contains(gap))
        #expect(direct === host)
        #expect(route === host)
        #expect(!host.mouseDownCanMoveWindow)
        let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown,
            location: host.convert(gap, to: nil), modifierFlags: [], timestamp: 0,
            windowNumber: window.windowNumber, context: nil, eventNumber: 0,
            clickCount: 1, pressure: 1))
        host.mouseDown(with: event)
        #expect(window.dragEvents.count == 1 && window.dragEvents.first === event)
        #expect(!window.isVisible && !window.isKeyWindow && window.toolbar === toolbar)
    }
}
#endif
