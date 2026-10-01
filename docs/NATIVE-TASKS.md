# Native/Xcode tasks

| ID | State | Concrete deliverable / exit criterion |
| --- | --- | --- |
| N00 | Implemented | `PDFno.xcworkspace`, real command-line target and shared `PDFnoBridge` scheme; unsigned universal Xcode build |
| N01 | Implemented | `capabilities` JSON protocol and fixed-path Electron invocation; unknown operations exit 64 |
| N02 | Open | Agree keychain service/access boundary; define store/delete/read-by-reference API and tests; avoid exposing keys to reader content |
| N03 | Open | Decide iCloud devices/content/backend; create PDFno-owned identity and permissions only with explicit approval |
| N04 | Open | Evaluate packaging the native bridge with the main Electron application; version negotiation and failure handling |
| N05 | Open | Signing/notarisation, own identity and clean-install/recovery tests; no upstream signing identity |

The Electron UI queries only capabilities. N00/N01 do not mean Keychain or iCloud is integrated. There is no dummy SwiftUI wrapper, certificate request, provisioning update or persistent token setup. The executable lives only under ignored build output. A future in-process/XPC implementation remains an architecture decision.
