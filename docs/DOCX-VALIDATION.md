# DOCX / Kookit-Mammoth validation — 2026-10-03

Current scope: actual Kookit DOCX Mammoth conversion chain, fixed Mammoth 1.13.0, in independent `feature/docx` based on `aaba190a878df9de5674491d20f1b36fa4733607`. Native semantic candidate commits `fafd0a6` / `c9630ed` remain for comparison; they are not the product fallback. Toolchain: Xcode 27.0 (27A266a), Apple Swift 6.4, Node 20.20.2, arm64 Mac. Mac/iOS deployment targets remain 14.0/17.0.

## Independent branch evidence (historical snapshot)

- **6 JavaScript tests passed**: four actual Mammoth/bundled-browser/sanitiser tests and two existing EPUB loader tests. The real browser-target bundle runs in an isolated Node VM without fetch/filesystem and with string code generation disabled; it produces the same canonical output as the actual Node Mammoth chain. Ordinary external hyperlink labels survive, all href/src/event/style targets disappear, and a second conversion request is rejected. Standard headings, ordered list, table cells, direct emphasis, Unicode, malformed converted markup and output budgets are checked.
- **55 Swift tests in 9 suites passed** with `--skip EPUBWebKitTests`. This includes native ZIP/XML preflight/security/source/persistence tests, an actual pinned-engine extraction DTO, normal external hyperlink preflight and two isolated native bridge/cancellation units. The existing window-creating EPUB suite and desktop UI suites were excluded.
- **Isolated native bridge/cancellation units passed** separately: native bootstrap loads the real bundled engine, converts the original hyperlink fixture, verifies actual DOM versus native canonical text, recognises headings, captures `window`, returns exactly to it, projects a note and refuses stale navigation after close. A second unit closes an in-flight opening generation during preflight/readiness and verifies that it cannot reactivate the reader. The test process has activation policy prohibited; WKWebView is unattached, with **zero visible/key/main windows**. WebKit creates internal hidden auxiliary objects, so this is not a claim that AppKit allocates no internal NSWindow. No explicit window, user's app, desktop interaction or screen capture is used.
- **Unsigned independent Mac and generic iOS Simulator builds succeeded.** No Simulator or PDFno app is launched. Only the existing no-AppIntents metadata-extraction warning appeared. Cross-platform compilation does not enable mobile DOCX reading UI.
- Authored sources pass staged whitespace checks. The assembled DOCX notices preserve nine trailing spaces from existing upstream BSD license texts; the notices are excluded only from this cosmetic whitespace check, not source/license verification.
- Rebuilding EPUB after the DOCX dependency/build changes yields byte-identical `Resources/EPUB/engine.js`, `Notices.txt` and `engine-build/BUNDLE-INPUTS.json`.
- Four installed Mammoth files (`LICENSE`, `lib/index.js`, browser unzip and browser external-file adapter) match bytes from official Git commit `791a189230977143cde64dbf9f1d24dce96ac8a1`. Their SHA-256 values are checked at every DOCX build. The npm lock/integrity, full actual license texts, 301 source inputs and 13 bundled package records are retained. GitHead metadata alone is not treated as independent source proof.

```sh
npm ci --prefix engine-build --ignore-scripts --no-audit --no-fund --registry=https://registry.npmjs.org --userconfig=/dev/null
python3 scripts/generate-docx-fixture.py
node engine-build/generate-docx-extraction.mjs
node engine-build/build-docx.mjs
node --test engine-build/docx.test.mjs engine-build/loader.test.mjs
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/DOCX --filter DOCXBridgeUnitTests
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/DOCX --skip EPUBWebKitTests
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/DOCX-Mac CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DOCX-Mobile CODE_SIGNING_ALLOWED=NO build
```

## Security/source corpus

The 21 original archives cover ordinary/stored/descriptor ZIPs, standard Mammoth headings/numbering, a real ordinary hyperlink relationship to `example.invalid`, malformed external relationship rejection, file entities/DTD/expansion, alternative HTML chunks, embedded objects, macro paths, XML depth/style cycles/UTF-16 encoding, traversal, entry/text/paragraph budgets, CRC/name mismatch and encryption. Native in-memory mutations additionally check symlinks, local/central size lies, corrupt compressed data, truncation and oversized input. These gates run before the real engine receives bytes.

Source tests check distinct repeated quotes, exact Unicode/UTF-16 across paragraphs, surrogate refusal, context/version/edition checks and literal script-looking text. Temporary repositories bind the actual Mammoth DTO, preserve original bytes, deduplicate, atomically save/back up `docx-mammoth-v1.json`, reopen progress/notes and refuse unbound/forged/tampered/corrupt/future stores and legacy DOC. The candidate `docx-v1.json`, PDF and EPUB records are not migrated or rewritten. Every payload and the extraction snapshot is original/generated; there are no user books, images, fonts, active remote document requests or authenticated service calls.

The independent branch audit originally reported the old Rangy high prototype pollution. GitHub's GHSA-65rp-mhqf-8gj3 lists patched versions None; that metadata is not the source of patch proof. The integrated EPUB profile now retains the separately verified official1.3.2 dangerous-key repair in RANGY-SECURITY-2026-10-03. Rangy remains absent from the DOCX bundle. See the ADR for the source/license boundary rather than interpreting npm's upgrade suggestion as patch evidence.

## Limits

The offscreen bridge verifies engine/native DOM/source behavior, not visible page geometry, keyboard/accessibility, full Word corpus compatibility or Word layout fidelity. Desktop UI/user-app acceptance, note editing/deletion, mobile DOCX UI and conversion/export remain outside this slice. No main-tree edit, push/merge, shared Library write, user document upload or real-key operation is performed.

Current raw local logs: `/tmp/pdfno-docx-mammoth-js.log`, `/tmp/pdfno-docx-mammoth-swift.log`, `/tmp/pdfno-docx-mammoth-bridge.log`, `/tmp/pdfno-docx-mammoth-mac.log`, `/tmp/pdfno-docx-mammoth-mobile.log`. Build outputs stay ignored under the worktree's `.build/`. Commands and assertions above are the portable evidence; temporary logs are not part of public source.

Historical candidate evidence remains in Git history: 10 DOCX tests / 52 non-window Swift tests and independent Mac/iOS builds at the candidate stage. Those counts and the candidate's smaller compatibility profile are not used to claim acceptance of the current engine route.

## Combined coordinator integration

All three approved commits were applied in order after the exact e30fb2f comic/conversion gate passed. The finite exporter retains its own renamed DOCXConversionArchive; actual Word content continues from the pinned Mammoth browser engine, without native candidate fallback or execution of the full upstream DocxRender class. Mac source/selection/notes/progress/import routing is preserved; Word deactivation and both AI cancellation hooks were reconciled with EPUB/CBZ/PDF. Unknown binary files remain rejected by the main source guard;21 original Word archives and the UI copy have precise hashes in scripts/ORIGINAL-FIXTURES.json, and CI regenerates/checks them.

Combined local97 Swift/14 suites (including both real EPUB and comic WebKit suites),11 Node and both builds passed. Two complete actual app UI methods were added for import/semantic reading/real selection/manual note/source return/restart and malformed-file recovery/PDF/EPUB/CBZ transitions. Final complete13-method isolated CI results belong to the exact delivered SHA and are reported by VALIDATION/delivery; compilation alone does not accept these new methods. No owner-app UI/key was accessed. Whole-project independent audit remains pending after freeze.
