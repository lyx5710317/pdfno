// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import AppKit
import PDFnoUI

@main struct PDFnoMacApp: App {
    @State private var settingsRequest = Self.isFourLiveQA ? 1 : 0
    @AppStorage(PDFnoAppAppearance.preferenceKey) private var appearancePreference = ""
    @Environment(\.openWindow) private var openWindow
    private static var isFourLiveQA: Bool {
        let args = ProcessInfo.processInfo.arguments
        return Bundle.main.bundleIdentifier?.hasPrefix("org.pdfno.integration.professionala20261007.qaMacFourLive20261013.") == true
            && args.contains("--ui-testing") && args.contains("--ui-test-four-live-preview")
    }
    private var windowTitle: String {
        let arguments = ProcessInfo.processInfo.arguments
        if Self.isFourLiveQA { return "PDFno · 四项真实API验证" }
        if Bundle.main.bundleIdentifier?.hasPrefix("org.pdfno.integration.professionala20261007.qa") == true,
           arguments.contains("--ui-testing"), arguments.contains("--ui-test-four-layout-preview") {
            return "PDFno · 四项界面验证"
        }
        if Bundle.main.bundleIdentifier?.hasPrefix("org.pdfno.integration.professionala20261007.qa") == true,
           arguments.contains("--ui-testing"), arguments.contains("--ui-test-unlimited-reading-requests") {
            return "PDFno · 无次数限制验证"
        }
        return "PDFno"
    }
    var body: some Scene {
        Window(windowTitle, id: "library") {
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
