# Third-party notices

Current native source has **no external Swift package**. The Mac EPUB content adapter includes the independently licensed Kookit core and JS dependencies below. Node/npm/esbuild only build resources; they are not app runtimes. Its local `PDFnoKit` package and original fixtures are PDFno-authored AGPL-3.0-or-later source.

The applications link Apple system frameworks: SwiftUI, Foundation, AppKit/UIKit, PDFKit, WebKit, UniformTypeIdentifiers and CryptoKit. Swift/Xcode/SDK/test tools are installed system/toolchain components. No Apple SDK, framework implementation, bundled font, certificate or provisioning file is redistributed. Future compiled distribution requires review of the applicable platform/toolchain terms and notices.

The original PDF fixture references the standard PDF font Helvetica by name, without embedding a font program. Original text and fixture generator provenance appear in `SOURCE-NOTICES.md`.

## Historical dependencies and unselected candidates

React, Electron, Vite, TypeScript, ESLint, Vitest, jsdom and Playwright were used by the retired demo. Their pinned npm metadata remains in `docs/historical/dependency-inventory.json` and their lockfile in Git history/external recovery material. They are no longer current installation or execution requirements. Historical MIT/Apache/Chromium notices must still be retained if an old compiled demo is separately redistributed; npm metadata alone is not a distribution audit.

No Koodo application/extra engine, dictionary, OCR/conversion engine, private Bookno code, UPDF asset or proprietary binary is included. The selected public Kookit core source is pinned to `95f602ed62d204af0de9278cf53212c309b34bfc`. Standalone comparison candidates Readium Swift 3.11.0 (BSD-3-Clause) and epub.js (BSD-2-Clause) remain uninstalled; foliate-js (MIT) is embedded through Kookit; Kookit public core declares AGPL-3.0-or-later, separate extra bundles are unverified. Audit each selected version's actual dependencies, assets, corresponding source and platform distribution before future integration. See `docs/EPUB-ENGINE-AUDIT.md`.

## Mac EPUB resource

Kookit 1.0.4: AGPL-3.0-or-later. The fread-ink CFI upstream declares AGPL-3.0 (not automatically or-later). Embedded foliate-js retains the John Factotum MIT notice. The precise original declarations remain in `engine-build/licenses`; no claim of PDFno ownership or third-party relicensing is made.

Actual npm packages and integrity are in `engine-build/DEPENDENCIES.json` and the lock. JSZip 3.10.1 uses MIT; Rangy 1.3.0 and Underscore 1.13.8 use MIT; pako 1.0.11 preserves MIT and zlib, inherits 2.0.4 ISC, and the other selected helper packages preserve MIT. Build-only esbuild 0.25.11 and its platform compiler use MIT. Complete actual package license files, isarray README license, and pako original zlib header are copied into generated `Resources/EPUB/Notices.txt`. `BUNDLE-INPUTS.json` and original vendored source identify the corresponding source needed to rebuild. OpenCC mapping and all upstream PDF/other-format engines and unknown minified/WASM resources are excluded from the bundle.
