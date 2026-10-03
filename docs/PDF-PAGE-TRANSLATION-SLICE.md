# Mac PDF current-page translation slice

Date: 2026-10-03. The bounded page command is integrated in main with CBZ, finite DOCX export and the actual Mammoth Word reader. Historical branch: `feature/page-translation`, base `aaba190a878df9de5674491d20f1b36fa4733607`. Implements the user's delegated continuation of specification §8/§14. ADR0006's selection-request boundary still applies to that module; this authorised page command owns a separate bounded flow. Main integration, ordinary push and same-item Library delivery belong to the coordinator, with complete isolated app CI tracked in VALIDATION and the final delivery. No owner-app launch, authenticated service request, signing-account setup or new test product occurred. No applicable `AGENTS.md`, `.agents` or `.codex` skill files were present in the inspected repository/ancestor locations.

## User-visible behavior and caps

The existing Mac PDF toolbar opens **翻译当前页** for the physical page at click time. PDFKit extracts only that page's available text and honours copying restrictions. No text gives an explicit OCR-needed message; this slice does not implement OCR or send images. The original PDF stays in the reader and its bytes are never rewritten. The separate result sheet shows page number, full source preview and every segment, fixed official receiver/model, Simplified Chinese target, request/token/deadline caps and unknown currency cost. The user personally enters a key, checks consent covering the complete plan and presses send. Opening the sheet, selecting/changing a page, entering a key or checking consent never sends.

* At most **3000 UTF-16 units per complete page**, **6 segments**, **500 UTF-16 per segment**, and **6 actual submissions per page-module app session**. The page count is independent of the existing three-attempt selection/probe budgets. Failure and cancellation after reservation consume an attempt; closing/reopening/preparing another page does not reset it. Restart resets memory counters, not account charges, and is not an account quota mechanism.
* The deterministic plan preserves every Unicode scalar, whitespace and whole Character/grapheme boundary. It prefers sentence/whitespace boundaries; no context or other page is added. A page under3000 can still need more than six safe segments, which is refused. A single grapheme over500 is refused. No prefix-only translation is described as whole-page completion.
* Each segment uses the existing DeepSeek selection HTTP adapter/coordinator, official fixed HTTPS completion URL and exact `deepseek-flash` profile. New `deepseek-pdf-page-1` prompt asks to translate every part of the segment rather than restrict translation to three sentences. Each request has1024 output tokens including JSON/echoed quote, disabled thinking, strict source echo/complete stop choice,64KiB response cap and30s deadline. Plan totals are request/token upper bounds (up to6144 tokens and180s of request timeout budgets), not price or wall-clock completion promises. No usage, server billing or language quality is inferred.
* Before any send the model checks that **all** planned sources remain current and enough of the independent six-attempt budget remains for the entire plan. One sequential task owns the budget; it rechecks authoritative budget state before dispatch and each segment checks cancellation/source. All scope is initiated by one explicit user action. No retry, provider fallback, automatic continuation or new consent scope occurs.
* The first failure stops all remaining segments. Successful segments remain readable and individually saveable; pending/failed ones are visibly incomplete. Cancellation/close/book change clears temporary input/credentials and cancels the active coordinator; noncooperative late responses cannot enter visible results. Already submitted requests can still be billed. Partial resume/retry is deliberately absent; a plan with any completed segment cannot be re-sent by this slice.

The bilingual sheet uses two text columns at sufficient width and a vertical original/translation pair at narrow width, with wrapping/scrolling. It does not claim layout overlay, original fonts, table reconstruction, image translation, flawless PDF extraction/reading order or complete N4/T07 acceptance. Completed results persist in this model while the same sheet/page is reopened; preparing a different page replaces unsaved in-memory results. Explicitly saved notes remain durable. EPUB chapters, multi-page/whole-book translation, exported bilingual PDF and mobile page UI are out of scope.

## Credentials, source and learning notes

The page sheet uses its own temporary input and existing `SessionCredentialStore`; it never reads or reuses the selection/probe key or a Keychain item. The input clears on send and credentials are removed on completion/cancel/close. No config or key is persisted by page requests. One immutable provider profile is frozen per explicit submission; each submission gets a fresh identity to isolate coordinator cache entries. Swift/Foundation cannot promise secure memory erasure; an in-flight HTTP request temporarily owns its Authorization header.

`PDFPageTextSnapshot`/new `AISelectionAnchor.pdfPage` preserve book, reader session, edition/hash, physical page, `pdfkit-page-text-1`, the full local page text and checked UTF-16 segment span/quote. Full page text and identity remain local; only that request's sourceText/task and fixed instructions enter the body. Reader resolution compares scalar-exact page text and original edition/hash without fabricated rectangles. Execution/save require the current session; saved note return validates the original page/edition/text after reopen and navigates to that page (no promised geometry highlight).

Manual segment save calls the existing `AILearningModel`/atomic `AILearningRepository` and records `AIResult`/`AILearningNote`, with user text separate. No automatic note writes. Learning schema1 adds an exact-key whitelist for `pdfPage` and the matching page prompt/kind/provider. Old selection notes still decode. Older builds cannot decode files containing page anchors; downgrade must preserve the complete learning store/backup and explicitly recover an earlier compatible copy without discarding new user notes. This is an additive schema extension, not guaranteed backward readability.

## Independent branch verification (historical)

Local toolchain: Xcode27.0 (27A266a), Swift6.4, arm64 macOS. At the recorded source snapshot:

