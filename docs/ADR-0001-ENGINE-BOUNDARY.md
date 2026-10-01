# ADR 0001 · Temporary engine boundary

Status: implemented for the initial foundation; final engine/fork route remains undecided.

The existing PDFno directory contained no code. Koodo is the candidate basis, but its root AGPL text and closed-source description for Kookit do not resolve the engine's separate distribution/source rights. Copying its package wholesale would mix that unresolved boundary with the authored prototype.

For this authorised skeleton task, implement a narrow ReaderAdapter capability boundary and a self-authored demo adapter. Build the React/Electron workspace, source snapshots, local notes, task events and native protocol against legal fixtures. Preserve the full candidate format inventory; every genuine format is reported unavailable.

This is not approval for a full rewrite, removal of Koodo's formats, or migration of user databases. Following license clarification, assess a low-intrusion Koodo integration or other explicitly approved engine against real format tests. That choice needs its own decision and evidence.

Temporary JSON notes provide a reproducible local persistence slice with version checks and backup. They are not the final SQLite architecture. No existing database is migrated. Provider configuration stays nonsecret and in memory until a reviewed secure credential store exists. Native capabilities remain a query-only protocol, while iCloud, Bookno and conversion are explicit contracts/statuses without hidden transports.
