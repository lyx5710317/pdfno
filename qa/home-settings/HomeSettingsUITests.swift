// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest
import AppKit

final class HomeSettingsUITests: XCTestCase {
    @MainActor private func item(_ id: String, _ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
    @MainActor private func click(_ element: XCUIElement) throws {
        let ready = expectation(for: NSPredicate { _, _ in element.exists && element.isEnabled && element.isHittable }, evaluatedWith: element)
        wait(for: [ready], timeout: 15)
        XCTAssertTrue(element.exists && element.isEnabled && element.isHittable)
        guard element.exists && element.isEnabled && element.isHittable else { throw NSError(domain: "HomeSettingsFixture", code: 1) }
        element.click()
    }
    @MainActor private func app(width: Int = 1280, dark: Bool = false) throws -> XCUIApplication {
        let id = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_ISOLATED_UI_APPLICATION_ID"])
        XCTAssertEqual(id, ProcessInfo.processInfo.environment["PDFNO_A_QA_EXPECTED_BUNDLE"])
        XCTAssertTrue(id.hasPrefix("org.pdfno.integration.professionala20261007.qa"))
        let app = XCUIApplication(bundleIdentifier: id)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchEnvironment["PDFNO_A_QA_SCOPE"] = "a-regression"
        app.launchEnvironment["PDFNO_A_QA_WIDTH"] = String(width)
        app.launchEnvironment["PDFNO_A_QA_HEIGHT"] = width == 720 ? "520" : "800"
        app.launchEnvironment["PDFNO_A_QA_APPEARANCE"] = dark ? "dark" : "light"
        app.launch(); app.activate(); return app
    }
    @MainActor private func value(_ element: XCUIElement, _ expected: String) {
        let ready = expectation(for: NSPredicate { _, _ in element.exists && element.value as? String == expected }, evaluatedWith: element)
        wait(for: [ready], timeout: 10); XCTAssertEqual(element.value as? String, expected)
    }
    @MainActor private func contains(_ element: XCUIElement, _ text: String) {
        let ready = expectation(for: NSPredicate { _, _ in element.exists && (element.label + " " + (element.value as? String ?? "")).contains(text) }, evaluatedWith: element)
        wait(for: [ready], timeout: 15)
    }
    @MainActor private func paste(_ text: String, into element: XCUIElement, app: XCUIApplication) throws {
        try click(element); app.typeKey("a", modifierFlags: .command)
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
        app.typeKey("v", modifierFlags: .command); value(element, text)
    }
    @MainActor private func category(_ title: String, id: String, app: XCUIApplication) throws {
        let direct = item("settings-category-" + id, app)
        if direct.exists { try click(direct) }
        else { try click(item("settings-category-picker", app)); try click(app.menuItems[title].firstMatch) }
    }
    @MainActor private func reveal(_ element: XCUIElement, scrollID: String, app: XCUIApplication) throws {
        let scroll = item(scrollID, app)
        XCTAssertTrue(scroll.waitForExistence(timeout: 10)); XCTAssertTrue(element.waitForExistence(timeout: 10))
        for _ in 0..<18 {
            if scroll.frame.insetBy(dx: 4, dy: 8).contains(element.frame) && element.isHittable { return }
            scroll.scroll(byDeltaX: 0, deltaY: element.frame.minY < scroll.frame.minY ? 220 : -220)
        }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func capture(_ name: String, app: XCUIApplication) throws {
        let token = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_SHOT_TOKEN"])
        XCTAssertNotNil(UUID(uuidString: token))
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-A-WindowShots-" + token, isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent(name + ".png")
        try app.windows.firstMatch.screenshot().pngRepresentation.write(to: file)
        let receipt = try JSONSerialization.data(withJSONObject: ["name": name, "path": file.path], options: [.sortedKeys])
        print("PDFNO_A_WINDOW_SHOT " + String(decoding: receipt, as: UTF8.self))
    }
    @MainActor private func sample(_ app: XCUIApplication) throws {
        try click(item("workspace-help", app)); try click(item("open-sample", app)); contains(item("page-position", app), "1 / 2")
    }
    @MainActor private func persistentBytes(_ app: XCUIApplication) throws -> [String: Data] {
        let token = try XCTUnwrap(app.launchEnvironment["PDFNO_UI_TEST_SESSION"])
        let root = URL(fileURLWithPath: "/tmp/PDFno-UITests-" + token)
        let enumerator = try XCTUnwrap(FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]))
        var bytes: [String: Data] = [:]
        for case let file as URL in enumerator {
            let relative = String(file.path.dropFirst(root.path.count + 1))
            guard !relative.contains("cover"), !relative.contains("cache"), try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            bytes[relative] = try Data(contentsOf: file)
        }
        return bytes
    }

