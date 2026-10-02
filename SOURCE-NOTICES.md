# Source and modification notices

Copyright (C) 2026 PDFno contributors. PDFno-authored Swift source, project generator, tests, fixture generator and original sample text are **AGPL-3.0-or-later**. The unchanged GNU Affero General Public License version 3 is in `LICENSE`.

## Current source and fixtures

The 2026-10-02 native implementation creates actual macOS and iPhone/iPad applications, shared Swift modules, PDFKit hosting and local book/note repositories. Pure Swift Unicode, author-ruby, immutable task-source and revision/backup contracts preserve behavior from the earlier self-authored demo. They do not copy a third-party reader implementation or provide actual AI/EPUB functionality. The retired Electron/React/CLI implementation remains recoverable in ordinary Git history and the owner's external backup.

`study-sample.pdf` in UI resources and test fixtures is generated from original English text by `scripts/generate-apple-project.py`. It is the same deterministic two-page document in both locations, with two original outline entries. It uses the standard PDF Helvetica font name without bundling a font file. No private or third-party book is included. Japanese `本 / ほん`, repeated-quote, emoji and combining-mark tests are original fixtures ported from the project's own prior demo. Current intentional Mac screenshot attachments target the isolated application window. Earlier ignored local results used application screenshots that can include the desktop; those diagnostics remain private and are not published or automatically uploaded.

## Research references

- [Koodo Reader fixed commit](https://github.com/koodo-reader/koodo-reader/tree/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4), package 2.4.5: historical architecture/format/licensing research. The project license text was obtained unchanged from [upstream LICENSE](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/LICENSE). No application code, assets, minified engine or binaries are vendored.
- [EPUB audit](docs/EPUB-ENGINE-AUDIT.md): Readium Swift, foliate-js, epub.js and Kookit core are uninstalled comparison candidates. Public Kookit core's AGPL declaration does not prove provenance of separate `kookit-extra` products. No EPUB engine is selected.
- UPDF provides sanitised information-organisation observations only. No private code, logo, icon, screenshot, font, account or bundled resource was copied.
- The full original private development specification (internal v0.2) was read before the v0.3 rewrite. The public v0.3 copy preserves the complete requirements, removes personal paths/Library identifiers/private-project URLs, and distinguishes architecture targets from implemented scope. Private original material and its version history are retained outside public source.
- Bookno and language-learning projects are interface/behavior references from that specification. Their private code, assets, containers and credentials are not included. The Bookno API remains independent and unimplemented.

Official framework sources and audit dates are cited in the specification. System APIs prove availability, not completed product behavior; actual validation evidence belongs to `docs/VALIDATION.md` and CI for its exact commit.
