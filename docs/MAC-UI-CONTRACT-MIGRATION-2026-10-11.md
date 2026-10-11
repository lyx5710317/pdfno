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
| Separate BYOK chooser/settings pane | Current shared OpenAI-compatible connection. Assert explicit recipient/model setup, original selection, no automatic note save, explicit answer save, separate body/result, credential exclusion, endpoint-change revocation upon Apply, and independent whole-page credential/consent. |
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