    @MainActor func testHomeCoverGridAndSettingsFitFourWindowAppearances() throws {
        for width in [1280, 720] { for dark in [false, true] {
            let app = try app(width: width, dark: dark)
            defer { app.terminate() }
            XCTAssertTrue(item("professional-library-workspace", app).waitForExistence(timeout: 15))
            XCTAssertEqual(item("library-grid-layout", app).value as? String, "已选中")
            try sample(app); try click(item("workspace-back-library", app)); try click(item("library-category-examples", app))
            let card = item("library-book", app)
            XCTAssertTrue(card.waitForExistence(timeout: 10)); XCTAssertGreaterThan(card.frame.height, width == 720 ? 200 : 270)
            XCTAssertTrue(item("professional-library-books", app).frame.contains(card.frame), "The entire first card must fit in the visible gallery")
            let scheme = dark ? "dark" : "light", label = "H-" + String(width) + "-" + scheme
            try capture(label + "-home-grid", app: app)
            try click(item("library-list-layout", app)); XCTAssertEqual(item("library-list-layout", app).value as? String, "已选中")
            try click(item("library-grid-layout", app))
            app.typeKey(",", modifierFlags: .command)
            XCTAssertTrue(item("settings-return", app).waitForExistence(timeout: 10))
            XCTAssertEqual(app.windows.count, 1)
            if width == 720 { XCTAssertLessThanOrEqual(app.windows.firstMatch.frame.width, 760) }
            try category("通用", id: "general", app: app)
            try capture(label + "-settings", app: app)
            try click(item("settings-return", app))
            XCTAssertTrue(item("professional-library-workspace", app).exists)
            app.terminate()
        } }
    }
    @MainActor func testSettingsOrdinaryDraftReturnCancelAndInlineBYOKNeverAutoSave() throws {
        let app = try app(); defer { app.terminate() }
        try sample(app); try click(item("ai-settings", app))
        let label = item("ai-provider-label", app)
        XCTAssertTrue(label.waitForExistence(timeout: 10))
        let before = try persistentBytes(app), pending = "Unapplied 原创配置 日本語 cafe\u{301}"
        try paste(pending, into: label, app: app)
        try category("通用", id: "general", app: app); try category("AI", id: "ai", app: app); value(label, pending)
        try click(item("settings-return", app)); contains(item("page-position", app), "1 / 2")
        try click(item("ai-settings", app)); value(label, pending)
        XCTAssertEqual(try persistentBytes(app), before)
        try click(item("ai-settings-cancel", app)); try click(item("ai-settings", app))
        XCTAssertNotEqual(label.value as? String, pending)
        try click(item("byok-settings-open", app))
        let endpoint = item("byok-endpoint", app)
        try reveal(endpoint, scrollID: "ai-settings-form", app: app)
        try paste("https://fixture-config.example/v1", into: endpoint, app: app)
        let byokPending = endpoint.value as? String
        try category("通用", id: "general", app: app); try category("AI", id: "ai", app: app)
        try reveal(endpoint, scrollID: "ai-settings-form", app: app); value(endpoint, try XCTUnwrap(byokPending))
        XCTAssertEqual(app.windows.count, 1)
        XCTAssertFalse(app.sheets.firstMatch.exists)
        XCTAssertEqual(try persistentBytes(app), before)
        try capture("H-settings-inline-BYOK-unapplied", app: app)
        try click(item("settings-return", app)); contains(item("page-position", app), "1 / 2")
    }
    @MainActor func testReaderPositionSelectionNoteAndAIDraftsSurviveSettingsAndLibrary() throws {
        let app = try app(dark: true); defer { app.terminate() }
        try click(item("ai-settings", app)); try click(item("ai-use-mock", app)); try click(item("ai-settings-save", app))
        try sample(app)
        app.typeKey("f", modifierFlags: .command)
        try paste("window", into: item("search-input", app), app: app)
        try click(item("search-submit", app)); try click(item("search-result", app))
        try click(item("reader-notes", app)); contains(item("pdf-note-selection", app), "window")
        let note = "Unsaved note 原创 日本語 👩🏽‍🚀"
        try paste(note, into: item("note-input", app), app: app)
        try click(item("reader-ai", app)); try reveal(item("ai-scope-consent", app), scrollID: "ai-notes-list", app: app)
        try click(item("ai-scope-consent", app)); try click(item("ai-start", app))
        XCTAssertTrue(item("ai-result", app).waitForExistence(timeout: 15))
        let ai = "Unsaved AI 原创 cafe\u{301}"
        try reveal(item("ai-user-note", app), scrollID: "ai-notes-list", app: app)
        try paste(ai, into: item("ai-user-note", app), app: app)
        let before = try persistentBytes(app)
        for _ in 0..<3 {
            try click(item("ai-settings", app)); try category("通用", id: "general", app: app); try click(item("settings-return", app))
            contains(item("page-position", app), "1 / 2")
            try reveal(item("ai-user-note", app), scrollID: "ai-notes-list", app: app); value(item("ai-user-note", app), ai)
            try click(item("reader-notes", app)); value(item("note-input", app), note); contains(item("pdf-note-selection", app), "window")
            try click(item("reader-ai", app))
        }
        try click(item("workspace-back-library", app)); try click(item("workspace-resume-reader", app))
        try reveal(item("ai-user-note", app), scrollID: "ai-notes-list", app: app); value(item("ai-user-note", app), ai)
        XCTAssertTrue(item("ai-result", app).exists); XCTAssertFalse(item("ai-saved-user-note", app).exists)
        XCTAssertEqual(try persistentBytes(app), before)
        try capture("H-reader-two-drafts-after-settings", app: app)
    }
}
#endif
