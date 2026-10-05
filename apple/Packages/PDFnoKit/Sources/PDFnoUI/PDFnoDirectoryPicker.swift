// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI

/// A real native folder panel. Its initial directory is a session-only hint;
/// only the user's confirmed panel URL reaches the recovery operation.
struct PDFnoDirectoryPicker: NSViewRepresentable {
    @Binding var isPresented: Bool
    let initialDirectory: URL?
    let message: String
    let onPick: @MainActor (URL) -> Void
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> HostView {
        let view = HostView()
        context.coordinator.host = view
        view.didAttach = { [weak coordinator = context.coordinator] in coordinator?.presentIfNeeded() }
        return view
    }
    func updateNSView(_ view: HostView, context: Context) {
        context.coordinator.owner = self
        context.coordinator.presentIfNeeded()
    }
    static func dismantleNSView(_ view: HostView, coordinator: Coordinator) {
        view.didAttach = nil; coordinator.owner = nil
        coordinator.panel?.cancel(nil)
    }
    @MainActor final class HostView: NSView {
        var didAttach: (() -> Void)?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); didAttach?() }
    }
    @MainActor final class Coordinator: NSObject, NSOpenSavePanelDelegate {
        var owner: PDFnoDirectoryPicker?
        weak var host: HostView?
        var panel: NSOpenPanel?
        private var directoryLabel: NSTextField?
        private var scheduled = false
        func panel(_ sender: Any, didChangeToDirectoryURL url: URL?) {
            updateDirectoryLabel(url)
        }
        private func updateDirectoryLabel(_ url: URL?) {
            directoryLabel?.stringValue = "当前文件夹：" + (url?.resolvingSymlinksInPath().path ?? "尚未选择")
        }
        func presentIfNeeded() {
            guard owner?.isPresented == true, panel == nil, !scheduled, host?.window != nil else { return }
            scheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.scheduled = false
                guard let owner = self.owner, owner.isPresented, self.panel == nil, let window = self.host?.window else { return }
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true; panel.canChooseFiles = false
                panel.allowsMultipleSelection = false; panel.treatsFilePackagesAsDirectories = true
                let initial = owner.initialDirectory?.resolvingSymlinksInPath()
                panel.directoryURL = initial
                panel.message = owner.message
                let location = NSTextField(wrappingLabelWithString: "")
                location.frame = NSRect(x: 0, y: 0, width: 560, height: 54)
                location.isSelectable = true
                location.setAccessibilityIdentifier("pdfno-directory-current-location")
                self.directoryLabel = location
                panel.accessoryView = location
                panel.isAccessoryViewDisclosed = true
                panel.delegate = self
                self.updateDirectoryLabel(panel.directoryURL)
                self.panel = panel
                panel.beginSheetModal(for: window) { [weak self] response in
                    guard let self else { return }
                    let chosen = response == .OK ? panel.url : nil
                    self.panel = nil
                    self.directoryLabel = nil
                    guard let owner = self.owner else { return }
                    owner.isPresented = false
                    if let chosen { owner.onPick(chosen) }
                }
            }
        }
    }
}
#endif
