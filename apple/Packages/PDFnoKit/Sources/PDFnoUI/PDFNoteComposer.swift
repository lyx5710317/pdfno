// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import AppKit
import PDFnoDomain

/// A native panel boundary keeps its virtual controls in the same AppKit AX host.
struct PDFNotesPanelHost<Content: View>: NSViewRepresentable {
    @ViewBuilder let content: () -> Content
    func makeNSView(context: Context) -> NSHostingView<Content> {
        let view = NSHostingView(rootView: content())
        view.sizingOptions = []
        return view
    }
    func updateNSView(_ view: NSHostingView<Content>, context: Context) { view.rootView = content() }
}

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
                TextField("写下你的笔记（可选）", text: $draft, axis: .vertical)
                    .lineLimit(3...8).disabled(!enabled).accessibilityIdentifier("note-input")
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
#endif
