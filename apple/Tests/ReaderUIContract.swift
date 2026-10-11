// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import XCTest

/// Current public UI routes. All persistence reads are limited to the scenario's UUID store.
/// This driver never reads the pasteboard, creates selections through JavaScript, or writes app data.
@MainActor extension XCTestCase {
    func ui(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    func uiText(_ e: XCUIElement) -> String { (e.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? e.label }
    func uiWait(_ message: String, timeout: TimeInterval = 15, _ predicate: @escaping () -> Bool) throws {
        let check = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in predicate() }, object: nil)
        let result = XCTWaiter.wait(for: [check], timeout: timeout)
        XCTAssertEqual(result, .completed, message)
        guard result == .completed else { throw NSError(domain: "OriginalReaderContract", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    }
    func uiClick(_ e: XCUIElement) throws {
        try uiWait("Control must be visible and enabled: " + e.identifier) { e.exists && e.isEnabled && e.isHittable }
        e.click()
    }
    func uiContains(_ e: XCUIElement, _ value: String) throws {
        try uiWait("Expected text: " + value) { e.exists && self.uiText(e).contains(value) }
    }
    func uiPaste(_ text: String, _ e: XCUIElement) throws {
        try uiClick(e); e.typeKey("a", modifierFlags: .command)
        NSPasteboard.general.clearContents(); XCTAssertTrue(NSPasteboard.general.setString(text, forType: .string))
        if text.isEmpty { e.typeKey(.delete, modifierFlags: []) } else { e.typeKey("v", modifierFlags: .command) }
        try uiWait("Original fixture input must match exactly") { e.value as? String == text }
        XCTAssertEqual(e.value as? String, text)
    }
    func uiSyntheticCredential(_ text: String, _ e: XCUIElement) throws {
        // Only test-authored credentials; secure fields intentionally expose no plaintext value.
        try uiClick(e); e.typeKey("a", modifierFlags: .command)
        NSPasteboard.general.clearContents(); XCTAssertTrue(NSPasteboard.general.setString(text, forType: .string))
        e.typeKey("v", modifierFlags: .command)
    }
    func uiPanel(_ id: String, open: Bool, _ app: XCUIApplication) throws {
        let control = ui(id, app)
        try uiWait("Reader panel toggle") { control.exists && control.isEnabled }
        if (control.value as? String == "已展开") != open { try uiClick(control) }
        try uiWait("Panel state: " + id) { (control.value as? String == "已展开") == open }
    }
    func uiExample(_ id: String, _ app: XCUIApplication) throws {
        try uiClick(ui("workspace-help", app)); try uiClick(ui(id, app))
    }
    func uiSettings(_ app: XCUIApplication) throws {
        try uiClick(ui("ai-settings", app))
        let category = ui("settings-category-ai", app)
        if category.exists { try uiClick(category) }
        else { try uiClick(ui("settings-category-picker", app)); try uiClick(app.menuItems["AI"].firstMatch) }
    }
    func uiProvider(_ title: String, _ app: XCUIApplication, key: String? = nil) throws {
        try uiClick(ui("ai-provider-mode", app)); try uiClick(app.menuItems[title].firstMatch)
        if let key { try uiSyntheticCredential(key, ui("ai-session-key", app)) }
        try uiClick(ui("ai-settings-save", app))
        try uiContains(ui("ai-connection-status", app), "已应用")
    }
    func uiConfigureMock(_ app: XCUIApplication) throws {
        try uiSettings(app); try uiProvider("本地示例", app); try uiClick(ui("settings-return", app))
    }
    func uiLegacyAI(_ app: XCUIApplication, task: String = "translate") throws {
        if !ui("ai-tools-directory", app).exists {
            try uiClick(ui("document-more", app)); try uiClick(app.menuItems.matching(identifier: "document-reading-tools").firstMatch)
        }
        try uiClick(ui("ai-tool-" + task, app))
        XCTAssertTrue(ui("ai-scope-consent", app).waitForExistence(timeout: 10))
    }
    func uiReveal(_ e: XCUIElement, scroll id: String, _ app: XCUIApplication) throws {
        let scroll = ui(id, app)
        XCTAssertTrue(scroll.waitForExistence(timeout: 10)); XCTAssertTrue(e.waitForExistence(timeout: 10))
        for _ in 0..<16 {
            let viewport = scroll.frame.insetBy(dx: 3, dy: 6)
            if viewport.contains(e.frame) && e.isHittable { return }
            scroll.scroll(byDeltaX: 0, deltaY: e.frame.minY < viewport.minY ? 240 : -240)
        }
        XCTAssertTrue(scroll.frame.contains(e.frame)); XCTAssertTrue(e.isHittable)
    }
    func uiStartLegacyAI(_ app: XCUIApplication) throws {
        let consent = ui("ai-scope-consent", app), start = ui("ai-start", app)
        XCTAssertFalse(start.isEnabled)
        try uiReveal(consent, scroll: "ai-notes-list", app); try uiClick(consent)
        try uiReveal(start, scroll: "ai-notes-list", app); try uiClick(start)
    }
    func uiCloseLegacyAI(_ app: XCUIApplication) throws {
        try uiClick(ui("ai-close", app))
        try uiCloseToolDirectory(app)
    }
    func uiCloseToolDirectory(_ app: XCUIApplication) throws {
        try uiWait("Inner AI sheet finishes returning to source") { ["ai-close", "japanese-learning-close", "english-learning-close"].allSatisfy { !self.ui($0, app).exists } }
        try uiWait("Outer reading tools remain available") { self.ui("ai-tools-close", app).exists || self.ui("workspace-tool-return", app).exists }
        if ui("ai-tools-close", app).exists { try uiClick(ui("ai-tools-close", app)) }
        else if ui("workspace-tool-return", app).exists { try uiClick(ui("workspace-tool-return", app)) }
        try uiWait("Reading tools directory closes") { !self.ui("ai-tools-directory", app).exists }
    }
    func uiSaveLegacyAI(_ body: String, _ app: XCUIApplication) throws {
        let input = ui("ai-user-note", app); try uiReveal(input, scroll: "ai-notes-list", app); try uiPaste(body, input)
        let save = ui("ai-save-note", app); try uiReveal(save, scroll: "ai-notes-list", app); try uiClick(save)
        try uiContains(ui("ai-result-save-state", app), "已添加到当前文档笔记")
        XCTAssertFalse(save.isEnabled)
    }
    func uiReturnLegacyAI(_ app: XCUIApplication) throws {
        let source = ui("ai-result-source", app); try uiReveal(source, scroll: "ai-notes-list", app); try uiClick(source)
        try uiCloseToolDirectory(app)
    }
    func uiStore(_ app: XCUIApplication) throws -> URL {
        let token = try XCTUnwrap(app.launchEnvironment["PDFNO_UI_TEST_SESSION"])
        let uuid = try XCTUnwrap(UUID(uuidString: token))
        return URL(fileURLWithPath: "/tmp/PDFno-UITests-" + uuid.uuidString, isDirectory: true)
    }
    func uiManifest(_ name: String, _ app: XCUIApplication) throws -> [String: Any] {
        let root = try uiStore(app)
        let state = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(name))) as? [String: Any])
        XCTAssertEqual(state["schemaVersion"] as? Int, 1); return state
    }
    func uiAnnotations(_ app: XCUIApplication) throws -> [[String: Any]] {
        let root = try uiStore(app)
        if !FileManager.default.fileExists(atPath: root.appendingPathComponent("annotations-v1.json").path) { return [] }
        return try XCTUnwrap(uiManifest("annotations-v1.json", app)["notes"] as? [[String: Any]])
    }
    func uiOnlyAnnotation(_ app: XCUIApplication) throws -> [String: Any] {
        let records = try uiAnnotations(app); XCTAssertEqual(records.count, 1); return try XCTUnwrap(records.first)
    }
    func uiAnchorPayload(_ record: [String: Any]) throws -> [String: Any] {
        let anchor = try XCTUnwrap(record["anchor"] as? [String: Any]); XCTAssertEqual(anchor.count, 1)
        return try XCTUnwrap((anchor.values.first as? [String: Any])?["_0"] as? [String: Any])
    }
    func uiAnnotationRows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'annotation-row-'"))
    }
    func uiBeginNote(_ app: XCUIApplication) throws {
        try uiClick(ui("selection-annotation-note", app))
        XCTAssertTrue(ui("annotation-comment-input", app).waitForExistence(timeout: 10))
    }
    func uiSaveNote(_ app: XCUIApplication) throws {
        try uiClick(ui("annotation-editor-save", app))
        try uiWait("Explicit note commit finishes") { !self.ui("annotation-comment-input", app).exists }
    }
    func uiEditNote(_ app: XCUIApplication) throws {
        let row = uiAnnotationRows(app).firstMatch
        try uiWait("Saved annotation row") { row.exists && row.isHittable }
        row.doubleClick(); XCTAssertTrue(ui("annotation-comment-input", app).waitForExistence(timeout: 10))
    }
    func uiResumeDraft(_ app: XCUIApplication) throws {
        let draft = ui("annotation-resume-draft", app)
        if draft.exists { try uiClick(draft) } else { try uiEditNote(app) }
        XCTAssertTrue(ui("annotation-comment-input", app).waitForExistence(timeout: 10))
    }
    func uiReturnNote(_ app: XCUIApplication) throws {
        try uiClick(uiAnnotationRows(app).firstMatch)
        try uiContains(ui("annotation-status", app), "已定位原文")
    }
    func uiLegacySavedNotes(_ prefix: String, _ app: XCUIApplication) throws {
        try uiPanel(prefix + "-notes", open: true, app)
        try uiClick(ui("annotation-legacy-records", app))
        XCTAssertTrue(ui("legacy-notes-close", app).waitForExistence(timeout: 10))
    }
    func uiPDFShortcut(_ key: XCUIKeyboardKey, _ app: XCUIApplication) throws {
        // The current Mac reader exposes physical-page navigation as canvas shortcuts.
        let canvas = ui("pdf-canvas", app)
        try uiClick(canvas)
        canvas.typeKey(key, modifierFlags: [.command, .option])
    }
    func uiComicOption(_ title: String, picker: String, _ app: XCUIApplication) throws {
        try uiClick(ui("comic-settings", app))
        let option = app.menuItems[title].firstMatch
        if !option.waitForExistence(timeout: 1) || !option.isHittable {
            try uiClick(app.menuItems[picker].firstMatch)
        }
        try uiClick(option)
        try uiContains(ui("comic-settings", app), title)
    }
    func uiFileControl(_ app: XCUIApplication, type: XCUIElement.ElementType, identifier: String, requireEnabled: Bool = true) throws -> XCUIElement {
        var found: XCUIElement?
        try uiWait("Physical native file control: " + identifier, timeout: 12) {
            let windows = app.windows.allElementsBoundByAccessibilityElement + app.sheets.allElementsBoundByAccessibilityElement
            for window in windows where window.exists && !window.frame.isEmpty && !window.frame.isInfinite {
                found = window.descendants(matching: type).matching(identifier: identifier).allElementsBoundByAccessibilityElement.first { control in
                    guard control.exists && (!requireEnabled || (control.isEnabled && control.isHittable)) else { return false }
                    let frame = control.frame
                    return !frame.isEmpty && !frame.isInfinite && frame.minX.isFinite && frame.minY.isFinite && window.frame.intersects(frame)
                }
                if found != nil { break }
            }
            return found != nil
        }
        return try XCTUnwrap(found)
    }
    func uiSelectWeb(_ prefix: String, _ app: XCUIApplication) throws {
        var text: XCUIElement?
        try uiWait("Visible original WebKit paragraph", timeout: 25) {
            let web = app.webViews.firstMatch, bounds = web.frame
            let candidates = web.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", prefix, prefix)).allElementsBoundByIndex
            text = candidates.first { $0.exists && $0.isHittable && !$0.frame.isEmpty && bounds.intersects($0.frame) }
            return text != nil
        }
        let paragraph = try XCTUnwrap(text)
        paragraph.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: min(12, paragraph.frame.width / 2), dy: min(12, paragraph.frame.height / 2))).doubleClick()
        XCTAssertTrue(ui("selection-annotation-note", app).waitForExistence(timeout: 10))
    }
    func uiSelectPDFWindow(_ app: XCUIApplication) throws {
        try uiPanel("reader-navigation", open: false, app)
        var text: XCUIElement?
        let phrase = "Reading opens a small window onto a wider world."
        try uiWait("Original PDFKit accessible line") {
            text = app.staticTexts.allElementsBoundByIndex.first { self.uiText($0) == phrase && $0.isHittable }
            return text != nil
        }
        let line = try XCTUnwrap(text), font = try XCTUnwrap(NSFont(name: "Helvetica", size: 14))
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let prefix = ("Reading opens a small " as NSString).size(withAttributes: attrs).width
        let word = ("window" as NSString).size(withAttributes: attrs).width
        let whole = (phrase as NSString).size(withAttributes: attrs).width
        line.coordinate(withNormalizedOffset: CGVector(dx: (prefix + word / 2) / whole, dy: 0.5)).doubleClick()
        XCTAssertTrue(ui("selection-annotation-note", app).waitForExistence(timeout: 10))
    }
}
#endif
