// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest
import AppKit

/// Added only to the guarded local QA project. Never launches the product bundle.
final class ProfessionalReaderUITests: XCTestCase {
    @MainActor private func originalApp(width: Int, dark: Bool) throws -> XCUIApplication {
        let identifier = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_ISOLATED_UI_APPLICATION_ID"])
        XCTAssertEqual(identifier, "org.pdfno.integration.professionala20261007.PDFnoMac")
        let app = XCUIApplication(bundleIdentifier: identifier)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchEnvironment["PDFNO_A_QA_SCOPE"] = "a-regression"
        app.launchEnvironment["PDFNO_A_QA_WIDTH"] = String(width)
        app.launchEnvironment["PDFNO_A_QA_HEIGHT"] = width == 720 ? "520" : "800"
        app.launchEnvironment["PDFNO_A_QA_APPEARANCE"] = dark ? "dark" : "light"
        app.launch(); app.activate()
        return app
    }
    @MainActor private func item(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    @MainActor private func click(_ element: XCUIElement) throws {
        let ready = expectation(for: NSPredicate { _, _ in element.exists && element.isEnabled && element.isHittable }, evaluatedWith: element)
        wait(for: [ready], timeout: 15)
        XCTAssertTrue(element.exists && element.isEnabled && element.isHittable)
        guard element.exists && element.isEnabled && element.isHittable else { throw NSError(domain: "ProfessionalOriginalUI", code: 1) }
        element.click()
    }
    @MainActor private func value(_ element: XCUIElement, equals expected: String) {
        let ready = expectation(for: NSPredicate { _, _ in element.exists && element.value as? String == expected }, evaluatedWith: element)
        wait(for: [ready], timeout: 10); XCTAssertEqual(element.value as? String, expected)
    }
    @MainActor private func contains(_ element: XCUIElement, _ text: String) {
        let ready = expectation(for: NSPredicate { _, _ in element.exists && (element.label + " " + (element.value as? String ?? "")).contains(text) }, evaluatedWith: element)
        wait(for: [ready], timeout: 15)
    }
    @MainActor private func originalWebText(_ text: String, app: XCUIApplication) throws -> XCUIElement {
        // Same real WebKit roles/value handling as the original EPUB regressions.
        // macOS 15 may expose ruby as a group and text through value, not label.
        var found: XCUIElement?
        let ready = expectation(for: NSPredicate { _, _ in
            let label = app.webViews.firstMatch.descendants(matching: .any).matching(
                NSPredicate(format: "label BEGINSWITH %@", text)).firstMatch
            if label.exists { found = label; return true }
            found = app.webViews.firstMatch.staticTexts.allElementsBoundByIndex.first {
                ($0.value as? String)?.hasPrefix(text) == true
            }
            return found != nil
        }, evaluatedWith: app)
        wait(for: [ready], timeout: 20)
        return try XCTUnwrap(found, "Actual original EPUB text must exist for real user selection")
    }
    @MainActor private func pasteOriginal(_ text: String, app: XCUIApplication) {
        // Write fixture text only; do not read the user's clipboard.
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
        app.typeKey("v", modifierFlags: .command)
    }
    @MainActor private func searchOriginal(_ app: XCUIApplication) throws {
        app.typeKey("f", modifierFlags: .command)
        let input = item("search-input", app)
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        // No field click: Cmd-F must have moved keyboard focus into the actual search field.
        pasteOriginal("window", app: app); value(input, equals: "window")
        try click(item("search-submit", app)); try click(item("search-result", app))
    }
    @MainActor private func reveal(_ element: XCUIElement, in id: String, app: XCUIApplication) throws {
        let scroll = item(id, app)
        XCTAssertTrue(scroll.waitForExistence(timeout: 10)); XCTAssertTrue(element.waitForExistence(timeout: 10))
        for _ in 0..<14 {
            let viewport = scroll.frame.insetBy(dx: 4, dy: 8), target = element.frame
            if !target.isEmpty && viewport.contains(target) && element.isHittable { return }
            scroll.scroll(byDeltaX: 0, deltaY: target.minY < viewport.minY ? 220 : -220)
        }
        XCTAssertTrue(scroll.frame.insetBy(dx: 4, dy: 8).contains(element.frame)); XCTAssertTrue(element.isHittable)
        guard element.isHittable else { throw NSError(domain: "ProfessionalOriginalUI", code: 2) }
    }
    @MainActor private func capture(_ name: String, app: XCUIApplication) throws {
        let token = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_SHOT_TOKEN"])
        XCTAssertNotNil(UUID(uuidString: token))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-A-WindowShots-" + token, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let file = directory.appendingPathComponent(name + ".png")
        try app.windows.firstMatch.screenshot().pngRepresentation.write(to: file)
        let receipt = try JSONSerialization.data(withJSONObject: ["name": name, "path": file.path], options: [.sortedKeys])
        print("PDFNO_A_WINDOW_SHOT " + String(decoding: receipt, as: UTF8.self))
    }

    @MainActor func testANarrowPDFKeyboardSearchAndNoteDraftSurviveCollapse() throws {
        let app = try originalApp(width: 720, dark: false); defer { app.terminate() }
        try click(item("open-sample", app)); try searchOriginal(app)
        XCTAssertTrue(item("professional-reader-tool-rail", app).exists)
        XCTAssertLessThanOrEqual(app.windows.firstMatch.frame.width, 760)
        try click(item("reader-notes", app))
        let draft = item("note-input", app), body = "A original uncommitted draft 日本語 cafe\u{301}"
        try click(draft); pasteOriginal(body, app: app); value(draft, equals: body)
        draft.typeKey(.rightArrow, modifierFlags: [.command, .option]); contains(item("page-position", app), "1 / 2")
        try capture("A-product-03-narrow-notes-light", app: app)
        try click(item("close-notes", app)); try click(item("reader-notes", app)); value(draft, equals: body)
        XCTAssertFalse(item("saved-note-user-text", app).exists)
        try click(item("close-notes", app)); app.typeKey("f", modifierFlags: .command)
        value(item("search-input", app), equals: "window")
    }

    @MainActor func testARegularDarkLearningPanelConsentDraftAndManualSave() throws {
        let app = try originalApp(width: 1280, dark: true); defer { app.terminate() }
        try click(item("ai-settings", app)); try click(item("ai-use-mock", app)); try click(item("ai-settings-save", app))
        try click(item("open-sample", app)); try searchOriginal(app); try click(item("reader-ai", app))
        let start = item("ai-start", app)
        XCTAssertTrue(start.waitForExistence(timeout: 10)); XCTAssertFalse(start.isEnabled)
        XCTAssertFalse(item("ai-result", app).exists)
        try reveal(item("ai-scope-consent", app), in: "ai-notes-list", app: app)
        try click(item("ai-scope-consent", app)); try click(start)
        XCTAssertTrue(item("ai-result", app).waitForExistence(timeout: 15))
        let draft = item("ai-user-note", app), body = "A learning draft 日本語 👩🏽‍🚀"
        try reveal(draft, in: "ai-notes-list", app: app); try click(draft); pasteOriginal(body, app: app); value(draft, equals: body)
        try click(item("ai-close", app)); try click(item("reader-ai", app))
        try reveal(draft, in: "ai-notes-list", app: app); value(draft, equals: body)
        XCTAssertTrue(item("ai-result", app).exists); XCTAssertFalse(item("ai-saved-user-note", app).exists)
        try capture("A-product-04-learning-dark", app: app)
        let save = item("ai-save-note", app)
        try reveal(save, in: "ai-notes-list", app: app); try click(save)
        contains(item("ai-result-save-state", app), "已保存")
        try reveal(item("ai-result-source", app), in: "ai-notes-list", app: app); try click(item("ai-result-source", app))
        XCTAssertFalse(item("reader-notes-panel", app).exists); contains(item("page-position", app), "1 / 2")
    }

    @MainActor func testANarrowEPUBPanelsKeepCanonicalSourceAndDraft() throws {
        let app = try originalApp(width: 720, dark: true); defer { app.terminate() }
        try click(item("open-epub-sample", app))
        let paragraph = try originalWebText("window", app: app)
        XCTAssertTrue(paragraph.waitForExistence(timeout: 20)); XCTAssertTrue(paragraph.isHittable)
        // Target the first line: at 720 the fixture paragraph wraps, so its
        // vertical center can be the second line instead of the word window.
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.1)).doubleClick()
        try click(item("epub-notes", app)); contains(item("epub-selection", app), "window")
        let draft = item("epub-note-input", app), body = "A EPUB original draft 日本語"
        try click(draft); pasteOriginal(body, app: app); value(draft, equals: body)
        try click(item("epub-close-notes", app)); try click(item("epub-contents", app)); try click(item("epub-close-contents", app))
        try click(item("epub-notes", app)); value(draft, equals: body); contains(item("epub-selection", app), "window")
        try capture("A-product-05-narrow-epub-dark", app: app)
        try click(item("epub-save-note", app))
        let source = item("epub-return", app)
        try reveal(source, in: "epub-notes-list", app: app); try click(source)
        XCTAssertFalse(item("reader-notes-panel", app).exists); contains(item("epub-position", app), "第 1 章")
    }

    @MainActor func testARegularLightPanelsRestoreReadingArea() throws {
        let app = try originalApp(width: 1280, dark: false); defer { app.terminate() }
        try click(item("open-sample", app))
        try capture("A-product-01-default-light", app: app)
        try click(item("reader-navigation", app)); try click(item("reader-notes", app))
        let navigation = item("reader-navigation-panel", app), notes = item("reader-notes-panel", app)
        XCTAssertTrue(navigation.exists && notes.exists)
        XCTAssertGreaterThanOrEqual(notes.frame.minX - navigation.frame.maxX, 420)
        try capture("A-product-02-both-panels-light", app: app)
        try click(item("close-notes", app)); try click(item("close-navigation", app))
        XCTAssertFalse(navigation.exists); XCTAssertFalse(notes.exists)
        try click(item("next-page", app)); contains(item("page-position", app), "2 / 2")
        try click(item("previous-page", app)); contains(item("page-position", app), "1 / 2")
    }
}
#endif
