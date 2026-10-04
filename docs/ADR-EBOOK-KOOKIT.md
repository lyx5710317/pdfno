# ADR — restricted Kookit MOBI / AZW / AZW3 / FB2 candidate

Date: 2026-10-04. Base: `8cf6ab8e93e057aa73a6607a17e6e2fe42269315`; branch `feature/ebook-formats`. Status: source and offline DOM profile, normal native ebook tests, original-fixture offscreen WebKit functionality and both native builds verified at `d28afe72d4e56fe9ff9c4d838d167b2a62754e52`. App UI acceptance and the previously blocked safety-special remain UNVERIFIED. This local branch is a reviewable candidate, not accepted Mac support or a release.

The Swift shell and PDFKit remain. `EbookReaderSession` directly invokes the public MOBI / KF8 / FB2 parser API retained by Kookit's original MobiRender / Fb2Render; those wrappers and GeneralRender are not executed. Original sources are pinned to Kookit 1.0.4 commit `95f602ed62d204af0de9278cf53212c309b34bfc`. The full official Git tree was not truncated; all five added source/metadata blobs matched it. [Source/identity manifest](../engine-build/EBOOK-SOURCE.json) and [actual bundle inputs](../engine-build/EBOOK-BUNDLE-INPUTS.json) record the boundary.

Kookit package declares AGPL-3.0-or-later and its unchanged root AGPL text is retained. Kookit's README identifies foliate-js as the MOBI/AZW3/FB2 engine; the separately preserved John Factotum MIT notice comes from reference commit `78914aef4466eb960965702401634c2cb348e9b1`. This is a license/provenance reference, not a claim that Kookit's modified embedded files equal that exact foliate commit. No extra engine, DRM removal, font decoder, fflate, CFI, Rangy or npm runtime dependency enters the new four-input bundle. The build removes upstream HUFF/CDIC and font-decoding implementations, substitutes bounded INDX/PalmDOC behavior, checks its exact transforms and retains corresponding original source. The generated resource carries complete Kookit and foliate notices.

