// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest
import AppKit

/// Original fixtures and UUID stores only. Local execution additionally requires
/// the distinct application ID supplied by the isolated project/test receipt.
final class ReadingIntegrationUITests: XCTestCase {
    // Navigation driver only: existing behavior assertions remain in the methods.
    @MainActor private func navigateWorkspace(_ id: String, in app: XCUIApplication) {
        #if os(macOS)
        func target(_ name: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: name).firstMatch }
        // The requested list route must be selected explicitly now that home defaults to grid.
        // Inline cover editing retains the same thumbnail; do not navigate away to find it.
        if target("cover-select-image").exists && (id == "library-book" || id.hasPrefix("cover-image-")) { return }
        if target(id).exists {
            if id == "library-list-layout", target(id).value as? String != "已选中" { target(id).click() }
            return
        }
        let example = id.hasPrefix("open-") && id.contains("sample")
        let tools = ["ai-settings", "ai-tools-open", "bookno-preview-open", "document-conversion", "library-local-recovery"].contains(id)
        if example || tools {
            app.typeKey(.escape, modifierFlags: [])
            let launcher = target(example ? "workspace-help" : "workspace-tools")
            XCTAssertTrue(launcher.waitForExistence(timeout: 15)); launcher.click()
        } else {
            if target("workspace-back-library").exists { target("workspace-back-library").click() }
            XCTAssertTrue(target("professional-library-workspace").waitForExistence(timeout: 15))
            if id.hasPrefix("library-") || id.hasPrefix("cover-image-") {
                if !target(id).waitForExistence(timeout: 2) {
                    if target("library-category-picker").exists {
                        target("library-category-picker").click()
                        let category = app.menuItems["示例文档"].firstMatch
                        XCTAssertTrue(category.waitForExistence(timeout: 10))
                        category.click()
                    } else if target("library-category-examples").exists {
                        target("library-category-examples").click()
                    }
                }
            }
        }
        #endif
    }

    @MainActor private func app(paragraphScenario: String? = nil) -> XCUIApplication {
        let app: XCUIApplication
        if let id = ProcessInfo.processInfo.environment["PDFNO_ISOLATED_UI_APPLICATION_ID"] {
            precondition(id.hasPrefix("org.pdfno.integration."))
            app = XCUIApplication(bundleIdentifier: id)
        } else { app = XCUIApplication() } // Dedicated CI/VM/OS-user only.
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        if let paragraphScenario { app.launchEnvironment["PDFNO_UI_TEST_PARAGRAPH_RESPONSE"] = paragraphScenario }
        app.launch(); app.activate()
        return app
    }
    @MainActor private func element(_ id: String, in app: XCUIApplication) -> XCUIElement {
        if ["reader-ai-tools", "epub-ai-tools"].contains(id) {
            let menu = app.descendants(matching: .any).matching(identifier: "document-more").firstMatch
            if menu.exists { menu.click(); return app.menuItems.matching(identifier: "document-reading-tools").firstMatch }
        }
        return app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    @MainActor private func click(_ item: XCUIElement) throws {
        let ready = expectation(for: NSPredicate { _, _ in item.exists && item.isEnabled && item.isHittable }, evaluatedWith: item)
        wait(for: [ready], timeout: 15)
        guard item.exists && item.isEnabled && item.isHittable else { throw NSError(domain: "OriginalUI", code: 1) }
        item.click()
    }
    @MainActor private func value(_ item: XCUIElement, contains text: String) {
        let ready = expectation(for: NSPredicate { _, _ in
            item.exists && (item.label + " " + (item.value as? String ?? "")).contains(text)
        }, evaluatedWith: item)
        wait(for: [ready], timeout: 20)
    }
    @MainActor private func category(_ name: String, id: String, in app: XCUIApplication) throws {
        // Planning information moved from the old AI-tools category to About.
        // The original configuration/source assertions still run unchanged.
        let currentID = id == "tools" && name == "AI工具" ? "about" : id
        let currentName = currentID == "about" ? "关于" : name
        let sidebar = element("settings-category-" + currentID, in: app)
        if sidebar.exists { try click(sidebar) }
        else {
            try click(element("settings-category-picker", in: app))
            try click(app.menuItems[currentName].firstMatch)
        }
    }
    @MainActor private func search(_ query: String, in app: XCUIApplication) throws {
        let navigation = element("reader-navigation", in: app)
        if navigation.value as? String != "已展开" { try click(navigation) }
        value(navigation, contains: "已展开")
        let input = element("search-input", in: app)
        try paragraphPaste(query, into: input, replacing: true)
        XCTAssertEqual(input.value as? String, query)
        try click(element("search-submit", in: app))
        try click(element("search-result", in: app))
    }

    @MainActor func testMacPDFSearchTOCReturnAndTextInputProtection() throws {
        let app = app(); defer { app.terminate() }
        navigateWorkspace("open-sample", in: app)
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
        try paragraphPaste("Original navigation draft", into: draft)
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
        navigateWorkspace("open-epub-sample", in: app)
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
        navigateWorkspace("ai-settings", in: app)
        try click(element("ai-settings", in: app))
        try click(element("ai-use-mock", in: app))
        try click(element("ai-settings-save", in: app))
        navigateWorkspace("open-sample", in: app)
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
        navigateWorkspace("ai-settings", in: app)
        try click(element("ai-settings", in: app))
        try click(element("ai-use-deepseek", in: app))
        let label = element("ai-provider-label", in: app)
        try paragraphPaste("Original pending label", into: label, replacing: true)
        try category("AI工具", id: "tools", in: app)
        XCTAssertFalse(element("ai-settings-save", in: app).exists && element("ai-settings-save", in: app).isEnabled)
        XCTAssertTrue(element("planned-semantic", in: app).exists)
        try category("AI", id: "ai", in: app)
        XCTAssertEqual(element("ai-provider-label", in: app).value as? String, "Original pending label")
        try click(element("ai-settings-cancel", in: app))
        navigateWorkspace("ai-settings", in: app)
        try click(element("ai-settings", in: app))
        XCTAssertNotEqual(element("ai-provider-label", in: app).value as? String, "Original pending label")
    }

    @MainActor private func paragraphClick(_ target: XCUIElement, in app: XCUIApplication) throws {
        XCTAssertTrue(target.waitForExistence(timeout: 10))
        let scroll = app.scrollViews["ai-notes-list"].firstMatch
        if scroll.exists {
            for _ in 0..<12 {
                let viewport = scroll.frame.insetBy(dx: 4, dy: 8)
                if target.isHittable && viewport.contains(target.frame) { break }
                if target.frame.minY < viewport.minY { scroll.scroll(byDeltaX: 0, deltaY: 240) }
                else { scroll.scroll(byDeltaX: 0, deltaY: -240) }
            }
        }
        try click(target)
    }
    @MainActor private func paragraphPaste(_ text: String, into input: XCUIElement, replacing: Bool = false) throws {
        try click(input)
        if replacing { input.typeKey("a", modifierFlags: .command) }
        // Match the original NativeUITests input path: typeText can leave a
        // user-selected IME candidate window open even when AX value is exact.
        // Write only synthetic fixture data; never read or back up the system clipboard.
        let board = NSPasteboard.general
        board.clearContents(); XCTAssertTrue(board.setString(text, forType: .string))
        input.typeKey("v", modifierFlags: .command)
    }
    @MainActor private func paragraphSearch(_ query: String, in app: XCUIApplication) throws {
        let navigation = element("reader-navigation", in: app)
        if navigation.value as? String != "已展开" { try click(navigation) }
        value(navigation, contains: "已展开")
        let input = element("search-input", in: app)
        try paragraphPaste(query, into: input, replacing: true)
        XCTAssertEqual(input.value as? String, query)
        try click(element("search-submit", in: app))
        try click(element("search-result", in: app))
    }
    @MainActor private func paragraphWebText(in app: XCUIApplication) throws -> XCUIElement {
        // Use the original native suite's WebKit label/value lookup. A real
        // text node may be exposed as Other or have its text only in AXValue.
        var found: XCUIElement?
        let ready = expectation(for: NSPredicate { _, _ in
            let web = app.webViews.firstMatch
            let labelMatch = web.descendants(matching: .any).matching(
                NSPredicate(format: "label BEGINSWITH %@", "window")
            ).firstMatch
            if labelMatch.exists { found = labelMatch; return true }
            found = web.staticTexts.allElementsBoundByIndex.first {
                guard let value = $0.value as? String else { return false }
                return value.hasPrefix("window")
            }
            return found != nil
        }, evaluatedWith: app)
        wait(for: [ready], timeout: 15)
        if found == nil { print("PDFno original paragraph EPUB accessibility: \(app.webViews.firstMatch.debugDescription)") }
        return try XCTUnwrap(found, "Actual WebKit original paragraph must be exposed for user selection")
    }
    @MainActor private func prepareParagraph(_ app: XCUIApplication, epub: Bool = false) throws {
        navigateWorkspace("ai-settings", in: app)
        try click(element("ai-settings", in: app)); try click(element("ai-use-deepseek", in: app))
        let key = element("ai-session-key", in: app); try paragraphPaste("synthetic-reading-ui-credential", into: key)
        try click(element("ai-settings-save", in: app))
        if epub {
            navigateWorkspace("open-epub-sample", in: app)
            try click(element("open-epub-sample", in: app)); value(element("epub-position", in: app), contains: "第 1 章")
            let text = try paragraphWebText(in: app)
            XCTAssertTrue(text.isHittable)
            text.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
            try click(element("epub-ai-tools", in: app))
        } else {
            navigateWorkspace("open-sample", in: app)
            try click(element("open-sample", in: app)); try paragraphSearch("window", in: app); try click(element("reader-ai-tools", in: app))
        }
        try click(element("ai-tool-explain", in: app))
        value(element("ai-source-quote", in: app), contains: "window")
        let source = element("ai-source-quote", in: app)
        XCTAssertEqual((source.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? source.label, "window")
        XCTAssertFalse(element("ai-start", in: app).isEnabled)
        value(element("ai-provider-status", in: app), contains: "接收方")
    }
    @MainActor private func sendParagraph(_ app: XCUIApplication) throws {
        try paragraphClick(element("ai-scope-consent", in: app), in: app); try paragraphClick(element("ai-start", in: app), in: app)
    }
    @MainActor func testMacParagraphTypedEvidenceConsentManualSaveAndSource() throws {
        let app = app(paragraphScenario: "typed"); defer { app.terminate() }
        try prepareParagraph(app)
        XCTAssertFalse(element("paragraph-result", in: app).exists)
        try sendParagraph(app)
        value(element("paragraph-kind-i1", in: app), contains: "释义")
        value(element("paragraph-kind-i2", in: app), contains: "术语")
        value(element("paragraph-kind-i3", in: app), contains: "模型推断 · 待核对")
        value(element("paragraph-quote-c1", in: app), contains: "w")
        value(element("ai-result-save-state", in: app), contains: "尚未保存")
        let draft = element("ai-user-note", in: app); try paragraphClick(draft, in: app); try paragraphPaste("Original paragraph user body", into: draft)
        XCTAssertEqual(draft.value as? String, "Original paragraph user body")
        try paragraphClick(element("ai-save-note", in: app), in: app); value(element("ai-result-save-state", in: app), contains: "已保存")
        try paragraphClick(element("paragraph-source-c1", in: app), in: app); value(element("page-position", in: app), contains: "1 / 2")
    }
    @MainActor func testMacParagraphInsufficientAndInvalidResponsesCannotSave() throws {
        for scenario in ["insufficient", "invalid", "truncated"] {
            let app = app(paragraphScenario: scenario)
            defer { app.terminate() }
            try prepareParagraph(app); try sendParagraph(app)
            if scenario == "insufficient" {
                value(element("paragraph-insufficient", in: app), contains: "没有足够依据")
                XCTAssertFalse(element("ai-save-note", in: app).isEnabled)
            } else {
                value(element("ai-error", in: app), contains: scenario == "invalid" ? "结构或来源" : "截断")
                XCTAssertFalse(element("ai-save-note", in: app).exists)
                XCTAssertFalse(element("paragraph-result", in: app).exists)
            }
            app.terminate()
        }
    }
    @MainActor func testMacParagraphCancelDoesNotPublishOrSave() throws {
        let app = app(paragraphScenario: "slow"); defer { app.terminate() }
        try prepareParagraph(app); try sendParagraph(app)
        try paragraphClick(element("ai-cancel", in: app), in: app); value(element("ai-error", in: app), contains: "取消")
        XCTAssertFalse(element("paragraph-result", in: app).exists)
        XCTAssertFalse(element("ai-save-note", in: app).exists)
    }
    @MainActor func testMacParagraphEPUBCitationReturnsToCanonicalRange() throws {
        let app = app(paragraphScenario: "typed"); defer { app.terminate() }
        try prepareParagraph(app, epub: true); try sendParagraph(app)
        value(element("paragraph-quote-c1", in: app), contains: "w")
        try paragraphClick(element("paragraph-source-c1", in: app), in: app); value(element("epub-position", in: app), contains: "第 1 章")
        XCTAssertFalse(element("epub-error", in: app).exists)
    }

}
#endif
