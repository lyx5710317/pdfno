// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import SwiftUI
import Testing
@testable import PDFnoUI

@MainActor
struct NativeNoteBodyUpdateTests {
    private func finishQueuedUpdates() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
    }

    @Test func SavingBlocksEditsBeforeDeferredNativeDisable() async throws {
        var text = "Original draft 日本語🌸"
        let binding = Binding(get: { text }, set: { text = $0 })
        let coordinator = NativeNoteBodyInput.Coordinator(text: binding)
        let scroll = NativeNoteBodyInput.makeEditor(coordinator: coordinator, identifier: "original-saving-editor", enabled: true)
        let view = try #require(scroll.documentView as? NSTextView)
        coordinator.update(view, text: binding, enabled: false)
        #expect(view.isEditable) // No AppKit setter runs during the SwiftUI update.
        view.insertText("Rejected", replacementRange: NSRange(location: 0, length: view.string.utf16.count))
        #expect(view.string == text && text == "Original draft 日本語🌸")
        await finishQueuedUpdates()
        #expect(!view.isEditable && view.string == text)
        withExtendedLifetime(scroll) {}
    }

    @Test func CoalescedUpdatesUseLatestBindingAndPreserveUTF16Selection() async throws {
        var first = "Original 日本語🌸", latest = "短🌸"
        let firstBinding = Binding(get: { first }, set: { first = $0 })
        let latestBinding = Binding(get: { latest }, set: { latest = $0 })
        let coordinator = NativeNoteBodyInput.Coordinator(text: firstBinding)
        let scroll = NativeNoteBodyInput.makeEditor(coordinator: coordinator, identifier: "original-coalesced-editor", enabled: true)
        let view = try #require(scroll.documentView as? NSTextView)
        view.setSelectedRange(NSRange(location: 9, length: 3))
        first = "Stale queued body"
        coordinator.update(view, text: firstBinding, enabled: false)
        coordinator.update(view, text: latestBinding, enabled: true)
        #expect(view.string == "Original 日本語🌸" && view.isEditable)
        await finishQueuedUpdates()
        #expect(view.string == latest && view.isEditable)
        #expect(view.selectedRange() == NSRange(location: latest.utf16.count, length: 0))
        view.insertText("新", replacementRange: NSRange(location: 0, length: latest.utf16.count))
        #expect(latest == "新" && first == "Stale queued body")
        withExtendedLifetime(scroll) {}
    }

    @Test func RemovedEditorRejectsQueuedWorkWithoutAffectingReplacement() async throws {
        var text = "Original old body"
        let binding = Binding(get: { text }, set: { text = $0 })
        let coordinator = NativeNoteBodyInput.Coordinator(text: binding)
        let oldScroll = NativeNoteBodyInput.makeEditor(coordinator: coordinator, identifier: "original-old-editor", enabled: true)
        let oldView = try #require(oldScroll.documentView as? NSTextView)
        text = "Original replacement body"
        coordinator.update(oldView, text: binding, enabled: false)
        NativeNoteBodyInput.dismantleNSView(oldScroll, coordinator: coordinator)
        let newScroll = NativeNoteBodyInput.makeEditor(coordinator: coordinator, identifier: "original-new-editor", enabled: true)
        let newView = try #require(newScroll.documentView as? NSTextView)
        text = "Original latest replacement"
        coordinator.update(newView, text: binding, enabled: false)
        await finishQueuedUpdates()
        #expect(oldView.string == "Original old body" && oldView.isEditable && oldView.delegate == nil)
        #expect(newView.string == text && !newView.isEditable)
        withExtendedLifetime((oldScroll, newScroll)) {}
    }
}
#endif
