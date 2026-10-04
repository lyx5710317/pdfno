# Mac EPUB current spine document bilingual translation

Date: 2026-10-04. Branch: `feature/chapter-translation`. Base: `11d32265a8b7ee7956f36c6af59dd42e54dcf035` (the accepted full functional-CI baseline). This is an isolated, local-only delegated slice. No cover/note-edit/search integration commits are included, and no main/release/push/merge/Library delivery is performed here. Swift/PDFKit, pinned Kookit and AGPL remain unchanged.

## Exact chapter definition

The command is labelled **翻译当前文档** in the Mac EPUB toolbar. It reads all existing `epub-canonical-utf16-1` text in the currently loaded spine resource, independent of the viewport/page or a TOC fragment. A single resource can contain several logical TOC chapters; one logical chapter can span resources. This slice does not infer either relationship and does not claim to translate an entire logical TOC chapter or book.

The confirmation sheet names that distinction, resource href, one-based spine position/count, full `[0, UTF16Count)` range, exact UTF-16 character-unit count and number of planned segments. It exposes a full original preview and every segment's unmodified original beside its independent translation. Canonical extraction remains identical to existing selection/notes: rt/rp and active/style text are excluded, base ruby text remains. Kookit places the source title inside its body DOM, so that title remains in this existing canonical range. Raw WebKit selection strings can contain displayed ruby and block separators; persistent quotes use the canonical mapping rather than that display string. No extraction-version or original EPUB byte change is made.

The bridge returns the true count but **null text** for an oversized resource. This is a refusal, never a truncated excerpt. Preparation offers no key or send control on refusal and tells the user to select a smaller original range with the existing selection AI.

## Explicit submission and limits

Complete resource cap: 3000 UTF-16 units and six segments. Segments are greedy at Swift Character boundaries, at most 500 UTF-16 units each; their scalar-exact concatenation must equal the whole snapshot. Huge graphemes or more than six segments refuse the complete plan. No whitespace trimming, normalization, inferred separators or summary is substituted.

The receiver/profile stays fixed at `https://api.deepseek.com/chat/completions`, `deepseek-flash`, Simplified Chinese, nonstreaming JSON, thinking disabled. Only `sourceText` and `task` plus fixed instructions leave the device; file bytes, images, book/edition identity, filenames, resource paths, surrounding documents, notes and history do not. Each response allows 1024 output tokens (including echoed quote/JSON), a 30-second deadline and the existing 64 KiB transport bound. The displayed complete plan therefore allows at most 6144 output tokens and 180 seconds summed request deadlines. These are technical bounds, not a monetary guarantee; failures/cancellations count and an already-sent request can be charged.

The user personally enters this batch's temporary key, confirms the frozen complete scope/receiver/budget/possible fee, then presses the explicit send button. Changing the key resets confirmation. No preparation/open/navigation/cancel/configuration action sends requests. Key entry clears upon sending; its private session store is removed on completion/cancel/close. It is not persisted in files, Keychain, shared settings, JS, selection credentials or probe credentials. Swift memory does not promise secure erasure.

`AppAISession.chapter` owns an independent process-lifetime six-attempt budget. A complete plan claims the batch before its first send; another window or insufficient remaining budget refuses before sending any segment. Attempts increment at actual provider submission, unsent claim slots are released, and recreating models does not reset the counter. Selection, PDF-page and bookless-probe counters remain independent.

## Cancellation, results and source return

`EPUBChapterTranslationModel` reuses `AIJobCoordinator`, `DeepSeekSelectionProvider`, strict response validation, ephemeral transport and temporary credential store. Its `epubChapter(EPUBAnchor)` variant and `deepseek-epub-chapter-1` prompt keep source/cache/store provenance separate from selection and physical-page output.

There is one sequential submission of each prepared plan, no automatic retry or resume. Cancellation/timeout/auth/quota/format/truncation/source failure stops the remainder. Closing, switching books, WebKit closing, chapter/document-version changes and reflow invalidate current work. Noncooperative late output cannot display or save to a newer scope. Same-spine page moves do not alter the canonical scope; a concurrent reader command conservatively refuses current-source validation while busy.

Completed segments and independent user drafts remain in memory after cancellation/partial failure. Preparing another scope archives earlier successful segments in the same model instead of replacing them. UI marks incomplete work and offers explicit original-source return and per-segment learning-note save. Nothing automatically modifies a book or saves a note. Before saving retained output after a source switch, the user returns to the source; a read-only bridge command validates resource identity, exact canonical offsets/quote and prefix/suffix. Saved sources can return after reopening the exact book/edition/hash despite their older request session/version. No fuzzy rebinding or model coordinates are trusted.

