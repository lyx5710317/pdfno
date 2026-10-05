// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import AppKit
import PDFnoUI

@main struct PDFnoMacApp: App {
    var body: some Scene {
        WindowGroup("PDFno", id: "library") { LibraryWorkspace().frame(minWidth: 720, minHeight: 520) }
            .defaultSize(width: min(1180, max(720, (NSScreen.main?.visibleFrame.width ?? 1204) - 24)),
                         height: min(780, max(520, (NSScreen.main?.visibleFrame.height ?? 804) - 24)))
            .defaultPosition(.center)
            .commands { CommandGroup(replacing: .newItem) {} }
        Settings { FeatureStatusView() }
    }
}
