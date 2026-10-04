# Mac saved-note body editing handoff

Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later

2026-10-04; branch `feature/note-editing`, based on fixed
`11d32265a8b7ee7956f36c6af59dd42e54dcf035`. This slice edits **existing saved**
PDF/EPUB reading notes and PDF/EPUB/current-page learning notes. It adds no saved-note
delete action, model request, credential handling, sync, or migration.

## Result and persistence contract

Each saved row offers edit/save/cancel and local saving/saved/failure feedback. Only
`userText` changes. PDF preserves ID/book/anchor/createdAt, increments its existing
local revision and updates updatedAt. EPUB preserves ID/book/anchor; learning notes
preserve their entire AIResult, including source, quote, request, provider, prompt
and generated text. Existing `library-v1.json`, `epub-v1.json`, `learning-v1.json`
remain schema 1, with the same note fields. The existing atomic write/backup and
corrupt/future-store refusal remain in use. The new update methods receive a saved
baseline and read the current record inside the same existing repository actor;
a stale baseline is rejected. EPUB/learning compare the complete snapshot because
their old schemas contain no revision field. This is local compare-and-set, not a
cross-process or cloud revision protocol.

Empty text clears just the user body and retains the saved record/highlight/result.
Whitespace and Unicode scalars are preserved without trimming or normalization.
The old limits are retained: PDF 50,000 characters, EPUB 16,000 UTF-8 bytes and
learning 16,000 UTF-16 units. An unchanged-body save does not create a new revision.

`NoteEditingModel` lives with LibraryModel rather than an ephemeral sheet. Drafts
are keyed by format/book/note and synchronously checkpointed to the separate
`note-edit-drafts-v1.json`. Closing a sheet, switching books and restarting retains
unsaved text. Cancel explicitly discards only that edit draft. A failed note write
retains the draft and permits a manual retry. A conflict permits an explicit
baseline reload while retaining the user's draft for comparison before saving.
Malformed/future/unknown-field draft journals are refused, never silently replaced;
checkpoint failure is reported and current-session text remains. Journal bounds
are 100 drafts, 256,000 UTF-8 bytes per draft body and 10 MiB total. Exceeding those
bounds reports a checkpoint failure, with live text retained.

Save captures baseline/text before suspension, prevents duplicate save/edit/cancel
on the in-flight record, and clears only that record's draft on success. A crash
between note commit and draft removal is reconciled when the same exact body is
already saved. Current reader projection is fenced by original book/session;
late completion never opens or redirects the reader.

## Search and parallel integration

The existing `LibraryModel.notes`, `LibraryModel.epubNotes` and
`AILearningModel.notes` Published arrays are updated on successful save. No new
notification or search indexing protocol is needed; search can observe those arrays
and rebuild from their current contents. The save path does not perform a whole
library reload or alter the active book, selection, progress or AI generation.

Shared-file touch points, to preserve when integrating covers/search:

- `LibraryModel.swift`: one editor property and a seven-line initializer binding
  it to the **same** existing PDF, EPUB and learning repository actors.
- `LibraryWorkspace.swift`: only the saved PDF row editor, body identifier and
  notes-list identifier. Library/sidebar/book-open/search controls are untouched.
- `EPUBWorkspace.swift` / `AILearningWorkspace.swift`: the equivalent saved-row
  editor/body/list identifiers; their source-return actions remain.
- `AILearningModel.swift`: repository visibility changes from private to internal
  for the same-actor binding; no AI request/state/save logic change.
- The three existing repository files gain `updateNoteBody(expected:text:)`.
- `NativeUITests.swift`: four new Mac methods/helpers before the existing suite;
  all prior methods/assertions remain. The generated project already includes this
  file, so project/scheme/generator changes are unnecessary.

New implementation files are `NoteBodyEditing.swift`, `NoteEditDraftJournal.swift`,
`NoteEditingModel.swift`, `NoteBodyEditor.swift`, `LibraryModel+NoteEditing.swift` and
`NoteEditingTests.swift`.

## Local evidence

macOS 27.0 / arm64 (26A428), Xcode 27.0 (27A266a), Swift 6.4.0. All inputs are original
bundled fixtures or synthetic in-memory notes in fresh temporary directories. No
real credential, API call, user book, current PDFno process, signing profile,
shared Library or other worktree is used. All compilation outputs/caches are
independent under `/tmp/pdfno-note-edit-*`.

Passed:

1. `swift test --package-path apple/Packages/PDFnoKit --scratch-path /tmp/pdfno-note-edit-swift --filter 'NoteEditingTests|RepositoryTests'`:
   **17 tests / 2 suites**, 0 failures, 0.073 seconds. The new suite contributes
   13 tests covering old schemas and exact source/AI fields, PDF revision/no-op,
   empty/Unicode/limits, original asset bytes, restart drafts, explicit cancel,
   suspended late saves, duplicate save refusal, disk failure/retry, conflict
   retention/rebase, commit/checkpoint crash reconciliation, incompatible journals
   and saved manifests, and Published collections without reader replacement.
   Log: `/tmp/pdfno-note-edit-swift-final.log`.
2. `xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/pdfno-note-edit-mac CODE_SIGNING_ALLOWED=NO build-for-testing`:
   **TEST BUILD SUCCEEDED**; application plus all old/new UI methods compiled.
   Log: `/tmp/pdfno-note-edit-mac-final.log`.
3. Equivalent `PDFnoMobile`, `generic/platform=iOS Simulator`,
   `/tmp/pdfno-note-edit-mobile`, `CODE_SIGNING_ALLOWED=NO build`:
   **BUILD SUCCEEDED**. Log: `/tmp/pdfno-note-edit-mobile.log`.
4. `python3 scripts/check-native-source.py`: 252 candidate source files passed after
   this handoff was added. `git diff --check` passed.

The first test compilation found an incorrect initializer in the new page-anchor
fixture. It was corrected to construct a PDFPageTextSnapshot; it is not counted as
a passing run. There were no permission denials. Existing unused-variable warnings
in converter UI tests and AppIntents metadata warnings are unrelated to this slice.

## Integration CI and remaining acceptance

The four new real Mac UI methods compile, but **have not been executed locally**:

- `testMacPDFBodyEditingCancelDraftRestartEmptyAndSource`
- `testMacPDFBodyEditingDiskFailureKeepsDraftAndExplicitRetry`
- `testMacEPUBBodyEditingBookSwitchRestartAndSource`
- `testMacLearningBodyEditingPreservesResultRestartAndSource`

They use actual PDFKit search selection, actual EPUB double-click selection, local
mock generation, fresh UUID stores and the app's real controls. The failure method
changes only its isolated original-fixture backup path. Editor input/actions require
full visibility inside the notes list before a synthetic click. Complete execution
belongs to the coordinator's isolated CI host with the entire existing UI suite and
unchanged time limits. `build-for-testing` is compilation evidence only.

Security-specialist platform blockers remain **unverified**, with no retry or
workaround in this slice. No full-suite security acceptance, current-user UI test,
oldest-OS/Intel/accessibility/real-device/real-provider acceptance, cross-process
file coordination or power-loss/fsync guarantee is claimed. Main merge, push and
release are left to the coordinator; this handoff is a local commit only.
