// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
#if os(macOS)
import AppKit
#endif

final class NativeUITests: XCTestCase {
    #if os(macOS)
    @MainActor func testMacCBZImportSpreadsDirectionPageJumpAndRestart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-CBZ-UI-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = root.appendingPathComponent("Original Comic.cbz")
        let entries = try (0..<7).map { index in
            ("pages/\(index + 1).PNG", try originalPNG(width: index == 3 ? 30 : 12, height: index == 3 ? 10 : 20))
        }
        try originalZIP(entries).write(to: archive)
        let broken = root.appendingPathComponent("Broken Original.cbz")
        try Data("Original malformed CBZ fixture".utf8).write(to: broken)
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        XCTAssertTrue(app.buttons["open-sample"].firstMatch.waitForExistence(timeout: 15))
        try chooseInput(archive, trigger: app.buttons["import-pdf"].firstMatch, app: app)
        let position = app.staticTexts["comic-position"].firstMatch
        waitForText(["1 / 7"], in: position, timeout: 25)
        XCTAssertTrue(app.webViews["comic-content"].firstMatch.exists)
        let layout = app.popUpButtons["comic-layout"].firstMatch
        XCTAssertTrue(layout.waitForExistence(timeout: 5)); press(layout); press(app.menuItems["双页"].firstMatch)
        waitForText(["双页"], in: layout, timeout: 10)
        waitUntilEnabled(app.buttons["comic-next"].firstMatch)
        press(app.buttons["comic-next"].firstMatch)
        waitForText(["2–3 / 7"], in: position, timeout: 15)
        let direction = app.popUpButtons["comic-direction"].firstMatch
        press(direction); press(app.menuItems["从右到左"].firstMatch)
        waitForText(["从右到左"], in: direction, timeout: 10)
        waitForText(["2–3 / 7"], in: position, timeout: 15)
        waitUntilEnabled(app.buttons["comic-next"].firstMatch)
        press(app.buttons["comic-next"].firstMatch)
        waitForText(["4 / 7"], in: position, timeout: 15)
        waitUntilEnabled(app.buttons["comic-next"].firstMatch)
        press(app.buttons["comic-next"].firstMatch)
        waitForText(["5–6 / 7"], in: position, timeout: 15)
        waitUntilEnabled(app.buttons["comic-next"].firstMatch)
        press(app.buttons["comic-next"].firstMatch)
        waitForText(["7 / 7"], in: position, timeout: 15)
        XCTAssertFalse(app.buttons["comic-next"].firstMatch.isEnabled)
        press(app.buttons["comic-pages"].firstMatch)
        let page = app.buttons["comic-page-4"].firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 5)); press(page)
        waitForText(["5–6 / 7"], in: position, timeout: 15)
        press(layout); press(app.menuItems["单页"].firstMatch)
        waitForText(["单页"], in: layout, timeout: 10)
        waitForText(["5 / 7"], in: position, timeout: 15)
        press(app.buttons["comic-close"].firstMatch)
        let comic = app.descendants(matching: .any).matching(identifier: "library-comic").firstMatch
        XCTAssertTrue(comic.waitForExistence(timeout: 5)); press(comic)
        waitForText(["5 / 7"], in: position, timeout: 25)
        app.terminate(); app.launch(); app.activate()
        XCTAssertTrue(comic.waitForExistence(timeout: 10)); press(comic)
        waitForText(["5 / 7"], in: position, timeout: 25)
        XCTAssertTrue(textValue(direction).contains("从右到左")); XCTAssertTrue(textValue(layout).contains("单页"))
        try chooseInput(broken, trigger: app.buttons["import-pdf"].firstMatch, app: app)
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 10)); press(app.buttons["知道了"].firstMatch)
        waitForText(["5 / 7"], in: position, timeout: 5)
        press(app.buttons["open-sample"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 10)
        press(app.buttons["open-epub-sample"].firstMatch)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        press(comic); waitForText(["5 / 7"], in: position, timeout: 25)
    }
    @MainActor private func waitUntilEnabled(_ element: XCUIElement) {
        let ready = expectation(for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: element)
        wait(for: [ready], timeout: 10)
    }
    @MainActor private func chooseInput(_ url: URL, trigger: XCUIElement, app: XCUIApplication) throws {
        press(trigger)
        app.typeKey("g", modifierFlags: [.command, .shift])
        let combo = app.comboBoxes.firstMatch
        let text = app.textFields.firstMatch
        let location = combo.waitForExistence(timeout: 3) ? combo : text
        XCTAssertTrue(location.waitForExistence(timeout: 5))
        enterSearch(url.path, into: location); app.typeKey(.return, modifierFlags: [])
        let open = app.buttons["Open"].firstMatch.exists ? app.buttons["Open"].firstMatch : app.buttons["打开"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 5)); press(open)
    }
    @MainActor private func originalPNG(width: Int, height: Int) throws -> Data {
        let bitmap = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4, bitsPerPixel: 32))
        let bytes = try XCTUnwrap(bitmap.bitmapData)
        for i in 0..<(width * height) { bytes[4*i] = 45; bytes[4*i+1] = 125; bytes[4*i+2] = 210; bytes[4*i+3] = 255 }
        return try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
    }
    private func originalZIP(_ entries: [(String, Data)]) -> Data {
        func u16(_ value: Int) -> Data { Data([UInt8(value & 255), UInt8((value >> 8) & 255)]) }
        func u32(_ value: Int) -> Data { u16(value & 65535) + u16((value >> 16) & 65535) }
        func crc(_ data: Data) -> Int {
            var value = UInt32.max
            for byte in data { value ^= UInt32(byte); for _ in 0..<8 { value = value & 1 == 0 ? value >> 1 : (value >> 1) ^ 0xedb88320 } }
            return Int(value ^ UInt32.max)
        }
        var local = Data(), central = Data()
        for (path, data) in entries {
            let name = Data(path.utf8), offset = local.count, checksum = crc(data)
            local += u32(0x04034b50) + u16(20) + u16(0x0800) + u16(0) + u16(0) + u16(0)
            local += u32(checksum) + u32(data.count) + u32(data.count) + u16(name.count) + u16(0) + name + data
            central += u32(0x02014b50) + u16(0x0314) + u16(20) + u16(0x0800) + u16(0) + u16(0) + u16(0)
            central += u32(checksum) + u32(data.count) + u32(data.count) + u16(name.count) + u16(0) + u16(0)
            central += u16(0) + u16(0) + u32(0x8000 << 16) + u32(offset) + name
        }
        return local + central + u32(0x06054b50) + u16(0) + u16(0) + u16(entries.count) + u16(entries.count) + u32(central.count) + u32(local.count) + u16(0)
    }
    @MainActor func testMacDeepSeekSelectionOfflineTransportPDFEPUBAndRestart() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launch(); app.activate()
        let sample = app.buttons["open-sample"].firstMatch
        XCTAssertTrue(sample.waitForExistence(timeout: 15)); press(sample)
        press(app.buttons["reader-navigation"].firstMatch)
        let search = app.textFields["search-input"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); enterSearch("window", into: search)
        press(app.buttons["search-submit"].firstMatch)
        let match = app.buttons["search-result"].firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 5)); press(match)
        press(app.buttons["reader-ai"].firstMatch)
        // Fail before setting or submitting any credential if offline injection is absent.
        guard app.staticTexts["ai-offline-fixture"].firstMatch.waitForExistence(timeout: 5) else {
            XCTFail("Offline transport must be injected before any synthetic credential entry")
            app.terminate(); return
        }
        press(app.buttons["ai-close"].firstMatch)
        press(app.buttons["ai-settings"].firstMatch)
        let preset = app.buttons["ai-use-deepseek"].firstMatch
        XCTAssertTrue(preset.waitForExistence(timeout: 5)); press(preset)
        let key = app.descendants(matching: .any).matching(identifier: "ai-session-key").firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 5)); press(key); key.typeText("synthetic-reading-ui-credential")
        press(app.buttons["ai-settings-save"].firstMatch)
        press(app.buttons["reader-ai"].firstMatch)
        let start = app.buttons["ai-start"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5)); XCTAssertFalse(start.isEnabled)
        XCTAssertEqual(textValue(app.staticTexts["ai-source-quote"].firstMatch), "window")
        let consent = app.descendants(matching: .any).matching(identifier: "ai-scope-consent").firstMatch
        press(consent); XCTAssertTrue(start.isEnabled); press(start)
        let result = app.staticTexts["ai-result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8)); XCTAssertTrue(textValue(result).contains("离线 DeepSeek UI 替身"))
        XCTAssertTrue(textValue(result).contains("翻译"))
        XCTAssertFalse(app.staticTexts["ai-saved-result"].firstMatch.exists, "Generated output must not create a saved note automatically")
        let note = app.descendants(matching: .any).matching(identifier: "ai-user-note").firstMatch
        enterSearch("Original synthetic DeepSeek user note", into: note)
        press(app.buttons["ai-save-note"].firstMatch)
        XCTAssertTrue(app.staticTexts["ai-saved-user-note"].firstMatch.waitForExistence(timeout: 8))
        press(app.buttons["ai-result-source"].firstMatch)
        XCTAssertTrue(textValue(app.staticTexts["page-position"].firstMatch).contains("1 / 2"))
        press(app.buttons["open-epub-sample"].firstMatch)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        let paragraph = try webText(in: app, matching: "window", prefix: true, timeout: 10)
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        press(app.buttons["epub-ai"].firstMatch)
        XCTAssertTrue(app.staticTexts["ai-source-quote"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["ai-saved-user-note"].firstMatch.exists)
        let kind = app.popUpButtons["ai-kind"].firstMatch
        XCTAssertTrue(kind.waitForExistence(timeout: 5)); press(kind); press(app.menuItems["选文解释"].firstMatch)
        press(consent); press(start)
        XCTAssertTrue(result.waitForExistence(timeout: 8)); XCTAssertTrue(textValue(result).contains("解释"))
        press(app.buttons["ai-save-note"].firstMatch)
        XCTAssertTrue(app.staticTexts["ai-saved-result"].firstMatch.waitForExistence(timeout: 8))
        press(app.buttons["ai-result-source"].firstMatch)
        app.terminate(); app.launch(); app.activate()
        let book = app.descendants(matching: .any).matching(identifier: "library-epub").firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        press(app.buttons["epub-ai"].firstMatch)
        let saved = app.staticTexts["ai-saved-result"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 8)); XCTAssertTrue(textValue(saved).contains("解释"))
        XCTAssertTrue(textValue(app.staticTexts["ai-reading-key-status"].firstMatch).contains("请先"))
        XCTAssertFalse(start.isEnabled, "No session key may persist across restart")
        app.terminate()
    }
    @MainActor func testMacAISelectionConsentMockNotesAndRestart() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate()
        let sample = app.buttons["open-sample"].firstMatch
        XCTAssertTrue(sample.waitForExistence(timeout: 15)); press(sample)
        press(app.buttons["reader-navigation"].firstMatch)
        let search = app.textFields["search-input"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); enterSearch("window", into: search)
        press(app.buttons["search-submit"].firstMatch)
        let match = app.buttons["search-result"].firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 5)); press(match)
        press(app.buttons["reader-ai"].firstMatch)
        let start = app.buttons["ai-start"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5)); XCTAssertFalse(start.isEnabled)
        let source = app.staticTexts["ai-source-quote"].firstMatch
        XCTAssertEqual(textValue(source), "window")
        let consent = app.descendants(matching: .any).matching(identifier: "ai-scope-consent").firstMatch
        press(consent); XCTAssertTrue(start.isEnabled); press(start)
        let error = app.staticTexts["ai-error"].firstMatch
        XCTAssertTrue(error.waitForExistence(timeout: 5)); XCTAssertTrue(textValue(error).contains("未配置"))
        XCTAssertFalse(app.staticTexts["ai-result"].firstMatch.exists)
        press(app.buttons["ai-close"].firstMatch)
        press(app.buttons["ai-settings"].firstMatch)
        let mock = app.buttons["ai-use-mock"].firstMatch
        XCTAssertTrue(mock.waitForExistence(timeout: 5)); press(mock)
        press(app.buttons["ai-settings-save"].firstMatch)
        press(app.buttons["reader-ai"].firstMatch)
        XCTAssertTrue(start.waitForExistence(timeout: 5)); XCTAssertFalse(start.isEnabled)
        press(consent); press(start)
        let result = app.staticTexts["ai-result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 8)); XCTAssertTrue(textValue(result).contains("本地 mock"))
        let note = app.descendants(matching: .any).matching(identifier: "ai-user-note").firstMatch
        XCTAssertTrue(note.waitForExistence(timeout: 5)); enterSearch("Original synthetic AI user note", into: note)
        press(app.buttons["ai-save-note"].firstMatch)
        let userNote = app.staticTexts["ai-saved-user-note"].firstMatch
        XCTAssertTrue(userNote.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(userNote), "Original synthetic AI user note")
        press(app.buttons["ai-result-source"].firstMatch)
        XCTAssertTrue(textValue(app.staticTexts["page-position"].firstMatch).contains("1 / 2"))
        app.terminate(); app.launch(); app.activate()
        let book = app.descendants(matching: .any).matching(identifier: "library-book").firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        press(app.buttons["reader-ai"].firstMatch)
        XCTAssertTrue(userNote.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(userNote), "Original synthetic AI user note")
        XCTAssertEqual(textValue(app.staticTexts["ai-saved-quote"].firstMatch), "window")
        press(app.buttons["ai-saved-source"].firstMatch)
        let epubSample = app.buttons["open-epub-sample"].firstMatch
        XCTAssertTrue(epubSample.waitForExistence(timeout: 5)); press(epubSample)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        let paragraph = try webText(in: app, matching: "window", prefix: true, timeout: 10)
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        press(app.buttons["epub-ai"].firstMatch)
        XCTAssertTrue(source.waitForExistence(timeout: 8)); XCTAssertFalse(textValue(source).isEmpty)
        XCTAssertFalse(userNote.exists, "PDF user notes must not appear under another EPUB book")
        let kind = app.popUpButtons["ai-kind"].firstMatch
        XCTAssertTrue(kind.waitForExistence(timeout: 5)); press(kind)
        press(app.menuItems["选文解释"].firstMatch)
        press(consent); press(start)
        XCTAssertTrue(result.waitForExistence(timeout: 8)); XCTAssertTrue(textValue(result).contains("本地 mock"))
        XCTAssertTrue(textValue(result).contains("解释"))
        press(app.buttons["ai-save-note"].firstMatch)
        XCTAssertTrue(app.staticTexts["ai-saved-quote"].firstMatch.waitForExistence(timeout: 8))
        press(app.buttons["ai-saved-source"].firstMatch)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 10)
        app.terminate()
    }
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
