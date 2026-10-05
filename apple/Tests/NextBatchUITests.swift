// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest
import CryptoKit
import AppKit

/// Compile locally; execute only in isolated CI/VM/OS user with explicit scope.
/// UUID stores and intercepted transport do not isolate an existing app process.
final class NextBatchUITests: XCTestCase {
    @MainActor private func element(_ id: String, _ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }
    @MainActor private func click(_ item: XCUIElement) {
        if !item.exists { XCTAssertTrue(item.waitForExistence(timeout: 10)) }
        if !item.isEnabled || !item.isHittable {
            let ready = expectation(for: NSPredicate { _, _ in item.exists && item.isEnabled && item.isHittable }, evaluatedWith: item)
            wait(for: [ready], timeout: 10)
        }
        XCTAssertTrue(item.exists && item.isEnabled && item.isHittable)
        item.click()
    }
    @MainActor private func text(_ item: XCUIElement, contains value: String) {
        let ready = expectation(for: NSPredicate { _, _ in
            item.exists && (item.label + " " + (item.value as? String ?? "")).contains(value)
        }, evaluatedWith: item)
        wait(for: [ready], timeout: 15)
    }
    @MainActor private func reveal(_ item: XCUIElement, form: String, app: XCUIApplication) {
        let scroll = app.scrollViews[form].firstMatch
        if !scroll.exists { XCTAssertTrue(scroll.waitForExistence(timeout: 10)) }
        if !item.exists { XCTAssertTrue(item.waitForExistence(timeout: 10)) }
        XCTAssertTrue(scroll.exists && item.exists)
        for _ in 0..<12 {
            let viewport = scroll.frame.insetBy(dx: 4, dy: 8), target = item.frame
            if !target.isEmpty, viewport.contains(target), item.isHittable { return }
            let delta: CGFloat = target.minY < viewport.minY
                ? min(280, max(48, viewport.minY - target.minY + 16))
                : -min(280, max(48, target.maxY - viewport.maxY + 16))
            scroll.scroll(byDeltaX: 0, deltaY: delta)
        }
        XCTAssertTrue(scroll.frame.insetBy(dx: 4, dy: 8).contains(item.frame))
        XCTAssertTrue(item.isHittable)
    }
    private func cleanup(_ url: URL) {
        do { try FileManager.default.removeItem(at: url) }
        catch { print("Synthetic UI cleanup retained \(url.lastPathComponent): \(error.localizedDescription)") }
    }
    @MainActor private func pastePath(_ value: String, into field: XCUIElement) {
        let board = NSPasteboard.general
        let previous = (board.pasteboardItems ?? []).map { item in
            let copy = NSPasteboardItem()
            for type in item.types { if let bytes = item.data(forType: type) { copy.setData(bytes, forType: type) } }
            return copy
        }
        board.clearContents(); board.setString(value, forType: .string); let change = board.changeCount
        defer { if board.changeCount == change { board.clearContents(); board.writeObjects(previous) } }
        field.typeKey("a", modifierFlags: .command); field.typeKey("v", modifierFlags: .command)
        XCTAssertEqual(field.value as? String, value)
    }
    @MainActor private func chooseDirectory(_ url: URL, trigger: XCUIElement, app: XCUIApplication) throws {
        click(trigger)
        let open = app.buttons["OKButton"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        app.typeKey("g", modifierFlags: [.command, .shift])
        let path = app.textFields["PathTextField"].firstMatch; click(path)
        pastePath(url.path, into: path)
        XCTAssertEqual(path.value as? String, url.path)
        for _ in 0..<2 {
            if !path.exists || !path.isHittable { break }
            app.typeKey(.return, modifierFlags: [])
            let dismissed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !path.exists || !path.isHittable }, object: app)
            if XCTWaiter.wait(for: [dismissed], timeout: 5) == .completed { break }
        }
        XCTAssertFalse(path.exists && path.isHittable)
        if open.exists { click(open) }
    }
    @MainActor private func confirmInitialDirectory(_ url: URL, trigger: XCUIElement, app: XCUIApplication) {
        click(trigger)
        let open = app.buttons["OKButton"].firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 10))
        let location = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "初始位置：" + url.resolvingSymlinksInPath().path)).firstMatch
        XCTAssertTrue(location.waitForExistence(timeout: 10), "The real folder panel must show the previously selected location")
        click(open)
    }
    private func verifyPackage(_ package: URL) throws {
        let inventory = try state("inventory-v1.json", root: package)
        let entries = try XCTUnwrap(inventory["entries"] as? [[String: Any]])
        XCTAssertFalse(entries.isEmpty)
        for entry in entries {
            let path = try XCTUnwrap(entry["path"] as? String)
            XCTAssertFalse(path.contains("..")); XCTAssertFalse(path.hasPrefix("/"))
            let bytes = try Data(contentsOf: package.appendingPathComponent("Payload").appendingPathComponent(path))
            XCTAssertEqual(bytes.count, entry["byteLength"] as? Int)
            XCTAssertEqual(SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined(), entry["sha256"] as? String)
            XCTAssertFalse(path.contains("edit-drafts")); XCTAssertFalse(path.contains("Keychain"))
        }
    }
    private func state(_ file: String, root: URL) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(file))) as? [String: Any])
    }
    @MainActor private func fixture(_ app: XCUIApplication, token: String) {
        app.launchEnvironment["PDFNO_UI_TEST_SESSION"] = token
        app.launchEnvironment["PDFNO_UI_TEST_DEEPSEEK"] = "offline"
        app.launch(); app.activate()
        click(app.buttons["open-sample"].firstMatch)
        text(element("page-position", app), contains: "1 / 2")
    }
    @MainActor func testEnglishManualConsentSaveSearchAndRestartKeepsSourceAndNoKey() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        let root = URL(fileURLWithPath: "/tmp/PDFno-UITests-" + token)
        fixture(app, token: token); defer { app.terminate(); cleanup(root) }
        click(app.buttons["reader-navigation"].firstMatch)
        let search = app.textFields["search-input"].firstMatch; click(search); search.typeText("window")
        click(app.buttons["search-submit"].firstMatch); click(app.buttons["search-result"].firstMatch)
        click(app.buttons["reader-english-learning"].firstMatch)
        XCTAssertTrue(element("english-offline-fixture", app).waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["english-learning-start"].firstMatch.isEnabled)
        click(app.buttons["english-learning-close"].firstMatch)
        click(app.buttons["ai-settings"].firstMatch); click(app.buttons["ai-use-deepseek"].firstMatch)
        let key = app.secureTextFields["ai-session-key"].firstMatch
        reveal(key, form: "ai-settings-form", app: app); click(key); key.typeText("synthetic-reading-ui-credential")
        click(app.buttons["ai-settings-save"].firstMatch)
        click(app.buttons["reader-english-learning"].firstMatch)
        text(element("english-learning-fixed-source", app), contains: "window")
        let consent = element("english-learning-confirm", app), start = app.buttons["english-learning-start"].firstMatch
        reveal(consent, form: "english-learning-form", app: app); click(consent)
        reveal(start, form: "english-learning-form", app: app); click(start)
        text(element("english-learning-status", app), contains: "可审阅建议")
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("english-learning-v1.json").path))
        let input = element("english-learning-user-text", app)
        reveal(input, form: "english-learning-form", app: app)
        // Native macOS TextView does not report button-like AX enabled state.
        // Keep viewport/hit checks and prove the actual editor value and stored body.
        input.coordinate(withNormalizedOffset: CGVector(dx: 0.12, dy: 0.15)).click()
        input.typeText("Original English UI saved marker")
        XCTAssertEqual(input.value as? String, "Original English UI saved marker")
        let save = app.buttons["english-learning-save"].firstMatch
        reveal(save, form: "english-learning-form", app: app); click(save)
        text(element("english-learning-status", app), contains: "已保存")
        let bytes = try Data(contentsOf: root.appendingPathComponent("english-learning-v1.json"))
        let saved = try XCTUnwrap((try state("english-learning-v1.json", root: root)["notes"] as? [[String: Any]])?.first)
        XCTAssertEqual(saved["userText"] as? String, "Original English UI saved marker")
        XCTAssertFalse(String(decoding: bytes, as: UTF8.self).contains("synthetic-reading-ui-credential"))
        click(app.buttons["english-learning-close"].firstMatch); click(app.buttons["library-search"].firstMatch)
        let global = app.textFields["library-search-input"].firstMatch; click(global); global.typeText("Original English UI saved marker")
        text(element("library-search-status", app), contains: "找到 1 项")
        click(app.buttons["record-search-source"].firstMatch)
        text(element("page-position", app), contains: "1 / 2")
        app.terminate(); app.launch(); app.activate()
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("english-learning-v1.json")), bytes)
        click(element("library-book", app))
        click(app.buttons["reader-navigation"].firstMatch)
        let repeatSearch = app.textFields["search-input"].firstMatch; click(repeatSearch); repeatSearch.typeText("window")
        click(app.buttons["search-submit"].firstMatch); click(app.buttons["search-result"].firstMatch)
        click(app.buttons["reader-english-learning"].firstMatch)
        text(element("english-learning-fixed-source", app), contains: "window")
        XCTAssertFalse(app.buttons["english-learning-start"].firstMatch.isEnabled, "Session credential must not survive restart")
    }
    @MainActor func testTrashConfirmationRestoreAndRestartPreserveOriginalBook() throws {
        let app = XCUIApplication(), token = UUID().uuidString
        let root = URL(fileURLWithPath: "/tmp/PDFno-UITests-" + token)
        fixture(app, token: token); defer { app.terminate(); cleanup(root) }
        let before = try state("library-v1.json", root: root)
        let book = try XCTUnwrap((before["books"] as? [[String: Any]])?.first), id = try XCTUnwrap(book["id"] as? String)
        let hash = try XCTUnwrap(book["fileSHA256"] as? String)
        let original = root.appendingPathComponent("Originals/" + hash + ".pdf"), bytes = try Data(contentsOf: original)
        click(app.buttons["library-local-recovery"].firstMatch)
        let remove = app.buttons["local-recovery-trash-" + id].firstMatch
        reveal(remove, form: "local-recovery-form", app: app); click(remove)
        XCTAssertEqual((try state("library-v1.json", root: root)["books"] as? [[String: Any]])?.count, 1)
        click(app.buttons["local-recovery-cancel-change"].firstMatch)
        click(remove); click(app.buttons["local-recovery-confirm-change"].firstMatch)
        text(element("local-recovery-status", app), contains: "已移至")
        XCTAssertEqual((try state("library-v1.json", root: root)["books"] as? [[String: Any]])?.count, 0)
        XCTAssertEqual(try Data(contentsOf: original), bytes)
        let restore = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'local-recovery-restore-'")).firstMatch
        reveal(restore, form: "local-recovery-form", app: app); click(restore)
        click(app.buttons["local-recovery-confirm-change"].firstMatch)
        text(element("local-recovery-status", app), contains: "已恢复")
        print("Synthetic recovery checkpoint: restore completed; reading current manifest")
        XCTAssertEqual((try state("library-v1.json", root: root)["books"] as? [[String: Any]])?.first?["id"] as? String, id)
        XCTAssertEqual(try Data(contentsOf: original), bytes)
        print("Synthetic recovery checkpoint: original bytes preserved; creating runner-owned backup parent")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Directory-UI-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { cleanup(directory) }
        let currentManifest = try Data(contentsOf: root.appendingPathComponent("library-v1.json"))
        let export = app.buttons["local-recovery-export"].firstMatch
        reveal(export, form: "local-recovery-form", app: app)
        try chooseDirectory(directory, trigger: export, app: app)
        text(element("local-recovery-status", app), contains: "已导出并校验")
        let package = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("PDFnoBackup-") })
        try verifyPackage(package)
        print("Synthetic recovery checkpoint: exported inventory and payload SHA256 verified")
        XCTAssertEqual(try Data(contentsOf: package.appendingPathComponent("Payload/library-v1.json")), currentManifest)
        let inspect = app.buttons["local-recovery-inspect"].firstMatch
        reveal(inspect, form: "local-recovery-form", app: app)
        confirmInitialDirectory(package, trigger: inspect, app: app)
        text(element("local-recovery-status", app), contains: "备份预检通过")
        let restorePackage = app.buttons["local-recovery-restore-package"].firstMatch
        reveal(restorePackage, form: "local-recovery-form", app: app)
        confirmInitialDirectory(directory, trigger: restorePackage, app: app)
        text(element("local-recovery-status", app), contains: "已恢复到新目录")
        let recovered = try XCTUnwrap(FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .first { $0.lastPathComponent.hasPrefix("PDFnoRecovered-") })
        XCTAssertEqual(try Data(contentsOf: recovered.appendingPathComponent("library-v1.json")), currentManifest)
        XCTAssertEqual(try Data(contentsOf: recovered.appendingPathComponent("Originals/" + hash + ".pdf")), bytes)
        XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent("library-v1.json")), currentManifest)
        XCTAssertFalse(FileManager.default.fileExists(atPath: recovered.appendingPathComponent("note-edit-drafts-v1.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: recovered.appendingPathComponent("record-edit-drafts-v1.json").path))
        print("Synthetic recovery checkpoint: new-root restoration and unchanged active library verified")
        click(app.buttons["local-recovery-close"].firstMatch)
        app.terminate(); app.launch(); app.activate(); click(element("library-book", app))
        text(element("page-position", app), contains: "1 / 2")
    }
}
#endif
