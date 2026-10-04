# Ebook candidate validation and integration handoff

This is the historical module-slice report. For the new f3ed-based combined candidate, use [the dedicated integration handoff](EBOOK-INTEGRATION-2026-10-04.md) and [its evidence](EBOOK-INTEGRATION-EVIDENCE.json).

Date: 2026-10-04. Independent branch `feature/ebook-formats` from the user-specified22-UI baseline `8cf6ab8e93e057aa73a6607a17e6e2fe42269315`. No text/chapter candidate was used as a base. This report is not native UI acceptance.

## Verified offline results

- Fixed Kookit1.0.4 official nontruncated tree verified all five added blobs; generated ebook resource has four inputs and no npm runtime dependency. Actual original AGPL/MIT texts retained.
- `node --test` across loader, Rangy security, DOCX, comics, ebook extraction and native ebook bridge: **25 passed, 0 failed, 0 skipped**. Eleven are new ebook checks. They parse all four independently generated containers through the actual built bundle, exercise KF8 skeleton/fragment reconstruction, PalmDOC, ruby, emoji/decomposed accents, real DOM selection/return, cross-paragraph offsets, canonical mismatch, DRM/compression/type refusal, bounded index errors, FB2 root/entity/depth/binary refusal and absent raw TOC indices.
- EPUB/DOCX/comics rebuilt through existing builders and compared with Git: **byte-identical to the base**. A metadata placement that initially changed esbuild module interpretation was fixed by moving original package metadata outside the vendored package scope, then the comparison and all tests passed.
- `scripts/check-native-source.py`: passed, with the eight new copies explicitly admitted and hashed; original corpus now36 copies. Existing source/Unicode/data-repair contracts and the requirement ledger were retained.
- `python3 -B scripts/test-requirement-ledger.py`: **8 passed**.
- `plutil -lint apple/PDFno.xcodeproj/project.pbxproj`: passed; project generation and fixtures reproducible. Authored-source staged whitespace checks passed. A full staged `git diff --check` flags original CRLF/terminal blank lines in four preserved upstream license files (@asamuzakjp css-color, decimal.js, debug and iconv-lite); their original bytes and recorded hashes are intentionally retained. No license text was normalized.
- Host tool observations: Node20.20.2, Python3.9.6; Xcode SDK path identifies MacOSX27.0. CI targets Node22/macOS15. No oldest-OS/Intel/physical-device claim.

Logs are local diagnostics under `/tmp/pdfno-ebook-all-node.log`, `/tmp/pdfno-ebook-node.log`, and `/tmp/pdfno-ebook-build.log`, not committed or uploaded. They contain only self-authored source/fixtures. Passing jsdom checks do not establish WKWebView, CSP, actual Mac UI or native repository execution.

## Approved normal native functional follow-up

Tested source: `d28afe72d4e56fe9ff9c4d838d167b2a62754e52`, initially a clean worktree. No runtime/test-source changes were needed after the results. This follow-up commit changes only documentation/evidence.

New authorization was supplied after the assistant explicitly asked to run normal MOBI/AZW/AZW3/FB2 Swift builds and reading functional tests in an independent environment, excluding the previously blocked safety-special. The user replied “继续开发剩余的部分”. The delegated instruction supplied this full context to approval review and authorized exactly one retry of the same rejected normal `EbookTests` action; stop immediately if rejected again. Review allowed that one retry. No sandbox-disable or alternate compiler route was used.

| Normal functional action / target | Result | Scope |
| --- | --- | --- |
| `swift test --filter EbookTests`, independent PDFnoKit package | Exit 0; **5 test definitions passed**, with 4 original-format cases in admission/storage | Native format admission, retained originals, notes/progress, type/Unicode/source and existing fixture refusal contracts; no security-special suite |
| `swift test --skip-build --filter EbookReaderTests`, same package | Exit 0; **2 test definitions passed**, with 4 real WebKit format cases | Actual original-file import/Kookit parsing, directory data, real DOM selection, note store, source return, progress/reopen and active-source routing; offscreen test host only |
| `PDFnoMac build-for-testing`, macOS destination | Exit 0; **TEST BUILD SUCCEEDED** | App and old/new UI test-source compilation; no UI execution or app launch |
| `PDFnoMobile build`, generic iOS Simulator destination | Exit 0; **BUILD SUCCEEDED** | arm64/x86_64 simulator compilation; no simulator/app launch, physical device or mobile ebook-reading claim |

All four original fixture variants ran through actual offscreen WKWebView. The newly created NSApplication/NSWindow belonged to the isolated test process and the window remained invisible. No existing user app was opened, inspected, terminated or automated. Only fresh UUID test stores and original fixtures were used. Explicit SwiftPM/module/DerivedData/package/log paths were under `/tmp/pdfno-ebook-build`; WebKit/functionality and Xcode Foundation user directories were isolated with `CFFIXED_USER_HOME`, without changing `HOME`. The first single-retry invocation retained its exact explicit temporary build/cache/config/security paths. Content-rule stores still use per-session temporary directories.

