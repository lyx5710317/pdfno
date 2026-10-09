// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI

/// Window presentation only. Reader models and draft owners remain mounted.
enum PDFnoWorkspaceRoute: Equatable { case library, reader, settings, tool }
enum PDFnoWorkspaceTool { case search, cover, conversion, bookno, recovery, tools }

@MainActor final class PDFnoWorkspaceNavigation: ObservableObject {
    @Published private(set) var route = PDFnoWorkspaceRoute.library
    @Published private(set) var hasOpenedSettings = false
    private(set) var settingsReturnRoute = PDFnoWorkspaceRoute.library
    @Published private(set) var tool = PDFnoWorkspaceTool.search
    private var toolReturnRoute = PDFnoWorkspaceRoute.library

    func showLibrary() { route = .library }
    func showReader() { route = .reader }
    func showSettings() {
        if route != .settings { settingsReturnRoute = route == .tool ? toolReturnRoute : route }
        hasOpenedSettings = true
        route = .settings
    }
    func returnFromSettings(readerAvailable: Bool) {
        route = settingsReturnRoute == .reader && readerAvailable ? .reader : .library
    }
    func showTool(_ tool: PDFnoWorkspaceTool) {
        if route != .tool { toolReturnRoute = route }
        self.tool = tool; route = .tool
    }
    func returnFromTool(readerAvailable: Bool) {
        guard route == .tool else { return }
        route = toolReturnRoute == .reader && !readerAvailable ? .library : toolReturnRoute
    }
}

struct PDFnoWorkspaceBusyKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) { value = value || nextValue() }
}

private struct PDFnoWorkspaceNavigationKey: EnvironmentKey {
    static let defaultValue: PDFnoWorkspaceNavigation? = nil
}
extension EnvironmentValues {
    var pdfnoWorkspaceNavigation: PDFnoWorkspaceNavigation? {
        get { self[PDFnoWorkspaceNavigationKey.self] }
        set { self[PDFnoWorkspaceNavigationKey.self] = newValue }
    }
    var pdfnoInlineDismiss: (@MainActor @Sendable () -> Void)? {
        get { self[PDFnoInlineDismissKey.self] }
        set { self[PDFnoInlineDismissKey.self] = newValue }
    }
}
private struct PDFnoInlineDismissKey: EnvironmentKey {
    static let defaultValue: (@MainActor @Sendable () -> Void)? = nil
}
#endif
