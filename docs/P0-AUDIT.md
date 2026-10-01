# P0 audit · 2026-10-01

## Local baseline

The existing Codex-registered `pdfno` project was located and used. It was empty, with no Git checkout, remote, existing source, `AGENTS.md` or `.agents/skills`. No existing work was overwritten. The sibling specification was not substituted for the authoritative Library file. Library version 1 was materialised through the current supported helper and read as internal version 0.2; its 94,484 bytes and hash are recorded in SOURCE-NOTICES.

User authorisation expands the specification's original read-only first-round instructions: implement a limited runnable foundation, run normal dependency/build checks, publish AGPL source and create native/Xcode groundwork. It does not approve all P1–P4 features, paid models, book uploads or native entitlements.

## Upstream evidence

All references are pinned to `90e659f0188795f9a4f6e1ccc1727fd3793fe4a4` on the Koodo `dev` baseline (package 2.4.5).

| Evidence | Static finding | Consequence |
| --- | --- | --- |
| [LICENSE](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/LICENSE) | Complete GNU AGPLv3 root text | Retain text/notices when using covered source; not proof for every embedded asset |
| [CLAUDE.md](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/CLAUDE.md), architecture / important reminders | Kookit ESM marked closed source; source referenced elsewhere | Engine modification/redistribution and corresponding source remain unconfirmed |
| [engine directory](https://github.com/koodo-reader/koodo-reader/tree/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/src/assets/lib) | Three minified products; no separate license or full engine source in this directory | No engine product included here; this is an unresolved boundary, not a finding of illegality |
| [package.json](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/package.json) | Electron, React, native SQLite, engine in package files; upstream signing and account settings | Do not reuse upstream identity, entitlements, accounts or binaries |
| [bookUtil.ts lines 1–140](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/src/utils/file/bookUtil.ts#L1) | Imports engine utilities, local file/database/sync services | A superficial fork could retain hidden engine and official service dependencies |
| [mouseEvent.ts lines 1–200](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/src/utils/reader/mouseEvent.ts#L1) | Selection clone strips rt/rp; sentence context separately uses textContent/Selection strings | Potential inconsistent ruby extraction warrants real-engine reproduction; no upstream bug is claimed reproduced |

No minified product was executed, modified, deobfuscated or published. The full Koodo build was **not run**: the engine/source licensing boundary remains open and the inspected snapshot is not a licensed production baseline for PDFno yet.

## Format inventory

Koodo's pinned architecture lists EPUB, PDF, MOBI, AZW3, AZW, TXT, FB2, CBR/CBZ/CBT/CB7, MD, DOCX and HTML/XML/XHTML/MHTML/HTM. This is static inventory, not a runtime probe. All remain candidate targets in `src/reader/capabilities.ts`. No existing PDFno reading support was present to regress; **all genuine formats are currently unavailable**. Only self-authored demo text is implemented. DRM/scan/OCR and conversion remain unavailable.

## Toolchain and build scope

Mac arm64 host, Xcode 27.0 (27A266a), Swift 6.4. System Node was 20.20.2 / npm 10.8.2. Current dependencies require newer Node; a temporary project build toolchain used official Node 24.21.0 without changing global Node. TypeScript 7.0.2 failed the lint peer constraint; TypeScript 6.0.3 was selected within the supported range rather than bypassing it. Exact dependencies are locked.

React/Electron skeleton and the capability-only native bridge are tested independently from any future reader. The native project builds a macOS 13+ universal CLI with no code signing, team, entitlements or provisioning updates. It does not implement Keychain or iCloud. Check VALIDATION for actual command outcomes, including untested Intel runtime and release gates.

## Decision / remaining gates

Publish only this authored foundation and declared dependencies under AGPL. Continue P0 by clarifying Kookit rights, choosing an approved ReaderAdapter, constructing legal PDF/EPUB/comic fixtures and measuring real selections, annotation restoration and geometry. Do not treat unit tests on demo text as EPUB/PDF validation. Do not infer a Bookno API or iCloud permission from another project's code. No paid model call, credential creation, book upload, signing or notarisation was performed.
