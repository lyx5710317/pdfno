# Native/Xcode tasks

As of 2026-10-02, the approved future product is Swift native UI + PDFKit, with an independently selected EPUB adapter and long-term Mac/iPhone/iPad support. This revision is **documentation only**. See [ADR 0002](ADR-0002-NATIVE-APPLE.md), [the implementation/migration plan](NATIVE-APPLE-PLAN.md), and [EPUB audit](EPUB-ENGINE-AUDIT.md). The current `native/` project remains a CLI; no GUI app target has been created.

## Preserved legacy bridge

| ID | State | Concrete deliverable / exit criterion |
| --- | --- | --- |
| N00 | Implemented | `PDFno.xcworkspace`, real command-line target and shared `PDFnoBridge` scheme; unsigned universal Xcode build |
| N01 | Implemented | `capabilities` JSON protocol and fixed-path Electron invocation; unknown operations exit 64 |
| N02 | Replanned | Keychain belongs to the future native service, not new Electron bridge work; access contract and device policy remain open |
| N03 | Replanned | Plan native three-device iCloud; decide content/backend and obtain explicit permission before container/entitlement changes |
| N04 | Frozen | No new bridge/Electron packaging development; existing fixed capability invocation is retained |
| N05 | Replanned | Native app signing/channel/recovery gates follow A8; no existing identity or entitlements are silently changed |

The Electron UI queries only capabilities. N00/N01 do not mean Keychain, iCloud or a native GUI is integrated. There is no dummy SwiftUI wrapper, certificate request, provisioning update or persistent token setup. The executable lives only under ignored build output.

## Future native app tasks

A0 documentation is the current scope. A1 creates two real app targets in a new `apple/` directory; A2 validates local PDFKit reading; A3 evaluates EPUB; A4–A8 cover learning, migration, iCloud, Bookno/conversion and release gates. These targets/modules do not exist yet. Deliverables and exit criteria are defined in [the native plan](NATIVE-APPLE-PLAN.md#8-实施任务与验收门槛).
