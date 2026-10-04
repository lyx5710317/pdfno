# DOCX reading-PDF export candidate

2026-10-04. Independent local candidate on `feature/docx-pdf-export`, based on accepted main `bb6928e1319f85a72c967a6c3f054bb544e9c306`. This finite Mac slice implements **DOCX → 阅读版PDF** from the existing checked Kookit-reference / actual Mammoth 1.13.0 semantic reading content. It does not complete the original seven fidelity conversion directions. No push, merge, release, Library integration, Bookno/iCloud operation or independent security audit is part of this change.

## Implementation and provenance

`DOCXReadingPDFService` is an independent public Mac service in Readers. It registers only `DOCXReadingPDFConversionAdapter` with the Services transaction. The adapter uses an independent, unattached `DOCXReaderSession`, with empty notes and a synthetic book identity derived from the actual input SHA-256. The existing ZIP/XML preflight, pinned Mammoth engine, allowlisted semantic DTO, canonical DOM check, bounded deadlines and network/resource refusal run unchanged. The old native semantic candidate and the separate TXT/HTML body extractor are not PDF conversion fallbacks. Opening and closing this export session does not alter any live reader or its source anchors.

`DOCXReadingPDFRenderer` consumes the validated immutable DTO in the utility worker. Apple Core Text creates attributed paragraphs and frames; Apple Core Graphics writes a PDF into memory. PDFKit is used only on the main actor in original-fixture tests for opening/extraction/rendering. The new production renderer has no PDFKit objects, window, printer dialog, subprocess, network endpoint, source path or repository. All added Swift and synthetic test XML are original, AGPL-3.0-or-later. Existing Mammoth source/version/licenses and bundled resources are unchanged. No LibreOffice, cloud service, new JS engine, external Swift dependency or vendored font was added.

