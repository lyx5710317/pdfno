// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

enum PDFnoReaderPanel: Equatable { case navigation, notes }

/// Presentation state only: hidden panels retain search/draft/source in their owner.
struct PDFnoReaderPanels: Equatable {
    var navigation = false
    var notes = false
    private(set) var lastOpened: PDFnoReaderPanel = .navigation
    mutating func toggle(_ panel: PDFnoReaderPanel, width: CGFloat) {
        let layout = placement(width: width)
        switch panel {
        case .navigation:
            navigation = !layout.showNavigation
        case .notes:
            notes = !layout.showNotes
        }
        lastOpened = panel
    }
    func placement(width: CGFloat) -> PDFnoReaderPlacement {
        PDFnoReaderPlacement(width: width, navigation: navigation, notes: notes, preferred: lastOpened)
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

    init(width: CGFloat, navigation: Bool, notes: Bool, preferred: PDFnoReaderPanel) {
        self.width = max(0, width.isFinite ? width : 0)
        let m = PDFnoDesign.Metric.self
        let bothFit = self.width >= m.readerMinimum + m.navigationWidth + m.notesWidth
        showNavigation = navigation && (!notes || bothFit || preferred == .navigation)
        showNotes = notes && (!navigation || bothFit || preferred == .notes)
        let requestedWidth = showNavigation ? m.navigationWidth : (showNotes ? m.notesWidth : 0)
        overlay = requestedWidth > 0 && self.width < m.readerMinimum + requestedWidth
        navigationWidth = min(m.navigationWidth, max(0, self.width - (overlay ? m.overlayInset : 0)))
        notesWidth = min(m.notesWidth, max(0, self.width - (overlay ? m.overlayInset : 0)))
        leading = showNavigation && !overlay ? navigationWidth : 0
        trailing = showNotes && !overlay ? notesWidth : 0
    }
}

/// The reader is always the first, stable child; panel/width changes never rehost it.
struct PDFnoReaderShell<Reader: View, Navigation: View, Notes: View>: View {
    let panels: PDFnoReaderPanels
    @ViewBuilder let reader: () -> Reader
    @ViewBuilder let navigation: () -> Navigation
    @ViewBuilder let notes: () -> Notes
    var body: some View {
        GeometryReader { geometry in
            let layout = panels.placement(width: geometry.size.width)
            ZStack(alignment: .topLeading) {
                reader()
                    .padding(.leading, layout.leading)
                    .padding(.trailing, layout.trailing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if layout.showNavigation {
                    navigation().frame(width: layout.navigationWidth, height: geometry.size.height)
                        .accessibilityIdentifier("reader-navigation-panel")
                }
                if layout.showNotes {
                    notes().frame(width: layout.notesWidth, height: geometry.size.height)
                        .offset(x: layout.notesOffset)
                        .accessibilityIdentifier("reader-notes-panel")
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}
