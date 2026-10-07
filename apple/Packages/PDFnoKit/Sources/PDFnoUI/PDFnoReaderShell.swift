// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

enum PDFnoReaderPanel: Equatable { case navigation, notes }
enum PDFnoReaderLayoutProfile { case standard, professional }

/// Presentation state only: hidden panels retain search/draft/source in their owner.
struct PDFnoReaderPanels: Equatable {
    var navigation = false
    var notes = false
    private(set) var lastOpened: PDFnoReaderPanel = .navigation
    mutating func show(_ panel: PDFnoReaderPanel) {
        if panel == .navigation { navigation = true } else { notes = true }
        lastOpened = panel
    }
    mutating func toggle(_ panel: PDFnoReaderPanel, width: CGFloat, profile: PDFnoReaderLayoutProfile = .standard) {
        let layout = placement(width: width, profile: profile)
        switch panel {
        case .navigation:
            navigation = !layout.showNavigation
        case .notes:
            notes = !layout.showNotes
        }
        lastOpened = panel
    }
    func placement(width: CGFloat, profile: PDFnoReaderLayoutProfile = .standard) -> PDFnoReaderPlacement {
        PDFnoReaderPlacement(width: width, navigation: navigation, notes: notes, preferred: lastOpened, profile: profile)
    }
}

struct PDFnoReaderPlacement: Equatable {
    let showNavigation: Bool
    let showNotes: Bool
    let overlay: Bool
    let navigationWidth: CGFloat
    let notesWidth: CGFloat
    let leading: CGFloat
    let trailing: CGFloat
    let width: CGFloat
    var canvasWidth: CGFloat { max(0, width - leading - trailing) }
    var notesOffset: CGFloat { max(0, width - notesWidth) }

    init(width: CGFloat, navigation: Bool, notes: Bool, preferred: PDFnoReaderPanel, profile: PDFnoReaderLayoutProfile = .standard) {
        self.width = max(0, width.isFinite ? width : 0)
        let m = PDFnoDesign.Metric.self
        let navigationSize: CGFloat = profile == .professional ? 210 : m.navigationWidth
        let notesSize: CGFloat = profile == .professional ? 300 : m.notesWidth
        let bothFit = self.width >= m.readerMinimum + navigationSize + notesSize
        showNavigation = navigation && (!notes || bothFit || preferred == .navigation)
        showNotes = notes && (!navigation || bothFit || preferred == .notes)
        let requestedWidth = showNavigation ? navigationSize : (showNotes ? notesSize : 0)
        overlay = requestedWidth > 0 && self.width < m.readerMinimum + requestedWidth
        navigationWidth = min(navigationSize, max(0, self.width - (overlay ? m.overlayInset : 0)))
        notesWidth = min(notesSize, max(0, self.width - (overlay ? m.overlayInset : 0)))
        leading = showNavigation && !overlay ? navigationWidth : 0
        trailing = showNotes && !overlay ? notesWidth : 0
    }
}

/// The reader is always the first, stable child; panel/width changes never rehost it.
struct PDFnoReaderShell<Reader: View, Navigation: View, Notes: View>: View {
    let panels: PDFnoReaderPanels
    var profile = PDFnoReaderLayoutProfile.standard
    @ViewBuilder let reader: () -> Reader
    @ViewBuilder let navigation: () -> Navigation
    @ViewBuilder let notes: () -> Notes
    var body: some View {
        GeometryReader { geometry in
            let layout = panels.placement(width: geometry.size.width, profile: profile)
            ZStack(alignment: .topLeading) {
                reader()
                    .padding(.leading, layout.leading)
                    .padding(.trailing, layout.trailing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(0)
                if layout.showNavigation {
                    navigation().frame(width: layout.navigationWidth, height: geometry.size.height)
                        .zIndex(1)
                        .accessibilityIdentifier("reader-navigation-panel")
                }
                if layout.showNotes {
                    notes().frame(width: layout.notesWidth, height: geometry.size.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .zIndex(2)
                        // Foreground controls precede the reader in the AX tree.
                        .accessibilitySortPriority(10)
                        .accessibilityIdentifier("reader-notes-panel")
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}
