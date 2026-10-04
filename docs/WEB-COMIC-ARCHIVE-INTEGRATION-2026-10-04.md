# Web + comic archive integration — 2026-10-04

The local candidate combines **XHTML / MHTML / readable XML and finite CBT** on the existing native Swift, PDFKit and fixed Kookit/WKWebView architecture. Two new joint regressions prove independent originals, identities, exact text notes/source return, reading progress and CBZ/CBT cover records in the same temporary library. **201 selected Swift tests / 29 suites, 4 Node tests, 8 requirement-ledger checks and unsigned Mac + generic Simulator build-for-testing passed. All 33 native UI methods are retained and compiled; full application UI is NOT-RUN.** No Bookno or ebook worker is included.

## Candidate lineage and conflict resolution

- Accepted common base: `f3ed484fee815effed2d955f8eb21bcd66d8546e`.
- Web input: `0b75e6cc7913e5f91ac8cf512c8bd7a9e744c53b`, `feature/web-archive-formats`.
- Comic input: `1ca74253b80ce6de5a945be1e4a294126adf8455`, `feature/comic-archive-formats`; its parent is the same accepted base.
- Independent integration branch: `feature/integration-web-comic-archives-20261004`, based on the exact web input. The CBT cherry-pick is `5f8db0a8db62c0ebb9b37bf7973bf94c9ba0c8cf`.
- The final local commit adds only joint regression tests, complete UI inventory and this handoff record/pointer. Resolve its exact candidate identity with `git rev-parse feature/integration-web-comic-archives-20261004`; the delivery includes that SHA.

Only three cherry-pick conflicts required manual resolution. `SOURCE-NOTICES.md` and `THIRD_PARTY_NOTICES.md` keep both additive provenance sections. `LibraryWorkspace.swift` retains the three web picker types and adds CBT with archive conformance; CBZ and prior picker types remain. Other common UI/library/model/cover/test/status/document edits merged without conflict. No format enum case or original UI method was removed.

For later serial Bookno/ebook integration, shared files still need review: `LibraryModel.swift`, `LibraryModel+Comics.swift`, `LibraryWorkspace.swift`, `TextFormatWorkspace.swift`, `TextFormatModels.swift`, `ComicModels.swift`, `CoverModels.swift`, `TextFileDecoder.swift`, text/comic reader sessions and repositories, cover repository, `NativeUITests.swift`, README, source/third-party notices, native task/status/spec/validation records and `.github/workflows/comics.yml`. No dependency, package/project generator, fixed engine resource or requirement-ledger definition was changed by this joint integration.

## Format routes, provenance and limits

The implementation and notices preserve AGPL-3.0-or-later. The fixed Kookit input remains `95f602ed62d204af0de9278cf53212c309b34bfc`; the existing pinned comic/text resources are reused unchanged. Source-entry and license evidence is in [WEB-ARCHIVE-FORMATS](WEB-ARCHIVE-FORMATS.md) and [ADR-COMIC-ARCHIVE-FORMATS](ADR-COMIC-ARCHIVE-FORMATS.md). The upstream HTML entry dispatches XHTML/MHTML/XML to HtmlRender; its mhtml2html branch is not bundled or executed here. The upstream comic entry feeds the same makeComicBook model; its js-untar/RAR/7z loaders are not newly installed. Bounded original Swift admission feeds those established models rather than introducing a reading engine.

