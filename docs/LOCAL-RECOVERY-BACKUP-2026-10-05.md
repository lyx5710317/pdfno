# Local recoverable deletion and verified directory backups

Date: 2026-10-05. Slice baseline: `7bea8ec89ea7273b3b52ee714fbf1180b3d51c73`. This slice adds independent Domain/Services/UI files only. Shared library models, repository writers, layouts, schemes/generator, requirement ledger and all 50 existing app UI tests are unchanged. The integration owner must wire the host lifecycle described below before making mutation actions available. No push, merge, release, real library operation or application/UI launch is part of this slice.

## Implemented behavior

`LocalRecoveryService` offers read-only book/trash listing, previewed book or saved-note removal, previewed trash restoration, checked export, read-only package verification and restoration to a new directory. Removal is explicitly “move from the local library to trash”; it is not removal of a download or cross-device deletion. There is no permanent-delete API, automatic expiry or empty-trash action.

Book deletion stages the original book row (including reading progress), every related saved reading/learning note, metadata and cover record in a versioned tombstone. Original and cover bytes are additionally retained under `LocalRecovery/Assets`; originals are not removed from `Originals`, and shared assets are not deleted. Cover collection can later discard an unreferenced ordinary cover asset without discarding its retained copy. Trash content and completed receipts remain indefinitely; disk reclamation is not implemented.

Saved-note deletion targets `.note(manifest:id:)`; it removes just that saved reading or learning record. Source anchors, generated results, user bodies and revisions are preserved bytewise as JSON record payloads. Separate note tombstones require the source book to be active before restoration. Restoring a book does not implicitly restore a note removed earlier in a separate operation.

Restoration merges the selected tombstone into the active manifests. An existing exact record is acceptable; same ID with different content, edition/hash, revision or changed body is refused. Native manifest uniqueness rules additionally refuse same-hash duplicates within their own stores. UUID/edition collisions across active format stores are refused. There is no last-write-wins policy. A tombstone marked restored acknowledges repeat restoration without rewriting later edits or reviving a later deletion. Trash preflight fingerprints all managed file sizes/hashes and confirmation compares the complete snapshot again.

## Actual data coverage

| File/path | Covered data and identity |
| --- | --- |
| `library-v1.json` | PDF book/edition/hash, physical page count and last page, reading note anchors/user text/revisions/dates |
| `epub-v1.json` | EPUB book/edition/hash, canonical progress and reading notes |
| `comics-v1.json`, `comics-cbt-v1.json`, `comics-cb7-v1.json`, `comics-cbr-v1.json` | Individual CBZ/CBT/CB7/CBR stores, page inventory, direction/layout/progress; these stores currently have no saved reading-note collection |
| `docx-mammoth-v1.json` | Current DOCX books/progress/notes; obsolete `docx-v1.json` is refused rather than migrated |
| `text-formats-v1.json` | TXT/Markdown/HTML/XHTML/MHTML/readable XML books/progress/notes |
| `ebook-kookit-v1.json` | Finite MOBI/AZW/AZW3/FB2 books/content kind/progress/notes |
| `learning-v1.json` | Complete saved general AI result/provenance/source/user body and existing credential-free provider config; no key or credential-reference field exists in this schema |
| `japanese-learning-v1.json` | Original saved Japanese review, author/generated readings, components/grammar/warnings, corrections and user body |
| `book-metadata-v1.json` | Local title/author and stable book identity/revision |
| `covers-v1.json`, `Covers/Assets/<hash>.png` | Identity/origin/revision/provenance plus existing original cover PNG, hash/size/dimensions checked |
| `Originals/<hash>.<format>` | Immutable stored bytes; exact current storage suffix is used, including `.markdown` for imported MD and `.html` for imported HTM |
| Existing known manifest `.backup` files | Previous strict manifests preserved without rewriting; originals and cover assets referenced by previous manifests must still exist |
| `local-recovery-v1.json`, `LocalRecovery/Assets` | Versioned trash records and retained original/cover copies, including already-restored historical tombstones |

