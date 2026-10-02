# Third-party notices

Current native source has **no external Swift package or npm runtime dependency**. Its local `PDFnoKit` package and original fixtures are PDFno-authored AGPL-3.0-or-later source.

The applications link Apple system frameworks: SwiftUI, Foundation, AppKit/UIKit, PDFKit, UniformTypeIdentifiers and CryptoKit. Swift/Xcode/SDK/test tools are installed system/toolchain components. No Apple SDK, framework implementation, bundled font, certificate or provisioning file is redistributed. Future compiled distribution requires review of the applicable platform/toolchain terms and notices.

The original PDF fixture references the standard PDF font Helvetica by name, without embedding a font program. Original text and fixture generator provenance appear in `SOURCE-NOTICES.md`.

## Historical dependencies and unselected candidates

React, Electron, Vite, TypeScript, ESLint, Vitest, jsdom and Playwright were used by the retired demo. Their pinned npm metadata remains in `docs/historical/dependency-inventory.json` and their lockfile in Git history/external recovery material. They are no longer current installation or execution requirements. Historical MIT/Apache/Chromium notices must still be retained if an old compiled demo is separately redistributed; npm metadata alone is not a distribution audit.

No Koodo/Kookit engine, dictionary, OCR/conversion engine, private Bookno code, UPDF asset or proprietary binary is included. EPUB comparison candidates remain uninstalled: Readium Swift 3.11.0 (BSD-3-Clause), foliate-js (MIT), epub.js (BSD-2-Clause); Kookit public core declares AGPL-3.0-or-later, separate extra bundles are unverified. Audit each selected version's actual dependencies, assets, corresponding source and platform distribution before future integration. See `docs/EPUB-ENGINE-AUDIT.md`.
