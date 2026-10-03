# ADR 0005 — Independent Mac DeepSeek short-sentence self-test

Date: 2026-10-03. Status: native entry implemented; development uses intercepted synthetic requests only. Actual provider connectivity, cost and language quality are **NOT-RUN**. The reader AI remains the offline slice in [ADR 0004](ADR-0004-SELECTION-AI.md).

## Authorised scope and user action

The requested provider is DeepSeek, base endpoint `https://api.deepseek.com`, model `deepseek-flash`. This entry is a separate Mac native sheet under model settings. It never reads the current book/selection/notes, provider preview secret, existing Keychain or another app. Opening settings, opening the sheet or importing/reading a book does not submit a request. There is no automatic test, fallback, retry or account setup.

The complete outbound messages are displayed before submission:

- System instruction: `Translate the following original test sentence into Simplified Chinese. Return only one short sentence.`
- User sentence: `A small blue bird rests beside a quiet window.`

Both are original PDFno text. Endpoint, path, model and text are immutable in this limited entry. The user must manually enter a new temporary key in this sheet's SecureField, explicitly confirm the displayed content and fee scope, and personally click the final send button. Keys are never taken from chat, screenshots, accessibility, logs or configuration preview. An agent must not fill/read/copy a real key or click live submission. A configuration-complete message does not establish consent to charges or actual connection success.

The proposed budget is at most RMB 1, with at most three submissions in this application session, 128 output tokens each and thinking disabled. Fee approval is still pending until the user explicitly confirms. This client cannot enforce the provider's monetary bill cap or know an account's current billing price; its numeric limit is requests/tokens, not a guaranteed RMB stop. Failed/cancelled/timed-out submissions conservatively consume an attempt and may still be charged. Reopening the sheet keeps the count; app restart resets this in-memory development counter, so it is not a durable account-level budget. Each send requires new manual input and fresh confirmation. No automatic retries.

## Native service and transient state

`DeepSeekSelfTest` is a bookless actor, not an `AIRequest` with fabricated PDF/EPUB anchors. It posts native JSON to the literal `https://api.deepseek.com/chat/completions`, with `Authorization: Bearer …`, `stream:false`, `max_tokens:128` and `thinking:{type:disabled}`. No files, images, tools, history, hidden reader context or retrieval chunks are included. It uses the shared ephemeral `URLSessionAITransport`: no cookie/cache storage, all authenticated redirects refused, and an actual 64 KiB response budget. No TLS/ATS exemption, server-side key relay or new SDK is introduced.

The actor validates consent/key before any submission and limits the total to three. A single continuation owner resolves worker/30-second-deadline/cancellation races; late responses cannot complete a cleared request. Native UI generation checks also prevent closed results from reappearing. Status errors are fixed messages for auth/quota/rate limit/redirect/network/server/format/cancel/timeout; raw error, response, headers, URL or key is never logged or copied to UI. A response must contain one assistant plain-text choice with `finish_reason:stop`, without tool/function calls, within 2,048 UTF-16 units. Truncated output is rejected rather than presented as a successful completed test. Rendering is `Text(verbatim:)`, with no HTML, link execution or tool handling.

Input clears when send begins; closing/cancelling clears input, confirmation and output and cancels work. The transient request needs an in-memory Authorization value until URLSession completes/cancels; Swift strings and framework buffers do not promise secure zeroisation. No credential, response, usage record or request is written to disk, Keychain, learning notes, iCloud or Bookno. Persistent Keychain activation and full reading BYOK remain separate future work. Existing application data schemas and originals are unchanged.

## Existing open app, validation and handoff

When a user has already entered a temporary value in an open older build, source changes and isolated builds must not quit/restart it, read its input region or overwrite its running bundle. This delivery builds a separate `.build/DeepSeekPreview` product without launching it. The user decides when to close the old preview and run the new version, then manually re-enters a new key; temporary input is not promised across restart. Local real-app UI tests that would relaunch that bundle are deferred to the separate CI machine. No screenshot or accessibility read of the entered key region is allowed.

Offline tests use only obviously synthetic keys, fixed synthetic response bodies and URLProtocol interception of **every** URL. They verify fixed host/path/model/messages/headers, consent before work, request/token limits, no retry on error, safe HTTP/JSON errors, redirect refusal, noncooperative cancellation/timeout, cleared native input and ignored late UI results. Ordinary PDF/EPUB/mock acceptance remains intact in CI. Exact counts, builds and exact-SHA CI evidence belong to [VALIDATION](VALIDATION.md).

Manual user acceptance: run the new Mac product when ready; open model settings → DeepSeek short-sentence self-test; read scope/limits and confirm the fees if accepted; enter a new key locally; personally click one request; inspect the plain result or safe error, then clear/close. Do not copy keys into chat or logs. A real successful response and the provider's own billing are the only evidence of actual connectivity/cost; intercepted tests and compiling an entry do not establish either.

## Official documentation, checked 2026-10-03

- [DeepSeek first API call](https://api-docs.deepseek.com/): official compatible API and base endpoint; the Chinese root timed out during this pass, so current API reference and English guide were read instead.
- [Create Chat Completion](https://api-docs.deepseek.com/api/create-chat-completion/): `POST /chat/completions`, `deepseek-flash`, `max_tokens`, nonstream messages and response contract.
- [Thinking mode](https://api-docs.deepseek.com/guides/thinking_mode/): thinking defaults on; an explicit `thinking.type:disabled` opts this short probe out.
- [Models and pricing](https://api-docs.deepseek.com/quick_start/pricing/): provider pricing is external and subject to change; this client does not hardcode a promised RMB cost.

These are primary wire-contract sources, not proof of a live signed client, network/TLS/proxy behavior, account entitlement, actual bill or language quality. No private SDK, account, key or copyrighted book was obtained.
