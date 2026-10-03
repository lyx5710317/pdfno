# ADR 0009 — Local DOCX body-text conversion

Date: 2026-10-03. Status: implemented narrow Mac slice; broader conversion goals remain open.

PDFno now converts ordinary DOCX body text to a new UTF-8 TXT or standalone, escaped HTML file. The Mac toolbar opens a native conversion window with input selection, explicit output format/location, loss warnings, background stage progress, cancellation and manual retry. This direction needs neither a document-layout engine nor a cloud service. It does not establish Word reading, editable Word reconstruction, OCR, PDF fidelity or whole-EPUB conversion.

## Conversion matrix

| Direction | Local feasibility and engine boundary | Current result |
| --- | --- | --- |
| DOCX → UTF-8 TXT | Bounded ZIP + WordprocessingML body text, using system zlib and Foundation XMLParser | Implemented and unit-tested; Mac entry exposed |
| DOCX → simplified HTML | Same text extraction; escaped `<pre>` text, UTF-8 and restrictive CSP; no active resources | Implemented and unit-tested; Mac entry exposed |
| DOCX → PDF | Needs font, layout, pagination and object handling; body extraction cannot establish this | Not implemented |
| EPUB → PDF | Requires a controlled full-publication print pipeline and renderer/vertical/ruby/resource validation | Not implemented; existing Kookit reading alone is insufficient |
| Text PDF → DOCX | Needs reading-order, paragraph/table/layout reconstruction; PDFKit selection is not an editable-document engine | Not implemented, no fidelity claim |
| Scanned PDF → DOCX | Needs OCR accuracy/regions plus editable layout reconstruction | Not implemented; no OCR call |
| PDF → EPUB | Needs semantic/reading-order recovery and a validated publication writer | Not implemented |
| DOCX → EPUB | Needs heading/TOC/notes/media mapping and a publication writer/readback matrix | Not implemented |
| EPUB → DOCX | Needs chapter/CSS/ruby/layout conversion and an OOXML writer | Not implemented |
| Legacy DOC, macro/encrypted Word, batch or arbitrary directions | Requires additional engines, security profiles, licenses and samples | Not supported by this adapter |

These are direction-specific conclusions, not promises that every DOCX is convertible. The first adapter accepts the conventional `word/document.xml` main part in a standard non-macro OPC package with UTF-8 XML. Strict and transitional WordprocessingML namespaces work. Stored/deflated ZIP and ordinary data descriptors work; encrypted, ZIP64, multi-disk, symbolic-link entries, unsafe/ambiguous names and unsupported methods are refused. A nonstandard main-part location, `mc:AlternateContent`, `w:altChunk` or `w:subDoc` is refused rather than guessed.

## Sources and license audit

