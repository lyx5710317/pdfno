# Native CB7 / CBR increment — 2026-10-04

Useful result: finite Mac CB7 COPY/LZMA/LZMA2 and CBR RAR4/RAR5 STORE import, mixed comic library, first-page covers and exact direction/layout/page progress restoration through the unchanged fixed Kookit comic reader. This increment follows CBT commit `1ca74253b80ce6de5a945be1e4a294126adf8455`; it neither rewrites that commit nor includes the coordinator's later integration commit. Cherry-pick only this increment onto the integrated tree.

The human explicitly approved the proposed native libarchive + liblzma route and necessary source vendoring in this isolated branch. No global installation occurred. Official fixed release tarballs were downloaded into a temporary directory, selected source was compiled using existing Xcode/SwiftPM, and no upstream executable, configure output, CLI, test binary, WASM or UnRAR component is redistributed. Configuration is a tracked original 64-bit Apple header; no host absolute paths or generated machine configuration enter source. All original PDFno code remains AGPL-3.0-or-later.

## Exact admitted slice

| Format | Accepted | Rejected / not claimed |
| --- | --- | --- |
| CB7 | Real 7z version 0.4 signature at offset zero; plaintext next header ending exactly at input EOF; one simple COPY, LZMA1 or LZMA2 coder per folder; at most one unpacked stream per folder; ordinary regular files/directories; admitted nonempty entries must expose a payload CRC and pass libarchive's CRC check | Encoded/encrypted headers, crypto coders, solid folders, multiple coders/transform chains, other codecs, anti-files, links/sparse/special entries, external wrappers/SFX, truncated/split/concatenated/trailing input, absent or unexposed payload CRC, oversized metadata/dictionaries. A valid archive whose folder-only CRC is not surfaced by libarchive is deliberately refused |
| CBR / RAR4-family | RAR signature at offset zero, exactly one 13-byte main header (flags 0 or new-numbering 0x10); ordinary STORE 0x30 file headers with unpack version29, exactly flag0x8000, ASCII names and Windows/Unix host; verified header CRC16 and payload CRC32; exact unflagged end header/EOF | Compressed RAR, older unpack versions, Unicode/large/extended RAR4 headers, explicit directory records, encryption/password/salt, solid, volumes/splits, extra/service/recovery/signature records, links/special entries, SFX, missing end/trailing input |
| CBR / RAR5 | RAR5 signature at offset zero; canonical bounded variable integers; ordinary STORE with compression-info zero/version50, Windows/Unix regular attributes, UTF-8 names, known exact sizes and CRC32, optional main-file mtime; exact main/file/end record sequence | Compressed/new compression versions, directories, extra/service/crypt/recovery records, nonzero main flags, unknown size, solid/splits/volumes, encryption, links/special entries, SFX or trailing input |
| CBZ / CBT | Existing accepted implementations unchanged | Existing finite ZIP and POSIX USTAR restrictions remain |

This is useful decoding of real container bytes, never extension renaming or fallback. Most compressed CBR files remain unavailable. Wider CBR compression needs original fixtures and separate functional/budget evidence before admission opens. Mobile shared parser/bridge compiles, but mobile comic reading remains unavailable. The fixed Kookit model/resource hashes and reading controls do not change.

## Resource and persistence contract

Existing bounds remain: input100 MiB, all entries2000, each expanded entry16 MiB, cumulative expanded payload512 MiB, static PNG/JPEG24M pixels/image and512M total pixels, dimension16000, thumbnail2400. New plaintext header limit1 MiB and **64 MiB per live native decoder allocation budget** apply. Decoder malloc/calloc/realloc/free/strdup calls are redirected through the original tracked allocator; allocation headers and simultaneous old/new realloc buffers count toward peak. Overflow or budget exhaustion refuses allocation before libc is called. The small bridge handle, input Data, Swift64 KiB buffer/one bounded payload, ImageIO allocations, stack and system library overhead are outside that decoder-heap measurement; it is not total process RSS. Existing pixel/output caps still bound those admitted content allocations.

Input is held alive only while synchronous native reads occur. A thread-local decoder budget isolates concurrent Swift calls. Data is read from memory with only the NONE outer filter and one selected archive reader; no disk extraction or external-program callback is compiled into the selected interface. All payloads, including ignored metadata, are consumed/checksummed; original names are checked before RAR normalization. Cancellation is checked between records/chunks/images; an individual libarchive call is synchronous and not preemptively interrupted. No hard wall-clock deadline or broad large-book performance claim is made.

