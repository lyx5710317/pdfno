// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

struct ReadingLayoutPanel: View {
    let layout: ReadingLayout
    let language: DocumentWritingLanguage
    let busy: Bool
    let close: () -> Void
    let change: (ReadingLayout) -> Void
    var body: some View {
        PDFnoPanel(title: "排版",icon: "textformat",closeIdentifier: "reading-aa-close",close: close,surface: PDFnoDesign.Palette.surface) {
            VStack(alignment: .leading,spacing: 18) {
                if language.permitsVerticalReflow {
                    HStack(spacing: 8) {
                        choice("横排",selected: !layout.vertical,identifier: "reading-horizontal") { var value=layout;value.vertical=false;change(value) }
                        choice("竖排",selected: layout.vertical,identifier: "reading-vertical") { var value=layout;value.vertical=true;change(value) }
                    }
                }
                Text("字号").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("缩小") { var value=layout;value.fontSize=max(12,value.fontSize-2);change(value) }
                        .disabled(layout.fontSize<=12).accessibilityIdentifier("reading-font-smaller")
                    Spacer(minLength: 0)
                    Text("\(layout.fontSize)").monospacedDigit().accessibilityIdentifier("reading-font-size")
                    Spacer(minLength: 0)
                    Button("放大") { var value=layout;value.fontSize=min(36,value.fontSize+2);change(value) }
                        .disabled(layout.fontSize>=36).accessibilityIdentifier("reading-font-larger")
                }
                Text("翻页").font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(ReadingPageMode.allCases,id: \.self) { mode in
                        choice(mode.title,selected: layout.mode==mode,identifier: "reading-mode-"+mode.rawValue) { var value=layout;value.mode=mode;change(value) }
                    }
                }
                Spacer(minLength: 0)
            }.padding(12).disabled(busy)
        }
    }
    private func choice(_ title: String,selected: Bool,identifier: String,action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 12)).frame(maxWidth: .infinity).padding(.vertical,8)
            .background(selected ? Color.accentColor.opacity(0.12) : .clear,in: RoundedRectangle(cornerRadius: 6)) }
            .buttonStyle(.plain).accessibilityIdentifier(identifier).accessibilityValue(selected ? "已选中" : "未选中")
    }
}
struct ReadingPageButtons: View {
    let previousEnabled: Bool
    let nextEnabled: Bool
    let previous: () -> Void
    let next: () -> Void
    var body: some View {
        HStack {
            button("上一页",identifier: "reading-bottom-previous",enabled: previousEnabled,action: previous)
            Spacer(minLength: 8)
            button("下一页",identifier: "reading-bottom-next",enabled: nextEnabled,action: next)
        }.padding(.horizontal,16).padding(.bottom,12)
    }
    private func button(_ title: String,identifier: String,enabled: Bool,action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(title).font(.system(size: 12)).padding(.horizontal,16).padding(.vertical,7)
            .overlay { Capsule().strokeBorder(PDFnoDesign.Palette.border.opacity(0.65)) }.contentShape(Capsule()) }
            .buttonStyle(.plain).disabled(!enabled).accessibilityIdentifier(identifier)
    }
}
#endif
