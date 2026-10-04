# C04–C06 saved-record editing and search parity handoff

Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later

Date: 2026-10-04 UTC. Candidate branch: `feature/note-parity`. Accepted baseline:
`bb6928e1319f85a72c967a6c3f054bb544e9c306`. Local implementation only; no push,
merge, release, app launch, real API, credential, signing/entitlement change or
private book/Library access. The independently blocked security task remains
**UNVERIFIED** and was not resumed.

The repository contribution rules, v0.3 native note/source/concurrency contracts,
current native task records, previous editing/search handoffs and current source
were inspected. There is no current C04–C06 remaining-work table in this checkout;
this slice follows the delegated scope and current code instead of treating old
ledger snapshots as missing implementations. Existing PDF/EPUB/general-AI editing,
drafts and search remain in place. `LibraryModel.swift` and
`LibraryWorkspace.swift` are unchanged; host entry-point integration is reserved
for the serial integrator/UIworker.

## Delivered behavior

- Text records: TXT, Markdown, HTML, XHTML, MHTML and readable XML saved note bodies
  can be edited through the new adapter without reopening or re-extracting their
  source. Ebook records: the existing MOBI, AZW, AZW3 and FB2 note types have the
  same body-only update contract. Body edits preserve note/book IDs and every
  source locator field; they do not create or repair locators or edit originals.
- Japanese learning records: editing changes only `userText`. The complete saved
  review (source, provider, prompt version, request, readings, grammar, sentence
  components, warnings, translation) and independent user reading corrections
  stay intact. Existing generation drafts and general-AI original results retain
  their own provenance and are not overwritten by this editor.
- Repository updates use a saved-snapshot compare-and-set. Comparison uses sorted
  encoded bytes rather than Swift's canonically equivalent String equality. Empty
  and whitespace bodies remain intentional. Identical bytes cause no write. Text
  and ebook keep their existing 16,000 UTF-8-byte body limit; Japanese keeps its
  existing 16,000 UTF-16-unit limit. PDF and EPUB retain their old limits.
- The old editor, journal and body component now share generic implementations
  with the new record types. `NoteEditingModel`, `NoteEditDraft`,
  `NoteEditDraftJournal` and `NoteBodyEditor` remain source-compatible aliases.
  Existing `note-edit-drafts-v1.json` retains its old wire shape. New record drafts
  use **`record-edit-drafts-v1.json`** automatically; the two journals are never
  migrated, merged or rewritten into each other.
- Save/cancel/restart/conflict/failure/retry behavior comes from that same editor:
  synchronous checkpoints, independent per-record drafts, duplicate-save refusal,
  failed-write draft retention, explicit rebase retaining the draft, and recovery
  after a body commit succeeds before draft removal. Canonical-only committed
  Unicode changes also reconcile correctly, including the body component's change
  observation. Current reader projection is fenced by the captured reader session;
  completion does not reopen readers or redirect a switched book.
- `RecordSearchRepository` indexes only saved text/ebook notes, their catalog
  titles, and Japanese learning records. Japanese entries keep quote/body/generated
  suggestions/user corrections as separate fields. Orphan Japanese records retain
  their original quote and remain searchable with unavailable-source status.
  Text/ebook have no existing author metadata field; this slice searches their
  imported titles without creating a new metadata/cover/exchange namespace.
- Matching and grapheme-safe previews reuse the existing search implementation:
  POSIX case fold, canonical equivalence, all whitespace-separated terms, original
  quote scalars retained, empty/no-match/over-limit behavior and cooperative
  cancellation. No persistent index or whole-book extraction is introduced.
- `SavedRecordSearchRepository` combines the old index with new records, counts all
  matches and shares one 300-item display budget. Ordering is stable: existing
  groups receive the budget first, then new typed record hits. It does not claim
  cross-store or cross-process transactional snapshots.
- `SavedRecordSearchModel` supplies one host controller for those combined results.
  The optional record-only controller uses the same generation/cancel/failure
  implementation. Committed PDF/EPUB/DOCX/comic/general-AI/text/ebook/Japanese
  collections trigger refresh; drafts never enter the index. Failed reads clear
  old results, and cancelled/late backends cannot replace the current query. Empty
  combined queries still load the legacy catalog for existing metadata entry points
  while returning no note hits.
