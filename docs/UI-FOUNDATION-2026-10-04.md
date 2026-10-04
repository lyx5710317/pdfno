# UI foundation first slice — local candidate

Base: accepted main `bb6928e1319f85a72c967a6c3f054bb544e9c306`. Work is isolated on `feature/ui-foundation`; no push, merge, release or user-app launch is part of this slice. AGPL-3.0-or-later and the native Mac-first SwiftUI/PDFKit/Kookit route remain.

## Implemented scope

- `PDFnoDesignSystem.swift` centralizes replaceable system fonts (18 pt title, 13 pt section/body, 11 pt metadata), spacing (4/8/12/16/24 pt), shell colors, 8 pt corners and 30 pt controls. Native semantic colors follow light/dark appearance; accent follows the user's system accent. Reader paper is independent. Primary/secondary/quiet buttons have pressed and disabled appearance; disabled actions retain native accessibility semantics. Layout selection uses a border, accessible selection trait and text value in addition to color. Panel close controls have labels and help.
- Library header/count, list/grid selection, cover-row typography, empty state and a bounded scrollable action area use the tokens. All current format routes, samples, cover editing, library search, conversion, AI settings and default-off Bookno offline preview remain. Existing cover loading/caching/repository behavior is untouched.
- The Mac PDF reader is the finite reader-shell slice. Navigation/search docks left, notes dock right. Both appear only when the **reader detail area** is at least 980 pt (240 + 420 + 320). Below that, the last opened panel is shown; a dock is allowed only if at least 420 pt remains for the canvas. Smaller areas use one overlay panel with a 16 pt uncovered edge. The canvas stays the same first child across every panel/width change, preserving its PDFView, document, reader session and immutable selection/source. Search and new-note draft remain in ReaderWorkspace; saved-note editing remains in the existing editor model.
- Panel buttons toggle visible state and expose expanded/collapsed accessibility values. Search is Command-F in the PDF reader and Command-Shift-F for the library. Source return and search result navigation retain their exact existing checks and close the corresponding panel. Mobile PDF keeps its existing sheets.

The approved UPDF desktop research report was read as an information-organization reference. It distinguishes observed controls from recommendations and leaves narrow-window behavior unmeasured. No UPDF app/history, private book, screenshot or proprietary asset was opened/copied. No verified Bookno visual tokens were available in the report/repository; this candidate uses PDFno-owned replaceable tokens, without claiming Bookno visual equivalence.

## Validation and limits

Toolchain: macOS 27.0 (26A428), Xcode 27.0 (27A266a), Apple Swift 6.4, arm64. All builds use two jobs and independent output directories; no heavy validations run concurrently within this task. Other workers' build processes were checked; new heavy builds waited for an idle interval.

```sh
PDFNO_UI_FOUNDATION_PREVIEW=/tmp/pdfno-ui-foundation-component \
  swift test --package-path apple/Packages/PDFnoKit \
  --scratch-path .build/UIFoundation --jobs 2 --no-parallel \
  --filter 'UIFoundationTests|PDFReaderTests|PDFQuoteConsistencyTests|LibraryIntegrationTests|CoverTests'
python3 scripts/check-native-source.py
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac \
  -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/MacUIFoundation -jobs 2 \
  CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/MobileUIFoundation -jobs 2 \
  CODE_SIGNING_ALLOWED=NO build-for-testing
```

Local selected Swift tests: **31 methods / 5 suites passed**, including six new foundation methods. Parameterized existing cases remain intact. The layout sweep covers widths 0–1600, narrow switching/closing, wide dual docking and invalid width proposals. The real PDFKit test uses only the original bundled sample and an in-process, never-shown host: resizing at 1100/880/440/1100 pt and toggling panels preserve the exact PDFView/document/session/anchor and bound draft/search; native canvas width matches the production layout. This does not substitute for actual ReaderWorkspace desktop interactions.

Original light/dark component PNGs were generated in the unit-test process and visually inspected at 320 pt. Long multilingual text wraps and primary/disabled/quiet actions are visible. No desktop or other application was captured. An initial component test used unconstrained NSHostingView intrinsic width and failed; the fixture was corrected to impose the same fixed width as the production shell panel, then all six tests passed. No production limit or acceptance assertion was removed.

**Mac arm64 build-for-testing PASSED** (`TEST BUILD SUCCEEDED`); **iPhone/iPad Simulator arm64 + x86_64 build-for-testing PASSED** (`TEST BUILD SUCCEEDED`). Signing was disabled by command-line build override only; project signing settings, permissions, entitlements and account configuration were not modified. Final selected Swift rerun passed all 31 methods in 1.268 seconds. Source guard passed 585 files; `git diff --check` passed. Existing codec precision and legacy unused-variable compiler warnings remain; none arose from the new foundation files. Local raw logs are `/tmp/pdfno-ui-foundation-swift-final.log`, `/tmp/pdfno-ui-foundation-mac-build.log` and `/tmp/pdfno-ui-foundation-mobile-build.log`; original component images are `/tmp/pdfno-ui-foundation-component-light.png` and `/tmp/pdfno-ui-foundation-component-dark.png`. These generated files are not committed. Two new Mac UI methods check layout-selection accessibility values/retained sample routes, and original PDF selection plus unsaved-draft continuity across panel switch/close/save/source return. **All original NativeUITests and EbookFormatUITests lines are retained in order**: 43 existing Mac UI methods plus two new methods. All 34 identifiers originally declared by LibraryWorkspace are preserved, including those moved into reusable components. Actual desktop UI execution: **NOT-RUN locally**, reserved for an isolated final-commit CI/OS user; the original accepted baseline's 43 passed UI tests are not claimed for this candidate.

Full visual acceptance, VoiceOver, focus order/keyboard interaction, increased contrast/reduced motion and actual minimum-window desktop behavior remain **NOT-VERIFIED**. Mobile/Intel/device runtime acceptance remains separate. Panel widths are fixed in this slice; no draggable splitters, document tabs, new multi-window architecture or new capabilities are added. EPUB/other-format reader layouts and AI/settings/conversion contents retain their current implementation; adopting these tokens in those workflows is follow-up work, not an implied completed redesign.

## Shared conflict surfaces and rollback

Exclusive UI changes are confined to `LibraryWorkspace.swift`, visual portions of `LibraryCovers.swift`, new `PDFnoDesignSystem.swift` and `PDFnoReaderShell.swift`. No changes to LibraryModel, reader/AI/conversion kernels, note repositories, domain/source models, manifests, credentials, entitlements or signing configuration. No original fixtures, engine bundles, license files or shared Library content are modified. Independent security remains **UNVERIFIED / platform-blocked**; it was neither retried nor bypassed.

`NativeUITests.swift` is the only likely shared append surface with other workers; keep both test additions on integration without dropping any original lines. `LibraryWorkspace.swift` owns panel composition and library layout, and should remain exclusively owned by this slice until integration. `LibraryCovers.swift` changes are view-only; any later cover business change should preserve its model/repository code. No generated Xcode project or generator change is required because the two UI methods extend the existing source and the shared package discovers its own files.

The candidate can be reverted as one local commit; persisted schema/data are unchanged. Existing main and all other worktrees remain untouched.