The 18 reading extensions map to 17 actual storage formats: HTML and HTM use one HTML store/suffix; MD uses the `markdown` enum/suffix. This module verifies storage identity, strict schema/anchors and asset bytes; it does not add format reading engines or claim new rendering acceptance. Synthetic recovery fixtures intentionally test storage contracts, not document rendering.

`note-edit-drafts-v1.json` and `record-edit-drafts-v1.json` (and their `.backup` files) are excluded without reading their contents; the inventory reports which drafts were omitted. `Covers/Thumbnails` is a rebuildable cache and excluded. Transaction staging/receipts are excluded because completed user data is represented by the active manifests and trash. Keys/Keychain/provider credential configurations/account files/logs are not admitted paths. Provider/model/provenance already present in saved learning results is preserved. User-authored note text is retained as written; no claim is made to detect arbitrary secrets a user typed into a note.

An unknown top-level file, unknown/future schema or unknown field is refused. A file from an unregistered learning module is not silently omitted. Non-data directories, engines, indexes, other applications and arbitrary user directories are not part of the backup.

## Backup format and integrity

A `.pdfnobackup` export is a directory package, not ZIP:

```text
inventory-v1.json
Payload/
  <exact admitted relative user-data paths>
```

The independent inventory identifies `pdfno-directory-backup-1`, schema 1, creation ID/date, complete adapter set, each relative path/byte count/SHA-256, aggregate size and omitted-draft names. Every actual payload file must occur in the inventory. All payload entries are read with bounded ordinary-file access, checked against the inventory and then passed through the current trusted native store decoders. Book/source references must resolve to exact book/edition/hash identities; covers additionally resolve their format, PNG bytes, size and dimensions. Historical trash fragments are checked against original book context.

Limits are explicit: 256 MiB aggregate payload, 200 MiB per ordinary asset, 5 MiB per manifest/inventory, 20,000 files, 10,000 records per collection, 1,000 tombstones. Transaction preimage/postimage staging is also bounded to 256 MiB. Large libraries beyond these limits are refused. Capture holds bounded payload bytes in memory; streaming/high-volume performance has not been implemented or measured.

Absolute/traversal/empty/backslash/NUL paths, symlinks (including linked parents), special files and unexpected data paths are refused. macOS's system `/var` and `/tmp` aliases are canonicalized; custom links are not accepted. Read-time growth/replacement checks reuse `BoundedFileReader`. These are functional path/integrity checks, not the blocked independent security review.

Export runs under a host write pause, copies a snapshot to a new sibling staging directory, verifies it, rechecks the entire source snapshot and installs with exclusive `renamex_np(RENAME_EXCL)`. Existing exports are never overwritten. Cancellation or injected pre-install write failure leaves no completed destination and preserves the source. A failure after the exclusive rename leaves a complete package available for inspection.

Import first verifies without modifying the current library and exposes file/byte/book/saved-record/trash counts and restore mode. Confirmation pins the inventory hash and revalidates every payload entry before copying and verifying a new sibling staging root. Only a previously nonexistent destination is accepted. Existing even-empty directories and any destination inside the current library are refused; the original library is not switched or replaced. Installation is one exclusive directory rename. Merging whole backup libraries, overwriting existing roots and schema migration are not implemented.

The adapter set must match the exporter set; registering a new learning adapter can make older packages refuse verification until an explicitly reviewed compatibility policy is added. This conservative version-1 behavior prevents claiming a complete backup with unknown coverage.

## Multi-file transaction and restart boundary

Native repository writers currently have independent actors. The new recovery actor serializes its own operations only and cannot automatically suspend them. Multi-file modifications require `LocalRecoveryWritePermit(pausedRoot:writerEpoch:)`, a host attestation, not an enforced global writer lock.

A mutation first validates the complete proposed state, captures each path's expected preimage and creates verified preimage/postimage copies. It then atomically writes a `prepared` journal under `LocalRecovery/Transactions/<operationID>`. Each install compares current bytes to the expected preimage. All installed bytes are checked before the durable `committed` receipt is written. Ordinary failure/cancellation rolls back only paths still equal to a known preimage or installed postimage. Cancellation is ignored only by the bounded rollback reads so rollback can complete. Existing `.backup` files and unrelated admitted data are not changed.

