// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import XCTest
#if os(macOS)
import AppKit
import PDFKit
#endif

final class NativeUITests: XCTestCase {
    // Navigation driver only: existing behavior assertions remain in the methods.
    @MainActor private func navigateWorkspace(_ id: String, in app: XCUIApplication) {
        #if os(macOS)
        func target(_ name: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: name).firstMatch }
        if target(id).exists { return }
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
                if !target(id).waitForExistence(timeout: 2), target("library-category-examples").exists {
                    target("library-category-examples").click()
                }
            }
        }
        #endif
    }

    #if os(macOS)
    // New four-slice acceptance: compile locally, run only on the authorized
    // isolated CI/OS user. Original fixtures, UUID stores and intercepted AI only.
    @MainActor func testMacSavedTextBodyDraftRestartUnifiedSearchAndExactSource() throws {
        try runSavedRecordParityUI(ebook: false)
    }
    @MainActor func testMacSavedMOBIBodyDraftRestartUnifiedSearchAndExactSource() throws {
        try runSavedRecordParityUI(ebook: true)
    }
    @MainActor private func scrollRecordElement(_ element: XCUIElement, listID: String, app: XCUIApplication) {
        let list = japaneseElement(listID, in: app)
        XCTAssertTrue(list.waitForExistence(timeout: 5)); XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let viewport = list.frame.insetBy(dx: 4, dy: 8), target = element.frame
            if !target.isEmpty, viewport.contains(target), element.isHittable { return }
            let delta: CGFloat = target.minY < viewport.minY
                ? min(300, max(48, viewport.minY - target.minY + 16))
                : -min(300, max(48, target.maxY - viewport.maxY + 16))
            list.scroll(byDeltaX: 0, deltaY: delta)
        }
        XCTAssertTrue(list.frame.insetBy(dx: 4, dy: 8).contains(element.frame))
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func enterRecordBody(_ text: String, prefix: String, listID: String, app: XCUIApplication) {
        let input = japaneseElement(prefix + "-edit-input", in: app)
        scrollRecordElement(input, listID: listID, app: app)
        input.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.15)).click()
        input.typeKey("a", modifierFlags: .command)
        let board = NSPasteboard.general
        board.clearContents(); board.setString(text, forType: .string)
        input.typeKey("v", modifierFlags: .command)
        waitForEditingValue(text, in: input)
        waitForText(["正文未保存"], in: japaneseElement(prefix + "-edit-status", in: app), timeout: 5)
    }
    @MainActor private func runSavedRecordParityUI(ebook: Bool) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Record-UI-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate(); defer { app.terminate() }
        let prefix = ebook ? "ebook" : "textformat", manifest = ebook ? "ebook-kookit-v1.json" : "text-formats-v1.json"
        let input = root.appendingPathComponent("Original parity.txt")
        let original = Data("Chapter 1\nwindow original 日本語 cafe\u{301}\nChapter 2\nOriginal end".utf8)
        if ebook {
            navigateWorkspace("open-ebook-sample", in: app)
            let menu = japaneseElement("open-ebook-sample", in: app)
            navigateWorkspace("open-ebook-sample", in: app)
            XCTAssertTrue(menu.waitForExistence(timeout: 15)); press(menu)
            navigateWorkspace("open-ebook-sample-mobi", in: app)
            let item = japaneseElement("open-ebook-sample-mobi", in: app)
            XCTAssertTrue(item.waitForExistence(timeout: 5)); press(item)
        } else {
            try original.write(to: input)
            navigateWorkspace("import-pdf", in: app)
            XCTAssertTrue(app.buttons["import-pdf"].firstMatch.waitForExistence(timeout: 15))
            navigateWorkspace("import-pdf", in: app)
            try chooseInput(input, trigger: app.buttons["import-pdf"].firstMatch, app: app)
        }
        let navigation = app.buttons[prefix + "-navigation"].firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        let paragraph = try webText(in: app, matching: ebook ? "Original source" : "window", prefix: true, timeout: 10)
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        press(app.buttons[prefix + "-notes"].firstMatch)
        let selection = japaneseElement(prefix + "-selection", in: app)
        XCTAssertTrue(selection.waitForExistence(timeout: 8)); let quote = textValue(selection)
        XCTAssertFalse(quote.isEmpty)
        enterSearch("Original committed parity body", into: japaneseElement(prefix + "-user-note", in: app))
        press(app.buttons[prefix + "-save-note"].firstMatch)
        let editor = app.buttons[prefix + "-note-edit"].firstMatch, listID = prefix + "-notes-list"
        XCTAssertTrue(editor.waitForExistence(timeout: 8), "Read the manifest only after the saved row is published")
        let before = try originalSavedNote(token, manifest: manifest)
        scrollRecordElement(editor, listID: listID, app: app); press(editor)
        enterRecordBody("Original uncommitted draft 日本語", prefix: prefix + "-note", listID: listID, app: app)
        XCTAssertEqual(try originalSavedNote(token, manifest: manifest)["userText"] as? String, "Original committed parity body")
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace(ebook ? "library-ebook-mobi" : "library-textformat", in: app)
        let row = japaneseElement(ebook ? "library-ebook-mobi" : "library-textformat", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 15)); press(row)
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        press(app.buttons[prefix + "-notes"].firstMatch)
        let recovered = japaneseElement(prefix + "-note-edit-input", in: app)
        scrollRecordElement(recovered, listID: listID, app: app)
        XCTAssertEqual(textValue(recovered), "Original uncommitted draft 日本語")
        let cancel = app.buttons[prefix + "-note-edit-cancel"].firstMatch
        scrollRecordElement(cancel, listID: listID, app: app); press(cancel)
        scrollRecordElement(editor, listID: listID, app: app); press(editor)
        let body = "Saved parity body cafe\u{301} 日本語"
        enterRecordBody(body, prefix: prefix + "-note", listID: listID, app: app)
        let save = app.buttons[prefix + "-note-edit-save"].firstMatch
        scrollRecordElement(save, listID: listID, app: app); press(save)
        waitForText(["已保存"], in: japaneseElement(prefix + "-note-edit-status", in: app), timeout: 8)
        let after = try originalSavedNote(token, manifest: manifest)
        XCTAssertEqual(after["userText"] as? String, body); XCTAssertEqual(after["anchor"] as? NSDictionary, before["anchor"] as? NSDictionary)
        press(app.buttons[prefix + "-close-notes"].firstMatch); press(app.buttons["library-search"].firstMatch)
        let search = app.textFields["library-search-input"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8)); enterSearch("saved parity body CAFÉ", into: search)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        let preview = japaneseElement("record-search-preview", in: app)
        XCTAssertTrue(preview.waitForExistence(timeout: 5)); XCTAssertTrue(textValue(preview).contains("Saved parity"))
        press(app.buttons["record-search-source"].firstMatch)
        XCTAssertTrue(navigation.waitForExistence(timeout: 25))
        waitUntilEnabled(navigation)
        press(app.buttons[prefix + "-notes"].firstMatch)
        let returnedQuote = app.staticTexts[prefix + "-saved-quote"].firstMatch
        XCTAssertTrue(returnedQuote.waitForExistence(timeout: 8))
        XCTAssertEqual(textValue(returnedQuote), quote)
        XCTAssertEqual(try originalSavedNote(token, manifest: manifest)["anchor"] as? NSDictionary, before["anchor"] as? NSDictionary)
        if !ebook { XCTAssertEqual(try Data(contentsOf: input), original) }
    }
    @MainActor func testMacJapaneseSavedBodyEditingSearchKeepsReviewAndCorrections() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchEnvironment["PDFNO_UI_TEST_JAPANESE_RESPONSE"] = "components"
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareJapaneseOfflinePDF(app); startJapaneseReview(app)
        waitForText(["收到可审阅建议"], in: japaneseElement("japanese-learning-status", in: app), timeout: 8)
        let saveReview = app.buttons["japanese-learning-save"].firstMatch
        scrollJapaneseElement(saveReview, in: app); press(saveReview)
        waitForText(["已保存独立学习记录"], in: japaneseElement("japanese-learning-status", in: app), timeout: 8)
        let before = try originalSavedNote(token, manifest: "japanese-learning-v1.json")
        press(app.buttons["japanese-learning-close"].firstMatch); press(app.buttons["reader-notes"].firstMatch)
        pressEditingElement(app.buttons["japanese-note-edit"].firstMatch, app: app)
        enterEditingText("Saved Japanese parity body cafe\u{301}", prefix: "japanese-note", app: app)
        pressEditingElement(app.buttons["japanese-note-edit-save"].firstMatch, app: app)
        waitForText(["已保存"], in: japaneseElement("japanese-note-edit-status", in: app), timeout: 8)
        let after = try originalSavedNote(token, manifest: "japanese-learning-v1.json")
        XCTAssertEqual(after["review"] as? NSDictionary, before["review"] as? NSDictionary)
        XCTAssertEqual(after["corrections"] as? NSArray, before["corrections"] as? NSArray)
        XCTAssertEqual(after["userText"] as? String, "Saved Japanese parity body cafe\u{301}")
        press(app.buttons["close-notes"].firstMatch); press(app.buttons["library-search"].firstMatch)
        enterSearch("saved Japanese parity CAFÉ", into: app.textFields["library-search-input"].firstMatch)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        press(app.buttons["record-search-source"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 10)
        XCTAssertEqual(try originalSavedNote(token, manifest: "japanese-learning-v1.json")["review"] as? NSDictionary, before["review"] as? NSDictionary)
    }
    @MainActor private func scrollBYOKElement(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews["byok-selection-workspace"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5)); XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let viewport = scroll.frame.insetBy(dx: 4, dy: 8), target = element.frame
            if !target.isEmpty, viewport.contains(target), element.isHittable { return }
            let delta: CGFloat = target.minY < viewport.minY ? 250 : -250
            scroll.scroll(byDeltaX: 0, deltaY: delta)
        }
        XCTAssertTrue(element.isHittable)
    }
    @MainActor func testMacBYOKExplicitRecipientManualSaveAndDefaultChainsStaySeparate() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app)
        press(app.buttons["reader-byok"].firstMatch)
        guard japaneseElement("byok-offline-fixture", in: app).waitForExistence(timeout: 5) else {
            throw NSError(domain: "PDFno-Offline-BYOK-UI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Intercepted BYOK transport required before synthetic credential"])
        }
        press(app.buttons["byok-selection-settings"].firstMatch)
        let endpoint = app.textFields["byok-endpoint"].firstMatch
        XCTAssertTrue(endpoint.waitForExistence(timeout: 5)); enterSearch("https://joint-ui.example/v1", into: endpoint, replacing: true)
        enterSearch("original-ui-model", into: app.textFields["byok-model"].firstMatch, replacing: true)
        let key = japaneseElement("byok-session-key", in: app)
        XCTAssertTrue(key.waitForExistence(timeout: 5)); enterSearch("synthetic-reading-ui-credential", into: key, replacing: true)
        press(app.buttons["byok-apply"].firstMatch)
        waitForText(["仅在本次会话生效"], in: japaneseElement("byok-settings-status", in: app), timeout: 5)
        let settingsClose = app.buttons["byok-settings-close"].firstMatch
        press(settingsClose)
        let settingsDismissed = expectation(for: NSPredicate { _, _ in !settingsClose.exists }, evaluatedWith: app)
        wait(for: [settingsDismissed], timeout: 10)
        let recapture = app.buttons["byok-recapture"].firstMatch
        XCTAssertTrue(recapture.waitForExistence(timeout: 5)); waitUntilEnabled(recapture); press(recapture)
        let domain = japaneseElement("byok-consent-domain", in: app)
        XCTAssertTrue(domain.waitForExistence(timeout: 5)); XCTAssertTrue(textValue(domain).contains("joint-ui.example"))
        let consentSource = app.staticTexts["byok-consent-source"].firstMatch
        XCTAssertTrue(consentSource.waitForExistence(timeout: 5))
        XCTAssertEqual(textValue(consentSource), "window")
        let send = app.buttons["byok-send"].firstMatch, consent = japaneseElement("byok-confirm", in: app)
        scrollBYOKElement(send, in: app); XCTAssertFalse(send.isEnabled)
        scrollBYOKElement(consent, in: app); press(consent)
        scrollBYOKElement(send, in: app); waitUntilEnabled(send); press(send)
        let result = japaneseElement("byok-result", in: app)
        XCTAssertTrue(result.waitForExistence(timeout: 8)); XCTAssertTrue(textValue(result).contains("离线"))
        let body = japaneseElement("byok-user-note", in: app)
        scrollBYOKElement(body, in: app); enterSearch("Original saved BYOK body", into: body)
        let save = app.buttons["byok-save-note"].firstMatch
        scrollBYOKElement(save, in: app); press(save)
        waitForText(["已保存"], in: japaneseElement("byok-save-status", in: app), timeout: 8)
        let saved = try originalSavedNote(token, manifest: "learning-v1.json")
        let savedResult = try XCTUnwrap(saved["result"] as? [String: Any])
        XCTAssertEqual((savedResult["provider"] as? [String: Any])?["endpoint"] as? String, "https://joint-ui.example/v1")
        XCTAssertEqual(saved["userText"] as? String, "Original saved BYOK body")
        let store = URL(fileURLWithPath: "/tmp").appendingPathComponent("PDFno-UITests-" + token).appendingPathComponent("learning-v1.json")
        XCTAssertFalse(String(decoding: try Data(contentsOf: store), as: UTF8.self).contains("synthetic-reading-ui-credential"))
        press(app.buttons["byok-close"].firstMatch)
        navigateWorkspace("ai-settings", in: app)
        let originalSettings = app.buttons["ai-settings"].firstMatch
        navigateWorkspace("ai-settings", in: app)
        XCTAssertTrue(originalSettings.waitForExistence(timeout: 5)); waitUntilEnabled(originalSettings); press(originalSettings)
        XCTAssertTrue(app.buttons["ai-use-deepseek"].firstMatch.waitForExistence(timeout: 5))
        press(app.buttons["byok-settings-open"].firstMatch)
        XCTAssertTrue(endpoint.waitForExistence(timeout: 5)); enterSearch("https://different-ui.example/v1", into: endpoint, replacing: true)
        waitForText(["旧会话密钥已撤销"], in: japaneseElement("byok-settings-status", in: app), timeout: 5)
        XCTAssertEqual(key.value as? String, "")
        XCTAssertEqual(try originalSavedNote(token, manifest: "learning-v1.json")["result"] as? NSDictionary, NSDictionary(dictionary: savedResult))
    }
    @MainActor func testMacDOCXReadingPDFEntryCancelExportAndOverwriteRefusal() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Reading-PDF-UI-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Original UI.docx"), original = originalSemanticDOCX()
        try original.write(to: source)
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("document-conversion", in: app)
        let entry = app.buttons["document-conversion"].firstMatch
        navigateWorkspace("document-conversion", in: app)
        XCTAssertTrue(entry.waitForExistence(timeout: 15)); press(entry)
        XCTAssertTrue(app.buttons["conversion-export"].firstMatch.waitForExistence(timeout: 5))
        press(app.buttons["reading-pdf-open"].firstMatch)
        let export = app.buttons["reading-pdf-export"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 5)); XCTAssertFalse(export.isEnabled)
        try chooseInput(source, trigger: app.buttons["reading-pdf-source"].firstMatch, app: app)
        waitUntilEnabled(export); press(export)
        XCTAssertTrue(filePanelButton(app, titles: ["Save", "保存"]).waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: []); waitUntilEnabled(export)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path), [source.lastPathComponent])
        let output = root.appendingPathComponent("Original Reading.pdf")
        try chooseOutput(output, defaultName: "Original UI-阅读版.pdf", trigger: export, app: app)
        waitForText(["已保存阅读版PDF"], in: japaneseElement("reading-pdf-status", in: app), timeout: 25)
        let installed = try Data(contentsOf: output), pdf = try XCTUnwrap(PDFDocument(data: installed))
        XCTAssertGreaterThan(pdf.pageCount, 0); XCTAssertTrue(pdf.string?.contains("window") == true)
        XCTAssertEqual(try Data(contentsOf: source), original)
        try chooseOutput(output, defaultName: "Original UI-阅读版.pdf", trigger: export, app: app)
        waitForText(["输出位置已有文件"], in: japaneseElement("reading-pdf-status", in: app), timeout: 15)
        XCTAssertEqual(try Data(contentsOf: output), installed); XCTAssertEqual(try Data(contentsOf: source), original)
    }
    // UI foundation acceptance is compile-only locally. Run on an isolated CI/OS user.
    @MainActor func testMacLibraryLayoutSelectionAndOriginalSampleEntrypoints() throws {
        let app = XCUIApplication()
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("library-list-layout", in: app)
        let list = app.buttons["library-list-layout"].firstMatch
        navigateWorkspace("library-grid-layout", in: app)
        let grid = app.buttons["library-grid-layout"].firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 10)); XCTAssertTrue(grid.exists)
        XCTAssertEqual(list.value as? String, "已选中")
        navigateWorkspace("library-grid-layout", in: app)
        press(grid); XCTAssertEqual(grid.value as? String, "已选中")
        XCTAssertEqual(list.value as? String, "未选中")
        XCTAssertTrue(japaneseElement("library-empty-state", in: app).exists)
        navigateWorkspace("library-list-layout", in: app)
        press(list); XCTAssertEqual(list.value as? String, "已选中")
        for id in ["open-sample", "open-epub-sample", "open-docx-sample", "bookno-preview-open", "import-pdf", "open-ebook-sample"] {
            if id == "import-pdf" { app.typeKey(.escape, modifierFlags: []) }
            navigateWorkspace(id, in: app)
            XCTAssertTrue(japaneseElement(id, in: app).exists, "Existing entry must remain: " + id)
        }
        navigateWorkspace("open-sample", in: app)
        press(app.buttons["open-sample"].firstMatch)
        XCTAssertTrue(app.staticTexts["page-position"].firstMatch.waitForExistence(timeout: 15))
    }
    @MainActor func testMacPDFPanelSwitchRetainsOriginalSelectionAndUnsavedDraft() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app)
        press(app.buttons["reader-notes"].firstMatch)
        let input = japaneseElement("note-input", in: app)
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        let draft = "Original shell draft 日本語 cafe\u{301} 👩🏽‍🚀"
        enterSearch(draft, into: input)
        press(app.buttons["reader-navigation"].firstMatch)
        let search = app.textFields["search-input"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); XCTAssertEqual(textValue(search), "window")
        // Both panels may dock on a wide CI screen; close navigation before returning.
        press(app.buttons["close-navigation"].firstMatch)
        if !input.exists { press(app.buttons["reader-notes"].firstMatch) }
        XCTAssertTrue(input.waitForExistence(timeout: 5)); XCTAssertEqual(textValue(input), draft)
        press(app.buttons["close-notes"].firstMatch)
        press(app.buttons["reader-notes"].firstMatch)
        XCTAssertTrue(input.waitForExistence(timeout: 5)); XCTAssertEqual(textValue(input), draft)
        press(app.buttons["save-note"].firstMatch)
        let saved = try originalSavedNote(token, manifest: "library-v1.json")
        XCTAssertEqual(saved["userText"] as? String, draft)
        XCTAssertEqual((saved["anchor"] as? [String: Any])?["quote"] as? String, "window")
        press(app.buttons["return-to-source"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
    }
    // Japanese flows extend the original 30 tests without modifying them. Compile locally;
    // execute only on the authorized isolated CI host, using UUID stores and an intercepted
    // transport. Confirm the visible offline marker BEFORE entering a synthetic credential.
    @MainActor private func japaneseElement(_ id: String, in app: XCUIApplication) -> XCUIElement {
        // Native Menu controls on macOS 15 can expose a custom identifier in
        // their identifiers collection without using it as the primary identifier.
        // Keep the existing entry assertion and resolve that exact native identifier.
        if id == "open-ebook-sample" {
            return app.descendants(matching: .any).matching(identifier: id).firstMatch
        }
        // Exact AX identifier avoids title/label alias resolution during broad snapshot queries.
        return app.descendants(matching: .any).matching(NSPredicate(format: "identifier == %@", id)).firstMatch
    }
    @MainActor private func scrollJapaneseElement(_ element: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 8))
        let form = japaneseElement("japanese-learning-form", in: app)
        XCTAssertTrue(form.waitForExistence(timeout: 5))
        // The review Form exposes its own vertical ScrollView by this stable identifier.
        // Never enumerate global/index-bound scroll nodes: the underlying EPUB WebKit
        // accessibility tree can change while the native review is opening.
        let scroll = app.scrollViews["japanese-learning-form"].firstMatch
        guard scroll.waitForExistence(timeout: 5) else {
            XCTFail("Japanese review must expose its own vertical viewport"); return
        }
        XCTAssertGreaterThan(scroll.frame.height, 250, "The review viewport must be vertical, not its horizontal legend")
        for _ in 0..<16 {
            let viewport = scroll.frame.insetBy(dx: 4, dy: 8), target = element.frame
            if !target.isEmpty, viewport.contains(target), element.isHittable { return }
            let delta: CGFloat = target.minY < viewport.minY
                ? min(280, max(48, viewport.minY - target.minY + 16))
                : -min(280, max(48, target.maxY - viewport.maxY + 16))
            scroll.scroll(byDeltaX: 0, deltaY: delta)
        }
        XCTAssertTrue(scroll.frame.insetBy(dx: 4, dy: 8).contains(element.frame))
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func pressJapaneseEntry(_ entry: XCUIElement, in app: XCUIApplication) {
        XCTAssertTrue(entry.waitForExistence(timeout: 8))
        let ready = expectation(for: NSPredicate { _, _ in
            entry.exists && entry.isEnabled && entry.isHittable
        }, evaluatedWith: entry)
        wait(for: [ready], timeout: 10)
        let visible = entry.exists && entry.isEnabled && entry.isHittable
            && app.windows.firstMatch.frame.contains(entry.frame)
        XCTAssertTrue(visible, "Japanese entry must be enabled and physically inside its native window")
        guard visible else {
            print("Original Japanese entry: window=\(app.windows.firstMatch.frame), entry=\(entry.frame), enabled=\(entry.isEnabled), hittable=\(entry.isHittable)")
            return
        }
        press(entry)
    }
    @MainActor private func prepareJapaneseOfflinePDF(_ app: XCUIApplication) throws {
        try prepareOriginalPDFNoteEditing(app)
        pressJapaneseEntry(app.buttons["reader-japanese-learning"].firstMatch, in: app)
        guard japaneseElement("japanese-offline-fixture", in: app).waitForExistence(timeout: 5) else {
            throw NSError(domain: "PDFno-Offline-UI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fully intercepted Japanese transport required before synthetic key entry"])
        }
        XCTAssertFalse(app.buttons["japanese-learning-start"].firstMatch.isEnabled)
        press(app.buttons["japanese-learning-close"].firstMatch)
        navigateWorkspace("ai-settings", in: app)
        press(app.buttons["ai-settings"].firstMatch)
        XCTAssertTrue(app.buttons["ai-use-deepseek"].firstMatch.waitForExistence(timeout: 5))
        press(app.buttons["ai-use-deepseek"].firstMatch)
        let key = japaneseElement("ai-session-key", in: app)
        XCTAssertTrue(key.waitForExistence(timeout: 5)); enterSearch("synthetic-reading-ui-credential", into: key, replacing: true)
        press(app.buttons["ai-settings-save"].firstMatch)
        pressJapaneseEntry(app.buttons["reader-japanese-learning"].firstMatch, in: app)
        XCTAssertTrue(japaneseElement("japanese-learning-source", in: app).waitForExistence(timeout: 5))
        XCTAssertEqual(textValue(japaneseElement("japanese-learning-source", in: app)), "window")
    }
    @MainActor private func startJapaneseReview(_ app: XCUIApplication) {
        let start = app.buttons["japanese-learning-start"].firstMatch
        scrollJapaneseElement(start, in: app); XCTAssertFalse(start.isEnabled)
        let consent = japaneseElement("japanese-learning-consent", in: app)
        scrollJapaneseElement(consent, in: app); press(consent)
        scrollJapaneseElement(start, in: app); XCTAssertTrue(start.isEnabled); press(start)
    }
    @MainActor private func verifyJapaneseAppearanceAndAccessibleLegend(_ app: XCUIApplication, appearance: String) {
        waitForText(["隔离 UI 外观：" + appearance], in: japaneseElement("japanese-fixture-appearance", in: app), timeout: 5)
        let source = japaneseElement("japanese-components-source", in: app)
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        // Selectable macOS Text exposes its readable content as AX value, rather than label.
        let sourceText = textValue(source)
        let expectedSource = textValue(japaneseElement("japanese-learning-source", in: app))
        XCTAssertFalse(expectedSource.isEmpty); XCTAssertEqual(sourceText, expectedSource)
        var verified = !expectedSource.isEmpty && sourceText == expectedSource
            && textValue(japaneseElement("japanese-fixture-appearance", in: app)).contains("隔离 UI 外观：" + appearance)
        let legend = japaneseElement("japanese-components-legend", in: app)
        scrollJapaneseElement(legend, in: app)
        for (role, label) in [("subject", "蓝色：主语"), ("predicate", "红色：谓语"), ("object", "绿色：宾语"),
                              ("attributive", "紫色：定语／修饰语"), ("adverbial", "橙色：状语"), ("topic", "青色：主题"), ("other", "正文色：其他结构")] {
            let item = japaneseElement("japanese-component-legend-" + role, in: app)
            XCTAssertTrue(item.waitForExistence(timeout: 5)); XCTAssertEqual(item.label, label)
            verified = verified && item.exists && item.label == label
        }
        guard verified else { return }
        // App-owned original-fixture window only; never captures the CI desktop or other apps.
        let snapshot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        snapshot.name = "Original Japanese review " + appearance + " with accessible color legend"
        snapshot.lifetime = .keepAlways; add(snapshot)
        print("Japanese actual UI verified appearance=" + appearance + "; seven AX role/color labels present; exact source AX text=" + sourceText)
    }
    @MainActor func testMacJapaneseOfflineConsentComponentSwitchManualSaveRestartExactPDFReturn() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        let root = URL(fileURLWithPath: "/tmp").appendingPathComponent("PDFno-UITests-" + token)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchEnvironment["PDFNO_UI_TEST_JAPANESE_RESPONSE"] = "components"
        app.launchEnvironment["PDFNO_UI_TEST_JAPANESE_APPEARANCE"] = "light"
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareJapaneseOfflinePDF(app)
        let legacy = root.appendingPathComponent("library-v1.json"), oldBytes = try Data(contentsOf: legacy)
        startJapaneseReview(app)
        waitForText(["收到可审阅建议", "未自动保存"], in: japaneseElement("japanese-learning-status", in: app), timeout: 8)
        verifyJapaneseAppearanceAndAccessibleLegend(app, appearance: "浅色")
        let manifest = root.appendingPathComponent("japanese-learning-v1.json")
        XCTAssertFalse(FileManager.default.fileExists(atPath: manifest.path))
        XCTAssertEqual(textValue(japaneseElement("japanese-components-source", in: app)), "window")
        let overlap = japaneseElement("japanese-components-overlap", in: app)
        scrollJapaneseElement(overlap, in: app)
        XCTAssertTrue(textValue(overlap).contains("一次显示清晰的一层"))
        let subject = app.buttons["japanese-component-subject"].firstMatch
        scrollJapaneseElement(subject, in: app); press(subject)
        waitForText(["合成主语候选", "蓝色"], in: japaneseElement("japanese-component-explanation", in: app), timeout: 5)
        let object = app.buttons["japanese-component-object"].firstMatch
        scrollJapaneseElement(object, in: app); press(object)
        waitForText(["合成宾语候选", "绿色"], in: japaneseElement("japanese-component-explanation", in: app), timeout: 5)
        let omitted = app.buttons["japanese-component-omitted-subject"].firstMatch
        scrollJapaneseElement(omitted, in: app); press(omitted)
        waitForText(["省略", "推测"], in: japaneseElement("japanese-component-selected-label", in: app), timeout: 5)
        XCTAssertEqual(textValue(japaneseElement("japanese-components-source", in: app)), "window")
        let correction = japaneseElement("japanese-learning-correction", in: app)
        scrollJapaneseElement(correction, in: app); enterSearch("ア", into: correction)
        let body = japaneseElement("japanese-learning-user-note", in: app)
        scrollJapaneseElement(body, in: app); enterSearch("Original independent Japanese note か\u{3099}👩🏽‍🚀", into: body)
        let save = app.buttons["japanese-learning-save"].firstMatch
        scrollJapaneseElement(save, in: app); press(save)
        waitForText(["已保存独立学习记录"], in: japaneseElement("japanese-learning-status", in: app), timeout: 8)
        let saved = try originalSavedNote(token, manifest: "japanese-learning-v1.json")
        let review = try XCTUnwrap(saved["review"] as? [String: Any])
        XCTAssertEqual((review["components"] as? [Any])?.count, 4)
        XCTAssertEqual((saved["corrections"] as? [[String: Any]])?.first?["reading"] as? String, "ア")
        XCTAssertEqual(try Data(contentsOf: legacy), oldBytes)
        XCTAssertFalse(String(decoding: try Data(contentsOf: manifest), as: UTF8.self).contains("synthetic-reading-ui-credential"))
        press(app.buttons["japanese-learning-close"].firstMatch)
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-book", in: app)
        let book = japaneseElement("library-book", in: app)
        navigateWorkspace("library-book", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        press(app.buttons["reader-notes"].firstMatch)
        XCTAssertTrue(japaneseElement("japanese-saved-source", in: app).waitForExistence(timeout: 8))
        XCTAssertEqual(textValue(japaneseElement("japanese-saved-source", in: app)), "window")
        let returned = app.buttons["japanese-saved-return"].firstMatch
        scrollEditingElement(returned, app: app); press(returned)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
        pressJapaneseEntry(app.buttons["reader-japanese-learning"].firstMatch, in: app)
        XCTAssertFalse(app.buttons["japanese-learning-start"].firstMatch.isEnabled, "Session key must not survive restart")
    }
    @MainActor func testMacJapaneseNativeEPUBSelectionManualSaveAndSourceReturnPreservesRuby() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchEnvironment["PDFNO_UI_TEST_JAPANESE_APPEARANCE"] = "dark"
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareJapaneseOfflinePDF(app); press(app.buttons["japanese-learning-close"].firstMatch)
        navigateWorkspace("open-epub-sample", in: app)
        press(app.buttons["open-epub-sample"].firstMatch)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        press(app.buttons["epub-contents"].firstMatch); press(app.buttons["epub-chapter-1"].firstMatch)
        waitForText(["第 2 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 15)
        // A new chapter's position event can precede the command reply and sheet dismissal.
        // Wait for the real native controls to settle before selecting body text.
        let tocClosed = expectation(for: NSPredicate { _, _ in !app.buttons["epub-chapter-1"].firstMatch.exists }, evaluatedWith: app)
        wait(for: [tocClosed], timeout: 10)
        let japaneseEntry = app.buttons["epub-japanese-learning"].firstMatch
        let entryReady = expectation(for: NSPredicate { _, _ in
            japaneseEntry.exists && japaneseEntry.isEnabled && japaneseEntry.isHittable
        }, evaluatedWith: japaneseEntry)
        wait(for: [entryReady], timeout: 10)
        XCTAssertTrue(japaneseEntry.isEnabled && japaneseEntry.isHittable)
        let original = try webText(in: app, matching: "日本語", prefix: true, timeout: 10)
        original.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).doubleClick()
        let selectionReady = expectation(for: NSPredicate { _, _ in
            japaneseEntry.exists && japaneseEntry.isEnabled && japaneseEntry.isHittable
        }, evaluatedWith: japaneseEntry)
        wait(for: [selectionReady], timeout: 10)
        XCTAssertTrue(japaneseEntry.isEnabled && japaneseEntry.isHittable)
        pressJapaneseEntry(japaneseEntry, in: app)
        let source = japaneseElement("japanese-learning-source", in: app)
        XCTAssertTrue(source.waitForExistence(timeout: 8))
        let quote = textValue(source); XCTAssertFalse(quote.isEmpty); XCTAssertFalse(quote.contains("にほんご"))
        startJapaneseReview(app)
        waitForText(["收到可审阅建议"], in: japaneseElement("japanese-learning-status", in: app), timeout: 8)
        XCTAssertEqual(textValue(japaneseElement("japanese-components-source", in: app)), quote)
        verifyJapaneseAppearanceAndAccessibleLegend(app, appearance: "深色")
        let subject = app.buttons["japanese-component-subject"].firstMatch
        scrollJapaneseElement(subject, in: app); press(subject)
        waitForText(["合成主语候选", "仅验证"], in: japaneseElement("japanese-component-explanation", in: app), timeout: 5)
        let save = app.buttons["japanese-learning-save"].firstMatch
        scrollJapaneseElement(save, in: app); press(save)
        waitForText(["已保存独立学习记录"], in: japaneseElement("japanese-learning-status", in: app), timeout: 8)
        let saved = try originalSavedNote(token, manifest: "japanese-learning-v1.json")
        let review = try XCTUnwrap(saved["review"] as? [String: Any]), snapshot = try XCTUnwrap(review["source"] as? [String: Any])
        let anchor = try XCTUnwrap(snapshot["anchor"] as? [String: Any]), wrapper = try XCTUnwrap(anchor["epub"] as? [String: Any])
        XCTAssertEqual((wrapper["_0"] as? [String: Any])?["quote"] as? String, quote)
        let returned = app.buttons["japanese-learning-return"].firstMatch
        scrollJapaneseElement(returned, in: app); press(returned)
        waitForText(["第 2 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 10)
        XCTAssertTrue(try webText(in: app, matching: "にほんご", prefix: false, timeout: 10).exists)
        press(app.buttons["epub-notes"].firstMatch)
        XCTAssertTrue(japaneseElement("japanese-saved-source", in: app).waitForExistence(timeout: 8))
        XCTAssertEqual(textValue(japaneseElement("japanese-saved-source", in: app)), quote)
    }
    @MainActor func testMacJapaneseInvalidOutputAndCancelCannotCreateNotesOrLateReview() throws {
        for scenario in ["invalid", "slow"] {
            let app = XCUIApplication(), token = UUID().uuidString
            app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
            app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
            app.launchEnvironment["PDFNO_UI_TEST_JAPANESE_RESPONSE"] = scenario
            app.launch(); app.activate()
            defer { app.terminate() }
            try prepareJapaneseOfflinePDF(app); startJapaneseReview(app)
            if scenario == "invalid" {
                waitForText(["输出无法验证", "仅保留来源"], in: japaneseElement("japanese-learning-status", in: app), timeout: 8)
                XCTAssertFalse(app.buttons["japanese-learning-save"].firstMatch.isEnabled)
                XCTAssertFalse(app.buttons["japanese-component-subject"].firstMatch.exists)
                XCTAssertFalse(japaneseElement("japanese-learning-translation", in: app).exists)
            } else {
                let cancel = app.buttons["japanese-learning-cancel"].firstMatch
                scrollJapaneseElement(cancel, in: app); press(cancel)
                waitForText(["请求已取消", "迟到结果不会显示或保存"], in: japaneseElement("japanese-learning-status", in: app), timeout: 5)
                XCTAssertFalse(japaneseElement("japanese-components-source", in: app).exists)
                press(app.buttons["japanese-learning-close"].firstMatch)
                pressJapaneseEntry(app.buttons["reader-japanese-learning"].firstMatch, in: app)
                XCTAssertFalse(japaneseElement("japanese-components-source", in: app).exists)
            }
            let budget = japaneseElement("japanese-learning-budget", in: app)
            scrollJapaneseElement(budget, in: app)
            waitForText(["已用 1 / 3"], in: budget, timeout: 5)
            let path = URL(fileURLWithPath: "/tmp").appendingPathComponent("PDFno-UITests-" + token).appendingPathComponent("japanese-learning-v1.json")
            XCTAssertFalse(FileManager.default.fileExists(atPath: path.path))
            app.terminate()
        }
    }
    // These flows are for the isolated integration CI host only. They use
    // original bundled books and a fresh UUID store, never real keys/API calls.
    @MainActor private func prepareOriginalPDFNoteEditing(_ app: XCUIApplication) throws {
        navigateWorkspace("open-sample", in: app)
        let sample = app.buttons["open-sample"].firstMatch
        navigateWorkspace("open-sample", in: app)
        XCTAssertTrue(sample.waitForExistence(timeout: 15)); press(sample)
        let position = app.staticTexts["page-position"].firstMatch
        XCTAssertTrue(position.waitForExistence(timeout: 15))
        press(app.buttons["reader-navigation"].firstMatch)
        let search = app.textFields["search-input"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5)); enterSearch("window", into: search)
        press(app.buttons["search-submit"].firstMatch)
        let result = app.buttons["search-result"].firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 5)); press(result)
    }
    @MainActor private func editingInput(_ prefix: String, app: XCUIApplication) -> XCUIElement {
        let input = app.descendants(matching: .any).matching(identifier: prefix + "-edit-input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5)); scrollEditingElement(input, app: app); return input
    }
    @MainActor private func scrollEditingElement(_ element: XCUIElement, app: XCUIApplication) {
        let prefix = element.identifier.hasPrefix("epub-note") ? "epub" : element.identifier.hasPrefix("ai-note") ? "ai" : "pdf"
        let list = app.descendants(matching: .any).matching(identifier: prefix + "-notes-list").firstMatch
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let viewport = list.frame.insetBy(dx: 4, dy: 8), target = element.frame
            if !target.isEmpty, viewport.contains(target), element.isHittable { return }
            let delta: CGFloat = target.minY < viewport.minY
                ? min(300, max(48, viewport.minY - target.minY + 16))
                : -min(300, max(48, target.maxY - viewport.maxY + 16))
            list.scroll(byDeltaX: 0, deltaY: delta)
        }
        XCTAssertTrue(list.frame.insetBy(dx: 4, dy: 8).contains(element.frame), "Editor action must be fully visible inside the notes list")
        XCTAssertTrue(element.isHittable)
    }
    @MainActor private func pressEditingElement(_ element: XCUIElement, app: XCUIApplication) {
        XCTAssertTrue(element.waitForExistence(timeout: 5)); scrollEditingElement(element, app: app); press(element)
    }
    @MainActor private func waitForEditingValue(_ text: String, in input: XCUIElement) {
        let ready = expectation(for: NSPredicate { _, _ in
            input.exists && (input.value as? String) == text
        }, evaluatedWith: input)
        wait(for: [ready], timeout: 5)
        XCTAssertEqual(input.value as? String, text)
    }
    @MainActor private func enterEditingText(_ text: String, prefix: String, app: XCUIApplication) {
        let input = editingInput(prefix, app: app)
        // In a macOS List, the blank centre of a multiline field can select the
        // row. Place the caret in its first line before sending fixture keys.
        input.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.15)).click()
        input.typeKey("a", modifierFlags: .command)
        let board = NSPasteboard.general
        let previous = (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types { if let data = item.data(forType: type) { copy.setData(data, forType: type) } }
            return copy
        }
        board.clearContents(); board.setString(text, forType: .string)
        let change = board.changeCount
        input.typeKey("v", modifierFlags: .command)
        // Verify both the actual control and its model before dismiss/save;
        // a missed keyboard event must fail here, not masquerade as data loss.
        waitForEditingValue(text, in: input)
        waitForText(["正文未保存"], in: app.staticTexts[prefix + "-edit-status"].firstMatch, timeout: 5)
        if board.changeCount == change { board.clearContents(); board.writeObjects(previous) }
    }
    private func originalSavedNote(_ token: String, manifest: String, root: URL? = nil) throws -> [String: Any] {
        let store = root ?? URL(fileURLWithPath: "/tmp", isDirectory: true).appendingPathComponent("PDFno-UITests-" + token)
        let url = store.appendingPathComponent(manifest)
        let state = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        XCTAssertEqual(state["schemaVersion"] as? Int, 1)
        return try XCTUnwrap((state["notes"] as? [[String: Any]])?.first)
    }
    // Added to the original 29 flows. Executed only on an authorized isolated UI
    // host; local integration compiles this test without launching the user app.
    @MainActor func testMacBooknoExplicitOfflinePreviewSavedBodyMockReplayAndClose() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app)
        press(app.buttons["reader-notes"].firstMatch)
        let input = app.descendants(matching: .any).matching(identifier: "note-input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5)); enterSearch("Original saved Bookno body", into: input)
        press(app.buttons["save-note"].firstMatch)
        XCTAssertTrue(app.buttons["pdf-note-edit"].firstMatch.waitForExistence(timeout: 8))
        let saved = try originalSavedNote(token, manifest: "library-v1.json")
        pressEditingElement(app.buttons["pdf-note-edit"].firstMatch, app: app)
        enterEditingText("Original private unsaved Bookno draft", prefix: "pdf-note", app: app)
        press(app.buttons["close-notes"].firstMatch)
        navigateWorkspace("bookno-preview-open", in: app)
        let open = app.buttons["bookno-preview-open"].firstMatch
        navigateWorkspace("bookno-preview-open", in: app)
        XCTAssertTrue(open.waitForExistence(timeout: 5)); press(open)
        let enable = app.checkBoxes["bookno-preview-enabled"].firstMatch
        XCTAssertTrue(enable.waitForExistence(timeout: 5)); XCTAssertEqual(booknoCheckboxState(enable), false)
        let prepare = app.buttons["bookno-prepare"].firstMatch
        XCTAssertTrue(prepare.waitForExistence(timeout: 5)); XCTAssertFalse(prepare.isEnabled)
        press(enable)
        let book = app.checkBoxes.matching(NSPredicate(format: "identifier BEGINSWITH %@", "bookno-book-pdfno:book:pdf:")).firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 5)); scrollBooknoElement(book, in: app); press(book)
        let notes = app.checkBoxes["bookno-include-notes"].firstMatch
        scrollBooknoElement(notes, in: app); XCTAssertEqual(booknoCheckboxState(notes), false); press(notes)
        scrollBooknoElement(prepare, in: app); XCTAssertTrue(prepare.isEnabled); press(prepare)
        waitForText(["2 个对象", "1 本书", "1 条已保存笔记", "0 个封面资产"], in: app.staticTexts["bookno-preview-summary"].firstMatch, timeout: 8)
        let body = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "bookno-note-body-")).firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 5)); XCTAssertEqual(textValue(body), "Original saved Bookno body")
        let quote = app.staticTexts.matching(NSPredicate(format: "identifier BEGINSWITH %@", "bookno-note-quote-")).firstMatch
        XCTAssertEqual(textValue(quote), "window")
        let lose = app.buttons["bookno-mock-lose-receipt"].firstMatch
        scrollBooknoElement(lose, in: app); press(lose)
        waitForText(["尚未确认", "Bookno 未连接"], in: app.staticTexts["bookno-preview-status"].firstMatch, timeout: 5)
        let counts = app.staticTexts["bookno-mock-counts"].firstMatch
        waitForText(["mock 记录 2", "连续确认游标 0"], in: counts, timeout: 5)
        let replay = app.buttons["bookno-run-mock"].firstMatch
        scrollBooknoElement(replay, in: app); press(replay); press(replay)
        waitForText(["mock 记录 2", "连续确认游标 1"], in: counts, timeout: 5)
        waitForText(["不是实际同步", "Bookno 未连接"], in: app.staticTexts["bookno-preview-status"].firstMatch, timeout: 5)
        XCTAssertEqual(NSDictionary(dictionary: try originalSavedNote(token, manifest: "library-v1.json")), NSDictionary(dictionary: saved))
        // Finish the current preview before navigating to its new tools entry.
        // Escape inside navigateWorkspace would otherwise dismiss this sheet.
        press(app.buttons["bookno-preview-close"].firstMatch)
        navigateWorkspace("bookno-preview-open", in: app)
        press(open)
        XCTAssertTrue(enable.waitForExistence(timeout: 5)); XCTAssertEqual(booknoCheckboxState(enable), false)
        XCTAssertFalse(prepare.isEnabled); XCTAssertFalse(app.staticTexts["bookno-preview-summary"].firstMatch.exists)
        XCTAssertFalse(counts.exists)
        let store = URL(fileURLWithPath: "/tmp").appendingPathComponent("PDFno-UITests-" + token)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: store.path).contains { $0.lowercased().contains("bookno") })
    }
    @MainActor private func booknoCheckboxState(_ element: XCUIElement) -> Bool? {
        // XCUIElementAttributes.value is Any?. macOS controls may expose an
        // NSNumber rather than a String; unknown/nil values must still fail.
        let value = element.value
        if let number = value as? NSNumber, number == 0 || number == 1 { return number.boolValue }
        if let text = value as? String, text == "0" || text == "1" { return text == "1" }
        XCTFail("Unsupported native checkbox state: \(String(describing: value))")
        return nil
    }
    @MainActor private func scrollBooknoElement(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews["bookno-preview-scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5)); XCTAssertTrue(element.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let viewport = scroll.frame.insetBy(dx: 4, dy: 8), target = element.frame
            if !target.isEmpty, viewport.contains(target), element.isHittable { return }
            let delta: CGFloat = target.minY < viewport.minY
                ? min(300, max(48, viewport.minY - target.minY + 16))
                : -min(300, max(48, target.maxY - viewport.maxY + 16))
            scroll.scroll(byDeltaX: 0, deltaY: delta)
        }
        XCTAssertTrue(scroll.frame.insetBy(dx: 4, dy: 8).contains(element.frame), "Bookno control must be fully visible inside preview")
        XCTAssertTrue(element.isHittable)
    }
    @MainActor func testMacPDFBodyEditingCancelDraftRestartEmptyAndSource() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app)
        press(app.buttons["reader-notes"].firstMatch)
        let input = app.descendants(matching: .any).matching(identifier: "note-input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5)); enterSearch("Original saved body", into: input)
        press(app.buttons["save-note"].firstMatch)
        let edit = app.buttons["pdf-note-edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 8))
        let before = try originalSavedNote(token, manifest: "library-v1.json")
        pressEditingElement(edit, app: app); enterEditingText("Original cancelled edit", prefix: "pdf-note", app: app)
        pressEditingElement(app.buttons["pdf-note-edit-cancel"].firstMatch, app: app)
        XCTAssertEqual(try originalSavedNote(token, manifest: "library-v1.json")["userText"] as? String, "Original saved body")
        pressEditingElement(edit, app: app); enterEditingText("Original recovered 日本語🌸 café", prefix: "pdf-note", app: app)
        press(app.buttons["close-notes"].firstMatch); press(app.buttons["reader-notes"].firstMatch)
        XCTAssertEqual(textValue(editingInput("pdf-note", app: app)), "Original recovered 日本語🌸 café")
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-book", in: app)
        let book = app.descendants(matching: .any).matching(identifier: "library-book").firstMatch
        navigateWorkspace("library-book", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        XCTAssertTrue(app.buttons["reader-notes"].firstMatch.waitForExistence(timeout: 10)); press(app.buttons["reader-notes"].firstMatch)
        XCTAssertEqual(textValue(editingInput("pdf-note", app: app)), "Original recovered 日本語🌸 café")
        pressEditingElement(app.buttons["pdf-note-edit-save"].firstMatch, app: app)
        waitForText(["已保存到本地"], in: app.staticTexts["pdf-note-edit-status"].firstMatch, timeout: 8)
        let after = try originalSavedNote(token, manifest: "library-v1.json")
        XCTAssertEqual(after["userText"] as? String, "Original recovered 日本語🌸 café")
        XCTAssertEqual(NSDictionary(dictionary: try XCTUnwrap(before["anchor"] as? [String: Any])), NSDictionary(dictionary: try XCTUnwrap(after["anchor"] as? [String: Any])))
        XCTAssertEqual(after["id"] as? String, before["id"] as? String)
        pressEditingElement(edit, app: app)
        let body = editingInput("pdf-note", app: app)
        body.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.15)).click()
        body.typeKey("a", modifierFlags: .command); body.typeKey(.delete, modifierFlags: [])
        waitForEditingValue("", in: body)
        waitForText(["正文未保存"], in: app.staticTexts["pdf-note-edit-status"].firstMatch, timeout: 5)
        pressEditingElement(app.buttons["pdf-note-edit-save"].firstMatch, app: app)
        waitForText(["已保存到本地"], in: app.staticTexts["pdf-note-edit-status"].firstMatch, timeout: 8)
        XCTAssertEqual(try originalSavedNote(token, manifest: "library-v1.json")["userText"] as? String, "")
        XCTAssertEqual(textValue(app.staticTexts["saved-note-quote"].firstMatch), "window")
        press(app.buttons["return-to-source"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
    }
    @MainActor func testMacPDFBodyEditingDiskFailureKeepsDraftAndExplicitRetry() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        let root = URL(fileURLWithPath: "/tmp", isDirectory: true).appendingPathComponent("PDFno-UITests-" + token)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launchEnvironment["PDFNO_UI_TEST_NOTE_FAILURE"] = "backup-directory"
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app)
        press(app.buttons["reader-notes"].firstMatch); press(app.buttons["save-note"].firstMatch)
        let edit = app.buttons["pdf-note-edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 8)); pressEditingElement(edit, app: app)
        enterEditingText("Original failure recovery body", prefix: "pdf-note", app: app)
        let body = editingInput("pdf-note", app: app)
        let manifest = root.appendingPathComponent("library-v1.json")
        let before = try Data(contentsOf: manifest)
        // The UUID-guarded Debug fixture makes a real backup-directory conflict
        // in the app's own sandbox. The runner only reads the resulting bytes.
        pressEditingElement(app.buttons["pdf-note-edit-save"].firstMatch, app: app)
        waitForText(["保存失败", "草稿保留"], in: app.staticTexts["pdf-note-edit-status"].firstMatch, timeout: 8)
        XCTAssertEqual(try Data(contentsOf: manifest), before)
        XCTAssertEqual(textValue(body), "Original failure recovery body")
        pressEditingElement(app.buttons["pdf-note-edit-save"].firstMatch, app: app)
        waitForText(["已保存到本地"], in: app.staticTexts["pdf-note-edit-status"].firstMatch, timeout: 8)
        XCTAssertEqual(try originalSavedNote(token, manifest: "library-v1.json", root: root)["userText"] as? String, "Original failure recovery body")
        XCTAssertEqual(textValue(app.staticTexts["saved-note-quote"].firstMatch), "window")
    }
    @MainActor func testMacEPUBBodyEditingBookSwitchRestartAndSource() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("open-epub-sample", in: app)
        XCTAssertTrue(app.buttons["open-epub-sample"].firstMatch.waitForExistence(timeout: 15)); press(app.buttons["open-epub-sample"].firstMatch)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        let paragraph = try webText(in: app, matching: "window", prefix: true, timeout: 10)
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        press(app.buttons["epub-notes"].firstMatch)
        XCTAssertTrue(app.buttons["epub-save-note"].firstMatch.waitForExistence(timeout: 8)); press(app.buttons["epub-save-note"].firstMatch)
        let edit = app.buttons["epub-note-edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 8))
        let before = try originalSavedNote(token, manifest: "epub-v1.json")
        pressEditingElement(edit, app: app); enterEditingText("Original EPUB edited body 日本語🌸", prefix: "epub-note", app: app)
        press(app.buttons["epub-close-notes"].firstMatch)
        navigateWorkspace("open-sample", in: app)
        press(app.buttons["open-sample"].firstMatch)
        XCTAssertTrue(app.buttons["reader-notes"].firstMatch.waitForExistence(timeout: 15)); press(app.buttons["reader-notes"].firstMatch)
        XCTAssertFalse(app.buttons["epub-note-edit-save"].firstMatch.exists)
        press(app.buttons["close-notes"].firstMatch)
        navigateWorkspace("library-epub", in: app)
        let book = app.descendants(matching: .any).matching(identifier: "library-epub").firstMatch
        navigateWorkspace("library-epub", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 8)); press(book)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        press(app.buttons["epub-notes"].firstMatch)
        XCTAssertEqual(textValue(editingInput("epub-note", app: app)), "Original EPUB edited body 日本語🌸")
        pressEditingElement(app.buttons["epub-note-edit-save"].firstMatch, app: app)
        waitForText(["已保存到本地"], in: app.staticTexts["epub-note-edit-status"].firstMatch, timeout: 8)
        let after = try originalSavedNote(token, manifest: "epub-v1.json")
        XCTAssertEqual(Set(before.keys), Set(after.keys))
        XCTAssertEqual(NSDictionary(dictionary: try XCTUnwrap(before["anchor"] as? [String: Any])), NSDictionary(dictionary: try XCTUnwrap(after["anchor"] as? [String: Any])))
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-epub", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        XCTAssertTrue(app.buttons["epub-notes"].firstMatch.waitForExistence(timeout: 25)); press(app.buttons["epub-notes"].firstMatch)
        let body = app.staticTexts["epub-saved-user-text"].firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(body), "Original EPUB edited body 日本語🌸")
        press(app.buttons["epub-return"].firstMatch)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 10)
    }
    @MainActor func testMacLearningBodyEditingPreservesResultRestartAndSource() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app)
        navigateWorkspace("ai-settings", in: app)
        press(app.buttons["ai-settings"].firstMatch)
        let mock = app.buttons["ai-use-mock"].firstMatch
        XCTAssertTrue(mock.waitForExistence(timeout: 5)); press(mock); press(app.buttons["ai-settings-save"].firstMatch)
        press(app.buttons["reader-ai"].firstMatch)
        let consent = app.descendants(matching: .any).matching(identifier: "ai-scope-consent").firstMatch
        XCTAssertTrue(consent.waitForExistence(timeout: 5)); press(consent); press(app.buttons["ai-start"].firstMatch)
        XCTAssertTrue(app.staticTexts["ai-result"].firstMatch.waitForExistence(timeout: 8))
        press(app.buttons["ai-save-note"].firstMatch)
        let edit = app.buttons["ai-note-edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 8))
        let before = try originalSavedNote(token, manifest: "learning-v1.json")
        pressEditingElement(edit, app: app); enterEditingText("Original independent edited AI body", prefix: "ai-note", app: app)
        pressEditingElement(app.buttons["ai-note-edit-save"].firstMatch, app: app)
        waitForText(["已保存到本地"], in: app.staticTexts["ai-note-edit-status"].firstMatch, timeout: 8)
        let after = try originalSavedNote(token, manifest: "learning-v1.json")
        XCTAssertEqual(Set(before.keys), Set(after.keys))
        XCTAssertEqual(NSDictionary(dictionary: try XCTUnwrap(before["result"] as? [String: Any])), NSDictionary(dictionary: try XCTUnwrap(after["result"] as? [String: Any])))
        XCTAssertEqual(after["userText"] as? String, "Original independent edited AI body")
        press(app.buttons["ai-close"].firstMatch)
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-book", in: app)
        let book = app.descendants(matching: .any).matching(identifier: "library-book").firstMatch
        navigateWorkspace("library-book", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        XCTAssertTrue(app.buttons["reader-ai"].firstMatch.waitForExistence(timeout: 10)); press(app.buttons["reader-ai"].firstMatch)
        let body = app.staticTexts["ai-saved-user-note"].firstMatch
        XCTAssertTrue(body.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(body), "Original independent edited AI body")
        XCTAssertEqual(textValue(app.staticTexts["ai-saved-quote"].firstMatch), "window")
        press(app.buttons["ai-saved-source"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
    }
    // Run only in isolated CI/VM/OS user: XCTest launches the existing app bundle identity.
    @MainActor func testMacCoverSelectionGridListRestartAndRestore() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        let store = URL(fileURLWithPath: "/tmp", isDirectory: true).appendingPathComponent("PDFno-UITests-" + token)
        let inputs = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Original-Cover-UI-" + token)
        try FileManager.default.createDirectory(at: inputs, withIntermediateDirectories: true)
        let image = inputs.appendingPathComponent("Original Cover.png"), imageBytes = try originalPNG(width: 1600, height: 1000)
        try imageBytes.write(to: image)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate()
        defer { app.terminate(); try? FileManager.default.removeItem(at: inputs); try? FileManager.default.removeItem(at: store) }
        navigateWorkspace("open-sample", in: app)
        XCTAssertTrue(app.buttons["open-sample"].firstMatch.waitForExistence(timeout: 15))
        navigateWorkspace("open-sample", in: app)
        press(app.buttons["open-sample"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 15)
        func cover(_ label: String) -> XCUIElement {
            if !app.sheets.firstMatch.exists { navigateWorkspace("library-book", in: app) }
            return app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'cover-image-' AND label == %@", label)).firstMatch
        }
        XCTAssertTrue(cover("自动封面").waitForExistence(timeout: 10))
        func record() throws -> [String: Any] {
            let data = try Data(contentsOf: store.appendingPathComponent("covers-v1.json"))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
            return try XCTUnwrap((object["records"] as? [[String: Any]])?.first)
        }
        let automatic = try record(), identity = try XCTUnwrap(automatic["identity"] as? [String: Any])
        let hash = try XCTUnwrap(identity["fileSHA256"] as? String), original = store.appendingPathComponent("Originals/" + hash + ".pdf")
        let originalBytes = try Data(contentsOf: original), libraryBytes = try Data(contentsOf: store.appendingPathComponent("library-v1.json"))
        navigateWorkspace("library-edit-cover", in: app)
        press(app.buttons["library-edit-cover"].firstMatch)
        try chooseInput(image, trigger: app.buttons["cover-select-image"].firstMatch, app: app)
        XCTAssertTrue(cover("自选封面").waitForExistence(timeout: 10))
        let manual = try record()
        XCTAssertEqual(manual["origin"] as? String, "userImage")
        XCTAssertEqual(manual["width"] as? Int, 1200)
        XCTAssertEqual(manual["revision"] as? Int, (automatic["revision"] as? Int ?? 0) + 1)
        press(app.buttons["cover-editor-done"].firstMatch)
        navigateWorkspace("library-grid-layout", in: app)
        press(app.buttons["library-grid-layout"].firstMatch)
        XCTAssertTrue(cover("自选封面").waitForExistence(timeout: 5)); XCTAssertTrue(cover("自选封面").isHittable)
        navigateWorkspace("library-list-layout", in: app)
        press(app.buttons["library-list-layout"].firstMatch)
        XCTAssertTrue(cover("自选封面").waitForExistence(timeout: 5)); XCTAssertTrue(cover("自选封面").isHittable)
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-book", in: app)
        let book = app.descendants(matching: .any).matching(identifier: "library-book").firstMatch
        navigateWorkspace("library-book", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 15)); press(book)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 15)
        XCTAssertTrue(cover("自选封面").waitForExistence(timeout: 8))
        XCTAssertEqual(try record()["imageSHA256"] as? String, manual["imageSHA256"] as? String)
        navigateWorkspace("library-edit-cover", in: app)
        press(app.buttons["library-edit-cover"].firstMatch)
        press(app.buttons["cover-restore-automatic"].firstMatch)
        XCTAssertTrue(cover("自动封面").waitForExistence(timeout: 8))
        let restored = try record()
        XCTAssertEqual(restored["origin"] as? String, "pdfFirstPage")
        XCTAssertEqual(restored["imageSHA256"] as? String, automatic["imageSHA256"] as? String)
        XCTAssertEqual(restored["identity"] as? NSDictionary, automatic["identity"] as? NSDictionary)
        XCTAssertEqual(try Data(contentsOf: original), originalBytes)
        XCTAssertEqual(try Data(contentsOf: image), imageBytes)
        // Cover writes never alter book IDs, progress or note data.
        XCTAssertEqual(try Data(contentsOf: store.appendingPathComponent("library-v1.json")), libraryBytes)
        press(app.buttons["cover-editor-done"].firstMatch)
        navigateWorkspace("open-docx-sample", in: app)
        press(app.buttons["open-docx-sample"].firstMatch)
        XCTAssertTrue(app.buttons["docx-navigation"].firstMatch.waitForExistence(timeout: 25))
        navigateWorkspace("library-grid-layout", in: app)
        press(app.buttons["library-grid-layout"].firstMatch)
        XCTAssertTrue(cover("自动封面").waitForExistence(timeout: 8))
        navigateWorkspace("library-book", in: app)
        press(app.descendants(matching: .any).matching(identifier: "library-book").firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 15)
        XCTAssertEqual(try Data(contentsOf: original), originalBytes)
    }
    @MainActor func testMacDOCXDefaultCoverInListGridAndRestart() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        let store = URL(fileURLWithPath: "/tmp", isDirectory: true).appendingPathComponent("PDFno-UITests-" + token)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate(); defer { app.terminate(); try? FileManager.default.removeItem(at: store) }
        navigateWorkspace("open-docx-sample", in: app)
        XCTAssertTrue(app.buttons["open-docx-sample"].firstMatch.waitForExistence(timeout: 15))
        navigateWorkspace("open-docx-sample", in: app)
        press(app.buttons["open-docx-sample"].firstMatch)
        XCTAssertTrue(app.buttons["docx-navigation"].firstMatch.waitForExistence(timeout: 25))
        navigateWorkspace("library-docx", in: app)
        let placeholder = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'cover-image-' AND label == '默认封面'")).firstMatch
        XCTAssertTrue(placeholder.waitForExistence(timeout: 10))
        let before = try Data(contentsOf: store.appendingPathComponent("covers-v1.json"))
        navigateWorkspace("library-grid-layout", in: app)
        press(app.buttons["library-grid-layout"].firstMatch)
        XCTAssertTrue(placeholder.waitForExistence(timeout: 5)); XCTAssertTrue(placeholder.isHittable)
        navigateWorkspace("library-list-layout", in: app)
        press(app.buttons["library-list-layout"].firstMatch)
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-docx", in: app)
        XCTAssertTrue(placeholder.waitForExistence(timeout: 15))
        XCTAssertEqual(try Data(contentsOf: store.appendingPathComponent("covers-v1.json")), before)
    }
    // Execute only in isolated CI/VM/OS user: the runner can terminate the same bundle ID.
    @MainActor func testMacLibrarySearchMetadataUnicodeEmptyNoResultsAndRestart() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("open-sample", in: app)
        let sample = app.buttons["open-sample"].firstMatch
        navigateWorkspace("open-sample", in: app)
        XCTAssertTrue(sample.waitForExistence(timeout: 15)); waitUntilEnabled(sample); press(sample)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 15)
        press(app.buttons["library-search"].firstMatch)
        let input = app.textFields["library-search-input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["library-search-empty"].firstMatch.exists)
        enterSearch("study-sample", into: input)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        press(app.buttons["library-search-metadata"].firstMatch)
        let title = app.textFields["library-metadata-title"].firstMatch, author = app.textFields["library-metadata-author"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        enterSearch("Original 中文 Café 日本語🌸", into: title, replacing: true)
        enterSearch("Original Author 山川", into: author, replacing: true)
        press(app.buttons["library-metadata-save"].firstMatch)
        XCTAssertTrue(app.staticTexts["library-metadata-saved"].firstMatch.waitForExistence(timeout: 8))
        press(app.buttons["library-metadata-close"].firstMatch)
        enterSearch("cafe\u{301}", into: input, replacing: true)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        let group = app.descendants(matching: .any).matching(identifier: "library-search-group").firstMatch
        XCTAssertTrue(group.waitForExistence(timeout: 5))
        XCTAssertTrue(textValue(group).contains("Original 中文 Café 日本語🌸"))
        enterSearch("山川", into: input, replacing: true)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        enterSearch("原创无结果词", into: input, replacing: true)
        XCTAssertTrue(app.staticTexts["library-search-no-results"].firstMatch.waitForExistence(timeout: 8))
        press(app.buttons["library-search-clear"].firstMatch)
        XCTAssertTrue(app.staticTexts["library-search-empty"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["library-search-open-book"].firstMatch.exists)
        press(app.buttons["library-search-close"].firstMatch)
        app.terminate(); app.launch(); app.activate()
        let search = app.buttons["library-search"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15)); press(search)
        XCTAssertTrue(input.waitForExistence(timeout: 8)); enterSearch("AUTHOR", into: input)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        press(app.buttons["library-search-open-book"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 15)
    }
    @MainActor func testMacLibrarySearchUserNoteSavedLocalMockAIAndExactSource() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("open-sample", in: app)
        let sample = app.buttons["open-sample"].firstMatch
        navigateWorkspace("open-sample", in: app)
        XCTAssertTrue(sample.waitForExistence(timeout: 15)); waitUntilEnabled(sample); press(sample)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 15)
        press(app.buttons["reader-navigation"].firstMatch)
        let navigationInput = app.textFields["search-input"].firstMatch
        XCTAssertTrue(navigationInput.waitForExistence(timeout: 5)); enterSearch("window", into: navigationInput)
        press(app.buttons["search-submit"].firstMatch)
        let match = app.buttons["search-result"].firstMatch
        XCTAssertTrue(match.waitForExistence(timeout: 5)); press(match)
        press(app.buttons["reader-notes"].firstMatch)
        let draft = app.descendants(matching: .any).matching(identifier: "note-input").firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 5)); enterSearch("Original 日記 cafe\u{301}🌸", into: draft)
        press(app.buttons["save-note"].firstMatch)
        XCTAssertTrue(app.staticTexts["saved-note-quote"].firstMatch.waitForExistence(timeout: 8))
        press(app.buttons["close-notes"].firstMatch); press(app.buttons["next-page"].firstMatch)
        waitForText(["2 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 5)
        press(app.buttons["library-search"].firstMatch)
        let input = app.textFields["library-search-input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 8)); enterSearch("日記", into: input)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        press(app.buttons["library-search-source"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
        navigateWorkspace("ai-settings", in: app)
        press(app.buttons["ai-settings"].firstMatch)
        XCTAssertTrue(app.buttons["ai-use-mock"].firstMatch.waitForExistence(timeout: 5))
        press(app.buttons["ai-use-mock"].firstMatch); press(app.buttons["ai-settings-save"].firstMatch)
        press(app.buttons["reader-ai"].firstMatch)
        XCTAssertTrue(app.staticTexts["ai-source-quote"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(textValue(app.staticTexts["ai-source-quote"].firstMatch), "window")
        waitForText(["本地 mock"], in: app.staticTexts["ai-provider-status"].firstMatch, timeout: 5)
        press(app.descendants(matching: .any).matching(identifier: "ai-scope-consent").firstMatch)
        press(app.buttons["ai-start"].firstMatch)
        XCTAssertTrue(app.staticTexts["ai-result"].firstMatch.waitForExistence(timeout: 8))
        let aiDraft = app.descendants(matching: .any).matching(identifier: "ai-user-note").firstMatch
        enterSearch("Original saved AI memory 学習", into: aiDraft); press(app.buttons["ai-save-note"].firstMatch)
        XCTAssertTrue(app.staticTexts["ai-saved-user-note"].firstMatch.waitForExistence(timeout: 8))
        press(app.buttons["ai-close"].firstMatch); press(app.buttons["next-page"].firstMatch)
        press(app.buttons["library-search"].firstMatch)
        XCTAssertTrue(input.waitForExistence(timeout: 8)); enterSearch("学習", into: input)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        press(app.buttons["library-search-source"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
        app.terminate(); app.launch(); app.activate()
        let search = app.buttons["library-search"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15)); press(search)
        XCTAssertTrue(input.waitForExistence(timeout: 8)); enterSearch("学習", into: input)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
    }
    // Cross-slice acceptance: execute only on an isolated CI host, never the user's running app.
    @MainActor func testMacEditedNoteSearchDraftExclusionCoverLayoutsAndExactSource() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        let store = URL(fileURLWithPath: "/tmp", isDirectory: true).appendingPathComponent("PDFno-UITests-" + token)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate(); defer { app.terminate(); try? FileManager.default.removeItem(at: store) }
        try prepareOriginalPDFNoteEditing(app)
        press(app.buttons["reader-notes"].firstMatch)
        let input = app.descendants(matching: .any).matching(identifier: "note-input").firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 5)); enterSearch("integrationpreviousbody", into: input)
        press(app.buttons["save-note"].firstMatch)
        let edit = app.buttons["pdf-note-edit"].firstMatch
        XCTAssertTrue(edit.waitForExistence(timeout: 8))
        let before = try originalSavedNote(token, manifest: "library-v1.json")
        let anchor = try XCTUnwrap(before["anchor"] as? [String: Any]), hash = try XCTUnwrap(anchor["fileSHA256"] as? String)
        let original = store.appendingPathComponent("Originals/" + hash + ".pdf"), originalBytes = try Data(contentsOf: original)
        pressEditingElement(edit, app: app)
        enterEditingText("integrationdraftbody", prefix: "pdf-note", app: app)
        press(app.buttons["close-notes"].firstMatch); press(app.buttons["library-search"].firstMatch)
        let search = app.textFields["library-search-input"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8)); enterSearch("integrationdraftbody", into: search)
        XCTAssertTrue(app.staticTexts["library-search-no-results"].firstMatch.waitForExistence(timeout: 8))
        press(app.buttons["library-search-close"].firstMatch); press(app.buttons["reader-notes"].firstMatch)
        XCTAssertEqual(textValue(editingInput("pdf-note", app: app)), "integrationdraftbody")
        pressEditingElement(app.buttons["pdf-note-edit-cancel"].firstMatch, app: app)
        pressEditingElement(edit, app: app)
        enterEditingText("integrationsavedbody 日本語", prefix: "pdf-note", app: app)
        pressEditingElement(app.buttons["pdf-note-edit-save"].firstMatch, app: app)
        waitForText(["已保存到本地"], in: app.staticTexts["pdf-note-edit-status"].firstMatch, timeout: 8)
        press(app.buttons["close-notes"].firstMatch)
        navigateWorkspace("library-grid-layout", in: app)
        navigateWorkspace("library-list-layout", in: app)
        press(app.buttons["library-grid-layout"].firstMatch); press(app.buttons["library-list-layout"].firstMatch)
        navigateWorkspace("library-edit-cover", in: app)
        press(app.buttons["library-edit-cover"].firstMatch)
        XCTAssertTrue(app.buttons["cover-restore-automatic"].firstMatch.waitForExistence(timeout: 5))
        let coverManifest = store.appendingPathComponent("covers-v1.json")
        let coverState = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: coverManifest)) as? [String: Any])
        let priorRevision = try XCTUnwrap((coverState["records"] as? [[String: Any]])?.first?["revision"] as? Int)
        press(app.buttons["cover-restore-automatic"].firstMatch)
        let restored = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let data = try? Data(contentsOf: coverManifest),
                  let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let revision = (state["records"] as? [[String: Any]])?.first?["revision"] as? Int else { return false }
            return revision > priorRevision
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [restored], timeout: 8), .completed)
        waitUntilEnabled(app.buttons["cover-editor-done"].firstMatch); press(app.buttons["cover-editor-done"].firstMatch)
        // Library controls have their own screen. Resume the preserved reader
        // before checking the original page and note-source assertions.
        press(app.buttons["workspace-resume-reader"].firstMatch)
        press(app.buttons["next-page"].firstMatch)
        waitForText(["2 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 5)
        press(app.buttons["library-search"].firstMatch)
        XCTAssertTrue(search.waitForExistence(timeout: 8)); enterSearch("integrationpreviousbody", into: search)
        XCTAssertTrue(app.staticTexts["library-search-no-results"].firstMatch.waitForExistence(timeout: 8))
        enterSearch("integrationsavedbody", into: search, replacing: true)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        press(app.buttons["library-search-source"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
        let after = try originalSavedNote(token, manifest: "library-v1.json")
        XCTAssertEqual(after["userText"] as? String, "integrationsavedbody 日本語")
        XCTAssertEqual(after["anchor"] as? NSDictionary, before["anchor"] as? NSDictionary)
        XCTAssertEqual(after["id"] as? String, before["id"] as? String)
        XCTAssertEqual(try Data(contentsOf: original), originalBytes)
    }
    // Prepared for isolated CI; local task does not launch the user's running app.
    @MainActor func testMacTXTImportSelectionNotesNavigationAndRestart() throws {
        try runTextFormatUI(extension: "TXT", source: "Chapter 1\nwindow original 日本語🌸 café\nChapter 2\nLast original line")
    }
    @MainActor func testMacMarkdownImportSelectionNotesNavigationAndRestart() throws {
        try runTextFormatUI(extension: "MD", source: "# Chapter 1\n\n**window** original 日本語🌸 café\n\n## Chapter 2\n\nLast original line [ordinary link](https://example.invalid)")
    }
    @MainActor func testMacHTMLAliasImportSelectionNotesNavigationAndRestart() throws {
        try runTextFormatUI(extension: "HTM", source: "<!doctype html><html><body><h1>Chapter 1</h1><p><strong>window</strong> original 日本語🌸 café</p><h2>Chapter 2</h2><p>Last original line <a href='https://example.invalid'>ordinary link</a></p><script>window.sourceExecuted=true</script></body></html>")
    }
    @MainActor func testMacXHTMLImportSelectionNotesNavigationAndRestart() throws {
        try runTextFormatUI(extension: "XHTML", source: "<?xml version='1.0' encoding='UTF-8'?><html xmlns='http://www.w3.org/1999/xhtml'><body><h1>Chapter 1</h1><p><strong>window</strong> original 日本語🌸 café</p><h2>Chapter 2</h2><p>Last original line</p><script>window.sourceExecuted=true</script></body></html>")
    }
    @MainActor func testMacReadableXMLImportSelectionNotesNavigationAndRestart() throws {
        try runTextFormatUI(extension: "XML", source: "<?xml version='1.0' encoding='UTF-8'?><document><title>Chapter 1</title><p><bold>window</bold> original 日本語🌸 café</p><section><title>Chapter 2</title><p>Last original line</p></section></document>")
    }
    @MainActor func testMacMHTMLImportSelectionNotesNavigationAndRestart() throws {
        let html = "<h1>Chapter 1</h1><p><strong>window</strong> original 日本語🌸 café</p><h2>Chapter 2</h2><p>Last original line</p><script>window.sourceExecuted=true</script><img src='https://example.invalid/private' alt='Original image'>"
        let archive = "MIME-Version: 1.0\r\nContent-Type: multipart/related; boundary=OriginalUIArchive; type=\"text/html\"\r\n\r\n--OriginalUIArchive\r\nContent-Type: text/html; charset=utf-8\r\nContent-Transfer-Encoding: base64\r\nContent-ID: <original>\r\nContent-Location: https://example.invalid/original\r\n\r\n" + Data(html.utf8).base64EncodedString() + "\r\n--OriginalUIArchive--\r\n"
        try runTextFormatUI(extension: "MHTML", source: archive)
    }
    @MainActor private func runTextFormatUI(extension ext: String, source: String) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Text-UI-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("Original Reading." + ext), bytes = Data(source.utf8)
        try bytes.write(to: file)
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("import-pdf", in: app)
        XCTAssertTrue(app.buttons["import-pdf"].firstMatch.waitForExistence(timeout: 15))
        navigateWorkspace("import-pdf", in: app)
        try chooseInput(file, trigger: app.buttons["import-pdf"].firstMatch, app: app)
        let navigation = app.buttons["textformat-navigation"].firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        navigateWorkspace("library-edit-cover", in: app)
        XCTAssertFalse(app.buttons["library-edit-cover"].firstMatch.isEnabled)
        navigateWorkspace("library-grid-layout", in: app)
        press(app.buttons["library-grid-layout"].firstMatch)
        let textRow = app.descendants(matching: .any).matching(identifier: "library-textformat").firstMatch
        XCTAssertTrue(textRow.waitForExistence(timeout: 5)); XCTAssertTrue(textRow.isHittable)
        navigateWorkspace("library-list-layout", in: app)
        press(app.buttons["library-list-layout"].firstMatch)
        XCTAssertTrue(textRow.waitForExistence(timeout: 5)); XCTAssertTrue(textRow.isHittable)
        press(app.buttons["workspace-resume-reader"].firstMatch)
        XCTAssertFalse(app.buttons["reader-ai"].firstMatch.exists)
        XCTAssertFalse(app.buttons["epub-ai"].firstMatch.exists)
        XCTAssertFalse(app.buttons["reader-page-translation"].firstMatch.exists)
        let paragraph = try webText(in: app, matching: "window", prefix: true, timeout: 10)
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        press(app.buttons["textformat-notes"].firstMatch)
        let selection = app.descendants(matching: .any).matching(identifier: "textformat-selection").firstMatch
        XCTAssertTrue(selection.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(selection), "window")
        let draft = app.descendants(matching: .any).matching(identifier: "textformat-user-note").firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 5)); enterSearch("Original text format observation", into: draft)
        press(app.buttons["textformat-save-note"].firstMatch)
        let saved = app.staticTexts["textformat-saved-quote"].firstMatch, note = app.staticTexts["textformat-saved-user-note"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(saved), "window")
        XCTAssertTrue(note.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(note), "Original text format observation")
        press(app.buttons["textformat-return"].firstMatch)
        press(navigation)
        let second = app.buttons["textformat-chapter-2"].firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 5)); press(second)
        XCTAssertTrue(try webText(in: app, matching: "Chapter 2", prefix: false, timeout: 10).isHittable)
        let store = URL(fileURLWithPath: "/tmp", isDirectory: true).appendingPathComponent("PDFno-UITests-" + token).appendingPathComponent("text-formats-v1.json")
        let persisted = expectation(for: NSPredicate { _, _ in
            guard let data = try? Data(contentsOf: store), let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let books = state["books"] as? [[String: Any]], let progress = books.first?["progress"] as? [String: Any], let notes = state["notes"] as? [[String: Any]] else { return false }
            return progress["blockID"] as? Int == 2 && progress["quote"] as? String == "C" && notes.count == 1
        }, evaluatedWith: app)
        wait(for: [persisted], timeout: 10)
        XCTAssertEqual(try Data(contentsOf: file), bytes)
        app.terminate(); app.launch(); app.activate()
        let row = app.descendants(matching: .any).matching(identifier: "library-textformat").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10)); press(row)
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        XCTAssertTrue(try webText(in: app, matching: "Chapter 2", prefix: false, timeout: 10).isHittable)
        press(app.buttons["textformat-notes"].firstMatch)
        XCTAssertTrue(saved.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(saved), "window")
        XCTAssertTrue(note.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(note), "Original text format observation")
        press(app.buttons["textformat-return"].firstMatch)
        XCTAssertTrue(try webText(in: app, matching: "window", prefix: true, timeout: 10).isHittable)
        XCTAssertEqual(try Data(contentsOf: file), bytes)
    }
    @MainActor func testMacDOCXImportSemanticSelectionNotesAndRestart() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Word-UI-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("Original Semantic.docx"), bytes = originalSemanticDOCX()
        try bytes.write(to: source)
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("import-pdf", in: app)
        XCTAssertTrue(app.buttons["import-pdf"].firstMatch.waitForExistence(timeout: 15))
        navigateWorkspace("import-pdf", in: app)
        try chooseInput(source, trigger: app.buttons["import-pdf"].firstMatch, app: app)
        let navigation = app.buttons["docx-navigation"].firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        XCTAssertFalse(app.buttons["reader-ai"].firstMatch.exists)
        XCTAssertFalse(app.buttons["reader-page-translation"].firstMatch.exists)
        XCTAssertTrue(try webText(in: app, matching: "Cell one", prefix: false, timeout: 10).exists)
        let paragraph = try webText(in: app, matching: "window", prefix: true, timeout: 10)
        waitUntilEnabled(paragraph)
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        press(app.buttons["docx-notes"].firstMatch)
        // Native selectable text may be exposed as Other on macOS 15. Match
        // its exact app-owned identifier without imposing an AX role.
        let selection = app.descendants(matching: .any).matching(identifier: "docx-selection").firstMatch
        guard selection.waitForExistence(timeout: 8) else {
            print("Original Word notes: empty-selection message exists =", app.descendants(matching: .any).matching(identifier: "docx-selection-empty").firstMatch.exists)
            XCTFail("Real Word selection must reach the native notes sheet")
            return
        }
        XCTAssertEqual(textValue(selection), "window")
        let draft = app.descendants(matching: .any).matching(identifier: "docx-user-note").firstMatch
        XCTAssertTrue(draft.waitForExistence(timeout: 5)); enterSearch("Original independent Word note", into: draft)
        press(app.buttons["docx-save-note"].firstMatch)
        let saved = app.staticTexts["docx-saved-quote"].firstMatch, userNote = app.staticTexts["docx-saved-user-note"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(saved), "window")
        XCTAssertTrue(userNote.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(userNote), "Original independent Word note")
        press(app.buttons["docx-return"].firstMatch)
        XCTAssertTrue(try webText(in: app, matching: "window", prefix: true, timeout: 10).isHittable)
        press(navigation)
        let second = app.buttons["Second UI heading"].firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 5)); press(second)
        XCTAssertTrue(try webText(in: app, matching: "Second UI heading", prefix: false, timeout: 10).isHittable)
        let store = URL(fileURLWithPath: "/tmp", isDirectory: true).appendingPathComponent("PDFno-UITests-" + token).appendingPathComponent("docx-mammoth-v1.json")
        var lastProgress: [String: Any]?
        let persisted = expectation(for: NSPredicate { _, _ in
            guard let data = try? Data(contentsOf: store), let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let books = object["books"] as? [[String: Any]], let progress = books.first?["progress"] as? [String: Any] else { return false }
            lastProgress = progress
            return progress["blockID"] as? Int == 4 && progress["quote"] as? String == "S" &&
                progress["start"] as? Int == ["Original UI chapter", "window — original 日本語🌸 café", "Cell one", "Cell two"].reduce(0) { $0 + $1.utf16.count + 1 }
        }, evaluatedWith: app)
        wait(for: [persisted], timeout: 10)
        if lastProgress?["blockID"] as? Int != 4 || lastProgress?["quote"] as? String != "S" {
            print("Original Word progress: manifest exists =", FileManager.default.fileExists(atPath: store.path),
                  "; block =", lastProgress?["blockID"] ?? "missing", "; start =", lastProgress?["start"] ?? "missing")
        }
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-docx", in: app)
        let book = app.descendants(matching: .any).matching(identifier: "library-docx").firstMatch
        navigateWorkspace("library-docx", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        XCTAssertTrue(try webText(in: app, matching: "Second UI heading", prefix: false, timeout: 10).isHittable)
        press(app.buttons["docx-notes"].firstMatch)
        XCTAssertTrue(saved.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(saved), "window")
        XCTAssertTrue(userNote.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(userNote), "Original independent Word note")
        press(app.buttons["docx-return"].firstMatch)
        XCTAssertTrue(try webText(in: app, matching: "window", prefix: true, timeout: 10).isHittable)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
    }
    @MainActor func testMacDOCXFailureRecoveryAndPDFEPUBTransitions() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Word-Recovery-UI-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let broken = root.appendingPathComponent("Broken Original Word.docx")
        try Data("Original malformed Word fixture".utf8).write(to: broken)
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("import-pdf", in: app)
        XCTAssertTrue(app.buttons["import-pdf"].firstMatch.waitForExistence(timeout: 15))
        navigateWorkspace("import-pdf", in: app)
        try chooseInput(broken, trigger: app.buttons["import-pdf"].firstMatch, app: app)
        let dismiss = try modalButton(app, titles: ["知道了"])
        XCTAssertTrue(app.staticTexts["DOCX ZIP 无效、校验失败或含不安全路径／加密／不支持的归档结构。"].firstMatch.exists)
        press(dismiss)
        navigateWorkspace("library-docx", in: app)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "library-docx").firstMatch.exists)
        navigateWorkspace("open-docx-sample", in: app)
        press(app.buttons["open-docx-sample"].firstMatch)
        let navigation = app.buttons["docx-navigation"].firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        XCTAssertTrue(try webText(in: app, matching: "Original DOCX chapter", prefix: false, timeout: 10).exists)
        navigateWorkspace("open-sample", in: app)
        press(app.buttons["open-sample"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 15)
        XCTAssertFalse(navigation.exists)
        navigateWorkspace("open-epub-sample", in: app)
        press(app.buttons["open-epub-sample"].firstMatch)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        XCTAssertFalse(navigation.exists)
        navigateWorkspace("library-docx", in: app)
        let word = app.descendants(matching: .any).matching(identifier: "library-docx").firstMatch
        navigateWorkspace("library-docx", in: app)
        XCTAssertTrue(word.waitForExistence(timeout: 5)); press(word)
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        XCTAssertTrue(try webText(in: app, matching: "Original DOCX chapter", prefix: false, timeout: 10).exists)
        XCTAssertFalse(app.buttons["reader-ai"].firstMatch.exists)
        XCTAssertFalse(app.buttons["epub-ai"].firstMatch.exists)
        XCTAssertFalse(app.buttons["reader-page-translation"].firstMatch.exists)
        let comic = root.appendingPathComponent("Original Word Transition.cbz")
        try originalZIP([("1.png", try originalPNG(width: 12, height: 20)), ("2.png", try originalPNG(width: 12, height: 20))]).write(to: comic)
        navigateWorkspace("import-pdf", in: app)
        try chooseInput(comic, trigger: app.buttons["import-pdf"].firstMatch, app: app)
        waitForText(["1 / 2"], in: app.staticTexts["comic-position"].firstMatch, timeout: 25)
        XCTAssertFalse(navigation.exists)
        navigateWorkspace("library-docx", in: app)
        press(word)
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        XCTAssertTrue(try webText(in: app, matching: "Original DOCX chapter", prefix: false, timeout: 10).exists)
        XCTAssertFalse(app.buttons["reader-page-translation"].firstMatch.exists)
    }
    private func originalSemanticDOCX() -> Data {
        let w = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
        let types = "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Default Extension=\"xml\" ContentType=\"application/xml\"/><Default Extension=\"rels\" ContentType=\"application/vnd.openxmlformats-package.relationships+xml\"/><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>"
        let relationships = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"original\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>"
        let stylesRelationship = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"styles\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles\" Target=\"styles.xml\"/></Relationships>"
        let styles = "<w:styles xmlns:w=\"\(w)\"><w:style w:type=\"paragraph\" w:styleId=\"Heading1\"><w:name w:val=\"heading 1\"/></w:style><w:style w:type=\"paragraph\" w:styleId=\"Heading2\"><w:name w:val=\"heading 2\"/></w:style></w:styles>"
        let xml = "<w:document xmlns:w=\"\(w)\"><w:body><w:p><w:pPr><w:pStyle w:val=\"Heading1\"/></w:pPr><w:r><w:t>Original UI chapter</w:t></w:r></w:p><w:p><w:r><w:t>window — original 日本語🌸 café</w:t></w:r></w:p><w:tbl><w:tr><w:tc><w:p><w:r><w:t>Cell one</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Cell two</w:t></w:r></w:p></w:tc></w:tr></w:tbl><w:p><w:pPr><w:pStyle w:val=\"Heading2\"/></w:pPr><w:r><w:t>Second UI heading</w:t></w:r></w:p><w:p><w:r><w:t>Last original Word line</w:t></w:r></w:p><w:sectPr/></w:body></w:document>"
        return originalZIP([("[Content_Types].xml", Data(types.utf8)), ("_rels/.rels", Data(relationships.utf8)), ("word/styles.xml", Data(styles.utf8)), ("word/_rels/document.xml.rels", Data(stylesRelationship.utf8)), ("word/document.xml", Data(xml.utf8))])
    }
    // Each test has its own original fixtures/store. Split the independent product
    // flows so real native-panel snapshots fit the unchanged 180-second CI limit.
    @MainActor func testMacDOCXConversionSavePanelCancelAndOverwriteRefusal() throws {
        let fixture = try originalConversionFixture()
        let (root, source, broken, bytes) = fixture
        defer { try? FileManager.default.removeItem(at: root) }
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("document-conversion", in: app)
        let entry = app.buttons["document-conversion"].firstMatch
        navigateWorkspace("document-conversion", in: app)
        XCTAssertTrue(entry.waitForExistence(timeout: 15)); press(entry)
        let export = app.buttons["conversion-export"].firstMatch, status = app.staticTexts["conversion-status"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 5)); XCTAssertFalse(export.isEnabled)
        XCTAssertTrue(app.staticTexts["conversion-warning-bodyOnly"].firstMatch.exists)
        XCTAssertTrue(app.staticTexts["conversion-warning-simplifiedLayout"].firstMatch.exists)
        try chooseInput(source, trigger: app.buttons["conversion-source"].firstMatch, app: app)
        waitUntilEnabled(export)
        press(export)
        XCTAssertTrue(filePanelButton(app, titles: ["Save", "保存"]).waitForExistence(timeout: 5))
        app.typeKey(.escape, modifierFlags: []); waitUntilEnabled(export)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: root.path).sorted(), ["Broken Body.docx", "Original Body.docx"])
        let output = root.appendingPathComponent("Original Output.txt")
        try chooseOutput(output, defaultName: "Original Body-converted.txt", trigger: export, app: app)
        waitForText(["已保存副本"], in: status, timeout: 15)
        let text = try Data(contentsOf: output)
        XCTAssertTrue(String(decoding: text, as: UTF8.self).contains("Original 日本語🌸 café <script>&"))
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        try chooseOutput(output, defaultName: "Original Body-converted.txt", trigger: export, app: app)
        waitForText(["输出位置已有文件"], in: status, timeout: 15)
        XCTAssertEqual(try Data(contentsOf: output), text); waitUntilEnabled(export)
    }
    @MainActor func testMacDOCXConversionFailureRecoveryAndEscapedHTML() throws {
        let fixture = try originalConversionFixture()
        let (root, source, broken, bytes) = fixture
        defer { try? FileManager.default.removeItem(at: root) }
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("document-conversion", in: app)
        let entry = app.buttons["document-conversion"].firstMatch
        navigateWorkspace("document-conversion", in: app)
        XCTAssertTrue(entry.waitForExistence(timeout: 15)); press(entry)
        let export = app.buttons["conversion-export"].firstMatch, status = app.staticTexts["conversion-status"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 5)); XCTAssertFalse(export.isEnabled)
        try chooseInput(broken, trigger: app.buttons["conversion-source"].firstMatch, app: app)
        let failed = root.appendingPathComponent("Failed Output.txt")
        try chooseOutput(failed, defaultName: "Broken Body-converted.txt", trigger: export, app: app)
        let statusRawValue = status.value
        print("PDFNO_DOCX_STATUS_DIAGNOSTIC exists=", status.exists, "valueType=", statusRawValue.map { String(reflecting: type(of: $0)) } ?? "nil", "valueString=", statusRawValue as? String ?? "<not String>", "label=", status.label)
        waitForText(["归档损坏"], in: status, timeout: 15)
        let completedStatusRawValue = status.value
        print("PDFNO_DOCX_STATUS_DIAGNOSTIC after_wait exists=", status.exists, "valueType=", completedStatusRawValue.map { String(reflecting: type(of: $0)) } ?? "nil", "valueString=", completedStatusRawValue as? String ?? "<not String>", "label=", status.label)
        XCTAssertFalse(FileManager.default.fileExists(atPath: failed.path)); waitUntilEnabled(export)
        try chooseInput(source, trigger: app.buttons["conversion-source"].firstMatch, app: app)
        let htmlChoice = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "简化 HTML")).firstMatch
        XCTAssertTrue(htmlChoice.waitForExistence(timeout: 5)); press(htmlChoice)
        let html = root.appendingPathComponent("Original Output.html")
        try chooseOutput(html, defaultName: "Original Body-converted.html", trigger: export, app: app)
        waitForText(["已保存副本"], in: status, timeout: 15)
        let markup = try String(contentsOf: html, encoding: .utf8)
        XCTAssertTrue(markup.contains("&lt;script&gt;&amp;")); XCTAssertFalse(markup.contains("<script>")); XCTAssertTrue(markup.contains("default-src 'none'"))
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        press(app.buttons["conversion-close"].firstMatch)
    }
    @MainActor func testMacDOCXConversionWorkerCancellationLeavesNoOutput() throws {
        let fixture = try originalConversionFixture()
        let (root, source, broken, bytes) = fixture
        defer { try? FileManager.default.removeItem(at: root) }
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("document-conversion", in: app)
        let entry = app.buttons["document-conversion"].firstMatch
        navigateWorkspace("document-conversion", in: app)
        XCTAssertTrue(entry.waitForExistence(timeout: 15)); press(entry)
        let export = app.buttons["conversion-export"].firstMatch, status = app.staticTexts["conversion-status"].firstMatch
        XCTAssertTrue(export.waitForExistence(timeout: 5)); XCTAssertFalse(export.isEnabled)
        press(app.buttons["conversion-close"].firstMatch)
        // An isolated DEBUG fixture pauses the real local worker before parsing, making cancellation deterministic.
        app.terminate(); app.launchEnvironment["PDFNO_UI_TEST_CONVERSION"] = "cancellation-checkpoint"; app.launch(); app.activate()
        navigateWorkspace("document-conversion", in: app)
        XCTAssertTrue(entry.waitForExistence(timeout: 10)); press(entry)
        guard app.staticTexts["conversion-fixture"].firstMatch.waitForExistence(timeout: 5) else { XCTFail("Cancellation fixture must be isolated"); return }
        try chooseInput(source, trigger: app.buttons["conversion-source"].firstMatch, app: app)
        let cancelled = root.appendingPathComponent("Cancelled Output.txt")
        try chooseOutput(cancelled, defaultName: "Original Body-converted.txt", trigger: export, app: app)
        let cancel = app.buttons["conversion-cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); press(cancel)
        waitForText(["转换已取消"], in: status, timeout: 10)
        XCTAssertFalse(FileManager.default.fileExists(atPath: cancelled.path)); waitUntilEnabled(export)
        XCTAssertEqual(try Data(contentsOf: source), bytes)
        XCTAssertFalse(try FileManager.default.contentsOfDirectory(atPath: root.path).contains { $0.hasPrefix(".pdfno-conversion-") })
    }
    private func originalConversionFixture() throws -> (root: URL, source: URL, broken: URL, bytes: Data) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Conversion-UI-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let source = root.appendingPathComponent("Original Body.docx"), broken = root.appendingPathComponent("Broken Body.docx")
        let types = "<Types xmlns=\"http://schemas.openxmlformats.org/package/2006/content-types\"><Override PartName=\"/word/document.xml\" ContentType=\"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml\"/></Types>"
        let relationships = "<Relationships xmlns=\"http://schemas.openxmlformats.org/package/2006/relationships\"><Relationship Id=\"original\" Type=\"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument\" Target=\"word/document.xml\"/></Relationships>"
        let xml = "<w:document xmlns:w=\"http://schemas.openxmlformats.org/wordprocessingml/2006/main\"><w:body><w:p><w:r><w:t>Original 日本語🌸 café &lt;script&gt;&amp;</w:t></w:r></w:p></w:body></w:document>"
        let bytes = originalZIP([("[Content_Types].xml", Data(types.utf8)), ("_rels/.rels", Data(relationships.utf8)), ("word/document.xml", Data(xml.utf8))])
        try bytes.write(to: source); try Data("Original invalid DOCX fixture".utf8).write(to: broken)
        return (root, source, broken, bytes)
    }
    @MainActor private func chooseOutput(_ url: URL, defaultName: String, trigger: XCUIElement, app: XCUIApplication) throws {
        let existed = FileManager.default.fileExists(atPath: url.path)
        press(trigger)
        let save = filePanelButton(app, titles: ["Save", "保存"])
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        try goToFixtureLocation(url.deletingLastPathComponent(), app: app)
        let name = app.textFields.matching(NSPredicate(format: "value == %@", defaultName)).firstMatch
        XCTAssertTrue(name.waitForExistence(timeout: 5)); enterSearch(url.lastPathComponent, into: name, replacing: true)
        waitUntilEnabled(save); press(save)
        if existed {
            let replace = try modalButton(app, titles: ["Replace", "替换"])
            press(replace)
        }
    }
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
        navigateWorkspace("open-sample", in: app)
        XCTAssertTrue(app.buttons["open-sample"].firstMatch.waitForExistence(timeout: 15))
        // The unchanged sample-entry assertion now observes the help popover.
        // Close that popover before activating the real library import button.
        app.typeKey(.escape, modifierFlags: [])
        navigateWorkspace("import-pdf", in: app)
        try chooseInput(archive, trigger: app.buttons["import-pdf"].firstMatch, app: app)
        let position = app.staticTexts["comic-position"].firstMatch
        waitForText(["1 / 7"], in: position, timeout: 25)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "comic-content").firstMatch.exists)
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
        navigateWorkspace("library-comic", in: app)
        let comic = app.descendants(matching: .any).matching(identifier: "library-comic").firstMatch
        navigateWorkspace("library-comic", in: app)
        XCTAssertTrue(comic.waitForExistence(timeout: 5)); press(comic)
        waitForText(["5 / 7"], in: position, timeout: 25)
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-comic", in: app)
        XCTAssertTrue(comic.waitForExistence(timeout: 10)); press(comic)
        waitForText(["5 / 7"], in: position, timeout: 25)
        XCTAssertTrue(textValue(direction).contains("从右到左")); XCTAssertTrue(textValue(layout).contains("单页"))
        navigateWorkspace("import-pdf", in: app)
        try chooseInput(broken, trigger: app.buttons["import-pdf"].firstMatch, app: app)
        let dismissError = try modalButton(app, titles: ["知道了"])
        let archiveError = "CBZ 无效、路径不安全、校验失败或 ZIP 结构不受支持（加密、分卷、ZIP64）。"
        XCTAssertTrue(app.staticTexts[archiveError].firstMatch.exists)
        press(dismissError)
        waitForText(["5 / 7"], in: position, timeout: 5)
        navigateWorkspace("open-sample", in: app)
        press(app.buttons["open-sample"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 10)
        navigateWorkspace("open-epub-sample", in: app)
        press(app.buttons["open-epub-sample"].firstMatch)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        navigateWorkspace("library-comic", in: app)
        press(comic); waitForText(["5 / 7"], in: position, timeout: 25)
    }
    @MainActor func testMacCBTImportSpreadsDirectionPageJumpAndRestart() throws {
        try macComicImportSpreadsDirectionPageJumpAndRestart(format: "cbt")
    }
    @MainActor func testMacCB7ImportSpreadsDirectionPageJumpAndRestart() throws {
        try macComicImportSpreadsDirectionPageJumpAndRestart(format: "cb7")
    }
    @MainActor func testMacCBRImportSpreadsDirectionPageJumpAndRestart() throws {
        try macComicImportSpreadsDirectionPageJumpAndRestart(format: "cbr")
    }
    private func original7zCopy(_ entries: [(String, Data)]) -> Data {
        func number(_ n: Int) -> Data {
            let value = UInt64(n)
            for i in 0..<8 where value < (UInt64(1) << (7 * (i + 1))) {
                let prefixMask: UInt64 = ((UInt64(1) << i) - 1) << (8 - i)
                let upperValue: UInt64 = value >> (8 * i)
                let firstByte: UInt8 = UInt8(prefixMask | upperValue)
                var bytes = Data([firstByte])
                for j in 0..<i { bytes.append(UInt8((value >> (8 * j)) & 255)) }; return bytes
            }
            return Data([255]) + little(value, width: 8)
        }
        var payload = Data(), stream = Data([6]) + number(0) + number(entries.count) + Data([9])
        for (_, bytes) in entries { payload += bytes; stream += number(bytes.count) }
        stream += Data([0,7,11]) + number(entries.count) + Data([0])
        for _ in entries { stream += Data([1,1,0]) }
        stream += Data([12]); for (_, bytes) in entries { stream += number(bytes.count) }
        stream += Data([0,8,10,1]); for (_, bytes) in entries { stream += little(UInt64(originalComicCRC(bytes)), width: 4) }
        stream += Data([0,0])
        var names = Data([0]); for (name,_) in entries { names += (name + "\0").data(using: .utf16LittleEndian)! }
        var header = Data([1,4]) + stream + Data([5]) + number(entries.count) + Data([17])
        header += number(names.count) + names + Data([0,0])
        let start = little(UInt64(payload.count), width: 8) + little(UInt64(header.count), width: 8) + little(UInt64(originalComicCRC(header)), width: 4)
        return Data([0x37,0x7a,0xbc,0xaf,0x27,0x1c,0,4]) + little(UInt64(originalComicCRC(start)), width: 4) + start + payload + header
    }
    private func originalRAR4Store(_ entries: [(String, Data)]) -> Data {
        func header(_ type: UInt8, flags: UInt64, body: Data) -> Data {
            let bytes = Data([type]) + little(flags, width: 2) + little(UInt64(body.count + 7), width: 2) + body
            return little(UInt64(originalComicCRC(bytes) & 0xffff), width: 2) + bytes
        }
        var result = Data([0x52,0x61,0x72,0x21,0x1a,0x07,0]) + header(0x73, flags: 0, body: Data(repeating: 0, count: 6))
        for (name, bytes) in entries {
            var body = little(UInt64(bytes.count), width: 4) + little(UInt64(bytes.count), width: 4) + Data([3])
            body += little(UInt64(originalComicCRC(bytes)), width: 4) + little(0, width: 4) + Data([29,0x30])
            body += little(UInt64(name.utf8.count), width: 2) + little(0o100644, width: 4) + Data(name.utf8)
            result += header(0x74, flags: 0x8000, body: body) + bytes
        }
        return result + header(0x7b, flags: 0, body: Data())
    }
    private func little(_ n: UInt64, width: Int) -> Data { Data((0..<width).map { UInt8((n >> ($0 * 8)) & 255) }) }
    private func originalComicCRC(_ bytes: Data) -> UInt32 {
        var value = UInt32.max
        for byte in bytes { value ^= UInt32(byte); for _ in 0..<8 { value = value & 1 == 0 ? value >> 1 : (value >> 1) ^ 0xedb88320 } }
        return value ^ UInt32.max
    }
    /// Original uncompressed POSIX USTAR fixture, distinct from ZIP bytes.
    private func originalUSTAR(_ entries: [(String, Data)]) -> Data {
        var result = Data()
        for (name, data) in entries {
            var header = [UInt8](repeating: 0, count: 512)
            func text(_ value: String, _ at: Int) { header.replaceSubrange(at..<(at + value.utf8.count), with: value.utf8) }
            text(name, 0); text("ustar\0", 257); text("00", 263)
            for (at, count, value) in [(100, 8, 0o644), (108, 8, 0), (116, 8, 0), (124, 12, data.count), (136, 12, 0), (329, 8, 0), (337, 8, 0)] {
                let digits = String(value, radix: 8)
                text(String(repeating: "0", count: count - digits.count - 1) + digits + "\0", at)
            }
            header[156] = 48; header.replaceSubrange(148..<156, with: [UInt8](repeating: 32, count: 8))
            let digits = String(header.reduce(0) { $0 + Int($1) }, radix: 8)
            text(String(repeating: "0", count: 6 - digits.count) + digits + "\0 ", 148)
            result.append(contentsOf: header); result.append(data)
            result.append(Data(repeating: 0, count: (512 - data.count % 512) % 512))
        }
        result.append(Data(repeating: 0, count: 1024)); return result
    }
    @MainActor private func macComicImportSpreadsDirectionPageJumpAndRestart(format: String) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-CBZ-UI-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let archive = root.appendingPathComponent("Original Comic." + format)
        let entries = try (0..<7).map { index in
            ("pages/\(index + 1).PNG", try originalPNG(width: index == 3 ? 30 : 12, height: index == 3 ? 10 : 20))
        }
        let bytes: Data
        switch format { case "cbt": bytes = originalUSTAR(Array(entries.reversed())); case "cb7": bytes = original7zCopy(Array(entries.reversed())); case "cbr": bytes = originalRAR4Store(Array(entries.reversed())); default: bytes = originalZIP(entries) }
        try bytes.write(to: archive)
        let broken = root.appendingPathComponent("Broken Original." + format)
        try Data("Original malformed CBZ fixture".utf8).write(to: broken)
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        navigateWorkspace("open-sample", in: app)
        XCTAssertTrue(app.buttons["open-sample"].firstMatch.waitForExistence(timeout: 15))
        // CB7, CBR and CBT share this driver and the same help popover.
        app.typeKey(.escape, modifierFlags: [])
        navigateWorkspace("import-pdf", in: app)
        try chooseInput(archive, trigger: app.buttons["import-pdf"].firstMatch, app: app)
        let position = app.staticTexts["comic-position"].firstMatch
        waitForText(["1 / 7"], in: position, timeout: 25)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "comic-content").firstMatch.exists)
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
        navigateWorkspace("library-comic", in: app)
        let comic = app.descendants(matching: .any).matching(identifier: "library-comic").firstMatch
        navigateWorkspace("library-comic", in: app)
        XCTAssertTrue(comic.waitForExistence(timeout: 5)); press(comic)
        waitForText(["5 / 7"], in: position, timeout: 25)
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-comic", in: app)
        XCTAssertTrue(comic.waitForExistence(timeout: 10)); press(comic)
        waitForText(["5 / 7"], in: position, timeout: 25)
        XCTAssertTrue(textValue(direction).contains("从右到左")); XCTAssertTrue(textValue(layout).contains("单页"))
        navigateWorkspace("import-pdf", in: app)
        try chooseInput(broken, trigger: app.buttons["import-pdf"].firstMatch, app: app)
        let dismissError = try modalButton(app, titles: ["知道了"])
        let archiveError: String
        switch format {
        case "cbt": archiveError = "CBT 无效或 TAR 结构不受支持；仅接受未压缩 POSIX USTAR 普通文件／目录，不支持 PAX、GNU 扩展、链接、特殊文件、分卷或加密容器。"
        case "cb7", "cbr": archiveError = "CB7 / CBR 无效或结构不受支持：CB7 仅 COPY/LZMA/LZMA2、明文头、非 solid；CBR 仅 RAR4/RAR5 STORE。均不支持加密、分卷、自解压、扩展记录或其他解码路线。"
        default: archiveError = "CBZ 无效、路径不安全、校验失败或 ZIP 结构不受支持（加密、分卷、ZIP64）。"
        }
        XCTAssertTrue(app.staticTexts[archiveError].firstMatch.exists)
        press(dismissError)
        waitForText(["5 / 7"], in: position, timeout: 5)
        navigateWorkspace("open-sample", in: app)
        press(app.buttons["open-sample"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 10)
        navigateWorkspace("open-epub-sample", in: app)
        press(app.buttons["open-epub-sample"].firstMatch)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        navigateWorkspace("library-comic", in: app)
        press(comic); waitForText(["5 / 7"], in: position, timeout: 25)
        XCTAssertEqual(try Data(contentsOf: archive), bytes)
    }
    @MainActor private func waitUntilEnabled(_ element: XCUIElement) {
        let ready = expectation(for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: element)
        wait(for: [ready], timeout: 10)
    }
    @MainActor private func chooseInput(_ url: URL, trigger: XCUIElement, app: XCUIApplication) throws {
        press(trigger)
        let open = filePanelButton(app, titles: ["Open", "打开"])
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        try goToFixtureLocation(url, app: app)
        // Choosing a file completion can also accept the selected file. Require actual import/output state below.
        if open.exists { waitUntilEnabled(open); press(open) }
    }
    @MainActor private func filePanelButton(_ app: XCUIApplication, titles: [String]) -> XCUIElement {
        // The actual macOS panel action reports OKButton; a name-only query can select the Touch Bar.
        if titles.contains("Open") || titles.contains("Save") { return app.buttons["OKButton"].firstMatch }
        return app.buttons[titles[0]].firstMatch.exists ? app.buttons[titles[0]].firstMatch : app.buttons[titles[1]].firstMatch
    }
    @MainActor private func modalButton(_ app: XCUIApplication, titles: [String]) throws -> XCUIElement {
        var found: XCUIElement?
        let ready = expectation(for: NSPredicate { _, _ in
            for scope in [app.dialogs, app.sheets, app.windows] {
                for title in titles {
                    let candidate = scope.buttons[title].firstMatch
                    if candidate.exists && candidate.isHittable && !candidate.frame.isEmpty { found = candidate; return true }
                }
            }
            return false
        }, evaluatedWith: app)
        wait(for: [ready], timeout: 10)
        if found == nil {
            print("PDFno original modal counts: windows=\(app.windows.count) dialogs=\(app.dialogs.count) sheets=\(app.sheets.count)")
            print("PDFno original modal buttons: " + app.buttons.allElementsBoundByIndex.prefix(40).map {
                "id=\($0.identifier) label=\($0.label) frame=\($0.frame) hittable=\($0.isHittable)"
            }.joined(separator: "; "))
        }
        return try XCTUnwrap(found, "The actual modal action must exist and be hittable")
    }
    @MainActor private func goToFixtureLocation(_ url: URL, app: XCUIApplication) throws {
        app.typeKey("g", modifierFlags: [.command, .shift])
        let location = app.textFields["PathTextField"].firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 5))
        enterSearch(url.path, into: location, replacing: true)
        XCTAssertEqual(location.value as? String, url.path)
        // The completion label is not hittable on macOS; select its actual row/cell by mouse.
        // A keyboard Return here can crash the system panel's input-context service.
        let fixture = NSPredicate(format: "label == %@ OR value == %@", url.lastPathComponent, url.lastPathComponent)
        let rows: [XCUIElement.ElementType] = [.cell, .tableRow, .outlineRow]
        let candidates = rows.flatMap { app.descendants(matching: $0).containing(fixture).allElementsBoundByIndex }
        let completion = try XCTUnwrap(candidates.first { $0.isHittable && !$0.frame.isEmpty
            && $0.frame.minX.isFinite && $0.frame.minY.isFinite }, "The actual fixture completion must be hittable")
        completion.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).doubleClick()
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !location.exists || !location.isHittable
        }, object: app)
        if XCTWaiter.wait(for: [dismissed], timeout: 5) == .completed { return }
        if !location.exists || !location.isHittable { return }
        XCTFail("The original fixture Go-to overlay must close before using the file-panel action")
        throw NSError(domain: "PDFnoOriginalFixturePanel", code: 1)
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
            for field in [u32(0x04034b50), u16(20), u16(0x0800), u16(0), u16(0), u16(0),
                          u32(checksum), u32(data.count), u32(data.count), u16(name.count), u16(0), name, data] { local.append(field) }
            for field in [u32(0x02014b50), u16(0x0314), u16(20), u16(0x0800), u16(0), u16(0), u16(0),
                          u32(checksum), u32(data.count), u32(data.count), u16(name.count), u16(0), u16(0),
                          u16(0), u16(0), u32(0x8000 << 16), u32(offset), name] { central.append(field) }
        }
        let centralOffset = local.count
        local.append(central)
        for field in [u32(0x06054b50), u16(0), u16(0), u16(entries.count), u16(entries.count),
                      u32(central.count), u32(centralOffset), u16(0)] { local.append(field) }
        return local
    }
    @MainActor func testMacPDFWholePageOfflineConsentBilingualNotesAndSourceReturn() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchEnvironment["PDFNO_UI_TEST_PAGE_FIXTURE"] = "multi"
        app.launch(); app.activate()
        navigateWorkspace("open-sample", in: app)
        XCTAssertTrue(app.buttons["open-sample"].firstMatch.waitForExistence(timeout: 15)); press(app.buttons["open-sample"].firstMatch)
        press(app.buttons["reader-page-translation"].firstMatch)
        guard app.staticTexts["page-offline-fixture"].firstMatch.waitForExistence(timeout: 5) else {
            XCTFail("Fully intercepted transport required before synthetic key entry"); app.terminate(); return
        }
        let scope = app.staticTexts["page-scope"].firstMatch
        XCTAssertTrue(textValue(scope).contains("第 1 页") && textValue(scope).contains("3 段"))
        let start = app.buttons["page-start"].firstMatch
        XCTAssertFalse(start.isEnabled)
        let key = app.descendants(matching: .any).matching(identifier: "page-session-key").firstMatch
        enterSearch("synthetic-reading-ui-credential", into: key, replacing: true)
        XCTAssertFalse(start.isEnabled, "Key entry never sends or implicitly consents")
        press(app.descendants(matching: .any).matching(identifier: "page-scope-consent").firstMatch)
        XCTAssertTrue(start.isEnabled); press(start)
        waitForText(["全部 3 段", "未自动保存"], in: app.staticTexts["page-status"].firstMatch, timeout: 10)
        for index in 0..<3 {
            let original = app.staticTexts["page-original-\(index)"].firstMatch
            let result = app.staticTexts["page-result-\(index)"].firstMatch
            XCTAssertTrue(original.exists && result.exists)
            XCTAssertTrue(textValue(result).contains("离线 DeepSeek UI 替身"))
        }
        XCTAssertTrue(textValue(app.staticTexts["page-original-2"].firstMatch).contains("line 18:"), "The final page text must remain in the whole-page scope")
        let note = app.descendants(matching: .any).matching(identifier: "page-user-note-0").firstMatch
        scrollPageElement(note, in: app); enterSearch("Original synthetic whole page note", into: note)
        waitForText(["Original synthetic whole page note"], in: note, timeout: 5)
        let save = app.buttons["page-save-0"].firstMatch
        scrollPageElement(save, in: app)
        XCTAssertTrue(app.scrollViews["page-scroll"].firstMatch.frame.insetBy(dx: 4, dy: 8).contains(save.frame),
                      "The actual save button must fit inside the scroll viewport before clicking")
        print("Original whole-page save controls: note frame =", note.frame, "; save frame =", save.frame,
              "; scroll frame =", app.scrollViews["page-scroll"].firstMatch.frame, "; enabled =", save.isEnabled)
        press(save)
        waitForText(["已保存"], in: save, timeout: 5)
        let feedback = app.staticTexts["page-note-status-0"].firstMatch
        print("Original whole-page save return:", feedback.exists ? textValue(feedback) : "action-feedback-absent")
        let store = URL(fileURLWithPath: "/tmp", isDirectory: true).appendingPathComponent("PDFno-UITests-" + token).appendingPathComponent("learning-v1.json")
        if let data = try? Data(contentsOf: store), let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let notes = state["notes"] as? [[String: Any]] {
            print("Original whole-page disk evidence: schema =", state["schemaVersion"] ?? "missing", "; notes =", notes.count)
            XCTAssertEqual(notes.count, 1)
            XCTAssertEqual(notes.first?["userText"] as? String, "Original synthetic whole page note")
            let result = notes.first?["result"] as? [String: Any], source = result?["source"] as? [String: Any]
            let anchor = source?["anchor"] as? [String: Any], page = anchor?["pdfPage"] as? [String: Any], payload = page?["_0"] as? [String: Any]
            XCTAssertEqual(payload?["pageIndex"] as? Int, 0)
            XCTAssertTrue((payload?["pageText"] as? String)?.contains("line 18:") == true)
            XCTAssertFalse(String(decoding: data, as: UTF8.self).contains("synthetic-reading-ui-credential"))
        } else {
            print("Original whole-page disk evidence: manifest exists =", FileManager.default.fileExists(atPath: store.path))
            XCTFail("The manual whole-page note must exist in the isolated learning store before restart")
        }
        scrollPageToTop(in: app); press(app.buttons["page-return-source"].firstMatch)
        XCTAssertTrue(textValue(app.staticTexts["page-position"].firstMatch).contains("1 / 1"))
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-book", in: app)
        let book = app.descendants(matching: .any).matching(identifier: "library-book").firstMatch
        navigateWorkspace("library-book", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        press(app.buttons["reader-page-translation"].firstMatch)
        XCTAssertFalse(app.buttons["page-start"].firstMatch.isEnabled)
        XCTAssertFalse(app.staticTexts["page-result-0"].firstMatch.exists)
        press(app.buttons["page-close"].firstMatch)
        press(app.buttons["reader-ai"].firstMatch)
        let saved = app.staticTexts["ai-saved-user-note"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); XCTAssertEqual(textValue(saved), "Original synthetic whole page note")
        press(app.buttons["ai-saved-source"].firstMatch)
        XCTAssertTrue(textValue(app.staticTexts["page-position"].firstMatch).contains("1 / 1"))
        app.terminate()
    }
    @MainActor func testMacEPUBChapterCompleteScopeConsentBilingualManualSaveRestartAndSourceReturn() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launch(); app.activate()
        defer { app.terminate() }
        openChapterFixture(in: app, japanese: true)
        press(app.buttons["epub-chapter-translation"].firstMatch)
        guard app.staticTexts["chapter-offline-fixture"].firstMatch.waitForExistence(timeout: 5) else {
            XCTFail("Fully intercepted transport required before synthetic key entry"); return
        }
        XCTAssertTrue(textValue(app.staticTexts["chapter-definition"].firstMatch).contains("目录"))
        waitForText(["2 / 2", "OEBPS/japanese.xhtml", "2837", "0–2837"], in: app.staticTexts["chapter-scope"].firstMatch, timeout: 5)
        waitForText(["完整计划 6 段", "6144", "180", "0 / 6"], in: app.staticTexts["chapter-limits"].firstMatch, timeout: 5)
        XCTAssertFalse(app.buttons["chapter-start"].firstMatch.isEnabled)
        let original = app.descendants(matching: .any).matching(identifier: "chapter-original-0").firstMatch
        XCTAssertTrue(original.exists); XCTAssertTrue(textValue(original).contains("日本語")); XCTAssertFalse(textValue(original).contains("にほんご"))
        XCTAssertFalse(app.staticTexts["chapter-result-0"].firstMatch.exists)
        let key = app.descendants(matching: .any).matching(identifier: "chapter-session-key").firstMatch
        scrollChapterElement(key, in: app); enterSearch("synthetic-reading-ui-credential", into: key, replacing: true)
        XCTAssertFalse(app.buttons["chapter-start"].firstMatch.isEnabled)
        let consent = app.descendants(matching: .any).matching(identifier: "chapter-scope-consent").firstMatch
        scrollChapterElement(consent, in: app); press(consent)
        let start = app.buttons["chapter-start"].firstMatch; scrollChapterElement(start, in: app); press(start)
        waitForText(["全部 6 段", "未自动保存"], in: app.staticTexts["chapter-status"].firstMatch, timeout: 15)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "chapter-session-key").firstMatch.exists)
        let result = app.descendants(matching: .any).matching(identifier: "chapter-result-0").firstMatch
        XCTAssertTrue(result.exists); XCTAssertTrue(textValue(result).contains("离线 DeepSeek"))
        let note = app.descendants(matching: .any).matching(identifier: "chapter-user-note-0").firstMatch
        scrollChapterElement(note, in: app); enterSearch("Original synthetic whole chapter note", into: note)
        let save = app.buttons["chapter-save-0"].firstMatch
        scrollChapterElement(save, in: app); press(save); waitForText(["已保存"], in: save, timeout: 5)
        let store = URL(fileURLWithPath: "/tmp", isDirectory: true).appendingPathComponent("PDFno-UITests-" + token).appendingPathComponent("learning-v1.json")
        let bytes = try Data(contentsOf: store), object = try XCTUnwrap(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        let notes = try XCTUnwrap(object["notes"] as? [[String: Any]])
        XCTAssertEqual(notes.count, 1); XCTAssertEqual(notes[0]["userText"] as? String, "Original synthetic whole chapter note")
        let saved = try XCTUnwrap(notes[0]["result"] as? [String: Any])
        XCTAssertEqual(saved["promptVersion"] as? String, "deepseek-epub-chapter-1")
        let source = try XCTUnwrap(saved["source"] as? [String: Any]), anchor = try XCTUnwrap(source["anchor"] as? [String: Any])
        XCTAssertNotNil(anchor["epubChapter"]); XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("synthetic-reading-ui-credential"))
        let back = app.buttons["chapter-return-source"].firstMatch
        scrollChapterElement(back, in: app); press(back)
        waitForText(["第 2 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 10)
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-epub", in: app)
        let book = app.descendants(matching: .any).matching(identifier: "library-epub").firstMatch
        navigateWorkspace("library-epub", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        waitForText(["第 2 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        press(app.buttons["epub-chapter-translation"].firstMatch)
        XCTAssertFalse(app.buttons["chapter-start"].firstMatch.isEnabled)
        XCTAssertFalse(app.staticTexts["chapter-result-0"].firstMatch.exists)
        let restartedKey = app.descendants(matching: .any).matching(identifier: "chapter-session-key").firstMatch
        XCTAssertTrue(restartedKey.exists); XCTAssertTrue((restartedKey.value as? String ?? "").isEmpty)
        press(app.buttons["chapter-close"].firstMatch)
        press(app.buttons["epub-ai"].firstMatch)
        let savedText = app.descendants(matching: .any).matching(identifier: "ai-saved-user-note").firstMatch
        XCTAssertTrue(savedText.waitForExistence(timeout: 5)); XCTAssertEqual(textValue(savedText), "Original synthetic whole chapter note")
        press(app.buttons["ai-saved-source"].firstMatch)
        waitForText(["第 2 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 10)
    }
    @MainActor func testMacEPUBChapterOversizeRefusesWholeDocumentWithoutKeyOrSend() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launch(); app.activate(); defer { app.terminate() }
        openChapterFixture(in: app, japanese: false)
        press(app.buttons["epub-chapter-translation"].firstMatch)
        waitForText(["3000", "不会静默截断", "选文 AI"], in: app.staticTexts["chapter-preparation-error"].firstMatch, timeout: 5)
        XCTAssertTrue(textValue(app.staticTexts["chapter-scope"].firstMatch).contains("OEBPS/english.xhtml"))
        XCTAssertFalse(app.buttons["chapter-start"].firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "chapter-session-key").firstMatch.exists)
        XCTAssertFalse(app.staticTexts["chapter-result-0"].firstMatch.exists)
    }
    @MainActor func testMacEPUBChapterCancelStopsRemainderAndReopenCannotRetryOrRestoreKey() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"; app.launchEnvironment["PDFNO_UI_TEST_CHAPTER_RESPONSE"] = "slow"
        app.launch(); app.activate(); defer { app.terminate() }
        openChapterFixture(in: app, japanese: true)
        startChapterFixture(in: app)
        waitForText(["正在处理第 1 / 6 段"], in: app.staticTexts["chapter-status"].firstMatch, timeout: 5)
        press(app.buttons["chapter-cancel"].firstMatch)
        waitForText(["已取消"], in: app.staticTexts["chapter-status"].firstMatch, timeout: 5)
        waitForText(["1 / 6"], in: app.staticTexts["chapter-limits"].firstMatch, timeout: 5)
        XCTAssertFalse(app.staticTexts["chapter-result-0"].firstMatch.exists)
        press(app.buttons["chapter-close"].firstMatch); press(app.buttons["epub-chapter-translation"].firstMatch)
        XCTAssertFalse(app.buttons["chapter-start"].firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "chapter-session-key").firstMatch.exists)
        waitForText(["1 / 6"], in: app.staticTexts["chapter-limits"].firstMatch, timeout: 5)
    }
    @MainActor func testMacEPUBChapterPartialFailureKeepsFirstSegmentAndStopsAllRemaining() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"; app.launchEnvironment["PDFNO_UI_TEST_CHAPTER_RESPONSE"] = "fail-second"
        app.launch(); app.activate(); defer { app.terminate() }
        openChapterFixture(in: app, japanese: true); startChapterFixture(in: app)
        waitForText(["未完成", "已完成 1 / 6", "无自动重试"], in: app.staticTexts["chapter-status"].firstMatch, timeout: 10)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "chapter-result-0").firstMatch.exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "chapter-result-1").firstMatch.exists)
        waitForText(["2 / 6"], in: app.staticTexts["chapter-limits"].firstMatch, timeout: 5)
        XCTAssertFalse(app.buttons["chapter-start"].firstMatch.exists)
        let save = app.buttons["chapter-save-0"].firstMatch
        scrollChapterElement(save, in: app); press(save); waitForText(["已保存"], in: save, timeout: 5)
    }
    @MainActor private func openChapterFixture(in app: XCUIApplication, japanese: Bool) {
        navigateWorkspace("open-epub-sample", in: app)
        let sample = app.buttons["open-epub-sample"].firstMatch
        navigateWorkspace("open-epub-sample", in: app)
        XCTAssertTrue(sample.waitForExistence(timeout: 15)); press(sample)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        if japanese {
            press(app.buttons["epub-contents"].firstMatch); press(app.buttons["epub-chapter-1"].firstMatch)
            waitForText(["第 2 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 20)
        }
    }
    @MainActor private func startChapterFixture(in app: XCUIApplication) {
        press(app.buttons["epub-chapter-translation"].firstMatch)
        guard app.staticTexts["chapter-offline-fixture"].firstMatch.waitForExistence(timeout: 5) else {
            XCTFail("Fully intercepted transport required before synthetic key entry"); return
        }
        let key = app.descendants(matching: .any).matching(identifier: "chapter-session-key").firstMatch
        scrollChapterElement(key, in: app); enterSearch("synthetic-reading-ui-credential", into: key, replacing: true)
        let consent = app.descendants(matching: .any).matching(identifier: "chapter-scope-consent").firstMatch
        scrollChapterElement(consent, in: app); press(consent)
        let start = app.buttons["chapter-start"].firstMatch
        scrollChapterElement(start, in: app); press(start)
    }
    @MainActor private func scrollChapterElement(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews["chapter-scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let viewport = scroll.frame.insetBy(dx: 4, dy: 8), target = element.frame
            if !target.isEmpty, viewport.contains(target), element.isHittable { return }
            let delta = target.minY < viewport.minY ? min(300, max(48, viewport.minY - target.minY + 16)) : -min(300, max(48, target.maxY - viewport.maxY + 16))
            scroll.scroll(byDeltaX: 0, deltaY: delta)
        }
        XCTAssertTrue(scroll.frame.insetBy(dx: 4, dy: 8).contains(element.frame), "Chapter control must be completely inside scroll viewport")
    }
    @MainActor func testMacPDFPageScanAndOversizeRefuseWithoutSend() throws {
        for mode in ["blank", "over-budget"] {
            let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
            app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"; app.launchEnvironment["PDFNO_UI_TEST_PAGE_FIXTURE"] = mode
            app.launch(); app.activate()
            navigateWorkspace("open-sample", in: app)
            XCTAssertTrue(app.buttons["open-sample"].firstMatch.waitForExistence(timeout: 15)); press(app.buttons["open-sample"].firstMatch)
            press(app.buttons["reader-page-translation"].firstMatch)
            let error = app.staticTexts["page-preparation-error"].firstMatch
            XCTAssertTrue(error.waitForExistence(timeout: 5)); XCTAssertTrue(textValue(error).contains(mode == "blank" ? "OCR" : "3000"))
            XCTAssertFalse(app.buttons["page-start"].firstMatch.exists); XCTAssertFalse(app.secureTextFields["page-session-key"].firstMatch.exists)
            press(app.buttons["page-close"].firstMatch); app.terminate()
        }
    }
    @MainActor func testMacPDFPageCancelStopsRemainderAndReopenKeepsAttemptCount() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"; app.launchEnvironment["PDFNO_UI_TEST_PAGE_FIXTURE"] = "multi"
        app.launchEnvironment["PDFNO_UI_TEST_PAGE_RESPONSE"] = "slow"
        app.launch(); app.activate()
        navigateWorkspace("open-sample", in: app)
        XCTAssertTrue(app.buttons["open-sample"].firstMatch.waitForExistence(timeout: 15)); press(app.buttons["open-sample"].firstMatch)
        press(app.buttons["reader-page-translation"].firstMatch)
        guard app.staticTexts["page-offline-fixture"].firstMatch.waitForExistence(timeout: 5) else {
            XCTFail("Fully intercepted transport required before synthetic key entry"); app.terminate(); return
        }
        let key = app.descendants(matching: .any).matching(identifier: "page-session-key").firstMatch
        enterSearch("synthetic-reading-ui-credential", into: key, replacing: true)
        press(app.descendants(matching: .any).matching(identifier: "page-scope-consent").firstMatch); press(app.buttons["page-start"].firstMatch)
        waitForText(["正在处理第 1 / 3 段"], in: app.staticTexts["page-status"].firstMatch, timeout: 5)
        let cancel = app.buttons["page-cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 5)); press(cancel)
        waitForText(["已取消"], in: app.staticTexts["page-status"].firstMatch, timeout: 5)
        XCTAssertFalse(app.staticTexts["page-result-0"].firstMatch.exists)
        waitForText(["1 / 6"], in: app.staticTexts["page-limits"].firstMatch, timeout: 5)
        press(app.buttons["page-close"].firstMatch); press(app.buttons["reader-page-translation"].firstMatch)
        XCTAssertFalse(app.buttons["page-start"].firstMatch.isEnabled)
        XCTAssertTrue(textValue(app.staticTexts["page-limits"].firstMatch).contains("1 / 6"))
        app.terminate()
    }
    @MainActor func testMacDeepSeekSelectionOfflineTransportPDFEPUBAndRestart() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launch(); app.activate()
        navigateWorkspace("open-sample", in: app)
        let sample = app.buttons["open-sample"].firstMatch
        navigateWorkspace("open-sample", in: app)
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
        navigateWorkspace("ai-settings", in: app)
        press(app.buttons["ai-settings"].firstMatch)
        let preset = app.buttons["ai-use-deepseek"].firstMatch
        XCTAssertTrue(preset.waitForExistence(timeout: 5)); press(preset)
        let key = app.descendants(matching: .any).matching(identifier: "ai-session-key").firstMatch
        XCTAssertTrue(key.waitForExistence(timeout: 5)); enterSearch("synthetic-reading-ui-credential", into: key, replacing: true)
        press(app.buttons["ai-settings-save"].firstMatch)
        press(app.buttons["reader-ai"].firstMatch)
        let start = app.buttons["ai-start"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout: 5)); XCTAssertFalse(start.isEnabled)
        XCTAssertEqual(textValue(app.staticTexts["ai-source-quote"].firstMatch), "window")
        let consent = japaneseElement("ai-scope-consent", in: app)
        scrollRecordElement(consent, listID: "ai-notes-list", app: app)
        press(consent); XCTAssertTrue(start.isEnabled)
        scrollRecordElement(start, listID: "ai-notes-list", app: app); press(start)
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
        navigateWorkspace("open-epub-sample", in: app)
        press(app.buttons["open-epub-sample"].firstMatch)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        let paragraph = try webText(in: app, matching: "window", prefix: true, timeout: 10)
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        press(app.buttons["epub-ai"].firstMatch)
        XCTAssertTrue(app.staticTexts["ai-source-quote"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["ai-saved-user-note"].firstMatch.exists)
        let kind = app.popUpButtons["ai-kind"].firstMatch
        XCTAssertTrue(kind.waitForExistence(timeout: 5)); press(kind); press(app.menuItems["选文解释"].firstMatch)
        scrollRecordElement(consent, listID: "ai-notes-list", app: app); press(consent)
        scrollRecordElement(start, listID: "ai-notes-list", app: app); waitUntilEnabled(start); press(start)
        XCTAssertTrue(result.waitForExistence(timeout: 8)); XCTAssertTrue(textValue(result).contains("解释"))
        press(app.buttons["ai-save-note"].firstMatch)
        XCTAssertTrue(app.staticTexts["ai-saved-result"].firstMatch.waitForExistence(timeout: 8))
        press(app.buttons["ai-result-source"].firstMatch)
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-epub", in: app)
        let book = app.descendants(matching: .any).matching(identifier: "library-epub").firstMatch
        navigateWorkspace("library-epub", in: app)
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
        navigateWorkspace("open-sample", in: app)
        let sample = app.buttons["open-sample"].firstMatch
        navigateWorkspace("open-sample", in: app)
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
        navigateWorkspace("ai-settings", in: app)
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
        navigateWorkspace("library-book", in: app)
        let book = app.descendants(matching: .any).matching(identifier: "library-book").firstMatch
        navigateWorkspace("library-book", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        press(app.buttons["reader-ai"].firstMatch)
        XCTAssertTrue(userNote.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(userNote), "Original synthetic AI user note")
        XCTAssertEqual(textValue(app.staticTexts["ai-saved-quote"].firstMatch), "window")
        press(app.buttons["ai-saved-source"].firstMatch)
        navigateWorkspace("open-epub-sample", in: app)
        let epubSample = app.buttons["open-epub-sample"].firstMatch
        navigateWorkspace("open-epub-sample", in: app)
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
        navigateWorkspace("open-epub-sample", in: app)
        let sample = app.buttons["open-epub-sample"].firstMatch
        navigateWorkspace("open-epub-sample", in: app)
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
        let next = app.buttons["epub-next"].firstMatch
        // Returning to source closes the inspector and starts native WebKit resize.
        // A click during that disabled interval is ignored. Synchronize the real
        // control before clicking; keep the original page assertion and its deadline.
        var readySince: TimeInterval?
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard next.exists, next.isEnabled, next.isHittable,
                  !app.buttons["epub-return"].firstMatch.exists else {
                readySince = nil; return false
            }
            let now = ProcessInfo.processInfo.systemUptime
            if readySince == nil { readySince = now }
            return now - (readySince ?? now) >= 0.3
        }, object: app)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 10), .completed,
                       "Source return and reader resize must finish before the real next-page click")
        press(next)
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
        navigateWorkspace("library-epub", in: app)
        let book = app.descendants(matching: .any).matching(identifier: "library-epub").firstMatch
        navigateWorkspace("library-epub", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        waitForText(["第 2 章", "竖排"], in: position, timeout: 20)
        press(app.buttons["epub-notes"].firstMatch)
        XCTAssertTrue(quote.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(quote), selectedText)
        press(app.buttons["epub-return"].firstMatch)
        waitForText(["第 1 章"], in: position, timeout: 10)
        app.terminate()
    }
    #endif
    @MainActor private func scrollPageToTop(in app: XCUIApplication) {
        scrollPageElement(app.buttons["page-return-source"].firstMatch, in: app)
    }
    @MainActor private func scrollPageElement(_ element: XCUIElement, in app: XCUIApplication) {
        let scroll = app.scrollViews["page-scroll"].firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 5))
        for _ in 0..<12 {
            let viewport = scroll.frame.insetBy(dx: 4, dy: 8), target = element.frame
            // CI proved isHittable could be true for a save button entirely
            // below this clip view. Require its full physical frame, including
            // a small edge margin, before synthesizing the real user click.
            if !target.isEmpty, viewport.contains(target), element.isHittable { return }
            let delta: CGFloat
            if target.minY < viewport.minY {
                delta = min(300, max(48, viewport.minY - target.minY + 16))
            } else {
                delta = -min(300, max(48, target.maxY - viewport.maxY + 16))
            }
            // Positive pixel deltas move toward the top. Reverse if a prior
            // scroll passed the target; retain the same twelve-step bound.
            scroll.scroll(byDeltaX: 0, deltaY: delta)
        }
        XCTAssertTrue(scroll.frame.insetBy(dx: 4, dy: 8).contains(element.frame), "Target must be completely inside the page scroll viewport")
        XCTAssertTrue(element.isHittable)
    }
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
    @MainActor private func enterSearch(_ text: String, into input: XCUIElement, replacing: Bool = false) {
        press(input)
        #if os(macOS)
        let literalField = input.identifier == "library-search-input" || input.identifier.hasPrefix("chapter-user-note-")
        let previousValue = literalField && !replacing ? (input.value as? String ?? "") : ""
        if replacing { input.typeKey("a", modifierFlags: .command) }
        // A user-selected input method can turn typeText into composition text.
        // Write only synthetic fixture data; never read or back up the system clipboard.
        let board = NSPasteboard.general
        board.clearContents(); board.setString(text, forType: .string)
        input.typeKey("v", modifierFlags: .command)
        if literalField {
            // macOS can publish a transient InputSource dialog after paste.
            // Read the real field and let that indicator disappear before the
            // next click/scroll; do not change input sources or dismiss alerts.
            let app = XCUIApplication(), expected = previousValue + text
            var quietSince: TimeInterval?
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard input.exists, (input.value as? String) == expected,
                      !app.buttons["InputSource"].firstMatch.exists else {
                    quietSince = nil; return false
                }
                let now = ProcessInfo.processInfo.systemUptime
                if quietSince == nil { quietSince = now }
                return now - (quietSince ?? now) >= 1
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 8), .completed,
                           "Literal fixture value and input indicator must settle before the next action")
        }
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
        navigateWorkspace("open-sample", in: app)
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
        navigateWorkspace("open-sample", in: app)
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
        navigateWorkspace("library-book", in: app)
        let book = app.descendants(matching: .any).matching(identifier: "library-book").firstMatch
        XCTAssertTrue(book.waitForExistence(timeout: 10))
        navigateWorkspace("library-book", in: app)
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
