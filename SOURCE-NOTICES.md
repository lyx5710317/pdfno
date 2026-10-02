# Source and modification notices

Copyright (C) 2026 PDFno contributors. PDFno-authored source and self-authored fixtures are licensed under AGPL-3.0-or-later. The complete GNU Affero General Public License version 3 appears in `LICENSE`.

## References

- Koodo Reader, by App by Troye and contributors: [fixed commit 90e659f0188795f9a4f6e1ccc1727fd3793fe4a4](https://github.com/koodo-reader/koodo-reader/tree/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4), package version 2.4.5. Used to assess the candidate React/Electron architecture, format inventory and licensing boundary. The license document itself was obtained unchanged from [upstream LICENSE](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/LICENSE). No application source, branded resource or minified engine is copied into this repository. Preserve all applicable upstream notices if later licensed source is integrated.
- UPDF desktop interface organisation: described by the development specification's sanitised observation record. No UPDF code, icon, screenshot, logo, font or account resource is included. The PDFno mark and sample covers are authored with text and CSS.
- PDFno AI development specification, internal v0.2, Library version 1, obtained 2026-10-01. Filename remains `PDFno_AI_Development_Spec_v0.1.md`; SHA-256 `5c33d02a0b5a973a68d12462e2f8af18a5e284336d7728206b22f48e63a84cbb`. The source specification is a private development input and is not published in this repository.
- Bookno and the Japanese learning projects mentioned by the specification remain interface/reference directions. Their private source and project assets were not read for copying or included here.
- The 2026-10-02 native architecture/migration documents follow the user's explicit Swift native UI + PDFKit decision and preserve the prior product goals and AGPL choice. Their proposed targets, data contracts, stages and tests are authored plans, not implemented app source. The private specification is neither changed nor republished.
- The updated [EPUB audit](docs/EPUB-ENGINE-AUDIT.md) records primary Apple framework documentation and fixed public source/license evidence for Readium Swift 3.11.0, foliate-js, epub.js and Kookit core. They are research references only; no candidate source, dependency, bundled font, fixture or build product is copied into this revision. Kookit core's public AGPL declaration is distinguished from the separate unverified `kookit-extra` bundles.

## This revision

The current revision updates documentation only: an approved native-route ADR, the Apple app/platform/iCloud/migration plan, a pinned EPUB platform/license audit, and consistent roadmap/history/source notices. No application, dependency, project, entitlement or store changes are made. The previous self-authored shell, snapshot/Unicode utilities, mock provider, note repository, restricted IPC and capability-only CLI are preserved as the historical baseline; their tests do not establish native PDF/EPUB support.

## Fixture provenance

All text in `src/reader/demo.ts` and the ruby `本 / ほん` sample is self-authored for this project. Sample edition fingerprints are SHA-256 of the canonical blocks joined by newline in page order; they are demo-text content fingerprints, not a claim about PDF/EPUB file bytes. UI test images show only these fixtures and the authored shell, with isolated test data. No private books or desktop screenshots are published.
