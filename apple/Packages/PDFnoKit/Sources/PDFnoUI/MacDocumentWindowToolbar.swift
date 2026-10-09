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
        context.coordinator.setContent(content)
        context.coordinator.width = width
        context.coordinator.attach(view.window)
    }
    static func dismantleNSView(_ view: Anchor, coordinator: Coordinator) { coordinator.detach() }
    final class Anchor: NSView {
        weak var owner: Coordinator?
        override func viewDidMoveToWindow() { super.viewDidMoveToWindow(); owner?.attach(window) }
    }
    final class DocumentBandHost: NSHostingView<AnyView> {
        var controlFrames: [CGRect] = []
        var nativeDoubleClick: ((NSEvent) -> Void)?
        private func isEmptySpace(_ point: NSPoint) -> Bool {
            !controlFrames.isEmpty && !controlFrames.contains(where: { $0.contains(point) })
        }
        override func hitTest(_ point: NSPoint) -> NSView? {
            let local = convert(point, from: superview)
            guard bounds.contains(local) else { return nil }
            // AppKit's titlebar receives empty space, including its native
            // drag and double-click behavior. SwiftUI keeps actual controls.
            if isEmptySpace(local) { return self }
            return super.hitTest(point)
        }
        override func mouseDown(with event: NSEvent) {
            guard isEmptySpace(convert(event.locationInWindow, from: nil)), let window else {
                super.mouseDown(with: event); return
            }
            if event.clickCount == 1 { window.performDrag(with: event) }
        }
        override func mouseUp(with event: NSEvent) {
            if event.clickCount > 1, isEmptySpace(convert(event.locationInWindow, from: nil)) {
                nativeDoubleClick?(event)
            } else { super.mouseUp(with: event) }
        }
    }
    @MainActor final class Coordinator: NSObject {
        let host: DocumentBandHost
        var width: CGFloat
        weak var window: NSWindow?
        let accessory = NSTitlebarAccessoryViewController()
        private var resizeObserver: NSObjectProtocol?
        private var updateObserver: NSObjectProtocol?
        private var widthConstraint: NSLayoutConstraint!
        init(content: AnyView, width: CGFloat) {
            host = DocumentBandHost(rootView: content); self.width = width
            super.init()
            host.sizingOptions = []; host.translatesAutoresizingMaskIntoConstraints = false
            widthConstraint = host.widthAnchor.constraint(equalToConstant: max(260, width - 120))
            NSLayoutConstraint.activate([widthConstraint, host.heightAnchor.constraint(equalToConstant: 34)])
            host.setFrameSize(NSSize(width: max(260, width - 120), height: 34))
            accessory.view = host; accessory.layoutAttribute = .right
            accessory.fullScreenMinHeight = 34
            setContent(content)
            host.nativeDoubleClick = { [weak self] event in self?.forwardNativeDoubleClick(event) }
        }
        private func forwardNativeDoubleClick(_ up: NSEvent) {
            guard let window, let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === accessory }),
                  let down = NSEvent.mouseEvent(with: .leftMouseDown, location: up.locationInWindow,
                    modifierFlags: up.modifierFlags, timestamp: up.timestamp, windowNumber: window.windowNumber,
                    context: nil, eventNumber: up.eventNumber, clickCount: up.clickCount, pressure: 1) else { return }
            // Give native event dispatch the original titlebar for this gesture.
            // The same accessory and document state return before this call ends.
            window.removeTitlebarAccessoryViewController(at: index)
            defer { window.insertTitlebarAccessoryViewController(accessory, at: index) }
            window.sendEvent(down)
            window.sendEvent(up)
        }
        func setContent(_ content: AnyView) {
            host.rootView = AnyView(content.coordinateSpace(name: PDFnoTitlebarControlFrames.space)
                .onPreferenceChange(PDFnoTitlebarControlFrames.self) { [weak host] frames in
                    host?.controlFrames = frames
                })
        }
        func attach(_ candidate: NSWindow?) {
            guard let candidate else { return }
            if window !== candidate {
                detach(); window = candidate
                candidate.addTitlebarAccessoryViewController(accessory)
                // NavigationStack may restore its title after a route update.
                // Hide only that text; the toolbar and its KVO ownership stay intact.
                updateObserver = NotificationCenter.default.addObserver(forName: NSWindow.didUpdateNotification, object: candidate, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.hideNativeTitle() }
                }
                resizeObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResizeNotification, object: candidate, queue: .main) { [weak self] _ in
                    MainActor.assumeIsolated { self?.resize() }
                }
            }
            hideNativeTitle(); resize()
        }
        private func hideNativeTitle() {
            if let window, window.titleVisibility != .hidden { window.titleVisibility = .hidden }
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
            if let updateObserver { NotificationCenter.default.removeObserver(updateObserver) }
            updateObserver = nil
            if let window, let index = window.titlebarAccessoryViewControllers.firstIndex(where: { $0 === accessory }) {
                window.removeTitlebarAccessoryViewController(at: index)
            }
            window = nil
        }
    }
}

private struct PDFnoTitlebarControlFrames: PreferenceKey {
    static let space = "PDFnoDocumentTitlebar"
    static let defaultValue: [CGRect] = []
    static func reduce(value: inout [CGRect], nextValue: () -> [CGRect]) { value += nextValue() }
}
extension View {
    func pdfnoTitlebarControl() -> some View {
        background {
            GeometryReader { geometry in
                Color.clear.preference(key: PDFnoTitlebarControlFrames.self,
                    value: [geometry.frame(in: .named(PDFnoTitlebarControlFrames.space))])
            }
        }
    }
}
#endif
