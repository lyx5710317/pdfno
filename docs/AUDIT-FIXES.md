# Audit remediation on the frozen 05cbcf5 baseline

This local branch starts at `05cbcf537e0ae85b2831a6b86e500e5d7d2b0a94`. The frozen main branch and both auditors' reports, sources and evidence stay unchanged. This record does not constitute independent revalidation, complete UI acceptance or permission to publish.

Original independent report identities:

- Security/license report: 32902 bytes; SHA-256 `5f860f2cc8f0e0c3ea02b073eaf7a34f0a5471e0f5f09dc24cc3cb7278fb8f6a`.
- Data/functional report: 52747 bytes; SHA-256 `ed0bbbf97baf4382a5d65f4dec50281015bb74b94821f7562540ce0c6739c582`.

| Independent finding | Remediation status | Required verification |
| --- | --- | --- |
| F01 / DF-03: output-directory race (one defect) | Locally repaired | Original swap reproduced on baseline; directory descriptor, device/inode checks, `openat`/`linkat`/`unlinkat`; unchanged originals/sentinels and cleanup after stage creation |
| F02: DOCX table quadratic cost | Local candidate repaired | Once-built table/row/cell Maps and1,000,000 visit budget; actual4000-row Mammoth DTO unchanged; unattached real reader and close fence |
| F03: EPUB sanitization MIME/extension split | Local candidate repaired | Fail-closed suffix profile on both text/blob routes; OPF MIME agreement, namespace/PI checks; Node and real hidden reader refusals |
| F04: complete reads before budgets | Local candidate repaired | Shared descriptor/fstat regular-file reader,64KiB chunks/limit+1, five manifests/backup gates, PDF/EPUB originals, DOCX/CBZ inputs; growth/rename/symlink/FIFO/directory tests |
| F05: model recreation resets app-session budgets | Local candidate repaired | Process-lifetime AppAISession counters3/3/6; recreated probe/learning/page models stop at caps with intercepted failures; model-local credentials |
| F06: mutable CI Action tags | Local candidate repaired | Official verified v4 commit SHAs; two workflows pinned; guard accepts candidates and rejects a temporary mutable-tag fixture |
| DF-01: PDF stale sidebar progress | Local candidate repaired | Flush outgoing progress, read current record by ID, update sidebar, capture session/book/page/event sequence before async UI task; real A/B/A, restart and late events |
| DF-02: duplicate moved DOCX revision text | Local candidate repaired | Exclude moveFrom with del, preserve moveTo/ins; original OOXML table+Unicode tested in TXT/HTML; no engine replacement |
| DF-04: EPUB long-paragraph/Unicode progress | Local candidate repaired | Visible-scalar binary search and Range pagination geometry; surrogate-safe spans; explicit native null clearing; real horizontal/vertical pages2/3, resize, reopen and ruby/orientation regressions |
| DF-05: drafts tied to transient reader identity | Local candidate repaired | Draft key retains book/edition/hash/extraction/anchor text/offsets; excludes reader session/version and EPUB orientation; real PDF reopen, EPUB reflow identity and existing late-result isolation |
| DF-06: PDF aggregate quote not verified | Local candidate repaired | Match ordered non-whitespace scalars without hyphen/Unicode normalization; raw forms retained; geometry still verified; forged refusal and real multiline/multipage acceptance |
| DF-07: requirement accounting | Local candidate repaired |83 original formal rows in REQUIREMENTS-LEDGER.json; explicit legacy UI/AI/A scope; duplicate/count/definition guard; no invented or removed IDs |

## F01 / DF-03 evidence and remaining limits

The corrected-behavior regression first failed against the unchanged frozen service: it returned a completed30-byte result in the replacement directory. Log: `/tmp/pdfno-audit-fixes-05cbcf5-red.log`. A fixture Sendable capture compilation error occurred first and is not counted as a runtime reproduction.

