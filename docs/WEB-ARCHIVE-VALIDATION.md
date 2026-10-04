# Web archive formats: local functional validation

2026-10-04, branch `feature/web-archive-formats`, accepted base `f3ed484fee815effed2d955f8eb21bcd66d8546e`. Runtime implementation and local checks passed. Full native UI acceptance is **NOT-RUN**, reserved for later isolated CI. Separate independent security review remains **UNVERIFIED / platform-blocked**; no denied specialist/audit action was retried or bypassed.

## Observed results

| Check | Result / precise scope |
| --- | --- |
| New format tests | PASS:8 tests in2 suites. Six Swift service/persistence tests plus two actual unattached-WebKit/Kookit/library tests, each exercising all applicable formats; no desktop UI or PDFno.app launched |
| Complete Swift package | PASS:201 tests in31 suites, final run3.705s after build. Includes all existing PDF/EPUB/DOCX/comic/storage/AI/text/chapter/cover/search/note regressions, temporary stores and intercepted transports |
| Mac app and native UI target | PASS: unsigned `build-for-testing`, **TEST BUILD SUCCEEDED**. Three new complete application flows compiled; never executed locally |
| iPhone/iPad simulator product | PASS: unsigned generic iOS Simulator **BUILD SUCCEEDED**, both device families retained. New formats remain Mac-only UI; no simulator/device launched |
| Native source guard | PASS:324 tracked/untracked source files after this validation document, original fixture/private-material/domain/product checks. This is the existing narrow functional/source guard, not an independent security verdict |
| Requirements ledger | PASS:8 regression tests;83 formal IDs/definitions retained. Matrix changes do not insert spec lines, so ledger bytes remain unchanged |
| Diff/provenance boundary | PASS: `git diff --check`; unchanged engine-build inputs/locks, all existing reader resources, Xcode project/generator. Four retained Kookit text/reference inputs match their existing pinned Git blob identities |

Toolchain: macOS27.0 (26A428), arm64; Xcode27.0 (27A266a), Swift6.4. Existing AppIntents metadata extraction warnings say no AppIntents.framework dependency is present; no new compile error remains. Oldest supported OS/Intel/device/signed sandbox behavior is not established by these builds.

## Reproduction

Run from this branch's worktree. Builds do not start the app:

```sh
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/WebArchivePackage --filter 'WebArchive.*Tests'
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/WebArchivePackage
python3 scripts/check-native-source.py
python3 -B scripts/test-requirement-ledger.py
git diff --check
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/WebArchiveMac CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/WebArchiveMobile CODE_SIGNING_ALLOWED=NO build
```

Local final raw logs are `/tmp/pdfno-web-archive-all-swift.log`, `/tmp/pdfno-web-archive-mac-build.log`, `/tmp/pdfno-web-archive-mobile-build.log`; focused initial runtime evidence is `/tmp/pdfno-web-archive-focused-tests.log`. They are local ephemeral evidence, excluded from Git, and contain only original test/build information. The complete Swift run also covers the final XML refinements and additional original PNG/opaque JPEG boundary assertions beyond the first focused run.

## Meaningful assertions and fixture provenance

All new fixtures are inline self-authored text/MIME bytes in `OriginalWebArchiveFixtures`, `WebArchiveFormatTests`, `WebArchiveBridgeTests` and the three NativeUITests functions. No new opaque book/archive fixture is committed and no original fixture inventory exemption is added.

- XHTML: default/prefixed real namespace, strict well-formedness, UTF-8/UTF-16LE/BE, XML/meta declarations matching bytes, entity/CDATA escaping, semantic emphasis/headings, stripped events/URLs/scripts/head metadata. Refuses external/internal DTD/entities, unknown/foreign namespaces, malformed tags, duplicate/missing body, stylesheet processing instructions and empty content.
- Readable XML: documented document/section/title/paragraph profile; actual two-level directory; unchaptered content stays readable with empty outline. Refuses data/invoice/unknown schemas, unsupported nesting/empty documents, out-of-budget depth and encoding mismatches. CDATA containing literal markup/charset text is not misclassified as a declaration.
- MHTML: one root and explicit start selecting a nonfirst root, Content-ID/location duplicate/missing refusal, charset and BOM agreement, base64/8bit/7bit/quoted-printable/soft breaks, header folding, boundary/closing validation. Refuses malformed transfers, duplicate parameters/headers, nested/alternative/message/JavaScript/SVG/font/unknown parts, unsupported Content-Encoding, missing selected root, multiple HTML bodies, file locations, nonempty epilogues and64-part/1MiB-part/4MiB-source overruns. CSS remains opaque nonrendered input.
- Real engine: each new format runs the unchanged fixed Kookit HTML bundle; actual live DOM matches the native canonical DTO, h1/h2 outline and original Unicode/emoji/decomposed spelling. DOM has no source URL/event/script/image resource nodes; resource performance entries contain only the allowlisted local engine. Tests do not use a remote page request to prove refusal.
- End-to-end local persistence: actual DOM selection captures exactly `window`; saved notes, different chapter progress, precise source return after resizing, cross-block anchors, split-surrogate refusal, original-byte preservation, close/reopen restoration and per-format/hash identity all pass. The library routes all three extensions and never exposes a hidden PDF/EPUB selection/page/chapter AI source; switching to PDF and reopening restores the correct text book/note/progress.

Prepared/compiled native UI cases are `testMacXHTMLImportSelectionNotesNavigationAndRestart`, `testMacMHTMLImportSelectionNotesNavigationAndRestart`, `testMacReadableXMLImportSelectionNotesNavigationAndRestart`. They reuse the original text-format native picker/library/grid/list/selection/notes/directory/progress/restart helper with fresh temporary files and stores. **Compilation is not picker, mouse selection, sheet or restart runtime acceptance.** Existing and new complete app UI must run later on an isolated machine/final integrated SHA, never alongside the owner's live bundle identifier.

See [format boundaries and shared conflict list](WEB-ARCHIVE-FORMATS.md). No push/merge/main/shared Library/real book/key/API/new dependency/release or independent audit was performed. No remaining blocker to the local commit; complete UI, mobile reading, arbitrary XML, nested/legacy MHTML, layout/assets, accessibility and distribution remain explicitly unverified or unsupported.

Final raw-log SHA-256 identities:

- `pdfno-web-archive-all-swift.log`: `f3c0b8fb867758861b50c9cecad818a77ac18b0ee35d5ae69cad4341e032b86e`
- `pdfno-web-archive-mac-build.log`: `2a86e13075e1a150e4d26a0f54b4c8e625062bebbee6384e6f39d1cc57b03680`
- `pdfno-web-archive-mobile-build.log`: `81d4d2f20491154ab7cf2adb85de2b937960cc7e51fd4a2ced6d12fb216b97ac`
