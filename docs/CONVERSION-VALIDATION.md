# Local conversion validation — 2026-10-03

The independent conversion branch, based on `aaba190a878df9de5674491d20f1b36fa4733607`, implements DOCX body text → UTF-8 TXT / standalone escaped HTML. It is a local export operation with a new output location and does not modify a book store. [ADR 0009](ADR-0009-LOCAL-CONVERSION.md) records direction feasibility, selected licenses, safety and quality limits.

## Actual results

| Check | Result and scope |
| --- | --- |
| Shared Swift package build | Passed with `.build/ConversionPackage`; final full test compilation includes the native conversion window |
| New conversion suite | **17 tests passed**, including parameterized stored/deflated and four-stage cancellation cases. All input archives are generated in memory from original synthetic XML |
| Full Swift regression | **61 tests in 9 suites passed, 0 failures**, 0.778 seconds on the final run; includes the existing PDF, EPUB/WebKit, repositories and intercepted AI tests |
| Native Mac build | **BUILD SUCCEEDED**, unsigned Debug app in `.build/ConversionMac`; system zlib and new SwiftUI/AppKit entry link successfully |
| Common iPhone/iPad Simulator build | **BUILD SUCCEEDED**, unsigned generic Simulator target in `.build/ConversionMobile`; shared service compiles, conversion UI is Mac-only |
| Source/provenance and patch guard | `check-native-source.py` and `git diff --check` passed. Checked 141 source files. No external Swift dependency, binary DOCX fixture, build log, key or private document is a deliverable |
| Project/resource regeneration | `generate-apple-project.py` regenerated project, schemes, workspace and both original PDF copies byte-for-byte; tracked project/resources/fixtures diff was empty |
| Desktop acceptance | Deliberately not run: no user-app launch/replacement or desktop UI test. Native model state is tested in process; system save-panel/Finder interaction is not accepted as tested |

Toolchain: Xcode 27.0 (`27A266a`), Swift 6.4, Apple SDK 27.0; deployment settings remain macOS 14 / iOS 17. Success on this toolchain is not oldest-system acceptance. Both app builds produced the existing benign metadata-extraction warning because they do not depend on AppIntents; no converter compilation/link warning was reported.

The first test compilation failed on one missing `try` annotation inside an `#expect` expression; it was corrected before the passing runs. The initial new suite passed 16 tests; a deterministic actual-caller cancellation propagation test was then added, and the final full suite passed 61 total / 17 new tests. Final review also added explicit refusal of non-UTF-8 XML declarations and unsupported embedded body parts (`altChunk` / `subDoc`), with final full regression and independent native rebuilds after those runtime changes.

## What the tests demonstrate

- Real read-only file → DOCX package validation → body extraction → new TXT/HTML output, with byte/content comparison and original preservation.
- Unicode/combining marks, paragraphs, tabs/line breaks, table-cell order, inserted/deleted revisions, cached fields and ruby-base text; the expected omissions are explicit.
- Stored/deflated ZIP, signed data descriptors and strict WordprocessingML namespace operation.
- Escaped HTML with no script/resource/link element and a restrictive CSP.
- Refusal of unsafe/duplicate paths, local-header mismatches, CRC corruption, symbolic-link ZIP attributes, unsupported flags/methods, overlapping entries, macro/external main-part metadata, missing required parts, malformed/wrong-namespace XML, UTF-16/non-UTF-8 declarations, DTD/entities, markup-alternate content and unsupported embedded body parts.
- Actual inflate output exceeding 4 MiB is stopped even when local and central declared sizes lie; entry-count and XML-depth budgets are also checked.
- Existing output and dangling symlink refusal, source symlink/non-file refusal, a destination appearing after preflight, and temporary-file cleanup after the failed commit.
- Cancellation at reading/validation/conversion/writing phases leaves no final file and permits retry. A caller task cancellation reaches the detached worker; cancellation after atomic installation reports a completed output.
- The isolated Mac model becomes ready after failure and can complete a retry. No real file panel or user's Library is touched.

## Reproduce locally

Run from a disposable checkout or the independent conversion worktree:

```sh
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/ConversionPackage --filter ConversionTests
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/ConversionPackage
python3 scripts/check-native-source.py
git diff --check
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/ConversionMac -jobs 2 CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/ConversionMobile -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

Do not infer desktop UI acceptance from compilation. Automated tests use temporary directories that are deleted after each test and original in-memory OOXML fixtures, not uploaded or private Word files. Existing EPUB WebKit tests run without desktop automation. All AI requests in the regression suite are intercepted or mocked.

Remaining gaps: oldest OS/runtime, actual NSSavePanel and Finder keyboard/VoiceOver flow, signed sandbox/file-provider access, filesystem types without hard links, full real-world OOXML object/schema compatibility, very large-file performance, precise per-object loss counts, power-loss/crash durability and durable task resumption. No T17/full conversion UAT completion, PDF-to-Word fidelity, OCR, whole-EPUB conversion, automatic edition import, external converter installation or cloud fallback is claimed.

## Coordinator integration and actual interface gate

The bounded conversion commit was reviewed and integrated after CBZ. Its shared feature-state conflict was resolved preserving CBZ, PDF/EPUB and DeepSeek. The custom OOXML body extractor is only this export direction; the separate Word reading candidates are not merged or adopted as the product engine. The combined local suite passed75 tests/11 suites; native test/mobile compilation use separate products without launching/overwriting the user's app.

The complete isolated Mac UI flow now exercises the real input picker and NSSavePanel, canceling output selection, TXT/escaped HTML byte checks, unchanged original, refusing replacement even after the system confirmation, invalid input/no output, recovery with valid input, and the native worker cancel button. Worker cancellation uses an explicit DEBUG-only checkpoint enabled only with a valid isolated store UUID and test flag; it reads the real original fixture through the production service, pauses before the real adapter, then observes actual task cancellation and absence of final/staging output. Successful paths use the real converter; no network, fake conversion result or user directory is involved. The existing deterministic service tests cover cancellation inside parse/write stages and after atomic commit. Actual eight-method UI CI outcome belongs to the final exact SHA, never inferred from compile-only evidence.

The original combined conversion UI method exceeded the180-second execution limit after successful Save cancel/TXT/overwrite/invalid-input/HTML assertions in exact run37121073922. Save/overwrite, failure-to-HTML recovery and real worker cancellation are now three independent methods with fresh original fixtures/stores. All previous assertions and the CI time limit remain; this failed run does not accept the worker-cancel UI until the complete rerun succeeds.
