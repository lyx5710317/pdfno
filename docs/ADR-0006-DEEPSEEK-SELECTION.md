# ADR 0006 — Bounded DeepSeek reading selection

Date: 2026-10-03. Status: implemented, local offline suite/builds passed; exact-SHA actual Mac UI CI result is reported at delivery. The user reported three successful independent original-sentence probe calls and authorised the next minimal reading integration. This extends ADR0004 in the existing settings and PDF/EPUB learning windows, without a new app, target, identity or entry. AGPL, Mac-first three-platform scope, PDFKit and independent Kookit remain unchanged.

## Request and user action

Only HTTPS `api.deepseek.com`, default/443 port, supported normalised paths and exact `deepseek-flash` profile enable remote selection. Final URL is fixed to `https://api.deepseek.com/chat/completions`. Other configurations remain previews; mock requires explicit selection. Users manually enter a temporary key in the existing settings, save it, select text, inspect exact source/receiver/limits/fee scope, confirm and personally press start. No automatic send on import/open/selection/mode/config changes or retry/fallback occurs.

Source cap is 500 UTF-16 units (mock's existing source contract remains8000). Only sourceText/task and fixed instructions leave the device: no surrounding text, book identity, files, notes, saved results or history. Nonstream output cap is1024 tokens including JSON/echoed quote, thinking is disabled, JSON response format required, deadline30 seconds. Independent reading budget actor reserves at most three network attempts per app session, including later failure/cancellation; a cache hit uses no new network attempt but still needs consent. Restart resets memory counts, not account charges; cancellation cannot guarantee no bill. These are technical caps, not a currency billing guarantee. The independent bookless probe retains its separate three/128 limits and key.

## Credentials, provenance and completion

The private session store holds a UUID-referenced key only in memory. Empty input save or clear removes it; changing config cancels work and changes generation. No real Keychain item, persisted key, iCloud/Bookno secret or existing credential is accessed. Swift/Foundation memory cannot promise secure erasure. Relaunch retains nonsecret config/explicit notes, requires key re-entry and consent; model checks prevent cached or late output from an old credential/config generation appearing.

The existing request freezes reader session/version, book/edition/hash/extraction, PDF geometry or EPUB resource/span, provider/kind/prompt and request ID. A single continuation owner governs cancel/timeout; noncooperative late outputs cannot display/cache/save. Completion additionally checks the current source/config. Closing or switching books cancels unfinished work. Source return uses native original anchors; the model supplies no trusted coordinates/citation.

The response must have one completed assistant/stop choice, no actual tool/function calls, exact typed JSON keys/schemaVersion1, nonblank bounded plain text and Unicode-scalar-exact sourceQuote. Nullable absent/null tool fields are accepted. Truncation, mismatched quote, boolean schema and unknown fields fail safely. Ephemeral URLSession disables cookies/cache, refuses all redirects and consumes at most64KiB. Safe errors distinguish authentication401/403, quota402, rate429, timeout/cancel and truncation; no raw response/header/key/book logging. Book instructions stay data; output executes no HTML/links/tools.

## Data, cache and rollback

The20-entry memory success cache uses full source/provider/generation/kind/prompt; `deepseek-selection-1` separates these outputs from mock/older contracts. Up to10 safe request records are retained in memory and displayed for the current book. Same-source sheet reopen retains completed output and independent user draft; no result automatically writes notes. Explicit save keeps result/provenance/source separate from user text in the strict atomic/backup `learning-v1.json`. Existing PDF/EPUB manifests and original books do not change.

Learning schema1 now accepts both `selection-1` and `deepseek-selection-1`; this is an additive allowed-value change, not guaranteed backward readability. The older AI reader protects/rejects a file containing the newer prompt. Back up the complete learning file before downgrade; restore its earlier copy only after checking user notes. Earlier PDF/EPUB apps ignore the independent learning store, which must be retained. Cross-process recovery, automatic migration, editing/deleting AI notes and persistent cache remain gaps.

## Evidence and next acceptance

44 local Swift tests/eight suites and Mac build-for-testing/mobile compilation passed. Four complete actual Mac UI tests are configured in isolated CI: existing PDF, EPUB, mock flows plus an all-intercepted DeepSeek fixture flow with actual PDFKit/WebKit selection, confirmation, output, protected user notes/source return and restart key absence. The fixture marker is asserted before synthetic-key entry; DEBUG transport never falls through to URLSession. The user-running app is not read/restarted/overwritten for local UI tests. Actual CI counts/outcome must be obtained for the final SHA.

The independent probe's three successes are USER-REPORTED, not agent paid calls or new reader language-quality acceptance. Next the user can manually validate a small original PDF/EPUB selection. No page/chapter/book translation, Q&A, full structured English/Japanese grammar, kana generation, persistent Keychain, SSE/usage, other provider, mobile AI, cloud or release completion follows from this slice.

Official protocol sources checked2026-10-03: [Chat completion](https://api-docs.deepseek.com/api/create-chat-completion/) specifies JSON response_format and finish reasons; [Thinking mode](https://api-docs.deepseek.com/guides/thinking_mode/) specifies explicit disabled thinking. [JSON Output](https://api-docs.deepseek.com/guides/json_mode/) timed out in this check and is not counted as a fully read source. Limits/strict quote policy are PDFno decisions; intercepted tests validate construction and refusal, not real server/account/billing behavior.
