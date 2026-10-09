// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Attach the native file panel to this component's own window. A nested
/// SwiftUI fileImporter can be shadowed by the host's importer on macOS 15.
struct PDFnoDOCXPicker: NSViewRepresentable {
    @Binding var isPresented: Bool
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
    @MainActor final class Coordinator {
        var owner: PDFnoDOCXPicker?
        weak var host: HostView?
        var panel: NSOpenPanel?
        private var scheduled = false
        func presentIfNeeded() {
            guard owner?.isPresented == true, panel == nil, !scheduled, host?.window != nil else { return }
            scheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.scheduled = false
                guard let owner = self.owner, owner.isPresented, self.panel == nil,
                      let window = self.host?.window, window.attachedSheet == nil else { return }
                let panel = NSOpenPanel()
                panel.title = "选择 DOCX 原件"
                panel.allowedContentTypes = [UTType(filenameExtension: "docx") ?? .data]
                panel.canChooseFiles = true; panel.canChooseDirectories = false
                panel.allowsMultipleSelection = false
                self.panel = panel
                panel.beginSheetModal(for: window) { [weak self] response in
                    guard let self else { return }
                    let chosen = response == .OK ? panel.url : nil
                    self.panel = nil
                    guard let owner = self.owner else { return }
                    owner.isPresented = false
                    if let chosen { owner.onPick(chosen) }
                }
            }
        }
    }
}
#endif
