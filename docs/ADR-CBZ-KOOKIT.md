# ADR: bounded CBZ comic reading through the Kookit / WKWebView route

Date: 2026-10-03. Status: implemented in the comics feature branch; desktop reading acceptance pending.
Base: `aaba190a878df9de5674491d20f1b36fa4733607`. License: PDFno remains AGPL-3.0-or-later.

## Decision and delivered slice

Use the existing native library and an independent `comics-v1.json` manifest, with immutable, hash-named CBZ originals in `Originals`. PDF stays in PDFKit. The CBZ content host is an isolated Mac WKWebView and the fixed Kookit `makeComicBook` model. Archive decoding and image admission run in Swift before any book content reaches WebKit. This is a format-specific bounded loader/adapter, following the existing EPUB integration; the full upstream ComicRender runtime is not imported.

The user can import CBZ, reopen it from the library, select pages, turn forward/backward, select left-to-right/right-to-left reading, and select automatic/single/double layout. Covers and landscape pages stay single; portrait pairs and an odd final page are reachable. Automatic pairing requires a viewport at least 900 points wide and wider than tall. Direction changes the visual pair order and navigation chevrons, while progress uses logical order. A persisted position records schema, edition, original hash, exact page path/index, direction and layout. Reopening reads fresh saved state and checks the archive hash and complete page manifest. Resizing preserves the logical current page.

Page order is deterministic numeric full-path order, independent of user locale. Numeric tokens do not parse into bounded machine integers, so very long page numbers cannot overflow. Leading zeros/spelling provide a stable tie break. Native order is applied explicitly over the upstream model's locale sort; synthetic `.png` aliases handle uppercase source extensions. Archive paths and filenames never become HTML or JavaScript source.

## Source and dependency audit

Kookit is pinned to `95f602ed62d204af0de9278cf53212c309b34bfc`, matching the existing EPUB profile. [ComicRender.ts](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/renders/ComicRender.ts) explicitly routes ZIP/CBZ into `makeComicBook`, then renders pre-paginated sections. [comic-book.js](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/libs/comic-book.js) provides sections, TOC, image/page blobs, unload/revoke and pre-paginated layout. [package.json](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/package.json) declares AGPL-3.0-or-later; its [LICENSE](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/LICENSE) is preserved in the comic resource notices.

The one new upstream source file has Git blob SHA-1 `f75f4876e33ca06a83fee9ea9f60981dcdc9f18f`, SHA-256 `fb8b11ffead40f2ab48530e0c00ebe670e71cc36225bba9a33222dd6dc8ee45c`, 2247 bytes. `engine-build/COMICS-SOURCE.json` and `build-comics.mjs` verify both hashes before a deterministic source-only wrapper is generated. No package install, new npm dependency, compiler download, RAR worker, WASM or executable is needed. Existing EPUB engine inputs/resources are unchanged. The builder strips only the fixed export keyword and retains all original source and comments; PDFno adapter source and Kookit license are available alongside the output.

Swift uses Apple SDK ImageIO/UniformTypeIdentifiers and the SDK's dynamically linked zlib for stored/raw-deflate ZIP data. These are platform libraries, not downloaded or vendored binaries. The [zlib license](https://zlib.net/zlib_license.html) and SDK header retain their original authors/terms. This change does not claim those platform components were authored or relicensed by PDFno.

## Security boundary and limits

* At most 100 MiB original CBZ, 2000 archive entries, 16 MiB per decompressed entry, 512 MiB total decompressed bytes, 24M pixels per image, 16000 pixels per dimension and 512M admitted pixels per archive. All entries, including ignored metadata, must match real decompressed length and CRC. A deflate operation allocates only the admitted size plus one overflow-detection byte; it never falls back to a more permissive loader. File reads themselves are capped at archive limit plus one byte.
* Validate original central and local names before any normalization, reject traversal, absolute/drive/backslash/percent/control paths, canonical/case duplicates, symlinks/special files, overlapping records, encryption, unsupported compression/flags, split archives, ZIP64 and malformed extra fields. Signed and unsigned ordinary data descriptors are verified. Only UTF-8 names (or ASCII without the UTF-8 flag) are admitted. There is no filesystem extraction or shell archiver.
* Accept only ImageIO-complete, one-image PNG/JPEG resources. Other recognized image formats fail explicitly instead of silently losing pages. Ignore validated hidden/macOS metadata and non-image metadata. Import decodes a thumbnail to catch malformed rasters before committing. Image dimensions are checked before raster allocation; EXIF orientation is applied. Export to the viewer is always a static PNG thumbnail with maximum dimension 2400, stripping original metadata/active payloads. At most the current one/two pages are retained in the WebKit model; old Kookit blob URLs are revoked.
* WKWebView uses a nonpersistent data store, an exact app-asset scheme allowlist, no-network CSP and per-protocol content rules. Book frames have `allow-same-origin` without script permission and contain only trusted generated image markup. Main-frame navigation is limited to the shell; subframe navigation is limited to local blobs/about:blank. The bridge checks version/session/book/edition/hash/request and exact requested indices. Native ready/render deadlines, cancellation/generation checks and WebKit process termination prevent stale results updating a new session. Persistence occurs only after rendering acknowledges the exact spread.
* Comic switching cancels AI and excludes the old hidden PDF/EPUB source from AI capture/validation/return. No comic OCR or comic-to-AI source capability is claimed.

