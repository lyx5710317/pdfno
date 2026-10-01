# PDFno

Mac-first language-learning reader foundation. React + Electron is the main app; a small Swift command-line bridge and Xcode workspace establish the future native boundary.

**This is a runnable development skeleton, not a working PDF/EPUB reader or an AI product.** It uses self-authored Japanese and English text fixtures and local mock events. No books are uploaded and no model service is called.

## Implemented

- Library, document tabs, outline, text search, return navigation, font size and light/dark appearance.
- Canonical single-block text selection that excludes author ruby annotations; code point offsets and immutable source snapshots, with fingerprint validation on return.
- Per-document tasks and per-mode note drafts. Local mock success, rate limit, partial result and cancellable waiting scenarios.
- Versioned local notes, stable IDs, revision conflict checks, atomic JSON replacement and a previous-version backup. Corrupt or newer stores are preserved and saving stops.
- Sandboxed Electron renderer, restrictive production CSP, fixed IPC channels, main-frame sender checks, denied permissions/navigation/new windows; only the two fixed source/license links may open in the system browser.
- Native capability query integrated with Electron. The unsigned Swift bridge builds through Xcode and explicitly reports Keychain as not integrated and iCloud as disabled.

## Not implemented

Real PDF/EPUB/comic/other-file reading or import; real BYOK, model requests, translation, grammar or dictionary generation; complete highlight editing, SQLite migrations, OCR, conversion, Bookno transport/cover exchange, iCloud sync, signed application packaging and automatic updates.

Koodo remains the candidate foundation and multi-format direction. This temporary shell isolates unknown engine licensing; it does not settle a rewrite or engine replacement decision. Candidate formats are inventoried in [P0 audit](docs/P0-AUDIT.md). Kookit binaries, dictionaries, fonts, UPDF assets and private project code are excluded.

## Run on macOS

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

## Architecture

`src/reader` is the format capability / demo adapter boundary. `src/domain` owns source anchors, provider contracts, mock task events and future module contracts. `src/services` routes notes to desktop IPC or browser demo storage. `electron` owns local file persistence, IPC checks and the fixed native executable invocation. `native` is an unsigned Swift command-line tool, with no entitlements or cloud containers. It has no arbitrary file, shell or key operation.

UI borrowings are limited to the workspace organisation described in the development specification: document tabs, separate navigation and learning panes, contextual actions and explicit task/source status. Visual assets are newly authored; system fonts are referenced without bundling font files. Bookno family design tokens still need approved evidence.

## Data and recovery

Note schema version 1 is a skeleton format, not Koodo or Bookno data. Never point the app at those databases. A successful update keeps `notes-v1.json.backup` before atomic replacement. If parsing, schema or revision validation fails, the original file is preserved. Stop PDFno before manual recovery, keep copies of both files, verify the backup through `parseStore`, and replace only after reviewing its contents. A future schema migrator and in-app recovery preview remain open tasks. Browser demo storage is separate and has no desktop backup guarantee.

## Roadmap

1. Clarify Kookit source and redistribution rights; approve a licensed ReaderAdapter and measure genuine PDF/EPUB/comic rendering, selections and annotation coordinates.
2. Agree the first learning slice, integrate secure credential storage and a controlled OpenAI-compatible adapter; evaluate real language quality separately from schema checks.
3. Establish SQLite repositories, migrations and backups; validate PDF geometry and EPUB reflow with licensed fixtures.
4. Agree Bookno's versioned metadata, cover and note contract with receiver-side preview/conflict/receipt semantics.
5. Decide device/content scope and a PDFno-owned iCloud adapter; evaluate each conversion direction separately.
6. Complete accessibility/device testing, signing, notarisation and application release gates.

These are retained directions, not claims of completed features or a release date. See [native tasks](docs/NATIVE-TASKS.md) and [architecture decision](docs/ADR-0001-ENGINE-BOUNDARY.md).

## Sources and license

PDFno source is Copyright (C) 2026 PDFno contributors, released under **AGPL-3.0-or-later**, without warranty; the [full license](LICENSE) accompanies the source. [SOURCE-NOTICES](SOURCE-NOTICES.md) distinguishes references from copied code and [third-party notices](THIRD_PARTY_NOTICES.md) cover direct dependencies. The [locked dependency inventory](docs/dependency-inventory.json) records all npm entries and license metadata.

The candidate upstream is [Koodo Reader](https://github.com/koodo-reader/koodo-reader/tree/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4), whose root license is AGPLv3 and whose architecture document calls Kookit closed source. No Koodo application implementation or engine binary has been vendored in this skeleton. UPDF is an interface-organisation reference only. PDFno is independent; no official Koodo/UPDF identity, signing account or service is used.
