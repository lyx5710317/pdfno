// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import Testing
@testable import PDFnoUI

@Suite @MainActor
struct NativeJapaneseSourceTextTests {
    @Test func exactUnicodeSourceKeepsNativeAccessibilityAndSelection() {
        let quote = "か\u{3099}👩🏽‍🚀 日本語"
        let coordinator = NativeJapaneseSourceText.Coordinator { _ in }
        let content = NSAttributedString(string: quote)
        let view = NativeJapaneseSourceText.makeTextView(content: content, quote: quote, coordinator: coordinator)
        #expect(!view.isEditable && view.isSelectable)
        #expect(view.accessibilityIdentifier() == "japanese-components-source")
        for _ in 0..<20 {
            #expect(view.accessibilityRole() == .textArea)
            #expect((view.accessibilityValue() as? String)?.utf8.elementsEqual(quote.utf8) == true)
            #expect(view.accessibilityLabel()?.utf8.elementsEqual(quote.utf8) == true)
        }
        view.setSelectedRange(NSRange(location: 2, length: 7))
        let selected = view.selectedRange()
        let restyled = NSMutableAttributedString(attributedString: content)
        restyled.addAttribute(.foregroundColor, value: NSColor.systemBlue, range: NSRange(location: 0, length: content.length))
        NativeJapaneseSourceText.updateContent(restyled, quote: quote, in: view)
        #expect(view.selectedRange() == selected)
        #expect(view.string.utf8.elementsEqual(quote.utf8))
    }
    @Test func candidateLinkHandledLocallyAndOtherURLsNeverOpened() {
        var selected: [URL] = []
        let coordinator = NativeJapaneseSourceText.Coordinator { selected.append($0) }
        let view = NativeJapaneseSourceText.makeTextView(content: NSAttributedString(string: "原文"), quote: "原文", coordinator: coordinator)
        let candidate = URL(string: "pdfno-japanese-component://candidate/0")!
        #expect(coordinator.textView(view, clickedOnLink: candidate, at: 0))
        #expect(selected == [candidate])
        for url in [URL(string: "https://example.invalid/")!, URL(string: "pdfno-japanese-component://other/0")!, URL(string: "pdfno-japanese-component://candidate/-1")!] {
            #expect(coordinator.textView(view, clickedOnLink: url, at: 0))
        }
        #expect(selected == [candidate])
        #expect(view.string == "原文")
    }
}
#endif