A fresh service must call `recoverPendingTransactions` with writers paused before opening writers. `prepared` journals roll back verified preimages; `committed` journals acknowledge historical completed operations and do not undo later ordinary edits. Staging directories without a journal never began source writes and are retained, ignored by snapshots. No staging cleanup/retention policy is implemented. A modified journal/preimage or intervening unknown write blocks recovery, preserves new data and keeps the root blocked for manual reconciliation. The operation is not reported successful in that state.

This is a reversible journaled same-process contract. Individual file replacement is atomic; the sequence is not a filesystem-wide transaction and is only hidden from observers by the host pause. A simulated interruption creates a fresh repository/service against the same temporary files; it does not prove power-loss durability, filesystem `fsync`, inter-process isolation, file-provider behavior or physical-disk failure. No cross-process, cloud, SQLite or automatic repair promise is made.

## Host integration checklist

1. Instantiate one service for the managed root, registering trusted English adaptation when present.
2. On startup, block writes/readers, recover pending transactions, then recreate/reload repository instances. Existing cached readers/documents/search/cover memory must not survive recovery.
3. Implement `LocalRecoveryHostPause` for `LocalRecoveryManagementModel`: stop new imports/progress saves/edit commits/learning saves, cancel active AI jobs and block late result saves; wait for all already-issued writer tasks to settle. Prevent draft autosave during the operation. Only then issue the permit and invoke its operation.
4. On success, rollback or recovery, recreate/reload all format/learning/metadata/cover repositories and readers, refresh searches and discard stale UI snapshots. Keep writes blocked when recovery reports conflict or a pending transaction.
5. Preserve existing draft files. Quarantine/review old drafts after a deleted/restored identity or root switch; do not automatically apply them to a restored note or manufacture a new source. Recovered backup roots have no drafts. Clear live editor ownership and pending saves before reload.
6. Attach `LocalRecoveryWorkspace(model:)` to the shared navigation/settings entry. Saved-note rows can call `model.preview(.note(manifest:id:))`; book rows can call `.book(LocalRecoveryBook)`. The component provides preview/confirmation, file selection, export/verification/new-root restore and trash actions, but does not choose a running-library replacement.

The UI uses ordinary folder selection. Export/new-root recovery append fresh UUID names in the selected destination parent, never use an existing name. Security-scoped access is held during selected-package/destination operations. No scheme/Info.plist/account/signing changes were needed by the independent component. Cancellation is available at service task level; the current management component has no cancel-progress button and ignores file-picker cancellation without starting work.

## Trusted English adaptation

`LocalRecoveryAdditionalAdapter` permits only `english-learning-v1.json`. Integration supplies `validate: @Sendable (Data) throws -> Void` using its fully audited repository decode and `associations: @Sendable (Data) throws -> [LocalRecoveryAssociation]`. Every record ID must correspond one-to-one with the `notes` collection, including exact source book ID, edition ID and SHA-256; optional format should be supplied where available. The registry checks duplicate JSON members, version/size, collection bounds and mapping cardinality in addition to the supplied validator. The current English slice was read-only checked as schema 1 with `notes` only, matching the empty-store contract. If a future English schema adds required fields, the adapter contract must be reviewed rather than silently migrated. In normal deletion/restoration the manifest stays present.

This seam is trusted application code, not a plugin/dynamic filename loader. The slice's synthetic additional-learning adapter proves inclusion, delete/restore and refusal of unapproved filenames; actual English schema/source/retention wiring remains the integration owner's review.

## Validation evidence and unverified work

Build/test logs are under this worktree's `.build/LocalRecovery/` and are not tracked. Heavy checks used the batch's `run-heavy-check.py` file lock and two build jobs. Actual tools: Xcode 27.0 (27A266a), Apple Swift 6.4, arm64 host; deployment targets remain unchanged. The initial Swift invocation hit a default home-cache restriction; rerunning with explicit isolated module/cache directories succeeded. Initial sandboxed Xcode reported that the existing workspace was not a workspace and its service connection became invalid; the authorized build-only escalation succeeded without starting an app.

