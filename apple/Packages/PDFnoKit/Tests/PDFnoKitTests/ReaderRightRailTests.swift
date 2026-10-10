// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import Testing
import SwiftUI
@testable import PDFnoUI

@Suite struct ReaderRightRailTests {
    @Test func openingOneProfessionalPanelClosesThePreviousPanelAtEveryWidth() {
        for width in [CGFloat(360), 620, 720, 1280] {
            var panels = PDFnoReaderPanels()
            panels.show(.navigation, profile: .professional)
            panels.show(.notes, profile: .professional)
            let layout = panels.placement(width: width, profile: .professional)
            #expect(!panels.navigation && panels.notes)
            #expect(!layout.showNavigation && layout.showNotes && layout.leading == 0)
            panels.toggle(.navigation, width: width, profile: .professional)
            #expect(panels.navigation && !panels.notes)
            panels.toggle(.navigation, width: width, profile: .professional)
            #expect(!panels.navigation && !panels.notes)
            #expect(panels.placement(width: width, profile: .professional).canvasWidth == width)
        }
    }
    @Test func professionalDirectoryExpandsLeftFromTheRightEdge() {
        let layout = PDFnoReaderPlacement(width: 1000, navigation: true, notes: false, preferred: .navigation, profile: .professional)
        #expect(layout.showNavigation && !layout.showNotes && !layout.overlay)
        #expect(layout.leading == 0 && layout.trailing == layout.navigationWidth)
        #expect(layout.canvasWidth == 1000 - layout.navigationWidth)
    }
    @Test func narrowRightInspectorIsBoundedAndRestoresTheFullCanvasWhenClosed() {
        for width in stride(from: CGFloat(0), through: 1280, by: 8) {
            let open = PDFnoReaderPlacement(width: width, navigation: true, notes: true, preferred: .notes, profile: .professional)
            #expect(!(open.showNavigation && open.showNotes))
            #expect(open.notesWidth <= width && open.canvasWidth >= 0)
            let closed = PDFnoReaderPlacement(width: width, navigation: false, notes: false, preferred: .notes, profile: .professional)
            #expect(closed.leading == 0 && closed.trailing == 0 && closed.canvasWidth == width)
        }
    }
}
#endif
