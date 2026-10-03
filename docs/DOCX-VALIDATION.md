# DOCX slice validation — 2026-10-03

Scope: **pending-review native semantic candidate; no formal Kookit DOCX engine selected or integrated**. Independent `feature/docx` worktree based on `aaba190a878df9de5674491d20f1b36fa4733607`. No application was launched. Toolchain: Xcode 27.0 (27A266a), Apple Swift 6.4, arm64 Mac. Mac deployment target remains 14.0; iOS remains 17.0.

## Evidence

- `swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/DOCX --filter DOCXTests`: **10 tests passed**, including 16 cases in the parameterised hostile-document test. Ordinary deflated, stored and real descriptor ZIP fixtures produce the same semantic document.
- `swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/DOCX --skip EPUBWebKitTests`: **52 tests in 8 suites passed**. The excluded pre-existing suite creates NSWindows and was intentionally not run. Other tests use synthetic/intercepted HTTP and temporary stores.
- Unsigned independent Mac build below: **BUILD SUCCEEDED**. Only the existing no-AppIntents metadata-extraction warning appeared; no DOCX compiler warning.
- Unsigned generic iOS Simulator build below: **BUILD SUCCEEDED**. A build does not start a Simulator or make DOCX mobile UI available.

```sh
python3 scripts/generate-docx-fixture.py
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/DOCX --filter DOCXTests
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/DOCX --skip EPUBWebKitTests
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/DOCX-Mac CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/DOCX-Mobile CODE_SIGNING_ALLOWED=NO build
```

## Coverage

The 19 original fixtures cover ordinary/stored/descriptor DOCX; external relationships to `example.invalid`; file entities/DTD and entity expansion; alternative HTML chunks; embedded objects; macro paths; excessive XML depth; cyclic heading inheritance; UTF-16 XML; ZIP traversal; per-entry size, text and paragraph limits; CRC mismatch; central/local name disagreement; encryption. Additional in-memory mutations cover symlink attributes, consistent central/local size lies, corrupt compressed bytes, undersized input and excessive archive size.

Positive assertions cover inherited headings, direct emphasis, table-cell identities, list levels, exact Unicode and repeated quotes, cross-paragraph selection, surrogate-pair refusal, context/extraction-version checks, escaped source markup, default-deny CSP and JavaScriptCore compilation/initialisation of the trusted bridge and exact canonical-text equality without a window (minimal text/listener stubs, no DOM selection emulation). Temporary-repository tests cover duplicate import, original-byte preservation, atomic manifests/backups, progress/note reopen, cross-edition/forged quotes, tampered originals, corrupted/future/unknown schema refusal and explicit DOC rejection. The PDF and EPUB manifests are not created or modified by DOCX repository tests.

All samples and malicious payloads are generated in `scripts/generate-docx-fixture.py` from PDFno-authored text and inert bytes. There are no user documents, downloaded books/images/fonts, active network tests or newly installed dependencies.

## Limits of this evidence

These results establish parser, source-anchor, persistence, compile and escaped-resource contracts. They do not establish Word layout fidelity, full OOXML compatibility, WebKit DOM/selection/scroll/highlight behavior, mobile reading or accessibility. Desktop app/UI acceptance is deferred per the user's instruction; no screenshots, launched app, simulated user actions or real-library writes were performed.

Raw local logs are `/tmp/pdfno-docx-unit.log`, `/tmp/pdfno-docx-units.log`, `/tmp/pdfno-docx-mac.log`, `/tmp/pdfno-docx-mobile.log`; build outputs stay ignored under this worktree's `.build/`. The reproducible commands and claims above are the portable evidence; temporary logs are not included in public source.
