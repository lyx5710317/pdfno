# PDFno

Mac-first language-learning reader, with long-term support for Mac, iPhone and iPad.

**Approved direction (2026-10-02): Swift native UI + PDFKit for PDF; an independently selected EPUB adapter.** New development on the React/Electron route is stopped. This revision updates documents only; the existing demo and Swift command-line bridge are preserved. No native GUI app targets or EPUB dependency have been created.

Start with [the approved architecture decision](docs/ADR-0002-NATIVE-APPLE.md), [native Apple implementation and migration plan](docs/NATIVE-APPLE-PLAN.md), and [EPUB platform/license audit](docs/EPUB-ENGINE-AUDIT.md). Implementation details in those plans are proposals unless explicitly marked approved or implemented. The original functional goals and **AGPL-3.0-or-later** choice remain.

**This is a runnable development skeleton, not a working PDF/EPUB reader or an AI product.** It uses self-authored Japanese and English text fixtures and local mock events. No books are uploaded and no model service is called.

## Implemented in the preserved demo

- Library, document tabs, outline, text search, return navigation, font size and light/dark appearance.
- Canonical single-block text selection that excludes author ruby annotations; code point offsets and immutable source snapshots, with fingerprint validation on return.
- Per-document tasks and per-mode note drafts. Local mock success, rate limit, partial result and cancellable waiting scenarios.
- Versioned local notes, stable IDs, revision conflict checks, atomic JSON replacement and a previous-version backup. Corrupt or newer stores are preserved and saving stops.
- Sandboxed Electron renderer, restrictive production CSP, fixed IPC channels, main-frame sender checks, denied permissions/navigation/new windows; only the two fixed source/license links may open in the system browser.
- Native capability query integrated with Electron. The unsigned Swift bridge builds through Xcode and explicitly reports Keychain as not integrated and iCloud as disabled.

## Not implemented

Real PDF/EPUB/comic/other-file reading or import; real BYOK, model requests, translation, grammar or dictionary generation; complete highlight editing, SQLite migrations, OCR, conversion, Bookno transport/cover exchange, iCloud sync, signed application packaging and automatic updates.

The original PDF/EPUB/comic/other-format goals remain inventoried in [P0 audit](docs/P0-AUDIT.md) and the native plan. PDFKit is the approved PDF framework; it does not supply all those formats. Koodo is now a historical architecture and format reference, rather than the future main-app foundation. Public Kookit core source has been found and its AGPL declaration checked; this does not resolve the separate `kookit-extra` bundles or prove their corresponding source. No Koodo/Kookit implementation, binaries, dictionaries, bundled fonts, UPDF assets or private project code are included. See the audit for the corrected boundary.

## Run the preserved demo on macOS

These commands run the existing React/Electron demo and capability-only CLI. They do not build the planned SwiftUI/PDFKit application. Its future `apple/` Xcode application workspace is described in the native plan and does not exist yet.

Use Node **24.15+** (tested with 24.21.0), npm and Xcode command-line tools. `.nvmrc` records the tested Node version. Nothing in setup requests new certificates or cloud credentials.

```sh
npm ci
npm run electron:install
npm run native:build
npm run native:check
npm run dev
```

For the built app:

```sh
npm run build
npm start
```

Open `native/PDFno.xcworkspace` in Xcode and run the shared `PDFnoBridge` scheme, whose argument is `capabilities`. The main user interface remains in Electron. The bridge also has a Swift Package manifest for source editing; Electron uses the Xcode build output at `native/build/Build/Products/Release/PDFnoBridge`.

For browser-only exploration use `npm run dev:web`; native capabilities are unavailable, and demo notes use that browser origin's localStorage. Electron notes use the dedicated PDFno application support directory (`app.getPath('userData')/library/notes-v1.json`). No API key field is exposed until secure native credential storage is integrated.

## Verify

```sh
npm run lint
npm run typecheck
npm test
npm run build
npm run native:build
npm run native:check
npm run test:e2e
npm run notices
npm run check:source
```

