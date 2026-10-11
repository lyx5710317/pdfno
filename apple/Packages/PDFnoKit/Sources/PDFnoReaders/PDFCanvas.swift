// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFKit

@MainActor
public final class PDFCanvasCoordinator: NSObject {
    let session: PDFReaderSession
    init(_ session: PDFReaderSession) { self.session = session }
    func observe(_ view: PDFView) {
        NotificationCenter.default.addObserver(self, selector: #selector(pageChanged), name: .PDFViewPageChanged, object: view)
        NotificationCenter.default.addObserver(self, selector: #selector(selectionChanged), name: .PDFViewSelectionChanged, object: view)
        #if os(macOS)
        NotificationCenter.default.addObserver(self, selector: #selector(userScrollStarted), name: NSScrollView.willStartLiveScrollNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(userScrollStarted), name: NSScrollView.didLiveScrollNotification, object: nil)
        #endif
    }
    @objc func pageChanged() { session.updatePage() }
    @objc func selectionChanged() { session.captureSelection() }
    #if os(macOS)
    @objc private func userScrollStarted(_ notification: Notification) {
        guard let scroll = notification.object as? NSScrollView, let view = session.view,
              scroll.isDescendant(of: view) else { return }
        session.userScrollBegan()
    }
    #endif
    deinit { NotificationCenter.default.removeObserver(self) }
}

#if os(macOS)
@MainActor private final class PDFCanvasView: PDFView {
    var sizeChanged: ((PDFView) -> Void)?
    override func setFrameSize(_ newSize: NSSize) {
        let changed = frame.size != newSize
        super.setFrameSize(newSize)
        if changed { sizeChanged?(self) }
    }
}

public struct PDFCanvas: NSViewRepresentable {
    @ObservedObject var session: PDFReaderSession
    public init(session: PDFReaderSession) { self.session = session }
    public func makeCoordinator() -> PDFCanvasCoordinator { PDFCanvasCoordinator(session) }
    public func makeNSView(context: Context) -> PDFView {
        let view = PDFCanvasView(); view.autoScales = true; view.displayMode = .singlePageContinuous; view.displayDirection = .vertical
        view.sizeChanged = { [weak session] native in session?.canvasSizeChanged(native) }
        view.setAccessibilityIdentifier("pdf-canvas")
        context.coordinator.observe(view); session.attach(view); return view
    }
    public func updateNSView(_ view: PDFView, context: Context) { session.attach(view) }
    public static func dismantleNSView(_ view: PDFView, coordinator: PDFCanvasCoordinator) {
        (view as? PDFCanvasView)?.sizeChanged = nil
        NotificationCenter.default.removeObserver(coordinator)
        coordinator.session.detach(view)
    }
}
#else
public struct PDFCanvas: UIViewRepresentable {
    @ObservedObject var session: PDFReaderSession
    public init(session: PDFReaderSession) { self.session = session }
    public func makeCoordinator() -> PDFCanvasCoordinator { PDFCanvasCoordinator(session) }
    public func makeUIView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous; view.displayDirection = .vertical
        view.accessibilityIdentifier = "pdf-canvas"
        context.coordinator.observe(view); session.attach(view); return view
    }
    public func updateUIView(_ view: PDFView, context: Context) { session.attach(view) }
    public static func dismantleUIView(_ view: PDFView, coordinator: PDFCanvasCoordinator) {
        NotificationCenter.default.removeObserver(coordinator)
        coordinator.session.detach(view)
    }
}
#endif
