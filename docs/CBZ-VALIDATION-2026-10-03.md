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