| Selected component | Source/version evidence | Licensing and distribution boundary |
| --- | --- | --- |
| PDFno adapter, service, UI and generated fixtures | Original Swift source in this change; adapter ID `docx-body-text-1` | AGPL-3.0-or-later; no copied converter source or third-party sample |
| System zlib | Apple SDK `zlib.h` declares 1.2.12; local `zlibVersion()` returned 1.2.12. [Upstream license](https://zlib.net/zlib_license.html) checked 2026-10-03 | zlib permissive terms; use installed system library through `import zlib`. No implementation/header/binary is vendored; upstream origin remains acknowledged |
| Foundation XMLParser | [Apple XMLParser](https://developer.apple.com/documentation/foundation/xmlparser) and [entity resolving policy](https://developer.apple.com/documentation/foundation/xmlparser/externalentityresolvingpolicy-swift.property) | Apple installed platform component; no SDK implementation redistributed |
| SwiftUI/AppKit/UniformTypeIdentifiers and POSIX file APIs | [Apple NSSavePanel](https://developer.apple.com/documentation/appkit/nssavepanel), installed SDK/toolchain | Existing system-framework boundary and platform terms apply |
| OOXML format reference | [ECMA-376](https://ecma-international.org/publications-and-standards/standards/ecma-376/) defines document vocabulary and OPC packaging | Reference only; no standard PDF/schema or sample copied into the application |

No external Swift package, npm dependency, executable, model, font or network endpoint was added. The existing pinned Kookit EPUB resource and its notices remain unchanged; it is not used for this conversion path. Reader integration for other formats can reuse the explicit direction contract without exposing converters through the WebKit bridge.

Mammoth remains an uninstalled comparison candidate: its [root license](https://github.com/mwilliamson/mammoth.js/blob/master/LICENSE) declares BSD-2-Clause, but no version/transitive dependency or asset audit was performed for bundling it. [LibreOffice licensing](https://www.libreoffice.org/licenses/) describes MPL-2.0 plus version-specific third-party notices and dual-licensed contributions. No LibreOffice installation, binary or cloud conversion service was selected. Choosing such a dependency requires a concrete source/version/platform/size/license and integration proposal before installation; this slice does not depend on that choice.

## Small extension boundary

`ConversionRequest`, `ConversionCapability`, `ConversionResult`, typed warnings/errors and stage values live in Domain. `DocumentConversionAdapter` receives bounded immutable bytes and emits a converted document. `DocumentConversionService` selects only an advertised direction and owns file permissions, bounded I/O, cancellation propagation and output installation. Default capabilities are exactly DOCX→TXT and DOCX→HTML. A separate Mac model/view manages the system input/save panels and ignores stale progress; no library repository or reading/AI model was refactored.

The service runs in a detached utility worker, with caller cancellation forwarded by a cancellation handler. Checks occur during input chunks, ZIP validation, inflate output chunks, XML callbacks, rendering boundaries and output chunks. Stage progress is explicitly labelled as stage progress, not a measured percentage of bytes or an estimated completion time.

## Content and safety profile

Body text preserves Unicode (including combining marks), run text, paragraph breaks, tabs/line breaks and table cell order. Table cells are separated by tabs, rows by newlines, and multiple paragraphs within a cell by newlines. Inserted revision text is included; deleted text, field instructions, ruby readings and drawing/textbox text are omitted. Cached visible field text may be included but is never recalculated. Numbering/font/style/page layout are not interpreted. Images, media, headers, footers, footnotes, comments and hyperlink targets are not imported. These two unconditional loss warnings are visible before conversion and returned in the result; object counts or full per-page quality comparison are not claimed.

ZIP limits: 20 MiB source, 1000 entries, 4 MiB declared single-entry expansion, 50 MiB declared total. Required XML entries are also bounded by actual streamed output and checked against exact sizes and CRCs. Unused assets are never inflated or extracted. Duplicate/case/Unicode-ambiguous paths, traversal and local/central disagreement are refused. XML has a depth/event/text budget; only UTF-8 bytes and UTF-8 encoding declarations are accepted, DTD/entity declarations are rejected before parsing, and external entity resolution is disabled. No relationship is followed to a URL or file. HTML escapes all text and includes `default-src 'none'`, `base-uri 'none'` and `form-action 'none'`; it has no script, links, images or external CSS.

## Output, cancellation and recovery

The user selects a source and chooses a new filename/location through NSSavePanel. Source and destination security-scoped access lasts only for the worker operation. The source is opened read-only with `O_NOFOLLOW`, then checked as a regular file and read with an actual byte limit. The output extension must match the selected format. Existing files, aliases/hardlinks, directories and even dangling destination symlinks are protected; approving a system overwrite prompt still cannot cause the service to replace an existing output.

The worker writes a mode-0600 UUID temporary file beside the output, synchronizes it, checks cancellation, then uses a same-directory POSIX hard link to install the final filename. `link()` atomically fails if any destination appeared after preflight. The temporary name is removed on success, cancellation or ordinary failure. Before this commit point, cancellation reports cancelled and leaves no final output. After it, completion is reported even if cancellation arrives, because a complete file has been installed. There is no automatic retry or implicit upload; users can fix the input/location and choose another output. No new edition is imported and no shared Library/store is changed.

Crash/power-loss recovery, directory-fsync durability, file-provider coordination, signed sandbox permission renewal and persistent job resumption are not implemented. A process crash may leave its uniquely named hidden temporary file; this change does not scan/delete arbitrary user directories on restart. Destinations without hard-link support (some network/removable/file-provider volumes) fail safely instead of falling back to a replacing rename. APFS temporary-directory operation is covered by tests; other filesystem support is unvalidated.

## Validation and remaining acceptance

See [conversion validation](CONVERSION-VALIDATION.md) for actual commands/results. All fixtures are original minimal OOXML/ZIP generated in memory in Swift, including compressed/malicious variants; no user document is read or uploaded. Shared tests and independent unsigned Mac/iPhone/iPad Simulator compilation run without desktop UI automation or launching/replacing the user's app. System save-panel/Finder interaction, oldest OS versions, signed sandbox distribution, VoiceOver, huge real-world Word-object coverage and full T17/UAT conversion acceptance remain unvalidated. Only the Mac entry is exposed; mobile conversion UI is not implemented.
