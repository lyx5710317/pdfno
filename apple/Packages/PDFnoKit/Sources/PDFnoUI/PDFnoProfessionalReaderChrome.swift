// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI

enum PDFnoReaderNavigationTab: String, CaseIterable { case contents = "目录", search = "查找" }
enum PDFnoReaderInspector { case notes, learning }

/// Presentation only. The canvas and its original session remain inside one stable shell.
struct PDFnoProfessionalReaderChrome<Actions: View, Controls: View, Content: View>: View {
    let title: String
    let format: String
    @ViewBuilder let controls: () -> Controls
    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text").foregroundStyle(.blue).accessibilityHidden(true)
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    .truncationMode(.middle).accessibilityIdentifier("professional-reader-title")
                Text(format).font(.system(size: 9, weight: .semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 6).padding(.vertical, 4)
                    .background(PDFnoDesign.Palette.canvas, in: RoundedRectangle(cornerRadius: 5))
                Spacer(minLength: 8)
                HStack(spacing: 2) { controls() }
                    .labelStyle(.iconOnly).buttonStyle(PDFnoActionStyle(role: .quiet))
            }.padding(.horizontal, 14).frame(height: 46)
                .background(PDFnoDesign.Palette.surface)
            Divider()
            HStack(spacing: 0) {
                ScrollView(.vertical) {
                    VStack(spacing: 4) { actions() }.padding(.vertical, 8)
                }.scrollIndicators(.hidden).frame(width: 58)
                    .background(PDFnoDesign.Palette.surface)
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("professional-reader-tool-rail")
                Divider()
                content().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }.background(PDFnoDesign.Palette.chrome).tint(.blue)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("professional-reader-workspace")
    }
}

/// Identifier, label, selection and hit area all belong to the real Button.
struct PDFnoReaderRailButton: View {
    let title: String
    let symbol: String
    let identifier: String
    var accessibilityTitle: String? = nil
    var active = false
    var disabled = false
    var hint = ""
    let action: () -> Void
    @FocusState private var focused: Bool
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 14))
                Text(title).font(.system(size: 9, weight: active ? .semibold : .regular)).lineLimit(1)
            }.frame(width: 46, height: 40).contentShape(Rectangle())
                .foregroundStyle(active ? Color.blue : Color.secondary)
                .background(active ? Color.blue.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 8))
                .overlay { RoundedRectangle(cornerRadius: 8).strokeBorder(focused ? Color.blue : .clear) }
        }.buttonStyle(.plain).disabled(disabled).focused($focused)
            .accessibilityLabel(accessibilityTitle ?? title)
            .accessibilityIdentifier(identifier)
            .accessibilityValue(active ? "已展开" : "已收起")
            .accessibilityAddTraits(active ? .isSelected : [])
            .help(hint.isEmpty ? (accessibilityTitle ?? title) : hint)
    }
}

struct PDFnoReaderNavigationPicker: View {
    @Binding var tab: PDFnoReaderNavigationTab
    var body: some View {
        HStack(spacing: 3) {
            ForEach(PDFnoReaderNavigationTab.allCases, id: \.self) { value in
                Button { tab = value } label: {
                    Text(value.rawValue).font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(tab == value ? PDFnoDesign.Palette.surface : .clear, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain).accessibilityIdentifier("reader-navigation-tab-" + (value == .contents ? "contents" : "search"))
                    .accessibilityValue(tab == value ? "已选中" : "未选中")
                    .accessibilityAddTraits(tab == value ? .isSelected : [])
            }
        }.padding(3).background(PDFnoDesign.Palette.canvas, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12).padding(.vertical, 8)
    }
}
#endif