The repaired service pins the selected parent before reading, inspects the final name relative to it, and keeps that descriptor through staging, atomic no-replace installation and cleanup. Read-only device/inode checks reject observed pathname replacement. The writing phase now starts after exclusive0600 staging creation, so replacement/cancellation regressions also test cleanup of an actual existing staging file. No final or staging path mutation resolves through the replacement parent. A final parent symlink is rejected; existing ordinary ancestor symlinks may resolve during initial pinning, after which identity and all mutations stay tied to that descriptor.

`ConversionDestinationTests` has five methods/eight argument cases: writing-time symlink/plain-directory/ancestor swaps, reading/validation swaps, cancellation after a staged-file swap, initial parent-symlink refusal and ordinary Unicode success. Together with all17 existing conversion methods, **22 methods passed / two suites /0.089s**, including existing leaf collisions, dangling links, retry, every cancellation phase and post-commit completion. Log: `/tmp/pdfno-audit-fixes-05cbcf5-conversion.log`. New fixture parameter visibility was corrected after an initial compilation failure; no assertion or production limit was weakened.

An attacker who can continue renaming directories after the last identity check or after commit can still change the displayed pathname; the output operations nevertheless remain in the originally pinned directory. This is not a proof against arbitrary same-user file tampering, privilege escalation or all File Provider behavior. Signed sandbox/provider, power-loss/crash and actual app UI revalidation remain pending. No owner app, private book or real credential is involved.

## Candidate implementation and regression map

All entries below describe local candidates awaiting the original independent auditors. The original reports remain immutable. F01 and DF-03 are one finding, giving12 unique confirmed findings, rather than13 repairs. The first directory fix is commit `532f0ad23867cc167417cf20dcea6f89e873c06f`; the complete fixed candidate is identified by the handoff Git SHA, not by a mutable branch name.

| Finding | Main implementation | Direct regression/evidence |
| --- | --- | --- |
| F01 / DF-03 | `DocumentConversionService.swift` | `ConversionDestinationTests`: observed directory replacement, actual staged-file cleanup, cancellation and Unicode success; baseline corrected-behavior test failed before repair |
| F02 | `engine-build/docx-adapter.js`, rebuilt DOCX resource | `docx.test.mjs`: genuine4000-row OOXML/Mammoth, nested tables, fixed original DTO and browser bundle; `DOCXBridgeUnitTests.original4000RowArchiveUsesActualHiddenEngineAndCancellationFence` |
| F03 | `engine-build/loader.js`, rebuilt EPUB resource | `loader.test.mjs`: `.content`/SVG refused through both routes, MIME agreement; `EPUBWebKitTests.surrogateBoundaryHasReadableProgressAndUnsupportedMIMERoutesFail`: genuine reader refusal for nonstandard/MIME/SVG, foreign namespace and processing instruction cases |
| F04 | `BoundedFileReader.swift`, five repositories, PDF/EPUB import, DOCX/CBZ readers | `BoundedFileReaderTests`: regular descriptor, size+1, symlink/FIFO/directory, concurrent growth/path replacement, five oversized manifests and unchanged backup sentinel,200MiB PDF/20MiB EPUB before hash |
| F05 | `AppAISession.swift`, `DeepSeekSelfTest.swift`, learning/page/probe models, LibraryModel injection | `AppAISessionTests`: recreated actual models and synthetic intercepted failures produce exactly3/3/6 sends; existing timeout/cancel/late-output tests remain; counters contain no credentials |
| F06 | `.github/workflows/checks.yml`, `comics.yml`, source guard | Official v4 tag/commit identity verification; a temporary `checkout@v4` fixture failed the real guard and was removed; normal candidates pass |
| DF-01 | `LibraryModel.swift`, `LibraryModel+Comics.swift`, `LibraryWorkspace.swift` | `AuditFunctionalTests.latestPDFProgressSurvivesStaleSidebarReopenAndLateSave`: real two editions, A/B/A, sidebar refresh, captured old session/event refusal and restart |
| DF-02 | `DOCXTextConversionAdapter.swift` | `ConversionTests.acceptedMovesExcludeOldLocationInTextAndHTML`: `moveFrom`/`moveTo`/`ins`/`del` within original table, Unicode, both outputs and unchanged input hash |
| DF-04 | `engine-build/reader.js`, `EPUBReaderSession.swift`, rebuilt resource | `EPUBWebKitTests.longParagraphSecondAndThirdPagesRestoreExactVisibleOffsetsAndReopen`: genuine long single paragraph, horizontal and vertical pages2/3, real changed viewport, exact selection text and reopen; surrogate boundary and existing ruby/orientation/stale tests |
| DF-05 | `AILearningModel.draftKey` | `AuditFunctionalTests.realPDFSelectionDraftReturnsAcrossReaderSessionsWithoutRelaxingFence`, `EPUBDraftIdentitySurvivesReflowAndVerticalChangeButSeparatesOffsets`; existing uncooperative late-output tests unchanged |
| DF-06 | `PDFSourceAnchor.hasConsistentQuote`, PDFKit resolution, AI source and repository validation | `AuditFunctionalTests.forgedAggregateQuoteFailsRealPDFKitAndAIWhileMultilineRemainsValid`, `inconsistentStoredQuotePreservesManifestAndBackup`: forged refusal, real two-page/multiline acceptance, original bytes and backup preserved |
| DF-07 | `REQUIREMENTS-LEDGER.json`, specification/status/validation count corrections, source guard |83 unique formal definitions parsed from the exact preserved original table rows, including J01–J08 labels; guard checks category set/count/duplicates and original row text |

