// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import AppKit

/// The window owns this native toolbar. Nested NavigationStacks may publish their
/// own toolbar preferences, but cannot relocate document tabs into the content.
struct MacDocumentWindowToolbar: NSViewRepresentable {
    let content: AnyView
    let width: CGFloat
    func makeCoordinator() -> Coordinator { Coordinator(content: content, width: width) }
    func makeNSView(context: Context) -> Anchor {
        let view = Anchor(); view.owner = context.coordinator; return view
    }
    func updateNSView(_ view: Anchor, context: Context) {
        context.coordinator.host.rootView = content
        context.coordinator.width = width
        context.coordinator.attach(view.window)
    }
    static func dismantleNSView(_ view: Anchor, coordinator: Coordinator) { coordinator.detach() }
    final class Anchor: NSView {
        weak var owner: Coordinator?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); owner?.attach(window) }
    }
    @MainActor final class Coordinator: NSObject, NSToolbarDelegate {
        let host: NSHostingView<AnyView>
        var width: CGFloat
        weak var window: NSWindow?
        let toolbar = NSToolbar(identifier: "PDFno.DocumentWindowToolbar")
        let item = NSToolbarItem(itemIdentifier: NSToolbarItem.Identifier("PDFno.DocumentWindowTabs"))
        private var observers: [NSObjectProtocol] = []
        private var widthConstraint: NSLayoutConstraint!
        init(content: AnyView, width: CGFloat) {
            host = NSHostingView(rootView: content); self.width = width
            super.init()
            toolbar.delegate = self; toolbar.allowsUserCustomization = false
            toolbar.autosavesConfiguration = false; toolbar.showsBaselineSeparator = false
            toolbar.displayMode = .iconOnly
            host.sizingOptions = []; host.translatesAutoresizingMaskIntoConstraints = false
            widthConstraint = host.widthAnchor.constraint(equalToConstant: max(260, width - 120))
            NSLayoutConstraint.activate([widthConstraint, host.heightAnchor.constraint(equalToConstant: 34)])
            item.view = host; item.visibilityPriority = .high; item.isBordered = false
        }
        func attach(_ candidate: NSWindow?) {
            guard let candidate else { return }
            if window !== candidate {
                detach(); window = candidate
                for name in [NSWindow.didUpdateNotification, NSWindow.didResizeNotification] {
                    observers.append(NotificationCenter.default.addObserver(forName: name, object: candidate, queue: .main) { [weak self] _ in
                        MainActor.assumeIsolated { self?.install() }
                    })
                }
            }
            install()
        }
        private func install() {
            guard let window else { return }
            window.titleVisibility = .hidden; window.toolbarStyle = .unifiedCompact
            let available = max(260, min(width, window.frame.width) - 120)
            let size = NSSize(width: available, height: 34)
            if host.frame.size != size {
                host.setFrameSize(size); widthConstraint.constant = available
            }
            if window.toolbar !== toolbar { window.toolbar = toolbar }
        }
        func detach() {
            for observer in observers { NotificationCenter.default.removeObserver(observer) }
            observers = []; window = nil
        }
        func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [item.itemIdentifier] }
        func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [item.itemIdentifier] }
        func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier identifier: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
            identifier == item.itemIdentifier ? item : nil
        }
    }
}
#endif
