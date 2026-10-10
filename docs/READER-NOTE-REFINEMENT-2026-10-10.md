# Reader and annotation refinement · 2026-10-10

Based on `9ca8564`, on `feature/mac-ai-bookmarks-20261010`.

The professional reader keeps the directory search field and submission behavior, but removes the duplicate Search tab. The directory uses the same semantic surface as the right rail, with the native list background hidden. Directory, notes, AI and bookmarks share the directory's 210-point width; compact overlays remain bounded by available width.

The native titlebar document band moves Home closer to the traffic lights. Its leading inset follows the actual button frames with at least 12 points of clearance. Existing native toolbar ownership, control hit testing, empty-space window drag and double-click behavior remain intact.

The annotation editor is a plain, borderless writable body with Cancel and Done beside each other at the bottom. The editor title and duplicated quoted-source plate are removed. Existing AI results remain immutable and visible for AI notes; anchors and exact navigation remain attached to records. Cancel discards changes made during this editing session, preserves a resumed draft and other drafts, and creates no empty new record. Done uses the existing generation/CAS and draft-journal write fences.

Validation: 60 tests in 9 affected offline suites passed (`SWIFT-UI-REFINEMENT-02`), including seven new tests covering cancellation, explicit saving and reopening, resumed/other drafts, uniform inspector sizing, the native editor's save fence, both appearance modes in hidden narrow hosts, and the titlebar button gap. One stale layout expectation was corrected to reflect the already-established single-inspector professional layout. No original four UI suites or native input factory were modified. Full 12/68/603 and CI remain paused.

The two supplied reference images were resolved by Library identity and metadata. Pixel materialization failed before transfer because the available Python runtime could not parse the helper's union type annotation. No Library helper, runtime or dependency was changed; implementation follows the five explicit requirements and the parent-reported reference descriptions. Do not claim pixel-level reference matching.

The sole preview entry remains `.build/HomeSettingsRedesign/2026-10-09/OPEN-LATEST-UI-IN-XCODE.command`, workspace **PDFnoLatestUI**, scheme **PDFno Latest UI (Offline)**, destination **My Mac**. The refreshed preview uses a fresh bundle, runtime UUID, registry and build cache, retains offline transport/Keychain refusal and original fixtures, and preserves the previous preview checkpoint and Xcode user metadata. Build and foreground acceptance evidence are recorded under `.build/UIRefinement/2026-10-10/Evidence/`.
