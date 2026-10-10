// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest
import AppKit

/// Installed only in a unique guarded QA snapshot. Standard XCTest input only.
final class AnchoredAnnotationUITests: XCTestCase {
    @MainActor private func item(_ id: String,_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    @MainActor private func click(_ e: XCUIElement) throws {
        let ready=expectation(for: NSPredicate { _,_ in e.exists && e.isEnabled && e.isHittable },evaluatedWith: e)
        wait(for: [ready],timeout: 15);XCTAssertTrue(e.exists && e.isEnabled && e.isHittable)
        guard e.exists && e.isEnabled && e.isHittable else { throw NSError(domain: "OriginalAnnotationQA",code: 1) };e.click()
    }
    @MainActor private func app(_ width: Int,dark: Bool) throws -> XCUIApplication {
        let bundle=try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_EXPECTED_BUNDLE"])
        XCTAssertEqual(bundle,ProcessInfo.processInfo.environment["PDFNO_ISOLATED_UI_APPLICATION_ID"])
        XCTAssertTrue(bundle.hasPrefix("org.pdfno.integration.professionala20261007.qa"))
        let app=XCUIApplication(bundleIdentifier: bundle)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"]=UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"]="offline"
        app.launchEnvironment["PDFNO_A_QA_SCOPE"]="a-regression"
        app.launchEnvironment["PDFNO_A_QA_WIDTH"]=String(width)
        app.launchEnvironment["PDFNO_A_QA_HEIGHT"]=width==720 ? "520" : "800"
        app.launchEnvironment["PDFNO_A_QA_APPEARANCE"]=dark ? "dark" : "light"
        app.launch();app.activate()
        try click(item("workspace-help",app));try click(item("open-epub-sample",app))
        XCTAssertTrue(item("epub-content",app).waitForExistence(timeout: 20))
        return app
    }
    @MainActor private func selectOriginal(_ app: XCUIApplication) throws {
        var paragraph: XCUIElement?
        let found=expectation(for: NSPredicate { _,_ in
            paragraph=app.webViews.firstMatch.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@","window")).firstMatch
            if paragraph?.exists != true { paragraph=app.webViews.firstMatch.staticTexts.allElementsBoundByIndex.first { ($0.value as? String)?.hasPrefix("window")==true } }
            return paragraph?.exists==true
        },evaluatedWith: app)
        wait(for: [found],timeout: 20);let text=try XCTUnwrap(paragraph)
        XCTAssertTrue(text.isHittable)
        // Standard XCTest coordinate path. Stop on failure; never switch to CGEvent helpers.
        let point=text.coordinate(withNormalizedOffset: CGVector(dx: 0.03,dy: 0.1)),screen=point.screenPoint
        guard screen.x.isFinite && screen.y.isFinite else { XCTFail("Standard XCTest selection coordinate is invalid; no fallback input");throw NSError(domain: "OriginalAnnotationQA",code: 2) }
        point.doubleClick()
        XCTAssertTrue(item("selection-annotation-highlight",app).waitForExistence(timeout: 10))
        XCTAssertTrue(item("selection-annotation-underline",app).exists && item("selection-annotation-note",app).exists)
    }
    @MainActor private func rows(_ app: XCUIApplication) -> XCUIElementQuery {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'annotation-row-'"))
    }
    @MainActor private func paste(_ value: String,_ app: XCUIApplication,focus: Bool = true) throws {
        if focus { try click(item("annotation-comment-input",app)) }
        NSPasteboard.general.clearContents();NSPasteboard.general.setString(value,forType: .string)
        app.typeKey("v",modifierFlags: .command)
        let input=item("annotation-comment-input",app)
        let pasted=expectation(for: NSPredicate { _,_ in input.value as? String == value },evaluatedWith: input)
        wait(for: [pasted],timeout: 10);XCTAssertEqual(input.value as? String,value)
    }
    @MainActor private func shot(_ name: String,_ app: XCUIApplication) throws {
        let token=try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_SHOT_TOKEN"]);XCTAssertNotNil(UUID(uuidString: token))
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-A-WindowShots-"+token)
        try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
        let path=directory.appendingPathComponent(name+".png");try app.windows.firstMatch.screenshot().pngRepresentation.write(to: path)
        let bytes=try JSONSerialization.data(withJSONObject: ["name":name,"path":path.path],options: [.sortedKeys]);print("PDFNO_A_WINDOW_SHOT "+String(decoding: bytes,as: UTF8.self))
    }
    @MainActor func testWideFloatThreeActionsOneRowRightClickEditAndExactSource() throws {
        let app=try app(1280,dark: false);defer { app.terminate() }
        XCTAssertFalse(item("epub-orientation",app).exists)
        try selectOriginal(app);try shot("AN-01-wide-floating-tools",app)
        try click(item("selection-annotation-highlight",app));try click(item("epub-notes",app))
        XCTAssertTrue(item("annotation-list",app).waitForExistence(timeout: 10));XCTAssertEqual(rows(app).count,1)
        let originalID=rows(app).firstMatch.identifier
        try click(item("epub-close-notes",app));try selectOriginal(app);try click(item("selection-annotation-underline",app))
        try click(item("epub-notes",app));XCTAssertEqual(rows(app).count,1);XCTAssertEqual(rows(app).firstMatch.identifier,originalID)
        try click(item("epub-close-notes",app));try selectOriginal(app);try click(item("selection-annotation-note",app))
        let body=" 原创批注\nか\u{3099} 👩🏽‍🚀 e\u{301} ";try paste(body,app);try shot("AN-02-wide-comment-editor",app)
        try click(item("annotation-editor-save",app));try click(item("epub-notes",app))
        XCTAssertEqual(rows(app).count,1);XCTAssertEqual(rows(app).firstMatch.identifier,originalID)
        XCTAssertTrue(item("annotation-comment",app).waitForExistence(timeout: 10))
        rows(app).firstMatch.rightClick();try click(item("annotation-context-edit",app))
        try click(item("annotation-comment-input",app));app.typeKey("a",modifierFlags: .command);try paste("Cancelled original edit",app,focus: false)
        try click(item("annotation-editor-cancel",app));XCTAssertEqual(rows(app).count,1)
        try shot("AN-03-wide-annotation-list",app);try click(rows(app).firstMatch)
        let status=item("annotation-status",app);XCTAssertTrue(status.waitForExistence(timeout: 10));XCTAssertTrue((status.label+(status.value as? String ?? "")).contains("已定位原文"))
        try click(item("annotation-legacy-records",app));XCTAssertTrue(item("epub-notes-list",app).waitForExistence(timeout: 10))
    }
    @MainActor func testNarrowDarkNoteDraftCloseReopenPasteSaveAndRestart() throws {
        let app=try app(720,dark: true);defer { app.terminate() }
        XCTAssertLessThanOrEqual(app.windows.firstMatch.frame.width,760)
        try selectOriginal(app);try click(item("selection-annotation-note",app))
        let body=" 自制窄窗批注\n日本語 2026 cafe\u{301} ";try paste(body,app)
        try click(item("annotation-editor-close",app));try click(item("epub-notes",app))
        XCTAssertTrue(item("annotation-resume-draft",app).waitForExistence(timeout: 10));XCTAssertEqual(rows(app).count,0)
        try click(item("annotation-resume-draft",app));XCTAssertEqual(item("annotation-comment-input",app).value as? String,body)
        try shot("AN-04-narrow-dark-editor",app);try click(item("annotation-editor-save",app))
        XCTAssertEqual(rows(app).count,1);try shot("AN-05-narrow-dark-list",app)
        try click(rows(app).firstMatch);try click(item("epub-close-notes",app));app.terminate();app.launch();app.activate()
        try click(item("workspace-help",app));try click(item("open-epub-sample",app))
        XCTAssertTrue(item("epub-content",app).waitForExistence(timeout: 20));try click(item("epub-notes",app))
        XCTAssertEqual(rows(app).count,1);XCTAssertTrue(item("annotation-comment",app).exists)
        try shot("AN-06-narrow-dark-restarted",app)
    }
}
#endif
