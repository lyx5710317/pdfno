// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest
import AppKit

/// Added only to the guarded local QA project. Never launches the product bundle.
final class ReaderRightRailUITests: XCTestCase {
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


    @MainActor func testPDFRightRailHasOnePanelAndRetainsDraft() throws {
        let app = try originalApp(width: 1280, dark: false); defer { app.terminate() }
        navigateWorkspace("open-sample", in: app); try click(item("open-sample", app)); try searchOriginal(app)
        XCTAssertFalse(item("professional-reader-title", app).exists)
        let rail = item("professional-reader-tool-rail", app), canvas = item("pdf-canvas", app)
        XCTAssertGreaterThanOrEqual(rail.frame.minX, canvas.frame.maxX - 1)
        let collapsed = rail.frame.width
        try click(item("reader-rail-toggle", app)); XCTAssertGreaterThan(rail.frame.width, collapsed)
        try capture("R-01-pdf-expanded", app: app)
        try click(item("reader-notes", app)); XCTAssertFalse(item("reader-navigation-panel", app).exists)
        let draft = item("note-input", app); try click(draft); pasteOriginal("Right rail original draft 日本語 cafe\u{301}", app: app)
        try click(item("reader-navigation", app)); XCTAssertFalse(item("reader-notes-panel", app).exists)
        try click(item("reader-notes", app)); XCTAssertFalse(item("reader-navigation-panel", app).exists)
        value(draft, equals: "Right rail original draft 日本語 cafe\u{301}")
        try click(item("close-notes", app)); try click(item("reader-rail-toggle", app))
        XCTAssertEqual(rail.frame.width, collapsed)
        try capture("R-02-pdf-collapsed", app: app)
    }
    @MainActor func testPDFWheelUpdatesPageAndReopenRestoresPosition() throws {
        let app = try originalApp(width: 1280, dark: false); defer { app.terminate() }
        navigateWorkspace("open-sample", in: app); try click(item("open-sample", app)); contains(item("page-position", app), "1 / 2")
        item("pdf-canvas", app).scroll(byDeltaX: 0, deltaY: -1600)
        contains(item("page-position", app), "2 / 2")
        try capture("R-03-pdf-wheel-page2", app: app)
        try click(item("previous-page", app)); contains(item("page-position", app), "1 / 2")
        try click(item("next-page", app)); contains(item("page-position", app), "2 / 2")
        app.terminate();app.launch();app.activate()
        navigateWorkspace("library-book", in: app);try click(item("library-book", app));contains(item("page-position", app), "2 / 2")
    }
    @MainActor func testNarrowDarkRightPanelSelectionAndManualNoteSave() throws {
        let app = try originalApp(width: 720, dark: true); defer { app.terminate() }
        navigateWorkspace("open-sample", in: app); try click(item("open-sample", app)); try searchOriginal(app)
        try click(item("reader-notes", app));let draft=item("note-input", app)
        try click(draft);pasteOriginal("Narrow original saved note",app:app)
        try click(item("save-note", app));contains(item("saved-note-user-text",app),"Narrow original saved note")
        try click(item("reader-navigation",app));XCTAssertFalse(item("reader-notes-panel",app).exists)
        try click(item("reader-notes",app));XCTAssertFalse(item("reader-navigation-panel",app).exists)
        try capture("R-04-narrow-dark-note",app:app)
        try click(item("return-to-source",app));contains(item("page-position",app),"1 / 2")
    }
    @MainActor func testEPUBContinuousWheelCrossesChapterAndPositionSurvivesRestart() throws {
        let app=try originalApp(width:1280,dark:false);defer{app.terminate()}
        navigateWorkspace("open-epub-sample",in:app);try click(item("open-epub-sample",app));contains(item("epub-position",app),"第 1 章")
        XCTAssertFalse(item("professional-reader-title",app).exists)
        app.webViews.firstMatch.scroll(byDeltaX:0,deltaY:-9000);contains(item("epub-position",app),"第 2 章")
        try capture("R-05-epub-continuous-chapter2",app:app)
        try click(item("epub-contents",app));try click(item("epub-chapter-0",app));contains(item("epub-position",app),"第 1 章")
        try click(item("epub-contents",app));try click(item("epub-chapter-1",app));contains(item("epub-position",app),"第 2 章")
        app.terminate();app.launch();app.activate();navigateWorkspace("library-book",in:app);try click(item("library-book",app));contains(item("epub-position",app),"第 2 章")
    }
    @MainActor func testEPUBOrientationAndNarrowPanelKeepActualSource() throws {
        let app=try originalApp(width:720,dark:true);defer{app.terminate()}
        navigateWorkspace("open-epub-sample",in:app);try click(item("open-epub-sample",app));contains(item("epub-position",app),"第 1 章")
        try click(item("epub-orientation",app));contains(item("epub-position",app),"竖排")
        try capture("R-06-epub-narrow-vertical",app:app)
        try click(item("epub-orientation",app));contains(item("epub-position",app),"第 1 章")
        try click(item("epub-contents",app));try click(item("epub-notes",app));XCTAssertFalse(item("reader-navigation-panel",app).exists)
        try capture("R-07-epub-narrow-notes",app:app)
        try click(item("epub-close-notes",app));XCTAssertFalse(item("reader-notes-panel",app).exists)
    }
    @MainActor func testTwoNativeDocumentTabsKeepTheirOwnSelectionAndDraft() throws {
        let app=try originalApp(width:1280,dark:false);defer{app.terminate()}
        navigateWorkspace("open-sample",in:app);try click(item("open-sample",app));try searchOriginal(app);try click(item("reader-notes",app))
        try click(item("note-input",app));pasteOriginal("PDF independent original draft",app:app)
        let tabs=app.buttons.matching(NSPredicate(format:"identifier BEGINSWITH 'document-tab-' AND NOT identifier BEGINSWITH 'document-tab-close-'"))
        XCTAssertEqual(tabs.count,1);let pdfID=tabs.firstMatch.identifier
        try click(item("workspace-back-library",app));navigateWorkspace("open-epub-sample",in:app);try click(item("open-epub-sample",app))
        contains(item("epub-position",app),"第 1 章")
        let paragraph=try originalWebText("window",app:app);paragraph.coordinate(withNormalizedOffset:CGVector(dx:0.03,dy:0.1)).doubleClick()
        try click(item("epub-notes",app));contains(item("epub-selection",app),"window")
        try click(item("epub-note-input",app));pasteOriginal("EPUB independent original draft",app:app)
        XCTAssertEqual(tabs.count,2);let epubID=tabs.allElementsBoundByIndex.first { $0.identifier != pdfID }!.identifier
        try click(item(pdfID,app));value(item("note-input",app),equals:"PDF independent original draft")
        try click(item(epubID,app));value(item("epub-note-input",app),equals:"EPUB independent original draft")
        try capture("R-08-two-native-document-drafts",app:app)
    }

}
#endif
