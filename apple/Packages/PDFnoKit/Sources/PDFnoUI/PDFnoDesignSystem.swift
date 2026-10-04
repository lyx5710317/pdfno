// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

/// PDFno-owned, replaceable shell tokens. No Bookno palette or font has been verified.
/// Native semantic colors follow appearance and system contrast; paper is reader-owned.
enum PDFnoDesign {
    enum Space {
        static let tight: CGFloat = 4
        static let small: CGFloat = 8
        static let regular: CGFloat = 12
        static let section: CGFloat = 16
        static let roomy: CGFloat = 24
    }
    enum TypeStyle {
        static let title = Font.system(size: 18, weight: .semibold)
        static let section = Font.system(size: 13, weight: .semibold)
        static let body = Font.system(size: 13)
        static let metadata = Font.system(size: 11)
    }
    enum Metric {
        static let corner: CGFloat = 8
        static let controlHeight: CGFloat = 30
        static let sidebarMinimum: CGFloat = 220
        static let sidebarIdeal: CGFloat = 270
        static let sidebarMaximum: CGFloat = 360
        static let navigationWidth: CGFloat = 240
        static let notesWidth: CGFloat = 320
        static let readerMinimum: CGFloat = 420
        static let overlayInset: CGFloat = 16
    }
    enum Palette {
        static let accent = Color.accentColor
        static let selection = accent.opacity(0.14)
        static let border = Color.primary.opacity(0.12)
        static let canvas = Color.secondary.opacity(0.08)
        #if os(macOS)
        static let chrome = Color(nsColor: .windowBackgroundColor)
        static let surface = Color(nsColor: .controlBackgroundColor)
        #else
        static let chrome = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        #endif
    }
}

enum PDFnoActionRole { case primary, secondary, quiet }
struct PDFnoActionStyle: ButtonStyle {
    var role: PDFnoActionRole = .secondary
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(PDFnoDesign.TypeStyle.body)
            .padding(.horizontal, PDFnoDesign.Space.regular)
            .frame(minHeight: PDFnoDesign.Metric.controlHeight)
            .foregroundStyle(role == .primary ? Color.white : Color.primary)
            .background(fill(pressed: configuration.isPressed), in: RoundedRectangle(cornerRadius: PDFnoDesign.Metric.corner))
            .overlay {
                RoundedRectangle(cornerRadius: PDFnoDesign.Metric.corner)
                    .strokeBorder(role == .secondary ? PDFnoDesign.Palette.border : .clear)
            }
            .opacity(isEnabled ? 1 : 0.45)
    }
    private func fill(pressed: Bool) -> Color {
        if role == .primary { return PDFnoDesign.Palette.accent.opacity(pressed ? 0.8 : 1) }
        if pressed { return PDFnoDesign.Palette.selection }
        return role == .secondary ? PDFnoDesign.Palette.surface : .clear
    }
}

struct PDFnoLibraryLayoutPicker: View {
    @Binding var grid: Bool
    var body: some View {
        HStack(spacing: PDFnoDesign.Space.tight) {
            choice("列表", icon: "list.bullet", value: false, identifier: "library-list-layout")
            choice("网格", icon: "square.grid.2x2", value: true, identifier: "library-grid-layout")
        }
    }
    private func choice(_ title: String, icon: String, value: Bool, identifier: String) -> some View {
        Button { grid = value } label: {
            Label(title, systemImage: icon).frame(maxWidth: .infinity)
        }
        .buttonStyle(PDFnoActionStyle(role: .quiet))
        .background(grid == value ? PDFnoDesign.Palette.selection : .clear, in: RoundedRectangle(cornerRadius: PDFnoDesign.Metric.corner))
        .overlay {
            RoundedRectangle(cornerRadius: PDFnoDesign.Metric.corner)
                .strokeBorder(grid == value ? PDFnoDesign.Palette.accent : .clear)
        }
        .accessibilityIdentifier(identifier)
        .accessibilityValue(grid == value ? "已选中" : "未选中")
        .accessibilityAddTraits(grid == value ? .isSelected : [])
        .help("以" + title + "显示书库")
    }
}

struct PDFnoPanel<Content: View>: View {
    let title: String
    let icon: String
    let closeIdentifier: String
    let close: () -> Void
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: PDFnoDesign.Space.small) {
                Label(title, systemImage: icon).font(PDFnoDesign.TypeStyle.section)
                Spacer(minLength: 0)
                Button(action: close) { Label("完成", systemImage: "xmark").labelStyle(.iconOnly) }
                    .buttonStyle(PDFnoActionStyle(role: .quiet))
                    .accessibilityLabel("完成")
                    .accessibilityIdentifier(closeIdentifier)
                    .help("关闭" + title)
            }.padding(PDFnoDesign.Space.small)
            Divider()
            content().frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(PDFnoDesign.Palette.chrome)
        .overlay { Rectangle().strokeBorder(PDFnoDesign.Palette.border) }
        .accessibilityElement(children: .contain)
    }
}
