# DOCX integration handoff

Independent checkout: `/Users/artsmartluo/pdfno/worktrees/docx`, branch `feature/docx`, base `aaba190a878df9de5674491d20f1b36fa4733607`.

History stays additive: `fafd0a6ce474ceefee1a36b2dd2b8658a43bd3c6` (bounded native candidate), then `c9630ed94b5ae4eb7cbe85842e8d33957c7f46f0` (shared import/sidebar entry candidate), then the current audited Kookit/Mammoth implementation. The candidate semantics remain for comparison/testing only. Integrate the whole ordered branch state; applying the newest commit alone to the original base misses its new Swift modules and C ZIP target.

## Shared merge points

- `Package.swift`: retain the independent `PDFnoDOCXZIP` system-zlib target, Services dependency, Readers → Services preflight dependency, DOCX engine resources and original sample/fixture resources when reconciling other format targets.
- `LibraryModel.swift` / `LibraryWorkspace.swift`: retain DOCX importer/UTI/sample/sidebar/detail routing, active-format deactivation, the same local-versus-test repository root, explicit legacy DOC refusal and DOCX guards on existing PDF/EPUB AI snapshots. Reconcile with concurrent comics/conversion changes; do not replace those changes with these base-derived shared files.
- Keep DOCX-specific Domain/Services/Readers/UI files independent. Product content comes from actual pinned Mammoth; never route the old native semantic parser back into reading/persistence. `DOCXReaderSession.open` independently enforces preflight and identity checks.
- New `docx-mammoth-v1.json` is separate from the candidate `docx-v1.json`; no automatic offset migration. The retained original hash plus edition/extraction/UTF-16 anchors define source identity. Render/bind current canonical content before saving progress or notes.
- Carry exact npm lock/source checks, build source, notices/licenses and generated DOCX engine together. EPUB resource bytes remain unchanged. Root notices need additive reconciliation with concurrent dependency audits. The existing Rangy advisory is a separate coordinator item, with no verified patched version claimed here.

See [implemented architecture/security/license boundaries](ADR-DOCX-KOOKIT-MAMMOTH.md) and [55 Swift / 6 JS tests plus independent builds](DOCX-VALIDATION.md). No main-tree edit, merge/push, user-app launch or shared Library write was performed. Visible layout/keyboard/accessibility, full Word corpus, mobile DOCX UI, note editing/deletion and conversion/export remain outside this validated slice.

## Complete changed-file inventory relative to the base

- `SOURCE-NOTICES.md`
- `THIRD_PARTY_NOTICES.md`
- `apple/Packages/PDFnoKit/Package.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoDOCXZIP/ZIP.c`
- `apple/Packages/PDFnoKit/Sources/PDFnoDOCXZIP/include/PDFnoDOCXZIP.h`
- `apple/Packages/PDFnoKit/Sources/PDFnoDomain/DOCXModels.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoReaders/DOCXHTML.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoReaders/DOCXReaderSession.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/DOCX/Notices.txt`
- `apple/Packages/PDFnoKit/Sources/PDFnoReaders/Resources/DOCX/engine.js`
- `apple/Packages/PDFnoKit/Sources/PDFnoServices/DOCXArchive.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoServices/DOCXParser.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoServices/DOCXRepository.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoUI/DOCXLibraryModel.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoUI/DOCXWorkspace.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoUI/LibraryModel.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoUI/LibraryWorkspace.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoUI/Resources/study-sample.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/DOCXBridgeUnitTests.swift`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/DOCXTests.swift`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/altchunk.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/bad-crc.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/cycle.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/deep.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/descriptor-sample.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/embedded.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/encrypted.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/entities.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/expansion.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/external.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/hyperlink-sample.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/local-mismatch.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/macro.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/mammoth-extraction.json`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/mammoth-sample.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/oversize.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/paragraphbudget.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/stored-sample.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/study-sample.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/textbudget.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/traversal.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/DOCX/utf16.docx`
- `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/README.md`
- `docs/ADR-DOCX-KOOKIT-MAMMOTH.md`
- `docs/ADR-DOCX-SEMANTIC.md`
- `docs/DOCX-INTEGRATION.md`
- `docs/DOCX-VALIDATION.md`
- `engine-build/DOCX-BUNDLE-INPUTS.json`
- `engine-build/DOCX-BUNDLED-DEPENDENCIES.json`
- `engine-build/DOCX-DEPENDENCIES.json`
- `engine-build/MAMMOTH-SOURCE-CHECKS.json`
- `engine-build/MAMMOTH-SOURCE.json`
- `engine-build/README.md`
- `engine-build/build-docx.mjs`
- `engine-build/build.mjs`
- `engine-build/docx-adapter.js`
- `engine-build/docx-reader.js`
- `engine-build/docx.test.mjs`
- `engine-build/generate-docx-extraction.mjs`
- `engine-build/licenses/argparse-LICENSE`
- `engine-build/licenses/base64-js-LICENSE`
- `engine-build/licenses/dingbat-to-unicode-LICENSE`
- `engine-build/licenses/duck-LICENSE`
- `engine-build/licenses/lop-LICENSE`
- `engine-build/licenses/mammoth-LICENSE`
- `engine-build/licenses/option-LICENSE`
- `engine-build/licenses/sprintf-js-LICENSE`
- `engine-build/licenses/xmlbuilder-LICENSE`
- `engine-build/licenses/xmldom-xmldom-LICENSE`
- `engine-build/package-lock.json`
- `engine-build/package.json`
- `engine-build/vendor/kookit/src/renders/DocxRender.ts`
- `engine-build/vendor/manifest.json`
- `scripts/generate-docx-fixture.py`
