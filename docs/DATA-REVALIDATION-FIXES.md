# Data revalidation follow-up: RV-01 and RV-02

This local follow-up starts at preserved candidate `216a8de05497ca0962e2bf2993183747d0bff442`, tree `c1cabf846d742c37bc573854b2de2580abf6927f`, in `feature/audit-fixes`. It repairs only the two confirmed data-functional P3 findings. The parent will give the new fixed Git SHA to the same independent data auditor; these local results do not constitute that independent revalidation.

The independent `REVALIDATION.zh-CN.md` remains untouched, SHA-256 `e1f702b8286f7fa5b4cc2bf2cdebbe48ee6a3ba36c41526799a269506e46c049`. Original frozen main remains `05cbcf537e0ae85b2831a6b86e500e5d7d2b0a94`; neither original audit report is changed. Candidate216 and its historical claims remain accessible in Git. The new report does not erase its two failed findings or recast them as environment failures.

**Security-specialist revalidation remains platform-blocked/unverified.** The parent reported a cyber-risk platform block, not a normal test failure. This task does not retry, rewrite, replace or execute that blocked specialist's experiments. Ordinary data/reader regressions and builds cannot close the specialist security/license review.

## RV-01 / residual DF-06: keep region-internal source text exact

The old `PDFSourceAnchor.hasConsistentQuote` removed every whitespace scalar from both the aggregate and region text. A real original PDFKit selection of `window` therefore accepted aggregate `w i n d o w` as exact, AI-valid and writable. The new corrected-behavior regression reproduced **three assertion failures** against the unchanged216 implementation before the repair (`/tmp/pdfno-data-fixes-rv01-red.log`,1 method/0.089s).

The validator now compares every region's internal Unicode scalars exactly and in order, including spaces, tabs and nonbreaking spaces. It permits separator whitespace differences **only at boundaries between distinct line/page regions**: trailing whitespace of a non-final region, leading whitespace of a non-first region and the corresponding separator in the aggregate. A single region has no boundary trimming. Leading/trailing aggregate edges, hyphens, combining marks and all other scalars remain exact. No raw quote is rewritten and no extraction version/schema is changed. Ambiguous internal changes are rejected rather than silently normalized.

PDFKit resolution, AI source validity, note save and manifest decode already share this validator. Consequently the same incorrect quote receives needsRebind/invalid/sourceMismatch or an unreadable-store error at the appropriate boundary. An existing malformed manifest and its previous backup remain byte-identical after refusal; original PDF bytes remain unchanged.

`PDFQuoteConsistencyTests.swift` adds four methods, with2 query cases and4 rotation cases in its parameterized methods:

- Real `window` and `Reading opens` selections reject inserted/deleted/repeated/internal/newline/tab/NBSP spacing and altered outer edges through reader, AI and store; valid originals remain exact and failed writes preserve the manifest/backup.
- Literal region tests accept line/page separator differences while rejecting internal word-spacing, changed composed/decomposed Unicode, missing hyphens, omitted repeated regions and reordered distinct region text.
- A manually malformed stored word-spacing quote is refused without replacing its bytes, backup or original PDF.
- Original CoreText-generated Unicode/two-page/hyphenated PDFs remain resolvable after JSON round-trip and reopen with CropBox and rotations0/90/180/270. These are original in-memory fixtures, not user documents or new committed binaries.

The original whole-page/multiline and unselected-text regressions remain. The focused run passed **9 methods /2 suites /0.126s**, including the five existing AuditFunctionalTests methods. A test expression initially exceeded Swift's type-checking limit and was split into explicit String values; that compilation error is retained separately and is not treated as a product runtime reproduction.

This verifies the stated original fixture matrix, not all real PDF layouts, font encodings, overlapping selections, reading orders or arbitrary old records. Unknown relationships continue to require rebinding; the patch does not introduce automatic repair, migrations or new UI behavior.

## RV-02: bind each formal ID to its own complete definition

The old guard accepted R02 with R01's existing `specRow` because it checked row membership and ID-set size separately. Before repairing the guard, the real CLI in a fresh temporary repository accepted both this wrong binding and changed category totals. The new regressions correctly failed **two of three methods** (`/tmp/pdfno-data-fixes-rv02-red.log`); normal original content passed.

