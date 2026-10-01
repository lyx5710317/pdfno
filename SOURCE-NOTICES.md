# Source and modification notices

Copyright (C) 2026 PDFno contributors. PDFno-authored source and self-authored fixtures are licensed under AGPL-3.0-or-later. The complete GNU Affero General Public License version 3 appears in `LICENSE`.

## References

- Koodo Reader, by App by Troye and contributors: [fixed commit 90e659f0188795f9a4f6e1ccc1727fd3793fe4a4](https://github.com/koodo-reader/koodo-reader/tree/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4), package version 2.4.5. Used to assess the candidate React/Electron architecture, format inventory and licensing boundary. The license document itself was obtained unchanged from [upstream LICENSE](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/LICENSE). No application source, branded resource or minified engine is copied into this repository. Preserve all applicable upstream notices if later licensed source is integrated.
- UPDF desktop interface organisation: described by the development specification's sanitised observation record. No UPDF code, icon, screenshot, logo, font or account resource is included. The PDFno mark and sample covers are authored with text and CSS.
- PDFno AI development specification, internal v0.2, Library version 1, obtained 2026-10-01. Filename remains `PDFno_AI_Development_Spec_v0.1.md`; SHA-256 `5c33d02a0b5a973a68d12462e2f8af18a5e284336d7728206b22f48e63a84cbb`. The source specification is a private development input and is not published in this repository.
- Bookno and the Japanese learning projects mentioned by the specification remain interface/reference directions. Their private source and project assets were not read for copying or included here.

## This revision

Newly authored application shell, source snapshot and Unicode utilities, local mock provider, note repository, restricted IPC, capability-only Swift bridge, tests and documentation. It is an experimental boundary around a pending engine integration, not a fork whose upstream format support has been validated. It does not select a full rewrite on the user's behalf.

## Fixture provenance

All text in `src/reader/demo.ts` and the ruby `本 / ほん` sample is self-authored for this project. Sample edition fingerprints are SHA-256 of the canonical blocks joined by newline in page order; they are demo-text content fingerprints, not a claim about PDF/EPUB file bytes. UI test images show only these fixtures and the authored shell, with isolated test data. No private books or desktop screenshots are published.
