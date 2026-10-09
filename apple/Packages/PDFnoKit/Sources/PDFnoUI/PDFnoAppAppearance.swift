// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import AppKit

public enum PDFnoAppearanceMode: String, CaseIterable {
    case light, dark
    public var colorScheme: ColorScheme { self == .light ? .light : .dark }
    var title: String { self == .light ? "浅色" : "深色" }
}

public enum PDFnoAppAppearance {
    public static let preferenceKey = "PDFno.AppAppearance"
    @MainActor public static func apply(_ value: String) {
        switch PDFnoAppearanceMode(rawValue: value) {
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case nil: NSApp.appearance = nil
        }
    }
}

struct PDFnoAppearancePicker: View {
    @AppStorage(PDFnoAppAppearance.preferenceKey) private var preference = ""
    @Environment(\.colorScheme) private var colorScheme
    private var selected: PDFnoAppearanceMode {
        PDFnoAppearanceMode(rawValue: preference) ?? (colorScheme == .dark ? .dark : .light)
    }
    var body: some View {
        HStack(spacing: 16) {
            ForEach(PDFnoAppearanceMode.allCases, id: \.self) { mode in
                Button { preference = mode.rawValue } label: {
                    VStack(spacing: 14) {
                        Text("Aa").font(.system(size: 30, design: .serif))
                            .foregroundStyle(mode == .light ? Color.black : Color.white)
                            .frame(width: 80, height: 80)
                            .background(mode == .light ? Color.white : Color.black, in: Circle())
                            .overlay(Circle().stroke(Color.primary.opacity(0.12)))
                        Text(mode.title).font(.system(size: 14, weight: .medium))
                    }.padding(.vertical, 24).frame(maxWidth: .infinity)
                        .background(selected == mode ? Color.blue.opacity(0.08) : Color.primary.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected == mode ? Color.blue : Color.primary.opacity(0.12), lineWidth: selected == mode ? 2 : 1))
                        .contentShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain).foregroundStyle(.primary)
                    .accessibilityLabel(mode.title)
                    .accessibilityIdentifier("appearance-" + mode.rawValue)
                    .accessibilityValue(selected == mode ? "已选中" : "未选中")
            }
        }
        Text("选择后立即应用，并在下次启动时保留。").font(.caption).foregroundStyle(.secondary)
    }
}
#endif
