// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI

/// Native selectable source, retaining the exact value and candidate links.
/// Source queries in the isolated Mac reader re-entered SwiftUI AX role/label
/// resolution. Keep the source exposed through a native selectable text view.
@MainActor
struct NativeJapaneseSourceText: NSViewRepresentable {
    let content: NSAttributedString
    let quote: String
    let onCandidateLink: (URL) -> Void

    final class Coordinator: NSObject, NSTextViewDelegate {
        var onCandidateLink: (URL) -> Void
        init(onCandidateLink: @escaping (URL) -> Void) { self.onCandidateLink = onCandidateLink }
        func textView(_ textView: NSTextView, clickedOnLink link: Any, at charIndex: Int) -> Bool {
            if let url = link as? URL, url.scheme == "pdfno-japanese-component", url.host == "candidate",
               let index = Int(url.path.dropFirst()), index >= 0 {
                onCandidateLink(url)
            }
            // All links belong to this display-only projection. Never open an external URL.
            return true
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(onCandidateLink: onCandidateLink) }
    func makeNSView(context: Context) -> NSTextView {
        Self.makeTextView(content: content, quote: quote, coordinator: context.coordinator)
    }
    static func makeTextView(content: NSAttributedString, quote: String, coordinator: Coordinator) -> NSTextView {
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 40))
        view.isEditable = false; view.isSelectable = true; view.isRichText = true
        view.drawsBackground = false; view.allowsUndo = false
        view.isHorizontallyResizable = false; view.isVerticallyResizable = true
        view.textContainerInset = NSSize(width: 0, height: 4)
        view.textContainer?.lineFragmentPadding = 0
        view.textContainer?.widthTracksTextView = true
        view.linkTextAttributes = [:]
        view.delegate = coordinator
        updateContent(content, quote: quote, in: view)
        view.setAccessibilityIdentifier("japanese-components-source")
        view.setAccessibilityHelp("成分颜色仅表示候选；可从下方文字按钮选择成分并阅读中文解释。")
        return view
    }
    static func updateContent(_ content: NSAttributedString, quote: String, in view: NSTextView) {
        view.setAccessibilityLabel(quote)
        guard view.textStorage?.isEqual(to: content) != true else { return }
        let selection = view.selectedRange()
        view.textStorage?.setAttributedString(content)
        let start = min(selection.location, content.length)
        view.setSelectedRange(NSRange(location: start, length: min(selection.length, content.length - start)))
    }
    func updateNSView(_ view: NSTextView, context: Context) {
        context.coordinator.onCandidateLink = onCandidateLink
        Self.updateContent(content, quote: quote, in: view)
    }
    func sizeThatFits(_ proposal: ProposedViewSize, nsView: NSTextView, context: Context) -> CGSize? {
        let width = max(1, proposal.width ?? 400)
        nsView.setFrameSize(NSSize(width: width, height: nsView.frame.height))
        guard let container = nsView.textContainer, let layout = nsView.layoutManager else { return nil }
        container.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        layout.ensureLayout(for: container)
        return CGSize(width: width, height: max(28, ceil(layout.usedRect(for: container).height) + 8))
    }
}
#endif
