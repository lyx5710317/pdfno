// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import XCTest

/// Unique guarded fixture application only. Standard XCTest events; no alternate input.
final class ReadingLayoutUITests: XCTestCase {
    @MainActor private func item(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    @MainActor private func textValue(_ element: XCUIElement) -> String {
        // macOS StaticText exposes displayed text through AXValue. Match the
        // existing NativeUITests reader without changing the position assertion.
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }
    @MainActor private func click(_ element: XCUIElement) throws {
        let ready = expectation(for: NSPredicate { _, _ in element.exists && element.isEnabled && element.isHittable }, evaluatedWith: element)
        wait(for: [ready], timeout: 15)
        XCTAssertTrue(element.exists && element.isEnabled && element.isHittable)
        guard element.exists && element.isEnabled && element.isHittable else { throw NSError(domain: "OriginalAaQA", code: 1) }
        element.click()
    }
    @MainActor private func app(_ width: Int, dark: Bool) throws -> XCUIApplication {
        let bundle = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_EXPECTED_BUNDLE"])
        XCTAssertEqual(bundle, ProcessInfo.processInfo.environment["PDFNO_ISOLATED_UI_APPLICATION_ID"])
        XCTAssertTrue(bundle.hasPrefix("org.pdfno.integration.professionala20261007.qa"))
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchEnvironment["PDFNO_A_QA_SCOPE"] = "a-regression"
        app.launchEnvironment["PDFNO_A_QA_WIDTH"] = String(width)
        app.launchEnvironment["PDFNO_A_QA_HEIGHT"] = width == 720 ? "520" : "800"
        app.launchEnvironment["PDFNO_A_QA_APPEARANCE"] = dark ? "dark" : "light"
        app.launch(); app.activate()
        return app
    }
    @MainActor private func open(_ id: String, _ app: XCUIApplication) throws {
        app.typeKey(.escape, modifierFlags: [])
        try click(item("workspace-help", app)); try click(item(id, app))
    }
    @MainActor private func selected(_ id: String, _ app: XCUIApplication) {
        let target = item(id, app)
        let settled = expectation(for: NSPredicate { _, _ in target.exists && target.value as? String == "已选中" }, evaluatedWith: target)
        wait(for: [settled], timeout: 12); XCTAssertEqual(target.value as? String, "已选中")
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) throws {
        let token = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_SHOT_TOKEN"])
        XCTAssertNotNil(UUID(uuidString: token))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-A-WindowShots-" + token)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let path = directory.appendingPathComponent(name + ".png")
        try app.windows.firstMatch.screenshot().pngRepresentation.write(to: path)
        let record = try JSONSerialization.data(withJSONObject: ["name": name, "path": path.path], options: .sortedKeys)
        print("PDFNO_A_WINDOW_SHOT " + String(decoding: record, as: UTF8.self))
    }
    @MainActor func testWideEPUBModesSizeNoteAndBookmarkSourceReturn() throws {
        let app = try app(1280, dark: false); defer { app.terminate() }
        try open("open-epub-sample", app)
        XCTAssertTrue(item("epub-aa", app).waitForExistence(timeout: 25))
        XCTAssertFalse(item("epub-previous", app).exists || item("epub-next", app).exists || item("epub-return-to-previous", app).exists)
        XCTAssertFalse(item("reading-bottom-next", app).exists)
        try click(item("epub-aa", app)); selected("reading-mode-scroll", app)
        try click(item("reading-font-larger", app))
        let font = item("reading-font-size", app)
        let enlarged = expectation(for: NSPredicate { _, _ in font.label == "22" || font.value as? String == "22" }, evaluatedWith: font)
        wait(for: [enlarged], timeout: 12)
        try click(item("reading-mode-single", app)); selected("reading-mode-single", app)
        try shot("AA-01-wide-single-panel", app)
        try click(item("reading-aa-close", app))
        let old = textValue(item("epub-position", app))
        XCTAssertTrue(old.contains("第 1 页"))
        try click(item("reading-bottom-next", app))
        let moved = expectation(for: NSPredicate { _, _ in self.textValue(self.item("epub-position", app)) != old }, evaluatedWith: app)
        wait(for: [moved], timeout: 12)
        XCTAssertTrue(textValue(item("epub-position", app)).contains("第 2 页"))
        XCTAssertTrue(textValue(item("epub-reading-mode-description", app)).contains("单栏分页阅读"))
        try shot("AA-08-wide-single-next-page", app)
        try click(item("reading-bottom-previous", app))
        try click(item("epub-aa", app)); try click(item("reading-mode-double", app)); selected("reading-mode-double", app)
        try click(item("reading-aa-close", app)); try shot("AA-02-wide-double-body", app)
        try click(item("epub-bookmarks", app)); try click(item("bookmark-add", app))
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'bookmark-row-'"))
        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 12)); XCTAssertEqual(rows.count, 1)
        try click(rows.firstMatch)
        try click(item("epub-close-bookmarks", app))
        try click(item("epub-aa", app)); try click(item("reading-mode-scroll", app)); selected("reading-mode-scroll", app)
        try click(item("reading-aa-close", app)); XCTAssertFalse(item("reading-bottom-next", app).exists)
        var paragraph: XCUIElement?
        let found = expectation(for: NSPredicate { _, _ in
            paragraph = app.webViews.firstMatch.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "window")).firstMatch
            if paragraph?.exists != true { paragraph = app.webViews.firstMatch.staticTexts.allElementsBoundByIndex.first { ($0.value as? String)?.hasPrefix("window") == true } }
            return paragraph?.exists == true
        }, evaluatedWith: app)
        wait(for: [found], timeout: 15); let text = try XCTUnwrap(paragraph); XCTAssertTrue(text.isHittable)
        text.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.1)).doubleClick()
        try click(item("selection-annotation-note", app))
        try click(item("annotation-editor-cancel", app))
        try click(item("epub-notes", app)); XCTAssertTrue(item("annotation-list", app).waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'annotation-row-'" )).count, 0)
        try shot("AA-03-wide-scroll-cancelled-note", app)
        try click(item("epub-close-notes", app))
        text.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.1)).doubleClick()
        try click(item("selection-annotation-highlight", app))
        try click(item("epub-aa", app)); try click(item("reading-mode-single", app)); selected("reading-mode-single", app)
        try click(item("reading-aa-close", app)); try click(item("epub-notes", app))
        let annotations = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'annotation-row-'"))
        XCTAssertTrue(annotations.firstMatch.waitForExistence(timeout: 12)); XCTAssertEqual(annotations.count, 1)
        try click(annotations.firstMatch)
        let status = item("annotation-status", app)
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        XCTAssertTrue((status.label + (status.value as? String ?? "")).contains("已定位原文"))
        try shot("AA-07-wide-note-return-after-reflow", app)
    }
    @MainActor func testNarrowDarkReopenModesAndPDFWordNegativeCapabilities() throws {
        let app = try app(720, dark: true); defer { app.terminate() }
        try open("open-epub-sample", app)
        XCTAssertTrue(item("epub-aa", app).waitForExistence(timeout: 25))
        try click(item("epub-aa", app)); try click(item("reading-mode-single", app)); selected("reading-mode-single", app)
        try click(item("reading-aa-close", app)); try click(item("epub-aa", app)); selected("reading-mode-single", app)
        try shot("AA-04-narrow-dark-reopened-panel", app)
        try click(item("reading-mode-scroll", app)); selected("reading-mode-scroll", app); try click(item("reading-aa-close", app))
        XCTAssertFalse(item("reading-bottom-next", app).exists)
        try open("open-sample", app); XCTAssertTrue(item("page-position", app).waitForExistence(timeout: 20))
        XCTAssertFalse(item("epub-aa", app).exists || item("textformat-aa", app).exists || item("ebook-aa", app).exists)
        XCTAssertFalse(item("reading-bottom-previous", app).exists || item("reading-bottom-next", app).exists)
        try click(item("reader-navigation", app)); XCTAssertTrue(item("search-input", app).waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["导航与搜索"].exists)
        try shot("AA-05-narrow-dark-pdf-search", app)
        try open("open-docx-sample", app); XCTAssertTrue(item("docx-navigation", app).waitForExistence(timeout: 25))
        XCTAssertFalse(item("ebook-aa", app).exists || item("textformat-aa", app).exists || item("epub-aa", app).exists)
        XCTAssertFalse(item("reading-bottom-next", app).exists)
        try shot("AA-06-narrow-dark-word", app)
    }
}
#endif
