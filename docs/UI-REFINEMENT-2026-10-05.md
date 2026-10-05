# Mac UI refinement — local slice

Base: `7bea8ec89ea7273b3b52ee714fbf1180b3d51c73`. Branch: `feature/ui-refinement-20261005`. All work is confined to the assigned temporary worktree. This slice does not publish, push, merge or launch the user's app.

## Implemented

- Existing PDFno tokens now supply shared empty/status messages, bounded selectable text viewports, cards and action rows that switch to a vertical arrangement when their labels do not fit. Status messages use an icon or real busy indicator plus text; they do not invent progress or task events. Semantic system colors preserve the existing accent and follow light/dark appearance. The original Japanese role palette and projection are unchanged. Mac controls remain at least 30 pt; shared styles use 44 pt minimum height on iOS.
- The library loading surface, PDF navigation/search empty states and PDF/EPUB note selection surfaces adopt these components. Nonempty new-note drafts are explicitly marked unsaved; their bindings and clear-on-success save calls are preserved. Reader, PDF document, captured selection, source-return checks, repositories and schemas are unchanged. Existing library cover/grid/list presentation remains on its established tokens.
- The PDF/EPUB learning entry row adapts to available width. EPUB keeps its existing directory/note sheets and original canvas/session; footer metadata now has its own line. Its loading, empty, error and selected-source surfaces use the shared tokens. This slice does **not** introduce a docked EPUB reader shell.
- Selection AI and BYOK source/result text can scroll independently without truncating or replacing the exact displayed text. Request status, errors, missing source/history/notes, consent and credential requirements remain visible. Selection AI distinguishes an existing saved note from subsequently changed, unsaved user text and directs editing to the existing saved-note editor. All send/consent/cancel/save calls and current source validation remain intact.
- Settings are grouped into service/model, temporary credential, and scope/status sections. AI/BYOK/Japanese/translation sheets have a 360 pt minimum width instead of 440–520 pt; existing height requirements remain. PDF-page and EPUB-spine translation keep their existing finite-width two-column/stacked branch, bounded source/result scrolling, segment bindings, retained batches, source return and explicit save semantics. Only the presentation of Japanese learning changes.

No dependencies, fonts, private images/icons, engine assets, original fixtures, model/provider/reader code, persistent schema, credentials, app menus, Xcode project/generator, signing/CloudKit configuration, CI workflow or frozen ledger changed. The UPDF research report informed information organization only. No unseen Figma or Bookno design is claimed as reproduced.

## Validation

Toolchain: Xcode 27.0 (`27A266a`), Apple Swift 6.4, local arm64 Mac. Heavy checks use the shared `run-heavy-check.py` lock, two jobs and worktree-specific scratch/cache/DerivedData. Test stores are fresh UUID directories. The new tests render original content in NSHostingView/NSWindow instances that are **never ordered on screen**; no desktop screenshot or XCTest UI run occurs.

Evidence directory: `.build/UIRefinementEvidence/` in this worktree. Build/test products and images are not committed.

- `swift-final.log`: final selected test result is recorded in the receipt below.
- `mac-build.log` / `mobile-build.log`: final build-for-testing results are recorded below; UI test execution is not implied.
- `components-light.png` / `components-dark.png`: original 320 pt components, inspected visually for empty/busy/cancelled/save-failed/saved states, multilingual Unicode wrapping and narrow action arrangement. These are component renders, not full-app screenshots or contrast/VoiceOver certification.
- `UIRefinementTests.swift`: three new methods exercise narrow light/dark components, actual PDFView/document/session/anchor/source/result/draft continuity at 1100/880/440/1100 pt, and the actual selection-learning surface at 360/760 pt with long original Unicode text. Its fully intercepted transport records zero sends; presentation does not save records.
- Existing foundation, PDF reader/quote, library, cover, selection-AI, page/chapter translation and saved-note editing tests remain in the selected regression set. Two existing EPUB WebKit methods check original ruby/source/reflow and long-paragraph exact navigation/reopen behavior. These functional tests are not the blocked independent security audit.

