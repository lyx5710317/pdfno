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

Kookit minified engines have unconfirmed redistribution and corresponding-source rights and are excluded. No dictionaries, OCR/conversion engines, proprietary binaries, bundled fonts or UPDF assets are included. No private Bookno/JapaneseLearningApp/NihongoFlow code is included. Future additions need a file-level source, license and distribution record before integration.
