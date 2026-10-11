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
    func uiLanguageMenuAction(_ language: String, review: Bool, _ app: XCUIApplication) throws {
        XCTAssertTrue(["japanese", "english"].contains(language))
        let title = review ? (language == "japanese" ? "假名与语法审阅" : "结构与语法审阅") : "对话"
        let category = app.menuItems.matching(identifier: "selection-ai-" + language).firstMatch
        try uiWait("Visible public language category") { category.exists && category.isEnabled && category.isHittable }
        print("Original language category before-hover id=\(category.identifier) frame=\(category.frame) hittable=\(category.isHittable)")
        // Use the explicit native hover from the existing submenu driver.
        // The leaf must then be observed; there is no extra click or key fallback.
        category.hover()
        // AppKit exposes SwiftUI submenu actions as menuAction:, retaining labels
        // (the existing native-menu driver fix in 3792279). Only the open submenu
        // may supply this action; never choose a hidden same-title language action.
        var matches: [XCUIElement] = []
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            matches = app.menuItems.matching(NSPredicate(format: "label == %@", title))
                .allElementsBoundByAccessibilityElement.filter { $0.exists && $0.isEnabled && $0.isHittable }
            return matches.count == 1
        }, object: app)
        let outcome = XCTWaiter.wait(for: [ready], timeout: 12)
        // Record bounded command-only AX evidence before any failing assertion:
        // continueAfterFailure=false can terminate the test at XCTAssert itself.
        if outcome != .completed {
            let exists = category.exists
            print("Original language category after-hover exists=\(exists)")
            if exists {
                print("Original language category frame=\(category.frame) enabled=\(category.isEnabled) hittable=\(category.isHittable)")
                for node in category.descendants(matching: .any).allElementsBoundByAccessibilityElement.prefix(12) {
                    print("Original language subtree role=\(node.elementType.rawValue) id=\(node.identifier) label=\(node.label) frame=\(node.frame)")
                }
            }
            for known in ["对话", "假名与语法审阅", "结构与语法审阅"] {
                let items = app.menuItems.matching(NSPredicate(format: "label == %@", known)).allElementsBoundByAccessibilityElement
                print("Original language menu title=\(known) matches=\(items.count) visible=\(items.filter { $0.exists && $0.isHittable }.count)")
            }
        }
        XCTAssertEqual(outcome, .completed, "One visible public language action: " + title)
        guard outcome == .completed else { throw NSError(domain: "OriginalReaderContract", code: 2) }
        XCTAssertEqual(matches.count, 1)
        try uiClick(try XCTUnwrap(matches.first))
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
        if (control.value as? String == "已展开") != open {
            try uiClick(control)
        }
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
    func uiEnableLanguage(_ language: String, _ app: XCUIApplication) throws {
        XCTAssertTrue(["japanese", "english"].contains(language))
        try uiSettings(app)
        let category = ui("settings-category-aiTools", app)
        if category.exists { try uiClick(category) }
        else { try uiClick(ui("settings-category-picker", app)); try uiClick(app.menuItems["AI工具"].firstMatch) }
        let toggle = ui("settings-" + language + "-learning", app)
        try uiWait("Public language preference") { toggle.exists && toggle.isEnabled }
        if toggle.value as? String != "1" { try uiClick(toggle) }
        XCTAssertEqual(toggle.value as? String, "1")
        try uiClick(ui("settings-return", app))
    }
    func uiCloseLanguageReview(_ app: XCUIApplication) throws {
        try uiWait("Structured review returns to the current reader") {
            !self.ui("japanese-learning-close", app).exists && !self.ui("english-learning-close", app).exists
                && self.ui("document-more", app).exists && self.ui("document-more", app).isEnabled
        }
        XCTAssertFalse(ui("ai-tools-directory", app).exists)
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
        // The saved row's primary action returns to its source. Edit through
        // the visible native context menu, as offered by the current reader.
        row.rightClick()
        let edit = app.menuItems["编辑批注"].firstMatch
        try uiClick(edit)
        XCTAssertTrue(ui("annotation-comment-input", app).waitForExistence(timeout: 10))
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
        // PDFKit omits its PDFView identifier from AX. Focus a real, visible fixture
        // text line instead; the physical key event still goes through the reader policy.
        let originals = ["Reading opens a small window onto a wider world.",
                         "A useful note stays connected to the words that inspired it."]
        var line: XCUIElement?
        try uiWait("Visible original PDFKit page text for canvas focus") {
            line = app.staticTexts.allElementsBoundByIndex.first { originals.contains(self.uiText($0)) && $0.isHittable }
            return line != nil
        }
        let target = try XCTUnwrap(line), window = app.windows.firstMatch
        try uiWait("Physical original PDFKit text inside the reader window") {
            guard target.exists, target.isHittable, window.exists else { return false }
            let frame = target.frame
            return !frame.isEmpty && !frame.isInfinite && frame.minX.isFinite && frame.minY.isFinite
                && frame.maxX.isFinite && frame.maxY.isFinite && window.frame.contains(frame)
        }
        // PDFKit static text does not expose button-like AXEnabled. A single real
        // click sets canvas focus; the original physical-page assertions follow.
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        app.typeKey(key, modifierFlags: [.command, .option])
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
            found = nil
            if type == .button && identifier == "OKButton" {
                // Resolve the native action before a deep containing query.
                // The latter can traverse the comic WebView while AppKit is
                // still presenting its panel. Inspect exact-ID candidates
                // and retain a physical frame inside the own window.
                let window = app.windows.firstMatch
                if window.exists {
                    let panelFrame = window.frame
                    if !panelFrame.isEmpty, !panelFrame.isInfinite,
                       [panelFrame.minX, panelFrame.minY, panelFrame.maxX, panelFrame.maxY].allSatisfy(\.isFinite) {
                        for control in app.buttons.matching(identifier: identifier).allElementsBoundByIndex {
                            guard control.exists && (!requireEnabled || (control.isEnabled && control.isHittable)) else { continue }
                            let frame = control.frame
                            guard !frame.isEmpty, !frame.isInfinite,
                                  [frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy(\.isFinite),
                                  panelFrame.intersects(frame) else { continue }
                            found = control; break
                        }
                        return found != nil
                    }
                }
            }
            // Query the real modal root before the document window. Queries
            // refresh after a panel transition; bound AX tokens can go stale.
            let goTo = app.sheets.matching(identifier: "GoToWindow").firstMatch
            let roots = (identifier == "PathTextField" ? [goTo] : [])
                + [app.sheets, app.dialogs, app.windows].map { $0.containing(type, identifier: identifier).firstMatch }
            for panel in roots {
                guard panel.exists else { continue }
                let control = panel.descendants(matching: type).matching(identifier: identifier).firstMatch
                guard control.exists && (!requireEnabled || (control.isEnabled && control.isHittable)) else { continue }
                let panelFrame = panel.frame, frame = control.frame
                guard !panelFrame.isEmpty, !panelFrame.isInfinite,
                      !frame.isEmpty, !frame.isInfinite,
                      [panelFrame.minX, panelFrame.minY, panelFrame.maxX, panelFrame.maxY,
                       frame.minX, frame.minY, frame.maxX, frame.maxY].allSatisfy(\.isFinite),
                      panelFrame.intersects(frame) else { continue }
                found = control; break
            }
            return found != nil
        }
        return try XCTUnwrap(found)
    }
    func uiCaptureOwnWindow(_ name: String, _ app: XCUIApplication) throws {
        guard let token = ProcessInfo.processInfo.environment["PDFNO_A_QA_SHOT_TOKEN"] else { return }
        XCTAssertNotNil(UUID(uuidString: token))
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PDFno-A-WindowShots-" + token)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let path = root.appendingPathComponent(name + ".png")
        try app.windows.firstMatch.screenshot().pngRepresentation.write(to: path)
        let record = try JSONSerialization.data(withJSONObject: ["name": name, "path": path.path], options: [.sortedKeys])
        print("PDFNO_A_WINDOW_SHOT " + String(decoding: record, as: UTF8.self))
    }
    func uiEPUBSourceRoot(_ app: XCUIApplication) -> XCUIElement? {
        // The production WKWebView publishes the source viewport identifier.
        // Resolve the visible WebKit area within this test application's window.
        let ownWindow = app.windows.firstMatch
        guard ownWindow.exists else { return nil }
        let identified = ownWindow.descendants(matching: .any).matching(identifier: "epub-content").firstMatch
        let hostBounds = identified.exists ? identified.frame : ownWindow.frame
        // The passing reader-chrome scenario selects a real WebView. Keep that
        // selector inside this fixture window and the identified source viewport;
        // whether the native host exposes the same AX subtree is still unproven.
        return ownWindow.descendants(matching: .webView).allElementsBoundByAccessibilityElement.first { web in
            guard web.exists else { return false }
            let bounds = web.frame
            return !bounds.isEmpty && !bounds.isNull && !bounds.isInfinite
                && bounds.minX.isFinite && bounds.minY.isFinite
                && ownWindow.frame.intersects(bounds) && hostBounds.intersects(bounds)
        }
    }
    func uiVisibleEPUBParagraph(_ prefix: String, in web: XCUIElement) -> XCUIElement? {
        let bounds = web.frame
        @MainActor func visible(_ candidate: XCUIElement) -> Bool {
            guard candidate.exists else { return false }
            let frame = candidate.frame
            return !frame.isEmpty && !frame.isNull && !frame.isInfinite
                && frame.minX.isFinite && frame.minY.isFinite
                && bounds.intersects(frame) && candidate.isHittable
        }
        let named = web.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix))
        for candidate in named.allElementsBoundByIndex where visible(candidate) { return candidate }
        // Read the raw value with the passing reader-chrome selector, stopping
        // at the first visible match. Eager filtering reads every paragraph and
        // ruby token before returning a match near the beginning of the fixture.
        for candidate in web.staticTexts.allElementsBoundByIndex {
            if uiText(candidate).hasPrefix(prefix) && visible(candidate) { return candidate }
        }
        return nil
    }
    func uiAuditEPUBSource(_ app: XCUIApplication, prefix: String, root: XCUIElement?, candidates: [XCUIElement]) {
        // Offline fixture window only. Read AX state; do not create a selection
        // or change the document. Limit the retained diagnostic to one snapshot.
        let env = ProcessInfo.processInfo.environment
        guard env["PDFNO_A_QA_EXPECTED_BUNDLE"]?.hasPrefix("org.pdfno.integration.professionala20261007.qa") == true,
              env["PDFNO_UI_TEST_DEEPSEEK"] == "offline",
              UUID(uuidString: app.launchEnvironment["PDFNO_UI_TEST_SESSION"] ?? env["PDFNO_UI_TEST_SESSION"] ?? "") != nil else { return }
        let ownWindow = app.windows.firstMatch
        guard ownWindow.exists, ownWindow.identifier == "library" else { return }
        let webViews = ownWindow.descendants(matching: .webView).allElementsBoundByIndex
        var observed = candidates
        if observed.isEmpty, let root,
           let value = root.staticTexts.allElementsBoundByIndex.first(where: { self.uiText($0).hasPrefix(prefix) }) { observed = [value] }
        let attributes = observed.prefix(4).map { candidate in
            "type=\(candidate.elementType.rawValue) text=\(String(self.uiText(candidate).prefix(160))) frame=\(NSStringFromRect(candidate.frame)) hittable=\(candidate.isHittable)"
        }.joined(separator: "\n")
        let summary = "prefix=\(prefix) candidates=\(observed.count) webViews=\(webViews.count) root=\(root.map { String($0.elementType.rawValue) + " " + $0.identifier + " " + NSStringFromRect($0.frame) } ?? "absent")\n" + attributes
        print("PDFNO_EPUB_AX_DIAGNOSTIC " + summary)
        // Keep primitive source attributes and this one owned window. A full
        // synchronous debugDescription can consume the unchanged wait budget.
        let attachment = XCTAttachment(string: summary + "\nwindow=" + NSStringFromRect(ownWindow.frame))
        attachment.name = "Original offline EPUB source AX state"
        attachment.lifetime = .keepAlways
        add(attachment)
        let visual = XCTAttachment(screenshot: ownWindow.screenshot())
        visual.name = "Original offline EPUB source window"
        visual.lifetime = .keepAlways
        add(visual)
    }
    func uiSelectWeb(_ prefix: String, _ app: XCUIApplication) throws {
        var text: XCUIElement?
        let diagnosticAt = Date().addingTimeInterval(12)
        var diagnosed = false
        try uiWait("Visible original WebKit paragraph", timeout: 25) {
            guard let web = self.uiEPUBSourceRoot(app) else {
                if !diagnosed && Date() >= diagnosticAt {
                    diagnosed = true
                    self.uiAuditEPUBSource(app, prefix: prefix, root: nil, candidates: [])
                }
                return false
            }
            if !diagnosed && ProcessInfo.processInfo.environment["PDFNO_UI_TEST_SOURCE_DIAGNOSTICS"] == "1" && web.staticTexts.count > 0 {
                diagnosed = true
                self.uiAuditEPUBSource(app, prefix: prefix, root: web, candidates: [])
            }
            text = self.uiVisibleEPUBParagraph(prefix, in: web)
            if text == nil && !diagnosed && Date() >= diagnosticAt {
                diagnosed = true
                self.uiAuditEPUBSource(app, prefix: prefix, root: web, candidates: [])
            }
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
