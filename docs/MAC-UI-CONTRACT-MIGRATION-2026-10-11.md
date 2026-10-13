# Current reader UI regression contracts

The accepted reader now has exclusive inspector panels, a modal annotation editor, a shared AI connection, and document-owned conversations. The original 60 CI methods and eight professional-reader methods retain their names and remain required. This migration was explicitly approved on 2026-10-11 after identifying obsolete control and storage assumptions. It does not mark any GUI scenario as passed.

The original sources are available at `daed865d357a8c8c3906b7d13b74f8813fc86b37`; byte copies and SHA-256 records are retained in the local integration evidence. The previous baseline failures remain available. No test skip or workflow scope reduction was introduced.

| Prior contract | Current route and retained verification |
| --- | --- |
| Inline PDF/EPUB/Word/text/ebook note inputs | Real reader selection → floating Note action → annotation editor → explicit Done. Verify exact quote and body, no committed record before save, unchanged source bytes, and exact return. |
| Inline edit status and old note manifests | `annotations-v1.json` committed record and `annotation-edit-drafts-v1.json` draft journal. Verify stable note ID and anchor, independent user body, cancel, empty-body save, restart persistence, and failed-write/retry behavior. |
| Leave an inline unsaved editor while switching panels | The current editor is modal. Interrupt and restart once to establish a recovered draft checkpoint; then cancel the resumed editing session, switch panels/books/library, and resume the same draft. Verify committed data is unchanged throughout. |
| Two simultaneously docked panels | Navigation and notes are mutually exclusive. Check each actual panel, the reading-space bound, closure, and unchanged page navigation. |
| Old rail opens translation/explanation consent | The current rail opens conversations. Historical typed translation/explanation checks use the existing Reading Tools route and retain consent, error, cancellation, evidence, and explicit-save assertions. |
| Selection AI writes `learning-v1.json` | New explicitly saved selection results use `annotations-v1.json`; immutable `aiResult`, anchor, and separately editable comment are compared across edit/restart. Whole-page/spine historical records still use the original typed learning store and keep those assertions. |
| Separate BYOK chooser/settings pane | Current shared OpenAI-compatible connection. Assert explicit recipient/model setup, original selection, no automatic note save, explicit answer save, separate body/result, credential exclusion, endpoint-change revocation upon Apply, and shared whole-page connection with independently confirmed source scope. |
| Provider preset buttons and settings auto-dismiss | Current provider picker, Apply Connection, and Return. No connection-test request is added. The unapplied-label test still checks category switching preserves the draft and Return discards it. |
| English-dominant sample permits vertical | The registered original Japanese-dominant continuous fixture retains the English opening word and author ruby. Assert actual page 1→2, chapter navigation, Aa vertical selection, ruby, restart, and unchanged saved source. |
| Native file completion and buttons | Resolve physical `PathTextField`/`OKButton` controls and the observed full-path or original filename completion. Require exact typed path, real hittable row, overlay dismissal, and original import/output assertions. No synthetic button or JavaScript selection. |

The common `ReaderUIContract` driver reads only each test's UUID fixture store. It writes original fixture text to the pasteboard without reading or backing up existing contents. Local runs additionally install the desktop ownership fence in the isolated snapshot; production app identity and live validation processes are never used.

Migration exposed three product regressions, fixed without changing the assertions to accept data loss:

- Current manual annotations were absent from unified search. They now have a distinct target namespace, validated persisted book/source identity, draft exclusion, and exact native source navigation. Saved AI results keep their existing separate namespace.
- Bookno previews omitted current saved annotations. Supported PDF, EPUB and text annotations now contribute only committed body/source/result data; draft journals and provider configuration stay excluded.
- Switching settings categories recreated the connection draft. Its state now belongs to the enclosing settings workspace; Return discards unapplied changes.

The real filesystem-failure fixture now also targets the annotation sidecar. Its UUID/root checks, real backup-directory conflict and explicit retry remain; it is compiled only for Debug and runs only under the explicit fixture environment.

Validation at preparation: full Swift suite 690 methods passed; native source, licensed codec/original-fixture and requirement-ledger guards passed. GUI compilation/execution and final CI must be recorded separately before integration is declared complete.

Gate17 attempt 01 on `2fd1ea1` executed all 17 methods: original12 7 passed/5 failed; additional5 4 passed/1 failed; zero skips. The desktop was released at 2026-10-11 18:58:24 Asia/Shanghai, with the existing live credential process preserved. The failed xcresult and 34 fixture-window captures remain in local evidence. No integration or upload is implied by this result.

Follow-up migration retains physical PDF page transitions through the current canvas shortcuts, restores the existing canonical return action inside the contents panel, and adds stable identifiers to the existing legacy-note sheet. Native file selection may resolve a disabled Open button before selecting the file, but must prove it enabled and hittable before activation. Comic layout/direction/close use the current settings menu; original page, spread, direction and restart assertions remain.

In frozen baseline `8fa7678`, five original structured-language methods were compatibility component tests through a labelled Debug-only host. That did not prove the public Japanese/English structured capabilities were retained, and blocked complete product acceptance. The follow-up isolated restoration connects both structured review pages directly through the public selection language submenus, alongside the existing conversations. The five original methods now enable their public settings and use actual selection controls without the compatibility launch flag. Their original source, result, correction, explicit-save, restart and exact-return assertions remain. Public GUI execution must pass before this gap is considered resolved; see [restoration scope and validation](PUBLIC-LANGUAGE-RESTORATION-2026-10-11.md).

Local QA titlebar/viewport diagnostics are stored outside the fixture Library. They must not weaken recovery's strict file allowlist. Gate17 attempt 01 exposed this harness conflict when an audit file prevented the recycle-bin preview from loading.
