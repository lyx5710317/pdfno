// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest
import AppKit

/// Supplemental real-window checks. Original 68 methods and assertions stay exact.
final class ViewportInspectorUITests: XCTestCase {
    @MainActor func testRegularEPUBLightInspectorAvoidsNativeBody() throws { try check(dark: false) }
    @MainActor func testRegularEPUBDarkInspectorAvoidsNativeBody() throws { try check(dark: true) }
    @MainActor private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    @MainActor private func click(_ target: XCUIElement) {
        let ready = expectation(for: NSPredicate { _, _ in target.exists && target.isEnabled && target.isHittable }, evaluatedWith: target)
        wait(for: [ready], timeout: 15); XCTAssertTrue(target.isHittable); target.click()
    }
    @MainActor private func contains(_ target: XCUIElement, _ text: String) {
        let ready = expectation(for: NSPredicate { _, _ in target.exists && (target.label + " " + (target.value as? String ?? "")).contains(text) }, evaluatedWith: target)
        wait(for: [ready], timeout: 15)
    }
    @MainActor private func check(dark: Bool) throws {
        let identifier = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_ISOLATED_UI_APPLICATION_ID"])
        XCTAssertEqual(identifier, ProcessInfo.processInfo.environment["PDFNO_A_QA_EXPECTED_BUNDLE"])
        XCTAssertTrue(identifier.hasPrefix("org.pdfno.integration.professionala20261007.qa"))
        let app = XCUIApplication(bundleIdentifier: identifier)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchEnvironment["PDFNO_A_QA_SCOPE"] = "a-regression"
        app.launchEnvironment["PDFNO_A_QA_WIDTH"] = "1280"
        app.launchEnvironment["PDFNO_A_QA_HEIGHT"] = "800"
        app.launchEnvironment["PDFNO_A_QA_APPEARANCE"] = dark ? "dark" : "light"
        app.launch(); app.activate(); defer { app.terminate() }
        click(element("workspace-help", app)); click(element("open-epub-sample", app))
        var paragraph: XCUIElement?
        let ready = expectation(for: NSPredicate { _, _ in
            paragraph = app.webViews.firstMatch.staticTexts.allElementsBoundByIndex.first {
                ($0.value as? String ?? $0.label).hasPrefix("window")
            }
            return paragraph?.isHittable == true
        }, evaluatedWith: app)
        wait(for: [ready], timeout: 20)
        try XCTUnwrap(paragraph).coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.1)).doubleClick()
        click(element("epub-notes", app)); contains(element("epub-selection", app), "window")
        let draft = element("epub-note-input", app), body = "Original wide EPUB draft 日本語 cafe\u{301} 👩🏽‍🚀"
        click(draft); NSPasteboard.general.clearContents(); NSPasteboard.general.setString(body, forType: .string)
        app.typeKey("v", modifierFlags: .command)
        XCTAssertEqual(draft.value as? String, body)
        click(element("epub-contents", app))
        let notes = element("reader-notes-panel", app), contents = element("reader-navigation-panel", app)
        let native = app.webViews.firstMatch
        XCTAssertTrue(notes.exists && contents.exists && native.exists)
        XCTAssertGreaterThanOrEqual(native.frame.width, 420)
        XCTAssertGreaterThanOrEqual(native.frame.minX, contents.frame.maxX - 0.5)
        XCTAssertLessThanOrEqual(native.frame.maxX, notes.frame.minX + 0.5)
        contains(element("epub-selection", app), "window")
        XCTAssertEqual(draft.value as? String, body)
        contains(element("epub-position", app), "第 1 页")
        let token = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_SHOT_TOKEN"])
        XCTAssertNotNil(UUID(uuidString: token))
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-A-WindowShots-" + token)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = "A-viewport-regular-epub-" + (dark ? "dark" : "light"), path = folder.appendingPathComponent(name + ".png")
        try app.windows.firstMatch.screenshot().pngRepresentation.write(to: path)
        let receipt = try JSONSerialization.data(withJSONObject: ["name": name, "path": path.path], options: [.sortedKeys])
        print("PDFNO_A_WINDOW_SHOT " + String(decoding: receipt, as: UTF8.self))
        click(element("epub-close-contents", app)); click(element("epub-close-notes", app)); click(element("epub-notes", app))
        contains(element("epub-selection", app), "window"); XCTAssertEqual(draft.value as? String, body)
        XCTAssertFalse(element("epub-saved-user-text", app).exists)
    }
}
#endif
