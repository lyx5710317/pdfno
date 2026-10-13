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
        if id == "import-pdf", target("document-add").exists { return }
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
            if example || tools {
                // Native example and tools controls enter the popover's AX tree
                // after its launcher click. Await the requested control before
                // the caller checks the original entry or opens its workspace.
                XCTAssertTrue(target(id).waitForExistence(timeout: 10))
                traceWorkspaceEntry(id, element: target(id))
            }
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

    @MainActor private func nativeImportEntry(_ app: XCUIApplication) -> XCUIElement {
        #if os(macOS)
        let add = app.buttons["document-add"].firstMatch
        if add.exists { return add }
        #endif
        return app.buttons["import-pdf"].firstMatch
    }
    @MainActor private func currentToolReturn(_ app: XCUIApplication, formerID: String) -> XCUIElement {
        let back = app.buttons["workspace-tool-return"].firstMatch
        return back.exists ? back : app.buttons[formerID].firstMatch
    }
    @MainActor private func currentLanguageLauncher(_ app: XCUIApplication, formerID: String) throws -> XCUIElement {
        if !ui("document-more", app).exists { resumeCurrentDocument(app) }
        if formerID.hasPrefix("reader-") {
            try uiPanel("reader-notes", open: false, app)
            try uiSelectPDFWindow(app)
        }
        return ui("selection-ai-menu", app)
    }
    @MainActor private func chooseCurrentLanguage(_ id: String, app: XCUIApplication) throws {
        let languages = ["document-japanese-learning": "japanese", "document-english-learning": "english"]
        let language = try XCTUnwrap(languages[id])
        try uiLanguageMenuAction(language, review: true, app)
        XCTAssertFalse(ui("language-compatibility-test-host", app).exists)
    }
    @MainActor private func resumeCurrentDocument(_ app: XCUIApplication) {
        let tabs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'document-tab-' AND NOT identifier BEGINSWITH 'document-tab-close-'"))
        XCTAssertEqual(tabs.count, 1, "Resume the scenario's single real document tab")
        press(tabs.firstMatch)
    }
    @MainActor private func openCurrentFileMenu(_ app: XCUIApplication) {
        if !app.descendants(matching: .any).matching(identifier: "document-more").firstMatch.exists { resumeCurrentDocument(app) }
        press(app.descendants(matching: .any).matching(identifier: "document-more").firstMatch)
    }
    @MainActor private func openCurrentFileAction(_ id: String, app: XCUIApplication) {
        openCurrentFileMenu(app)
        let menu = app.menuItems.matching(identifier: id).firstMatch
        XCTAssertTrue(menu.waitForExistence(timeout: 10)); XCTAssertTrue(menu.isEnabled)
        press(menu)
    }

    @MainActor private func traceWorkspaceEntry(_ id: String, element: XCUIElement) {
        guard ProcessInfo.processInfo.environment["PDFNO_UI_TEST_PANEL_DIAGNOSTICS"] == "1" else { return }
        // The caller has already awaited this exact public entry. Successful
        // diagnostics must not repeatedly traverse the reader's AX tree.
        print("PDFno original workspace entry diagnostic id=\(id) ready-after-existence-wait")
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
        let prefix = ebook ? "ebook" : "textformat"
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
            XCTAssertTrue(nativeImportEntry(app).waitForExistence(timeout: 15))
            navigateWorkspace("import-pdf", in: app)
            try chooseInput(input, trigger: nativeImportEntry(app), app: app)
        }
        let navigation = app.buttons[prefix + "-navigation"].firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        let paragraph = try webText(in: app, matching: ebook ? "Original source" : "window", prefix: true, timeout: 10)
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        try uiBeginNote(app); try uiPaste("Original committed parity body", ui("annotation-comment-input", app)); try uiSaveNote(app)
        try uiPanel(prefix + "-notes", open: true, app)
        let before = try uiOnlyAnnotation(app), quote = try XCTUnwrap(uiAnchorPayload(before)["quote"] as? String)
        XCTAssertFalse(quote.isEmpty); try uiEditNote(app)
        try uiPaste("Original uncommitted draft 日本語", ui("annotation-comment-input", app))
        XCTAssertEqual(try uiOnlyAnnotation(app)["userText"] as? String, "Original committed parity body")
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace(ebook ? "library-ebook-mobi" : "library-textformat", in: app)
        let row = japaneseElement(ebook ? "library-ebook-mobi" : "library-textformat", in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 15)); press(row)
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        try uiPanel(prefix + "-notes", open: true, app); try uiResumeDraft(app)
        XCTAssertEqual(uiText(ui("annotation-comment-input", app)), "Original uncommitted draft 日本語")
        try uiClick(ui("annotation-editor-cancel", app)); XCTAssertEqual(try uiOnlyAnnotation(app)["userText"] as? String, "Original committed parity body")
        try uiEditNote(app); let body = "Saved parity body cafe\u{301} 日本語"
        try uiPaste(body, ui("annotation-comment-input", app)); try uiSaveNote(app)
        let after = try uiOnlyAnnotation(app)
        XCTAssertEqual(after["userText"] as? String, body); XCTAssertEqual(after["anchor"] as? NSDictionary, before["anchor"] as? NSDictionary)
        try uiPanel(prefix + "-notes", open: false, app); press(app.buttons["library-search"].firstMatch)
        let search = app.textFields["library-search-input"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8)); enterSearch("saved parity body CAFÉ", into: search)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        let preview = japaneseElement("record-search-preview", in: app)
        XCTAssertTrue(preview.waitForExistence(timeout: 5)); XCTAssertTrue(textValue(preview).contains("Saved parity"))
        press(app.buttons["record-search-source"].firstMatch)
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        try uiPanel(prefix + "-notes", open: true, app)
        let returnedQuote = ui("annotation-excerpt", app)
        XCTAssertTrue(returnedQuote.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(returnedQuote), quote)
        XCTAssertEqual(try uiOnlyAnnotation(app)["anchor"] as? NSDictionary, before["anchor"] as? NSDictionary)
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
        press(app.buttons["japanese-learning-close"].firstMatch); try uiCloseLanguageReview(app); try uiLegacySavedNotes("reader", app)
        pressEditingElement(app.buttons["japanese-note-edit"].firstMatch, app: app)
        enterEditingText("Saved Japanese parity body cafe\u{301}", prefix: "japanese-note", app: app)
        pressEditingElement(app.buttons["japanese-note-edit-save"].firstMatch, app: app)
        waitForText(["已保存"], in: japaneseElement("japanese-note-edit-status", in: app), timeout: 8)
        let after = try originalSavedNote(token, manifest: "japanese-learning-v1.json")
        XCTAssertEqual(after["review"] as? NSDictionary, before["review"] as? NSDictionary)
        XCTAssertEqual(after["corrections"] as? NSArray, before["corrections"] as? NSArray)
        XCTAssertEqual(after["userText"] as? String, "Saved Japanese parity body cafe\u{301}")
        try uiClick(ui("legacy-notes-close", app)); try uiPanel("reader-notes", open: false, app); press(app.buttons["library-search"].firstMatch)
        enterSearch("saved Japanese parity CAFÉ", into: app.textFields["library-search-input"].firstMatch)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        press(app.buttons["record-search-source"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 10)
        XCTAssertEqual(try originalSavedNote(token, manifest: "japanese-learning-v1.json")["review"] as? NSDictionary, before["review"] as? NSDictionary)
    }

    @MainActor func testMacConfiguredAPIExplicitRecipientManualSaveAndSharedTranslation() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app); try uiLegacyAI(app)
        guard ui("ai-offline-fixture", app).waitForExistence(timeout: 5) else { XCTFail("Intercepted transport required before synthetic credential"); return }
        try uiCloseLegacyAI(app); try uiSettings(app)
        try uiClick(ui("ai-provider-mode", app)); try uiClick(app.menuItems["OpenAI 兼容"].firstMatch)
        try uiPaste("https://joint-ui.example/v1", ui("ai-endpoint", app)); try uiPaste("original-ui-model", ui("ai-model", app))
        try uiSyntheticCredential("synthetic-reading-ui-credential", ui("ai-session-key", app))
        XCTAssertEqual(try uiAnnotations(app).count, 0)
        try uiClick(ui("ai-settings-save", app)); try uiContains(ui("ai-connection-status", app), "已应用")
        try uiContains(ui("ai-credential-status", app), "已配置"); try uiClick(ui("settings-return", app))
        try uiSelectPDFWindow(app); try uiClick(ui("selection-ai-menu", app)); try uiClick(ui("selection-ai-translate", app))
        let answers = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'ai-conversation-answer-'"))
        try uiWait("One offline answer for the explicit selected task") { answers.count == 1 && !self.ui("ai-conversation-stop", app).exists }
        let answer = answers.firstMatch; XCTAssertTrue(uiText(answer).contains("离线"))
        XCTAssertFalse(ui("ai-conversation-source-toggle", app).exists)
        try uiClick(ui("ai-conversation-return", app)); try uiContains(ui("page-position", app), "1 / 2")
        // The applied receiver is verified in the saved typed result below.
        XCTAssertEqual(try uiAnnotations(app).count, 0, "An applied connection and generated answer do not save notes")
        let save = ui(answer.identifier.replacingOccurrences(of: "ai-conversation-answer-", with: "ai-conversation-save-"), app)
        try uiClick(save); try uiWait("Explicit answer save") { save.label == "已加入笔记" }
        try uiClick(ui("ai-close", app)); try uiPanel("reader-notes", open: true, app); try uiEditNote(app)
        try uiPaste("Original saved configured API body", ui("annotation-comment-input", app)); try uiSaveNote(app)
        let saved = try uiOnlyAnnotation(app), result = try XCTUnwrap(saved["aiResult"] as? [String: Any])
        XCTAssertEqual((result["provider"] as? [String: Any])?["endpoint"] as? String, "https://joint-ui.example/v1")
        XCTAssertEqual(saved["userText"] as? String, "Original saved configured API body"); XCTAssertEqual(try uiAnchorPayload(saved)["quote"] as? String, "window")
        let store = try uiStore(app).appendingPathComponent("annotations-v1.json")
        XCTAssertFalse(String(decoding: try Data(contentsOf: store), as: UTF8.self).contains("synthetic-reading-ui-credential"))
        try uiSettings(app); try uiPaste("https://different-ui.example/v1", ui("ai-endpoint", app))
        XCTAssertEqual(ui("ai-session-key", app).value as? String, "")
        try uiClick(ui("ai-settings-save", app)); try uiContains(ui("ai-credential-status", app), "填写后点击应用连接")
        XCTAssertEqual(try uiOnlyAnnotation(app)["aiResult"] as? NSDictionary, result as NSDictionary)
        try uiClick(ui("settings-return", app)); openCurrentFileAction("document-page-translation", app: app)
        XCTAssertFalse(ui("page-session-key", app).exists, "Page translation uses the shared connection without another credential field")
        XCTAssertFalse(ui("page-start", app).isEnabled, "Revoking the shared credential blocks page translation; separate scope consent is still required")
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
        XCTAssertTrue(try filePanelButton(app, titles: ["Save", "保存"]).waitForExistence(timeout: 5))
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
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app); try uiSelectPDFWindow(app); try uiBeginNote(app)
        let draft = "Original shell draft 日本語 cafe\u{301} 👩🏽‍🚀"
        try uiPaste(draft, ui("annotation-comment-input", app)); XCTAssertEqual(try uiAnnotations(app).count, 0)
        app.terminate(); app.launch(); app.activate(); try uiExample("open-sample", app)
        try uiPanel("reader-notes", open: true, app); try uiResumeDraft(app)
        XCTAssertEqual(uiText(ui("annotation-comment-input", app)), draft)
        try uiClick(ui("annotation-editor-cancel", app))
        try uiPanel("reader-navigation", open: true, app)
        try uiPaste("window", ui("search-input", app)); try uiClick(ui("search-submit", app)); try uiClick(ui("search-result", app))
        try uiPanel("reader-notes", open: true, app); try uiResumeDraft(app)
        XCTAssertEqual(uiText(ui("annotation-comment-input", app)), draft); try uiSaveNote(app)
        let saved = try uiOnlyAnnotation(app)
        XCTAssertEqual(saved["userText"] as? String, draft); XCTAssertEqual(try uiAnchorPayload(saved)["quote"] as? String, "window")
        try uiReturnNote(app); waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
    }
    // Japanese flows extend the original 30 tests without modifying them. Compile locally;
    // execute only on the authorized isolated CI host, using UUID stores and an intercepted
    // transport. Confirm the visible offline marker BEFORE entering a synthetic credential.
    @MainActor private func japaneseElement(_ id: String, in app: XCUIApplication) -> XCUIElement {
        // Use the same exact native identifier matching as the ebook format flows.
        if id == "open-ebook-sample" {
            return app.descendants(matching: .any).matching(identifier: id).firstMatch
        }
        if id == "import-pdf" { return nativeImportEntry(app) }
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
    @MainActor private func pressJapaneseEntry(_ entry: XCUIElement, in app: XCUIApplication) throws {
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
        try chooseCurrentLanguage("document-japanese-learning", app: app)
    }
    @MainActor private func prepareJapaneseOfflinePDF(_ app: XCUIApplication) throws {
        try uiEnableLanguage("japanese", app)
        try prepareOriginalPDFNoteEditing(app)
        try pressJapaneseEntry(currentLanguageLauncher(app, formerID: "reader-japanese-learning"), in: app)
        guard japaneseElement("japanese-offline-fixture", in: app).waitForExistence(timeout: 5) else {
            throw NSError(domain: "PDFno-Offline-UI", code: 1, userInfo: [NSLocalizedDescriptionKey: "Fully intercepted Japanese transport required before synthetic key entry"])
        }
        XCTAssertFalse(app.buttons["japanese-learning-start"].firstMatch.isEnabled)
        press(app.buttons["japanese-learning-close"].firstMatch); try uiCloseLanguageReview(app)
        navigateWorkspace("ai-settings", in: app)
        press(app.buttons["ai-settings"].firstMatch)
        XCTAssertTrue(ui("ai-provider-mode", app).waitForExistence(timeout: 5))
        try uiClick(ui("ai-provider-mode", app)); try uiClick(app.menuItems["DeepSeek"].firstMatch)
        let key = japaneseElement("ai-session-key", in: app)
        XCTAssertTrue(key.waitForExistence(timeout: 5)); enterSearch("synthetic-reading-ui-credential", into: key, replacing: true)
        press(app.buttons["ai-settings-save"].firstMatch); try uiContains(ui("ai-connection-status", app), "已应用"); try uiClick(ui("settings-return", app))
        try pressJapaneseEntry(currentLanguageLauncher(app, formerID: "reader-japanese-learning"), in: app)
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
        XCTAssertNoThrow(try uiCaptureOwnWindow("LANG-public-Japanese-" + (appearance == "深色" ? "dark" : "light"), app))
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
        press(app.buttons["japanese-learning-close"].firstMatch); try uiCloseLanguageReview(app)
        app.terminate(); app.launch(); app.activate()
        navigateWorkspace("library-book", in: app)
        let book = japaneseElement("library-book", in: app)
        navigateWorkspace("library-book", in: app)
        XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        try uiLegacySavedNotes("reader", app)
        XCTAssertTrue(japaneseElement("japanese-saved-source", in: app).waitForExistence(timeout: 8))
        XCTAssertEqual(textValue(japaneseElement("japanese-saved-source", in: app)), "window")
        let returned = app.buttons["japanese-saved-return"].firstMatch
        scrollEditingElement(returned, app: app); press(returned)
        if ui("legacy-notes-close", app).exists { try uiClick(ui("legacy-notes-close", app)) }
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
        try pressJapaneseEntry(currentLanguageLauncher(app, formerID: "reader-japanese-learning"), in: app)
        XCTAssertFalse(app.buttons["japanese-learning-start"].firstMatch.isEnabled, "Session key must not survive restart")
    }
    @MainActor func testMacJapaneseNativeEPUBSelectionManualSaveAndSourceReturnPreservesRuby() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchEnvironment["PDFNO_UI_TEST_JAPANESE_APPEARANCE"] = "dark"
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareJapaneseOfflinePDF(app); press(app.buttons["japanese-learning-close"].firstMatch); try uiCloseLanguageReview(app)
        navigateWorkspace("open-epub-sample", in: app)
        press(app.buttons["open-epub-sample"].firstMatch)
        waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        press(app.buttons["epub-contents"].firstMatch); press(app.buttons["epub-chapter-1"].firstMatch)
        waitForText(["第 2 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 15)
        // A new chapter's position event can precede the command reply and sheet dismissal.
        // Wait for the real native controls to settle before selecting body text.
        let tocClosed = expectation(for: NSPredicate { _, _ in !app.buttons["epub-chapter-1"].firstMatch.exists }, evaluatedWith: app)
        wait(for: [tocClosed], timeout: 10)
        let original = try webText(in: app, matching: "日本語", prefix: true, timeout: 10)
        original.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5)).doubleClick()
        let japaneseEntry = try currentLanguageLauncher(app, formerID: "epub-japanese-learning")
        let entryReady = expectation(for: NSPredicate { _, _ in
            japaneseEntry.exists && japaneseEntry.isEnabled && japaneseEntry.isHittable
        }, evaluatedWith: japaneseEntry)
        wait(for: [entryReady], timeout: 10)
        XCTAssertTrue(japaneseEntry.isEnabled && japaneseEntry.isHittable)
        let selectionReady = expectation(for: NSPredicate { _, _ in
            japaneseEntry.exists && japaneseEntry.isEnabled && japaneseEntry.isHittable
        }, evaluatedWith: japaneseEntry)
        wait(for: [selectionReady], timeout: 10)
        XCTAssertTrue(japaneseEntry.isEnabled && japaneseEntry.isHittable)
        try pressJapaneseEntry(japaneseEntry, in: app)
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
        scrollJapaneseElement(returned, in: app); press(returned); try uiCloseLanguageReview(app)
        waitForText(["第 2 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 10)
        XCTAssertTrue(try webText(in: app, matching: "にほんご", prefix: false, timeout: 10).exists)
        try uiLegacySavedNotes("epub", app)
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
                press(app.buttons["japanese-learning-close"].firstMatch); try uiCloseLanguageReview(app)
                try pressJapaneseEntry(currentLanguageLauncher(app, formerID: "reader-japanese-learning"), in: app)
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
        board.clearContents(); board.setString(text, forType: .string)
        input.typeKey("v", modifierFlags: .command)
        // Verify both the actual control and its model before dismiss/save;
        // a missed keyboard event must fail here, not masquerade as data loss.
        waitForEditingValue(text, in: input)
        waitForText(["正文未保存"], in: app.staticTexts[prefix + "-edit-status"].firstMatch, timeout: 5)
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
        try uiSelectPDFWindow(app); try uiBeginNote(app)
        try uiPaste("Original saved Bookno body", ui("annotation-comment-input", app)); try uiSaveNote(app)
        try uiPanel("reader-notes", open: true, app); let saved = try uiOnlyAnnotation(app)
        try uiEditNote(app); try uiPaste("Original private unsaved Bookno draft", ui("annotation-comment-input", app))
        app.terminate(); app.launch(); app.activate(); try uiExample("open-sample", app)
        XCTAssertEqual(try uiOnlyAnnotation(app)["userText"] as? String, "Original saved Bookno body")
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
        XCTAssertEqual(NSDictionary(dictionary: try uiOnlyAnnotation(app)), NSDictionary(dictionary: saved))
        // Finish the current preview before navigating to its new tools entry.
        // Escape inside navigateWorkspace would otherwise dismiss this sheet.
        press(currentToolReturn(app, formerID: "bookno-preview-close"))
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
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app); try uiSelectPDFWindow(app); try uiBeginNote(app)
        try uiPaste("Original saved body", ui("annotation-comment-input", app)); try uiSaveNote(app)
        try uiPanel("reader-notes", open: true, app); let before = try uiOnlyAnnotation(app)
        try uiEditNote(app); try uiPaste("Original cancelled edit", ui("annotation-comment-input", app)); try uiClick(ui("annotation-editor-cancel", app))
        XCTAssertEqual(try uiOnlyAnnotation(app)["userText"] as? String, "Original saved body")
        try uiEditNote(app); try uiPaste("Original recovered 日本語🌸 café", ui("annotation-comment-input", app))
        XCTAssertEqual(try uiOnlyAnnotation(app)["userText"] as? String, "Original saved body")
        app.terminate(); app.launch(); app.activate(); try uiExample("open-sample", app)
        try uiPanel("reader-notes", open: true, app); try uiResumeDraft(app)
        XCTAssertEqual(uiText(ui("annotation-comment-input", app)), "Original recovered 日本語🌸 café")
        try uiClick(ui("annotation-editor-cancel", app)); try uiPanel("reader-notes", open: false, app); try uiPanel("reader-notes", open: true, app)
        try uiResumeDraft(app); XCTAssertEqual(uiText(ui("annotation-comment-input", app)), "Original recovered 日本語🌸 café")
        try uiSaveNote(app); let after = try uiOnlyAnnotation(app)
        XCTAssertEqual(after["userText"] as? String, "Original recovered 日本語🌸 café")
        XCTAssertEqual(before["anchor"] as? NSDictionary, after["anchor"] as? NSDictionary); XCTAssertEqual(after["id"] as? String, before["id"] as? String)
        try uiEditNote(app); try uiPaste("", ui("annotation-comment-input", app))
        XCTAssertEqual(ui("annotation-comment-input", app).value as? String, ""); try uiSaveNote(app)
        XCTAssertEqual(try uiOnlyAnnotation(app)["userText"] as? String, "")
        XCTAssertEqual(uiText(ui("annotation-excerpt", app)), "window")
        try uiReturnNote(app); waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
    }
    @MainActor func testMacPDFBodyEditingDiskFailureKeepsDraftAndExplicitRetry() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_NOTE_FAILURE"] = "backup-directory"
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app); try uiSelectPDFWindow(app); try uiBeginNote(app); try uiSaveNote(app)
        try uiPanel("reader-notes", open: true, app); try uiEditNote(app)
        try uiPaste("Original failure recovery body", ui("annotation-comment-input", app))
        let manifest = try uiStore(app).appendingPathComponent("annotations-v1.json"), before = try Data(contentsOf: manifest)
        // The same app-owned real filesystem failure now targets the active annotation sidecar.
        try uiClick(ui("annotation-editor-save", app)); try uiContains(ui("annotation-editor-status", app), "保存失败")
        try uiContains(ui("annotation-editor-status", app), "草稿保留")
        XCTAssertEqual(try Data(contentsOf: manifest), before)
        XCTAssertEqual(uiText(ui("annotation-comment-input", app)), "Original failure recovery body")
        try uiSaveNote(app)
        XCTAssertEqual(try uiOnlyAnnotation(app)["userText"] as? String, "Original failure recovery body")
        XCTAssertEqual(uiText(ui("annotation-excerpt", app)), "window")
    }
    @MainActor func testMacEPUBBodyEditingBookSwitchRestartAndSource() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        try uiExample("open-epub-sample", app); try uiSelectWeb("window", app); try uiBeginNote(app); try uiSaveNote(app)
        try uiPanel("epub-notes", open: true, app); let before = try uiOnlyAnnotation(app)
        try uiEditNote(app); try uiPaste("Original EPUB edited body 日本語🌸", ui("annotation-comment-input", app))
        app.terminate(); app.launch(); app.activate(); try uiExample("open-sample", app)
        try uiPanel("reader-notes", open: true, app); XCTAssertEqual(uiAnnotationRows(app).count, 0); XCTAssertFalse(ui("annotation-resume-draft", app).exists)
        try uiExample("open-epub-sample", app); try uiPanel("epub-notes", open: true, app); try uiResumeDraft(app)
        XCTAssertEqual(uiText(ui("annotation-comment-input", app)), "Original EPUB edited body 日本語🌸"); try uiSaveNote(app)
        let after = try uiOnlyAnnotation(app)
        XCTAssertEqual(Set(before.keys), Set(after.keys)); XCTAssertEqual(before["anchor"] as? NSDictionary, after["anchor"] as? NSDictionary)
        app.terminate(); app.launch(); app.activate(); try uiExample("open-epub-sample", app); try uiPanel("epub-notes", open: true, app)
        try uiContains(ui("annotation-comment", app), "Original EPUB edited body 日本語🌸")
        XCTAssertEqual(uiText(ui("annotation-comment", app)), "Original EPUB edited body 日本語🌸")
        try uiReturnNote(app); waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 10)
    }
    @MainActor func testMacLearningBodyEditingPreservesResultRestartAndSource() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app); try uiConfigureMock(app); try uiLegacyAI(app); try uiStartLegacyAI(app)
        XCTAssertTrue(ui("ai-result", app).waitForExistence(timeout: 15)); XCTAssertEqual(try uiAnnotations(app).count, 0)
        try uiReveal(ui("ai-save-note", app), scroll: "ai-notes-list", app); try uiClick(ui("ai-save-note", app))
        try uiContains(ui("ai-result-save-state", app), "已添加到当前文档笔记"); let before = try uiOnlyAnnotation(app)
        try uiCloseLegacyAI(app); try uiPanel("reader-notes", open: true, app)
        try uiEditNote(app); try uiPaste("Original independent edited AI body", ui("annotation-comment-input", app)); try uiSaveNote(app)
        let after = try uiOnlyAnnotation(app)
        XCTAssertEqual(Set(before.keys), Set(after.keys)); XCTAssertEqual(before["aiResult"] as? NSDictionary, after["aiResult"] as? NSDictionary)
        XCTAssertNotNil(after["aiResult"]); XCTAssertEqual(before["anchor"] as? NSDictionary, after["anchor"] as? NSDictionary)
        XCTAssertEqual(after["userText"] as? String, "Original independent edited AI body")
        app.terminate(); app.launch(); app.activate(); try uiExample("open-sample", app); try uiPanel("reader-notes", open: true, app)
        XCTAssertTrue(ui("annotation-comment", app).waitForExistence(timeout: 8)); XCTAssertEqual(uiText(ui("annotation-comment", app)), "Original independent edited AI body")
        XCTAssertEqual(uiText(ui("annotation-excerpt", app)), "window"); XCTAssertTrue(ui("annotation-ai-result", app).exists)
        XCTAssertEqual(try uiOnlyAnnotation(app)["aiResult"] as? NSDictionary, before["aiResult"] as? NSDictionary)
        try uiReturnNote(app); waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
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
        resumeCurrentDocument(app)
        openCurrentFileAction("document-file-settings", app: app)
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
        resumeCurrentDocument(app)
        openCurrentFileAction("document-file-settings", app: app)
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
        press(currentToolReturn(app, formerID: "library-search-close"))
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
        try uiSelectPDFWindow(app); try uiBeginNote(app)
        try uiPaste("Original 日記 cafe\u{301}🌸", ui("annotation-comment-input", app)); try uiSaveNote(app)
        try uiPanel("reader-notes", open: true, app); XCTAssertTrue(ui("annotation-excerpt", app).waitForExistence(timeout: 8))
        try uiPanel("reader-notes", open: false, app); try uiPDFShortcut(.rightArrow, app)
        waitForText(["2 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 5)
        press(app.buttons["library-search"].firstMatch)
        let input = app.textFields["library-search-input"].firstMatch
        XCTAssertTrue(input.waitForExistence(timeout: 8)); enterSearch("日記", into: input)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        press(app.buttons["record-search-source"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
        try uiConfigureMock(app); try uiLegacyAI(app)
        XCTAssertTrue(ui("ai-source-quote", app).waitForExistence(timeout: 5)); XCTAssertEqual(uiText(ui("ai-source-quote", app)), "window")
        waitForText(["本地 mock"], in: ui("ai-provider-status", app), timeout: 5); try uiStartLegacyAI(app)
        XCTAssertTrue(ui("ai-result", app).waitForExistence(timeout: 8)); XCTAssertEqual(try uiAnnotations(app).count, 1)
        try uiSaveLegacyAI("Original saved AI memory 学習", app); XCTAssertEqual(try uiAnnotations(app).count, 2)
        try uiReturnLegacyAI(app); try uiPDFShortcut(.rightArrow, app)
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
        try uiSelectPDFWindow(app); try uiBeginNote(app)
        try uiPaste("integrationpreviousbody", ui("annotation-comment-input", app)); try uiSaveNote(app)
        try uiPanel("reader-notes", open: true, app); let before = try uiOnlyAnnotation(app)
        let anchor = try uiAnchorPayload(before), hash = try XCTUnwrap(anchor["fileSHA256"] as? String)
        let original = store.appendingPathComponent("Originals/" + hash + ".pdf"), originalBytes = try Data(contentsOf: original)
        try uiEditNote(app); try uiPaste("integrationdraftbody", ui("annotation-comment-input", app))
        app.terminate(); app.launch(); app.activate(); try uiExample("open-sample", app)
        press(app.buttons["library-search"].firstMatch)
        let search = app.textFields["library-search-input"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 8)); enterSearch("integrationdraftbody", into: search)
        XCTAssertTrue(app.staticTexts["library-search-no-results"].firstMatch.waitForExistence(timeout: 8))
        press(currentToolReturn(app, formerID: "library-search-close")); try uiPanel("reader-notes", open: true, app); try uiResumeDraft(app)
        XCTAssertEqual(uiText(ui("annotation-comment-input", app)), "integrationdraftbody")
        try uiClick(ui("annotation-editor-cancel", app)); XCTAssertEqual(try uiOnlyAnnotation(app)["userText"] as? String, "integrationpreviousbody")
        try uiEditNote(app); try uiPaste("integrationsavedbody 日本語", ui("annotation-comment-input", app)); try uiSaveNote(app)
        try uiPanel("reader-notes", open: false, app)
        navigateWorkspace("library-grid-layout", in: app)
        navigateWorkspace("library-list-layout", in: app)
        press(app.buttons["library-grid-layout"].firstMatch); press(app.buttons["library-list-layout"].firstMatch)
        resumeCurrentDocument(app)
        openCurrentFileAction("document-file-settings", app: app)
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
        resumeCurrentDocument(app)
        try uiPDFShortcut(.rightArrow, app)
        waitForText(["2 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 5)
        press(app.buttons["library-search"].firstMatch)
        XCTAssertTrue(search.waitForExistence(timeout: 8)); enterSearch("integrationpreviousbody", into: search)
        XCTAssertTrue(app.staticTexts["library-search-no-results"].firstMatch.waitForExistence(timeout: 8))
        enterSearch("integrationsavedbody", into: search, replacing: true)
        waitForText(["找到 1 项"], in: app.staticTexts["library-search-status"].firstMatch, timeout: 8)
        press(app.buttons["record-search-source"].firstMatch)
        waitForText(["1 / 2"], in: app.staticTexts["page-position"].firstMatch, timeout: 8)
        let after = try uiOnlyAnnotation(app)
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
        XCTAssertTrue(nativeImportEntry(app).waitForExistence(timeout: 15))
        navigateWorkspace("import-pdf", in: app)
        try chooseInput(file, trigger: nativeImportEntry(app), app: app)
        let navigation = app.buttons["textformat-navigation"].firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        openCurrentFileMenu(app)
        XCTAssertFalse(app.menuItems["document-file-settings"].firstMatch.isEnabled)
        app.typeKey(.escape, modifierFlags: [])
        navigateWorkspace("library-grid-layout", in: app)
        press(app.buttons["library-grid-layout"].firstMatch)
        let textRow = app.descendants(matching: .any).matching(identifier: "library-textformat").firstMatch
        XCTAssertTrue(textRow.waitForExistence(timeout: 5)); XCTAssertTrue(textRow.isHittable)
        navigateWorkspace("library-list-layout", in: app)
        press(app.buttons["library-list-layout"].firstMatch)
        XCTAssertTrue(textRow.waitForExistence(timeout: 5)); XCTAssertTrue(textRow.isHittable)
        resumeCurrentDocument(app)
        XCTAssertFalse(app.buttons["reader-ai"].firstMatch.exists)
        XCTAssertFalse(app.buttons["epub-ai"].firstMatch.exists)
        XCTAssertFalse(app.buttons["reader-page-translation"].firstMatch.exists)
        let paragraph = try webText(in: app, matching: "window", prefix: true, timeout: 10)
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        try uiBeginNote(app)
        let draft = ui("annotation-comment-input", app)
        XCTAssertTrue(draft.waitForExistence(timeout: 5)); try uiPaste("Original text format observation", draft)
        XCTAssertEqual(try uiAnnotations(app).count, 0); try uiSaveNote(app); try uiPanel("textformat-notes", open: true, app)
        let saved = ui("annotation-excerpt", app), note = ui("annotation-comment", app)
        XCTAssertTrue(saved.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(saved), "window")
        XCTAssertTrue(note.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(note), "Original text format observation")
        let anchorBefore = try uiOnlyAnnotation(app)["anchor"] as? NSDictionary
        XCTAssertEqual(try uiAnchorPayload(uiOnlyAnnotation(app))["quote"] as? String, "window")
        try uiReturnNote(app); try uiPanel("textformat-notes", open: false, app)
        press(navigation)
        let second = app.buttons["textformat-chapter-2"].firstMatch
        XCTAssertTrue(second.waitForExistence(timeout: 5)); press(second)
        XCTAssertTrue(try webText(in: app, matching: "Chapter 2", prefix: false, timeout: 10).isHittable)
        let store = URL(fileURLWithPath: "/tmp", isDirectory: true).appendingPathComponent("PDFno-UITests-" + token).appendingPathComponent("text-formats-v1.json")
        let persisted = expectation(for: NSPredicate { _, _ in
            guard let data = try? Data(contentsOf: store), let state = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let books = state["books"] as? [[String: Any]], let progress = books.first?["progress"] as? [String: Any], let notes = try? self.uiAnnotations(app) else { return false }
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
        try uiReturnNote(app); try uiPanel("textformat-notes", open: false, app)
        XCTAssertEqual(try uiOnlyAnnotation(app)["anchor"] as? NSDictionary, anchorBefore)
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
        XCTAssertTrue(nativeImportEntry(app).waitForExistence(timeout: 15))
        navigateWorkspace("import-pdf", in: app)
        try chooseInput(source, trigger: nativeImportEntry(app), app: app)
        let navigation = app.buttons["docx-navigation"].firstMatch
        XCTAssertTrue(navigation.waitForExistence(timeout: 25)); waitUntilEnabled(navigation)
        XCTAssertFalse(app.buttons["reader-ai"].firstMatch.exists)
        XCTAssertFalse(app.buttons["reader-page-translation"].firstMatch.exists)
        XCTAssertTrue(try webText(in: app, matching: "Cell one", prefix: false, timeout: 10).exists)
        let paragraph = try webText(in: app, matching: "window", prefix: true, timeout: 10)
        waitUntilEnabled(paragraph)
        paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)).doubleClick()
        try uiBeginNote(app)
        let draft = ui("annotation-comment-input", app)
        XCTAssertTrue(draft.waitForExistence(timeout: 5)); try uiPaste("Original independent Word note", draft)
        XCTAssertEqual(try uiAnnotations(app).count, 0); try uiSaveNote(app); try uiPanel("docx-notes", open: true, app)
        let saved = ui("annotation-excerpt", app), userNote = ui("annotation-comment", app)
        XCTAssertTrue(saved.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(saved), "window")
        XCTAssertTrue(userNote.waitForExistence(timeout: 8)); XCTAssertEqual(textValue(userNote), "Original independent Word note")
        let anchorBefore = try uiOnlyAnnotation(app)["anchor"] as? NSDictionary
        try uiReturnNote(app); try uiPanel("docx-notes", open: false, app)
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
        try uiReturnNote(app); try uiPanel("docx-notes", open: false, app)
        XCTAssertEqual(try uiOnlyAnnotation(app)["anchor"] as? NSDictionary, anchorBefore)
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
        XCTAssertTrue(nativeImportEntry(app).waitForExistence(timeout: 15))
        navigateWorkspace("import-pdf", in: app)
        try chooseInput(broken, trigger: nativeImportEntry(app), app: app)
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
        try chooseInput(comic, trigger: nativeImportEntry(app), app: app)
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
        XCTAssertTrue(try filePanelButton(app, titles: ["Save", "保存"]).waitForExistence(timeout: 5))
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
        let save = try filePanelButton(app, titles: ["Save", "保存"])
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
        try chooseInput(archive, trigger: nativeImportEntry(app), app: app)
        let position = app.staticTexts["comic-position"].firstMatch
        waitForText(["1 / 7"], in: position, timeout: 25)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "comic-content").firstMatch.exists)
        let layout = ui("comic-settings", app)
        XCTAssertTrue(layout.waitForExistence(timeout: 5)); try uiComicOption("双页", picker: "页面布局", app)
        waitForText(["双页"], in: layout, timeout: 10)
        waitUntilEnabled(app.buttons["reading-bottom-next"].firstMatch)
        press(app.buttons["reading-bottom-next"].firstMatch)
        waitForText(["2–3 / 7"], in: position, timeout: 15)
        let direction = ui("comic-settings", app)
        try uiComicOption("从右到左", picker: "阅读方向", app)
        waitForText(["从右到左"], in: direction, timeout: 10)
        waitForText(["2–3 / 7"], in: position, timeout: 15)
        waitUntilEnabled(app.buttons["reading-bottom-next"].firstMatch)
        press(app.buttons["reading-bottom-next"].firstMatch)
        waitForText(["4 / 7"], in: position, timeout: 15)
        waitUntilEnabled(app.buttons["reading-bottom-next"].firstMatch)
        press(app.buttons["reading-bottom-next"].firstMatch)
        waitForText(["5–6 / 7"], in: position, timeout: 15)
        waitUntilEnabled(app.buttons["reading-bottom-next"].firstMatch)
        press(app.buttons["reading-bottom-next"].firstMatch)
        waitForText(["7 / 7"], in: position, timeout: 15)
        XCTAssertFalse(app.buttons["reading-bottom-next"].firstMatch.isEnabled)
        press(app.buttons["comic-pages"].firstMatch)
        let page = app.buttons["comic-page-4"].firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 5)); press(page)
        waitForText(["5–6 / 7"], in: position, timeout: 15)
        try uiComicOption("单页", picker: "页面布局", app)
        waitForText(["单页"], in: layout, timeout: 10)
        waitForText(["5 / 7"], in: position, timeout: 15)
        try uiClick(ui("comic-settings", app)); try uiClick(app.menuItems.matching(identifier: "comic-close").firstMatch)
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
        try chooseInput(broken, trigger: nativeImportEntry(app), app: app)
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
        try chooseInput(archive, trigger: nativeImportEntry(app), app: app)
        let position = app.staticTexts["comic-position"].firstMatch
        waitForText(["1 / 7"], in: position, timeout: 25)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "comic-content").firstMatch.exists)
        let layout = ui("comic-settings", app)
        XCTAssertTrue(layout.waitForExistence(timeout: 5)); try uiComicOption("双页", picker: "页面布局", app)
        waitForText(["双页"], in: layout, timeout: 10)
        waitUntilEnabled(app.buttons["reading-bottom-next"].firstMatch)
        press(app.buttons["reading-bottom-next"].firstMatch)
        waitForText(["2–3 / 7"], in: position, timeout: 15)
        let direction = ui("comic-settings", app)
        try uiComicOption("从右到左", picker: "阅读方向", app)
        waitForText(["从右到左"], in: direction, timeout: 10)
        waitForText(["2–3 / 7"], in: position, timeout: 15)
        waitUntilEnabled(app.buttons["reading-bottom-next"].firstMatch)
        press(app.buttons["reading-bottom-next"].firstMatch)
        waitForText(["4 / 7"], in: position, timeout: 15)
        waitUntilEnabled(app.buttons["reading-bottom-next"].firstMatch)
        press(app.buttons["reading-bottom-next"].firstMatch)
        waitForText(["5–6 / 7"], in: position, timeout: 15)
        waitUntilEnabled(app.buttons["reading-bottom-next"].firstMatch)
        press(app.buttons["reading-bottom-next"].firstMatch)
        waitForText(["7 / 7"], in: position, timeout: 15)
        XCTAssertFalse(app.buttons["reading-bottom-next"].firstMatch.isEnabled)
        press(app.buttons["comic-pages"].firstMatch)
        let page = app.buttons["comic-page-4"].firstMatch
        XCTAssertTrue(page.waitForExistence(timeout: 5)); press(page)
        waitForText(["5–6 / 7"], in: position, timeout: 15)
        try uiComicOption("单页", picker: "页面布局", app)
        waitForText(["单页"], in: layout, timeout: 10)
        waitForText(["5 / 7"], in: position, timeout: 15)
        try uiClick(ui("comic-settings", app)); try uiClick(app.menuItems.matching(identifier: "comic-close").firstMatch)
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
        try chooseInput(broken, trigger: nativeImportEntry(app), app: app)
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
        if element.exists && element.isEnabled && element.isHittable { return }
        let ready = expectation(for: NSPredicate(format: "enabled == true AND hittable == true"), evaluatedWith: element)
        wait(for: [ready], timeout: 10)
    }
    @MainActor private func chooseInput(_ url: URL, trigger: XCUIElement, app: XCUIApplication) throws {
        press(trigger)
        let open = try filePanelButton(app, titles: ["Open", "打开"])
        XCTAssertTrue(open.waitForExistence(timeout: 5))
        try goToFixtureLocation(url, app: app)
        // Choosing a file completion can also accept the selected file. Require actual import/output state below.
        if open.exists { waitUntilEnabled(open); press(open) }
    }
    @MainActor private func filePanelButton(_ app: XCUIApplication, titles: [String]) throws -> XCUIElement {
        // The actual macOS panel action reports OKButton; a name-only query can select the Touch Bar.
        if titles.contains("Open") || titles.contains("Save") {
            // Open may be disabled until the exact fixture is selected; chooseInput still waits for enabled/hittable before clicking.
            return try uiFileControl(app, type: .button, identifier: "OKButton", requireEnabled: false)
        }
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
        let diagnosticStarted = ProcessInfo.processInfo.systemUptime
        // Resolve the real file panel once; its AX queries should not repeatedly
        // traverse the reader WebView behind it. Retain the application scope
        // for platforms where the panel has no exposed dialog/sheet/window root.
        let panel = [app.sheets, app.dialogs, app.windows].lazy.map {
            $0.containing(.button, identifier: "OKButton").firstMatch
        }.first { $0.exists } ?? app
        traceFixturePanel("panel-resolved", url: url, started: diagnosticStarted)
        app.typeKey("g", modifierFlags: [.command, .shift])
        let location = try uiFileControl(app, type: .textField, identifier: "PathTextField")
        XCTAssertTrue(location.waitForExistence(timeout: 5))
        // The modal field owns keyboard focus after its physical click. Send
        // the two native shortcuts to that app, avoiding a full reader/WebKit
        // AX traversal for each key. The exact path and completion stay checked.
        press(location)
        app.typeKey("a", modifierFlags: .command)
        NSPasteboard.general.clearContents()
        XCTAssertTrue(NSPasteboard.general.setString(url.path, forType: .string))
        app.typeKey("v", modifierFlags: .command)
        XCTAssertEqual(location.value as? String, url.path)
        traceFixturePanel("literal-path-confirmed", url: url, started: diagnosticStarted)
        // The completion label is not hittable on macOS; select its actual row/cell by mouse.
        // A keyboard Return here can crash the system panel's input-context service.
        let goTo = app.sheets.matching(identifier: "GoToWindow").firstMatch
        let fullPath = NSPredicate(format: "identifier == %@", url.path)
        let fixture = NSPredicate(format: "label == %@ OR value == %@", url.lastPathComponent, url.lastPathComponent)
        var completion: XCUIElement?
        try uiWait("One physical completion for the exact entered fixture path", timeout: 12) {
            let fullRows = goTo.exists ? goTo.tables.tableRows.containing(fullPath).allElementsBoundByIndex : []
            let observedRows = fullRows.isEmpty ? [XCUIElement.ElementType.cell, .tableRow, .outlineRow].flatMap {
                panel.descendants(matching: $0).containing(fixture).allElementsBoundByIndex
            } : fullRows
            completion = observedRows.first { row in
                let frame = row.frame
                return row.exists && row.isHittable && !frame.isEmpty && !frame.isInfinite && frame.minX.isFinite && frame.minY.isFinite
            }
            return completion != nil
        }
        let selectedCompletion = try XCTUnwrap(completion)
        traceFixturePanel("qualified-completion", url: url, started: diagnosticStarted)
        selectedCompletion.doubleClick()
        traceFixturePanel("real-cell-double-clicked", url: url, started: diagnosticStarted)
        let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            !location.exists || !location.isHittable
        }, object: app)
        if XCTWaiter.wait(for: [dismissed], timeout: 5) == .completed { return }
        if !location.exists || !location.isHittable { return }
        XCTFail("The original fixture Go-to overlay must close before using the file-panel action")
        throw NSError(domain: "PDFnoOriginalFixturePanel", code: 1)
    }
    @MainActor private func traceFixturePanel(_ stage: String, url: URL, started: TimeInterval) {
        // Enabled only in the explicit focused CI xctestrun. It never opens a
        // different app, reads production data, changes input, or fakes a result.
        guard ProcessInfo.processInfo.environment["PDFNO_UI_TEST_PANEL_DIAGNOSTICS"] == "1" else { return }
        let elapsed = ProcessInfo.processInfo.systemUptime - started
        // Successful diagnostics must not re-query AX. On a system file panel,
        // each extra property read can traverse the WebKit reader behind it.
        // The real path, frame, hittability and dismissal checks above remain.
        print("PDFno fixture-panel diagnostic stage=\(stage) file=\(url.lastPathComponent) seconds=\(elapsed)")
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
        openCurrentFileAction("document-page-translation", app: app)
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
        openCurrentFileAction("document-page-translation", app: app)
        XCTAssertFalse(app.buttons["page-start"].firstMatch.isEnabled)
        XCTAssertFalse(app.staticTexts["page-result-0"].firstMatch.exists)
        press(app.buttons["page-close"].firstMatch)
        try uiLegacyAI(app)
        let saved = app.staticTexts["ai-saved-user-note"].firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5)); XCTAssertEqual(textValue(saved), "Original synthetic whole page note")
        press(app.buttons["ai-saved-source"].firstMatch)
        try uiCloseToolDirectory(app)
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
        openCurrentFileAction("document-spine-translation", app: app)
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
        openCurrentFileAction("document-spine-translation", app: app)
        XCTAssertFalse(app.buttons["chapter-start"].firstMatch.isEnabled)
        XCTAssertFalse(app.staticTexts["chapter-result-0"].firstMatch.exists)
        let restartedKey = app.descendants(matching: .any).matching(identifier: "chapter-session-key").firstMatch
        XCTAssertTrue(restartedKey.exists); XCTAssertTrue((restartedKey.value as? String ?? "").isEmpty)
        press(app.buttons["chapter-close"].firstMatch)
        try uiLegacyAI(app)
        let savedText = app.descendants(matching: .any).matching(identifier: "ai-saved-user-note").firstMatch
        XCTAssertTrue(savedText.waitForExistence(timeout: 5)); XCTAssertEqual(textValue(savedText), "Original synthetic whole chapter note")
        press(app.buttons["ai-saved-source"].firstMatch)
        try uiCloseToolDirectory(app)
        waitForText(["第 2 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 10)
    }
    @MainActor func testMacEPUBChapterOversizeRefusesWholeDocumentWithoutKeyOrSend() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launch(); app.activate(); defer { app.terminate() }
        openChapterFixture(in: app, japanese: false)
        openCurrentFileAction("document-spine-translation", app: app)
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
        press(app.buttons["chapter-close"].firstMatch); openCurrentFileAction("document-spine-translation", app: app)
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
        openCurrentFileAction("document-spine-translation", app: app)
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
            openCurrentFileAction("document-page-translation", app: app)
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
        openCurrentFileAction("document-page-translation", app: app)
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
        press(app.buttons["page-close"].firstMatch); openCurrentFileAction("document-page-translation", app: app)
        XCTAssertFalse(app.buttons["page-start"].firstMatch.isEnabled)
        XCTAssertTrue(textValue(app.staticTexts["page-limits"].firstMatch).contains("1 / 6"))
        app.terminate()
    }
    @MainActor func testMacDeepSeekSelectionOfflineTransportPDFEPUBAndRestart() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app); try uiLegacyAI(app)
        guard ui("ai-offline-fixture", app).waitForExistence(timeout: 5) else { XCTFail("Offline transport required before synthetic credential entry"); return }
        try uiCloseLegacyAI(app); try uiSettings(app); try uiProvider("DeepSeek", app, key: "synthetic-reading-ui-credential"); try uiClick(ui("settings-return", app))
        try uiLegacyAI(app); let start = ui("ai-start", app), result = ui("ai-result", app)
        XCTAssertTrue(start.waitForExistence(timeout: 5)); XCTAssertFalse(start.isEnabled)
        XCTAssertEqual(uiText(ui("ai-source-quote", app)), "window"); try uiStartLegacyAI(app)
        XCTAssertTrue(result.waitForExistence(timeout: 8)); XCTAssertTrue(uiText(result).contains("离线 DeepSeek UI 替身")); XCTAssertTrue(uiText(result).contains("翻译"))
        XCTAssertEqual(try uiAnnotations(app).count, 0, "Generated output must never save automatically")
        try uiSaveLegacyAI("Original synthetic DeepSeek user note", app); XCTAssertEqual(try uiOnlyAnnotation(app)["userText"] as? String, "Original synthetic DeepSeek user note")
        try uiReturnLegacyAI(app); XCTAssertTrue(textValue(app.staticTexts["page-position"].firstMatch).contains("1 / 2"))
        try uiExample("open-epub-sample", app); waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        try uiPanel("epub-notes", open: true, app); XCTAssertEqual(uiAnnotationRows(app).count, 0); try uiPanel("epub-notes", open: false, app)
        try uiSelectWeb("window", app); try uiLegacyAI(app, task: "explain")
        XCTAssertTrue(ui("ai-source-quote", app).waitForExistence(timeout: 5)); try uiStartLegacyAI(app)
        XCTAssertTrue(result.waitForExistence(timeout: 8)); XCTAssertTrue(uiText(result).contains("解释"))
        try uiSaveLegacyAI("", app); XCTAssertEqual(try uiAnnotations(app).count, 2); try uiReturnLegacyAI(app)
        let before = try uiAnnotations(app)
        app.terminate(); app.launch(); app.activate(); try uiExample("open-epub-sample", app)
        try uiPanel("epub-notes", open: true, app); XCTAssertTrue(ui("annotation-ai-result", app).waitForExistence(timeout: 8)); XCTAssertTrue(uiText(ui("annotation-ai-result", app)).contains("解释"))
        XCTAssertEqual(try uiAnnotations(app) as NSArray, before as NSArray)
        try uiReturnNote(app); try uiPanel("epub-notes", open: false, app); try uiLegacyAI(app, task: "explain")
        XCTAssertTrue(uiText(ui("ai-reading-key-status", app)).contains("请先")); XCTAssertFalse(start.isEnabled, "No session key may persist across restart")
    }
    @MainActor func testMacAISelectionConsentMockNotesAndRestart() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        try prepareOriginalPDFNoteEditing(app); try uiLegacyAI(app)
        let start = ui("ai-start", app), source = ui("ai-source-quote", app)
        XCTAssertTrue(start.waitForExistence(timeout: 5)); XCTAssertFalse(start.isEnabled)
        XCTAssertEqual(uiText(source), "window"); try uiStartLegacyAI(app)
        let error = ui("ai-error", app)
        XCTAssertTrue(error.waitForExistence(timeout: 5)); XCTAssertTrue(uiText(error).contains("未配置")); XCTAssertFalse(ui("ai-result", app).exists)
        try uiCloseLegacyAI(app); try uiConfigureMock(app); try uiLegacyAI(app)
        XCTAssertTrue(start.waitForExistence(timeout: 5)); XCTAssertFalse(start.isEnabled); try uiStartLegacyAI(app)
        let result = ui("ai-result", app)
        XCTAssertTrue(result.waitForExistence(timeout: 8)); XCTAssertTrue(uiText(result).contains("本地 mock"))
        XCTAssertEqual(try uiAnnotations(app).count, 0)
        try uiSaveLegacyAI("Original synthetic AI user note", app)
        let saved = try uiOnlyAnnotation(app)
        XCTAssertEqual(saved["userText"] as? String, "Original synthetic AI user note")
        XCTAssertEqual(try uiAnchorPayload(saved)["quote"] as? String, "window")
        try uiReturnLegacyAI(app); XCTAssertTrue(textValue(app.staticTexts["page-position"].firstMatch).contains("1 / 2"))
        app.terminate(); app.launch(); app.activate(); try uiExample("open-sample", app); try uiPanel("reader-notes", open: true, app)
        XCTAssertTrue(ui("annotation-comment", app).waitForExistence(timeout: 8)); XCTAssertEqual(uiText(ui("annotation-comment", app)), "Original synthetic AI user note")
        XCTAssertEqual(uiText(ui("annotation-excerpt", app)), "window"); try uiReturnNote(app)
        XCTAssertEqual(try uiOnlyAnnotation(app)["aiResult"] as? NSDictionary, saved["aiResult"] as? NSDictionary)
        try uiExample("open-epub-sample", app); waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 25)
        try uiPanel("epub-notes", open: true, app); XCTAssertEqual(uiAnnotationRows(app).count, 0, "PDF notes must not appear in another EPUB")
        try uiPanel("epub-notes", open: false, app); try uiSelectWeb("window", app); try uiLegacyAI(app, task: "explain")
        XCTAssertTrue(source.waitForExistence(timeout: 8)); XCTAssertFalse(uiText(source).isEmpty); try uiStartLegacyAI(app)
        XCTAssertTrue(result.waitForExistence(timeout: 8)); XCTAssertTrue(uiText(result).contains("本地 mock")); XCTAssertTrue(uiText(result).contains("解释"))
        XCTAssertEqual(try uiAnnotations(app).count, 1); try uiSaveLegacyAI("", app); XCTAssertEqual(try uiAnnotations(app).count, 2)
        try uiReturnLegacyAI(app); waitForText(["第 1 章"], in: app.staticTexts["epub-position"].firstMatch, timeout: 10)
        try uiPanel("epub-notes", open: true, app); XCTAssertEqual(uiAnnotationRows(app).count, 1); XCTAssertEqual(uiText(ui("annotation-excerpt", app)), "window")
    }
    @MainActor func testMacEPUBSelectionRubyNotesAndRestart() throws {
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        // Whole-book language classification requires a Japanese-dominant book.
        // This registered original fixture keeps the same first English quote and author ruby.
        let fixture = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/ReadingModes/original-vertical-continuous.epub")
        try chooseInput(fixture, trigger: nativeImportEntry(app), app: app)
        let position = ui("epub-position", app); waitForText(["第 1 章"], in: position, timeout: 25)
        XCTAssertFalse(ui("epub-error", app).exists)
        // New books default to continuous scrolling. Establish the actual
        // paginated mode before asserting a physical first-to-second-page turn.
        try uiPanel("epub-aa", open: true, app); try uiClick(ui("reading-mode-single", app))
        try uiWait("Actual single-column pagination selected") { self.ui("reading-mode-single", app).value as? String == "已选中" }
        try uiPanel("epub-aa", open: false, app); waitForText(["第 1 页"], in: position, timeout: 10)
        try uiSelectWeb("window", app); try uiBeginNote(app); try uiSaveNote(app)
        try uiPanel("epub-notes", open: true, app); let quote = ui("annotation-excerpt", app)
        XCTAssertTrue(quote.waitForExistence(timeout: 8)); let selectedText = uiText(quote)
        XCTAssertEqual(selectedText, "window"); XCTAssertFalse(selectedText.isEmpty)
        let anchor = try uiOnlyAnnotation(app)["anchor"] as? NSDictionary
        try uiReturnNote(app); try uiPanel("epub-notes", open: false, app)
        let next = ui("reading-bottom-next", app)
        let pagerFailure = { () -> String in
            // Bounded diagnostics from this original-fixture window only,
            // evaluated after the unchanged readiness predicate times out.
            if app.windows.firstMatch.exists {
                do { try self.uiCaptureOwnWindow("EPUB-pagination-failed", app) }
                catch { print("EPUB pagination own-window capture failed: \(error.localizedDescription)") }
            }
            let exists = next.exists
            let enabled = exists ? String(next.isEnabled) : "unavailable"
            let hittable = exists ? String(next.isHittable) : "unavailable"
            let frame = exists ? NSStringFromRect(next.frame) : "unavailable"
            let modeControl = self.ui("epub-reading-mode-description", app)
            let mode = modeControl.exists ? self.uiText(modeControl) : "unavailable"
            let page = position.exists ? self.uiText(position) : "unavailable"
            let notesVisible = self.ui("annotation-list", app).exists
            let errorVisible = self.ui("epub-error", app).exists
            print("EPUB pagination after-source-return exists=\(exists) enabled=\(enabled) hittable=\(hittable) frame=\(frame) position=\(page) mode=\(mode) notes=\(notesVisible) error=\(errorVisible)")
            return "Source return and reader layout finish before next page"
        }
        try uiWait(pagerFailure()) { next.exists && next.isEnabled && next.isHittable && !self.ui("annotation-list", app).exists }
        try uiCaptureOwnWindow("EPUB-pagination-ready", app)
        try uiClick(next); waitForText(["第 2 页"], in: position, timeout: 10)
        try uiPanel("epub-contents", open: true, app); try uiClick(ui("epub-chapter-1", app)); waitForText(["第 2 章"], in: position, timeout: 10)
        try uiPanel("epub-aa", open: true, app); try uiClick(ui("reading-vertical", app))
        try uiWait("Actual vertical layout selected") { self.ui("reading-vertical", app).value as? String == "已选中" }
        try uiPanel("epub-aa", open: false, app)
        let ruby = try webText(in: app, matching: "にほんご", prefix: false, timeout: 15)
        XCTAssertTrue(ruby.exists, "Author ruby remains visible in vertical reading")
        app.terminate(); app.launch(); app.activate(); navigateWorkspace("library-epub", in: app)
        let book = ui("library-epub", app); XCTAssertTrue(book.waitForExistence(timeout: 10)); press(book)
        waitForText(["第 2 章"], in: position, timeout: 20); try uiPanel("epub-aa", open: true, app)
        XCTAssertEqual(ui("reading-vertical", app).value as? String, "已选中")
        try uiPanel("epub-notes", open: true, app); XCTAssertTrue(quote.waitForExistence(timeout: 8)); XCTAssertEqual(uiText(quote), selectedText)
        XCTAssertEqual(try uiOnlyAnnotation(app)["anchor"] as? NSDictionary, anchor)
        try uiReturnNote(app); waitForText(["第 1 章"], in: position, timeout: 10)
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
        let matches = {
            guard element.exists else { return false }
            let text = self.textValue(element)
            return parts.allSatisfy { text.contains($0) }
        }
        if matches() { return }
        let ready = expectation(for: NSPredicate { _, _ in matches() }, evaluatedWith: element)
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
    @MainActor private func revealCurrentSettingsElement(_ element: XCUIElement, app: XCUIApplication) {
        let outer = app.scrollViews["ai-settings-form"].firstMatch
        XCTAssertTrue(outer.waitForExistence(timeout: 5)); XCTAssertTrue(element.waitForExistence(timeout: 5))
        let returning = element.identifier == "settings-return"
        for _ in 0..<12 {
            let target = element.frame, viewport = outer.frame.insetBy(dx: 4, dy: 8)
            // The native header button may extend into the scroll content inset.
            // It must still be fully inside this App's window and actually hittable.
            if !target.isEmpty, (returning || viewport.contains(target)),
               app.windows.firstMatch.frame.contains(target), element.isHittable { return }
            let scroll = outer
            let bounds = scroll.frame.insetBy(dx: 4, dy: 8)
            scroll.scroll(byDeltaX: 0, deltaY: target.minY < bounds.minY ? 250 : -250)
        }
        if !returning { XCTAssertTrue(outer.frame.insetBy(dx: 4, dy: 8).contains(element.frame)) }
        XCTAssertTrue(app.windows.firstMatch.frame.contains(element.frame)); XCTAssertTrue(element.isHittable)
    }


    @MainActor private func currentSettingsReturn(_ app: XCUIApplication) -> XCUIElement {
        let back = app.buttons["settings-return"].firstMatch
        revealCurrentSettingsElement(back, app: app); return back
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
        let identifier = input.identifier
        let literalField = identifier == "library-search-input" || identifier.hasPrefix("chapter-user-note-")
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
    @MainActor func testLocalPDFReadingAndNoteFlow() throws {
        #if os(macOS)
        let app = XCUIApplication(); app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launch(); app.activate(); defer { app.terminate() }
        try uiExample("open-sample", app)
        let position = ui("page-position", app); XCTAssertTrue(position.waitForExistence(timeout: 15)); XCTAssertTrue(uiText(position).contains("1 / 2"))
        try uiPDFShortcut(.rightArrow, app); try uiContains(position, "2 / 2")
        try uiPDFShortcut(.leftArrow, app); try uiContains(position, "1 / 2")
        try uiPanel("reader-navigation", open: true, app); try uiPaste("window", ui("search-input", app))
        try uiClick(ui("search-submit", app)); try uiClick(ui("search-result", app)); try uiSelectPDFWindow(app)
        try uiBeginNote(app); XCTAssertTrue(ui("annotation-editor-save", app).exists, "Actual PDFKit selection reaches note composer")
        try uiSaveNote(app); try uiPanel("reader-notes", open: true, app)
        let quote = ui("annotation-excerpt", app); XCTAssertTrue(quote.waitForExistence(timeout: 5)); XCTAssertEqual(uiText(quote), "window")
        try uiReturnNote(app); try uiContains(position, "1 / 2")
        let image = XCTAttachment(screenshot: app.windows.firstMatch.screenshot()); image.name = "Original sample in native PDFKit reader"; image.lifetime = .keepAlways; add(image)
        try uiPanel("reader-notes", open: false, app); try uiPDFShortcut(.rightArrow, app); try uiContains(position, "2 / 2")
        app.terminate(); app.launch(); app.activate(); try uiExample("open-sample", app)
        XCTAssertTrue(position.waitForExistence(timeout: 10)); XCTAssertTrue(uiText(position).contains("2 / 2"), "Reading position persists after restart")
        try uiPanel("reader-notes", open: true, app); XCTAssertTrue(quote.waitForExistence(timeout: 5), "Note survives restart")
        try uiReturnNote(app); try uiContains(position, "1 / 2")
        #else

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
        #endif
    }
}

#if os(macOS)
final class MacPanelCardsUITests: XCTestCase {
    @MainActor private func originalPDFViewport(_ app: XCUIApplication) -> XCUIElement {
        // Recorded PDFKit AX hierarchy: the real viewport is a native scroll
        // view containing the document group; PDFView's identifier is omitted.
        app.scrollViews.containing(NSPredicate(format: "label == %@", "document")).firstMatch
    }
    @MainActor private func fixedConversationQuote(_ app: XCUIApplication) throws -> String {
        let viewport = ui("ai-conversation-source", app)
        XCTAssertTrue(viewport.waitForExistence(timeout: 6))
        // The identifier belongs to ScrollView. Read its selectable Text child,
        // never the empty scroll-container value or a hard-coded fixture value.
        var values: Set<String> = []
        try uiWait("Actual fixed source text inside the source viewport", timeout: 6) {
            values = Set(viewport.descendants(matching: .any).allElementsBoundByIndex
                .filter { [.staticText, .textView, .textField].contains($0.elementType) }
                .map { self.uiText($0) }.filter { !$0.isEmpty })
            return !values.isEmpty
        }
        XCTAssertEqual(values.count, 1, "Exactly one fixed source quote")
        return try XCTUnwrap(values.first)
    }

    @MainActor func testPrepareUncappedQAForUserCredentialEntry() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        guard environment["PDFNO_LIVE_QA_PREPARE"] == "1",
              let bundle = environment["PDFNO_PANEL_QA_BUNDLE"],
              bundle.hasPrefix("org.pdfno.integration.professionala20261007.qa"),
              let token = environment["PDFNO_PANEL_QA_SESSION"], UUID(uuidString: token) != nil else {
            throw XCTSkip("Prepare only the new isolated QA App without a request or credential read")
        }
        let app = XCUIApplication(bundleIdentifier: bundle)
        XCTAssertNotEqual(app.state, .notRunning)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token // storage checks only
        app.activate()
        func click(_ element: XCUIElement) throws {
            XCTAssertTrue(element.waitForExistence(timeout: 8))
            XCTAssertTrue(element.isEnabled && element.isHittable)
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle else {
                throw XCTSkip("EXPERIENCE_DESKTOP_CHANGED: stop QA preparation input")
            }
            element.click()
        }
        XCTAssertEqual(try uiAnnotations(app).count, 0, "New original-fixture Library only")
        if !originalPDFViewport(app).exists {
            try click(ui("workspace-help", app)); try click(ui("open-sample", app))
        }
        XCTAssertTrue(originalPDFViewport(app).waitForExistence(timeout: 12))
        let tabs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'document-tab-' AND NOT identifier BEGINSWITH 'document-tab-close-'")).allElementsBoundByIndex
        XCTAssertEqual(tabs.count, 1)
        print("PDFnoUncappedPrepare: original_document_tab=\(try XCTUnwrap(tabs.first).identifier)")
        try click(ui("ai-settings", app))
        try click(ui("ai-provider-mode", app))
        try click(app.menuItems["DeepSeek"].firstMatch)
        XCTAssertEqual(ui("ai-endpoint", app).value as? String, "https://api.deepseek.com")
        XCTAssertEqual(ui("ai-model", app).value as? String, "deepseek-flash")
        XCTAssertTrue(ui("ai-session-key", app).exists) // never read this secure field
        print("PDFnoUncappedPrepare: DeepSeek preset ready for user-entered Key; no connection probe or AI request")
    }

    @MainActor func testAuthorizedLiveResumeExplanationFollowupAndExplicitNote() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        guard environment["PDFNO_LIVE_QA_ENABLED"] == "explicit-user-authorized",
              let bundle = environment["PDFNO_PANEL_QA_BUNDLE"],
              bundle.hasPrefix("org.pdfno.integration.professionala20261007.qa"),
              let token = environment["PDFNO_PANEL_QA_SESSION"], let session = UUID(uuidString: token) else {
            throw XCTSkip("Requires explicit live-test authorization and the existing dedicated session")
        }
        let app = XCUIApplication(bundleIdentifier: bundle)
        XCTAssertNotEqual(app.state, .notRunning, "Never recreate the user-configured app session")
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = session.uuidString // storage checks only
        app.activate()
        func ownDesktop() throws {
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle else {
                throw XCTSkip("EXPERIENCE_DESKTOP_CHANGED: stop resumed live-test input")
            }
        }
        func click(_ element: XCUIElement) throws {
            XCTAssertTrue(element.waitForExistence(timeout: 8))
            XCTAssertTrue(element.isEnabled && element.isHittable)
            try ownDesktop(); element.click()
        }
        func answers() -> [XCUIElement] {
            app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'ai-conversation-answer-'" )).allElementsBoundByIndex
        }
        try ownDesktop()
        let recordsBefore = try uiAnnotations(app)
        let manualBefore = recordsBefore.filter { $0["aiResult"] == nil }
        let manualBytes = try JSONSerialization.data(withJSONObject: manualBefore, options: [.sortedKeys])
        if answers().isEmpty {
            // Restore the already-open document through its existing tab; do
            // not open a sample, create a tab or invoke an AI task to find data.
            let expectedTab = try XCTUnwrap(environment["PDFNO_LIVE_QA_EXPECTED_DOCUMENT_TAB"])
            let tab = ui(expectedTab, app)
            XCTAssertTrue(tab.exists, "The original document tab must still exist")
            try click(tab)
            XCTAssertEqual(tab.value as? String, "已选中")
            print("PDFnoLiveResume: original document tab restored without a request")
        }
        if answers().count == 0 {
            XCTAssertFalse(ui("annotation-comment-input", app).exists)
            guard environment["PDFNO_LIVE_QA_ALLOW_REPLAY_PATH"] == "explicit-user-authorized" else {
                print("PDFnoLiveResume: retained conversation exists but no presentation-only entry; replay path prohibited; no request sent")
                throw XCTSkip("Existing response retained; showing it requires the AI task entry, which may send if cached identity differs. Explicit replay authorization required.")
            }
            // Restore exactly the original PDF word in the unchanged document.
            // open(...fresh:false) displays its retained reply without sending.
            try ownDesktop(); try uiSelectPDFWindow(app)
            try click(ui("selection-ai-menu", app))
            try click(ui("selection-ai-explain", app))
            if ui("ai-conversation-stop", app).exists {
                print("PDFnoLiveResume: separately authorized explanation replay submitted")
                try uiWait("One explicitly authorized replacement explanation; never retry", timeout: 35) {
                    !answers().isEmpty && !self.ui("ai-conversation-stop", app).exists
                }
            }
            print("PDFnoLiveResume: same-source existing conversation reopened without a pending request")
        }
        try uiWait("Original explanation is available", timeout: 8) { !answers().isEmpty }
        let answerCountBefore = answers().count
        let answerIdentifiersBefore = Set(answers().map(\.identifier))
        XCTAssertFalse(ui("ai-conversation-stop", app).exists)
        if !ui("ai-conversation-source", app).exists { try click(ui("ai-conversation-source-toggle", app)) }
        XCTAssertEqual(try fixedConversationQuote(app), "window")
        print("PDFnoLiveResume: original source text verified; no new request")
        let first = try XCTUnwrap(answers().first), firstText = uiText(first)
        XCTAssertFalse(firstText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(firstText.contains("本地 mock")); XCTAssertFalse(firstText.contains("离线 DeepSeek UI 替身"))
        let beforeSave = try uiAnnotations(app)
        XCTAssertTrue(try JSONSerialization.data(withJSONObject: beforeSave, options: [.sortedKeys]) == JSONSerialization.data(withJSONObject: recordsBefore, options: [.sortedKeys]))
        let answerID = first.identifier.replacingOccurrences(of: "ai-conversation-answer-", with: "")
        let save = ui("ai-conversation-save-" + answerID, app)
        let messages = ui("ai-conversation-messages", app)
        XCTAssertTrue(messages.exists)
        for _ in 0..<8 {
            let viewport = messages.frame.insetBy(dx: 3, dy: 6)
            if viewport.contains(save.frame) && save.isHittable { break }
            try ownDesktop(); messages.scroll(byDeltaX: 0, deltaY: save.frame.minY < viewport.minY ? 220 : -220)
        }
        let previouslySaved = beforeSave.filter {
            (($0["aiResult"] as? [String: Any])?["requestID"] as? String)?.uppercased() == answerID.uppercased()
        }
        XCTAssertLessThanOrEqual(previouslySaved.count, 1)
        if previouslySaved.isEmpty { try click(save) }
        try uiWait("Explicitly commit the existing live result", timeout: 12) { save.label == "已加入笔记" }
        let savedRecords = try uiAnnotations(app)
        XCTAssertEqual(savedRecords.count, recordsBefore.count + (previouslySaved.isEmpty ? 1 : 0))
        let savedAI = savedRecords.filter {
            (($0["aiResult"] as? [String: Any])?["requestID"] as? String)?.uppercased() == answerID.uppercased()
        }
        XCTAssertEqual(savedAI.count, 1)
        let note = try XCTUnwrap(savedAI.first)
        XCTAssertTrue(try JSONSerialization.data(withJSONObject: savedRecords.filter { $0["aiResult"] == nil }, options: [.sortedKeys]) == manualBytes, "Keep existing manual notes unchanged")
        XCTAssertEqual(try uiAnchorPayload(note)["quote"] as? String, "window")
        XCTAssertEqual(note["userText"] as? String, "", "AI output remains separate from user-authored text")
        let result = try XCTUnwrap(note["aiResult"] as? [String: Any])
        XCTAssertEqual(result["text"] as? String, firstText)
        XCTAssertEqual(result["fromCache"] as? Bool, false)
        let provider = try XCTUnwrap(result["provider"] as? [String: Any])
        XCTAssertEqual(provider["mode"] as? String, "openAICompatible")
        XCTAssertEqual(provider["endpoint"] as? String, "https://api.deepseek.com")
        XCTAssertEqual(provider["model"] as? String, "deepseek-flash")
        print("PDFnoLiveResume: explicit note, exact original and separate remote result verified")
        let input = ui("ai-conversation-input", app)
        let draft = input.value as? String ?? ""
        print("PDFnoLiveInput: isolated follow-up field role=\(input.elementType.rawValue) existing draft=\(String(reflecting: draft))")
        XCTAssertTrue(["", "Give one short example using this word.", "Give了瘦肉汤example using thisword.", "word.Give one short example using this word."].contains(draft), "Only replace this test's own empty or generated input")
        try click(input)
        try ownDesktop(); app.typeKey("a", modifierFlags: .command)
        XCTAssertTrue(input.exists, "Native Select All must keep the conversation input open")
        NSPasteboard.general.clearContents()
        XCTAssertTrue(NSPasteboard.general.setString("Give one short example using this word.", forType: .string))
        try ownDesktop(); app.typeKey("v", modifierFlags: .command)
        XCTAssertTrue(input.exists, "Native Paste must keep the conversation input open")
        let pasted = input.value as? String ?? ""
        print("PDFnoLiveInput: after application Paste value=\(pasted)")
        XCTAssertEqual(pasted, "Give one short example using this word.")
        // One original follow-up. Connection probes and automatic retries stay absent.
        try click(ui("ai-conversation-send", app))
        print("PDFnoLiveResume: follow-up submitted; actual requests are recorded without a test ceiling")
        try uiWait("One resumed real follow-up answer; never retry", timeout: 35) {
            !self.ui("ai-conversation-stop", app).exists &&
                (self.ui("ai-conversation-status", app).exists || answers().contains { !answerIdentifiersBefore.contains($0.identifier) })
        }
        XCTAssertFalse(ui("ai-conversation-status", app).exists, "A stopped request with a failure is not a received answer")
        let newAnswers = answers().filter { !answerIdentifiersBefore.contains($0.identifier) }
        XCTAssertEqual(newAnswers.count, 1, "Exactly one new reply; LazyVStack may omit the offscreen original AX node")
        XCTAssertEqual(answerCountBefore, 1, "This scoped candidate continues its one original explanation")
        let followup = try XCTUnwrap(newAnswers.first)
        XCTAssertFalse(uiText(followup).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(uiText(followup).contains("本地 mock")); XCTAssertFalse(uiText(followup).contains("离线 DeepSeek UI 替身"))
        XCTAssertEqual(ui("ai-conversation-save-" + followup.identifier.replacingOccurrences(of: "ai-conversation-answer-", with: ""), app).label, "加入笔记")
        try ownDesktop()
        let followupShot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        followupShot.name = "real-original-followup-no-auto-note"; followupShot.lifetime = .keepAlways; add(followupShot)
        for _ in 0..<8 {
            if ui("ai-conversation-answer-" + answerID, app).exists { break }
            try ownDesktop(); messages.scroll(byDeltaX: 0, deltaY: 700)
        }
        XCTAssertTrue(ui("ai-conversation-answer-" + answerID, app).waitForExistence(timeout: 8))
        XCTAssertEqual(uiText(ui("ai-conversation-answer-" + answerID, app)), firstText)
        XCTAssertEqual(try fixedConversationQuote(app), "window")
        XCTAssertTrue(try JSONSerialization.data(withJSONObject: uiAnnotations(app), options: [.sortedKeys]) == JSONSerialization.data(withJSONObject: savedRecords, options: [.sortedKeys]), "The follow-up cannot auto-save or change either note")
        print("PDFnoLiveResume: follow-up received, original preserved, only explicit note persisted")
        try click(ui("ai-conversation-return", app))
        XCTAssertTrue(uiText(ui("page-position", app)).contains("1 / 2"))
        try click(ui("ai-close", app))
        try ownDesktop(); try uiPDFShortcut(.rightArrow, app)
        try uiContains(ui("page-position", app), "2 / 2")
        try ownDesktop(); try uiPanel("reader-notes", open: true, app)
        let row = ui("annotation-row-" + (try XCTUnwrap(note["id"] as? String)), app)
        try ownDesktop(); try uiReveal(row, scroll: "annotation-list", app)
        try click(row)
        try uiContains(ui("annotation-status", app), "已定位原文")
        XCTAssertTrue(uiText(ui("page-position", app)).contains("1 / 2"))
        let excerpts = app.staticTexts.matching(identifier: "annotation-excerpt").allElementsBoundByIndex.map { uiText($0) }
        XCTAssertTrue(excerpts.contains("window"))
        print("PDFnoLiveResume: saved AI note located the exact original PDF page and quote")
        try ownDesktop()
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = "live-two-requests-fixed-source-and-explicit-note"; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor func testAuthorizedLiveFinishSubmittedFollowupAndSourceNavigation() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        guard environment["PDFNO_LIVE_QA_ENABLED"] == "explicit-user-authorized",
              environment["PDFNO_LIVE_QA_FOLLOWUP_SUBMITTED"] == "1",
              let bundle = environment["PDFNO_PANEL_QA_BUNDLE"],
              bundle.hasPrefix("org.pdfno.integration.professionala20261007.qa"),
              let token = environment["PDFNO_PANEL_QA_SESSION"], UUID(uuidString: token) != nil,
              let originalID = environment["PDFNO_LIVE_QA_ORIGINAL_ANSWER_ID"] else {
            throw XCTSkip("Observe only the already-submitted request in its existing dedicated session")
        }
        let app = XCUIApplication(bundleIdentifier: bundle)
        XCTAssertNotEqual(app.state, .notRunning)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token // storage checks only; never launch
        app.activate()
        func ownDesktop() throws {
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle else {
                throw XCTSkip("EXPERIENCE_DESKTOP_CHANGED: stop follow-up observation input")
            }
        }
        func click(_ element: XCUIElement) throws {
            XCTAssertTrue(element.waitForExistence(timeout: 8))
            XCTAssertTrue(element.isEnabled && element.isHittable)
            try ownDesktop(); element.click()
        }
        func visibleAnswers() -> [XCUIElement] {
            app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'ai-conversation-answer-'" )).allElementsBoundByIndex
        }
        try ownDesktop()
        let records = try uiAnnotations(app)
        let originalNotes = records.filter {
            (($0["aiResult"] as? [String: Any])?["requestID"] as? String)?.uppercased() == originalID.uppercased()
        }
        XCTAssertEqual(originalNotes.count, 1)
        let note = try XCTUnwrap(originalNotes.first)
        let result = try XCTUnwrap(note["aiResult"] as? [String: Any])
        let firstText = try XCTUnwrap(result["text"] as? String)
        let recordsBytes = try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys])
        let firstIdentifier = "ai-conversation-answer-" + originalID
        print("PDFnoLiveFinish: existing answer IDs=\(visibleAnswers().map(\.identifier)); pending=\(ui("ai-conversation-stop", app).exists); service status visible=\(ui("ai-conversation-status", app).exists); no request sent")
        let failureStatus = ui("ai-conversation-status", app)
        if failureStatus.exists {
            // Product maps failures to fixed AIFailure messages; no response body or Key.
            print("PDFnoLiveFinish: sanitized application failure=\(uiText(failureStatus))")
        }
        XCTAssertFalse(failureStatus.exists, "The submitted request must succeed, not merely stop running")
        // LazyVStack exposes only rendered replies. Observe the new reply's identity,
        // not a count of offscreen accessibility nodes. Never send or retry here.
        try uiWait("The already-submitted remote follow-up finishes", timeout: 90) {
            !self.ui("ai-conversation-stop", app).exists && visibleAnswers().contains {
                $0.identifier != firstIdentifier && !self.uiText($0).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        let followups = visibleAnswers().filter { $0.identifier != firstIdentifier }
        XCTAssertEqual(followups.count, 1, "Exactly the one submitted follow-up")
        let followup = try XCTUnwrap(followups.first)
        let followupText = uiText(followup)
        XCTAssertFalse(followupText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(followupText.contains("本地 mock")); XCTAssertFalse(followupText.contains("离线 DeepSeek UI 替身"))
        XCTAssertEqual(ui("ai-conversation-save-" + followup.identifier.replacingOccurrences(of: "ai-conversation-answer-", with: ""), app).label, "加入笔记")
        XCTAssertTrue(try JSONSerialization.data(withJSONObject: uiAnnotations(app), options: [.sortedKeys]) == recordsBytes, "No automatic follow-up note or mutation of existing notes")
        print("PDFnoLiveFinish: submitted real follow-up received; generated result remains unsaved; no new request")
        try ownDesktop()
        let replyShot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        replyShot.name = "real-followup-original-fixture-no-auto-note"; replyShot.lifetime = .keepAlways; add(replyShot)
        let messages = ui("ai-conversation-messages", app)
        for _ in 0..<8 {
            if ui(firstIdentifier, app).exists { break }
            try ownDesktop(); messages.scroll(byDeltaX: 0, deltaY: 700)
        }
        XCTAssertTrue(ui(firstIdentifier, app).waitForExistence(timeout: 8))
        XCTAssertEqual(uiText(ui(firstIdentifier, app)), firstText, "The actual original explanation is unchanged")
        if !ui("ai-conversation-source", app).exists { try click(ui("ai-conversation-source-toggle", app)) }
        XCTAssertEqual(try fixedConversationQuote(app), "window")
        XCTAssertEqual(try uiAnchorPayload(note)["quote"] as? String, "window")
        XCTAssertEqual(note["userText"] as? String, "")
        XCTAssertEqual(result["fromCache"] as? Bool, false)
        let provider = try XCTUnwrap(result["provider"] as? [String: Any])
        XCTAssertEqual(provider["endpoint"] as? String, "https://api.deepseek.com")
        XCTAssertEqual(provider["model"] as? String, "deepseek-flash")
        try click(ui("ai-conversation-return", app))
        try uiContains(ui("page-position", app), "1 / 2")
        try click(ui("ai-close", app))
        try ownDesktop(); try uiPDFShortcut(.rightArrow, app)
        try uiContains(ui("page-position", app), "2 / 2")
        try ownDesktop(); try uiPanel("reader-notes", open: true, app)
        let row = ui("annotation-row-" + (try XCTUnwrap(note["id"] as? String)), app)
        try ownDesktop(); try uiReveal(row, scroll: "annotation-list", app)
        try click(row)
        try uiContains(ui("annotation-status", app), "已定位原文")
        try uiContains(ui("page-position", app), "1 / 2")
        XCTAssertTrue(app.staticTexts.matching(identifier: "annotation-excerpt").allElementsBoundByIndex.map { uiText($0) }.contains("window"))
        XCTAssertTrue(try JSONSerialization.data(withJSONObject: uiAnnotations(app), options: [.sortedKeys]) == recordsBytes)
        print("PDFnoLiveFinish: explicit AI note returned from page 2 to the exact page 1 quote; original response and all notes unchanged")
        try ownDesktop(); try uiPanel("reader-notes", open: false, app)
        try ownDesktop()
        let sourceShot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        sourceShot.name = "real-ai-note-return-from-page-two-to-page-one"; sourceShot.lifetime = .keepAlways; add(sourceShot)
    }

    @MainActor func testAuthorizedLiveSavedNoteSourceNavigationWithoutSending() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        guard environment["PDFNO_LIVE_QA_ENABLED"] == "explicit-user-authorized",
              let bundle = environment["PDFNO_PANEL_QA_BUNDLE"],
              bundle.hasPrefix("org.pdfno.integration.professionala20261007.qa"),
              let token = environment["PDFNO_PANEL_QA_SESSION"], UUID(uuidString: token) != nil,
              let originalID = environment["PDFNO_LIVE_QA_ORIGINAL_ANSWER_ID"] else {
            throw XCTSkip("Existing dedicated live session and original saved result required")
        }
        let app = XCUIApplication(bundleIdentifier: bundle)
        XCTAssertNotEqual(app.state, .notRunning)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token // storage checks only
        app.activate()
        func ownDesktop() throws {
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle else {
                throw XCTSkip("EXPERIENCE_DESKTOP_CHANGED: stop source navigation input")
            }
        }
        func click(_ element: XCUIElement) throws {
            XCTAssertTrue(element.waitForExistence(timeout: 8))
            XCTAssertTrue(element.isEnabled && element.isHittable)
            try ownDesktop(); element.click()
        }
        try ownDesktop()
        let records = try uiAnnotations(app)
        let originalNotes = records.filter {
            (($0["aiResult"] as? [String: Any])?["requestID"] as? String)?.uppercased() == originalID.uppercased()
        }
        XCTAssertEqual(originalNotes.count, 1)
        let note = try XCTUnwrap(originalNotes.first)
        let result = try XCTUnwrap(note["aiResult"] as? [String: Any])
        let recordsBytes = try JSONSerialization.data(withJSONObject: records, options: [.sortedKeys])
        let first = ui("ai-conversation-answer-" + originalID, app)
        XCTAssertTrue(first.waitForExistence(timeout: 8))
        XCTAssertEqual(uiText(first), result["text"] as? String)
        XCTAssertEqual(result["fromCache"] as? Bool, false)
        if !ui("ai-conversation-source", app).exists { try click(ui("ai-conversation-source-toggle", app)) }
        XCTAssertEqual(try fixedConversationQuote(app), "window")
        XCTAssertEqual(try uiAnchorPayload(note)["quote"] as? String, "window")
        XCTAssertEqual(note["userText"] as? String, "")
        try click(ui("ai-conversation-return", app))
        try uiContains(ui("page-position", app), "1 / 2")
        try click(ui("ai-close", app))
        try ownDesktop(); try uiPDFShortcut(.rightArrow, app)
        try uiContains(ui("page-position", app), "2 / 2")
        try ownDesktop(); try uiPanel("reader-notes", open: true, app)
        let row = ui("annotation-row-" + (try XCTUnwrap(note["id"] as? String)), app)
        try ownDesktop(); try uiReveal(row, scroll: "annotation-list", app)
        try click(row)
        try uiContains(ui("annotation-status", app), "已定位原文")
        try uiContains(ui("page-position", app), "1 / 2")
        XCTAssertTrue(app.staticTexts.matching(identifier: "annotation-excerpt").allElementsBoundByIndex.map { uiText($0) }.contains("window"))
        XCTAssertTrue(try JSONSerialization.data(withJSONObject: uiAnnotations(app), options: [.sortedKeys]) == recordsBytes, "AI and manual notes remain byte-for-byte unchanged")
        print("PDFnoLiveSource: saved real AI note returned from page 2 to the exact page 1 quote; original response and all notes unchanged; no request")
        try ownDesktop(); try uiPanel("reader-notes", open: false, app)
        try ownDesktop()
        let shot = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        shot.name = "real-ai-note-return-from-page-two-to-page-one"; shot.lifetime = .keepAlways; add(shot)
    }

    @MainActor func testAuthorizedLiveInspectVisibleRoutesWithoutInput() throws {
        let environment = ProcessInfo.processInfo.environment
        guard environment["PDFNO_LIVE_QA_DIAGNOSTICS"] == "routes-only",
              let bundle = environment["PDFNO_PANEL_QA_BUNDLE"],
              bundle.hasPrefix("org.pdfno.integration.professionala20261007.qa") else {
            throw XCTSkip("Read-only route diagnostics for the already-open dedicated app")
        }
        let app = XCUIApplication(bundleIdentifier: bundle)
        XCTAssertNotEqual(app.state, .notRunning)
        // Do not activate, launch, click, type, screenshot or read a credential.
        // Only known public route identifiers and panel state strings are read.
        let identifiers = ["professional-library-workspace", "ai-settings-form", "document-more", "page-position", "reader-navigation", "reader-notes", "reader-ai", "ai-close", "ai-tools-directory", "ai-conversation-source-toggle", "ai-conversation-source", "ai-conversation-input", "ai-conversation-send", "ai-conversation-retry", "ai-conversation-stop"]
        var routes: [[String: Any]] = []
        for identifier in identifiers {
            let element = ui(identifier, app)
            var route: [String: Any] = ["identifier": identifier, "exists": element.exists]
            if element.exists {
                route["hittable"] = element.isHittable
                if ["reader-navigation", "reader-notes", "reader-ai", "ai-conversation-source-toggle"].contains(identifier) {
                    route["panel_state"] = element.value as? String ?? ""
                }
            }
            routes.append(route)
        }
        let tabs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'document-tab-' AND NOT identifier BEGINSWITH 'document-tab-close-'"))
            .allElementsBoundByIndex.map { ["identifier": $0.identifier, "selected_state": $0.value as? String ?? ""] }
        let answerCount = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'ai-conversation-answer-'" )).count
        let data = try JSONSerialization.data(withJSONObject: ["routes": routes, "document_tabs": tabs, "visible_answers": answerCount, "input_actions": 0, "API_requests": 0], options: [.sortedKeys])
        print("PDFnoLiveRoutes: " + String(decoding: data, as: UTF8.self))
    }

    // Opt-in only; attach to the dedicated, already-open QA app after the user
    // applies a credential there. Never launch, restart, migrate or read its key.
    @MainActor func testAuthorizedLiveSelectionExplanationFollowupAndExplicitNote() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        guard environment["PDFNO_LIVE_QA_ENABLED"] == "explicit-user-authorized",
              environment["PDFNO_LIVE_QA_EXPLANATION_ALLOWED"] == "1",
              let bundle = environment["PDFNO_PANEL_QA_BUNDLE"],
              bundle.hasPrefix("org.pdfno.integration.professionala20261007.qa"),
              let token = environment["PDFNO_PANEL_QA_SESSION"], let session = UUID(uuidString: token) else {
            throw XCTSkip("Requires explicit live authorization and a dedicated synthetic QA session")
        }
        let app = XCUIApplication(bundleIdentifier: bundle)
        XCTAssertNotEqual(app.state, .notRunning, "User-configured QA app must already be open")
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = session.uuidString // storage assertions only; no launch()
        app.activate()
        func ownDesktop() throws {
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle else {
                throw XCTSkip("EXPERIENCE_DESKTOP_CHANGED: stop live-test input")
            }
        }
        func click(_ id: String) throws {
            let element = ui(id, app)
            XCTAssertTrue(element.waitForExistence(timeout: 8), id)
            XCTAssertTrue(element.isHittable && element.isEnabled, id)
            try ownDesktop(); element.click()
        }
        func answers() -> [XCUIElement] {
            app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'ai-conversation-answer-'" )).allElementsBoundByIndex
        }
        func awaitAnswers(_ count: Int) throws {
            try uiWait("Live answer count \(count); no retry", timeout: 35) {
                answers().count == count && !self.ui("ai-conversation-stop", app).exists
            }
            XCTAssertEqual(answers().count, count)
        }
        try ownDesktop()
        // Activating an existing window does not imply that its settings route
        // is visible. Navigate through the public entry before checking status.
        if !ui("ai-credential-status", app).exists { try click("ai-settings") }
        let credentialStatus = ui("ai-credential-status", app)
        XCTAssertTrue(credentialStatus.waitForExistence(timeout: 8))
        XCTAssertTrue(uiText(credentialStatus).contains("本次会话已配置 API Key"), "Read presence status only; never inspect the secure field")
        XCTAssertEqual(ui("ai-endpoint", app).value as? String, "https://api.deepseek.com")
        XCTAssertEqual(ui("ai-model", app).value as? String, "deepseek-flash")
        XCTAssertTrue(FileManager.default.fileExists(atPath: try uiStore(app).path), "Dedicated UUID library must already exist")
        try click("workspace-help"); try click("open-sample")
        XCTAssertTrue(originalPDFViewport(app).waitForExistence(timeout: 12))
        XCTAssertEqual(app.scrollViews.containing(NSPredicate(format: "label == %@", "document")).count, 1)
        XCTAssertEqual(try uiAnnotations(app).count, 0, "Fresh synthetic library")
        let phrase = "Reading opens a small window onto a wider world."
        var selectedLine: XCUIElement?
        try uiWait("Original PDFKit line", timeout: 12) {
            selectedLine = app.staticTexts.allElementsBoundByIndex.first { self.uiText($0) == phrase && $0.isHittable }
            return selectedLine != nil
        }
        let line = try XCTUnwrap(selectedLine), font = try XCTUnwrap(NSFont(name: "Helvetica", size: 14))
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let prefix = ("Reading opens a small " as NSString).size(withAttributes: attributes).width
        let word = ("window" as NSString).size(withAttributes: attributes).width
        let total = (phrase as NSString).size(withAttributes: attributes).width
        try ownDesktop(); line.coordinate(withNormalizedOffset: CGVector(dx: (prefix + word/2)/total, dy: 0.5)).doubleClick()
        try click("selection-ai-menu")
        // This public action sends request 1, using the immutable original selection.
        try click("selection-ai-explain"); try awaitAnswers(1)
        try click("ai-conversation-source-toggle")
        XCTAssertEqual(try fixedConversationQuote(app), "window")
        let first = try XCTUnwrap(answers().first), firstText = uiText(first)
        XCTAssertFalse(firstText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertFalse(firstText.contains("离线 DeepSeek UI 替身"))
        XCTAssertEqual(try uiAnnotations(app).count, 0, "Live output must not save automatically")
        let answerID = first.identifier.replacingOccurrences(of: "ai-conversation-answer-", with: "")
        try click("ai-conversation-save-" + answerID)
        try uiWait("Explicit live note commit", timeout: 12) { self.ui("ai-conversation-save-" + answerID, app).label == "已加入笔记" }
        let note = try uiOnlyAnnotation(app)
        XCTAssertEqual(try uiAnchorPayload(note)["quote"] as? String, "window")
        XCTAssertEqual(note["userText"] as? String, "", "Generated output stays separate from user-authored body")
        let savedResult = try XCTUnwrap(note["aiResult"] as? [String: Any])
        XCTAssertEqual(savedResult["text"] as? String, firstText, "Persist the exact generated result separately")
        let input = ui("ai-conversation-input", app)
        try click("ai-conversation-input")
        try ownDesktop(); input.typeText("Give one short example using this word.")
        // Request 2 only. Failure ends the test; never press Retry.
        try click("ai-conversation-send"); try awaitAnswers(2)
        XCTAssertEqual(try uiAnnotations(app).count, 1, "Follow-up must not save automatically")
        try click("ai-conversation-return")
        XCTAssertTrue(uiText(ui("page-position", app)).contains("1 / 2"))
        try ownDesktop()
        let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = "live-original-selection-and-explicit-note"; attachment.lifetime = .keepAlways; add(attachment)
    }

    @MainActor func testRealDividerDragSharedPanelsPersistenceAndAlwaysVisibleAPICards() throws {
        continueAfterFailure = false
        guard let bundle = ProcessInfo.processInfo.environment["PDFNO_PANEL_QA_BUNDLE"],
              bundle.hasPrefix("org.pdfno.integration.professionala20261007.qa"),
              let session = ProcessInfo.processInfo.environment["PDFNO_PANEL_QA_SESSION"], UUID(uuidString: session) != nil else {
            throw XCTSkip("Requires a dedicated offline QA bundle and fresh session; never launch production PDFno")
        }
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = session
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchArguments = ["-PDFno.AppAppearance", "light"]
        func element(_ id: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: id).firstMatch }
        func ownDesktop() throws {
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle else {
                throw XCTSkip("EXPERIENCE_DESKTOP_CHANGED: stop input; dedicated test app is not frontmost")
            }
        }
        func click(_ id: String) throws {
            let target = element(id); XCTAssertTrue(target.waitForExistence(timeout: 12),id)
            try ownDesktop(); target.click()
        }
        func openSample(_ id: String) throws {
            try click("workspace-help"); try click(id)
            let reader = id.contains("epub") ? element("epub-aa") : originalPDFViewport(app)
            XCTAssertTrue(reader.waitForExistence(timeout: 15))
        }
        func width() -> CGFloat {
            let handle = element("reader-panel-divider")
            return CGFloat(Double(String(describing: handle.value ?? "")) ?? -1)
        }
        func awaitWidth(_ expected: CGFloat) {
            let end = Date().addingTimeInterval(3)
            while abs(width() - expected) > 5 && Date() < end { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
            XCTAssertEqual(width(),expected,accuracy: 5)
        }
        func shot(_ name: String) throws {
            try ownDesktop(); let window = app.windows.firstMatch
            XCTAssertTrue(window.exists)
            let attachment = XCTAttachment(screenshot: window.screenshot()); attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        app.launch(); defer { app.terminate() }
        let frontDeadline = Date().addingTimeInterval(8)
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != bundle && Date() < frontDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        try ownDesktop()
        try openSample("open-sample"); try click("reader-navigation")
        let divider = element("reader-panel-divider"); XCTAssertTrue(divider.waitForExistence(timeout: 5)); XCTAssertTrue(divider.isHittable)
        let initial = width(), amount = min(35, width() - 230); XCTAssertGreaterThan(amount,10)
        let canvasBefore = originalPDFViewport(app).frame.width
        let origin = divider.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        try ownDesktop(); origin.click(forDuration: 0.15,thenDragTo: origin.withOffset(CGVector(dx: amount,dy: 0)))
        awaitWidth(initial - amount)
        XCTAssertGreaterThan(originalPDFViewport(app).frame.width,canvasBefore + 15,"Reader must grow with the narrowing panel")
        let left = divider.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        try ownDesktop(); left.click(forDuration: 0.15,thenDragTo: left.withOffset(CGVector(dx: -amount,dy: 0)))
        awaitWidth(initial)
        XCTAssertEqual(originalPDFViewport(app).frame.width,canvasBefore,accuracy: 5,"Reader must shrink as the panel widens")
        let final = divider.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        try ownDesktop(); final.click(forDuration: 0.15,thenDragTo: final.withOffset(CGVector(dx: amount/2,dy: 0)))
        awaitWidth(initial - amount/2); let saved = width()
        try shot("real-left-and-right-directory-drag")
        for id in ["reader-ai","reader-notes","reader-bookmarks"] { try click(id); awaitWidth(saved) }
        try click("reader-bookmarks"); XCTAssertFalse(divider.exists,"Icon must collapse the panel")
        try click("reader-bookmarks"); awaitWidth(saved)
        try openSample("open-epub-sample"); try click("epub-aa"); awaitWidth(saved)
        try shot("shared-width-epub-Aa")
        try ownDesktop(); app.terminate(); app.launch()
        let restartDeadline = Date().addingTimeInterval(8)
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != bundle && Date() < restartDeadline { RunLoop.current.run(until: Date().addingTimeInterval(0.1)) }
        try ownDesktop(); try openSample("open-sample"); try click("reader-navigation"); awaitWidth(saved)
        try click("ai-settings")
        for id in ["ai-endpoint","ai-session-key","ai-model","settings-japanese-card","settings-english-card"] { XCTAssertTrue(element(id).waitForExistence(timeout: 10),id) }
        let mode = element("ai-provider-mode"); try ownDesktop(); mode.click()
        XCTAssertFalse(app.menuItems["未配置"].exists,"Unconfigured must not be a provider choice")
        try ownDesktop(); app.typeKey(.escape,modifierFlags: [])
        try shot("always-visible-global-api-and-language-cards")
    }
}
#endif

// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest
import AppKit

final class MacFourLayoutUITests: XCTestCase {
    private var bundle = ""
    @MainActor private func startApp() throws -> XCUIApplication {
        continueAfterFailure = false
        let env = ProcessInfo.processInfo.environment
        guard let id = env["PDFNO_FOUR_LAYOUT_BUNDLE"], id.contains(".qaMacFourLayout20261013."),
              let token = env["PDFNO_FOUR_LAYOUT_SESSION"], UUID(uuidString: token) != nil else {
            throw XCTSkip("Dedicated offline QA bundle and synthetic Library only")
        }
        bundle = id
        let app = XCUIApplication(bundleIdentifier: id)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchArguments = ["--ui-testing", "--ui-test-session", token, "--ui-test-four-layout-preview", "-PDFno.AppAppearance", "light"]
        app.launch(); try openOwnWindow(app)
        try click(ui("ai-settings", app))
        XCTAssertTrue(ui("ai-provider-mode", app).waitForExistence(timeout: 8))
        return app
    }
    @MainActor private func openOwnWindow(_ app: XCUIApplication) throws {
        let url = try XCTUnwrap(NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle))
        XCTAssertTrue(url.path.hasSuffix("/.build/MacFourUI/2026-10-13/Products/PDFnoMac.app"))
        XCTAssertEqual(Bundle(url: url)?.bundleIdentifier, bundle)
        // XCTest launch does not always send a reopen event to a single Window
        // scene. Reopen only this exact registered offline QA product.
        XCTAssertTrue(NSWorkspace.shared.open(url))
        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        try ownDesktop()
    }
    @MainActor private func ownDesktop() throws {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle else {
            throw XCTSkip("EXPERIENCE_DESKTOP_CHANGED: stop scoped offline UI input")
        }
    }
    @MainActor private func click(_ element: XCUIElement) throws {
        XCTAssertTrue(element.waitForExistence(timeout: 8)); XCTAssertTrue(element.isEnabled && element.isHittable)
        try ownDesktop(); element.click()
    }
    @MainActor private func viewport(_ app: XCUIApplication) -> XCUIElement {
        app.scrollViews.containing(NSPredicate(format: "label == %@", "document")).firstMatch
    }
    @MainActor private func sample(_ app: XCUIApplication, epub: Bool = false) throws {
        try click(ui("workspace-help", app)); try click(ui(epub ? "open-epub-sample" : "open-sample", app))
        XCTAssertTrue((epub ? ui("epub-aa", app) : viewport(app)).waitForExistence(timeout: 12))
    }
    @MainActor private func shot(_ name: String, _ app: XCUIApplication) throws {
        try ownDesktop(); let attachment = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    @MainActor private func blueHoverShot(_ name: String, _ app: XCUIApplication) throws {
        let divider = ui("reader-panel-divider", app), window = app.windows.firstMatch
        // Splitter's default hittable point is its bottom edge on this SDK.
        // Use the native center coordinate inside the same 14-point handle.
        try ownDesktop(); divider.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5)).hover()
        RunLoop.current.run(until: Date().addingTimeInterval(0.15))
        try ownDesktop(); let screenshot = window.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        let bitmap = try XCTUnwrap(NSBitmapImageRep(data: screenshot.pngRepresentation))
        let scale = CGFloat(bitmap.pixelsWide) / window.frame.width
        let center = Int((divider.frame.midX - window.frame.minX) * scale)
        let lower = max(0, Int((divider.frame.minY - window.frame.minY + 20) * scale))
        let upper = min(bitmap.pixelsHigh - 1, Int((divider.frame.maxY - window.frame.minY - 20) * scale))
        print("PDFnoFourUI hover geometry divider=\(divider.frame) window=\(window.frame) pointer=\(NSEvent.mouseLocation) pixel-column=\(center)")
        XCTAssertGreaterThan(upper, lower)
        var blueRows = 0, rows = 0
        for y in stride(from: lower, through: upper, by: max(1,bitmap.pixelsHigh/180)) {
            rows += 1
            if (max(0,center-8)...min(bitmap.pixelsWide-1,center+8)).contains(where: { x in
                guard let c = bitmap.colorAt(x: x,y: y)?.usingColorSpace(.deviceRGB) else { return false }
                return c.redComponent < 0.35 && c.blueComponent > 0.7 && c.greenComponent < 0.85
            }) { blueRows += 1 }
        }
        let fraction = Double(blueRows) / Double(max(1,rows))
        print("PDFnoFourUI visible blue divider \(name): \(fraction)")
        XCTAssertGreaterThan(fraction,0.7,"The actual window screenshot must show a blue vertical hover cue")
    }
    @MainActor func test01SelectionHasNoSourceHeaderAndSettingsRemainSeparated() throws {
        let app = try startApp()
        try shot("initial-isolated-QA-window", app)
        try click(ui("ai-provider-mode", app)); try click(app.menuItems["本地示例"].firstMatch)
        try click(ui("ai-settings-save", app))
        XCTAssertFalse(ui("settings-japanese-card", app).exists)
        XCTAssertFalse(ui("settings-english-card", app).exists)
        let endpoint = ui("ai-endpoint", app).value as? String
        let model = ui("ai-model", app).value as? String
        try shot("settings-AI-only-connection", app)
        try click(ui("settings-category-aiTools", app))
        XCTAssertFalse(ui("ai-provider-mode", app).exists)
        XCTAssertFalse(ui("ai-endpoint", app).exists)
        XCTAssertTrue(ui("settings-japanese-card", app).exists && ui("settings-english-card", app).exists)
        try shot("settings-AI-tools-before-toggle", app)
        print("PDFnoFourUI scoped toggle AX: " + app.checkBoxes.debugDescription)
        try click(app.checkBoxes["启用日语学习"].firstMatch); try click(app.checkBoxes["启用英语学习"].firstMatch)
        let preferences = try uiManifest("ai-reading-tools-v1.json", app)
        XCTAssertEqual(preferences["japanese"] as? Bool, true)
        XCTAssertEqual(preferences["english"] as? Bool, true)
        try shot("settings-AI-tools-two-independent-cards", app)
        try click(ui("settings-category-ai", app))
        XCTAssertEqual(ui("ai-endpoint", app).value as? String, endpoint)
        XCTAssertEqual(ui("ai-model", app).value as? String, model)
        XCTAssertFalse(ui("settings-japanese-card", app).exists)
        try click(ui("settings-return", app))
        try sample(app)
        try ownDesktop(); try uiSelectPDFWindow(app)
        try click(ui("selection-ai-menu", app)); try click(ui("selection-ai-explain", app))
        func answers() -> [XCUIElement] {
            app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'ai-conversation-answer-'" )).allElementsBoundByIndex
        }
        try uiWait("Explicit local answer only") { !answers().isEmpty }
        XCTAssertFalse(ui("ai-conversation-source-toggle", app).exists)
        XCTAssertFalse(ui("ai-conversation-source", app).exists)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '原文 ·'" )).firstMatch.exists)
        let first = try XCTUnwrap(answers().first), firstText = uiText(first)
        XCTAssertTrue(firstText.contains("本地 mock"))
        XCTAssertEqual(try uiAnnotations(app).count, 0)
        let answerID = first.identifier.replacingOccurrences(of: "ai-conversation-answer-", with: "")
        try click(ui("ai-conversation-save-" + answerID, app))
        try uiWait("Explicit note commit only") { (try? self.uiAnnotations(app).count) == 1 }
        let note = try uiOnlyAnnotation(app)
        XCTAssertEqual(try uiAnchorPayload(note)["quote"] as? String, "window")
        XCTAssertEqual((note["aiResult"] as? [String: Any])?["text"] as? String, firstText)
        let input = ui("ai-conversation-input", app)
        try click(input); try ownDesktop(); app.typeKey("a", modifierFlags: .command)
        NSPasteboard.general.clearContents(); XCTAssertTrue(NSPasteboard.general.setString("Give one short example using this word.", forType: .string))
        try ownDesktop(); app.typeKey("v", modifierFlags: .command)
        XCTAssertEqual(input.value as? String, "Give one short example using this word.")
        try click(ui("ai-conversation-send", app))
        try uiWait("Local follow-up retains the fixed source") { answers().contains { $0.identifier != first.identifier } }
        XCTAssertEqual(try uiAnnotations(app).count, 1, "Follow-up is not automatically saved")
        XCTAssertEqual(try uiAnchorPayload(try uiOnlyAnnotation(app))["quote"] as? String, "window")
        try shot("selection-dialogue-header-and-source-block-removed", app)
        try click(ui("ai-conversation-return", app)); try uiContains(ui("page-position", app), "1 / 2")
        try click(ui("ai-close", app))
        try ownDesktop(); try uiPDFShortcut(.rightArrow, app); try uiContains(ui("page-position", app), "2 / 2")
        try ownDesktop(); try uiPanel("reader-notes", open: true, app)
        let row = ui("annotation-row-" + (try XCTUnwrap(note["id"] as? String)), app)
        try ownDesktop(); try uiReveal(row, scroll: "annotation-list", app); try click(row)
        try uiContains(ui("annotation-status", app), "已定位原文"); try uiContains(ui("page-position", app), "1 / 2")
        print("PDFnoFourUI: no source header/block; connection/tools separate; saved flags and config retained; local follow-up not saved; precise note jump passed")
    }
    @MainActor func test02BottomDocumentStartConsentAndSharedBlueDivider() throws {
        let app = try startApp(); try sample(app)
        try click(ui("reader-navigation", app))
        func width() -> Double { Double(String(describing: ui("reader-panel-divider", app).value ?? "")) ?? -1 }
        let divider = ui("reader-panel-divider", app), initial = width(), before = viewport(app).frame.width
        XCTAssertGreaterThan(initial, 230)
        try shot("directory-idle-subtle-divider", app)
        try blueHoverShot("directory-blue-hover-divider", app)
        let point = divider.coordinate(withNormalizedOffset: CGVector(dx: 0.5,dy: 0.5))
        try ownDesktop(); point.click(forDuration: 0.15,thenDragTo: point.withOffset(CGVector(dx: 24,dy: 0)))
        try uiWait("Physical panel drag updates width") { abs(width() - (initial - 24)) < 5 }
        XCTAssertGreaterThan(viewport(app).frame.width,before+12)
        let changed = width()
        for id in ["reader-ai", "reader-notes", "reader-bookmarks"] {
            try click(ui(id, app)); XCTAssertEqual(width(),changed,accuracy: 5)
            try blueHoverShot(id + "-shared-blue-divider", app)
        }
        try click(ui("reader-ai", app))
        let start = app.buttons["开始对话"].firstMatch, card = ui("document-ai-document-card", app)
        XCTAssertTrue(start.waitForExistence(timeout: 10)); XCTAssertTrue(start.isEnabled)
        XCTAssertEqual(start.frame.midX,card.frame.midX,accuracy: 3)
        XCTAssertGreaterThanOrEqual(start.frame.height,44)
        XCTAssertGreaterThan(card.frame.minY,app.windows.firstMatch.frame.midY)
        XCTAssertFalse(ui("document-ai-answer", app).exists); XCTAssertFalse(ui("document-ai-consent", app).exists)
        try shot("whole-document-initial-bottom-card-and-centered-start", app)
        try click(start)
        let confirmSend = app.windows.buttons["发送并开始对话"].firstMatch
        let cancelSend = app.windows.buttons["取消"].firstMatch
        XCTAssertTrue(confirmSend.waitForExistence(timeout: 5))
        XCTAssertFalse(ui("document-ai-answer", app).exists, "Start shows consent and cannot send")
        try shot("whole-document-explicit-consent-before-send", app)
        try click(cancelSend)
        XCTAssertFalse(ui("document-ai-answer", app).exists)
        try sample(app,epub: true); try click(ui("epub-aa", app)); XCTAssertEqual(width(),changed,accuracy: 5)
        try blueHoverShot("Aa-shared-blue-divider", app)
        try ownDesktop(); app.terminate(); app.launch(); try openOwnWindow(app); try sample(app)
        try click(ui("reader-navigation", app)); XCTAssertEqual(width(),changed,accuracy: 5, "Changed shared width survives this offline App restart")
        try click(ui("reader-ai", app)); try click(app.buttons["开始对话"].firstMatch); try click(confirmSend)
        XCTAssertTrue(ui("document-ai-answer", app).waitForExistence(timeout: 10))
        XCTAssertEqual(try uiAnnotations(app).count,1)
        print("PDFnoFourUI: large bottom-centered Start; no answer before consent; local answer only after confirmation; actual drag/shared widths/restart and five blue cues passed")
        // Leave the dedicated preview at its initial layout without touching either live-Key App.
        try ownDesktop(); app.terminate(); app.launch(); try openOwnWindow(app); try sample(app); try click(ui("reader-ai", app))
    }
}
#endif