Notes use the existing strict/atomic/backup `learning-v1.json`, retaining original source, generated text and user text in separate fields. Adding `epubChapter`/the new prompt is additive to the schema-1 allowed variants; older AI readers reject such stores safely. Preserve the complete learning file before downgrade and retain user notes; no automatic migration/downgrade is supplied. Unsaved output disappears on application exit, which the sheet explicitly states.

## Local evidence and pending acceptance

All test text/credentials/responses are original/synthetic. Existing binary fixtures are unchanged. New WebKit tests use generated in-memory EPUBs and hidden NSWindows inside the test runner; no user-running PDFno app, private book, actual key or real API is accessed. DEBUG UI injection requires an isolated UUID test session and the existing `offline` marker; the supplied transport has no URLSession fallback. The UI tests assert that marker before synthetic-key entry.

| Verification | Outcome |
| --- | --- |
| `swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/ChapterTests --filter 'EPUBChapter(Translation\|WebKit)Tests\|PDFPageTranslationTests\|DeepSeekSelectionTests\|AppAISessionTests'` | 30 tests / 5 suites passed; 10 chapter domain/model/service tests and 3 new hidden WebKit/native-library tests |
| Full-range Unicode/context, oversize/no excerpt, TOC A/B in one spine, page-independent extraction, ruby, exact navigation/reopen | Passed in new chapter suites |
| Explicit scope, no secret in body/store, independent notes, mismatch/truncation, cancel/timeout/noncooperative late response, partial success/draft retention, full-plan budget/concurrent windows/model recreation | Passed with fully intercepted providers |
| `xcodebuild ... PDFnoMac ... CODE_SIGNING_ALLOWED=NO build-for-testing` | Mac app and all UI test source compiled; no app launched |
| `xcodebuild ... PDFnoMobile ... CODE_SIGNING_ALLOWED=NO build` | iPhone/iPad simulator target compiled; chapter UI remains Mac-only |
| `node engine-build/build.mjs` | Existing licensed EPUB profile rebuilt, 188 inputs; pinned vendor/bundle input list unchanged |
| Source/fixture guard, requirement ledger and diff whitespace | Final checks recorded at local handoff |

Four new actual Mac UI test methods in `NativeUITests.swift` cover whole Japanese fixture consent/bilingual/manual save/restart/source return, English oversize refusal, cancellation/no automatic retry/key re-entry, and second-segment failure with first-segment manual save. They are **compiled but NOT EXECUTED** here. The integrator must run isolated exact-integrated-SHA CI before claiming UI acceptance. Local logs are in `/tmp/pdfno-chapter-final-tests.log`, `/tmp/pdfno-chapter-mac-final-build.log`, `/tmp/pdfno-chapter-mobile-final-build.log` and `/tmp/pdfno-chapter-source-guards.log`.

Real language quality, real receiver/account/TLS/billing, persistent keys, actual UI/VoiceOver/layout acceptance, mobile EPUB/AI reading, TOC logical-range inference, oversized range picker, whole-book/batch resume, EPUB page snapshots, Q&A and OCR remain unverified/out of this slice. The separate security专项 remains **UNVERIFIED / platform blocked**; it was not retried or bypassed and these functional checks do not change that status.

## Integration touchpoints

New files: `EPUBChapterTranslation.swift`, `EPUBChapterTranslationModel.swift`, `EPUBChapterTranslationWorkspace.swift`, `EPUBChapterTranslationTests.swift`, `EPUBChapterWebKitTests.swift` and this handoff.

Shared files likely to conflict with the text-format or cover/note/search integration work:

- `LibraryModel.swift` / `LibraryModel+Comics.swift`: initialize the chapter owner, cancel on every import/open route, add chapter snapshot/preparation/current-source/exact-save/return cases. Preserve the integrator's new format routes and other cancellation owners.
- `AIContracts.swift`: add the typed `epubChapter` anchor, labels/validation and prompt. Preserve any other concurrently added anchor variants and all exhaustive switch cases.
- `AILearningRepository.swift` / `AILearningModel.swift`: allow the new typed variant and prompt, validate before explicit per-segment save. Preserve edit/search schema guards, duplicate-note protection and user-text separation.
- `AppAISession.swift` / `DeepSeekSelectionProvider.swift`: add independent chapter counters and an optional claimed batch ID; unchanged selection/page/probe defaults must remain covered by regression tests.
- `EPUBReaderSession.swift` / `EPUBWorkspace.swift`: additive read-only bridge commands, current spine/version invalidation and Mac toolbar/sheet entry.
- `engine-build/reader.js` and generated `Resources/EPUB/engine.js`: integrate source then rebuild; do not hand-edit the generated bundle. No vendored Kookit source or engine replacement.
- `apple/Tests/NativeUITests.swift`: four additive tests and chapter-specific scroll/fixture helpers; preserve the ongoing 22-UI repair work. CI workflow/project files and original fixture bytes are not changed here.
