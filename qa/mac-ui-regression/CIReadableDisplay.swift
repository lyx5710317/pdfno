// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
// Dedicated ephemeral GitHub runner only. Never configure a developer's display.
import AppKit
import CoreGraphics
import Foundation
import Darwin

let environment = ProcessInfo.processInfo.environment
guard CommandLine.arguments == [CommandLine.arguments[0], "--configure-ci"],
      environment["GITHUB_ACTIONS"] == "true",
      environment["RUNNER_OS"] == "macOS",
      environment["RUNNER_ENVIRONMENT"] == "github-hosted",
      environment["GITHUB_REPOSITORY"] == "lyx5710317/pdfno",
      ((environment["GITHUB_EVENT_NAME"] == "push" &&
        (environment["GITHUB_REF"] ?? "").hasPrefix("refs/heads/")) ||
       (environment["GITHUB_EVENT_NAME"] == "pull_request" &&
        (environment["GITHUB_REF"] ?? "").hasPrefix("refs/pull/")) ||
       (environment["GITHUB_EVENT_NAME"] == "workflow_dispatch" &&
        environment["GITHUB_WORKFLOW"] == "Isolated reading integration UI checks" &&
        environment["GITHUB_JOB"] == "completion49" &&
        // Sentinel_e0cf63b4333c8191a85b9fc2f8ae5b4b authorizes the current
        // main Mac global check, including this unchanged completion job.
        ["refs/heads/fix/public-language-reader-20261011", "refs/heads/main"]
            .contains(environment["GITHUB_REF"] ?? "") &&
        environment["PDFNO_APPROVED_COMPLETION_AUTHORITY"] == "Sentinel_ae30196ad1dc8191b5e6f2d5ee0055fa")),
      NSUserName() == "runner",
      let workspace = environment["GITHUB_WORKSPACE"],
      URL(fileURLWithPath: workspace).resolvingSymlinksInPath().path ==
        URL(fileURLWithPath: FileManager.default.currentDirectoryPath).resolvingSymlinksInPath().path else {
    fputs("Refused: display configuration is restricted to the approved dedicated CI runner.\n", stderr)
    exit(2)
}

NSApplication.shared.setActivationPolicy(.prohibited)
let display = CGMainDisplayID()
let output = URL(fileURLWithPath: workspace).appendingPathComponent(".build/CI-Mac73-Display.json")
func rectangle(_ rect: CGRect) -> [String: Double] {
    ["x": rect.origin.x, "y": rect.origin.y, "width": rect.width, "height": rect.height]
}
func modeRecord(_ mode: CGDisplayMode) -> [String: Any] {
    ["width_points": mode.width, "height_points": mode.height,
     "width_pixels": mode.pixelWidth, "height_pixels": mode.pixelHeight,
     "usable_for_desktop": mode.isUsableForDesktopGUI()]
}
func screen() -> NSScreen? {
    NSScreen.screens.first {
        ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == display
    }
}
func observation() -> [String: Any] {
    var value: [String: Any] = ["display_id": display, "cg_bounds": rectangle(CGDisplayBounds(display)),
                             "width_pixels": CGDisplayPixelsWide(display), "height_pixels": CGDisplayPixelsHigh(display)]
    if let current = CGDisplayCopyDisplayMode(display) { value["mode"] = modeRecord(current) }
    if let screen = screen() {
        value["screen_frame"] = rectangle(screen.frame)
        value["visible_frame"] = rectangle(screen.visibleFrame)
        value["backing_scale"] = screen.backingScaleFactor
    }
    return value
}
func adequate() -> Bool {
    guard CGDisplayIsActive(display) != 0, CGDisplayIsAsleep(display) == 0,
          let screen = screen() else { return false }
    let bounds = CGDisplayBounds(display), visible = screen.visibleFrame
    return bounds.width >= 1600 && bounds.height >= 1000
        && visible.width >= 1440 && visible.height >= 900
}
var receipt: [String: Any] = ["at_utc": ISO8601DateFormatter().string(from: Date()),
                            "repository": environment["GITHUB_REPOSITORY"]!,
                            "ref": environment["GITHUB_REF"]!,
                            "head": environment["GITHUB_SHA"] ?? "",
                            "before": observation(), "changed": false,
                            "required_window_content": ["width": 1280, "height": 800],
                            "required_visible_frame": ["width": 1440, "height": 900]]
func finish(_ accepted: Bool, _ reason: String) -> Never {
    receipt["after"] = observation()
    receipt["accepted"] = accepted
    receipt["reason"] = reason
    do {
        try JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys])
            .write(to: output, options: .atomic)
    } catch {
        fputs("Could not write the CI display preflight receipt.\n", stderr)
        exit(2)
    }
    print("CI display preflight: \(accepted ? "accepted" : "environment blocked") · \(reason)")
    exit(accepted ? 0 : 2)
}
if adequate() { finish(true, "Existing logical display fits the original windows and drag margin") }
guard let modes = CGDisplayCopyAllDisplayModes(display, nil) as? [CGDisplayMode] else {
    finish(false, "No supported display modes were returned")
}
receipt["supported_modes"] = modes.map(modeRecord)
let candidates = modes.filter { $0.isUsableForDesktopGUI() && $0.width >= 1600 && $0.height >= 1000 }
    .sorted {
        let left = abs($0.width - 1920) + abs($0.height - 1080)
        let right = abs($1.width - 1920) + abs($1.height - 1080)
        return left == right ? $0.pixelWidth < $1.pixelWidth : left < right
    }
guard let selected = candidates.first else {
    finish(false, "No existing usable logical display mode fits the original 1280×800 scenarios")
}
receipt["selected_mode"] = modeRecord(selected)
var configuration: CGDisplayConfigRef?
let begin = CGBeginDisplayConfiguration(&configuration)
receipt["begin_code"] = begin.rawValue
guard begin == .success, let configuration else { finish(false, "Could not begin the display transaction") }
let configure = CGConfigureDisplayWithDisplayMode(configuration, display, selected, nil)
receipt["configure_code"] = configure.rawValue
guard configure == .success else {
    CGCancelDisplayConfiguration(configuration)
    finish(false, "The supported display mode could not be configured")
}
// Session-scoped on this disposable VM, never permanent. An app-only mode would
// revert when this preflight exits, before XCTest starts.
let complete = CGCompleteDisplayConfiguration(configuration, .forSession)
receipt["complete_code"] = complete.rawValue
receipt["configuration_lifetime"] = "dedicated disposable CI login session"
guard complete == .success else { finish(false, "The CI session rejected the display mode") }
receipt["changed"] = true
let deadline = Date().addingTimeInterval(5)
while !adequate() && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
finish(adequate(), "Checked the actual CG bounds and AppKit visible frame after the session change")
