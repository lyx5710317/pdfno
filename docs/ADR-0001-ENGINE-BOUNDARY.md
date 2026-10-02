# ADR 0001 · Temporary engine boundary

Status: historical implementation decision for the preserved foundation. Its future engine/fork direction is superseded by [ADR 0002](ADR-0002-NATIVE-APPLE.md), approved 2026-10-02: Swift native UI, PDFKit, independently selected EPUB adapter, long-term Mac/iPhone/iPad support.

The statements below describe the original baseline and decisions, not the current future route. The later audit found public Kookit core source; distinguish that core from the unverified `kookit-extra` products. See [the corrected evidence](EPUB-ENGINE-AUDIT.md#koodokookit-研究的修正与保留). Existing demo code, stores and the bridge remain intact.

At the initial baseline, the existing PDFno directory contained no code and Koodo was the candidate basis. Its root AGPL text and closed-source description for `kookit-extra` did not resolve those products' separate distribution/source rights. Copying its package wholesale would have mixed that unresolved boundary with the authored prototype. Later discovery of public Kookit core source is recorded separately and does not resolve the extra products.

For this authorised skeleton task, implement a narrow ReaderAdapter capability boundary and a self-authored demo adapter. Build the React/Electron workspace, source snapshots, local notes, task events and native protocol against legal fixtures. Preserve the full candidate format inventory; every genuine format is reported unavailable.

This is not approval for a full rewrite, removal of Koodo's formats, or migration of user databases. Following license clarification, assess a low-intrusion Koodo integration or other explicitly approved engine against real format tests. That choice needs its own decision and evidence.

Temporary JSON notes provide a reproducible local persistence slice with version checks and backup. They are not the final SQLite architecture. No existing database is migrated. Provider configuration stays nonsecret and in memory until a reviewed secure credential store exists. Native capabilities remain a query-only protocol, while iCloud, Bookno and conversion are explicit contracts/statuses without hidden transports.
