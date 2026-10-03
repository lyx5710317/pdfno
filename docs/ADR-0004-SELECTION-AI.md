# ADR 0004 — Mac selection AI and BYOK preview

Date: 2026-10-03. Status: implemented bounded offline reading slice; real reading provider and persistent credential validation pending. A later independent, bookless DeepSeek manual probe is specified in [ADR 0005](ADR-0005-DEEPSEEK-SELF-TEST.md); it does not enable this selection provider. Swift native UI, PDFKit, isolated Kookit EPUB, AGPL and Mac-first remain unchanged.

## Scope and product state

Mac settings offer unconfigured, explicitly selected local mock, and OpenAI-compatible configuration preview. Only non-secret provider/endpoint/model values persist. A SecureField can accept a temporary demonstration value; it stays in a session-only store and is never used for a remote request in this slice. No existing credentials are read, no persistent credential is installed, and there is no automatic mock fallback. The reading UI states that actual remote selection requests are disabled. Mock output is deliberately labelled synthetic and makes no language-quality claim.

Only a fixed selection is processed, at most 8,000 UTF-16 units. There is no implicit context, page/chapter/whole-book request, indexing, image/OCR upload, tool use, web fetch or paid API call. Translation and explanation are separate commands; the latter is not the complete structured English/Japanese grammar feature. User confirmation binds the displayed selection and provider/model before work starts.

## Source, task and result contract

`AISourceSnapshot` contains book ID, reader session, document version and the existing strongly typed PDF/EPUB anchor. The source carries edition/hash/extraction version, exact quote and PDF geometry or EPUB resource/span. PDF opens create new session IDs; EPUB uses its existing bridge generation/version. Request ID, complete source/provider fingerprint, kind and prompt version are frozen. Models return text and an echoed quote, never trusted navigation coordinates or citations. Scalar-exact quote checks reject substitutions and canonical-normalisation changes; citations are generated from the original snapshot and return only through reader validation.

`AIJobCoordinator` is an actor. Consent is checked before provider work or cache use. Unstructured worker/timeout tasks have one checked-continuation owner, removed before terminal completion. Cancellation/timeout returns even if a provider ignores cancellation; a late response cannot complete, cache or display an expired job. No automatic retry occurs. The UI checks source session/version and current provider config again after completion, cancels on switching books, and preserves user drafts independently of generated output. Closing this first modal sheet explicitly cancels unfinished work; a future persistent sidebar may use a separately specified background policy.

The memory cache holds at most 20 completed validated outputs, keyed by sorted-key encoded source/provider/kind/prompt data. It excludes request ID, timeouts and secrets. It conservatively includes reader session/version and config generation; reopen may miss the cache. Shared subscribers/coalescing, disk cache, partial streaming and cross-process persistence are pending. Cache clearing never deletes saved notes.

## Native service boundary and credentials

`OpenAICompatibleSelectionProvider` builds a JSON user-data message, a fixed instruction message, model and `stream:false`. It adds `/chat/completions` once (root defaults to `/v1/chat/completions`). HTTPS or explicit loopback HTTP is accepted; credential-bearing URL, query/fragment, control characters and invalid/oversized model values are rejected. Book instructions cannot change endpoint, headers, tools or native settings. The adapter has no filesystem/tool access.

`URLSessionAITransport` uses an ephemeral session without cookies/cache, refuses all redirects through its delegate and enforces a 64 KiB response budget while consuming bytes. Response schema/quote/text are checked. Auth, quota, rate limit, redirect, timeout, cancellation, network, malformed output and server failures map to fixed safe messages; raw response, URL errors, headers, key and book content are not logged. Output is rendered as plain text, without executing HTML or interpreting generated links. Actual TLS/ATS/proxy behavior and any service-specific wire contract are not established by intercepted tests.

`KeychainCredentialStore` exposes read/put/remove only for one UUID reference in a PDFno service namespace. The Security client uses generic-password items, exact service/account, non-synchronizable and device-only unlocked accessibility, without access group. A noninteractive `LAContext` prevents authentication prompts. Its default client is not instantiated by the UI. Tests inject an exact-item fake with synthetic values and inspect policy queries; they do not access the user's Keychain or prove live signed Keychain behavior. This distinction is required before enabling persistent configuration or real service validation.

## Persistence, migration and rollback

`learning-v1.json` holds only config metadata and explicit saved learning notes. Result provenance/source and user text are separate fields. Nested keys, schema, IDs, source bounds and text budgets are checked; unknown secret fields/future/corrupt state stop writes. Updates back up the prior manifest and atomically replace it. Existing strict `library-v1.json`, `epub-v1.json` and originals are untouched. Request IDs cannot be saved twice; regeneration never overwrites a saved user note.

Saved sources can be navigated after reopening the exact book/edition/hash, even though their old request session has expired. Live task/UI reuse requires the current session/version. The saved-note list is scoped to the current book. Rollback to the EPUB baseline retains originals and all three manifests; the older app ignores the independent learning store. Never delete it as a cache. Cross-process writing, crash/fsync tests, automatic migration and AI-note editing/deletion remain gaps.

## Verification and next gate

Automated tests use original fixtures, synthetic credentials, exact Keychain replacements, and a URLProtocol that intercepts every URL. They cover scope/consent, Unicode source refusal, cache boundaries, noncooperative late responses, real URLSession response limits, HTTP error sanitisation, redirect refusal, separate PDF/EPUB notes, protected user text and corrupt/future-store refusal. Mac UI checks use actual PDFKit selection and a real double-click WebKit selection; UI verification and exact-SHA CI outcomes are reported in VALIDATION/delivery, never inferred from the previous EPUB CI.

Next: decide the exact provider/protocol, authorised test text and cost limit before real service calls; then validate actual Keychain policy under the chosen signing/runtime. Do not treat mock success as translation, grammar, cloud, mobile or full T09/UAT completion. Page/chapter/whole-book translation remains a separate later slice.

Official sources read on 2026-10-03: Apple [Keychain services](https://developer.apple.com/documentation/security/keychain-services) for encrypted secret storage; [URLSessionTask.cancel](https://developer.apple.com/documentation/foundation/urlsessiontask/cancel()) states cancellation can precede final acknowledgement/messages; [HTTP redirect delegate](https://developer.apple.com/documentation/foundation/urlsessiontaskdelegate/urlsession(_:task:willperformhttpredirection:newrequest:completionhandler:)) documents nil as refusal and applies to ephemeral/default sessions. SDK compilation and offline tests validate interface usage; they are not an account, network or distribution approval.