- Source activation resolves IDs from current validated stores. Text/ebook note
  routes preflight with an independent native canonical reader before changing the
  active reader, then reread the record before exact navigation. Japanese routes
  use the original PDF/EPUB source services; PDF is exact-preflighted with PDFKit,
  EPUB awaits the captured reader readiness and native navigation verifies the
  anchor. Reader-scope guards stop delayed preflight/navigation after another book
  switch. Missing/mismatched sources do not receive invented fallback anchors.

All saved manifests remain schema 1. Strict/future/corrupt-store refusal, existing
atomic writes and existing validated-prior backup behavior are retained. No new
backup, deletion, trash, synchronization or migration feature is implemented.
Text/ebook CAS is serialized within the injected existing repository actor;
Japanese uses its existing shared same-process file gate. Cross-process writes,
fsync/power-loss recovery and cloud conflict protocols are outside this slice.

## Serial integration contract

1. Retain one `RecordEditingAdapter` for the **library lifetime**, alongside the
   existing `noteEditing`. Create it with `await library.makeRecordEditingAdapter()`;
   it automatically binds to that library's existing repository actors and root.
   Do not recreate it per row or per sheet.
2. Keep the current saved quote/review/corrections display and source-return action.
   Add `RecordBodyEditor(editor: adapter.editor, note: .text(note), identifier: ...,
   save: { await adapter.save(.text(note)) }, reload: { await adapter.reload(.text(note)) })`
   to text rows. Use `.ebook(note)` and `.japanese(note)` for the other saved rows.
   Existing PDF/EPUB/general-AI editors continue using their current aliases.
3. For a unified search, retain/observe **`SavedRecordSearchModel(root:)`** and drive
   `updateQuery`, `refresh`, `cancel`, `waitForSearch`, `observeChanges(in:)` and
   `stopObservingChanges()` from the host. Display `response.legacy` through the
   existing group presentation and `response.records` through `RecordSearchResults`.
   The component accepts `response`, `error` and an async `open` callback.
   Route existing targets with `library.openSearchTarget` and record targets with
   `library.openRecordSearchTarget`. Close the host on successful explicit navigation
   if that is its existing behavior. Use `response.totalCount` for the combined count.
4. Do not run two independent 300-hit controllers for the unified UI: the combined
   repository/controller owns the shared budget. Retain existing local metadata
   editing for its currently admitted old formats; text/ebook metadata extensions
   are not part of this candidate. Update the search scope label in the integration
   UI to include the newly admitted saved records.

## Verification

Host: arm64, macOS 27.0, Xcode 27.0 (27A266a), Swift 6.4.0. Only original bundled
fixtures and synthetic records in fresh UUID temporary stores were used. All build,
cache, module and DerivedData paths were isolated under `/tmp`; compilation used
`jobs=2`, with no other Swift/Xcode compiler processes present at build start.

- **67 tests / 7 suites passed**, including 19 new `RecordParityTests` methods
  (parameterized cases additionally exercise all six text and four ebook formats).
  Suites: RecordParity, NoteEditing, LibrarySearch, LibrarySearchModel,
  JapaneseLearningRepository, TextFormat and Ebook. Final log:
  `/tmp/pdfno-note-parity-tests-accepted.log`.
- Coverage includes old v1 manifests, Japanese legacy prompt/omitted optional
  components, exact Unicode CAS and original assets, no-op/empty/limits,
  protected invalid stores/journals, restart/cancel, real failed backup write with
  manual retry, explicit conflict rebase, commit/checkpoint recovery, saved-only
  search and refresh, namespaces, missing source, result budgets and late/cancelled
  backend suppression. A saved Japanese review edited locally returns through
  exact PDFKit fixture geometry to its original page, with unchanged source bytes.
- Mac `build-for-testing`, signing disabled, completed for the candidate app and
  existing UI test host. Final log: `/tmp/pdfno-note-parity-mac-build-accepted.log`.
  This is **compilation evidence**, not actual desktop UI execution.
