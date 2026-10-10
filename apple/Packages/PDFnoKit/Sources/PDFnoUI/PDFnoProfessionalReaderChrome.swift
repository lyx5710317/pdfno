// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI

enum PDFnoReaderNavigationTab: String, CaseIterable { case contents = "目录", search = "查找" }
enum PDFnoReaderInspector { case notes, learning, bookmarks }

private struct ReaderRailExpandedKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var pdfnoReaderRailExpanded: Bool {
        get { self[ReaderRailExpandedKey.self] }
        set { self[ReaderRailExpandedKey.self] = newValue }
    }
}

struct PDFnoReaderRailLabelStyle: LabelStyle {
    let expanded: Bool
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
            if expanded { configuration.title.font(.system(size: 11)).lineLimit(1) }
        }
    }
}

/// Keep the native canvas in the same stable child while the right rail changes width.
struct PDFnoProfessionalReaderChrome<Actions: View, Controls: View, Content: View>: View {
    let title: String
    let format: String
    @ViewBuilder let controls: () -> Controls
    @ViewBuilder let actions: () -> Actions
    @ViewBuilder let content: () -> Content
    @State private var expanded = false
    var body: some View {
        HStack(spacing: 0) {
            content().frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            VStack(spacing: 0) {
                Button { expanded.toggle() } label: {
                    Label(expanded ? "收缩工具栏" : "展开工具栏", systemImage: expanded ? "chevron.right" : "chevron.left")
                        .labelStyle(.iconOnly).frame(maxWidth: .infinity).frame(height: 36)
                }.buttonStyle(.plain).accessibilityIdentifier("reader-rail-toggle")
                    .accessibilityLabel(expanded ? "收缩工具栏" : "展开工具栏")
                    .accessibilityValue(expanded ? "已展开" : "已收缩")
                    .help(expanded ? "收缩工具栏，保留图标" : "展开工具栏，显示工具名称")
                Divider()
                ScrollView(.vertical) {
                    VStack(spacing: 5) {
                        actions()
                        Divider().padding(.vertical, 6)
                        controls().labelStyle(PDFnoReaderRailLabelStyle(expanded: expanded))
                            .buttonStyle(PDFnoActionStyle(role: .quiet))
                    }.padding(.horizontal, 5).padding(.vertical, 8)
                }.scrollIndicators(.hidden)
            }.frame(width: expanded ? 104 : 46)
                .background(PDFnoDesign.Palette.surface)
                .environment(\.pdfnoReaderRailExpanded, expanded)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("professional-reader-tool-rail")
        }.background(PDFnoDesign.Palette.chrome).tint(.blue)
            .accessibilityElement(children: .contain)
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
    @Environment(\.pdfnoReaderRailExpanded) private var expanded
    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.system(size: 14)).frame(width: 22)
                if expanded { Text(title).font(.system(size: 11, weight: active ? .semibold : .regular)).lineLimit(1) }
            }.frame(maxWidth: .infinity).frame(height: 36).contentShape(Rectangle())
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
            // The search field is the single search entry. Keep contents as the
            // way back after showing results without another search shortcut.
            ForEach([PDFnoReaderNavigationTab.contents], id: \.self) { value in
                Button { tab = value } label: {
                    Text(value.rawValue).font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity).padding(.vertical, 7)
                        .background(tab == value ? PDFnoDesign.Palette.surface : .clear, in: RoundedRectangle(cornerRadius: 6))
                }.buttonStyle(.plain).accessibilityIdentifier("reader-navigation-tab-" + (value == .contents ? "contents" : "search"))
                    .accessibilityValue(tab == value ? "已选中" : "未选中")
                    .accessibilityAddTraits(tab == value ? .isSelected : [])
            }
        }.padding(3)
            .padding(.horizontal, 12).padding(.vertical, 8)
    }
}
#endif