`scripts/requirement_ledger.py` parses the canonical specification into **ID → (line number, complete original row)**, rejects duplicate specification IDs, and checks the expected83 IDs and category totals. Each ledger item must match the complete row and actual line for its own ID. Ledger IDs and definition rows must be unique and one-to-one. The ledger cannot redirect the canonical specification path. `check-native-source.py` calls this validator; it no longer treats an unrelated existing row as enough evidence.

The actual83-entry ledger, its baseline assessments, the complete specification, all legacy UI/AI/A references,18 reading formats and seven fidelity directions are byte-identical to216. No requirement is added, deleted, renamed, redefined or inferred from legacy range endpoints. Titles and historical audit assessments retain their original provenance; this binding guard is not a new independent assessment of implementation completeness.

`scripts/test-requirement-ledger.py` runs the actual source guard in a private temporary copy of repository source. It never mutates the candidate's ledger/specification. Its eight methods cover the correct baseline plus19 negative cases: wrong-ID duplicate/swap/changed definitions, wrong/missing/type-altered category totals, wrong formal total, missing/extra/duplicate IDs, deleted/added/changed/duplicate specification rows, incorrect line reference, redirected spec and the pre-existing mutable-Action lint rule. Counts must be integers, including refusals of otherwise numerically equal floats. Negative cases require both nonzero exit and the relevant diagnostic. The workflow now runs these tests after the ordinary source guard; no Action identity, permission or publishing setting changes.

## Allowed functional validation and remaining gates

- Full ordinary shared Swift package: **120/120 methods,19 suites,2.802s**, in the approved local execution context. This is116 preserved methods plus four new quote-consistency methods. Parameterized argument cases are not extra methods. Log: `/tmp/pdfno-data-fixes-full-swift.log`.
- Requirement guard regressions: **8/8 methods,19 negative cases,1.505s**; actual source guard and `git diff --check` pass. Log: `/tmp/pdfno-data-fixes-ledger-regressions-final.log`.
- Mac and generic iOS Simulator targets: **BUILD SUCCEEDED**, signing disabled, dedicated worktree `.build/AuditFixMac` / `.build/AuditFixMobile`, no app or simulator launch. Logs: `/tmp/pdfno-data-fixes-mac-build.log`, `/tmp/pdfno-data-fixes-mobile-build.log`.
- Node/engines: unchanged from216, including source, generated resources, locked/vendor input and dependency manifests. The independent data audit's **14/14 Node** result remains216 evidence; no unchanged Node/security/performance experiment is rerun or relabeled as a new security-specialist result.
- Current source still has9 ordinary WebKit methods, giving a planned restricted denominator111 (120−9), including the unchanged Keychain assertion. This current restricted attempt **did not complete**: the known Keychain assertion failed, PDF/Vision logged Code8/`Failed to create CVPixelBuffer`, and the test process terminated with unexpected signal5. There is no final pass count, so this is not reported as110/111 or as a complete subset pass. The exact log is `/tmp/pdfno-data-fixes-restricted-subset.log`. The observed context difference does not establish the crash's OS/framework root cause; no assertion is changed or new fixture skipped to manufacture a completed result.

Historical Keychain counts remain98/98 approved original full package and91/92 security-auditor restricted input; candidate216 independently had116/116 approved and106/107 restricted. The new four methods change the restricted denominator107→111. The original `LAContext.interactionNotAllowed` assertion is not weakened, skipped or xfailed; tests use a fake exact-reference store and query construction without real SecItem access. Signed persistent-Keychain acceptance remains unverified.

The unchanged original fixture inventory/bytes, project/schemes, credential implementation/assertion, frozen main and audit-report identities are checked again. User app, private documents/keys, Library, signing account/CloudKit container and other worktrees are not operated or changed. No new feature, push, merge, shutdown or Library update is performed.

Remaining delivery gates are the same data auditor's fixed-SHA revalidation, the separately blocked security-specialist review, remote final-SHA CI/complete app UI and signed/lowest-system/real-device/persistent-Keychain acceptance. Current local package/build results do not imply these gates have passed.