#if os(macOS)
final class MacFourLiveUITests: XCTestCase {
    private var bundle = ""
    private var metadataPath = ""
    @MainActor private func ownDesktop() throws {
        guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundle else {
            throw XCTSkip("FOUR_LIVE_DESKTOP_CHANGED: stop input; retain existing Key process")
        }
    }
    @MainActor private func click(_ target: XCUIElement) throws {
        XCTAssertTrue(target.waitForExistence(timeout: 8)); XCTAssertTrue(target.isEnabled && target.isHittable)
        try ownDesktop(); target.click()
    }
    private func events() throws -> [[String: Any]] {
        let data = try Data(contentsOf: URL(fileURLWithPath: metadataPath))
        let allowed = Set(["event", "atUTC", "requestID", "httpStatus"])
        return String(decoding: data,as: UTF8.self).split(separator: "\n").compactMap { line in
            guard let value = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any],
                  Set(value.keys).isSubset(of: allowed),value["event"] is String else { return nil }
            return value
        }
    }
    private func count(_ event: String) throws -> Int { try events().filter { $0["event"] as? String == event }.count }
    @MainActor private func shot(_ name: String,_ app: XCUIApplication) throws {
        try ownDesktop(); let a = XCTAttachment(screenshot: app.windows.firstMatch.screenshot())
        a.name=name;a.lifetime = .keepAlways;add(a)
    }
    @MainActor private func reveal(_ target: XCUIElement,_ app: XCUIApplication) throws {
        let scroll=ui("ai-conversation-messages",app)
        for _ in 0..<12 {
            if scroll.frame.insetBy(dx: 3,dy: 5).contains(target.frame) && target.isHittable { return }
            try ownDesktop();scroll.scroll(byDeltaX: 0,deltaY: target.frame.minY < scroll.frame.minY ? 220 : -220)
        }
        XCTAssertTrue(target.isHittable)
    }
    @MainActor func testFinalFourUIRealSelectionAndFullDocumentConsent() throws {
        continueAfterFailure=false
        let env=ProcessInfo.processInfo.environment
        guard env["PDFNO_FOUR_LIVE_AUTHORIZATION"] == "explicit-user-authorized",
              let id=env["PDFNO_FOUR_LIVE_BUNDLE"],id.contains(".qaMacFourLive20261013."),
              let token=env["PDFNO_FOUR_LIVE_SESSION"],UUID(uuidString: token) != nil,
              let path=env["PDFNO_FOUR_LIVE_METADATA"],path.hasSuffix("/LiveAPI/APP.stdout") else {
            throw XCTSkip("Explicit authorization and original-only dedicated live QA required")
        }
        bundle=id;metadataPath=path
        let app=XCUIApplication(bundleIdentifier: id)
        XCTAssertNotEqual(app.state,.notRunning,"Never relaunch or recreate the user-entered credential session")
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"]=token // own-fixture storage assertions only
        app.activate();try ownDesktop()
        XCTAssertEqual(try count("unlimited_selection_session"),1,"No QA request ceiling")
        XCTAssertEqual(try count("transport_dispatch"),0);XCTAssertEqual(try count("document_transport_dispatch"),0)
        print("PDFnoFourLive public credential status: " + uiText(ui("ai-credential-status",app)))
        print("PDFnoFourLive public connection status: " + uiText(ui("ai-connection-status",app)))
        try uiContains(ui("ai-credential-status",app),"已配置") // never inspect SecureField value
        XCTAssertEqual(ui("ai-endpoint",app).value as? String,"https://api.deepseek.com")
        XCTAssertEqual(ui("ai-model",app).value as? String,"deepseek-flash")
        XCTAssertFalse(ui("settings-japanese-card",app).exists)
        try click(ui("settings-category-aiTools",app))
        XCTAssertFalse(ui("ai-endpoint",app).exists)
        XCTAssertTrue(ui("settings-japanese-card",app).exists && ui("settings-english-card",app).exists)
        try click(ui("settings-category-ai",app));try uiContains(ui("ai-credential-status",app),"已配置")
        try click(ui("settings-return",app));try click(ui("workspace-help",app));try click(ui("open-sample",app))
        XCTAssertTrue(app.scrollViews.containing(NSPredicate(format:"label == %@","document")).firstMatch.waitForExistence(timeout:12))
        XCTAssertEqual(try uiAnnotations(app).count,0)
        try ownDesktop();try uiSelectPDFWindow(app)
        try click(ui("selection-ai-menu",app));try click(ui("selection-ai-explain",app))
        func answers() -> [XCUIElement] { app.descendants(matching:.any).matching(NSPredicate(format:"identifier BEGINSWITH 'ai-conversation-answer-'" )).allElementsBoundByIndex }
        try uiWait("Real explanation accepted; no automatic retry",timeout:35) { !answers().isEmpty || self.ui("ai-conversation-status",app).exists }
        XCTAssertFalse(ui("ai-conversation-status",app).exists)
        let first=try XCTUnwrap(answers().first),text=uiText(first)
        let firstIdentifier=first.identifier
        XCTAssertFalse(text.isEmpty || text.contains("本地 mock") || text.contains("离线 DeepSeek UI 替身"))
        XCTAssertFalse(ui("ai-conversation-source-toggle",app).exists);XCTAssertFalse(ui("ai-conversation-source",app).exists)
        XCTAssertEqual(try count("transport_dispatch"),1);XCTAssertEqual(try count("server_response"),1)
        XCTAssertEqual(try events().filter { $0["event"] as? String == "server_response" }.last?["httpStatus"] as? Int,200)
        let firstID=first.identifier.replacingOccurrences(of:"ai-conversation-answer-",with:"")
        let save=ui("ai-conversation-save-"+firstID,app);try reveal(save,app);try click(save)
        try uiWait("Explicit real AI note commit") { (try? self.uiAnnotations(app).count)==1 }
        let note=try uiOnlyAnnotation(app),result=try XCTUnwrap(note["aiResult"] as? [String:Any])
        XCTAssertEqual(try uiAnchorPayload(note)["quote"] as? String,"window")
        XCTAssertEqual(note["userText"] as? String,"");XCTAssertEqual(result["text"] as? String,text)
        XCTAssertEqual(result["fromCache"] as? Bool,false)
        let input=ui("ai-conversation-input",app);try click(input)
        try ownDesktop();app.typeKey("a",modifierFlags:.command)
        NSPasteboard.general.clearContents();XCTAssertTrue(NSPasteboard.general.setString("Give one short example using this word.",forType:.string))
        try ownDesktop();app.typeKey("v",modifierFlags:.command)
        XCTAssertEqual(input.value as? String,"Give one short example using this word.")
        try click(ui("ai-conversation-send",app))
        try uiWait("Real follow-up accepted; no automatic retry",timeout:35) { answers().contains { $0.identifier != firstIdentifier } || self.ui("ai-conversation-status",app).exists }
        XCTAssertFalse(ui("ai-conversation-status",app).exists)
        let followup=try XCTUnwrap(answers().first { $0.identifier != firstIdentifier })
        XCTAssertFalse(uiText(followup).isEmpty || uiText(followup).contains("本地 mock"))
        XCTAssertEqual(try count("transport_dispatch"),2);XCTAssertEqual(try count("server_response"),2)
        XCTAssertTrue(try events().filter { $0["event"] as? String == "server_response" }.allSatisfy { $0["httpStatus"] as? Int == 200 })
        XCTAssertEqual(try uiAnnotations(app).count,1,"Follow-up never auto-saves")
        XCTAssertEqual(try uiAnchorPayload(try uiOnlyAnnotation(app))["quote"] as? String,"window")
        try shot("real-selection-explanation-followup-explicit-note-no-source-header",app)
        try click(ui("ai-close",app));try click(ui("reader-ai",app))
        let start=app.windows.buttons["开始对话"].firstMatch
        XCTAssertTrue(start.waitForExistence(timeout:10));XCTAssertTrue(start.isEnabled)
        XCTAssertFalse(ui("document-ai-answer",app).exists)
        XCTAssertEqual(try count("document_transport_dispatch"),0,"Opening full AI cannot send")
        try shot("real-full-document-initial-no-send",app);try click(start)
        let confirm=app.windows.buttons["发送并开始对话"].firstMatch,cancel=app.windows.buttons["取消"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout:5));XCTAssertFalse(ui("document-ai-answer",app).exists)
        XCTAssertEqual(try count("document_transport_dispatch"),0,"Start only requests consent")
        try shot("real-full-document-confirmation-zero-dispatch",app);try click(cancel)
        XCTAssertEqual(try count("document_transport_dispatch"),0);XCTAssertFalse(ui("document-ai-answer",app).exists)
        try click(start);try click(confirm)
        try uiWait("Real full document response accepted",timeout:35) { self.ui("document-ai-answer",app).exists || self.ui("document-ai-error",app).exists }
        XCTAssertFalse(ui("document-ai-error",app).exists)
        let documentText=uiText(ui("document-ai-answer",app))
        XCTAssertFalse(documentText.isEmpty || documentText.contains("本地示例") || documentText.contains("未联网"))
        XCTAssertEqual(try count("document_transport_dispatch"),1);XCTAssertEqual(try count("document_server_response"),1)
        XCTAssertEqual(try events().filter { $0["event"] as? String == "document_server_response" }.last?["httpStatus"] as? Int,200)
        XCTAssertEqual(try uiAnnotations(app).count,1)
        try shot("real-full-document-answer-only-after-confirmation",app)
        print("PDFnoFourLive: actual selection explanation and follow-up HTTP200; one explicit note; original window quote; settings retains connection; full document zero sends through Start/cancel and HTTP200 only after confirm; no request ceiling")
    }
}
#endif
