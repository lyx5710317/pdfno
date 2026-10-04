# Mac local library and note search slice

Date: 2026-10-04. Branch: `feature/note-search`. Base: `11d32265a8b7ee7956f36c6af59dd42e54dcf035` (`feature/audit-fixes`). Main remains `05cbcf537e0ae85b2831a6b86e500e5d7d2b0a94`. This delivery is local only: no push, merge, release, app launch, real key, cloud API or private-document use. The previously blocked security revalidation remains **UNVERIFIED** and was not retried.

## Delivered behavior

The Mac toolbar opens **书库与笔记搜索**. Results are grouped by book and identify catalog matches, user notes/quotes, and saved AI learning notes. A result opens its book or returns through the existing exact PDFKit, EPUB or Mammoth DOCX source resolver. CBZ supports catalog search/open only. Saved PDF selection/current-page and EPUB learning notes search their quote, generated text and independent user body. Unsaved AI output, full page text outside the saved quote, provider configuration, whole-book content, OCR and remote APIs are outside this index.

Queries use a fixed `en_US_POSIX` case fold and NFC-equivalent copies; source text and anchors are never normalized or rewritten. Whitespace-separated terms must all occur in the relevant fields: catalog title/author for a book hit, or user body/quote/saved AI text for a note hit. Chinese/Japanese substrings, case changes, composed/decomposed accents and emoji components have original-fixture regressions. Preview boundaries preserve complete grapheme clusters. Accent removal, language segmentation, fuzzy ranking and full-width/transliteration equivalence are not claimed.

Empty queries show an input prompt and no note hits. No-result, cancellation and validation failure have separate states. Queries are limited to 1024 UTF-16 units; the display retains up to 300 stable hits and reports the complete match count. A missing/changed book or note does not receive a fabricated locator; its persisted quote is retained. Orphan AI notes remain searchable and display unavailable source status. PDF route preflight checks the real asset and exact anchor before switching books; click activation also rereads current records. EPUB/DOCX continue to rely on their existing native identity checks and engine exact-source validation.

## Metadata without migration

The baseline has filename-derived titles and no author field. **书目信息** lets the user supply an optional local title/author for search. It defaults to the current imported title; an empty author means unknown. Automatic author extraction from all format containers is not implemented. These values affect the search catalog; existing sidebar/reader titles and original filenames remain owned by the current reader models.

`book-metadata-v1.json` is a new optional sidecar, keyed by format, book UUID, edition UUID and original SHA-256. It uses strict keys/version, bounded reads and text, revision conflict checks, validated prior backup and atomic replacement. Absent sidecars are empty; corrupt/future/unknown-key sidecars stop search or metadata saving and preserve original bytes/backup. Existing PDF, EPUB, DOCX, comic and learning manifests, original bytes, citation schemas and provenance protections are unchanged. No existing data migration is performed. An older app can continue to read the unchanged manifests and ignore the sidecar.

## Refresh and integration interface

`LibrarySearchRepository.search(_:)` reads the current validated format/learning/metadata manifests and safely rebuilds an ephemeral index for every request. It never writes a persistent search index. Normalization/matching runs in a detached task; task cancellation propagates, cooperative checks stop work, and `LibrarySearchModel` generation tokens reject late success or failure even when an injected backend ignores cancellation. Failure clears old hits rather than publishing a partial index.

The sheet subscribes to the existing published `LibraryModel.books/notes`, `epubBooks/epubNotes`, `comicBooks`, `docx.books/notes`, and `learning.notes`. Successful import/save/reload or edited array-element publication triggers `LibrarySearchModel.refresh()`. The explicit Refresh button supports other editor integrations. Reopening the sheet also reconstructs from stores. This is local single-app behavior; cross-process transactional snapshots and incremental on-disk indexing are not promised.

`feature/note-editing` at `235807b51701031b2928445dc415a639968cb620` already publishes PDF/EPUB/learning arrays from `saveEditedNote`/`reloadEditedNote`. Search uses those unchanged interfaces. No files in its worktree were changed, and its commits were not imported into this branch.

### File overlap list

| Existing file | Search change | Integration consideration |
| --- | --- | --- |
| `apple/Packages/PDFnoKit/Sources/PDFnoUI/LibraryWorkspace.swift` | Three lines: search state, Mac toolbar button, sheet | Also changed by note editing, in separate notes-panel hunks. Preserve both; cover UI may also change this file. |
| `apple/Tests/NativeUITests.swift` | Two additional Mac tests under the existing class/helpers | Also changed by note editing. Keep all test methods/helpers; insertion hunks may need manual resolution. |

All other search source/test files and this handoff are new, independent files. `LibraryModel.swift`, existing repositories/readers, project generator, engine bundles, original fixture corpus and requirements ledger were not modified. Covers was still at the base commit when local branch overlap was inspected; no claim is made about its unfinished file diff.

