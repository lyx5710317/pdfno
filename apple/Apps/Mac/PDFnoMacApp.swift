// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFnoUI

@main struct PDFnoMacApp: App {
    var body: some Scene {
        Window("PDFno", id: "library") { LibraryWorkspace().frame(minWidth: 720, minHeight: 520) }
            .defaultSize(width: 1180, height: 780)
        Settings { FeatureStatusView() }
    }
}