The final validation receipt is filled after the final commands complete. No app UI test was executed, skipped or modified. All 50 existing actual UI methods/identifiers/assertions remain byte-identical to baseline. Shared entrypoint/pause lifecycle, actual desktop/file-panel UI, VoiceOver, oldest supported OS, Intel, physical iPhone/iPad, large-library performance, file providers, cloud and fault/crash durability are not verified. Independent security remains **UNVERIFIED / platform-blocked**; no rejected scan was retried.

Final slice checks:

| Check | Actual result |
| --- | --- |
| Selected storage regressions | **100 test methods / 9 suites passed**; selection includes `LocalRecoveryTests`, `RepositoryTests`, `JapaneseLearningRepositoryTests`, `NoteEditingTests`, `RecordParityTests`, `LibrarySearchTests`, `LibrarySearchModelTests`, `BoundedFileReaderTests`, `CoverTests` |
| New recovery suite | **20 methods, 55 parameterized/nonparameterized case executions**; 17 storage-format closures, 13 independent reading-note closures, 2 standalone learning-note closures, 5 interrupted journal boundaries, 3 package pre-install failure boundaries and 15 ordinary methods; methods also exercise their internal failure/schema loops |
| Native source guard | **619 source files checked**, passed |
| Mac native target | Unsigned Debug `build`, arm64 selected by the local Mac destination, passed |
| Mobile native target | Unsigned Debug generic iOS Simulator `build`, arm64/x86_64 simulator compile products, passed; no simulator boot/application run |
| Existing UI preservation | `NativeUITests.swift`: 46 methods, SHA-256 `1d22a88e17984f4123fe9728e4a978cf24d8d242737b192c40e5f073bebf16c6`; `EbookFormatUITests.swift`: 4 methods, SHA-256 `4d50ab3983c6df07fe03c296648c1bc6cc0ad497fa7ede759742988d9117c233`; both byte-identical to baseline |
| UI execution / independent security | **0 app UI tests run**; independent security remains **UNVERIFIED** |

Commands (run from the assigned data worktree; logs remain local):

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/LocalRecovery/ModuleCache" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/LocalRecovery/ModuleCache" \
python3 ../run-heavy-check.py -- swift test \
  --package-path apple/Packages/PDFnoKit --scratch-path .build/LocalRecovery/Package \
  --cache-path .build/LocalRecovery/SwiftCache --jobs 2 --disable-sandbox \
  --filter 'LocalRecoveryTests|RepositoryTests|JapaneseLearningRepositoryTests|NoteEditingTests|RecordParityTests|LibrarySearchTests|BoundedFileReaderTests|CoverTests'
python3 scripts/check-native-source.py
git diff --check
python3 ../run-heavy-check.py -- xcodebuild -workspace apple/PDFno.xcworkspace \
  -scheme PDFnoMac -configuration Debug -destination platform=macOS \
  -derivedDataPath .build/LocalRecovery/Mac -clonedSourcePackagesDirPath .build/LocalRecovery/MacPackages \
  -jobs 2 CODE_SIGNING_ALLOWED=NO build
python3 ../run-heavy-check.py -- xcodebuild -workspace apple/PDFno.xcworkspace \
  -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/LocalRecovery/Mobile -clonedSourcePackagesDirPath .build/LocalRecovery/MobilePackages \
  -jobs 2 CODE_SIGNING_ALLOWED=NO build
```

Evidence: `.build/LocalRecovery/storage-regression.log`, `mac-build.log`, `mobile-build.log`, `source-guard.log`, `ui-preservation.json`, and `FINAL-LOCAL-RECOVERY-RECEIPT.json`. The final JSON records the committed SHA and per-log SHA-256. Earlier failing test/compilation attempts identified and fixed temporary staging-validation and nondeterministic fingerprint defects; only the final source/test results above establish the slice outcome. There is no unresolved functional test failure in the final selection.

Rollback of the code is a normal Git revert of this local slice before host activation. Reverting application code after using trash does not restore deleted book rows automatically: retain the complete managed root/package and recover through this module first. Older builds do not understand `local-recovery-v1.json`; they must not be allowed to discard that file or retained assets. No user store was migrated or used to establish these results.
