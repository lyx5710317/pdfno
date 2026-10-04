# Comic archive validation — 2026-10-04

Delivered useful result: finite **Mac CBT / uncompressed POSIX USTAR** import, mixed CBZ/CBT library, first-page cover and existing fixed Kookit comic controls/progress. CB7/CBR remain closed. Base `f3ed484fee815effed2d955f8eb21bcd66d8546e`, local `feature/comic-archive-formats`. No push/merge or new dependency installation. Exact supported structures, sources/licenses, downgrade behavior and shared conflict points are in [ADR-COMIC-ARCHIVE-FORMATS](ADR-COMIC-ARCHIVE-FORMATS.md).

Toolchain: arm64 Mac, Xcode27.0 (27A266a), Swift6.4; Mac SDK27.0 and iPhone Simulator SDK27.0. All data is original/generated, stores and build outputs use separate temporary roots. No user private books/library/credentials or Library service were accessed.

| Authorized check | Result | Evidence / scope |
| --- | --- | --- |
| Explicit offline Swift functional tests | **37 tests / 3 suites passed**, 0.522 s test duration | CBTTests11, ComicTests12, CoverTests14; original records/raster and independent real Python USTAR fixture; no WebKit/window test suite in this corrected run |
| Fixed Kookit Node adapter tests | **4/4 passed** | Existing actual generated profile; logical/visual order, blob lifetime, stale/image/concurrent failures, simulated DOM only |
| Rebuild pinned comic resource | Passed; resource `git diff --exit-code` empty | Existing `COMICS-SOURCE.json` hashes and source-only builder; no npm/install/new source |
| Native Mac application + UI target | **TEST BUILD SUCCEEDED**, unsigned | `PDFnoMac`, Debug, `platform=macOS`, `CODE_SIGNING_ALLOWED=NO`, `build-for-testing`; new CBT app test compiled, not executed |
| iPhone/iPad Simulator application + UI target | **TEST BUILD SUCCEEDED**, unsigned | `PDFnoMobile`, generic Simulator, arm64 and x86_64 compile, `CODE_SIGNING_ALLOWED=NO`, `build-for-testing`; no simulator started |
| Native source/fixture/domain guard | Passed | `python3 scripts/check-native-source.py`; 326 source files after this report added |
| Requirement ledger checks | **8/8 passed** | `python3 scripts/test-requirement-ledger.py`; all83 formal definitions/bindings preserved, existing ledger unchanged |
| Whitespace check | Passed | `git diff --check` |

The Mac UI test compilation reports the same two unused `broken` locals in existing DOCX conversion UI methods (pre-existing at the base); no new Swift implementation warning/error. Mac/mobile also report the existing skipped AppIntents metadata warning because those targets do not depend on AppIntents.framework. Builds do not prove actual CBT picker/rendering/accessibility/device acceptance.

## Exact commands

```sh
PDFNO_COMIC_OFFLINE_ONLY=1 swift test --package-path apple/Packages/PDFnoKit --scratch-path /tmp/pdfno-comic-archive-unit --filter 'ComicTests|CBTTests|CoverTests' --skip ComicWebKitTests
node --test engine-build/comics-reader.test.mjs
node engine-build/build-comics.mjs
git diff --exit-code -- apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/Comics
python3 scripts/check-native-source.py
python3 scripts/test-requirement-ledger.py
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/pdfno-comic-archive-mac CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/pdfno-comic-archive-mobile CODE_SIGNING_ALLOWED=NO build-for-testing
git diff --check
```

Logs remain local in `/tmp/pdfno-comic-archive-offline.log`, `/tmp/pdfno-comic-archive-mac.log` and `/tmp/pdfno-comic-archive-mobile.log`; they are not committed or uploaded. No exact-SHA CI/release/device run is claimed.

## Original real-format fixture and coverage

