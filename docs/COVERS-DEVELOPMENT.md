# Mac local covers — implementation and handoff

Base: `11d32265a8b7ee7956f36c6af59dd42e54dcf035`, local branch `feature/covers`. This slice does not merge/push/release or alter the main checkout, another worktree, shared Library, original documents, reader anchors, Unicode handling, credentials or remote integrations. The previously blocked security专项 remains **UNVERIFIED**, with no retry or workaround.

## Behavior

- PDF: render physical page zero from a fresh, unannotated PDFKit document, preserving CropBox/rotation/aspect ratio. No annotation projection or PDF writes.
- EPUB: use the existing EPUB archive validator and CRC-checked bounded inflater. Read EPUB 3 `cover-image`, EPUB 2 `meta name=cover` and local guide image wrappers. Local relative paths may traverse within the archive but cannot escape it. Static PNG/JPEG/HEIC/TIFF are supported; no declared cover, unsupported vector-only art or unreadable embedded art uses the same placeholder on reopening. There is no title search, guessed first-body-image cover, WebView or network request.
- CBZ: use the existing validated page order and the first supported PNG/JPEG image, ignoring metadata as the reader already does.
- DOCX: a stable format placeholder, without guessing that a body image is a cover. Manual replacement and restore are available.
- Mac: sidebar list and lazy grid use one thumbnail component and the same original open/import routes. The selected book's toolbar and each row's context menu open the local cover editor. Switching layouts/reopening restores the same saved choice. Existing row/test identifiers remain.
- Manual: the native image importer accepts a single-frame PNG/JPEG/HEIC/TIFF. Original local images remain unchanged; a normalized PNG copy strips source metadata and applies orientation. Explicit restore rebuilds the automatic cover. Source edition/extractor changes refresh automatic covers while retaining a user's chosen cover.

## Storage and resource limits

`CoverIdentity` carries existing book/edition UUIDs, source format and exact original SHA-256. `CoverRecord` carries provenance, archive resource path where applicable, normalized PNG SHA-256, MIME, byte length, dimensions, extractor version, local revision and timestamp. It stores no private absolute image path, bookmark, remote URL or credentials. This is reusable input for a future Bookno adapter; the local counter is not a cross-device conflict algorithm and no Bookno/iCloud transport is connected.

`covers-v1.json` is independent of all four existing book/note manifests. Validated writes back up the previous cover manifest, then atomically replace it; corrupt/future/unknown-field records refuse overwrites. `Covers/Assets/<sha>.png` contains managed cover bytes, deduplicated by digest. Current and immediately preceding backup cover assets are retained; unreferenced module-owned assets can be reclaimed. `Covers/Thumbnails/` is disposable and rebuilt if absent or damaged. Missing automatic assets regenerate; a missing user asset reports unavailable and keeps the user's record until explicitly restored/replaced.

Manual inputs: 12 MiB, at most 32 million pixels and 16000 pixels per edge; reject dimensions/frame count before allocating a raster. Managed manual copy: maximum edge 1200; automatic image and thumbnail: maximum edge 512. CBZ inputs retain the existing 16 MiB entry limit. Windows for the same local store share the cover controller and serialized service, preventing independent in-process cover writers and keeping edits visible in both windows. The service bounds simultaneous raster work. The LRU charges at least decoded pixel cost against 16 MiB, disk thumbnails are limited to 64 MiB, and visible UI images release on disappearance. PDFs and archives retain their existing bounded file/entry limits. Lazy loading does not pre-render every book during import.

## Verification and isolation

Local toolchain: Xcode 27.0 (27A266a), Swift 6.4, Apple Silicon. A passing compile does not establish macOS 14/Xcode 16 runtime behavior. The new CoverTests use generated original two-page PDFs, raster images and ZIP records, fresh temporary roots, and no app/API/private files. Three parameter cases verify EPUB 3, EPUB 2 metadata and guide behavior. Tests additionally verify first-page/first-image pixels, rotated CropBox dimensions, Word/missing-cover persistence, replacement/restart/restore, source identity changes, selected cover protection, damaged derived cache and missing automatic asset recovery, disk-cache byte-limit eviction with unrelated-file preservation, invalid images/frame limits, future-store refusal and unchanged original/book-manifest bytes.

All local build, module, SwiftPM and temporary paths are explicitly placed under `.build/covers/`; `CFFIXED_USER_HOME` points to its isolated home without redefining `HOME`. Logs are ignored local evidence:

