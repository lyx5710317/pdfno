// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
#if os(macOS)
import AppKit
#endif

final class NativeUITests: XCTestCase {
    #if os(macOS)
    @MainActor func testMacEPUBSelectionRubyNotesAndRestart() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate()
        let sample = app.buttons["open-epub-sample"].firstMatch
        XCTAssertTrue(sample.waitForExistence(timeout: 15)); press(sample)
        let position = app.staticTexts["epub-position"].firstMatch
        waitForText(["第 1 章"], in: position, timeout: 25)
        XCTAssertFalse(app.staticTexts["epub-error"].firstMatch.exists)
        let paragraph = try webText(in: app, matching: "window", prefix: true, timeout: 10)
        // Real WebKit user selection, never a JS-created test selection.
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        press(app.buttons["epub-notes"].firstMatch)
        let selection = app.staticTexts["epub-selection"].firstMatch
        XCTAssertTrue(selection.waitForExistence(timeout: 8))
        let selectedText = textValue(selection); XCTAssertFalse(selectedText.isEmpty)
        press(app.buttons["epub-save-note"].firstMatch)
        let quote = app.staticTexts["epub-saved-quote"].firstMatch
        XCTAssertTrue(quote.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(quote), selectedText)
        press(app.buttons["epub-return"].firstMatch)
        press(app.buttons["epub-next"].firstMatch)
        waitForText(["第 2 页"], in: position, timeout: 10)
        press(app.buttons["epub-contents"].firstMatch)
        let japanese = app.buttons["epub-chapter-1"].firstMatch
        XCTAssertTrue(japanese.waitForExistence(timeout: 5)); press(japanese)
        waitForText(["第 2 章"], in: position, timeout: 10)
        press(app.buttons["epub-orientation"].firstMatch)
        waitForText(["竖排"], in: position, timeout: 10)
        let ruby = try webText(in: app, matching: "にほんご", prefix: false, timeout: 15)
        XCTAssertTrue(ruby.exists, "Author ruby must remain visible in vertical reading")
        app.terminate(); app.launch(); app.activate()
        let book = app.descendants(matching: .any).matching(identifier: "library-epub").firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        waitForText(["第 2 章", "竖排"], in: position, timeout: 20)
        press(app.buttons["epub-notes"].firstMatch)
        XCTAssertTrue(quote.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(quote), selectedText)
        press(app.buttons["epub-return"].firstMatch)
        waitForText(["第 1 章"], in: position, timeout: 10)
        app.terminate()
    }
    #endif
    @MainActor private func textValue(_ element: XCUIElement) -> String {
        (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label
    }
    @MainActor private func waitForText(_ parts: [String], in element: XCUIElement, timeout: TimeInterval) {
        let ready = expectation(for: NSPredicate { _, _ in
            guard element.exists else { return false }
            let text = self.textValue(element)
            return parts.allSatisfy { text.contains($0) }
        }, evaluatedWith: element)
        wait(for: [ready], timeout: timeout)
    }
    @MainActor private func webText(in app: XCUIApplication, matching text: String, prefix: Bool, timeout: TimeInterval) throws -> XCUIElement {
        // WebKit can expose numeric AX values on macOS 15. Inspect actual
        // elements in Swift so substring predicates never receive a number.
        var found: XCUIElement?
        let ready = expectation(for: NSPredicate { _, _ in
            // Ruby can be exposed as a group rather than StaticText. Label is
            // always a String; query it without applying predicates to value.
            let labelMatch = app.webViews.firstMatch.descendants(matching: .any).matching(
                NSPredicate(format: prefix ? "label BEGINSWITH %@" : "label CONTAINS %@", text)
            ).firstMatch
            if labelMatch.exists { found = labelMatch; return true }
            if !prefix {
                // Equality accepts mixed value types. On macOS 15 rt text is
                // after every base paragraph in the AX tree, so avoid hundreds
                // of individual snapshot requests before finding its value.
                let exact = app.webViews.firstMatch.descendants(matching: .any).matching(
                    NSPredicate(format: "value == %@", text)
                ).firstMatch
                if exact.exists { found = exact; return true }
            }
            found = app.webViews.firstMatch.staticTexts.allElementsBoundByIndex.first {
                guard let value = $0.value as? String else { return false }
                return prefix ? value.hasPrefix(text) : value.contains(text)
            }
            return found != nil
        }, evaluatedWith: app)
        wait(for: [ready], timeout: timeout)
        if found == nil {
            // This app uses an isolated original fixture; never describe the
            // desktop, other applications, clipboard or the user's library.
            print("PDFno original EPUB WebKit accessibility: \(app.webViews.firstMatch.debugDescription)")
        }
        return try XCTUnwrap(found, "Actual WebKit text must be exposed for user selection/ruby acceptance")
    }
    @MainActor private func press(_ element: XCUIElement) {
        #if os(macOS)
        element.click()
        #else
        element.tap()
        #endif
    }
    @MainActor private func enterSearch(_ text: String, into input: XCUIElement) {
        press(input)
        #if os(macOS)
        // A user-selected input method can turn typeText into composition text.
        // Paste only the original fixture query and restore clipboard data in memory.
        let board = NSPasteboard.general
        let previous = (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        }
        board.clearContents(); board.setString(text, forType: .string)
        let change = board.changeCount
        input.typeKey("v", modifierFlags: .command)
        if board.changeCount == change { board.clearContents(); board.writeObjects(previous) }
        #else
        input.typeText(text)
        #endif
    }
    @MainActor
    func testLocalPDFReadingAndNoteFlow() throws {
        let app = XCUIApplication()
        // Keep a bare UUID out of macOS launch arguments: AppKit may interpret
        // positional arguments as files and suppress the initial library window.
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch()
        app.activate()
        let sample = app.buttons["open-sample"].firstMatch
        guard sample.waitForExistence(timeout: 15) else {
            // Only the isolated PDFno test application is described here. Do not
            // dump the desktop, other applications, clipboard or user library.
            print("PDFno isolated startup: state=\(app.state.rawValue), windows=\(app.windows.count), buttons=\(app.buttons.count)")
            for window in app.windows.allElementsBoundByIndex { print(window.debugDescription) }
            XCTFail("The isolated PDFno library must expose its original sample action")
            return
        }
        let ready = expectation(for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: sample)
        wait(for: [ready], timeout: 15)
        press(sample)
        let position = app.staticTexts["page-position"].firstMatch
        XCTAssertTrue(position.waitForExistence(timeout: 15))
        XCTAssertTrue(textValue(position).contains("1 / 2"))
        // macOS 15 exposes the toolbar wrapper and its child as buttons with
        // the same app-owned identifier. Both represent the same action.
        press(app.buttons["next-page"].firstMatch)
        XCTAssertTrue(textValue(position).contains("2 / 2"))
        press(app.buttons["previous-page"].firstMatch)
        XCTAssertTrue(textValue(position).contains("1 / 2"))
        press(app.buttons["reader-navigation"].firstMatch)
        let input = app.textFields["search-input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        enterSearch("window", into: input)
        press(app.buttons["search-submit"].firstMatch)
        let result = app.buttons["search-result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5))
        press(result)
        press(app.buttons["reader-notes"].firstMatch)
        let save = app.buttons["save-note"].firstMatch
        XCTAssertTrue(save.waitForExistence(timeout: 5), "PDFKit selection must survive opening notes")
        press(save)
        let quote = app.staticTexts["saved-note-quote"].firstMatch
        XCTAssertTrue(quote.waitForExistence(timeout: 5))
        XCTAssertEqual(textValue(quote), "window")
        press(app.buttons["return-to-source"].firstMatch)
        XCTAssertTrue(position.waitForExistence(timeout: 5))
        XCTAssertTrue(textValue(position).contains("1 / 2"))
        // macOS application screenshots can include the whole desktop. Keep
        // this attachment confined to the isolated original-fixture window.
        #if os(macOS)
        let image = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        #else
        let image = XCTAttachment(screenshot: app.screenshot())
        #endif
        image.name = "Original sample in native PDFKit reader"
        image.lifetime = .keepAlways
        add(image)
        press(app.buttons["next-page"].firstMatch)
        XCTAssertTrue(textValue(position).contains("2 / 2"))
        app.terminate()
        app.launch()
        app.activate()
        // SwiftUI plain buttons can be exposed as a group rather than a Button
        // on newer simulators. Target the explicit app-owned identifier.
        let book = app.descendants(matching: .any).matching(identifier: "library-book").firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        press(book)
        XCTAssertTrue(position.waitForExistence(timeout: 10))
        XCTAssertTrue(textValue(position).contains("2 / 2"), "Reading position must persist after process restart")
        press(app.buttons["reader-notes"].firstMatch)
        XCTAssertTrue(quote.waitForExistence(timeout: 5), "Note must survive process restart")
        press(app.buttons["return-to-source"].firstMatch)
        XCTAssertTrue(textValue(position).contains("1 / 2"))
        app.terminate()
    }
}
