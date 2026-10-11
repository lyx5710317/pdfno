// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import AppKit
import XCTest

final class ReaderConversationUITests: XCTestCase {
    @MainActor private func text(_ element: XCUIElement) -> String { (element.value as? String).flatMap { $0.isEmpty ? nil : $0 } ?? element.label }
    @MainActor private func item(_ id: String,_ app: XCUIApplication) -> XCUIElement {
        if ["settings-japanese-learning","settings-english-learning"].contains(id) { return app.checkBoxes.matching(identifier: id).firstMatch }
        return app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    @MainActor private func state(_ element: XCUIElement) -> String? {
        guard element.exists, element.elementType == .checkBox else { return nil }
        if let value = element.value as? String, ["0","1"].contains(value) { return value }
        if let value = element.value as? NSNumber, [0,1].contains(value.intValue) { return String(value.intValue) }
        return nil
    }
    @MainActor private func click(_ element: XCUIElement) throws {
        let ready = expectation(for: NSPredicate { _,_ in element.exists && element.isEnabled && element.isHittable },evaluatedWith: element)
        wait(for: [ready],timeout: 12)
        guard element.exists && element.isEnabled && element.isHittable else { throw NSError(domain: "OriginalConversationQA",code: 1) }; element.click()
    }
    @MainActor private func launch(_ width: Int) throws -> XCUIApplication {
        continueAfterFailure = false
        let bundle = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_EXPECTED_BUNDLE"])
        XCTAssertTrue(bundle.hasPrefix("org.pdfno.integration.professionala20261007.qa"))
        let app = XCUIApplication(bundleIdentifier: bundle)
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = UUID().uuidString
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launchEnvironment["PDFNO_A_QA_SCOPE"] = "a-regression"
        app.launchEnvironment["PDFNO_A_QA_WIDTH"] = String(width)
        app.launchEnvironment["PDFNO_A_QA_HEIGHT"] = width == 720 ? "520" : "800"
        app.launchEnvironment["PDFNO_A_QA_APPEARANCE"] = width == 720 ? "dark" : "light"
        app.launch(); app.activate(); return app
    }
    @MainActor private func open(_ sample: String,_ app: XCUIApplication) throws {
        try click(item("workspace-help",app)); try click(item(sample,app))
        XCTAssertTrue(item("epub-aa",app).waitForExistence(timeout: 25))
    }
    @MainActor private func category(_ id: String,title: String,_ app: XCUIApplication) throws {
        if item("settings-category-" + id,app).exists { try click(item("settings-category-" + id,app)) }
        else { try click(item("settings-category-picker",app)); try click(app.menuItems[title].firstMatch) }
    }
    @MainActor private func configureMock(_ app: XCUIApplication) throws {
        try category("ai",title: "AI",app)
        try click(item("ai-provider-mode",app)); try click(app.menuItems["本地示例"].firstMatch)
        try click(item("ai-settings-save",app)); try click(item("ai-connection-test",app))
        let status = item("ai-connection-status",app)
        let ready = expectation(for: NSPredicate { _,_ in status.exists && self.text(status).contains("未测试网络") },evaluatedWith: app)
        wait(for: [ready],timeout: 12)
    }
    @MainActor private func select(_ prefix: String,_ app: XCUIApplication) throws {
        var paragraph: XCUIElement?
        let ready = expectation(for: NSPredicate { _,_ in
            paragraph = app.webViews.firstMatch.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@",prefix)).firstMatch
            if paragraph?.exists != true { paragraph = app.webViews.firstMatch.staticTexts.allElementsBoundByIndex.first { ($0.value as? String)?.hasPrefix(prefix) == true } }
            return paragraph?.exists == true
        },evaluatedWith: app)
        wait(for: [ready],timeout: 15)
        let text = try XCTUnwrap(paragraph); XCTAssertTrue(text.isHittable)
        text.coordinate(withNormalizedOffset: CGVector(dx: 0.1,dy: 0.5)).doubleClick()
    }
    @MainActor private func task(_ task: String,_ app: XCUIApplication) throws {
        try click(item("selection-ai-menu",app)); try click(item("selection-ai-" + task,app))
        if task == "japanese" || task == "english" { try click(item("selection-ai-" + task + "-conversation",app)) }
        XCTAssertTrue(item("ai-close",app).waitForExistence(timeout: 15))
        XCTAssertFalse(item("selection-service",app).exists); XCTAssertFalse(item("ai-provider-mode",app).exists)
    }
    @MainActor private func answers(_ app: XCUIApplication) -> [XCUIElement] {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'ai-conversation-answer-'" )).allElementsBoundByIndex
    }
    @MainActor private func waitAnswers(_ count: Int,_ app: XCUIApplication) {
        let ready = expectation(for: NSPredicate { _,_ in self.answers(app).count == count && !self.item("ai-conversation-stop",app).exists },evaluatedWith: app)
        wait(for: [ready],timeout: 20)
    }
    @MainActor private func shot(_ name: String,_ app: XCUIApplication) throws {
        let token = try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_SHOT_TOKEN"]); XCTAssertNotNil(UUID(uuidString: token))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-A-WindowShots-" + token)
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        let path = root.appendingPathComponent(name + ".png")
        try app.windows.firstMatch.screenshot().pngRepresentation.write(to: path)
        let record = try JSONSerialization.data(withJSONObject: ["name": name,"path": path.path],options: [.sortedKeys])
        print("PDFNO_A_WINDOW_SHOT " + String(decoding: record,as: UTF8.self))
    }
    @MainActor func testWideConnectionFiveTasksDialogueStopRetryFollowupAndExplicitNotes() throws {
        let app = try launch(1280); defer { app.terminate() }
        try open("open-epub-sample",app)
        try click(item("ai-settings",app)); try category("ai",title: "AI",app)
        try click(item("ai-provider-mode",app)); try click(app.menuItems["OpenAI 兼容"].firstMatch)
        XCTAssertTrue(item("ai-endpoint",app).exists && item("ai-session-key",app).exists && item("ai-model",app).exists)
        XCTAssertFalse(item("ai-provider-label",app).exists)
        try shot("AI-00-unified-connection-fields",app); try configureMock(app)
        try category("aiTools",title: "AI工具",app)
        let japanese = item("settings-japanese-learning",app), english = item("settings-english-learning",app)
        XCTAssertEqual(state(japanese),"0"); XCTAssertEqual(state(english),"0")
        try click(japanese); try click(english)
        XCTAssertEqual(state(japanese),"1"); XCTAssertEqual(state(english),"1")
        try shot("AI-01-connection-independent-tools",app); try click(item("settings-return",app))
        try select("window",app); try task("explain",app)
        let stop = item("ai-conversation-stop",app); XCTAssertTrue(stop.waitForExistence(timeout: 5)); try click(stop)
        XCTAssertTrue(item("ai-conversation-retry",app).waitForExistence(timeout: 10)); XCTAssertEqual(answers(app).count,0)
        try shot("AI-02-stopped-fixed-source",app); try click(item("ai-conversation-retry",app)); waitAnswers(1,app)
        let first = try XCTUnwrap(answers(app).first), answerID = first.identifier.replacingOccurrences(of: "ai-conversation-answer-",with: "")
        try click(item("ai-conversation-source-toggle",app)); XCTAssertEqual(item("ai-conversation-source-toggle",app).value as? String,"已展开")
        XCTAssertTrue(item("ai-conversation-source",app).exists && item("ai-conversation-return",app).exists)
        try click(item("ai-conversation-copy-" + answerID,app)); XCTAssertEqual(item("ai-conversation-copy-" + answerID,app).label,"已复制")
        try click(item("ai-conversation-save-" + answerID,app))
        let saved = expectation(for: NSPredicate { _,_ in self.item("ai-conversation-save-" + answerID,app).label == "已加入笔记" },evaluatedWith: app)
        wait(for: [saved],timeout: 12); XCTAssertEqual(item("ai-conversation-save-" + answerID,app).label,"已加入笔记")
        let input = item("ai-conversation-input",app); try click(input); input.typeText("Original follow-up about this source")
        try click(item("ai-conversation-send",app)); waitAnswers(2,app)
        try shot("AI-03-wide-followup-explicit-save",app)
        try click(item("ai-close",app)); try click(item("epub-ai",app)); waitAnswers(2,app)
        XCTAssertTrue(item("ai-conversation-answer-" + answerID,app).exists)
        try shot("AI-04-rail-reconnects-same-dialogue",app); try click(item("epub-ai",app))
        for name in ["translate","summarize","english"] {
            try select("window",app); try task(name,app); waitAnswers(1,app)
            XCTAssertTrue(answers(app).first.map { text($0).contains("本地 mock") } == true)
            try click(item("ai-close",app))
        }
        try click(item("epub-contents",app)); try click(item("epub-chapter-1",app))
        let chapter = expectation(for: NSPredicate { _,_ in !self.item("epub-chapter-1",app).exists },evaluatedWith: app); wait(for: [chapter],timeout: 12)
        try select("日本語",app); try task("japanese",app); waitAnswers(1,app)
        let result = try XCTUnwrap(answers(app).first), japaneseID = result.identifier.replacingOccurrences(of: "ai-conversation-answer-",with: "")
        XCTAssertTrue(text(result).contains("日语学习示例"))
        try click(item("ai-conversation-save-" + japaneseID,app)); try shot("AI-05-japanese-original-source",app); try click(item("ai-close",app))
        try click(item("epub-notes",app)); XCTAssertTrue(item("annotation-list",app).waitForExistence(timeout: 12))
        XCTAssertTrue(app.staticTexts["AI 日语学习"].firstMatch.exists)
        try shot("AI-06-original-notes-task-type",app)
    }
    @MainActor func testNarrowIndependentSettingsDefaultOffAndRetainedDisabledConversation() throws {
        let app = try launch(720); defer { app.terminate() }
        try click(item("ai-settings",app)); try category("aiTools",title: "AI工具",app)
        XCTAssertEqual(state(item("settings-japanese-learning",app)),"0")
        XCTAssertEqual(state(item("settings-english-learning",app)),"0")
        XCTAssertFalse(item("settings-tools-source",app).exists)
        try shot("AI-07-narrow-tools-without-document",app)
        try configureMock(app); try category("aiTools",title: "AI工具",app); try click(item("settings-english-learning",app))
        try click(item("settings-return",app)); try open("open-epub-sample",app)
        try select("window",app); try task("english",app); waitAnswers(1,app)
        let result = try XCTUnwrap(answers(app).first), answerID = result.identifier.replacingOccurrences(of: "ai-conversation-answer-",with: "")
        try shot("AI-08-narrow-dark-dialogue",app); try click(item("ai-close",app))
        try click(item("ai-settings",app)); try category("aiTools",title: "AI工具",app); try click(item("settings-english-learning",app))
        XCTAssertEqual(state(item("settings-english-learning",app)),"0")
        try click(item("settings-return",app)); try click(item("epub-ai",app)); waitAnswers(1,app)
        XCTAssertTrue(item("ai-conversation-answer-" + answerID,app).exists && !item("ai-conversation-input",app).isEnabled)
        try click(item("ai-conversation-save-" + answerID,app)); try shot("AI-09-disabled-tool-answer-retained",app)
        try click(item("epub-ai",app)); try select("window",app); try click(item("selection-ai-menu",app))
        XCTAssertFalse(item("selection-ai-japanese",app).exists); XCTAssertFalse(item("selection-ai-english",app).exists)
        XCTAssertTrue(item("selection-ai-explain",app).exists && item("selection-ai-translate",app).exists && item("selection-ai-summarize",app).exists)
        app.typeKey(.escape,modifierFlags: [])
    }
}
#endif