The installed SDK supplies [PDF CGContext creation](https://developer.apple.com/documentation/coregraphics/cgcontext/init(consumer:mediabox:_:)), [Core Text frames](https://developer.apple.com/documentation/coretext/ctframesettercreateframe(_:_:_:_:)), and the [visible string range](https://developer.apple.com/documentation/coretext/ctframegetvisiblestringrange(_:)). Header availability is older than the existing macOS14 minimum. API availability does not establish oldest-OS runtime, font/extractor compatibility or Word fidelity.

## Layout and quality contract

- Fixed A4: 595.28 × 841.89 pt; 48 pt left/right/top margin; body ends at 60 pt from the bottom; 12 pt body, bounded heading sizes, paragraph spacing, header “DOCX 阅读版PDF”, centered sequential page numbers.
- Preserve all text emitted by the existing semantic reader, basic h1–h6 headings, bold/italic runs and list hierarchy. Render list items with a uniform bullet. Tables become ordered paragraphs with explicit table/row/cell labels; merged cells, grid layout, source numbering and Word pagination are not reconstructed. Long paragraphs flow across pages.
- Helvetica with installed PingFang SC / Hiragino Sans cascade; Core Text selects actual fallback fonts. Inspect drawn glyphs and line bounds before committing a page. Refuse zero glyphs and `LastResort` placeholder fonts, inability to advance, out-of-frame text, >300 pages or >16 MiB output. These checks are finite layout guards, not a typography/accessibility certification.
- Images retain only the reading engine's inert text placeholder. Word fonts, headers/footers, annotations/revisions, fields, footnotes, formulas, ruby and complex objects may be omitted or changed by the existing semantic engine; no fidelity or completeness claim is made for those objects. Engine warnings and unconditional loss warnings are exposed before export and in the result UI.
- `DOCXReadingPDFReport` contains input SHA-256, semantic engine/extraction/renderer IDs, actual page/block/text counts, fonts, fixed settings and actual semantic warnings. The PDF title explicitly says 阅读版PDF, and Subject metadata retains the source SHA-256 and extraction version. Original bytes and all existing stores/anchors remain unchanged; no new edition is imported and no DOCX anchor is assigned to a PDF page.

Quartz emits per-glyph `/ActualText` to preserve authored Unicode when its CJK font cmap chooses a compatibility radical. Actual evidence contains exact `日`, `乙`, `一`, `二`, `行`, `文` replacement spans. PDFKit extracts the expected Chinese/Japanese, combining characters and emoji from the original fixture. The installed `pypdf` normal extractor ignores those spans and returns some compatibility radicals (e.g. `⽇` for `日`); the file remains extractable, but third-party extraction is **not** scalar-exact acceptance or a safe source-anchor migration. This limitation is visible in the export component. No PDF/UA or full tagged accessibility acceptance is claimed.

## Output and cancellation

`DocumentConversionService` now also accepts `AsyncDocumentConversionAdapter`; the original synchronous adapter interface and default two TXT/HTML capabilities remain intact. It still owns source/output security scopes, bounded read-only source fd, the same pinned destination directory and the detached utility task with caller cancellation propagation. Known domain errors preserve their safe localized reason.

`PinnedConversionDestination` and every output filesystem operation are unchanged. The directory is opened once with `O_DIRECTORY | O_NOFOLLOW`; `fstatat` checks the selected leaf; `openat` creates a private mode-0600 staging leaf; `linkat` installs a complete new file without replacement; `unlinkat` cleans staging relative to that fd. No path-based write, rename fallback or TOCTOU downgrade was introduced. Identity checks still reject a replaced pathname. The directory fd and scopes stay alive while the asynchronous semantic engine runs.

Cancellation checks cover reading, validation/semantic boundaries, attributed text, page/glyph inspection, page boundaries and writing. The export's cancellation handler closes its private WebKit session and rejects pending work. Before atomic installation, failure/cancellation leaves no final or staging output. After installation, the complete output is reported even if cancellation arrives. Unsupported filesystems fail safely; crash cleanup, directory-fsync durability, file-provider coordination, persistent jobs and automatic retry remain outside this slice.

## Integration without shared workspace changes

No `LibraryModel`, `LibraryWorkspace`, repository, project generator, existing conversion window, fixture resource, engine bundle or package manifest was edited. Public entry points:

```swift
let result = try await DOCXReadingPDFService().convert(
    source: originalDOCXURL,
    destination: newPDFURL,
    progress: { phase in /* stage-only progress; not an ETA */ }
)
// Show result.readingPDFReport, including lossWarnings and semanticWarnings.
```

A host can present the independent `DOCXReadingPDFExportWorkspace(source: optionalOriginalURL)` in its own sheet/window. It includes DOCX file selection, PDF-only NSSavePanel, clear loss warnings, stage progress, cancellation, quality report and explicit manual retry. It never starts conversion automatically. The coordinator owns the later toolbar/menu/sheet route and isolated actual UI tests. The default existing `ConversionWorkspace` still exposes TXT/HTML only.

Shared conflict points are limited to additive `ConversionContracts.swift` (readingPDF format, paginating phase, optional report) and `DocumentConversionService.swift` (async adapter registration/dispatch). Retain current synchronous adapters, async additions, error propagation and the complete unchanged pinned-fd class when integrating. New files are otherwise independent. Other branches need no changes to reader/store schemas or generated JS. Rollback can remove this component/adapter and additive contract fields; no data migration or original-file restoration is needed.

## Actual validation

Tests use an original, in-memory DOCX with headings, styled runs, a list, two table cells and 85 multilingual paragraphs, plus the existing provenance-checked original Mammoth fixture. They use isolated temporary output directories and unattached WKWebView instances in the test process with activation prohibited. No application process is launched/replaced, real library/key is read, real AI request is sent, or signing/entitlement setting is changed.

| Check | Actual result |
| --- | --- |
| Targeted Swift tests | 26 tests / 2 suites passed: 18 existing conversion tests plus 8 new PDF test methods, including five parameterized cancellation phases. The final run includes complete original semantic-block/emoji extraction, caller cancellation propagation, explicit line breaks, tabs and long-token wrapping; 0 failures, 2.744 seconds. |
| Original multipage PDF | 11 pages, 68,041 bytes; actual fonts Helvetica, Helvetica-Bold, Helvetica-Oblique, PingFangSC-Regular. PDFKit opens the file and extracts all row start/end markers, Chinese/Japanese, styles/list/table text, correct page numbers and in-margin character geometry. Original SHA-256 `5fd1721c88d98cf952a67be6e0c93135d13cf64b6742876c40d251b3308e027c` is retained in report and PDF metadata. |
| Render review | All 11 pages rendered with PDFKit to PNG and reviewed in a contact sheet; first/last pages also inspected at full thumbnail resolution. No clipping, overlap, blank/missing page or missing-glyph boxes observed. Poppler is unavailable; no dependency was installed. |
| Output/error boundaries | All five cancellation phases, cancellation after a real rendered page, cancellation after commit, existing/late destination refusal, original preservation, no staging residue, failure→manual model retry, invalid DTO, unsupported Unicode `LastResort` and 300-page budget all passed. |
| Independent Python extraction | Existing pypdf opened all 11 pages. Per-glyph ActualText inspection confirms exact source variants; ordinary extraction has the disclosed compatibility-radical limitation. |
| Source/provenance guard | `check-native-source.py` and `git diff --check` passed; original fixtures/dependency resources untouched. |
| Native Mac build | Unsigned Debug `PDFnoMac`, jobs=2: BUILD SUCCEEDED on the final production implementation after metadata/UI changes. Existing AppIntents metadata-extraction warning only; no new converter compilation warnings. |
| Native mobile compatibility | Unsigned generic iPhone/iPad Simulator `PDFnoMobile`, jobs=2: BUILD SUCCEEDED after the Mac build. Existing libarchive narrowing and AppIntents metadata warnings remain; no new converter warnings. This is shared-code compatibility only; reading-PDF service/component are Mac-only. |
| Actual desktop UI / independent security | NOT-RUN / UNVERIFIED. UI is compiled but no new host route or actual UI acceptance exists. The separately blocked security task was not retried or bypassed. |

The first missing-glyph expectation exposed `LastResort`'s nonzero placeholders; the renderer was corrected and the final test passed. An experimental explicit structure-tag route was removed after platform-generated structure references and reader compatibility proved unsuitable; final output retains Quartz's own nonstructural ActualText and does not claim tagged-PDF conformance.

Reproduction, one heavy build at a time:

```sh
PDFNO_READING_PDF_EVIDENCE=1 swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/ReadingPDF --jobs 2 --filter 'DOCXReadingPDFTests|ConversionTests'
python3 scripts/check-native-source.py
git diff --check
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/ReadingPDFMac -jobs 2 CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/ReadingPDFMobile -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

Optional evidence is generated only under the OS temporary `PDFno-ReadingPDF-Evidence` directory; it is not tracked, published or saved to a shared Library. Build/test logs stay outside source. Xcode27.0 (`27A266a`), Swift6.4, macOS27.0 are the actual local toolchain/runtime; macOS14/Intel/real devices, signed sandbox/file-provider grants, performance/memory/crash recovery, arbitrary Word corpus, VoiceOver, visible export/save-panel flow and mobile export remain unverified. Broader conversion/format reading goals, actual Bookno/iCloud sync and the independent security gate remain unchanged.