## Verification on the local candidate

Final full Swift result: **116 methods /18 suites passed /2.320s**, with no skipped suite. The frozen baseline had98 methods /14 suites. Additions are5 conversion-destination methods,1 accepted-move method,2 EPUB methods,1 large-DOCX reader method,3 bounded-file methods,5 functional methods and1 app-session method, totaling18 new methods. Parameterized argument cases are not additional method counts.

All **14 Node tests passed /0.585s**: original11 plus one admission test and two actual DOCX table tests. The actual Mammoth chain is retained. On the identical2022-byte original4000-row input, a read-only baseline/candidate comparison measured **9508ms →226ms**, and both actual-engine document DTOs had SHA-256 `822a80e0f5dae6e9d74d7840eabb1631c345f4a3d4b7b64338be18451227bd81`. These timings describe this machine/run, not a universal performance guarantee. No comparison changed the frozen source or the auditor's original fixture.

Both native targets built successfully with signing disabled: Mac and the generic iOS Simulator app supporting iPhone/iPad families1,2, using `.build/AuditFixMac` and `.build/AuditFixMobile` in this worktree. No application or simulator was launched. Project/schemes, original fixture inventory/bytes, vendored source/lockfiles, bundled input/dependency manifests and the user's workspace metadata stayed unchanged. EPUB/DOCX resources were rebuilt by their existing builders with the same licensed inputs; AGPL and notices remain in place.

Local logs, retained outside committed source:

- `/tmp/pdfno-audit-fixes-full-swift-final.log`
- `/tmp/pdfno-audit-fixes-full-node.log`
- `/tmp/pdfno-audit-fixes-mac-build-final.log`
- `/tmp/pdfno-audit-fixes-mobile-build-final.log`
- `/tmp/pdfno-audit-fixes-performance-comparison.log`
- `/tmp/pdfno-audit-fixes-action-guard.log`
- `/tmp/pdfno-audit-fixes-keychain-restricted-final.log`
- `/tmp/pdfno-audit-fixes-restricted-subset-final.log`

The source/fixture/privacy, formal-definition and full-SHA Action guard and `git diff --check` pass. The candidate has no new binary fixtures: additional EPUB/DOCX/ZIP/PDF cases are generated from original test content in memory or fresh temporary directories. The live user app and its build directory, user documents, credentials, real APIs and model billing were never inspected or operated.

## R01: preserve the actual Keychain environment difference

The independent functional audit/CI recorded **98/98 full baseline methods**. The independent security audit explicitly excluded6 WebKit methods across EPUBWebKitTests, ComicWebKitTests and DOCXBridgeUnitTests, leaving **92 methods,91 passed and1 failed**. That failure was the original `LAContext.interactionNotAllowed == true` assertion. It is not evidence that98 methods were independently passed by the security auditor.

