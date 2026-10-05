// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import AppKit
import PDFnoDomain

/// Keep the draft editor outside the saved-record List's AX row proxies.
struct PDFNoteComposer: View {
    let anchor: PDFSourceAnchor?
    @Binding var draft: String
    let enabled: Bool
    let save: (PDFSourceAnchor, String) -> Bool

    var body: some View {
        VStack(alignment: .leading, spacing: PDFnoDesign.Space.small) {
            Text("当前选区").font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary)
            if let anchor {
                PDFnoTextViewport(text: anchor.quote)
                PDFNoteDraftInput(text: $draft, enabled: enabled).frame(height: 96)
                if !draft.isEmpty { PDFnoStatusMessage(text: "草稿未保存 · 关闭面板会保留，保存成功后清空") }
                Button("保存高亮与笔记") {
                    if save(anchor, draft) { draft = "" }
                }.buttonStyle(PDFnoActionStyle(role: .primary)).disabled(!enabled).accessibilityIdentifier("save-note")
            } else {
                PDFnoEmptyState(title: "尚未选择原文", detail: "在 PDF 中选中文字，再打开这里。扫描页或受限文件可能不可选择。")
            }
        }.padding(PDFnoDesign.Space.regular).frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The queried AX identifier belongs to the same native cell used for hit testing.
@MainActor private struct PDFNoteDraftInput: NSViewRepresentable {
    @Binding var text: String
    let enabled: Bool
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        init(text: Binding<String>) { self.text = text }
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }
        func controlTextDidBeginEditing(_ notification: Notification) {
            guard let field = notification.object as? NSTextField, let editor = field.currentEditor() as? NSTextView else { return }
            editor.isAutomaticQuoteSubstitutionEnabled = false
            editor.isAutomaticDashSubstitutionEnabled = false
            editor.isAutomaticTextReplacementEnabled = false
            editor.isAutomaticSpellingCorrectionEnabled = false
        }
        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            textView.insertNewlineIgnoringFieldEditor(nil)
            return true
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }
    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = "写下你的笔记（可选）"
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.usesSingleLineMode = false
        field.maximumNumberOfLines = 0
        field.cell?.wraps = true
        field.cell?.isScrollable = false
        field.lineBreakMode = .byWordWrapping
        field.setAccessibilityIdentifier("note-input")
        field.cell?.setAccessibilityIdentifier("note-input")
        field.setAccessibilityLabel("写下你的笔记（可选）")
        field.delegate = context.coordinator
        return field
    }
    func updateNSView(_ field: NSTextField, context: Context) {
        context.coordinator.text = $text
        field.isEnabled = enabled
        field.isEditable = enabled
        field.isSelectable = true
        guard !field.stringValue.utf8.elementsEqual(text.utf8) else { return }
        let editor = field.currentEditor() as? NSTextView
        let selection = editor?.selectedRange()
        field.stringValue = text
        if let editor, let selection {
            editor.string = text
            let start = min(selection.location, text.utf16.count)
            editor.setSelectedRange(NSRange(location: start, length: min(selection.length, text.utf16.count - start)))
        }
    }
}
#endif