`Comics/original-ustar.cbt.hex` is a UTF-8 source artifact, not disguised ZIP. Decode it to get10,240 real USTAR bytes; SHA-256 `3a2fa00f098eabc419b3f2d0a4f494b090e914286e6a0119ce33a961ba4d97a3`, hex-source SHA-256 `52f13eedbd016dc06a5e7feadef0a85557d5cce897d85d46cd319709c208f04f`. The independent stdlib Python writer/readback and original PNG/XML generator are in `scripts/generate-cbt-fixture.py`; provenance/hashes are in the adjacent SOURCE.json. The Swift reader verifies numeric order1/2/10 and original landscape dimensions. Additional generated in-memory fixtures cover UTF-8/name prefix/NUL file type, header checksums and numeric fields, terminators/truncation/padding, unsupported extensions/types/wrappers, count/byte/raster limits, wrong-container renaming, mixed-store deduplication, exact LTR/RTL/double progress/restart, first-image cover, wrong positions, corrupt/future store preservation and orphan collision refusal/reuse.

The new `testMacCBTImportSpreadsDirectionPageJumpAndRestart` uses real independently generated USTAR records and the same app flow as CBZ: original file picker, cover/portrait/landscape/odd page, RTL/double/single, page jump, close/reopen/restart, malformed error and PDF/EPUB transitions; source bytes are checked unchanged. **Code compiled; full CBT app UI NOT-RUN.** CB7/RAR test data only contains original inert signatures to assert unavailable-format rejection; there is no claim of decoding a genuine 7z/RAR archive.

## Test-filter scope deviation — disclosed immediately

An earlier command, `swift test --package-path apple/Packages/PDFnoKit --scratch-path /tmp/pdfno-comic-archive-unit --filter 'ComicTests|CBTTests|CoverTests'`, unexpectedly selected the two pre-existing `ComicWebKitTests` as well as the requested suites. The completed run reported38 tests/4 suites and called `NSApplication.shared`/created hidden test-process `NSWindow`s for `actualRasterSpreadsDirectionResizeAndRestart` and `realWebKitRefusesNetworkScriptsAndStaleCommands`. It did not launch the user's PDFno application or use a private store, but **these window bodies were outside the current no-desktop-UI authorization**. This is not presented as an authorized UI/security validation result. The first initial compile failure was a stale test-helper CBZ-only type, then repaired to accept the common archive wrapper.

That execution path was stopped and the scope deviation reported immediately. The final test run uses both a `PDFNO_COMIC_OFFLINE_ONLY=1` suite-level enabled condition and `--skip ComicWebKitTests`; its log has exactly the3 offline suites and37 tests, no WebKit/window suite. The workflow adopts those same exclusions. No new CBT app/UI flow or further desktop window was run. The earlier local log `/tmp/pdfno-comic-archive-unit.log` remains available to the coordinator; it is not uploaded or committed. There was no platform rejection of this local functional/build work, and no attempt to retry or bypass the previously blocked independent security task.

Previously platform-blocked **independent full-project security remains UNVERIFIED**. Routine rejection behavior/unit/source checks and the accidental pre-existing WebKit run do not change that status.

## Remaining blockers and shared conflicts

CB7/CBR: exact third-party source/codec choice and new-source approval, full per-file/transitive license/corresponding-source review, reproducible native Apple builds and bounded decompression/memory evidence. No source was installed while those gates remain open. See ADR's candidate table and exact next action.

CBT: full isolated app/native picker/actual rendering/restart/accessibility acceptance NOT-RUN; mobile reading/device UI, additional TAR variants, zoom/continuous/OCR/AI/notes remain future work. No new UI acceptance permission is assumed.

Shared files to reconcile with the independent Bookno/ebook/web work: `LibraryModel.swift`, `LibraryWorkspace.swift`, cover identity/origin enum switches (`CoverModels.swift`, `CoverRepository.swift`), comic model/repository/archive/session files, `ComicTests.swift`, `NativeUITests.swift`, comic workflow and common README/spec/task/validation/provenance documents. The additive CBT files/fixtures/ADR/report/generator can be cherry-picked with those shared edits. `Package.swift`, project generator, Kookit resource/lock and requirements ledger are unchanged. Main and other worktrees were not edited.