- `.build/covers/tests-final.log` — **14 CoverTests passed**, zero failures, 0.104 seconds; three EPUB parameter cases are included.
- `.build/covers/mac-build-for-testing.log` — **TEST BUILD SUCCEEDED** for the app plus all existing/new UI test compilation; no execution.
- `.build/covers/mobile-build.log` — **BUILD SUCCEEDED** for generic iPhone/iPad Simulator compilation; no simulator execution or mobile UX acceptance.
- `.build/covers/initial-build.log` — initial failed compile due to unsupported Apple `FoundationXML` import; fixed by using existing Foundation XMLParser. This is failure evidence, not a pass.

Two methods were added to the existing `NativeUITests.swift` target, retaining every previous method: `testMacCoverSelectionGridListRestartAndRestore` exercises the native picker, manual dimensions, both layouts, app restart/actual PDF reopen, restore and original/manifest byte preservation; `testMacDOCXDefaultCoverInListGridAndRestart` exercises stable Word placeholders across layouts/restart. They are **NOT RUN locally**, and require subsequent isolated CI/VM/OS-user execution because the unchanged XCTest bundle identity would terminate a user's running PDFno app. No app identity, target, signing/account configuration or timeout was changed.

Ordinary source/fixture guard passed for 252 source files, all eight requirement-ledger tests passed, and `git diff --check` passed. These checks are not the blocked security专项. `.build/covers/validation-summary.json` records the exact final commands, exit codes, isolation variables and timings. The initial compile failure is retained; final builds pass with only existing unused-fixture/AppIntents warnings.

For isolated CI, use the existing Mac scheme's signed `xcodebuild test` flow and include these methods alongside all existing flows. For local compile/unit reproduction, explicitly set `.build/covers/` cache/config/security/scratch/DerivedData/temp paths and use `swift test ... --filter CoverTests` plus `xcodebuild ... build-for-testing`; do not substitute an app launch or security专项 rerun.

### Reproducing the same isolated checks

From this worktree (do not run app tests on the owner's OS user):

```sh
COVER_BUILD_ROOT="$PWD/.build/covers"
mkdir -p "$COVER_BUILD_ROOT"/{home,tmp,xdg,clang,module,swiftpm-cache,swiftpm-config,swiftpm-security}
export CFFIXED_USER_HOME="$COVER_BUILD_ROOT/home"
export TMPDIR="$COVER_BUILD_ROOT/tmp/"
export XDG_CACHE_HOME="$COVER_BUILD_ROOT/xdg"
export CLANG_MODULE_CACHE_PATH="$COVER_BUILD_ROOT/clang"
export SWIFTPM_MODULECACHE_OVERRIDE="$COVER_BUILD_ROOT/module"
swift test --package-path apple/Packages/PDFnoKit --scratch-path "$COVER_BUILD_ROOT/swift" --cache-path "$COVER_BUILD_ROOT/swiftpm-cache" --config-path "$COVER_BUILD_ROOT/swiftpm-config" --security-path "$COVER_BUILD_ROOT/swiftpm-security" --filter CoverTests
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath "$COVER_BUILD_ROOT/Mac" -clonedSourcePackagesDirPath "$COVER_BUILD_ROOT/MacPackages" -packageCachePath "$COVER_BUILD_ROOT/swiftpm-cache" CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath "$COVER_BUILD_ROOT/Mobile" -clonedSourcePackagesDirPath "$COVER_BUILD_ROOT/MobilePackages" -packageCachePath "$COVER_BUILD_ROOT/swiftpm-cache" CODE_SIGNING_ALLOWED=NO build
```

## Integration conflicts

Existing files changed: `README.md`, `apple/Packages/PDFnoKit/Sources/PDFnoUI/LibraryModel.swift` (cover controller injection only), `LibraryWorkspace.swift` (library display/editor only; reader search/note bodies untouched), and `apple/Tests/NativeUITests.swift` (two additive methods). Notes/search work is likely to overlap these four files; integrate the additive injection/methods and resolve the sidebar deliberately. No existing Domain models, note repositories, engine bundle, package manifest, Xcode project or workflow was modified.

New files: `CoverModels.swift`, `CoverRaster.swift`, `CoverRepository.swift`, `EPUBCoverExtractor.swift`, `LibraryCovers.swift`, `CoverTests.swift` and this handoff. They are discovered by the existing package targets without project generation. Only the local commit is offered for integration; full UI/final combined-branch CI and the original security verification gap remain separate gates.