Primary sources: [fixed package](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/package.json), [fixed LICENSE](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/LICENSE), [MOBI source](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/libs/mobi.js), [FB2 source](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/libs/fb2.js), [foliate reference MIT](https://github.com/johnfactotum/foliate-js/blob/78914aef4466eb960965702401634c2cb348e9b1/LICENSE).

## Per-format admission and original examples

All four `study-sample.*` publications are independently constructed from original text by [the generator](../scripts/generate-ebook-fixtures.py); their eight UI/test copies are explicitly enumerated with byte count and SHA-256 in [the original corpus](../scripts/ORIGINAL-FIXTURES.json). None is an EPUB or text document renamed to another extension. No third-party publication, DRM file, font, image or user document is distributed.

| Extension | Admitted content | Real original example | Boundaries |
| --- | --- | --- | --- |
| MOBI | `BOOKMOBI` PalmDB, version6 or restricted pure version8 | 748-byte MOBI6, compression1, two pagebreak sections, original ruby/emoji/decomposed accent | Not PalmDOC-only TEXtREAd, Topaz, DRM, HUFF/CDIC, combo or arbitrary other Kindle containers |
| AZW | Same verified PalmDB/MOBI structure, version6 or restricted pure version8; extension remains AZW | 786-byte independently built MOBI6/AZW with actual PalmDOC compression2 literal records | AZW is admitted by bytes/header, not extension. The sample is independently encoded, not a renamed MOBI fixture. Arbitrary Amazon content is not supported |
| AZW3 | Pure KF8/version8, valid skeleton and fragment INDX/TAGX tables | 1592-byte KF8 containing a skeleton, fragment, both real index pairs, EXTH and FDST | MOBI6 renamed AZW3 fails. Combo, fixed-layout, embedded media and raw NCX/guide indices are outside the profile |
| FB2 | Plain UTF-8 FictionBook2 XML with exact namespace, bounded main body | 833-byte XML, two original titled sections, multilingual Unicode | FB2 ZIP, other encodings, DTD/entities, binary assets, excessive/nested bodies and additional non-linear note bodies are unsupported |

MOBI records may be uncompressed or PalmDOC; native admission verifies actual expansion, backward distances, text length and record offsets. UTF-8 and Windows-1252 headers are admitted by the parser; the distributed multilingual samples exercise UTF-8 only, so broad Windows-1252 compatibility remains unverified. Raw NCX and KF8 guide indices must be absent (`0xffffffff`); the native directory is derived from decoded source headings with a source-section fallback. This intentionally excludes many real-world books with such indices. It is not a general Kindle compatibility claim.

## Minimum code path and source identity

`EbookLibraryModel` reads only the selected original, performs native preflight and a real Kookit parse before adding a library entry, then reopens the committed original. Import, library list/grid rows, source headings/section directory, reading, real DOM selection, local notes, exact return and progress restoration are implemented as candidate code. Normal native import/storage and offscreen WebKit opening, directory data, DOM selection, notes, exact return and progress reopen passed for all four original fixtures. Library rows, example menus and app UI interaction remain unexecuted. The renderer rebuilds display HTML from escaped semantic runs; original links, attributes, CSS and scripts never enter the displayed DOM. Author ruby is retained while rt/rp are excluded from canonical source and selection offsets. Images do not add invented placeholder text to anchors.

`EbookBook` retains the requested `format` and actual `contentKind` (mobi6/kf8/fb2). `EbookAnchor` binds schema/extraction version, edition, raw file SHA-256, format, content kind, logical source section, block, scalar-exact UTF-16 interval and exact quote/prefix/suffix. Canonical equivalence, split surrogate pairs, wrong contexts, different types and stale sessions fail closed. This new type is not relabeled EPUB or DOCX. Source section is a decoded section index, not a claimed EPUB CFI or original physical page.

The independent `ebook-kookit-v1.json` keeps complete originals under `Originals/<sha256>.<actual extension>`; unknown/future/corrupt manifests refuse writes, with validated atomic commits and previous-version backups. No existing PDF/EPUB/DOCX/comic/note-edit schema or store is migrated. Existing cover schema is unchanged: ebook rows currently use a native book glyph and explicit format label. Library search/note editing/AI/translation are not extended to ebooks by this slice. Active ebook state rejects hidden PDF progress and AI source capture. Future text-format routing must remain a separate reader type, with its own sources.

## Limits and host boundary

8 MiB original; 1000 PalmDB records/decoded sections/index entries; 4096 bytes actual text expansion per record; 4 MiB total decompressed text; 10000 semantic paragraphs; 1,000,000 canonical UTF-16 units; 100000 runs; 48 levels; bounded INDX variable integers/offsets/masks; 100000 FB2 nodes and 300000 extraction work units. XML entities/declarations, encrypted files and unsupported compression are refused before display. Full compatibility, image/font/layout fidelity, complex tables/lists, footnotes, original linked TOC semantics, vertical pagination, large files and non-UTF-8 corpus coverage remain unverified or excluded.

The Mac host uses nonpersistent WebKit storage, a random session per opening, a script nonce, CSP denying network/resources, navigation refusal, a single engine-resource whitelist, a 20-second readiness/extraction timeout and stale callback rejection. Content-rule files use a per-session temporary directory, not the shared default Library rule store. The offscreen functional tests exercised actual WKWebView opening and the trusted bridge. CSP/network/process security guarantees still require separately authorized safety acceptance; no previously blocked safety-special was retried. Mobile reading is not exposed. No user app process, real key/API/account, user library or private book was used.

## Reproduction and acceptance gate

```sh
npm ci --prefix engine-build --ignore-scripts --no-audit --no-fund --registry=https://registry.npmjs.org
python3 -B scripts/generate-ebook-fixtures.py
node engine-build/build-ebooks.mjs
node --test engine-build/ebook.test.mjs engine-build/ebook-bridge.test.mjs
python3 -B scripts/generate-original-fixture-inventory.py
python3 -B scripts/check-native-source.py
```

jsdom26.1.0 is test-only. Its 39 installed records/integrity/actual license hashes are in `EBOOK-TEST-DEPENDENCIES.json`; original license bytes are in `test-licenses/`. The saxes6.0.0 npm artifact omits LICENSE; its complete original v6.0.0 license is retained separately with the source URL. None enters any app bundle. The existing runtime dependency records and existing EPUB/DOCX/comic resources rebuild byte-identically.

After the new explicit authorization for normal four-format builds/functionality, the single retry of the previously rejected `EbookTests` invocation was approved and passed (5 test definitions, including 4 format cases). `EbookReaderTests` passed (2 definitions, including 4 real WebKit format cases); Mac `build-for-testing` and generic iOS Simulator `build` succeeded. No runtime or test-source fix was needed. This follow-up changes evidence/documentation only; tested source is `d28afe72d4e56fe9ff9c4d838d167b2a62754e52`. Exact commands, exit codes, toolchain and log hashes are in [native functional evidence](EBOOK-NATIVE-FUNCTIONAL-EVIDENCE.json).

Four app UI flows are compiled but not executed. `.github/workflows/ebooks.yml` has not run and does not replace the existing unfiltered acceptance suite. Before integration/release, execute all old Mac UI cases plus the four new flows at the final candidate commit, and run any separately authorized regression checks. The safety-special remains UNVERIFIED with no retry, disable-sandbox, compiler switch or bypass. See [validation and integration handoff](EBOOK-VALIDATION.md).