Run `npm run electron:install` before desktop tests so a first-time runtime download does not consume their 30-second timeout. Desktop tests launch the locally installed Electron using a temporary isolated user-data directory; no separate browser download is needed. They require a macOS graphical session. Check [validation evidence](docs/VALIDATION.md) for actual results and untested areas.

## Existing architecture and planned replacement

`src/reader` is the format capability / demo adapter boundary. `src/domain` owns source anchors, provider contracts, mock task events and future module contracts. `src/services` routes notes to desktop IPC or browser demo storage. `electron` owns local file persistence, IPC checks and the fixed native executable invocation. `native` is an unsigned Swift command-line tool, with no entitlements or cloud containers. It has no arbitrary file, shell or key operation.

The approved future app uses a native macOS target and an iOS target supporting iPhone/iPad, with shared Swift domain/storage/services, a PDFKit adapter, and an independently evaluated EPUB adapter. The new application code is planned under a separate `apple/` directory in this repository; existing directories and stores are retained until an explicit migration and retirement step. File access, Keychain and synchronization will be native services, with book content kept outside their trust boundary.

UI borrowings are limited to the workspace organisation described in the development specification: document tabs, separate navigation and learning panes, contextual actions and explicit task/source status. Visual assets are newly authored; system fonts are referenced without bundling font files. Bookno family design tokens still need approved evidence.

## Data and recovery

Note schema version 1 is a skeleton format, not Koodo or Bookno data. Never point the app at those databases. A successful update keeps `notes-v1.json.backup` before atomic replacement. If parsing, schema or revision validation fails, the original file is preserved. Stop PDFno before manual recovery, keep copies of both files, verify the backup through `parseStore`, and replace only after reviewing its contents. A future schema migrator and in-app recovery preview remain open tasks. Browser demo storage is separate and has no desktop backup guarantee.

## Native roadmap

1. Complete the documentation change before adding application code; preserve the current runnable baseline.
2. In a subsequent implementation slice, create real macOS and iPhone/iPad Xcode app targets and shared Swift modules in `apple/`.
3. Validate native local import and PDFKit reading, selection, geometry, note persistence and recovery using legal fixtures.
4. Evaluate EPUB engines on all three devices, choose an adapter with recorded license/dependency evidence, then implement it. Readium Swift's iOS support does not establish native macOS support.
5. Port source/task behavior, establish versioned repositories and a reviewed importer for legacy demo data; integrate native Keychain and controlled BYOK only within its own approved scope.
6. Decide iCloud record/asset scope, implement local conflict/retry behavior, then validate PDFno-owned CloudKit on real devices. Agree Bookno's separate exchange contract and evaluate each conversion direction independently.
7. Complete three-device accessibility/recovery testing and separately review signing, distribution terms, notarisation and application release gates.

These are planned steps, not claims of completed features or a release date. See [native tasks](docs/NATIVE-TASKS.md) and [ADR 0002](docs/ADR-0002-NATIVE-APPLE.md). [ADR 0001](docs/ADR-0001-ENGINE-BOUNDARY.md) remains the historical demo decision; its future-route section is superseded.

## Sources and license

PDFno source is Copyright (C) 2026 PDFno contributors, released under **AGPL-3.0-or-later**, without warranty; the [full license](LICENSE) accompanies the source. [SOURCE-NOTICES](SOURCE-NOTICES.md) distinguishes references from copied code and [third-party notices](THIRD_PARTY_NOTICES.md) cover direct dependencies. The [locked dependency inventory](docs/dependency-inventory.json) records all npm entries and license metadata.

The historical reference is [Koodo Reader](https://github.com/koodo-reader/koodo-reader/tree/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4), whose root license is AGPLv3. Its architecture table marks `kookit-extra.min.mjs` closed source; the separately published [Kookit core](https://github.com/koodo-reader/kookit/tree/95f602ed62d204af0de9278cf53212c309b34bfc) has public rendering source and an AGPL-3.0-or-later package declaration. These are distinct evidence boundaries. No implementation or engine binary from either is vendored here. UPDF is an interface-organisation reference only. PDFno is independent; no official Koodo/UPDF identity, signing account or service is used. Apple system frameworks and prospective EPUB dependencies are discussed in the native documents; none is newly bundled by this documentation revision.
