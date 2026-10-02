# Third-party notices

Dependencies are installed from the public npm registry and pinned by `package-lock.json`; they are not vendored. Retain their license and NOTICE files when distributing any future compiled package. `npm run notices` generates `docs/dependency-inventory.json` from the lockfile, including transitive packages and declared license values. Metadata alone is not a complete distribution audit.

| Direct dependency | Purpose | Declared license |
| --- | --- | --- |
| React / React DOM | Renderer | MIT |
| Electron | Desktop runtime | MIT, with bundled Chromium/Node notices and other component licenses |
| Vite / React plugin | Build and development | MIT |
| TypeScript | Type checking | Apache-2.0 |
| ESLint / typescript-eslint / Prettier | Lint / formatting | MIT |
| Vitest / jsdom | Unit tests / DOM fixtures | MIT |
| Playwright Test | Desktop automation | Apache-2.0 |
| DefinitelyTyped type packages | Development types | MIT |

Exact versions and npm-declared licenses are recorded in the inventory. Electron's binary includes its own `LICENSE` and `LICENSES.chromium.html`; preserve both in future packages. No distributable application binary is published by this source-only skeleton task. Apple Foundation, Swift runtime and SDK are system/toolchain dependencies; no Apple SDK, certificate or provisioning file is redistributed.

## Excluded / pending

No Kookit product is included. Public Kookit core rendering source has been located with an AGPL-3.0-or-later declaration; this does not settle the separate `kookit-extra` products or establish provenance for existing minified bundles. The original broad closed-source wording is qualified by the [updated audit](docs/EPUB-ENGINE-AUDIT.md). No dictionaries, OCR/conversion engines, proprietary binaries, bundled fonts or UPDF assets are included. No private Bookno/JapaneseLearningApp/NihongoFlow code is included. Future additions need a file-level source, license and distribution record before integration.

## Native direction: research only

The documentation revision of 2026-10-02 selects PDFKit as the future PDF framework and preserves AGPL-3.0-or-later for PDFno source. Apple PDFKit/WebKit/CloudKit are future system-framework links, not redistributed SDKs or source dependencies added here. EPUB candidates remain uninstalled: Readium Swift 3.11.0 (BSD-3-Clause), foliate-js (MIT), and epub.js (BSD-2-Clause). Their actual selected transitive libraries, embedded assets and distribution notices still require a complete audit before integration. The npm lockfile and inventory are unchanged; this list is not a declaration that new third-party code ships in PDFno.
