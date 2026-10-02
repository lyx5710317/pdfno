# Native validation evidence

Date: 2026-10-02. Delivery priority is **Mac first, mobile adaptation afterward**. Two real app targets and shared contracts are retained; a mobile build is not a promise of a complete iPhone/iPad product. No release or real-account/cloud operation occurred.

## Environment and current evidence

Local environment: MacBook Air, Apple silicon, macOS 27.0 (26A428), Xcode 27.0 (27A266a), Swift 6.4, macOS/iOS SDK 27.0. Adjustable deployment settings are macOS 14 and iOS/iPadOS 17; tests on the latest local runtime do not establish oldest-version compatibility. GitHub uses its actually reported `macos-15` toolchain.

| Check | Actual result / scope |
| --- | --- |
| Real Xcode workspace | `xcodebuild -list -workspace apple/PDFno.xcworkspace` resolves the local PDFnoKit package and both shared app schemes. pbxproj has two application and two UI-testing product types; mobile device family is 1,2. |
| Shared Swift package | **12 tests passed**. Exact Unicode scalar/UTF-16 boundary preservation, author-ruby separation, repeated quotes, immutable task source/terminal event guard, provider endpoint contract, strict store fields/IDs, deduplicated original import, restart progress, note revisions, corrupt/future-store refusal and changed-source refusal. |
| Real PDFKit integration | Included in those tests: open the original two-page PDF, outline, text search, PDF-space selection geometry, exact hash/edition restore, in-memory annotations without duplicate projection, JSON/new-PDFDocument round trip and invalid-PDF refusal. |
| Mac app build | **Passed** Debug native macOS build; ad hoc build also launches. Initial Debug app/package architecture mismatch was corrected with consistent ONLY_ACTIVE_ARCH settings. |
| Mac application run | Direct isolated-store launch produced a real PDFno window, 1180 × 780; XCTest also verifies sample import and page controls. **Full Mac UI acceptance passed**: 1 real UI test, 0 failures, 26.859 seconds; local result bundle `.build/Mac-Acceptance.xcresult`; the corrected WindowGroup entry also passed the same full flow (26.860 seconds) in `.build/Mac-WindowGroup.xcresult`. It verifies sample import, page controls, search selection, note/highlight save, source return, process termination/relaunch, reading position and note survival. |
| Mobile app compile | **Passed** iOS Simulator build for the common iPhone/iPad target. No Catalyst or browser-wrapped main app. |
| Earlier mobile UI experiments | iPhone first-run sample/read/page/search/highlight/source flow passed. Later expanded restart attempts exposed restoration/element-role issues; the restoration guard and generic library-row lookup were revised, but final mobile UI acceptance was not established. User then prioritised Mac; no additional mobile refinement/run is required for this stage. |
| Source/privacy/provenance guard | Passed: no detected personal paths, Library IDs, credential patterns, unreviewed binaries, caches/user metadata or old runtime in public candidate files. Two PDFs are the same original generated fixture. This is a narrow guard, not a comprehensive security audit. |
| Reproducible generated files | Project, schemes, workspace and both original PDF copies regenerate byte-for-byte. No network dependency or signing account involved. |
| Recoverable retirement | Completed after 43 baseline tracked retirement hashes and native metadata/concurrent-change checks. External recovery holds old runtime/config/cache and Git bundle; historical inventory retained unchanged. Unknown files and user data untouched. |
| Repository/CI | SHAs `bc114d5` (run 36971581909), `d451126` (run 36972542689) and `20c4094` (run 36973584007) passed source guards, 12 Swift tests, Mac build and mobile compile, but failed Mac UI smoke on macOS 15/Xcode 16.4. The diagnostic run established a foreground process with **zero windows**, not a changed button role. The test now conveys its validated isolated-store UUID through an environment variable rather than positional launch arguments, which AppKit can treat as file-open requests. Startup diagnostics report counts and application-window hierarchies, excluding the menu bar's system recent items. Final delivery reports the latest exact SHA and actual CI outcome; failed runs are not called successful. |

Original PDF fixture: **1,850 bytes**, SHA-256 `0364d0ca9f7317a7bbcb546faafbdd19d4b3a4ebc31afbee38d7bb30d14f0847`. Text/layout/outline are PDFno-authored AGPL fixtures, no private book or font program.

## Commands and diagnostics

```sh
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/PDFnoKit
python3 scripts/check-native-source.py
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Mac CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/Mobile CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Mac -resultBundlePath .build/Mac-Acceptance.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 180 -maximum-test-execution-time-allowance 240 test
```

UI tests isolate the store using a fresh UUID session in `PDFNO_UI_TEST_SESSION` and the bundled original PDF. Malformed session values also create a new isolated directory and never select the user's library. Test actions use Mac clicks, mobile taps and each platform's text accessibility value. Mac search input uses the original query and restores clipboard data in memory, avoiding changes to the user's input-method settings. No clipboard content is logged or included in artifacts. Current intentional Mac screenshot attachments capture the application window; older application screenshots can include the desktop and remain private in ignored local results.

Earlier local Mac UI attempts failed because an unsigned XCTest runner was killed, inactive app windows needed explicit activation, macOS controls were incorrectly sent touch actions, and `.label` was used for Mac text whose value lives in `.value`. Actual Mac list issues were also corrected: search results use PDFSelection identity rather than colliding page integers, and library rows use native List selection rather than embedded plain buttons. These failures are preserved in ignored result bundles; they are not counted as passing runs. The correct test uses local ad hoc signing `-`, never a developer account or certificate. Desktop connection interruptions were checked against real process/worktree state; reconnecting was never treated as action success.

Local logs/results are ignored under `.build/` and temporary files. They may include desktop automation metadata and are not committed or automatically uploaded. CI reports status/logs for the exact published SHA without distributing an app binary.

## Remaining acceptance gaps

Real-device iPhone/iPad and oldest deployment versions; VoiceOver/keyboard coverage, dynamic text, contrast and Pencil; sandbox signing/security-scoped bookmarks, passwords, malformed/encrypted/large/multi-column/rotated/CropBox/cross-page PDF matrix; performance and cancellable search/import; actual covers/thumbnails/tabs; note edit/delete; interrupted-write/fsync/file-coordination/cross-process recovery; automatic legacy migration; all EPUB/AI/BYOK/Keychain/translation/grammar/kana/Bookno/iCloud/comic/OCR/conversion behavior; signed distribution/notarisation and AGPL distribution review remain unvalidated/unimplemented as appropriate. No full T01–T22 or UAT01–UAT15 completion is claimed.

[Historical demo validation](historical/VALIDATION-LEGACY.md) retains the earlier Electron/CLI evidence. Its commands and successful old CI apply only to recoverable old source, not the current native runtime.

WindowGroup follows Apple’s [SwiftUI app scene guidance](https://developer.apple.com/documentation/technologyoverviews/swiftui), verified 2026-10-02. This phase hides new-window commands and does not promise multiple-window repository coordination. [XCUIApplication launchEnvironment](https://developer.apple.com/documentation/xcuiautomation/xcuiapplication/launchenvironment) provides the supported test-session transport. The interpretation of earlier positional arguments as file requests is a diagnostic hypothesis until the corrected exact-commit CI establishes the outcome; the confirmed observation is a foreground process with no windows.
