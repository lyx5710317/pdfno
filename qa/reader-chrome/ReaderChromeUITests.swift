// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import XCTest

final class ReaderChromeUITests: XCTestCase {
    @MainActor private func item(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    @MainActor private func text(_ element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }
    @MainActor private func click(_ element: XCUIElement) throws {
        let ready = expectation(for: NSPredicate { _, _ in element.exists && element.isEnabled && element.isHittable }, evaluatedWith: element)
        wait(for: [ready], timeout: 15)
        guard element.exists && element.isEnabled && element.isHittable else { throw NSError(domain: "OriginalChromeQA", code: 1) }
        element.click()
    }
    @MainActor private func app(_ width: Int) throws -> XCUIApplication {
        let bundle = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_EXPECTED_BUNDLE"])
        XCTAssertEqual(bundle, ProcessInfo.processInfo.environment["PDFNO_ISOLATED_UI_APPLICATION_ID"])
        XCTAssertTrue(bundle.hasPrefix("org.pdfno.integration.professionala20261007.qa"))
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchEnvironment["PDFNO_A_QA_SCOPE"] = "a-regression"
        app.launchEnvironment["PDFNO_A_QA_WIDTH"] = String(width)
        app.launchEnvironment["PDFNO_A_QA_HEIGHT"] = width == 720 ? "520" : "800"
        app.launchEnvironment["PDFNO_A_QA_APPEARANCE"] = width == 720 ? "dark" : "light"
        app.launch(); app.activate(); return app
    }
    @MainActor private func open(_ id: String, _ app: XCUIApplication) throws {
        app.typeKey(.escape, modifierFlags: [])
        try click(item("workspace-help", app)); try click(item(id, app))
    }
    @MainActor private func tabs(_ app: XCUIApplication) -> [XCUIElement] {
        app.buttons.allElementsBoundByIndex.filter { $0.identifier.hasPrefix("document-tab-") && !$0.identifier.hasPrefix("document-tab-close-") }
    }
    @MainActor private func selected(_ id: String, _ app: XCUIApplication, _ value: String) {
        let target = item(id, app)
        let ready = expectation(for: NSPredicate { _, _ in target.exists && target.value as? String == value }, evaluatedWith: app)
        wait(for: [ready], timeout: 12)
    }
    @MainActor private func addFollowsLastTab(_ app: XCUIApplication) {
        let add = item("document-add", app)
        let ready = expectation(for: NSPredicate { _, _ in
            guard let last = self.tabs(app).last else { return add.isHittable }
            let close = self.item(last.identifier.replacingOccurrences(of: "document-tab-", with: "document-tab-close-"), app)
            let gap = add.frame.minX - close.frame.maxX
            return add.isHittable && gap >= 0 && gap < 28
        }, evaluatedWith: app)
        wait(for: [ready], timeout: 12)
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) throws {
        let token = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_SHOT_TOKEN"])
        XCTAssertNotNil(UUID(uuidString: token))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-A-WindowShots-" + token)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let path = root.appendingPathComponent(name + ".png")
        try app.windows.firstMatch.screenshot().pngRepresentation.write(to: path)
        let record = try JSONSerialization.data(withJSONObject: ["name": name, "path": path.path], options: .sortedKeys)
        print("PDFNO_A_WINDOW_SHOT " + String(decoding: record, as: UTF8.self))
    }
    @MainActor private func selectWindow(_ app: XCUIApplication) throws {
        var paragraph: XCUIElement?
        let found = expectation(for: NSPredicate { _, _ in
            paragraph = app.webViews.firstMatch.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "window")).firstMatch
            if paragraph?.exists != true { paragraph = app.webViews.firstMatch.staticTexts.allElementsBoundByIndex.first { ($0.value as? String)?.hasPrefix("window") == true } }
            return paragraph?.exists == true
        }, evaluatedWith: app)
        wait(for: [found], timeout: 15)
        let p = try XCTUnwrap(paragraph); XCTAssertTrue(p.isHittable)
        p.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.1)).doubleClick()
    }
    @MainActor func testWideHeaderlessPanelsRetainEditorAndAIAndFollowingAdd() throws {
        let app = try app(1280); defer { app.terminate() }
        XCTAssertTrue(item("document-add", app).waitForExistence(timeout: 15))
        XCTAssertEqual(tabs(app).count, 0)
        XCTAssertLessThan(item("document-add", app).frame.minX - item("workspace-back-library", app).frame.maxX, 24)
        try shot("CH-01-zero-tabs-plus", app)
        try open("open-sample", app); XCTAssertTrue(item("page-position", app).waitForExistence(timeout: 20)); addFollowsLastTab(app)
        try click(item("reader-navigation", app)); XCTAssertTrue(item("search-input", app).waitForExistence(timeout: 10)); XCTAssertFalse(item("close-navigation", app).exists)
        try click(item("reader-navigation", app)); XCTAssertFalse(item("reader-navigation-panel", app).exists)
        try click(item("reader-notes", app)); XCTAssertTrue(item("annotation-list", app).waitForExistence(timeout: 10)); XCTAssertFalse(item("close-notes", app).exists)
        try click(item("reader-bookmarks", app)); XCTAssertFalse(item("annotation-list", app).exists); XCTAssertFalse(item("reader-close-bookmarks", app).exists)
        try click(item("bookmark-add", app)); try click(item("bookmark-search-toggle", app)); XCTAssertTrue(item("bookmark-search", app).exists)
        try click(item("bookmark-edit-toggle", app)); XCTAssertTrue(item("bookmark-rename", app).waitForExistence(timeout: 10)); XCTAssertTrue(item("bookmark-delete", app).exists)
        try shot("CH-02-bookmark-actions-no-header", app)
        try click(item("reader-bookmarks", app)); XCTAssertFalse(item("bookmark-list", app).exists)
        try open("open-epub-sample", app); XCTAssertTrue(item("epub-aa", app).waitForExistence(timeout: 25)); addFollowsLastTab(app); XCTAssertEqual(tabs(app).count, 2)
        try click(item("epub-aa", app)); XCTAssertFalse(item("reading-aa-close", app).exists)
        try click(item("reading-mode-double", app)); selected("reading-mode-double", app, "已选中")
        try click(item("epub-contents", app)); XCTAssertFalse(item("reading-mode-double", app).exists); XCTAssertFalse(item("epub-close-contents", app).exists)
        try click(item("epub-aa", app)); selected("reading-mode-double", app, "已选中")
        try shot("CH-03-aa-no-header-two-tabs-plus", app)
        try click(item("reading-mode-scroll", app)); selected("reading-mode-scroll", app, "已选中"); try click(item("epub-aa", app))
        try selectWindow(app); try click(item("selection-annotation-note", app))
        XCTAssertTrue(item("annotation-editor-cancel", app).exists && item("annotation-editor-save", app).exists)
        let input = item("annotation-comment-input", app); try click(input); input.typeText("Original saved comment")
        try click(item("annotation-editor-save", app)); try click(item("epub-notes", app))
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'annotation-row-'" )).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 12)); row.doubleClick()
        XCTAssertTrue(item("annotation-comment-input", app).waitForExistence(timeout: 10))
        XCTAssertTrue(text(item("annotation-comment-input", app)).contains("Original saved comment"))
        try click(item("annotation-comment-input", app)); item("annotation-comment-input", app).typeText(" unsaved change")
        try click(item("annotation-editor-cancel", app)); try click(item("epub-aa", app)); try click(item("epub-notes", app))
        XCTAssertTrue(text(item("annotation-comment", app)).contains("Original saved comment")); XCTAssertFalse(text(item("annotation-comment", app)).contains("unsaved change"))
        try click(item("epub-notes", app)); try selectWindow(app)
        try click(item("selection-ai-menu", app)); try click(item("selection-ai-explain", app))
        XCTAssertTrue(item("ai-close", app).waitForExistence(timeout: 12)); XCTAssertTrue(app.staticTexts["选文学习"].exists)
        try shot("CH-04-ai-header-retained", app); try click(item("ai-close", app)); XCTAssertFalse(item("ai-close", app).exists)
        let window = app.windows.firstMatch, original = window.frame
        let add = item("document-add", app), more = item("document-more", app)
        XCTAssertGreaterThan(more.frame.minX - add.frame.maxX, 80)
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == app.bundleID else { throw NSError(domain: "OwnDesktopChanged", code: 2) }
        let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0)).withOffset(CGVector(dx: (add.frame.maxX + more.frame.minX) / 2 - original.minX, dy: add.frame.midY - original.minY))
        start.press(forDuration: 0.2, thenDragTo: start.withOffset(CGVector(dx: 20, dy: 20)))
        XCTAssertGreaterThan(abs(window.frame.minX - original.minX) + abs(window.frame.minY - original.minY), 8)
        XCTAssertEqual(tabs(app).count, 2); addFollowsLastTab(app)
        let last = try XCTUnwrap(tabs(app).last)
        try click(item(last.identifier.replacingOccurrences(of: "document-tab-", with: "document-tab-close-"), app))
        XCTAssertEqual(tabs(app).count, 1); addFollowsLastTab(app)
    }
    @MainActor func testNarrowOverflowBooknoAndOtherFormatPanels() throws {
        let app = try app(720); defer { app.terminate() }
        try open("open-sample", app); XCTAssertTrue(item("page-position", app).waitForExistence(timeout: 20))
        try open("open-epub-sample", app); XCTAssertTrue(item("epub-aa", app).waitForExistence(timeout: 25))
        try open("open-docx-sample", app); XCTAssertTrue(item("docx-navigation", app).waitForExistence(timeout: 25))
        try click(item("docx-navigation", app)); XCTAssertTrue(item("docx-chapter-0", app).waitForExistence(timeout: 12)); XCTAssertFalse(app.buttons["完成"].exists)
        try click(item("docx-navigation", app)); try click(item("docx-notes", app)); XCTAssertTrue(item("annotation-list", app).exists)
        try click(item("docx-notes", app)); XCTAssertFalse(item("annotation-list", app).exists)
        try open("open-ebook-sample", app); try click(item("open-ebook-sample-fb2", app)); XCTAssertTrue(item("ebook-aa", app).waitForExistence(timeout: 25))
        XCTAssertEqual(tabs(app).count, 4); XCTAssertTrue(item("document-add", app).isHittable)
        try click(item("ebook-navigation", app)); XCTAssertFalse(app.buttons["完成"].exists)
        try click(item("ebook-aa", app)); XCTAssertFalse(item("reading-aa-close", app).exists)
        try click(item("reading-mode-single", app)); selected("reading-mode-single", app, "已选中")
        try shot("CH-05-narrow-overflow-aa", app); try click(item("ebook-aa", app))
        try click(item("document-add", app)); app.typeKey(.escape, modifierFlags: [])
        XCTAssertTrue(item("document-add", app).isHittable)
        let bookno = item("bookno-preview-open", app); XCTAssertEqual(bookno.label, "bookno"); try click(bookno)
        XCTAssertTrue(item("bookno-preview-enabled", app).waitForExistence(timeout: 15)); XCTAssertTrue(app.staticTexts["bookno"].exists)
        XCTAssertFalse(app.staticTexts["Bookno 离线预览"].exists); XCTAssertTrue(item("bookno-prepare", app).exists)
        try shot("CH-06-bookno-display-only", app); try click(item("workspace-tool-return", app))
        XCTAssertEqual(tabs(app).count, 4); XCTAssertTrue(item("document-add", app).isHittable)
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_CHROME_ORIGINAL_FILE"])
        XCTAssertTrue(path.contains("/ReaderPanelSimplification/2026-10-10/QA01/FixtureInput/"))
        try click(item("document-add", app)); app.typeKey("g", modifierFlags: [.command, .shift])
        let location = app.sheets.firstMatch.textFields.firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 12)); try click(location)
        location.typeKey("a", modifierFlags: .command); location.typeText(path); location.typeKey(.return, modifierFlags: [])
        let filename = URL(fileURLWithPath: path).lastPathComponent
        XCTAssertTrue(app.staticTexts[filename].firstMatch.waitForExistence(timeout: 12))
        let accept = app.buttons["打开"].firstMatch.exists ? app.buttons["打开"].firstMatch : app.buttons["Open"].firstMatch
        try click(accept)
        XCTAssertTrue(item("textformat-aa", app).waitForExistence(timeout: 25)); XCTAssertEqual(tabs(app).count, 5)
        XCTAssertTrue(item("document-add", app).isHittable)
        try shot("CH-07-original-long-title-overflow", app)
        try click(item("textformat-navigation", app)); XCTAssertFalse(app.buttons["完成"].exists)
        try click(item("textformat-navigation", app)); try click(item("textformat-aa", app)); XCTAssertFalse(item("reading-aa-close", app).exists)
        try click(item("textformat-aa", app))
    }
}
#endif
