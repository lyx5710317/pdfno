// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest
import AppKit

/// Added only to the guarded local QA project. Never launches the product bundle.
final class ProfessionalReaderUITests: XCTestCase {
    // Navigation driver only: existing behavior assertions remain in the methods.
    @MainActor private func navigateWorkspace(_ id: String, in app: XCUIApplication) {
        #if os(macOS)
        func target(_ name: String) -> XCUIElement { app.descendants(matching: .any).matching(identifier: name).firstMatch }
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

    @MainActor private func originalApp(width: Int, dark: Bool) throws -> XCUIApplication {
        let identifier = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_ISOLATED_UI_APPLICATION_ID"])
        let expected = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_EXPECTED_BUNDLE"])
        XCTAssertEqual(identifier, expected)
        XCTAssertTrue(identifier.hasPrefix("org.pdfno.integration.professionala20261007.qa"))
        XCTAssertTrue(identifier.hasSuffix(".PDFnoMac"))
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
        let target = app.descendants(matching: .any).matching(identifier: id).firstMatch
        if !target.exists, id == "workspace-resume-reader" {
            let tabs = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'document-tab-' AND NOT identifier BEGINSWITH 'document-tab-close-'"))
            XCTAssertEqual(tabs.count, 1, "Resume the scenario's single real document tab")
            return tabs.firstMatch
        }
        if !target.exists, id == "workspace-tools" {
            return app.descendants(matching: .any).matching(identifier: "document-more").firstMatch
        }
        if !target.exists, id == "ai-tools-open" {
            return app.menuItems.matching(identifier: "document-reading-tools").firstMatch
        }
        if ["library-category-personal", "library-category-examples"].contains(id), !target.exists {
            let picker = app.descendants(matching: .any).matching(identifier: "library-category-picker").firstMatch
            if picker.exists {
                picker.click()
                return app.menuItems[id == "library-category-examples" ? "示例文档" : "我的书库"].firstMatch
            }
        }
        return target
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
    @MainActor private func waitForRemoval(_ element: XCUIElement) {
        // EPUB source navigation awaits a real WebKit reply before closing
        // its panel. Observe completion before the original closure assertion.
        let removed = expectation(for: NSPredicate { _, _ in !element.exists }, evaluatedWith: element)
        wait(for: [removed], timeout: 10)
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
        // Example import is asynchronous. Begin the keyboard check only after
        // the real PDF reader has appeared, then focus this fixture window.
        contains(item("page-position", app), "1 / 2")
        app.activate()
        app.typeKey("f", modifierFlags: .command)
        let input = item("search-input", app)
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        // No field click: Cmd-F must have moved keyboard focus into the actual search field.
        app.typeKey("a", modifierFlags: .command); pasteOriginal("window", app: app); value(input, equals: "window")
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
        try uiExample("open-sample", app); try searchOriginal(app)
        XCTAssertTrue(item("professional-reader-tool-rail", app).exists)
        XCTAssertLessThanOrEqual(app.windows.firstMatch.frame.width, 760)
        try uiSelectPDFWindow(app); try uiBeginNote(app)
        let body = "A original uncommitted draft 日本語 cafe\u{301}"
        try uiPaste(body, item("annotation-comment-input", app))
        app.typeKey(.rightArrow, modifierFlags: [.command, .option])
        contains(item("page-position", app), "1 / 2"); value(item("annotation-comment-input", app), equals: body)
        XCTAssertEqual(try uiAnnotations(app).count, 0)
        // The current editor is a sheet. An interrupted edit must survive restart;
        // cancelling a resumed editing session then keeps its prior draft checkpoint.
        app.terminate(); app.launch(); app.activate(); try uiExample("open-sample", app); try searchOriginal(app)
        try uiPanel("reader-notes", open: true, app); try uiResumeDraft(app)
        value(item("annotation-comment-input", app), equals: body)
        try click(item("annotation-editor-cancel", app))
        try uiPanel("reader-notes", open: false, app); try uiPanel("reader-notes", open: true, app)
        XCTAssertEqual(uiAnnotationRows(app).count, 0); try uiResumeDraft(app)
        value(item("annotation-comment-input", app), equals: body)
        try capture("A-product-03-narrow-notes-light", app: app)
        try click(item("annotation-editor-cancel", app)); try uiPanel("reader-notes", open: false, app)
        app.typeKey("f", modifierFlags: .command); value(item("search-input", app), equals: "window")
    }

    @MainActor func testARegularDarkLearningPanelConsentDraftAndManualSave() throws {
        let app = try originalApp(width: 1280, dark: true); defer { app.terminate() }
        try uiConfigureMock(app); try uiExample("open-sample", app); try searchOriginal(app); try uiSelectPDFWindow(app)
        XCTAssertEqual(try uiAnnotations(app).count, 0); XCTAssertEqual(uiConversationAnswers(app).count, 0)
        try uiChooseConversationTask("translate", app); let answer = try uiOnlyConversationAnswer(app)
        XCTAssertTrue(uiText(answer).contains("本地 mock")); XCTAssertEqual(try uiAnnotations(app).count, 0)
        try uiSaveConversationAnswer(answer, app); let original = try uiOnlyAnnotation(app)
        XCTAssertEqual(original["userText"] as? String, ""); XCTAssertNotNil(original["aiResult"])
        try uiCloseConversation(app); try uiPanel("reader-notes", open: true, app); try uiEditNote(app)
        let draft = item("annotation-comment-input", app), body = "A learning draft 日本語 👩🏽‍🚀"
        try uiPaste(body, draft); try click(item("annotation-editor-cancel", app))
        try uiPanel("reader-notes", open: false, app); try uiPanel("reader-notes", open: true, app); try uiResumeDraft(app)
        value(draft, equals: body)
        XCTAssertEqual(try uiOnlyAnnotation(app)["userText"] as? String, "", "The uncommitted user draft cannot alter the explicitly saved answer")
        XCTAssertEqual(try uiOnlyAnnotation(app)["aiResult"] as? NSDictionary, original["aiResult"] as? NSDictionary)
        try capture("A-product-04-learning-dark", app: app); try uiSaveNote(app)
        let note = try uiOnlyAnnotation(app)
        XCTAssertEqual(note["userText"] as? String, body); XCTAssertNotNil(note["aiResult"])
        XCTAssertEqual(note["aiResult"] as? NSDictionary, original["aiResult"] as? NSDictionary)
        XCTAssertEqual(try uiAnchorPayload(note)["quote"] as? String, "window")
        try uiReturnNote(app); try uiPanel("reader-notes", open: false, app)
        XCTAssertFalse(item("reader-notes-panel", app).exists); contains(item("page-position", app), "1 / 2")
    }

    @MainActor func testANarrowEPUBPanelsKeepCanonicalSourceAndDraft() throws {
        let app = try originalApp(width: 720, dark: true); defer { app.terminate() }
        try uiExample("open-epub-sample", app); try uiSelectWeb("window", app); try uiBeginNote(app)
        let body = "A EPUB original draft 日本語"
        try uiPaste(body, item("annotation-comment-input", app)); XCTAssertEqual(try uiAnnotations(app).count, 0)
        app.terminate(); app.launch(); app.activate(); try uiExample("open-epub-sample", app)
        try uiPanel("epub-notes", open: true, app); try uiResumeDraft(app)
        value(item("annotation-comment-input", app), equals: body); try click(item("annotation-editor-cancel", app))
        try uiPanel("epub-contents", open: true, app); try uiPanel("epub-contents", open: false, app)
        try uiPanel("epub-notes", open: true, app); try uiResumeDraft(app)
        value(item("annotation-comment-input", app), equals: body)
        try capture("A-product-05-narrow-epub-dark", app: app); try uiSaveNote(app)
        let note = try uiOnlyAnnotation(app); XCTAssertEqual(try uiAnchorPayload(note)["quote"] as? String, "window")
        try uiReturnNote(app); try uiPanel("epub-notes", open: false, app)
        XCTAssertFalse(item("reader-notes-panel", app).exists); contains(item("epub-position", app), "第 1 章")
    }

    @MainActor func testARegularLightPanelsRestoreReadingArea() throws {
        let app = try originalApp(width: 1280, dark: false); defer { app.terminate() }
        try uiExample("open-sample", app); contains(item("page-position", app), "1 / 2")
        XCTAssertTrue(item("professional-reader-tool-rail", app).exists)
        try capture("A-product-01-default-light", app: app)
        try uiPanel("reader-navigation", open: true, app)
        let navigation = item("reader-navigation-panel", app), notes = item("reader-notes-panel", app)
        XCTAssertTrue(navigation.exists)
        XCTAssertGreaterThanOrEqual(app.windows.firstMatch.frame.width - navigation.frame.width, 420)
        try uiPanel("reader-notes", open: true, app)
        XCTAssertTrue(notes.exists); XCTAssertFalse(navigation.exists)
        XCTAssertGreaterThanOrEqual(app.windows.firstMatch.frame.width - notes.frame.width, 420)
        try capture("A-product-02-exclusive-panel-light", app: app)
        try uiPanel("reader-notes", open: false, app)
        XCTAssertFalse(navigation.exists); XCTAssertFalse(notes.exists)
        try uiPDFShortcut(.rightArrow, app); contains(item("page-position", app), "2 / 2")
        try uiPDFShortcut(.leftArrow, app); contains(item("page-position", app), "1 / 2")
    }

    @MainActor func testShellRegularLightPDFDraftSelectionAndExamplePartition() throws {
        let app = try originalApp(width: 1280, dark: false); defer { app.terminate() }
        XCTAssertTrue(item("professional-library-workspace", app).waitForExistence(timeout: 15)); XCTAssertFalse(item("open-sample", app).exists)
        try uiExample("open-sample", app); try searchOriginal(app)
        XCTAssertFalse(item("professional-library-workspace", app).exists); XCTAssertFalse(item("open-sample", app).exists)
        try uiSelectPDFWindow(app); try uiBeginNote(app)
        let body = "Shell retained PDF draft 日本語 cafe\u{301}"
        try uiPaste(body, item("annotation-comment-input", app)); XCTAssertEqual(try uiAnnotations(app).count, 0)
        app.terminate(); app.launch(); app.activate(); try uiExample("open-sample", app)
        try uiPanel("reader-notes", open: true, app); try uiResumeDraft(app)
        value(item("annotation-comment-input", app), equals: body); try click(item("annotation-editor-cancel", app))
        try click(item("workspace-back-library", app)); XCTAssertFalse(item("library-book", app).exists)
        try click(item("library-category-examples", app)); XCTAssertTrue(item("library-book", app).waitForExistence(timeout: 10))
        try capture("A-shell-01-library-regular-light", app: app)
        try click(item("workspace-resume-reader", app)); try uiResumeDraft(app)
        value(item("annotation-comment-input", app), equals: body); contains(item("page-position", app), "1 / 2")
        try capture("A-shell-02-reader-regular-light", app: app)
        let library = try uiManifest("library-v1.json", app), origins = try uiManifest("bundled-examples-v1.json", app)
        let book = try XCTUnwrap((library["books"] as? [[String: Any]])?.first)
        let record = try XCTUnwrap((origins["records"] as? [[String: Any]])?.first), identity = try XCTUnwrap(record["book"] as? [String: Any])
        XCTAssertEqual(identity["bookID"] as? String, book["id"] as? String)
        XCTAssertEqual(identity["editionID"] as? String, book["editionID"] as? String)
        XCTAssertEqual(identity["fileSHA256"] as? String, book["fileSHA256"] as? String)
        XCTAssertEqual((library["notes"] as? [Any])?.count, 0); XCTAssertEqual(try uiAnnotations(app).count, 0)
    }

    @MainActor func testShellRegularDarkAIResultAndUncommittedDraftSurviveLibrary() throws {
        let app = try originalApp(width: 1280, dark: true); defer { app.terminate() }
        try uiConfigureMock(app); try uiExample("open-sample", app); try searchOriginal(app); try uiSelectPDFWindow(app)
        try uiChooseConversationTask("translate", app); let answer = try uiOnlyConversationAnswer(app)
        let body = "Shell retained AI draft 日本語", result = uiText(answer), answerID = answer.identifier
        // The accepted conversation retains its follow-up draft. The separate
        // annotation editor's user-body draft is covered by the dark-panel case.
        try uiPaste(body, item("ai-conversation-input", app)); XCTAssertEqual(try uiAnnotations(app).count, 0)
        try uiCloseConversation(app); try click(item("workspace-back-library", app))
        try click(item("library-category-examples", app)); try click(item("library-grid-layout", app))
        try capture("A-shell-03-library-grid-regular-dark", app: app); try click(item("library-book", app))
        try uiPanel("reader-ai", open: true, app)
        try click(item("document-ai-resume-selection", app))
        value(item("ai-conversation-input", app), equals: body); XCTAssertEqual(uiText(item(answerID, app)), result)
        XCTAssertEqual(uiConversationAnswers(app).count, 1); XCTAssertEqual(try uiAnnotations(app).count, 0)
        try capture("A-shell-04-reader-learning-regular-dark", app: app)
    }

    @MainActor func testShellNarrowLightPDFPageAndHelpToolsRoutes() throws {
        let app = try originalApp(width: 720, dark: false); defer { app.terminate() }
        XCTAssertTrue(item("professional-library-workspace", app).waitForExistence(timeout: 15))
        XCTAssertLessThanOrEqual(app.windows.firstMatch.frame.width, 760)
        try capture("A-shell-05-library-empty-narrow-light", app: app)
        navigateWorkspace("open-sample", in: app); try click(item("open-sample", app)); contains(item("page-position", app), "1 / 2")
        try uiPDFShortcut(.rightArrow, app); contains(item("page-position", app), "2 / 2")
        try click(item("workspace-back-library", app)); try click(item("workspace-resume-reader", app)); contains(item("page-position", app), "2 / 2")
        XCTAssertFalse(item("professional-library-workspace", app).exists)
        try capture("A-shell-06-reader-page2-narrow-light", app: app)
        try click(item("workspace-tools", app))
        XCTAssertTrue(item("bookno-preview-open", app).exists)
        XCTAssertTrue(app.menuItems.matching(identifier: "document-reading-translation").firstMatch.exists)
        XCTAssertTrue(app.menuItems.matching(identifier: "document-file-settings").firstMatch.exists)
        XCTAssertFalse(app.menuItems.matching(identifier: "document-reading-tools").firstMatch.exists)
        app.typeKey(.escape, modifierFlags: [])
        XCTAssertFalse(item("open-sample", app).exists)
    }
    @MainActor func testShellNarrowDarkEPUBCanonicalSelectionDraftAndLibrary() throws {
        let app = try originalApp(width: 720, dark: true); defer { app.terminate() }
        try uiExample("open-epub-sample", app); try uiSelectWeb("window", app); try uiBeginNote(app)
        let body = "Shell retained EPUB draft 日本語"
        try uiPaste(body, item("annotation-comment-input", app)); XCTAssertEqual(try uiAnnotations(app).count, 0)
        app.terminate(); app.launch(); app.activate(); try uiExample("open-epub-sample", app)
        try uiPanel("epub-notes", open: true, app); try uiResumeDraft(app)
        value(item("annotation-comment-input", app), equals: body); try click(item("annotation-editor-cancel", app))
        try click(item("workspace-back-library", app)); try click(item("library-category-examples", app))
        XCTAssertTrue(item("library-epub", app).waitForExistence(timeout: 10)); try capture("A-shell-07-library-examples-narrow-dark", app: app)
        try click(item("workspace-resume-reader", app)); try uiResumeDraft(app)
        value(item("annotation-comment-input", app), equals: body); contains(item("epub-position", app), "第 1 章")
        try capture("A-shell-08-reader-epub-narrow-dark", app: app)
        let root = try uiStore(app), data = try Data(contentsOf: root.appendingPathComponent("annotation-edit-drafts-v1.json"))
        let journal = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let draft = try XCTUnwrap((journal["drafts"] as? [[String: Any]])?.first), baseline = try XCTUnwrap(draft["baseline"] as? [String: Any])
        let note = try XCTUnwrap(baseline["annotation"] as? [String: Any])
        XCTAssertEqual(try uiAnchorPayload(note)["quote"] as? String, "window"); XCTAssertEqual(try uiAnnotations(app).count, 0)
    }


}
#endif
