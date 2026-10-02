# Native migration and recovery

Date: 2026-10-02. The user explicitly authorised real Swift/PDFKit Mac and iPhone/iPad apps, recoverable retirement of the unused Electron/React/Node/CLI skeleton, ordinary commit/push to the existing public repository and exact-commit CI verification. No history rewrite, force push, release or shutdown is included.

## Recoverable baseline

Baseline commit: `2c40a8fbac87df39ed39c089b3be28a61bd1662c` on `main`. The previous skeleton `cbd17f38314b626a72059ae1168a2eedef3e1998` remains in history; its old successful CI is not native reading evidence. Initial untracked inputs were the newly authored v0.3 specification and Xcode's old project workspace metadata; no tracked source changes from another task were present.

Before implementation/retirement, a sibling directory outside this public checkout was created under `../pdfno-recovery/native-migration-20261002/`. It contains a verified full `repository.bundle`, tracked baseline archive, 57-file SHA-256 manifest, baseline status, the private v0.3 document snapshot, a complete copy of the previous `native/` tree and metadata, restoration instructions and later retirement manifest. Its owner-specific absolute path is reported privately, never published. Local caches and untracked Xcode metadata are moved there, not permanently deleted or pushed.

Before moving each tracked retirement candidate, compare its actual hash to that baseline. Check unknown files and all native metadata/build files for later changes; a mismatch blocks the move rather than assuming another task stopped. No process is killed, Git reset/clean is not used, and no backup destination is overwritten.

## Retirement and preservation mapping

| Old content | Action / reason |
| --- | --- |
| `src`, `electron`, `shared`, old `tests` | Move to external `retired/`; Node/UI/IPC code is unused by the new native app. Full source remains in Git history and recovery bundle. |
| Old `native/` CLI project/package/build/metadata | Move entire backed-up tree to external recovery. It was a capability-only command-line tool, not an application. Genuine native apps now live under `apple/`. |
| npm manifests/lock, Node version/config, Vite/TypeScript/ESLint/Playwright/Prettier files and old `.mjs` scripts | Move to recovery; no current native code requires Node or these jobs. |
| `node_modules`, `dist`, old `test-results`, `.DS_Store` | Move to recovery; never include caches or diagnostics in the public commit. |
| `docs/dependency-inventory.json` | Move unchanged to `docs/historical/dependency-inventory.json` as licensing/provenance history. |
| Unicode offsets, author ruby exclusion, repeated quote rules, immutable task source and terminal/cancel states | Reimplemented in pure Swift with original fixture tests. Actual AI stream/network cancellation is still unimplemented. |
| Revision guard, atomic notes+backup, corrupt/future-store refusal | Reimplemented in local actor repository and tested. New manifest is independent of old demo data. |
| Requirements, architecture decisions, audits, source notices, AGPL LICENSE | Preserve; identify historical documents and update current commands/status. Public spec retains full goals, removes private identifiers/paths/URLs. |
| Existing user books, Electron notes, browser localStorage, Bookno stores and accounts | Untouched. No automatic import, cloud access, asset upload, paid request or private-code copying. |
| Unknown/concurrently changed files | Preserve and report; never infer that an older task has stopped. |

## Current store and rollback limits

New native data uses Application Support `PDFnoNative` on Mac, the mobile app's own container on iPhone/iPad, a versioned `library-v1.json` and content-addressed immutable PDF originals. The PDF anchor here is the minimal `PDFSourceAnchor` v1 contract (edition/file hash, PDFKit extraction version, quote and per-line page-space rectangles). It is not the complete future generic `SourceAnchor` schema with context/span/CFI/OCR lineage. A later schema expansion needs an explicit migration, not silently redefining v1. Rotated/cropped/multi-column source fidelity needs further fixtures.

The prior note store's demo-text hash and block offsets must remain labelled `legacy-demo`; they cannot be fabricated into PDF geometry or EPUB CFI. A reviewed, previewable and idempotent read-only importer remains a separate task. This migration did not read any real old notes or database. An in-process actor serialises current writes; multi-process/store file-coordination and crash-injection durability remain gaps.

To inspect/recover old source safely, create a separate directory from the verified bundle or baseline commit; do not reset this checkout or replace the new store. For example, `git clone <recovery-directory>/repository.bundle <new-inspection-directory>` then `git switch --detach 2c40a8f` inside that clone. The baseline tar and `retired/` restore untracked metadata/caches separately if needed, after checking destination conflicts. Old app and new app data are distinct. Preserve copies of all stores before any future importer, downgrade or manual recovery.

No registered bundle identity, signing account, provisioning, entitlements or CloudKit container was created. Temporary development bundle IDs and local ad hoc signing are not a release configuration. No automatic migration or distribution is implied by successful development builds.
