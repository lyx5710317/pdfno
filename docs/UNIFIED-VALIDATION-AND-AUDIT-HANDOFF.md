# Unified acceptance and independent code-audit handoff

Date: 2026-10-03. Scope: the four current slices are integrated; independent whole-project audit has not run. The final delivery must identify its full Git commit and the complete CI runs for that same commit. The user's requested independent review begins after the current four slices are complete and the source is frozen. Stop new feature development at that boundary.

## Review scope

Review the entire accumulated application, build graph, bundled resources, local storage and dependencies at the frozen commit, rather than only the latest feature diff. Include:

| Area | Sources and required review |
| --- | --- |
| Native products | `apple/PDFno.xcodeproj`, shared schemes/workspace and `scripts/generate-apple-project.py`; two real app targets, separate UI-test products, platform gates, unsigned/ad hoc development setup, no account/entitlement/container changes |
| Domain and persistence | All `PDFnoDomain`/`PDFnoServices` sources; PDF/EPUB/comic/DOCX/learning manifests, source identities, strict decoding, original hashes, backups/atomic installation, resource bounds, cancellation, downgrade behavior and cross-process limitations |
| PDF and reading surfaces | All `PDFnoReaders`/`PDFnoUI` sources; PDFKit selection/page extraction/annotations, source return, exclusive format switching, native sheets/file panels, accessibility and unsupported-capability reporting |
| Web content | EPUB, Comics and DOCX resources plus corresponding `engine-build` sources; native preflight, canonical text, bridge allowlists/identity/generation, CSP/content rules, script/resource/navigation refusal, image admission, browser-only conversion and process termination |
| AI and credentials | Every provider/coordinator/transport/model/store; exact scope/consent, separate selection/probe/page quotas and credentials, redirect refusal, response bounds/strict source echo, cache identity, failure/cancel handling and manual note writes |
| Conversion | Independent finite DOCX body exporter, read-only input, original/output preservation, resource budgets, detached worker cancellation, no-replace atomic commit, symlink/race refusal and staging cleanup |
| Dependencies and licenses | Root LICENSE/notices; every vendor manifest/source hash, npm lock/integrity, build-input inventory and actual bundled dependency/license text. Recheck Rangy's actual dangerous-key guard; npm audit alone is insufficient |
| Tests, docs and migration | All Swift/Node/UI tests, original generators/fixtures, both workflows, requirement coverage, current-vs-historical evidence and `NATIVE-MIGRATION.md`; preserve old user stores/source history and rollback boundaries |

The high-severity Rangy advisory found during integration is recorded in `RANGY-SECURITY-2026-10-03.md`. The official1.3.2 code/integrity and an isolated prototype-payload regression provide the patch evidence; GHSA's empty patched-version field is recorded honestly. This is a specific repair, not the requested whole-project security/license audit. No user's key, book, running bundle or historical exploitation was inspected.

Record findings with severity, exact file/line, concrete trigger/reproduction, effect, current reachability/uncertainty, remediation and verification. Report an actual high-risk finding immediately and halt affected delivery until repaired or explicitly resolved. Distinguish code review, executable acceptance, service/quality evidence and release readiness.

## Safe, reproducible validation

Use a disposable checkout of the frozen commit. The existing Mac bundle identifier is shared with the owner's running app. Full app UI tests launch/terminate that identifier: execute them on isolated GitHub CI, a disposable VM or a separate OS user with no live PDFno session. A temporary book-store UUID alone does not isolate the application process. The user's existing bundle and Xcode-generated workspace metadata were preserved during integration.

Use Xcode16.4+ / Swift6, Node22+ and Python3. Record actual versions/OS/architecture. Local verification used Xcode27; CI uses macOS15/Xcode16.4. Neither establishes the oldest supported OS, Intel distribution, physical iPhone/iPad or signed sandbox acceptance. Node is build-only and is not an application runtime.

Build-only and Swift-package checks can use fresh products without starting the app:

```sh
mkdir -p .build/Audit
xcodebuild -version
swift --version
node --version
python3 --version
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/Audit/Package
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Audit/Mac CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- build-for-testing
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/Audit/Mobile CODE_SIGNING_ALLOWED=NO build
python3 scripts/check-native-source.py
git diff --check
```

Swift tests use original/synthetic content, intercepted transports and their own temporary repositories. Real WebKit package tests may create hidden original-fixture host objects; they do not automate the owner's application. Do not supply real credentials, user documents or persistent-store paths.

Reproduce licensed resources and original fixtures in that disposable checkout, with lifecycle scripts disabled and fresh empty npm configs:

```sh
touch .build/Audit/npm-user.conf .build/Audit/npm-global.conf
NPM_CONFIG_USERCONFIG="$PWD/.build/Audit/npm-user.conf" NPM_CONFIG_GLOBALCONFIG="$PWD/.build/Audit/npm-global.conf" NPM_CONFIG_CACHE="$PWD/.build/Audit/npm-cache" npm ci --prefix engine-build --ignore-scripts --no-audit --no-fund --registry=https://registry.npmjs.org
node --test engine-build/loader.test.mjs engine-build/rangy-security.test.mjs engine-build/comics-reader.test.mjs engine-build/docx.test.mjs
node engine-build/build.mjs
node engine-build/build-comics.mjs
node engine-build/build-docx.mjs
python3 scripts/generate-apple-project.py
python3 scripts/generate-epub-fixture.py
python3 scripts/generate-docx-fixture.py
node engine-build/generate-docx-extraction.mjs
python3 scripts/generate-original-fixture-inventory.py
python3 scripts/check-native-source.py
git diff --exit-code -- apple engine-build scripts
```

