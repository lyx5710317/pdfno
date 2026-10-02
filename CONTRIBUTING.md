# Contributing

The approved future direction is Swift native UI + PDFKit, with an independently selected EPUB adapter and long-term Mac/iPhone/iPad support. Read [ADR 0002](docs/ADR-0002-NATIVE-APPLE.md) and [the native implementation/migration plan](docs/NATIVE-APPLE-PLAN.md) before adding features. The React/Electron route is frozen for new development; its existing code, tests, stores and CLI remain preserved. The 2026-10-02 change is documents only, not permission to replace old code or activate cloud/signing capabilities.

Use the locked dependencies and run the checks in README. Keep book content and model output untrusted. Validate IPC senders and payloads. Never add generic command, path, SQL or credential APIs to the renderer.

Preserve user notes and source snapshots; changes to persistent formats need version handling, fixtures and a reviewed migration/restore path. Keep mock outcomes labelled and document unsupported capabilities. Do not conflate local saves, sent batches and receiver confirmation.

For each engine, asset or source addition, record its origin, license and redistribution rights before committing. Do not include private books, screenshots, keys, certificates, proprietary engines or private-project code. Native entitlements, containers, real models and application release gates require separately approved scope.
