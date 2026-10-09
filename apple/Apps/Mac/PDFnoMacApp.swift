// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import AppKit
import PDFnoUI

@main struct PDFnoMacApp: App {
    @State private var settingsRequest = 0
    @AppStorage(PDFnoAppAppearance.preferenceKey) private var appearancePreference = ""
    @Environment(\.openWindow) private var openWindow
    var body: some Scene {
        Window("PDFno", id: "library") {
            LibraryWorkspace(settingsRequest: settingsRequest).frame(minWidth: 720, minHeight: 468)
                .preferredColorScheme(PDFnoAppearanceMode(rawValue: appearancePreference)?.colorScheme)
                .onChange(of: appearancePreference, initial: true) { _, value in PDFnoAppAppearance.apply(value) }
        }
            .defaultSize(width: min(1180, max(720, (NSScreen.main?.visibleFrame.width ?? 1204) - 24)),
                         height: min(780, max(520, (NSScreen.main?.visibleFrame.height ?? 804) - 24)))
            .defaultPosition(.center)
            .windowToolbarStyle(.unifiedCompact)
            .commands {
                CommandGroup(replacing: .newItem) {}
                CommandGroup(replacing: .appSettings) {
                    Button("设置…") { settingsRequest += 1; openWindow(id: "library") }
                        .keyboardShortcut(",", modifiers: .command)
                }
            }
    }
}