Selected test command (run from this worktree):

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/UIRefinementCaches/clang" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/UIRefinementCaches/clang" \
PDFNO_UI_REFINEMENT_PREVIEW="$PWD/.build/UIRefinementEvidence" \
python3 ../run-heavy-check.py -- swift test \
  --package-path apple/Packages/PDFnoKit \
  --scratch-path .build/UIRefinementSwift \
  --cache-path .build/UIRefinementCaches/SwiftPM --jobs 2 --no-parallel \
  --filter 'UIRefinementTests|UIFoundationTests|PDFReaderTests|PDFQuoteConsistencyTests|LibraryIntegrationTests|CoverTests|DeepSeekSelectionTests|PDFPageTranslationTests|EPUBChapterTranslationTests|NoteEditingTests|EPUBWebKitTests/sourceRubyReflowAndStaleRequests|EPUBWebKitTests/longParagraphSecondAndThirdPagesRestoreExactVisibleOffsetsAndReopen'
python3 scripts/check-native-source.py
git diff --check
python3 ../run-heavy-check.py -- xcodebuild \
  -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug \
  -destination 'platform=macOS,arch=arm64' -derivedDataPath .build/UIRefinementMac \
  -jobs 2 CODE_SIGNING_ALLOWED=NO build-for-testing
python3 ../run-heavy-check.py -- xcodebuild \
  -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/UIRefinementMobile \
  -jobs 2 CODE_SIGNING_ALLOWED=NO build-for-testing
```

The original `NativeUITests.swift` (46 methods) and `EbookFormatUITests.swift` (4 methods) remain byte-for-byte identical to the base, including assertions and timeouts. Their SHA-256 values are respectively `1d22a88e17984f4123fe9728e4a978cf24d8d242737b192c40e5f073bebf16c6` and `4d50ab3983c6df07fe03c296648c1bc6cc0ad497fa7ede759742988d9117c233`. A comparison of identifier literals in changed production views found no removed existing identifiers; moved text identifiers remain on the actual Text inside their components.

Initial Swift invocation was blocked when the compiler attempted its default user cache. The authorised rerun used isolated build caches and the required sandbox escalation. The first compilation then found an invalid nested projected test binding through a let model property; the test fixture now uses an explicit getter/setter binding. No original assertion or production acceptance rule was relaxed.

Final receipt: **78 selected Swift tests / 11 suites PASSED** (5.953 seconds of test execution), including all three new methods. **Mac arm64 build-for-testing PASSED** and **iOS Simulator arm64 + x86_64 build-for-testing PASSED**, both reporting `TEST BUILD SUCCEEDED`. The original 50 UI methods were compiled and remain unchanged; they were **not executed**. Source guard passed **613 source files**; `git diff --check` passed. `retention.json` records the unchanged UI test hashes and zero removed identifiers across all ten changed production view files. Final raw log names and exact commands are above; local generated evidence is retained in `.build/UIRefinementEvidence/`. The new code introduces no compiler error; existing native-codec precision warnings remain in clean builds.

## Integration contacts and limits

Changed production files are the ten existing view/token files named by this task. New components are internal to `PDFnoUI`; the English slice can use them after integration into that target. There is no new public API or persistent contract. New deletion/recovery/English entrypoints, shared host wiring and any new UI acceptance cases remain owned by integration. Keep all original 50 UI methods unchanged.

**EPUB selection on resize remains a pre-existing reader limitation.** `EPUBReaderSession.request` clears `selection` on every state response (currently around line 134), and `EPUBContainer.setFrameSize` schedules a `resize` command (around line 264). A docked pane would introduce extra resize events. The UI-only slice therefore preserves the existing sheets rather than add this regression. An integration/reader follow-up must explicitly define capture/restore of an immutable selection on reflow, fence it to the same session/document version and verify it with real WKWebView selection, frozen AI source, note draft and no extra sends. Do not restore an old anchor into another spine/document or change source-return semantics to a first-match guess. The selected EPUB tests validate the current engine behavior; they do not certify selection persistence across all window resizes.

Actual full-app GUI interaction, all 50 UI runtime tests, keyboard/focus return, Escape routing, VoiceOver, increased contrast, reduced motion, long URLs and custom accent contrast, all sheet/control combinations at minimum size, Intel runtime and physical iPhone/iPad remain **NOT VERIFIED locally**. Final GUI regression belongs to an isolated integration environment. Mobile builds verify compilation and preserve the existing PDF scope; they do not deliver mobile EPUB or a full mobile redesign. AI runtime behavior retains its existing modal-sheet lifecycle; this slice does not add a persistent AI sidebar, background tasks, document tabs or multi-window architecture.

Independent security remains **UNVERIFIED / platform-blocked**; no rejected audit or quota-blocked Figma tool was retried. The slice is reversible as one local commit; no persisted data migration is needed.
