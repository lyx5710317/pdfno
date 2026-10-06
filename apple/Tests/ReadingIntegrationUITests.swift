// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest

/// Original fixtures and UUID stores only. Local execution additionally requires
/// the distinct application ID supplied by the isolated project/test receipt.
final class ReadingIntegrationUITests: XCTestCase {
    @MainActor private func app() -> XCUIApplication {
        let app: XCUIApplication
        if let id = ProcessInfo.processInfo.environment["PDFNO_ISOLATED_UI_APPLICATION_ID"] {
            precondition(id.hasPrefix("org.pdfno.integration."))
            app = XCUIApplication(bundleIdentifier: id)
        } else { app = XCUIApplication() } // Dedicated CI/VM/OS-user only.
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launch(); app.activate()
        return app
    }
    @MainActor private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    @MainActor private func click(_ item: XCUIElement, editing: Bool = false) throws {
        let ready = expectation(for: NSPredicate { _, _ in item.exists && item.isEnabled && item.isHittable }, evaluatedWith: item)
        wait(for: [ready], timeout: 15)
        guard item.exists && item.isEnabled && item.isHittable else { throw NSError(domain: "OriginalUI", code: 1) }
        if editing { item.doubleClick() } else { item.click() }
    }
    @MainActor private func value(_ item: XCUIElement, contains text: String) {
        let ready = expectation(for: NSPredicate { _, _ in
            item.exists && (item.label + " " + (item.value as? String ?? "")).contains(text)
        }, evaluatedWith: item)
        wait(for: [ready], timeout: 20)
    }
    @MainActor private func category(_ name: String, id: String, in app: XCUIApplication) throws {
        let sidebar = element("settings-category-" + id, in: app)
        if sidebar.exists { try click(sidebar) }
        else {
            try click(element("settings-category-picker", in: app))
            try click(app.menuItems[name].firstMatch)
        }
    }
    @MainActor private func search(_ query: String, in app: XCUIApplication) throws {
        let navigation = element("reader-navigation", in: app)
        if navigation.value as? String != "已展开" { try click(navigation) }
        value(navigation, contains: "已展开")
        let input = element("search-input", in: app)
        // macOS List cells use a shared field editor; enter editing explicitly
        // and send keys to that active editor. The exact value proves the target.
        try click(input, editing: true)
        app.typeKey("a", modifierFlags: .command); app.typeText(query)
        XCTAssertEqual(input.value as? String, query)
        try click(element("search-submit", in: app))
        try click(element("search-result", in: app))
    }

    @MainActor func testMacPDFSearchTOCReturnAndTextInputProtection() throws {
        let app = app(); defer { app.terminate() }
        try click(element("open-sample", in: app))
        let position = element("page-position", in: app), back = element("reader-return-location", in: app)
        value(position, contains: "1 / 2")
        XCTAssertTrue(back.exists); XCTAssertFalse(back.isEnabled)
        try search("useful", in: app)
        value(position, contains: "2 / 2")
        try click(back); value(position, contains: "1 / 2")
        try click(element("reader-navigation", in: app))
        try click(app.buttons["A second page"].firstMatch)
        value(position, contains: "2 / 2")
        try click(back); value(position, contains: "1 / 2")
        try search("window", in: app)
        try click(element("reader-notes", in: app))
        let draft = element("note-input", in: app)
        try click(draft); draft.typeText("Original navigation draft")
        draft.typeKey(.rightArrow, modifierFlags: [.command, .option])
        value(position, contains: "1 / 2")
        XCTAssertEqual(draft.value as? String, "Original navigation draft")
        try click(element("close-notes", in: app))
        try click(element("next-page", in: app)); value(position, contains: "2 / 2")
        try click(element("reader-notes", in: app))
        XCTAssertEqual(element("note-input", in: app).value as? String, "Original navigation draft")
    }

    @MainActor func testMacEPUBTOCAndCanonicalReturnUseActualRuntime() throws {
        let app = app(); defer { app.terminate() }
        try click(element("open-epub-sample", in: app))
        let position = element("epub-position", in: app), back = element("epub-return-location", in: app)
        value(position, contains: "第 1 章")
        XCTAssertTrue(back.exists); XCTAssertFalse(back.isEnabled)
        try click(element("epub-contents", in: app))
        try click(element("epub-chapter-1", in: app))
        value(position, contains: "第 2 章")
        try click(back); value(position, contains: "第 1 章")
        XCTAssertFalse(back.isEnabled)
        try click(element("epub-ai-tools", in: app))
        value(element("ai-tool-spine", in: app), contains: "可进入")
        XCTAssertFalse(element("ai-tool-page", in: app).isEnabled)
        try click(element("ai-tools-close", in: app))
        value(position, contains: "第 1 章")
    }

    @MainActor func testMacToolsRouteRequiresConsentAndManualSave() throws {
        let app = app(); defer { app.terminate() }
        try click(element("ai-settings", in: app))
        try click(element("ai-use-mock", in: app))
        try click(element("ai-settings-save", in: app))
        try click(element("open-sample", in: app)); try search("window", in: app)
        try click(element("reader-ai-tools", in: app))
        value(element("ai-tool-explain", in: app), contains: "可进入")
        try click(element("ai-tool-explain", in: app))
        let start = element("ai-start", in: app)
        XCTAssertTrue(element("ai-close", in: app).waitForExistence(timeout: 10))
        value(element("ai-source-quote", in: app), contains: "window")
        XCTAssertTrue(start.waitForExistence(timeout: 10)); XCTAssertFalse(start.isEnabled)
        XCTAssertFalse(element("ai-result", in: app).exists)
        try click(element("ai-scope-consent", in: app)); try click(start)
        XCTAssertTrue(element("ai-result", in: app).waitForExistence(timeout: 15))
        value(element("ai-result-save-state", in: app), contains: "尚未保存")
        try click(element("ai-save-note", in: app))
        value(element("ai-result-save-state", in: app), contains: "已保存")
    }

    @MainActor func testMacSettingsCategoriesPreserveUnappliedConfiguration() throws {
        let app = app(); defer { app.terminate() }
        try click(element("ai-settings", in: app))
        try click(element("ai-use-deepseek", in: app))
        let label = element("ai-provider-label", in: app)
        try click(label); label.typeKey("a", modifierFlags: .command); label.typeText("Original pending label")
        try category("AI工具", id: "tools", in: app)
        XCTAssertFalse(element("ai-settings-save", in: app).isEnabled)
        XCTAssertTrue(element("planned-semantic", in: app).exists)
        try category("AI", id: "ai", in: app)
        XCTAssertEqual(element("ai-provider-label", in: app).value as? String, "Original pending label")
        try click(element("ai-settings-cancel", in: app))
        try click(element("ai-settings", in: app))
        XCTAssertNotEqual(element("ai-provider-label", in: app).value as? String, "Original pending label")
    }
}
#endif
