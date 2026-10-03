# CBZ slice validation — 2026-10-03

Base: `aaba190a878df9de5674491d20f1b36fa4733607`. Work is isolated in `feature/comics`. Nothing was pushed or merged. No dependency install was needed.

Toolchain: Xcode 27.0 (27A266a), Apple Swift 6.4, arm64 macOS host.

| Check | Result | Scope |
| --- | --- | --- |
| `swift test --filter 'ComicTests|EPUBTests|RepositoryTests|ContractsTests'` | 26 tests in 4 suites passed | CBZ (12), EPUB archive/storage (4), PDF storage (4), domain contracts (6); original synthetic data, isolated temporary stores |
| `node --test engine-build/comics-reader.test.mjs` | 4/4 passed | Actual generated Kookit profile, simulated DOM; blob lifecycle, order, stale requests, image failure, concurrent render |
| `node engine-build/build-comics.mjs` | Passed, deterministic output verified | One pinned/hash-verified Kookit source; no npm install or new dependency |
| Native Mac `xcodebuild ... -scheme PDFnoMac ... CODE_SIGNING_ALLOWED=NO build` | BUILD SUCCEEDED | Independent temporary DerivedData; app was not launched |
| Native simulator `xcodebuild ... -scheme PDFnoMobile -destination 'generic/platform=iOS Simulator' ... CODE_SIGNING_ALLOWED=NO build` | BUILD SUCCEEDED | Compile regression; simulator/app was not launched; mobile comic reading remains unavailable |
| `python3 scripts/check-native-source.py` | Passed | Original fixture/provenance/privacy/domain guards |
| `git diff --check` | Passed | No whitespace errors |

Only build warning: Xcode skipped AppIntents metadata extraction because the app has no AppIntents.framework dependency. No Swift compiler error/warning was reported.

Logs for this local run: `/tmp/pdfno-comics-unit-tests.log`, `/tmp/pdfno-comics-mac-build.log`, `/tmp/pdfno-comics-mobile-build.log`. These build logs may contain machine paths and are not committed. The independent `comics.yml` workflow repeats the profile and dedicated tests in CI; no CI run is claimed here.

The tests do not launch NSWindow, NSApplication, PDFno or a simulator, and do not read the real library or credentials. Existing EPUBWebKit and desktop UI tests were excluded per task instructions. Real WKWebView rendering, native picker and LTR/RTL/resize/restart interaction still need an isolated desktop acceptance run by the coordinator. See [ADR-CBZ-KOOKIT.md](ADR-CBZ-KOOKIT.md) for the exact slice, resource limits, CBR exclusion and merge touch points.

## Coordinator integration follow-up — 2026-10-03

The branch was reviewed and cherry-picked onto the AI baseline in the main checkout. Official fixed-commit `comic-book.js` content was fetched and compared byte-for-byte: 2247 bytes, SHA-256 `fb8b11ffead40f2ab48530e0c00ebe670e71cc36225bba9a33222dd6dc8ee45c`. Existing PDF/EPUB/DeepSeek source and user workspace metadata were preserved; other feature worktrees were not edited.

Two additional actual **WKWebView** tests passed locally in the separate test process in **0.943 seconds** (`.build/comics-webkit-tests.log`). They decode/render original PNG frames, check natural dimensions/blob URLs/script-disabled sandbox, cover/pair/landscape/odd-final-page order, LTR/RTL frame order, actual narrow/wide resize, explicit layout, saved progress and a fresh session. A second real-WebKit flow verifies CSP network refusal, script refusal, stale bridge refusal and close behavior. Their hidden temporary test windows do not launch, quit, inspect or overwrite the owner's PDFno app or credentials. All four original Node tests also passed.

The complete Mac app test is added to `NativeUITests`: original in-memory CBZ through the native picker, rendered cover, direction/layout, page jump, broken-file recovery, close/reopen, process restart and PDF/EPUB transitions. It runs on isolated CI with a fresh store UUID alongside all four existing regressions. The native CI also rebuilds and compares the comic resource. Local test compilation and exact-SHA CI outcomes are reported in the combined delivery; the original branch's build-only evidence does not prove that app flow passed.

## Merge file inventory

Shared files (review together with concurrent format/AI work):

* `apple/Packages/PDFnoKit/Package.swift`
* `apple/Packages/PDFnoKit/Sources/PDFnoUI/LibraryModel.swift`
* `apple/Packages/PDFnoKit/Sources/PDFnoUI/LibraryWorkspace.swift`

Additive files:

* `.github/workflows/comics.yml`
* `apple/Packages/PDFnoKit/Sources/PDFnoDomain/ComicModels.swift`
* `apple/Packages/PDFnoKit/Sources/PDFnoServices/CBZArchive.swift`
* `apple/Packages/PDFnoKit/Sources/PDFnoServices/ComicRepository.swift`
* `apple/Packages/PDFnoKit/Sources/PDFnoReaders/ComicReaderSession.swift`
* `apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/Comics/engine.js`
* `apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/Comics/index.html`
* `apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/Comics/Notices.txt`
* `apple/Packages/PDFnoKit/Sources/PDFnoUI/LibraryModel+Comics.swift`
* `apple/Packages/PDFnoKit/Sources/PDFnoUI/ComicWorkspace.swift`
* `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/ComicTests.swift`
* `engine-build/COMICS-SOURCE.json`
* `engine-build/build-comics.mjs`
* `engine-build/comics-reader.js`
* `engine-build/comics-reader.test.mjs`
* `engine-build/vendor/kookit/src/libs/comic-book.js`
* `docs/ADR-CBZ-KOOKIT.md`
* `docs/CBZ-VALIDATION-2026-10-03.md`
