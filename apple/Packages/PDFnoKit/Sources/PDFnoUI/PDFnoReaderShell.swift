// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI

enum PDFnoReaderPanel: Equatable { case navigation, notes }
enum PDFnoReaderLayoutProfile { case standard, professional }

/// Presentation state only: hidden panels retain search/draft/source in their owner.
struct PDFnoReaderPanels: Equatable {
    var navigation = false
    var notes = false
    private(set) var lastOpened: PDFnoReaderPanel = .navigation
    mutating func show(_ panel: PDFnoReaderPanel, profile: PDFnoReaderLayoutProfile = .standard) {
        if profile == .professional { navigation = false; notes = false }
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
        if profile == .professional {
            if panel == .navigation { notes = false } else { navigation = false }
        }
        lastOpened = panel
    }
    func placement(width: CGFloat, profile: PDFnoReaderLayoutProfile = .standard,
                   navigationWidth: CGFloat? = nil, notesWidth: CGFloat? = nil) -> PDFnoReaderPlacement {
        PDFnoReaderPlacement(width: width, navigation: navigation, notes: notes, preferred: lastOpened, profile: profile,
                             navigationWidth: navigationWidth, notesWidth: notesWidth)
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

    init(width: CGFloat, navigation: Bool, notes: Bool, preferred: PDFnoReaderPanel, profile: PDFnoReaderLayoutProfile = .standard,
         navigationWidth requestedNavigation: CGFloat? = nil, notesWidth requestedNotes: CGFloat? = nil) {
        self.width = max(0, width.isFinite ? width : 0)
        let m = PDFnoDesign.Metric.self
        let available = self.width
        let navigationSize: CGFloat = requestedNavigation.map { Self.clampedPanelWidth($0, available: available) } ?? (profile == .professional ? 210 : m.navigationWidth)
        let preferredNotesSize: CGFloat = requestedNotes.map { Self.clampedPanelWidth($0, available: available) } ?? (profile == .professional ? 210 : m.notesWidth)
        let bothFit = profile != .professional && self.width >= m.readerMinimum + navigationSize + preferredNotesSize
        // The professional inspector can become compact before covering the
        // native document. Keep the full-width, two-panel desktop threshold.
        let notesSize: CGFloat = profile == .professional
            ? min(preferredNotesSize, max(230, self.width - m.readerMinimum))
            : preferredNotesSize
        showNavigation = navigation && (!notes || bothFit || preferred == .navigation)
        showNotes = notes && (!navigation || bothFit || preferred == .notes)
        let requestedWidth = showNavigation ? navigationSize : (showNotes ? notesSize : 0)
        overlay = requestedWidth > 0 && self.width < m.readerMinimum + requestedWidth
        navigationWidth = min(navigationSize, max(0, self.width - (overlay ? m.overlayInset : 0)))
        notesWidth = min(notesSize, max(0, self.width - (overlay ? m.overlayInset : 0)))
        leading = profile == .professional ? 0 : (showNavigation && !overlay ? navigationWidth : 0)
        trailing = !overlay ? ((profile == .professional && showNavigation ? navigationWidth : 0) + (showNotes ? notesWidth : 0)) : 0
    }
    static func clampedPanelWidth(_ value: CGFloat, available: CGFloat) -> CGFloat {
        let maximum = min(640, max(230, available - PDFnoDesign.Metric.readerMinimum))
        return min(maximum, max(230, value.isFinite ? value : 320))
    }
}

/// The reader is always the first, stable child; panel/width changes never rehost it.
struct PDFnoReaderShell<Reader: View, Navigation: View, Notes: View>: View {
    let panels: PDFnoReaderPanels
    var profile = PDFnoReaderLayoutProfile.standard
    @ViewBuilder let reader: () -> Reader
    @ViewBuilder let navigation: () -> Navigation
    @ViewBuilder let notes: () -> Notes
    @AppStorage("PDFnoReader.navigationPanelWidth") private var navigationWidth = 280.0
    @AppStorage("PDFnoReader.inspectorPanelWidth") private var inspectorWidth = 340.0
    @State private var dragStart: CGFloat?
    var body: some View {
        GeometryReader { geometry in
            let layout = panels.placement(width: geometry.size.width, profile: profile,
                                          navigationWidth: profile == .professional ? inspectorWidth : navigationWidth, notesWidth: inspectorWidth)
            ZStack(alignment: .topLeading) {
                reader()
                    // Native PDF/WebKit AX hit tests otherwise resolve to the
                    // covered document instead of the foreground inspector.
                    .accessibilityHidden(layout.overlay && (layout.showNavigation || layout.showNotes))
                    .padding(.leading, layout.leading)
                    .padding(.trailing, layout.trailing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(0)
                if layout.showNavigation {
                    navigation().frame(width: layout.navigationWidth, height: geometry.size.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: profile == .professional ? .trailing : .leading)
                        .zIndex(1)
                        .accessibilityIdentifier("reader-navigation-panel")
                }
                if layout.showNotes {
                    VStack(spacing: 0) { notes() }.frame(width: layout.notesWidth, height: geometry.size.height)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                        .zIndex(2)
                        // Foreground controls precede the reader in the AX tree.
                        .accessibilitySortPriority(10)
                        .accessibilityElement(children: .contain)
                        .accessibilityIdentifier("reader-notes-panel")
                }
                if layout.showNavigation || layout.showNotes {
                    let panelWidth = layout.showNavigation ? layout.navigationWidth : layout.notesWidth
                    let onRight = profile == .professional || layout.showNotes
                    #if os(macOS)
                    PDFnoReaderResizeHandle(width: panelWidth, onRight: onRight) { next in
                        let clamped = PDFnoReaderPlacement.clampedPanelWidth(next, available: geometry.size.width)
                        if profile == .professional || layout.showNotes { inspectorWidth = Double(clamped) }
                        else { navigationWidth = Double(clamped) }
                    }.frame(width: 14, height: geometry.size.height)
                        .position(x: onRight ? geometry.size.width - panelWidth : panelWidth, y: geometry.size.height / 2)
                        .zIndex(3)
                    #else
                    Rectangle().fill(Color.primary.opacity(0.13)).frame(width: 1)
                        .frame(width: 9, height: geometry.size.height).contentShape(Rectangle())
                        .position(x: onRight ? geometry.size.width - panelWidth : panelWidth, y: geometry.size.height / 2)
                        .gesture(DragGesture(minimumDistance: 1).onChanged { value in
                            if dragStart == nil { dragStart = panelWidth }
                            let next = (dragStart ?? panelWidth) + (onRight ? -value.translation.width : value.translation.width)
                            let clamped = PDFnoReaderPlacement.clampedPanelWidth(next, available: geometry.size.width)
                            if layout.showNavigation { navigationWidth = Double(clamped) } else { inspectorWidth = Double(clamped) }
                        }.onEnded { _ in dragStart = nil })
                        .accessibilityLabel("调整面板宽度").accessibilityIdentifier("reader-panel-divider")
                        .accessibilityValue("\(Int(panelWidth))")
                        .accessibilityAdjustableAction { direction in
                            let next = panelWidth + (direction == .increment ? 20 : -20)
                            let clamped = PDFnoReaderPlacement.clampedPanelWidth(next, available: geometry.size.width)
                            if layout.showNavigation { navigationWidth = Double(clamped) } else { inspectorWidth = Double(clamped) }
                        }
                        .zIndex(3)
                    #endif
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
    }
}
