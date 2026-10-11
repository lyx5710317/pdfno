// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import PDFnoUI

@Suite(.serialized) @MainActor struct ReaderTitlebarHitRoutingTests {
    private final class DragRecordingWindow: NSWindow {
        var dragEvents: [NSEvent] = []
        override func performDrag(with event: NSEvent) { dragEvents.append(event) }
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
