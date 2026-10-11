# Saved AI annotation search — 2026-10-11

Saving an AI conversation answer created a valid `annotations-v1.json` record, but global search did not read that store. A search for the exact original quote returned zero results even though the document's notes panel displayed the saved answer and could navigate to its source.

The isolated fix indexes explicitly saved PDF/EPUB AI annotations alongside legacy saved records. Quotes, generated answers, and committed user comments remain separate searchable fields. The new `aiAnnotation` target namespace keeps these records distinct from legacy notes with the same UUID. Search activation reloads the current annotation before and after opening its book, verifies document identity and source, and uses the existing canonical navigation path. Visible search observes committed annotation updates; unsaved answers and editor drafts remain excluded.

This change does not migrate records or introduce a disk index. The existing combined 300-result display budget and query matching remain in use. Missing source books retain searchable saved text with navigation disabled. A malformed annotation store fails the search without returning partial results or rewriting the source data. Manual annotation search outside the existing supported stores is outside this narrowly scoped AI-save fix.

## Reproduction and verification

- GUI query: `Reading opens a small window onto a wider world.` The search reported zero results **247.230 seconds after** the annotation was committed. Its stored quote exactly matched the query. The current preview's search source hash matched the unfixed baseline. This was neither a typo nor the 180 ms search debounce.
- Unfixed baseline `529e5ab`: one new offline regression failed with two issues, reporting expected one hit but actual zero. The failed log and original assertions are retained.
- Fixed source: **39 targeted methods passed**, including five new saved-annotation checks and existing search/conversation checks.
- Additional targeted run: **2 methods passed**, covering separate source pages for colliding legacy/annotation UUIDs and the original existing-tab activation assertion. Total: **41 distinct passing methods**, including six new regressions.
- The six new regressions cover exact quote/generated text/committed comment search; actual conversation save and observer refresh with unsaved/draft exclusion; canonical PDF navigation and stale target rejection; EPUB/orphan identity; malformed-store failure without writes; and namespace collisions.
- All **110 pre-existing Swift test sources at `529e5ab`** are byte-identical. The earlier preservation guard also confirmed its original 105 files, the main tree's untracked Xcode workspace metadata, and the other acceptance tree. No assertion was removed or weakened.
- Tests used original bundled data, temporary local stores, mock AI, a separate APFS-cloned Swift scratch directory, and the shared `PDFnoNativeHeavyChecks.lock` with one build job. They did not operate the desktop or send requests.

Evidence is outside this worktree in `../Evidence/`: `LIVE-SEARCH-OBSERVATION.json`, `BASELINE-SAVED-AI-SEARCH.log`, `FIX-SAVED-AI-SEARCH-RESULT.json`, `FIX-SEARCH-NAMESPACE-TAB-RESULT.json`, and `PRESERVATION.json`.

## Separate real-service validation

The already-running dedicated preview was tested before this source fix:

- Original PDF explanation: DeepSeek `deepseek-flash`, HTTP 200 at **08:25:31 UTC**; valid answer displayed.
- Contextual follow-up: HTTP 200 at **08:26:09 UTC**; request contained two user messages and one previous assistant answer.
- One explicit save persisted the follow-up with its quote and PDF page-1 anchor; the initial explanation remained unsaved.
- Clicking that saved note reported successful source location at PDF page 1 of 2.
- An original EPUB displayed no PDF conversation answers. Returning to the PDF retained both answers and saved state.
- A real mouse drag across the visible original sentence displayed the floating highlight, underline, note, and AI tools.

This continuation added **two** real requests. At release, the new process had three requests including its preceding connection check; the older process had two, for five known requests total. No connection probe was repeated. Credentials were entered by the user and were neither read nor migrated; account quota and billing settings were not changed.

The last GUI input was the original mouse drag at approximately **08:32:56 UTC**. Desktop release was recorded at **08:35:42 UTC / 16:35:42 Asia/Shanghai**. No GUI action followed release. The dedicated app was not restarted or terminated.

Own-window screenshot and timestamped native-control evidence are in `../LiveDeepSeek-2026-10-11/Unlocked/CoreRun/` relative to the parent task directory, specifically `29-real-explanation.png`, `19-followup-result.json`, `20-explicit-save.jsonl`, `EXPLICIT-SAVE-PASS.json`, `22-note-row.jsonl`, `CROSS-BOOK-NO-LEAK.json`, `CONVERSATION-RESTORED-PASS.json`, `30-real-mouse-selection.jsonl`, and `FINAL-DESKTOP-RELEASE.json`. The screenshot contains only the original fixture window. There is no Library attachment ID.

## Limits and preserved failures

The current running preview retains its earlier binary and therefore has **not loaded this search fix**. The corrected search has compiled and passed offline service/native-model tests; GUI verification of the corrected global-search page remains pending a separate preview update. No current Key session was restarted to obtain that result.

During live testing, a driver first queried an Explain button instead of opening the current-selection menu; the corrected menu interaction passed. A save check initially inspected legacy `learning-v1.json`; its failure is retained and the actual annotation store was then verified. An EPUB observation helper exited once while the application remained alive; a subsequent read-only probe verified the separate document. A supplementary screenshot was refused because the floating popup made the unique-window condition ambiguous; no full-screen capture was substituted.

Full 12/68/603 regression, remote CI, and the earlier continuous-EPUB failures remain outside this run. No push, merge, or release occurred.