| Format | Accepted Mac slice | Explicit boundary |
| --- | --- | --- |
| XHTML | Strict real XHTML namespace/body, semantic text, headings when present, canonical exact selection notes/source return/progress | UTF-8 or BOM UTF-16 with matching declarations; no external doctype/entities, foreign namespace, source scripts/events/styles or URL resolution |
| MHTML | Flat multipart/related, exactly one selected HTML root; strict base64/quoted-printable/7bit/8bit and charset agreement | 64 parts, 1 MiB decoded/part, 4 MiB original/decoded aggregate; CSS and admitted opaque PNG/JPEG resources are not rendered/resolved. No nested/alternative/active/unknown parts, legacy encoding guessing or online original-page loading |
| Readable XML | Real XHTML or documented unnamespaced document/section/title/paragraph and limited semantic vocabulary | Arbitrary data XML, DocBook/TEI/business schemas and invented directory meaning are refused. No headings means an empty directory |
| CBT | One uncompressed POSIX USTAR with regular files/directories and complete static PNG/JPEG; existing page pairing/LTR/RTL/jump/restart/first-page cover | No GNU/PAX/V7/sparse/links/devices/base-256/compressed/concatenated TAR, other image types or extraction to filesystem. Original 100 MiB/2000-entry/16 MiB-entry and pixel/downsample budgets apply |
| CBR / CB7 | Unavailable | No decoder installed; not in the picker and no support claim |

Web originals remain `Originals/<sha256>.<xhtml|mhtml|xml>` in `text-formats-v1.json`; CBZ remains `comics-v1.json`/`.cbz`, CBT uses `comics-cbt-v1.json`/`.cbt`. The shared cover store retains book/edition/hash/format ownership even when identical raster bytes share a cache key. Text anchors describe canonical displayed semantic UTF-16 text, not raw XML/MIME byte offsets. Comic exact text/region notes, OCR/AI and mobile reading remain unsupported. Existing downgrade refusal/backup behavior is documented by the individual slices; this integration performs no migration.

## Joint evidence and authorized scope

`WebComicArchiveIntegrationTests.swift` adds two serialized Mac regressions using only original generated fixtures and temporary roots:

1. `sharedLibraryPreservesCanonicalNotesProgressOriginalsAndContainerCovers`: imports CBZ, CBT and all three web formats with the same title; verifies different edition/container identities, identical-image cache reuse without foreign cover ownership, actual unattached Kookit canonical text and exact `window` notes, text source return/reopen, independent text and comic progress, CBT cover replace/restore without CBZ/text changes, original-byte equality and absence of unrelated PDF/EPUB/DOCX/learning manifests.
2. `crossFormatPositionsRefuseWithoutChangingEitherManifest`: rejects CBZ progress for CBT and CBT-identity text anchors for XML notes/progress; all three manifests remain byte-identical.

The actual WKWebViews are unattached (`window == nil`), with no NSWindow or user application launch. The selected Swift regression intentionally excludes all 13 existing window test methods: ComicWebKitTests (2), EPUBWebKitTests (4), EPUBChapterWebKitTests (3), TextChapterIntegrationTests (3) and `isolatedNativeViewFitsNarrowWindowWithLongSyntheticResponse` (1). Their test bodies did not execute in this task. This is a complete result for the explicit selection, not unfiltered Swift/UI acceptance.

| Check | Actual local result |
| --- | --- |
| Joint tests, focused | 2 tests / 1 suite passed, 0.829 s |
| Selected Swift regression | 201 tests / 29 suites passed, 4.040 s; includes joint, web and CBT tests plus the prior no-window functional suites |
| Fixed Kookit comic Node adapter | 4/4 passed; simulated DOM, not native UI |
| Pinned comic rebuild / independent USTAR fixture regeneration | Passed; tracked resource/fixture diff empty; no install/network dependency action |
| Requirement ledger | 8/8 passed; all 83 formal IDs/definition bindings retained |
| Source/provenance/domain guard and whitespace | Passed; narrow repository guards, not independent security acceptance |
| Mac app + UI test target | TEST BUILD SUCCEEDED; Debug, unsigned, build-for-testing |
| iPhone/iPad generic Simulator app + UI test target | TEST BUILD SUCCEEDED; Debug, unsigned, build-for-testing; no simulator launched |

Toolchain: arm64 Mac, macOS27.0 (26A428), Xcode27.0 (27A266a), Swift6.4, SDK27.0, Node20.20.2. The same existing DOCX UI unused-local and AppIntents metadata warnings remain; no new implementation errors were reported. Oldest supported OS, Intel runtime, devices, accessibility and memory profiling are not established by compilation.