We ran the same compiled candidate and original Keychain assertion in two execution contexts: the restricted executor returned `false` and failed; the approved local execution context returned `true` and passed. Candidate `AICredentials.swift` is byte-identical to the frozen source, and the Keychain test's assertion/query construction is unchanged. The test uses a fake exact-reference store and an authentication-context/query dictionary; it does **not** perform a real SecItem read/write, display a Keychain prompt, inspect any credential or prove signed persistent-Keychain behavior. We do not replace, relax, skip or xfail that assertion to claim success. The precise OS/daemon mechanism is not established by this observation; signed persistent-Keychain/OS acceptance remains pending.

The repaired candidate has9 WebKit methods: the original6 plus2 EPUB and1 DOCX. Its analogous restricted subset therefore has107 methods, rather than92: **106 passed /107, one unchanged Keychain assertion failed /0.614s**. Its exact result is retained in the restricted-subset log; full116/116 is the separately identified approved local context result.

## Formal accounting and preserved legacy references

The formal set is **R01–R17 (17) + T01–T22 (22) + U01–U13 (13) + S01–S08 (8) + J01–J08 (8) + UAT01–UAT15 (15) =83**. The original77 rows plus native R15–R17/T20–T22 added6, giving83. `REQUIREMENTS-LEDGER.json` retains every original definition and baseline audit assessment; those assessments are historical baseline evidence, not a claim that all requirements are implemented by this patch.

The prior95-token result mixed83 formal IDs with7 legacy UI01–UI07 IDs,3 AI01–AI03 IDs and the two matched endpoints A00/A15. **A00–A15 denotes a16-task legacy range**, not two additional formal requirements. All legacy references and their original specification content remain; no missing task-card text is invented and no ID is renamed/deleted. Reading's18 extension targets and conversion's7 fidelity directions remain separate matrices. Some formal U/J rows record competitor observations and intended flows, not implemented feature acceptance.

## Official Action identities and remaining acceptance gates

Read-only official GitHub tag and commit metadata verified on2026-10-03:

- [actions/checkout v4 commit](https://github.com/actions/checkout/commit/11d5960a326750d5838078e36cf38b85af677262), GitHub signature verification reported valid; backported v4 fixes. Pinned `11d5960a326750d5838078e36cf38b85af677262`.
- [actions/setup-node v4 commit](https://github.com/actions/setup-node/commit/49933ea5288caeca8642d1e84afbd3f7d6820020), GitHub signature verification reported valid; cache dependency update. Pinned `49933ea5288caeca8642d1e84afbd3f7d6820020`.

No current remote CI, signed app UI or independent re-audit has run on this local candidate. Remote CI requires a separately authorized publishing step. The frozen main SHA and both independent audit report hashes stay unchanged. No push, main merge, account/permission/container change, user-app control or shutdown is performed.

The EPUB content admission is intentionally fail-closed: nonstandard XHTML suffixes, MIME mismatch, SVG resources, foreign namespaces and processing instructions are unsupported by this bounded profile. This repairs a raw-load route; neither the original finding nor these tests demonstrate successful XSS, network exfiltration or a sandbox escape. Broader EPUB/image/font/fixed-layout/platform compatibility still requires the original acceptance matrix.

The PDF aggregate relationship permits PDFKit whitespace separators while preserving both raw strings; it does not normalize hyphens or other Unicode scalars. Existing inconsistent records are refused with originals/backups preserved; a full rotated/CropBox/hyphenation/complex-order selection matrix remains pending. Unsaved drafts remain in memory within the learning model; this patch does not introduce cross-process draft persistence.

The large-DOCX tests exercise actual WebKit/Mammoth output and native close-generation cancellation. They do not claim that cancellation can preempt an already-running synchronous JavaScript instruction. Structural/text/work budgets and linear indices bound this path; broader worst-case engine/OS tests remain part of revalidation.

Security report R02 remains a **formal distribution/license gate**, not a demonstrated published violation: interactive notices/corresponding-source/install-information obligations must be satisfied before release. This local audit remediation does not add a release feature or change the AGPL decision. No new feature, engine replacement or privilege is approved by the regression results.