Only original input plus page metadata persist in `NativeComicArchive`. Display reopens/scans the immutable archive, rather than retaining a512 MiB expanded-book cache; this bounds memory but makes navigation cost proportional to archive decoding. CB7 and CBR use additive `comics-cb7-v1.json` / `comics-cbr-v1.json` and `Originals/<sha256>.cb7/.cbr`. Existing CBZ/CBT manifest bytes are not rewritten by new-format import/progress. Existing originals are never overwritten, and normal repository corruption/future-schema/collision protections remain. Cover format/origin tags are additive; an old version can reject a cover manifest containing unknown tags, with the existing validated backup available for rollback.

## Source, license and reproduction

- libarchive3.8.9: `https://github.com/libarchive/libarchive/releases/download/v3.8.9/libarchive-3.8.9.tar.xz`, SHA-256 `888c934f9d95648ecb9163dc8e23ab80a476ecb81a8f1154704a227b5b676dde`.
- XZ5.8.4: `https://github.com/tukaani-project/xz/releases/download/v5.8.4/xz-5.8.4.tar.xz`, SHA-256 `4ce24038fd4221e0d13bc1a2de7a4db56e90b92b3bf75321f6c14be73f65de4b`.
-96 selected source/header files: each original path, original digest, redistributed digest and selected license are recorded in `Sources/PDFnoComicCodecs/SOURCE.json`. Libarchive files retain their controlling BSD2 notices plus archive_entry.c's embedded UC Regents BSD3 notice; PPMd is public domain; BLAKE2 selects CC0-1.0; selected liblzma and API/support headers declare0BSD. The aggregate upstream license texts, official complete CC0 text, and complete per-file initial and embedded license notices are bundled in `PDFnoServices/Resources/ComicCodecs/NOTICES.txt`. Upstream build scripts/CLI/helpers with other licenses are not selected.
- `scripts/vendor-comic-codecs.py --source-root <verified-release-directory>` reproduces source selection, narrow7z guard modifications, decoder symbol namespace, provenance and bundled notices. It does not download or install. The supplied directory contains the two hash-checked tarballs and their extracted trees. The original bridge/budget/config remain tracked source, not generated configuration. `scripts/check-comic-codecs.py` verifies selected source and original fixture consistency offline; this is not an independent security audit.
- Six original real-format hex fixtures and deterministic stdlib generator are recorded by `Fixtures/Comics/NATIVE-SOURCE.json`. Three actually compressed/stored7z variants, two actual RAR STORE variants, and one refused solid7z variant contain only original colors/PNG geometry/XML. No third-party book/test archive or private file is included.

## Validation and practical limits

Offline functional run: **46 tests /4 suites passed** (NativeComicTests9, CBTTests11, ComicTests12, CoverTests14). It uses both `PDFNO_COMIC_OFFLINE_ONLY=1` and `--skip ComicWebKitTests`; no window/WebKit suite ran in this increment. Coverage includes real formats, CRC/truncation/SFX/rename refusal, huge dictionary and tiny allocation budget, solid/unselected coders, RAR flags/methods, original unsafe paths/duplicates, entry/actual image bounds, mixed manifest preservation, restart progress and native cover origin. Existing Kookit Node adapter tests remain source-only.

Final tiny original3-page samples measured decoder allocation peaks: COPY7z26,640 bytes; LZMA7z191,285; LZMA2 7z191,485; RAR4 STORE24,529; RAR5 STORE90,959. Ten-sample debug import medians were 2.283250 ms (LZMA2) and2.686084 ms (RAR5 STORE), including static-image admission. These tiny synthetic samples are functional evidence, not large-book throughput/peak-RSS acceptance. The near2 GiB declared LZMA dictionary test returns the resource-limit error before allocating that dictionary.

Unsigned Mac and generic iOS Simulator application/UI targets are compiled with `build-for-testing`, never test execution. New CB7 COPY and CBR STORE app-flow test methods reuse the existing7-page import/order/layout/direction/page-jump/restart workflow and are compile-only. UI/App launch, native picker acceptance, actual rendering/accessibility, devices, release signing and exact-SHA CI remain NOT-RUN. Both final application binaries contain arm64 and x86_64 slices. Exact commands and local logs are below. Upstream C code emits narrowing-conversion warnings; existing UI unused-local/AppIntents warnings remain. None are hidden by warning suppression.