- iOS Simulator generic `PDFnoMobile` build, signing disabled, **BUILD SUCCEEDED**.
  Log: `/tmp/pdfno-note-parity-mobile-build.log`. Shared aliases/protocols compile;
  the new Mac-only record UI is not enabled on mobile. No simulator/App was launched.
- `python3 -B scripts/check-native-source.py` and `git diff --check` passed;
  the final guard checked **590 source files**. The
  source guard is the ordinary repository/provenance check, not the blocked
  independent security review.

Two development compile errors were corrected before the accepted run: async
expressions inside Swift Testing boolean autoclosures, and an incorrect assumed
public comic reader session property in the new route fence. A new unused-variable
warning was removed. Existing codec integer-conversion warnings, the old Swift
sendable-capture test warning, two unused UI-test variables and AppIntents metadata
warnings remain baseline limitations, not acceptance of those areas.

Reproduce the targeted run:

```sh
env CLANG_MODULE_CACHE_PATH=/tmp/pdfno-note-parity-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/pdfno-note-parity-manifest swift test --jobs 2 --package-path apple/Packages/PDFnoKit --scratch-path /tmp/pdfno-note-parity-build --cache-path /tmp/pdfno-note-parity-cache --config-path /tmp/pdfno-note-parity-config --security-path /tmp/pdfno-note-parity-security -Xswiftc -module-cache-path -Xswiftc /tmp/pdfno-note-parity-modules --filter 'RecordParityTests|NoteEditingTests|LibrarySearchTests|JapaneseLearningRepositoryTests|TextFormatTests|EbookTests'
env CLANG_MODULE_CACHE_PATH=/tmp/pdfno-note-parity-xcode-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/pdfno-note-parity-xcode-manifest xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/pdfno-note-parity-Mac -clonedSourcePackagesDirPath /tmp/pdfno-note-parity-Packages -disableAutomaticPackageResolution -skipPackageUpdates -jobs 2 CODE_SIGNING_ALLOWED=NO 'OTHER_SWIFT_FLAGS=$(inherited) -j2' build-for-testing
env CLANG_MODULE_CACHE_PATH=/tmp/pdfno-note-parity-Mobile-clang SWIFTPM_MODULECACHE_OVERRIDE=/tmp/pdfno-note-parity-Mobile-manifest xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/pdfno-note-parity-Mobile -clonedSourcePackagesDirPath /tmp/pdfno-note-parity-Mobile-Packages -disableAutomaticPackageResolution -skipPackageUpdates -jobs 2 CODE_SIGNING_ALLOWED=NO 'OTHER_SWIFT_FLAGS=$(inherited) -j2' build
python3 -B scripts/check-native-source.py
git diff --check
```

## Shared-file touch points and remaining acceptance

Existing files modified: `NoteBodyEditing.swift`, `NoteEditDraftJournal.swift`,
`NoteEditingModel.swift`, `NoteBodyEditor.swift` (shared generic implementation and
aliases); `TextFormatRepository.swift`, `EbookRepository.swift`,
`JapaneseLearningRepository.swift` (body CAS only);
`TextFormatLibraryModel.swift`, `EbookLibraryModel.swift` (scoped publication);
`LibrarySearchRepository.swift` (reusable matching/preview helpers; existing search
behavior retained). All other implementation files and RecordParityTests are new.
No existing test was removed or changed. No project, generator, package dependency,
engine/resource bundle or original fixture was changed.

The two exclusive main UI files have **zero diff**. The extensions, adapter and
independent components compile, but their production entry points are not wired
into those files in this branch. Serial integration and isolated actual Mac UI
acceptance must cover text/ebook/Japanese saved-row edit/save/cancel/restart,
format/book switching during save/navigation, successful native text/ebook/EPUB
source returns, unknown-source feedback and the unified search scope/count.
VoiceOver, oldest OS/Intel, mobile runtime/UI, huge-library performance and
cross-process concurrent editing were not validated in this slice. Existing
43-test accepted UI evidence belongs to the baseline, not this new candidate.
