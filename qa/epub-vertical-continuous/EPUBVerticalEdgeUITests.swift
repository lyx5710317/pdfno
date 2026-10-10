// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import XCTest
import AppKit
import CoreGraphics

/// Added only to the guarded local QA project. Never launches the product bundle.
final class EPUBVerticalEdgeUITests: XCTestCase {
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


    @MainActor private func pdfViewport(_ app: XCUIApplication) throws -> XCUIElement {
        // PDFKit exposes the actual native scroll view through its document child,
        // rather than the representable's private NSView identifier.
        let views = app.scrollViews.allElementsBoundByIndex.filter {
            $0.frame.width > 120 && $0.frame.height > 120 &&
            $0.children(matching: .any).matching(NSPredicate(format: "label == %@", "document")).firstMatch.exists
        }
        XCTAssertEqual(views.count, 1, "Use the unique native PDF document scroller")
        return try XCTUnwrap(views.first)
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
    @MainActor private func importComic(_ app: XCUIApplication) throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-Edge-Original-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root,withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let file=root.appendingPathComponent("Original Edge Comic.cbz")
        try originalZIP(try (0..<7).map { ("page-\($0).png",try originalPNG(width: 120,height: 200)) }).write(to: file)
        try click(item("document-add",app))
        let open=app.buttons["OKButton"].firstMatch;XCTAssertTrue(open.waitForExistence(timeout: 10))
        let panel=[app.dialogs,app.sheets,app.windows].lazy.map { $0.containing(.button,identifier: "OKButton").firstMatch }.first { $0.exists } ?? app
        app.typeKey("g",modifierFlags: [.command,.shift]);let input=panel.textFields["PathTextField"].firstMatch
        try click(input);app.typeKey("a",modifierFlags: .command);pasteOriginal(file.path,app: app);XCTAssertEqual(input.value as? String,file.path)
        let predicate=NSPredicate(format: "label == %@ OR value == %@",file.lastPathComponent,file.lastPathComponent)
        let completion = try XCTUnwrap([XCUIElement.ElementType.cell,.tableRow,.outlineRow].lazy.flatMap {
            panel.descendants(matching: $0).containing(predicate).allElementsBoundByIndex
        }.first { $0.exists && $0.isHittable && !$0.frame.isEmpty })
        completion.doubleClick();if open.exists { try click(open) }
        contains(item("comic-position",app),"1 / 7")
    }
    @MainActor private func comicSetting(_ title: String, app: XCUIApplication) throws {
        try click(item("comic-settings",app))
        if ["单页","双页","从右到左","从左到右"].contains(title) {
            let label = title.hasPrefix("从") ? "阅读方向" : "页面布局"
            let picker = item(title.hasPrefix("从") ? "comic-direction" : "comic-layout",app)
            if picker.exists && picker.isHittable { try click(picker) }
            else { try click(app.menuItems[label].firstMatch) }
        }
        try click(app.menuItems[title].firstMatch)
    }
    @MainActor private func edge(_ x: CGFloat, app: XCUIApplication) throws -> OwnComicPoint {
        let marker=item("comic-content",app);XCTAssertTrue(marker.waitForExistence(timeout: 15))
        let window=app.windows.firstMatch, bounds=window.frame
        let candidates=app.webViews.allElementsBoundByIndex + app.descendants(matching: .any).matching(identifier: "comic-content").allElementsBoundByIndex
        let canvas=try XCTUnwrap(candidates.first {
            let f=$0.frame
            return $0.exists && f.width>100 && f.height>100 && f.minX.isFinite && f.minY.isFinite && f.maxX.isFinite && f.maxY.isFinite && bounds.contains(f)
        },"Actual comic WebKit viewport must have finite bounds inside this fixture window")
        print("OWN_COMIC_VIEWPORT",canvas.elementType.rawValue,canvas.frame)
        let f=canvas.frame,point=CGPoint(x: f.minX+f.width*x,y: f.minY+f.height*0.5)
        let front=try XCTUnwrap(NSWorkspace.shared.frontmostApplication)
        XCTAssertEqual(front.bundleIdentifier,ProcessInfo.processInfo.environment["PDFNO_A_QA_EXPECTED_BUNDLE"])
        return OwnComicPoint(point: point,bundle: try XCTUnwrap(front.bundleIdentifier),pid: front.processIdentifier)

    }
    @MainActor private struct OwnComicPoint {
        let point: CGPoint, bundle: String, pid: pid_t
        private static let admittedDisplay = CGMainDisplayID()
        private func admit(_ position: CGPoint) throws {
            let front=NSWorkspace.shared.frontmostApplication
            let windows=CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String: Any]] ?? []
            let ownsPoint=windows.contains { record in
                guard record[kCGWindowOwnerPID as String] as? Int == Int(pid),record[kCGWindowLayer as String] as? Int == 0,
                      let value=record[kCGWindowBounds as String] as? NSDictionary,
                      let rect=CGRect(dictionaryRepresentation: value) else { return false }
                return rect.contains(position)
            }
            guard position.x.isFinite,position.y.isFinite,front?.processIdentifier == pid,front?.bundleIdentifier == bundle,
                  bundle == ProcessInfo.processInfo.environment["PDFNO_A_QA_EXPECTED_BUNDLE"],ownsPoint,
                  CGMainDisplayID() == Self.admittedDisplay,CGDisplayIsActive(Self.admittedDisplay) != 0,
                  CGDisplayIsAsleep(Self.admittedDisplay) == 0 else {
                print("EXPERIENCE_DESKTOP_CHANGED native comic input stopped; no activation")
                XCTFail("Own comic window/display/input boundary changed");throw NSError(domain: "OwnComicInput",code: 1)
            }
        }
        private func pause(_ seconds: Double) { RunLoop.current.run(until: Date().addingTimeInterval(seconds)) }
        private func request(_ kind: String,end: CGPoint?=nil,duration: Double=0) throws {
            try admit(point);if let end { try admit(end) }
            let token=try XCTUnwrap(ProcessInfo.processInfo.environment["PDFNO_A_QA_SHOT_TOKEN"]),nonce=UUID().uuidString
            XCTAssertNotNil(UUID(uuidString: token))
            let directory=FileManager.default.temporaryDirectory.appendingPathComponent("PDFno-A-WindowShots-"+token)
            try FileManager.default.createDirectory(at: directory,withIntermediateDirectories: true)
            let ack=directory.appendingPathComponent("mouse-"+nonce+".ack.json")
            XCTAssertFalse(FileManager.default.fileExists(atPath: ack.path))
            let window=try XCTUnwrap((CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String: Any]])?.first { r in
                guard r[kCGWindowOwnerPID as String] as? Int == Int(pid),r[kCGWindowLayer as String] as? Int == 0,
                      let raw=r[kCGWindowBounds as String] as? NSDictionary,let rect=CGRect(dictionaryRepresentation: raw) else { return false }
                return rect.contains(point)
            })
            var payload: [String: Any]=["kind":kind,"x":point.x,"y":point.y,"bundle":bundle,"pid":Int(pid),"window":window[kCGWindowNumber as String]!,"display":Self.admittedDisplay,"nonce":nonce,"token":token,"ack":ack.path]
            if let end { payload["endX"]=end.x;payload["endY"]=end.y;payload["duration"]=duration }
            let data=try JSONSerialization.data(withJSONObject: payload,options: [.sortedKeys])
            print("PDFNO_OWN_COMIC_MOUSE "+String(decoding: data,as: UTF8.self));fflush(stdout)
            let deadline=Date().addingTimeInterval(10)
            while !FileManager.default.fileExists(atPath: ack.path) && Date()<deadline { pause(0.03) }
            let result=try JSONSerialization.jsonObject(with: Data(contentsOf: ack)) as? [String: Any]
            XCTAssertEqual(result?["nonce"] as? String,nonce);XCTAssertEqual(result?["passed"] as? Bool,true)
            try admit(point)
        }
        func click() throws { try request("click") }
        func doubleClick() throws { try request("double") }
        func press(forDuration duration: Double,thenDragTo destination: OwnComicPoint) throws {
            guard destination.pid == pid && destination.bundle == bundle else { throw NSError(domain: "OwnComicInput",code: 3) }
            try request("drag",end: destination.point,duration: duration)
        }
    }
    @MainActor func testVerticalWheelCrossesPagesChaptersAndReopensInVertical() throws {
        let app=try originalApp(width: 1280,dark: false);defer { app.terminate() }
        navigateWorkspace("open-epub-sample",in: app);try click(item("open-epub-sample",app));contains(item("epub-position",app),"第 1 章")
        try click(item("epub-orientation",app));contains(item("epub-position",app),"竖排")
        try capture("V-01-wide-vertical-start",app: app)
        app.webViews.firstMatch.scroll(byDeltaX: 0,deltaY: -1100)
        let firstPage=item("epub-position",app)
        let advanced=expectation(for: NSPredicate { _,_ in let text=firstPage.label+" "+(firstPage.value as? String ?? "");return text.contains("第 1 章") && text.contains("竖排") && !text.contains("第 1 页") },evaluatedWith: app)
        wait(for: [advanced],timeout: 15)
        try capture("V-02-wide-vertical-page2",app: app)
        app.webViews.firstMatch.scroll(byDeltaX: 0,deltaY: -22000);contains(firstPage,"第 2 章");contains(firstPage,"竖排")
        try capture("V-03-wide-vertical-japanese",app: app)
        try click(item("epub-contents",app));try click(item("epub-chapter-0",app));contains(firstPage,"第 1 章");contains(firstPage,"竖排")
        try click(item("epub-contents",app));try click(item("epub-chapter-1",app));contains(firstPage,"第 2 章");contains(firstPage,"竖排")
        app.webViews.firstMatch.scroll(byDeltaX: 0,deltaY: -900)
        app.terminate();app.launch();app.activate();navigateWorkspace("library-list-layout",in: app);navigateWorkspace("library-epub",in: app);try click(item("library-epub",app))
        contains(item("epub-position",app),"第 2 章");contains(item("epub-position",app),"竖排")
        try capture("V-04-wide-vertical-reopened",app: app)
    }
    @MainActor func testNarrowDarkVerticalRetainsSelectionDraftAndSavedNoteSource() throws {
        let app=try originalApp(width: 720,dark: true);defer { app.terminate() }
        navigateWorkspace("open-epub-sample",in: app);try click(item("open-epub-sample",app));contains(item("epub-position",app),"第 1 章")
        let paragraph=try originalWebText("window",app: app);paragraph.coordinate(withNormalizedOffset: CGVector(dx: 0.03,dy: 0.1)).doubleClick()
        try click(item("epub-orientation",app));contains(item("epub-position",app),"竖排")
        try click(item("epub-notes",app));contains(item("epub-selection",app),"window")
        let input=item("epub-note-input",app);try click(input);pasteOriginal("Original vertical note 日本語",app: app)
        try click(item("epub-orientation",app));contains(item("epub-selection",app),"window");value(input,equals: "Original vertical note 日本語")
        try click(item("epub-orientation",app));contains(item("epub-position",app),"竖排");contains(item("epub-selection",app),"window");value(input,equals: "Original vertical note 日本語")
        try capture("V-05-narrow-dark-vertical-draft",app: app)
        try click(item("epub-save-note",app));contains(item("epub-saved-user-text",app),"Original vertical note 日本語")
        try click(item("epub-close-notes",app));try click(item("epub-contents",app));try click(item("epub-chapter-1",app));contains(item("epub-position",app),"第 2 章")
        try click(item("epub-notes",app));try reveal(item("epub-return",app),in: "epub-notes-list",app: app);try click(item("epub-return",app));waitForRemoval(item("reader-notes-panel",app))
        contains(item("epub-position",app),"第 1 章");contains(item("epub-position",app),"竖排")
        try capture("V-06-narrow-dark-return-source",app: app)
    }
    @MainActor func testComicLTRAndRTLCanvasEdgesPreserveSingleAndDoublePageModes() throws {
        let app=try originalApp(width: 1280,dark: false);defer { app.terminate() };try importComic(app)
        try comicSetting("单页",app: app)
        try edge(0.01,app: app).click();contains(item("comic-position",app),"1 / 7")
        try edge(0.99,app: app).click();contains(item("comic-position",app),"2 / 7")
        try edge(0.01,app: app).click();contains(item("comic-position",app),"1 / 7")
        try comicSetting("双页",app: app)
        try edge(0.99,app: app).click();contains(item("comic-position",app),"2–3 / 7")
        try capture("C-01-wide-double-ltr",app: app)
        try comicSetting("从右到左",app: app)
        try edge(0.01,app: app).click();contains(item("comic-position",app),"4–5 / 7")
        try edge(0.99,app: app).click();contains(item("comic-position",app),"2–3 / 7")
        try comicSetting("单页",app: app)
        try edge(0.01,app: app).click();contains(item("comic-position",app),"3 / 7")
        try capture("C-02-wide-single-rtl",app: app)
        try comicSetting("下一页",app: app);contains(item("comic-position",app),"4 / 7")
        try comicSetting("上一页",app: app);contains(item("comic-position",app),"3 / 7")
    }
    @MainActor func testComicDragDoubleClickCenterAndToolPanelNeverTurn() throws {
        let app=try originalApp(width: 720,dark: true);defer { app.terminate() };try importComic(app)
        try comicSetting("单页",app: app)
        try edge(0.99,app: app).press(forDuration: 0.2,thenDragTo: edge(0.8,app: app))
        try edge(0.99,app: app).doubleClick()
        try edge(0.5,app: app).click()
        let until=Date().addingTimeInterval(1);while Date()<until { RunLoop.current.run(until: Date().addingTimeInterval(0.05)) }
        contains(item("comic-position",app),"1 / 7")
        try click(item("comic-pages",app));try click(item("comic-page-2",app));contains(item("comic-position",app),"3 / 7")
        try edge(0.99,app: app).click();contains(item("comic-position",app),"4 / 7")
        try capture("C-03-narrow-dark-edge",app: app)
    }
}
#endif