Previously blocked independent full-project security remains **UNVERIFIED**; this work does not retry it. The earlier CBT hidden-window test-filter deviation remains documented in the prior report, and was not repeated. No user App, desktop window, simulator, real API, private library or credential was accessed by this increment. No push/merge/main or other-worktree mutation occurred.

Shared integration conflicts: `Package.swift` (new C dependency plus Services notice resources), comic/cover enums and exhaustive switches, ComicArchive/ComicRepository/CoverRepository, LibraryWorkspace picker/status, NativeUITests helper/workflow, README/source notices/spec/task/validation docs. New C target, NativeComicArchive, fixtures/tests/scripts and this report are additive. No Bookno/ebook/web code, Kookit generated resources, Xcode project generator or requirement ledger definition is changed.


## Final local validation commands and evidence

Environment: Xcode 27.0 (27A266a), Apple Swift 6.4 (`swiftlang-6.4.0.34.1`, `clang-2100.3.34.1`), macOS/iOS Simulator SDK 27.0, arm64 host; fixture/source scripts use Python 3.9.6. Native source configuration targets 64-bit Apple; package minimums remain macOS14 and iOS17.

```sh
PDFNO_COMIC_OFFLINE_ONLY=1 swift test --package-path apple/Packages/PDFnoKit --scratch-path /tmp/pdfno-comic-codec-unit --filter 'NativeComicTests|CBTTests|ComicTests|CoverTests' --skip ComicWebKitTests
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/pdfno-comic-codec-mac CODE_SIGNING_ALLOWED=NO ONLY_ACTIVE_ARCH=NO ARCHS='arm64 x86_64' build-for-testing
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/pdfno-comic-codec-mobile CODE_SIGNING_ALLOWED=NO build-for-testing
python3 scripts/vendor-comic-codecs.py --source-root /tmp/pdfno-comic-codec-sources
python3 scripts/generate-native-comic-fixtures.py
python3 scripts/check-comic-codecs.py
python3 scripts/check-native-source.py
python3 scripts/test-requirement-ledger.py
node --test engine-build/comics-reader.test.mjs
node engine-build/build-comics.mjs
git diff HEAD^ HEAD --check -- . ':(exclude,glob)apple/Packages/PDFnoKit/Sources/PDFnoComicCodecs/libarchive/**' ':(exclude,glob)apple/Packages/PDFnoKit/Sources/PDFnoComicCodecs/xz/**' ':(exclude,glob)apple/Packages/PDFnoKit/Sources/PDFnoComicCodecs/Licenses/**' ':(exclude)apple/Packages/PDFnoKit/Sources/PDFnoServices/Resources/ComicCodecs/NOTICES.txt'
```

- Functional log `/tmp/pdfno-comic-codec-unit.log`: final **46 tests /4 suites passed in0.549 s**; the 10-sample medians and each tracked allocation peak above come from this run.
- Mac `/tmp/pdfno-comic-codec-mac.log` and Simulator `/tmp/pdfno-comic-codec-mobile.log`: final **TEST BUILD SUCCEEDED**; `lipo -archs` reports `x86_64 arm64` for each application binary. UI test targets were compiled by build-for-testing; neither was executed.
- Reproduction `/tmp/pdfno-comic-codec-reproduction.log`: verified fixed tarballs and every extracted selected byte, reproduced source/namespace/notices and original fixtures, then compared before/after SHA-256 maps across selected source/config/license/resources/fixtures; all 117 files were byte-identical.
- Offline guard:96 selected codec source/header hashes/licenses and6 original real-format fixtures; native source guard447 files; requirement ledger8/8 tests; Node comic adapter4/4 tests. Source-only Kookit regeneration leaves the fixed comic resource tree byte-identical. Xcode project and requirement ledger definition have no increment diff.
- Worktree writes require the scoped sandbox escalation because this approved independent worktree sits outside the initial writable root. One ordinary Kookit rebuild attempt returned EPERM, was disclosed immediately and succeeded on the one approved identical retry. No auto-review rejection remains; no denied security task was retried.

Whitespace validation covers authored code, tests, scripts and docs. Full staged `git diff --check` also flags original upstream whitespace and an original license/complete-notice final blank line; these bytes remain intact for release provenance and complete license reproduction. The full check delayed the first commit attempt. The final explicit pathspec check above passes for authored files; upstream-only whitespace diagnostics remain documented. This was a local whitespace-check failure, not a platform approval rejection.