## CBR audit and explicit exclusion

At the fixed Kookit commit, the CBR/RAR branch calls `window.RPC.new("./lib/libunrar/worker.js")`, then `unrar`, and loads the returned `fileContent` arrays. The comic source itself does not identify/pin the worker, generated decoder, compiler or their complete corresponding source/licenses. The separately inspected [Koodo worker](https://github.com/koodo-reader/koodo-reader/blob/master/public/lib/libunrar/worker.js) imports `libunrar.js` and `rpc.js` and returns complete decoded file arrays; this mutable master reference is audit context, not an approved runtime input. There is no PDFno resource bound established on that path.

RARLAB separately publishes [UnRAR source/addon information](https://www.rarlab.com/rar_add.htm). That does not establish the provenance or license of Koodo's exact generated assets, and Kookit's root AGPL declaration cannot substitute for that evidence. No worker, decoder or RAR binary was downloaded or installed. CBR is therefore rejected explicitly and omitted from the picker. Before opening CBR, pin the actual decoder/toolchain and corresponding sources, verify the actual third-party licenses and distribution terms, and add streaming output/pixel limits plus isolated malicious RAR tests. This ADR does not claim CBR support or a completed decoder license audit.

## Verification and remaining limits

All test images/ZIPs are generated from original colors/geometry in `ComicTests.swift`; no user document is copied or uploaded. The test suite covers stored/deflate archives, data descriptors, numeric order/uppercase extensions, downsampling, paths, duplicate/canonical names, CRC, lying output sizes, archive/entry/total/count limits, malformed/overlapping/ZIP64 records, invalid/unsupported/oversized images, cover/spread/odd/landscape behavior, exact restoration of direction/layout, wrong editions/paths, source replacement, deduplication, and refusal to overwrite future/corrupt stores.

`comics-reader.test.mjs` runs the actual generated Kookit profile in a simulated DOM to check pair order, current-spread URL lifetime, stale identity/command/page rejection, image failure cleanup and render serialization. These adapter tests do not establish real WebKit layout, visual fit or accessibility acceptance. The independent comic CI rebuilds/compares resources and runs both suites without installing packages.

Commands:

```sh
node engine-build/build-comics.mjs
node --test engine-build/comics-reader.test.mjs
swift test --package-path apple/Packages/PDFnoKit --scratch-path /tmp/pdfno-comics-build --filter ComicTests
python3 scripts/check-native-source.py
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/pdfno-comics-mac CODE_SIGNING_ALLOWED=NO build
```

Desktop UI/WebKit acceptance was deliberately not run on the user's Mac, as requested. The coordinator should use an isolated test app/store to confirm import, rendered cover, portrait/landscape resize, LTR/RTL spreads, page jump, close/reopen, broken-file error and PDF/EPUB transitions. Mobile comic reading, CBR/CB7/CBT, GIF/WebP/SVG/HEIC, ComicInfo-driven page order/direction, zoom/pan, continuous scroll, OCR, extraction/export/conversion, bookmarks/notes, cross-process store coordination and comprehensive accessibility remain outside this slice. Views use bounded downsampled images rather than original-resolution zoom. Manifest commits are atomic with a backup, but there is no cross-process transaction across original and manifest; an interrupted import can leave an unreferenced original.

Shared integration touch points: `Package.swift` (Readers-to-Services dependency and Comics resource), `LibraryModel.swift` (repository/session state, extension routing, exclusive session switching and AI guard), `LibraryWorkspace.swift` (book list, picker, detail view, feature status). All other implementation/test/CI/source-provenance files are additive. Coordinate those three files with concurrent Word/conversion/AI branches.