Preserve original third-party license bytes, including upstream whitespace. Confirm reproducibility with Git's byte comparison; `git diff --check` is cosmetic and does not replace source/license checks. A fresh `npm audit --json` may be recorded with its date and complete dependency graph; its database result is not a comprehensive vulnerability assessment.

On the isolated UI machine only, run the complete existing scheme; do not filter out old flows or replace failures with skip/expected-failure declarations:

```sh
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Audit/Mac -resultBundlePath .build/Audit/Full-Mac.xcresult CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- -parallel-testing-enabled NO -test-timeouts-enabled YES -default-test-execution-time-allowance 180 -maximum-test-execution-time-allowance 240 test
```

Keep original logs/result bundles outside Git. Publish the exact SHA, workflow links, observed counts/failures, meaningful assertions and explicit unrun items. A passing older SHA, compile-only result or offscreen bridge test cannot stand in for this complete app run. Current failed-run diagnosis and strict test-navigation/synchronization repairs are retained in `VALIDATION.md`.

## Original fixture inventory

No third-party book, proprietary UPDF resource, user document, embedded font or real key is a fixture. Inventory every frozen tracked fixture's relative path, byte size, SHA-256, generator and purpose. Dynamic fixtures remain reproducible from their test source; no user data is needed.

| Fixture group | Original source and acceptance scope |
| --- | --- |
| Two-page PDF | `generate-apple-project.py`; byte-identical UI/test `study-sample.pdf`; original Latin text/outline/geometry, PDFKit selection/highlights/progress/return. Standard Helvetica name only, no embedded font |
| Reflow EPUB | `generate-epub-fixture.py`; UI/test `study-sample.epub` and hostile `security-sample.epub`; original English/Japanese/ruby/emoji/combining/repeated text and inert script/network payloads |
| Word corpus | `generate-docx-fixture.py`;21 archives in `Fixtures/DOCX`, plus UI copy of `mammoth-sample.docx`; headings/list/table/emphasis/hyperlink/stored/descriptor and bounded ZIP/XML/path/CRC/entity/macro/encoding cases |
| Word canonical DTO | `generate-docx-extraction.mjs`; `mammoth-extraction.json` from the actual pinned/sanitised engine, not the old native parser |
| Comic unit/WebKit/app fixtures | `ComicTests.swift`, `ComicWebKitTests.swift`, `comics-reader.test.mjs`, `NativeUITests.swift`; original raster colors/geometry, ZIP records, natural ordering, portrait/landscape/cover/odd spreads, stale/network/script refusal and corrupt archive |
| Finite converter fixtures | `ConversionTests.swift` and UI `originalConversionFixture`; original in-memory OOXML plus malformed/budget/race/symlink/cancellation inputs; successful output compared byte/content-wise, original unchanged |
| Current-page PDF fixtures | `PDFPageTranslationTests.swift` and `OriginalPageTranslationUITestPDF.swift`; original blank, complete multi-segment, over-budget and Unicode/grapheme cases. Runtime fixture PDFs are not added as unknown binary books |
| AI and repository contracts | All AI/storage test files and `OfflineSelectionUITestTransport`; synthetic keys/responses, forged/stale identities, complete scoped bodies, redirect/cancel/timeout/cache/schema refusal and separate user text |

The explicit28-copy [path/size/SHA-256/generator inventory](../scripts/ORIGINAL-FIXTURES.json) covers the complete committed original corpus and is regenerated by `generate-original-fixture-inventory.py`; the main guard independently restricts exactly these approved paths. Any additional binary requires individual provenance approval and deterministic regeneration; never weaken the source guard to allow arbitrary ZIP/DOCX files.

## Remaining acceptance boundaries

Pending independent whole-project audit and unified acceptance must be reported separately from integration regressions. Mobile EPUB/comic/DOCX/AI/convert UI, true translation/grammar quality and billing, comprehensive extraction/layout/Word compatibility, oldest OS/Intel/real devices, VoiceOver/keyboard/Pencil, high-volume/performance/crash/filesystem/file-provider tests, cross-process writes, Bookno API, iCloud, OCR, persistent Keychain and the seven high-fidelity PDF/Word/EPUB conversion directions are unverified or unimplemented. Long-term Mac/iPhone/iPad, all18 reading extensions and future comic AI remain confirmed targets.

Downgrade preserves complete originals/manifests/backups and user notes. `docx-mammoth-v1.json` does not auto-migrate the old `docx-v1.json`; old AI builds reject the added page anchor/prompt instead of overwriting learning data. Repository history and migration backups are retained. No release, account/container change, forced push or user-data migration is implied by ordinary development commits.