```sh
PDFNO_COMIC_OFFLINE_ONLY=1 swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/ArchiveIntegrationPackage --skip 'ComicWebKitTests|EPUBWebKitTests|EPUBChapterWebKitTests|TextChapterIntegrationTests|isolatedNativeViewFitsNarrowWindowWithLongSyntheticResponse'
node --test engine-build/comics-reader.test.mjs
node engine-build/build-comics.mjs
python3 scripts/generate-cbt-fixture.py
git diff --exit-code -- engine-build apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/Comics apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/Comics
python3 scripts/check-native-source.py
python3 -B scripts/test-requirement-ledger.py
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/ArchiveIntegrationMac CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/ArchiveIntegrationMobile CODE_SIGNING_ALLOWED=NO build-for-testing
git diff --check
```

Original USTAR fixture decoded SHA-256: `3a2fa00f098eabc419b3f2d0a4f494b090e914286e6a0119ce33a961ba4d97a3` (10,240 bytes); source hex SHA-256: `52f13eedbd016dc06a5e7feadef0a85557d5cce897d85d46cd319709c208f04f`.

Final local raw logs remain ephemeral under `/tmp`, excluded from Git/upload. Their SHA-256 identities are:

| Log | SHA-256 |
| --- | --- |
| pdfno-web-comic-focused.log | `5b785df8614483725d07c99c8905b574f1f270f1621a7c0fac600847c846c0ec` |
| pdfno-web-comic-regression.log | `9ea94120bba6f05e35564065c4c23d2017efdb628f4c1761c24fc02a2eb02bd2` |
| pdfno-web-comic-mac-build.log | `8e6280aa7c2ef8b81d92de56cd8153944b86e46158f492c630f463acbdc5b78b` |
| pdfno-web-comic-mobile-build.log | `cfb2681c593f8568b183e3f51ebba1ebf0003c6f08e10fd169fbd5a32ee8062a` |

## Complete retained application UI inventory

[Machine-readable inventory](ARCHIVE-INTEGRATION-UI-INVENTORY.json) records exact names and input SHAs. The current source set was checked against the accepted base and both workers: **29 baseline + 3 web + 1 CBT = 33**, no missing/duplicate/additional method. The CBZ method retains its name and original assertion flow through the common CBZ/CBT helper. Mac compiles all 33 methods; mobile compiles its applicable conditional methods. None ran locally in this integration.

| Origin | Method in apple/Tests/NativeUITests.swift |
| --- | --- |
| Baseline | `testLocalPDFReadingAndNoteFlow` |
| Baseline | `testMacAISelectionConsentMockNotesAndRestart` |
| Baseline | `testMacCBZImportSpreadsDirectionPageJumpAndRestart` |
| Baseline | `testMacCoverSelectionGridListRestartAndRestore` |
| Baseline | `testMacDOCXConversionFailureRecoveryAndEscapedHTML` |
| Baseline | `testMacDOCXConversionSavePanelCancelAndOverwriteRefusal` |
| Baseline | `testMacDOCXConversionWorkerCancellationLeavesNoOutput` |
| Baseline | `testMacDOCXDefaultCoverInListGridAndRestart` |
| Baseline | `testMacDOCXFailureRecoveryAndPDFEPUBTransitions` |
| Baseline | `testMacDOCXImportSemanticSelectionNotesAndRestart` |
| Baseline | `testMacDeepSeekSelectionOfflineTransportPDFEPUBAndRestart` |
| Baseline | `testMacEPUBBodyEditingBookSwitchRestartAndSource` |
| Baseline | `testMacEPUBChapterCancelStopsRemainderAndReopenCannotRetryOrRestoreKey` |
| Baseline | `testMacEPUBChapterCompleteScopeConsentBilingualManualSaveRestartAndSourceReturn` |
| Baseline | `testMacEPUBChapterOversizeRefusesWholeDocumentWithoutKeyOrSend` |
| Baseline | `testMacEPUBChapterPartialFailureKeepsFirstSegmentAndStopsAllRemaining` |
| Baseline | `testMacEPUBSelectionRubyNotesAndRestart` |
| Baseline | `testMacEditedNoteSearchDraftExclusionCoverLayoutsAndExactSource` |
| Baseline | `testMacHTMLAliasImportSelectionNotesNavigationAndRestart` |
| Baseline | `testMacLearningBodyEditingPreservesResultRestartAndSource` |
| Baseline | `testMacLibrarySearchMetadataUnicodeEmptyNoResultsAndRestart` |
| Baseline | `testMacLibrarySearchUserNoteSavedLocalMockAIAndExactSource` |
| Baseline | `testMacMarkdownImportSelectionNotesNavigationAndRestart` |
| Baseline | `testMacPDFBodyEditingCancelDraftRestartEmptyAndSource` |
| Baseline | `testMacPDFBodyEditingDiskFailureKeepsDraftAndExplicitRetry` |
| Baseline | `testMacPDFPageCancelStopsRemainderAndReopenKeepsAttemptCount` |
| Baseline | `testMacPDFPageScanAndOversizeRefuseWithoutSend` |
| Baseline | `testMacPDFWholePageOfflineConsentBilingualNotesAndSourceReturn` |
| Baseline | `testMacTXTImportSelectionNotesNavigationAndRestart` |
| Web archive | `testMacMHTMLImportSelectionNotesNavigationAndRestart` |
| Web archive | `testMacReadableXMLImportSelectionNotesNavigationAndRestart` |
| Web archive | `testMacXHTMLImportSelectionNotesNavigationAndRestart` |
| CBT | `testMacCBTImportSpreadsDirectionPageJumpAndRestart` |

