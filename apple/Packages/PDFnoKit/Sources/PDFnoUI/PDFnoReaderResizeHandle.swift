// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI

/// A native hit target stays above PDF/WebKit and tracks the mouse in window coordinates.
struct PDFnoReaderResizeHandle: NSViewRepresentable {
    let width: CGFloat
    let onRight: Bool
    let resize: (CGFloat) -> Void
    func makeNSView(context: Context) -> HandleView { HandleView() }
    func updateNSView(_ view: HandleView, context: Context) {
        view.currentWidth = width; view.onRight = onRight; view.resize = resize
        view.setAccessibilityValue(Int(width)); view.needsDisplay = true
    }
    final class HandleView: NSView {
        var currentWidth: CGFloat = 0
        var onRight = true
        var resize: ((CGFloat) -> Void)?
        private var start: (x: CGFloat, width: CGFloat)?
        private var hovered = false
        private var tracking: NSTrackingArea?
        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            setAccessibilityElement(true); setAccessibilityRole(.splitter)
            setAccessibilityLabel("调整面板宽度"); setAccessibilityIdentifier("reader-panel-divider")
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func hitTest(_ point: NSPoint) -> NSView? {
            bounds.contains(convert(point, from: superview)) ? self : nil
        }
        override func resetCursorRects() { addCursorRect(bounds, cursor: .resizeLeftRight) }
        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let tracking { removeTrackingArea(tracking) }
            let area = NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .mouseMoved, .cursorUpdate, .activeAlways, .inVisibleRect], owner: self)
            addTrackingArea(area); tracking = area
        }
        override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true; NSCursor.resizeLeftRight.set() }
        override func mouseMoved(with event: NSEvent) { hovered = true; needsDisplay = true }
        override func cursorUpdate(with event: NSEvent) { NSCursor.resizeLeftRight.set() }
        override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
        override func draw(_ dirtyRect: NSRect) {
            let active = hovered || start != nil
            (active ? NSColor.systemBlue : NSColor.separatorColor).setFill()
            let lineWidth: CGFloat = active ? 3 : 1
            NSRect(x: bounds.midX - lineWidth / 2, y: bounds.minY, width: lineWidth, height: bounds.height).fill()
        }
        override func mouseDown(with event: NSEvent) {
            start = (event.locationInWindow.x, currentWidth); needsDisplay = true; NSCursor.resizeLeftRight.set()
        }
        override func mouseDragged(with event: NSEvent) { updateDrag(event) }
        override func mouseUp(with event: NSEvent) { updateDrag(event); start = nil; needsDisplay = true }
        private func updateDrag(_ event: NSEvent) {
            guard let start else { return }
            let delta = event.locationInWindow.x - start.x
            resize?(start.width + (onRight ? -delta : delta))
        }
        override func accessibilityPerformIncrement() -> Bool { resize?(currentWidth + 20); return resize != nil }
        override func accessibilityPerformDecrement() -> Bool { resize?(currentWidth - 20); return resize != nil }
    }
}
#endif
