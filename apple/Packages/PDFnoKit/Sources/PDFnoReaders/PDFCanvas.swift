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
    }
    @objc func pageChanged() { session.updatePage() }
    @objc func selectionChanged() { session.captureSelection() }
    deinit { NotificationCenter.default.removeObserver(self) }
}

#if os(macOS)
public struct PDFCanvas: NSViewRepresentable {
    @ObservedObject var session: PDFReaderSession
    public init(session: PDFReaderSession) { self.session = session }
    public func makeCoordinator() -> PDFCanvasCoordinator { PDFCanvasCoordinator(session) }
    public func makeNSView(context: Context) -> PDFView {
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous
        view.setAccessibilityIdentifier("pdf-canvas")
        context.coordinator.observe(view); session.attach(view); return view
    }
    public func updateNSView(_ view: PDFView, context: Context) { session.attach(view) }
    public static func dismantleNSView(_ view: PDFView, coordinator: PDFCanvasCoordinator) {
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
        let view = PDFView(); view.autoScales = true; view.displayMode = .singlePageContinuous
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
