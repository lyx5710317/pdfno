# Contributing to PDFno

PDFno source and original fixtures are AGPL-3.0-or-later. Keep SPDX and provenance notices when changing files. Read the v0.3 native specification and current task/validation records before implementation. Preserve all approved PDF/EPUB/comic/language-learning/sync/conversion goals while marking actual capability honestly.

Use the real `apple/PDFno.xcworkspace` targets and shared Swift package. The Domain target must not import UI frameworks; PDFKit objects stay on the main actor. Add a dependency only after source, license, transitive assets and actual native Mac/iPhone/iPad support have been audited. Readium's iOS platform declaration alone does not establish native macOS support.

Use self-authored or redistributable fixtures, isolated temporary stores and no private books, account identifiers, keys or signing profiles in source/CI artifacts. Do not configure team, cloud containers, entitlements or distribution without the user's explicit scope. Ad hoc local signing is for development, not release.

Run the README checks for the changed behavior. Extend meaningful PDF/anchor/storage tests when needed; report real-device, VoiceOver and failure-recovery gaps. Keep generated Xcode project/schemes/sample PDFs consistent with `scripts/generate-apple-project.py`. Current runtime has no Node/Electron dependency; historical npm inventory and Git commits are recovery/reference evidence only.

Never silently overwrite corrupt/future-version stores or migrate legacy demo fingerprints into native PDF coordinates. Review any data migration separately, with backup, preview, idempotence and rollback evidence.
