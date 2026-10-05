// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI

/// A plain native editor whose delegate checkpoints every edit, including an
/// empty body. Re-rendering a draft never replaces the active text or caret.
@MainActor
struct NativeNoteBodyInput: NSViewRepresentable {
    @Binding var text: String
    let identifier: String
    let enabled: Bool
    var label: String = "编辑用户正文"

    final class BodyTextView: NSTextView {
        private var requestedFocus = false
        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if !requestedFocus, let window {
                requestedFocus = true
                window.makeFirstResponder(self)
            }
        }
    }
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView else { return }
            text.wrappedValue = view.string
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    func makeNSView(context: Context) -> NSScrollView {
        Self.makeEditor(coordinator: context.coordinator, identifier: identifier, enabled: enabled, label: label)
    }
    // The same native control factory is exercised offscreen by storage tests.
    static func makeEditor(coordinator: Coordinator, identifier: String, enabled: Bool, label: String = "编辑用户正文") -> NSScrollView {
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 300, height: 96))
        scroll.setAccessibilityIdentifier(identifier + "-scroll")
        scroll.borderType = .bezelBorder
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        let view = BodyTextView(frame: scroll.contentView.bounds)
        view.isRichText = false
        view.isEditable = enabled
        view.isSelectable = true
        view.allowsUndo = true
        view.isAutomaticQuoteSubstitutionEnabled = false
        view.isAutomaticDashSubstitutionEnabled = false
        view.isAutomaticTextReplacementEnabled = false
        view.isAutomaticSpellingCorrectionEnabled = false
        view.font = .systemFont(ofSize: NSFont.systemFontSize)
        view.textContainerInset = NSSize(width: 6, height: 8)
        view.isHorizontallyResizable = false
        view.isVerticallyResizable = true
        view.autoresizingMask = [.width]
        view.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        view.textContainer?.widthTracksTextView = true
        view.string = coordinator.text.wrappedValue
        view.delegate = coordinator
        view.setAccessibilityIdentifier(identifier)
        view.setAccessibilityLabel(label)
        scroll.documentView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.text = $text
        guard let view = scroll.documentView as? NSTextView else { return }
        view.isEditable = enabled
        guard !view.string.utf8.elementsEqual(text.utf8) else { return }
        let selection = view.selectedRange()
        view.string = text
        let start = min(selection.location, text.utf16.count)
        view.setSelectedRange(NSRange(location: start, length: min(selection.length, text.utf16.count - start)))
    }
}
#endif