## Required later isolated exact-candidate CI

1. Check out the delivered final SHA in a disposable CI workspace. Rebuild all existing pinned text/comic/EPUB/DOCX resources and original fixtures with the existing workflows; require a clean generated diff and unchanged source/83-definition guards.
2. Run the complete unfiltered Swift package suite in the isolated environment, including the 13 deferred NSWindow methods. Record all selected/skipped methods; no local selected-test pass is a substitute for this run.
3. Run the **entire 33-method Mac application UI suite** with all original assertions, source/progress/note/cover/restart checks, 180/240-second limits and no only-testing subset. Keep fresh UUID temporary stores and an isolated machine/bundle context. Use the existing ad hoc test runner signing in CI; current local builds were unsigned and did not execute the runner. Record the exact SHA, toolchain, per-method results and xcresult evidence. No push or CI dispatch was performed here.
4. Confirm web-to-CBZ/CBT and PDF/EPUB transitions, real picker/selection/sheets, complete text source return and progress, CBT malformed refusal/raster/order/direction/restart and independent automatic/custom cover ownership. Additional joint app assertions may be added by the later CI owner if runtime evidence requires them; the present two repository/engine regressions cover the mixed-store invariant locally.
5. Keep mobile compile evidence separate from mobile reading/device acceptance, and resolve any shared-file conflicts when Bookno/ebook are later integrated serially. They are not included in this candidate.

## Scope transparency and remaining blockers

The prior web worker's historical 201-test full run did execute existing hidden-window unit tests. On review in this task, that fact was disclosed to the coordinator: it is **not** evidence of a no-window run and is not reused as current authorized UI validation. The CBT worker separately records its earlier hidden-window filter deviation and corrected offline run in [COMIC-ARCHIVE-VALIDATION](COMIC-ARCHIVE-VALIDATION-2026-10-04.md). Those historical worker records are preserved; this joint run explicitly excludes every known window body. No app/desktop UI launch occurred in this integration.

No approval was rejected for this local joint work. No main/worker checkout, push/merge/remote Git, Library service, private books, real keys/API, new dependency, Bookno/ebook integration, signing account or release was changed/accessed. Existing standalone full-project security remains **UNVERIFIED / platform-blocked**; this task does not retry or bypass that review. Full 33-method UI, deferred window tests, CBR/CB7 decoder work and the individual slices' unsupported compatibility/features remain open. There is no remaining local code/build blocker to reviewing the candidate.
