# Native implementation status

Date: 2026-10-03. Swift native UI + PDFKit, independent Kookit EPUB adapter, Mac/iPhone/iPad and AGPL remain confirmed. Latest approved delivery order: complete the Mac version first, then adapt its content/interaction to iPhone and iPad. Keep both targets and shared identities/models; mobile UI completeness is not this phase’s delivery gate. Current capability is a local PDF and Mac reflow EPUB development slice; the full [v0.3 specification](PDFno_AI_Development_Spec_v0.3_Native.md) remains the requirements inventory.

| Scope | Current evidence / gap |
| --- | --- |
| N0 specification | Complete original v0.2 read and rewritten to v0.3; original 77 requirements/tests/UAT IDs, 17 format goals and 7 conversion rows retained. Public copy removes personal metadata. |
| N1 real apps | `apple/PDFno.xcworkspace`, Mac/Mobile application targets and shared schemes. Mobile supports families 1,2; native Mac uses AppKit, not Catalyst. Local SwiftPM package has Domain/Services/Readers/UI targets and tests. |
| N2 PDF subset | Native file importer, managed hash-deduplicated originals, PDFKit view/page controls/search/outline/text selection, frozen PDF line geometry + hash/edition anchors, in-memory highlight projection, local notes/progress, revision guard and atomic manifest/backup. The PDF regressions remain in the 18-test Swift suite and the full two-test Mac UI flow. Actual results in VALIDATION. |
| N2 remaining | Real cover/thumbnails, complete document workspace, large-file/search cancellation, full multi-column/rotated/CropBox/multi-page selection fixture matrix, note editing/deletion, crash-injection recovery, robust extraction context/offset model and broader accessibility. |
| N3 EPUB | Pinned Kookit EPUB-only bundle in a restricted Mac WKWebView, native import/library/TOC/page controls/orientation/notes, canonical UTF-16 anchors excluding author ruby, exact source return and reopen progress. Native ZIP checks, actual streamed budgets, script/network isolation and stale-session refusal have original-fixture tests. Mobile EPUB UI, fixed layout, search, note editing/deletion, large-book/image/font/accessibility matrix remain pending. See ADR 0003 and VALIDATION. |
| N4 learning | Ported pure Unicode/ruby/task-state/provider-validation contracts. No actual provider stream, Keychain, endpoint/key/model settings, AI, translation, kana/grammar generation or cache service. |
| N5 migration | Old source/config/cache backed up then retired under explicit authorization. Old notes/localStorage left untouched; automatic reviewed legacy-demo importer remains unimplemented. |
| N6 iCloud | No CloudKit entitlement, container, identity, transport or device sync. Local only. |
| N7 Bookno/formats/conversion | Independent API and original goals preserved in specification. No transport, shared private database, other-format engine, comic reader, OCR, converter or asset exchange implemented. |
| N8 release | No release, signing account, certificate, provisioning registration, notarisation, app-store packaging or real-device installation. Local ad hoc signing only; final release device range open. |

Provisional adjustable developer baseline: macOS 14 / iOS/iPadOS 17, Swift 6, Xcode 16.4+. This supports current SwiftUI APIs and leaves CKSyncEngine compatibility; it does not enable cloud behavior. Two development bundle IDs are local placeholders, no registered identity is claimed.

Retired CLI N00/N01 were capability helpers, never native reading evidence. Their prior behavior is recoverable at baseline `2c40a8f`; current runtime has no dependency on them or Electron. See [migration/recovery](NATIVE-MIGRATION.md) and [validation](VALIDATION.md).

Mobile builds are retained as compile evidence. Dedicated mobile UI refinements and acceptance now follow the Mac milestone; any earlier failures remain honestly documented, not treated as a reason to delay Mac delivery.

Next implementable slice: strengthen Mac PDF selection/anchor and cover/thumbnail behavior with broader original fixtures and explicit performance/accessibility checks. Further EPUB resource/platform coverage and each external integration need their own scoped acceptance; the complete future product is not implied by this working slice.