* `swift test --package-path apple/Packages/PDFnoKit --scratch-path <isolated temporary directory>`: **53 tests in9 suites passed**, adding9 page tests to44 existing tests. Only original bundled/in-memory PDFs and synthetic credentials with fully intercepted transports are used. Coverage: scalar/grapheme preservation beyond500;3000/six-segment/huge-grapheme refusal; actual PDFKit whole-page text/return/no-text handling and original byte preservation; complete ordered body scope and caps; consent/stale refusal; manual existing note-store roundtrip/forged schema refusal/key absence; first failure/truncation stop; whole-plan remaining-budget refusal without a send; cancellation/timeout/stale source and noncooperative late-response rejection; canonically equivalent changed scalar sequences invalidating old prepared results.
* Existing `PDFnoMac` **build-for-testing passed**, including all new real UI-test source in the existing `NativeUITests` target. Existing `PDFnoMobile` **generic iOS Simulator build passed**. Neither launches an application. The only reported build warnings are the existing unused AppIntents metadata extraction notices.
* `scripts/check-native-source.py` passed; `git diff --check` passed. Guard confirms the two existing application and two UI-test products, original fixtures/domain import boundary and no detected private/build artifacts. No project/fixture binary or package dependency changes are needed.

Temporary logs are named `PDFno-page-translation-swift.log`, `PDFno-page-translation-Mac-build.log`, and `PDFno-page-translation-Mobile-build.log`; the Mac build result is `PDFno-page-translation-Mac-delivery.xcresult`. Build products/logs are outside Git. These logs contain original/synthetic tests only.

Actual UI execution is **NOT RUN locally**, per delegation. The integrator must execute the existing Mac suite in isolated CI on the final combined SHA. Three tests were added:

1. `testMacPDFWholePageOfflineConsentBilingualNotesAndSourceReturn`: real toolbar/sheet, original three-segment in-memory PDF (including final line18), no send on key entry, one complete-plan consent, bilingual results, manual note save, page return, restart without key/results, durable note/source return through existing learning UI.
2. `testMacPDFPageScanAndOversizeRefuseWithoutSend`: original no-text and over-budget PDF fixtures, explicit OCR/cap refusal and absence of send/key controls.
3. `testMacPDFPageCancelStopsRemainderAndReopenKeepsAttemptCount`: slowed intercepted response, cancellation, absence of accepted results and retained session count on reopening.

Debug fixture injection requires a valid `PDFNO_UI_TEST_SESSION` UUID and explicit `PDFNO_UI_TEST_DEEPSEEK=offline`. `PDFNO_UI_TEST_PAGE_FIXTURE` chooses only locally authored `multi`, `blank`, `over-budget` PDFs. `PDFNO_UI_TEST_PAGE_RESPONSE=slow` delays only the intercepted transport; no URLSession fallback exists. Tests assert the offline marker before entering the synthetic key. No screenshot/AX inspection of a user-running app or real documents occurs. Isolated UI results and real service/language/fee acceptance remain unverified and must not be claimed from a build.

## Integration touchpoints

Most implementation lives in new `PDFPageTranslation.swift`, `PDFPageTranslationModel.swift`, `PDFPageTranslationWorkspace.swift`, `OriginalPageTranslationUITestPDF.swift` and `PDFPageTranslationTests.swift`.

Shared edits to reconcile with comic/Word/conversion integration:

* `AIContracts.swift`: additive `pdfPage` anchor and request prompt selection; `AIJobCoordinator.swift`: use that prompt in consent/cache fingerprint.
* `DeepSeekSelectionProvider.swift`: optional bounded budget size (existing default3 unchanged), separate full-segment prompt; existing selection prompt is byte-for-byte retained.
* `AILearningRepository.swift`/`AILearningModel.swift`: exact page-note validation and existing explicit note writer.
* `PDFReaderSession.swift`: current-page snapshot and exact page-text resolution/return.
* `LibraryModel.swift`: page model construction, Debug fixture injection, book/import cancellation and page source handling. Merge lifecycle hooks with other modules rather than replacing their cancellation.
* `LibraryWorkspace.swift`: Mac-only page command/sheet and accurate capability text. `OfflineSelectionUITestTransport.swift`/`NativeUITests.swift`: extend the existing offline mode/suite, never add a product or network fallback.

The coordinator has updated the complete native specification, task/validation overview and audit handoff to the combined implementation. This slice record retains the original branch evidence and exact bounded behavior; final combined app results use the delivered SHA and its complete CI runs.

## Coordinator integration

The approved slice is now integrated with CBZ, finite DOCX export and the actual Mammoth Word reader. All import/open/close format transitions cancel both learning modules; currentness/preparation/source-return refuse active Word/comics, and DEBUG page fixtures preserve exclusive reader flags and busy guards. Selection limits/prompt bytes and independent3-attempt budgets remain. Combined local97 Swift/14 suites,11 Node and both builds passed; all three new actual app flows await the complete13-method final-SHA CI outcome reported by VALIDATION/delivery. No owner-app launch/key/service request occurred. Freeze after that gate for the separately requested whole-project audit.

## Manual-save evidence refinement

Per-segment saving/safe-error feedback sits beside its manual save button. The direct regression now uses real PDFKit plus the actual LibraryModel current-source predicate in a fresh injected root, decodes the persisted request/source/user note, reloads through a new model and proves unchanged bytes on stale-session refusal and safe disk-write failure. The complete UI method additionally verifies the actual original note input and private UUID learning manifest before its original restart/source-return assertions. The prior f961286 CI passed12/13 methods but did not save this page note; the precise action/binding/write cause is still under investigation, not a completed repair. Original13 methods and execution allowances remain.
