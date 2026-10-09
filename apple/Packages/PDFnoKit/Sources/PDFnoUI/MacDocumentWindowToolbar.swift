// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import AppKit

/// A native titlebar accessory keeps the document band beside the traffic lights.
/// Never replace NSWindow.toolbar: SwiftUI tracks observers on its own instance.
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
    @MainActor final class Coordinator: NSObject {
        let host: NSHostingView<AnyView>
        var width: CGFloat
        weak var window: NSWindow?
        let accessory = NSTitlebarAccessoryViewController()
        private var resizeObserver: NSObjectProtocol?
        private var widthConstraint: NSLayoutConstraint!
        init(content: AnyView, width: CGFloat) {
            host = NSHostingView(rootView: content); self.width = width
            super.init()
            host.sizingOptions = []; host.translatesAutoresizingMaskIntoConstraints = false
            widthConstraint = host.widthAnchor.constraint(equalToConstant: max(260, width - 120))
            NSLayoutConstraint.activate([widthConstraint, host.heightAnchor.constraint(equalToConstant: 34)])
            host.setFrameSize(NSSize(width: max(260, width - 120), height: 34))
            accessory.view = host; accessory.layoutAttribute = .right
            accessory.fullScreenMinHeight = 34
        }
        func attach(_ candidate: NSWindow?) {
            guard let candidate else { return }
            if window !== candidate {
                detach(); window = candidate
                candidate.addTitlebarAccessoryViewController(accessory)
                resizeObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: candidate, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.resize() }
                }
            }
            resize()
        }
        private func resize() {
            guard let window else { return }
            let available = max(260, min(width, window.frame.width) - 120)
            let size = NSSize(width: available, height: 34)
            if host.frame.size != size {
                host.setFrameSize(size); widthConstraint.constant = available
            }
        }
        func detach() {
            if let resizeObserver { NotificationCenter.default.removeObserver(resizeObserver) }
            resizeObserver = nil
            if let window, let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === accessory }) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            window = nil
        }
    }
}
#endif