## Actual verification

Host: arm64, macOS 27.0 (26A428), Xcode 27.0 (27A266a), Swift 6.4. All stores/inputs in the executed tests were original fixtures or freshly constructed synthetic data in UUID temporary roots. Build/cache/DerivedData paths were isolated under `/tmp`.

| Check | Result |
| --- | --- |
| Final `LibrarySearchTests` + `LibrarySearchModelTests` | **16/16 passed**, including real PDFKit cross-book note and persisted AI source return |
| Existing `RepositoryTests`, `PDFReaderTests`, `PDFQuoteConsistencyTests` | **10/10 passed** (parameterized cases additionally cover four rotations and two whitespace substitutions) |
| Mac `build-for-testing`, signing disabled | **TEST BUILD SUCCEEDED**; app and both new UI tests compiled, no app launched |
| iOS Simulator generic build, signing disabled | **BUILD SUCCEEDED**; shared package compiles; search UI stays Mac-only |
| Source/original-fixture guard and `git diff --check` | Passed |
| New Mac UI functional execution | **NOT-RUN** locally; queued for later isolated CI/VM/OS user |
| Previously blocked security专项 revalidation | **UNVERIFIED**, unchanged; no attempt to resume or bypass |

The baseline emits an existing Swift test capture warning and two unused-variable UI test warnings on a clean build. Xcode reports skipped AppIntents metadata extraction because the app does not depend on that framework. No new search-source compiler warning remains. The executed regression suite intentionally used targeted storage/source tests, not a full security revalidation or full functional CI rerun.

Reproduce with task-specific cache locations (SwiftPM's nested manifest sandbox needs the normal approved local build environment):

```sh
env CLANG_MODULE_CACHE_PATH=/tmp/pdfno-note-search-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/pdfno-note-search-manifest-modules swift test --package-path apple/Packages/PDFnoKit --scratch-path /tmp/pdfno-note-search-build --cache-path /tmp/pdfno-note-search-cache --config-path /tmp/pdfno-note-search-config --security-path /tmp/pdfno-note-search-security -Xswiftc -module-cache-path -Xswiftc /tmp/pdfno-note-search-modules --filter LibrarySearch
env CLANG_MODULE_CACHE_PATH=/tmp/pdfno-note-search-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/pdfno-note-search-manifest-modules swift test --skip-build --package-path apple/Packages/PDFnoKit --scratch-path /tmp/pdfno-note-search-build --cache-path /tmp/pdfno-note-search-cache --config-path /tmp/pdfno-note-search-config --security-path /tmp/pdfno-note-search-security -Xswiftc -module-cache-path -Xswiftc /tmp/pdfno-note-search-modules --filter 'RepositoryTests|PDFReaderTests|PDFQuoteConsistencyTests'
env CLANG_MODULE_CACHE_PATH=/tmp/pdfno-note-search-xcode-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/pdfno-note-search-xcode-manifest-modules xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/pdfno-note-search-Mac -clonedSourcePackagesDirPath /tmp/pdfno-note-search-Packages -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build-for-testing
env CLANG_MODULE_CACHE_PATH=/tmp/pdfno-note-search-Mobile-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/pdfno-note-search-Mobile-manifest-modules xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/pdfno-note-search-Mobile -clonedSourcePackagesDirPath /tmp/pdfno-note-search-Mobile-Packages -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build
python3 -B scripts/check-native-source.py
git diff --check
```

Local evidence logs: `/tmp/pdfno-note-search-unit-final.log`, `/tmp/pdfno-note-search-regression.log`, `/tmp/pdfno-note-search-mac-build-final.log`, `/tmp/pdfno-note-search-mobile-build-final.log`. They are not committed and contain no real books or credentials.

### Deferred isolated UI acceptance

The existing CI scheme automatically includes these methods in `NativeUITests`:

- `testMacLibrarySearchMetadataUnicodeEmptyNoResultsAndRestart`: original sample, sidecar title/author edit, canonical accent/Chinese search, empty/no results, restart and book opening.
- `testMacLibrarySearchUserNoteSavedLocalMockAIAndExactSource`: original selection note, local mock saved learning note, page return and restart persistence; no key or network provider.

Run the full Mac workflow only after integration in an isolated CI/VM/OS user with no running PDFno of the same bundle ID. Local unit/source/build evidence does not substitute for these UI executions. VoiceOver, large-library latency/resource benchmarks, crash injection and real-world EPUB/DOCX source-return layout coverage remain unverified. This advances the Mac S01/U01 library-search portion and saved-note search; it does not close the complete navigation/back-stack or full-book search inventory in the v0.3 specification.
