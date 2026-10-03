# Audit remediation on the frozen 05cbcf5 baseline

This local branch starts at `05cbcf537e0ae85b2831a6b86e500e5d7d2b0a94`. The frozen main branch and both auditors' reports, sources and evidence stay unchanged. This record does not constitute independent revalidation, complete UI acceptance or permission to publish.

Original independent report identities:

- Security/license report: 32902 bytes; SHA-256 `5f860f2cc8f0e0c3ea02b073eaf7a34f0a5471e0f5f09dc24cc3cb7278fb8f6a`.
- Data/functional report: 52747 bytes; SHA-256 `ed0bbbf97baf4382a5d65f4dec50281015bb74b94821f7562540ce0c6739c582`.

| Independent finding | Remediation status | Required verification |
| --- | --- | --- |
| F01 / DF-03: output-directory race (one defect) | Locally repaired | Original swap reproduced on baseline; directory descriptor, device/inode checks, `openat`/`linkat`/`unlinkat`; unchanged originals/sentinels and cleanup after stage creation |
| F02: DOCX table quadratic cost | Pending | Linear table indices, bounded work; genuine Mammoth output and actual isolated reader |
| F03: EPUB sanitization MIME/extension split | Pending | Unified content/resource admission; original nonstandard suffix and SVG cases; no claim of proved script execution or sandbox escape |
| F04: complete reads before budgets | Pending | Descriptor regular-file validation, bounded chunks, originals/manifests/backups/imports; growth/symlink/FIFO regressions |
| F05: model recreation resets app-session budgets | Pending | Shared app-session owner with isolated probe/selection/page counters; credentials remain separate; rebuilt models remain capped |
| F06: mutable CI Action tags | Pending | Verified official full commit IDs and a source guard; permissions unchanged |
| DF-01: PDF stale sidebar progress | Pending | Latest record on open, captured book/page progress context; A/B/A and reopen |
| DF-02: duplicate moved DOCX revision text | Pending | Accepted-revision exporter excludes old move location; TXT/HTML and unchanged originals |
| DF-04: EPUB long-paragraph/Unicode progress | Pending | Visible-character/Range navigation and scalar-safe spans in the real isolated reader |
| DF-05: drafts tied to transient reader identity | Pending | Stable source identity distinct from request session fences; real reader reopen |
| DF-06: PDF aggregate quote not verified | Pending | Explicit aggregate/region relationship with real multiline selection; forged quote refusal |
| DF-07: requirement accounting | Pending | Distinguish83 defined R/T/U/S/J/UAT rows from legacy UI/AI/A references; preserve all original targets and provide a reproducible ledger |

## F01 / DF-03 evidence and remaining limits

The corrected-behavior regression first failed against the unchanged frozen service: it returned a completed30-byte result in the replacement directory. Log: `/tmp/pdfno-audit-fixes-05cbcf5-red.log`. A fixture Sendable capture compilation error occurred first and is not counted as a runtime reproduction.

The repaired service pins the selected parent before reading, inspects the final name relative to it, and keeps that descriptor through staging, atomic no-replace installation and cleanup. Read-only device/inode checks reject observed pathname replacement. The writing phase now starts after exclusive0600 staging creation, so replacement/cancellation regressions also test cleanup of an actual existing staging file. No final or staging path mutation resolves through the replacement parent. A final parent symlink is rejected; existing ordinary ancestor symlinks may resolve during initial pinning, after which identity and all mutations stay tied to that descriptor.

`ConversionDestinationTests` has five methods/eight argument cases: writing-time symlink/plain-directory/ancestor swaps, reading/validation swaps, cancellation after a staged-file swap, initial parent-symlink refusal and ordinary Unicode success. Together with all17 existing conversion methods, **22 methods passed / two suites /0.089s**, including existing leaf collisions, dangling links, retry, every cancellation phase and post-commit completion. Log: `/tmp/pdfno-audit-fixes-05cbcf5-conversion.log`. New fixture parameter visibility was corrected after an initial compilation failure; no assertion or production limit was weakened.

An attacker who can continue renaming directories after the last identity check or after commit can still change the displayed pathname; the output operations nevertheless remain in the originally pinned directory. This is not a proof against arbitrary same-user file tampering, privilege escalation or all File Provider behavior. Signed sandbox/provider, power-loss/crash and actual app UI revalidation remain pending. No owner app, private book or real credential is involved.
