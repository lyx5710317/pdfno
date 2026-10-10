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
    @MainActor final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        private weak var mountedView: NSTextView?
        private var allowsEditing = true
        private var generation = 0
        private var updatePending = false
        init(text: Binding<String>) { self.text = text }
        func mount(_ view: NSTextView, enabled: Bool) {
            generation += 1
            mountedView = view
            allowsEditing = enabled
            updatePending = false
        }
        func unmount(_ view: NSTextView) {
            guard mountedView === view else { return }
            generation += 1
            mountedView = nil
            allowsEditing = false
            updatePending = false
            view.delegate = nil
        }
        func update(_ view: NSTextView, text: Binding<String>, enabled: Bool) {
            guard mountedView === view else { return }
            self.text = text
            // Enforce the saving fence immediately, before the native update runs.
            allowsEditing = enabled
            guard !updatePending,
                  view.isEditable != enabled || !view.string.utf8.elementsEqual(text.wrappedValue.utf8) else { return }
            updatePending = true
            let scheduledGeneration = generation
            // setEditable can flush AppKit's cursor/display transaction and enter
            // SwiftUI hit testing. Run it after the representable graph update.
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view, self.generation == scheduledGeneration,
                      self.mountedView === view else { return }
                self.updatePending = false
                if view.isEditable != self.allowsEditing { view.isEditable = self.allowsEditing }
                let latestText = self.text.wrappedValue
                guard !view.string.utf8.elementsEqual(latestText.utf8) else { return }
                let selection = view.selectedRange()
                view.string = latestText
                let start = min(selection.location, latestText.utf16.count)
                view.setSelectedRange(NSRange(location: start, length: min(selection.length, latestText.utf16.count - start)))
            }
        }
        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            mountedView === textView && allowsEditing
        }
        func textDidChange(_ notification: Notification) {
            guard let view = notification.object as? NSTextView,
                  mountedView === view, allowsEditing else { return }
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
        coordinator.mount(view, enabled: enabled)
        view.delegate = coordinator
        view.setAccessibilityIdentifier(identifier)
        view.setAccessibilityLabel(label)
        scroll.documentView = view
        return scroll
    }
    func updateNSView(_ scroll: NSScrollView, context: Context) {
        guard let view = scroll.documentView as? NSTextView else { return }
        context.coordinator.update(view, text: $text, enabled: enabled)
    }
    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        guard let view = scroll.documentView as? NSTextView else { return }
        coordinator.unmount(view)
    }
}
#endif