Host: arm64 macOS27.0, Xcode27.0 (27A266a), Swift6.4. Existing compilation warnings were a sendable capture in `PDFPageTranslationTests.swift`, two unused `broken` bindings in old `NativeUITests.swift`, and skipped AppIntents metadata without that framework; they were left outside this slice. No ebook warning/error was observed. This is no oldest-OS/Intel-Mac/physical-device acceptance claim.

[Machine-readable evidence](EBOOK-NATIVE-FUNCTIONAL-EVIDENCE.json) records the exact command, target, exit code, source SHA and SHA-256 for each local log: `/tmp/pdfno-ebook-unit-functional.log` (captured final compile/test output; initial progress omitted), `/tmp/pdfno-ebook-webkit-functional.log`, `/tmp/pdfno-ebook-mac-build.log` and `/tmp/pdfno-ebook-mobile-build.log`. Logs are not committed or uploaded.

## Preserved platform/permission history and remaining limits

| Action / target | Observed result | Current status |
| --- | --- | --- |
| Initial sandboxed SwiftPM package build, independent worktree with paths under `/tmp/pdfno-ebook-build` | Manifest could not compile: `sandbox-exec: sandbox_apply: Operation not permitted` | Historical blocked attempt retained. The later single normal-functional retry was separately authorized, reviewed and passed; this does not validate the safety-special |
| Initial request to escalate `swift test --filter EbookTests`, same package/worktree | Automatic approval rejected a retry under the then-current preserve/no-retry instruction | Did not execute then. New explicit functional context was supplied to review once; that retry was approved and passed. No bypass or second rejected retry |
| Scratch-script static `py_compile` | Configured default `~/Library/Caches/com.apple.python/tmp/ebook-budget-fixes.cpython-39.pyc.4456865840` was denied | No shared Library cache write succeeded; no escalation/retry. Subsequent scripts use `python3 -B` |
| Previously blocked safety-special | Excluded from the new functional authorization | **UNVERIFIED**, no retry or alternate route |

The four new Mac app UI flows and full prior22-case Mac UI suite at this branch are still **NOT-RUN / UNVERIFIED**. Manual CI was not dispatched. Offscreen functionality does not establish application toolbar/focus/menu behavior, adversarial process/network/CSP security guarantees, broad external-book compatibility or mobile ebook reading. The candidate must not be described as full accepted support; original admission boundaries remain unchanged.

## Integration conflict list

No merge or checkout mutation was performed in the main tree or any other worktree, and no push/PR/merge/main/release/Library action was performed. The branch has additive Ebook* files, generated Resources/Ebooks, original samples, metadata, notices and tests. The following shared seams require manual composition with text/chapter work; this is a file/semantic conflict forecast, not an attempted merge or proof of actual Git conflict:

1. `LibraryModel.swift`: new `ebook` nested observable model, load/import branch, reader deactivation, progress/AI guards. Preserve the independent text model/routes and chapter source guards when composing; do not reuse hidden PDF/EPUB anchors.
2. `LibraryWorkspace.swift`: separate ebook list/grid rows, example menu, import UTTypes, active reader and feature-status label. Compose with text rows/picker/detail route; existing covers and all older format rows remain intact.
3. `LibraryModel+Comics.swift`, `+NoteEditing.swift`, `+Search.swift`: only deactivation/source guards changed. Preserve other candidates' additional active-reader exclusions. Ebook search/edit/AI are deliberately outside scope.
4. `Package.swift`: additive resource directories for Readers and UI. Merge with future text resource additions.
5. `generate-apple-project.py` and generated `project.pbxproj`: add a separate Mac-only `EbookFormatUITests.swift` build file. Regenerate from the composed generator; existing `NativeUITests.swift` is unchanged.
6. `engine-build/package.json`/lock: jsdom26.1.0 and39 test-only records. Existing package records are unchanged. Merge locks deterministically; keep jsdom outside product builds.
7. `generate-original-fixture-inventory.py`, `check-native-source.py`, `ORIGINAL-FIXTURES.json`: explicit eight-file allowance. Combine future text corpus entries explicitly and regenerate; do not replace the restricted inventory with a wildcard.
8. Root source/third-party notices and engine README have additive ebook sections. The main specification, requirement ledger, shared validation and existing CI workflows remain unchanged; update their accepted status only after exact-commit integration evidence.

Read-only changed-file comparison against the currently visible parallel branch tips found **9** shared changed files with text (`0bec13886f22ad3b76c553f50437ce5ff97c99dd`) and **5** with chapter (`3dcc800a7f5a292f61738003b16e8403703696b5`). Text overlap: Package.swift, LibraryModel.swift, LibraryWorkspace.swift, LibraryModel+Comics/+NoteEditing/+Search.swift, engine README/package/lock. Chapter overlap: those five LibraryModel/Workspace/extension files. This compares changed paths against the same baseline, not a merge simulation. Existing non-root npm lock entries were independently compared to the base and none changed. The main checkout remains at its original `05cbcf537e0ae85b2831a6b86e500e5d7d2b0a94` with the same pre-existing untracked workspace metadata.

The new manual `.github/workflows/ebooks.yml` can run the isolated candidate checks after authorized publication to CI; no dispatch/push was made. Complete existing unfiltered CI before merging the branch. Keep originals, `ebook-kookit-v1.json`, backups and notes on downgrade; older apps do not open this independent manifest and must not delete it. No automatic data migration is included.
