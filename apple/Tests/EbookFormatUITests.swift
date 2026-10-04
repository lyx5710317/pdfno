// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest
import Foundation

/// Execute only on an isolated CI host/OS user. Never launch against the owner's app session.
final class EbookFormatUITests: XCTestCase {
    @MainActor func testMOBISelectionNoteProgressRestart() throws { try flow("mobi", paragraph: "Original source", second: "Original MOBI chapter two") }
    @MainActor func testAZWSelectionNoteProgressRestart() throws { try flow("azw", paragraph: "Original source", second: "Original AZW chapter two") }
    @MainActor func testAZW3SelectionNoteProgressRestart() throws { try flow("azw3", paragraph: "Pure KF8", second: "Second KF8 heading") }
    @MainActor func testFB2SelectionNoteProgressRestart() throws { try flow("fb2", paragraph: "FictionBook XML", second: "Original FB2 chapter two") }
    @MainActor private func flow(_ format: String, paragraph: String, second: String) throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate(); defer { app.terminate() }
        let menu = app.descendants(matching: .any).matching(identifier: "open-ebook-sample").firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 15)); menu.click()
        let item = app.descendants(matching: .any).matching(identifier: "open-ebook-sample-" + format).firstMatch
        XCTAssertTrue(item.waitForExistence(timeout: 5)); item.click()
        let nav = app.buttons["ebook-navigation"].firstMatch
        XCTAssertTrue(nav.waitForExistence(timeout: 25)); waitEnabled(nav)
        XCTAssertFalse(app.buttons["reader-ai"].exists); XCTAssertFalse(app.buttons["reader-page-translation"].exists)
        let text = try webText(app, prefix: paragraph)
        text.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        app.buttons["ebook-notes"].firstMatch.click()
        let selected = app.descendants(matching: .any).matching(identifier: "ebook-selection").firstMatch
        XCTAssertTrue(selected.waitForExistence(timeout: 8))
        let quote = (selected.value as? String) ?? selected.label
        XCTAssertFalse(quote.isEmpty)
        let draft = app.descendants(matching: .any).matching(identifier: "ebook-user-note").firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 5)); draft.click(); draft.typeText("Original ebook observation")
        app.buttons["ebook-save-note"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["ebook-saved-user-note"].firstMatch.waitForExistence(timeout: 8))
        app.buttons["ebook-return"].firstMatch.click()
        nav.click(); let heading = app.buttons[second].firstMatch
        XCTAssertTrue(heading.waitForExistence(timeout: 5)); heading.click()
        let manifest = URL(fileURLWithPath: "/tmp").appendingPathComponent("PDFno-UITests-" + token).appendingPathComponent("ebook-kookit-v1.json")
        var savedAnchor: NSDictionary?, savedProgress: NSDictionary?
        let stored = expectation(for: NSPredicate { _, _ in
            guard let data = try? Data(contentsOf: manifest), let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let book = (state["books"] as? [[String: Any]])?.first, let note = (state["notes"] as? [[String: Any]])?.first,
                  let progress = book["progress"] as? NSDictionary, let anchor = note["anchor"] as? NSDictionary else { return false }
            savedAnchor = anchor; savedProgress = progress
            return book["format"] as? String == format && note["userText"] as? String == "Original ebook observation" && progress["quote"] as? String == String(second.prefix(1))
        }, evaluatedWith: app); wait(for: [stored], timeout: 10)
        XCTAssertNotNil(savedAnchor); XCTAssertNotNil(savedProgress)
        app.terminate(); app.launch(); app.activate()
        let row = app.descendants(matching: .any).matching(identifier: "library-ebook-" + format).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15)); row.click()
        XCTAssertTrue(nav.waitForExistence(timeout: 25)); waitEnabled(nav)
        app.buttons["ebook-notes"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["ebook-saved-quote"].firstMatch.waitForExistence(timeout: 8))
        let data = try Data(contentsOf: manifest), state = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let note = try XCTUnwrap((state["notes"] as? [[String: Any]])?.first), book = try XCTUnwrap((state["books"] as? [[String: Any]])?.first)
        XCTAssertEqual(note["anchor"] as? NSDictionary, savedAnchor); XCTAssertEqual(book["progress"] as? NSDictionary, savedProgress)
        app.buttons["ebook-return"].firstMatch.click()
        XCTAssertTrue(try webText(app, prefix: paragraph).isHittable)
        app.buttons["open-sample"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["page-position"].firstMatch.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["ebook-navigation"].exists)
    }
    @MainActor private func waitEnabled(_ element: XCUIElement) {
        let ready = expectation(for: NSPredicate { _, _ in element.exists && element.isEnabled }, evaluatedWith: element)
        wait(for: [ready], timeout: 25)
    }
    @MainActor private func webText(_ app: XCUIApplication, prefix: String) throws -> XCUIElement {
        var found: XCUIElement?
        let ready = expectation(for: NSPredicate { _, _ in
            let match = app.webViews.firstMatch.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
            if match.exists { found = match; return true }
            found = app.webViews.firstMatch.staticTexts.allElementsBoundByIndex.first { ($0.value as? String)?.hasPrefix(prefix) == true }
            return found != nil
        }, evaluatedWith: app); wait(for: [ready], timeout: 15)
        return try XCTUnwrap(found)
    }
}
#endif
