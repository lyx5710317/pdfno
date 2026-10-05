// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI

public enum ReaderNavigationCommand: Sendable { case previousPage, nextPage, returnToPreviousLocation }

/// Reserved reader commands only. Text input, composition, sheets and unfocused windows
/// pass through unchanged. The host must additionally require focus inside its PDF canvas.
enum ReaderNavigationShortcutPolicy {
    static func command(keyCode: UInt16, modifiers: NSEvent.ModifierFlags, isRepeat: Bool,
                        enabled: Bool, canvasFocused: Bool, textInput: Bool, hasSheet: Bool) -> ReaderNavigationCommand? {
        let flags = modifiers.intersection(.deviceIndependentFlagsMask).subtracting([.capsLock, .numericPad, .function])
        guard enabled, canvasFocused, !textInput, !hasSheet, !isRepeat, flags == [.command, .option] else { return nil }
        switch keyCode {
        case 123: return .previousPage
        case 124: return .nextPage
        case 126: return .returnToPreviousLocation
        default: return nil
        }
    }
    @MainActor static func isTextInput(_ responder: NSResponder?) -> Bool {
        guard let responder else { return false }
        return responder is NSTextInputClient || responder is NSTextField || responder is NSComboBox
    }
}

/// A zero-size, reader-scoped event host. No application menu or global monitor is installed.
/// Use on the PDF canvas; conservative text-input rejection also excludes web text editors.
struct ReaderNavigationShortcuts: NSViewRepresentable {
    let enabled: Bool
    let canvas: () -> NSView?
    let perform: (ReaderNavigationCommand) -> Bool
    func makeNSView(context: Context) -> ReaderNavigationShortcutHost { ReaderNavigationShortcutHost() }
    func updateNSView(_ host: ReaderNavigationShortcutHost, context: Context) {
        host.enabled = enabled; host.canvas = canvas; host.perform = perform
    }
    static func dismantleNSView(_ host: ReaderNavigationShortcutHost, coordinator: ()) { host.stop() }
}

@MainActor final class ReaderNavigationShortcutHost: NSView {
    var enabled = false
    var canvas: (() -> NSView?)?
    var perform: ((ReaderNavigationCommand) -> Bool)?
    private var monitor: Any?
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow(); stop()
        guard window != nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, window.isKeyWindow, event.window === window,
                  let canvas = self.canvas?(), canvas.window === window,
                  let responder = window.firstResponder as? NSView else { return event }
            let focused = responder === canvas || responder.isDescendant(of: canvas)
            guard let command = ReaderNavigationShortcutPolicy.command(keyCode: event.keyCode, modifiers: event.modifierFlags,
                isRepeat: event.isARepeat, enabled: self.enabled, canvasFocused: focused,
                textInput: ReaderNavigationShortcutPolicy.isTextInput(responder), hasSheet: window.attachedSheet != nil),
                self.perform?(command) == true else { return event }
            return nil
        }
    }
    func stop() { if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil }
    // SwiftUI dismantle and window detachment both remove the monitor on the main actor.
}
#endif
