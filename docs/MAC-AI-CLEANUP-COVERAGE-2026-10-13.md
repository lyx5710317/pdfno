# Mac AI cleanup and current coverage, 2026-10-13


**Latest accepted directed result:** the unchanged current App/PID68526 passed the real API case on2026-10-13. Explanation and follow-up produced2 HTTP200 responses; full-document dialogue produced1 HTTP200 response only after confirmation. One explicit note was saved; follow-up/full-document responses did not auto-save. Full-document open/Start/cancel each had0 dispatches. Official1 method executed,1 passed,0 failed,0 skipped. Desk released15:56:40 UTC /23:56:40 Asia/Shanghai. This supplements the separate2/2 offline repair result and does not establish all73/global acceptance. Earlier blocked/failed rounds below remain historical evidence.

This ledger separates source migration from executed behavior. It does not establish all73 acceptance. Cleanup commit `3bfd3db` is already uploaded; current repairs are uploaded as main implementation commit `d0575b2`, based on `40bfbcb`. Original failed results are preserved.

## Deleted independent ownership

Deleted files:
- `apple/Packages/PDFnoKit/Sources/PDFnoServices/BYOKProviderSession.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoUI/BYOKLearningWorkspace.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoUI/BYOKSettingsModel.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoUI/BYOKSettingsView.swift`
- `apple/Packages/PDFnoKit/Sources/PDFnoUI/LibraryModel+BYOK.swift`

Renamed finite-provider files retain shared HTTPS/wire/security behavior:
- `R095	apple/Packages/PDFnoKit/Sources/PDFnoDomain/BYOKProviderContracts.swift	apple/Packages/PDFnoKit/Sources/PDFnoDomain/ConfiguredAPIProviderContracts.swift`
- `R071	apple/Packages/PDFnoKit/Tests/PDFnoKitTests/BYOKProviderTests.swift	apple/Packages/PDFnoKit/Tests/PDFnoKitTests/ConfiguredAPIProviderTests.swift`

Removed the independent editable settings/session/configuration/draft/source/result/save owners and nested routing. Shared `ConfiguredAPIProviderContracts`, `ConfiguredAPISelectionProvider`, central configuration and per-document conversations remain. `LegacyAIConnectionMigration` is an immutable capsule without editable-settings or HTTP interfaces. Existing Keychain service identity and persisted source/note/configuration schemas remain for migration. No user data or Key was read, copied or deleted.

This repair removes five unreachable document-more actions and their dispatchers, plus never-set `AISettingsView.showTools` state/sheet/subpage. Actual public page/spine translation and Japanese/English review entries remain. Selection and full-document conversations remain distinct with one shared configuration owner. Fixed DeepSeek diagnostics and configurable probes have distinct responsibilities.

Thirteen independent-owner Swift methods were retired with explicit replacements;14 existing finite-provider tests retain their safety assertions, and11 shared-connection/migration/document contracts were added. Earlier701-pass evidence applies to the cleanup source, not an unperformed complete repair rerun. This repair extends existing tests. Historical700/591/109 and GUI73/55/18 sets stay unchanged; exclusions never count as passes.

## Original CI13 failures

| Method | Source change | Actual GUI evidence |
| --- | --- | --- |
| `NativeUITests/testMacAISelectionConsentMockNotesAndRestart` | Current route/body migrated | Compiled only; not rerun end to end |
| `NativeUITests/testMacLearningBodyEditingPreservesResultRestartAndSource` | Current route/body migrated | Compiled only; not rerun end to end |
| `ProfessionalReaderUITests/testARegularDarkLearningPanelConsentDraftAndManualSave` | Current route/body migrated | Compiled only; not rerun end to end |
| `ProfessionalReaderUITests/testShellNarrowLightPDFPageAndHelpToolsRoutes` | Current route/body migrated | Compiled only; not rerun end to end |
| `ProfessionalReaderUITests/testShellRegularDarkAIResultAndUncommittedDraftSurviveLibrary` | Current route/body migrated | Compiled only; not rerun end to end |
| `ReadingIntegrationUITests/testMacEPUBTOCAndCanonicalReturnUseActualRuntime` | Current route/body migrated | Compiled only; not rerun end to end |
| `ReadingIntegrationUITests/testMacToolsRouteRequiresConsentAndManualSave` | Current route/body migrated | Compiled only; not rerun end to end |
| `NativeUITests/testMacEditedNoteSearchDraftExclusionCoverLayoutsAndExactSource` | Original source/focus assertions preserved; current routing/save ownership adapted where needed | PASS on `QA-ViewportRepair` (earlier directed product) |
| `NativeUITests/testMacLibrarySearchUserNoteSavedLocalMockAIAndExactSource` | Original source/focus assertions preserved; current routing/save ownership adapted where needed | PASS on `QA-ViewportRepair` (earlier directed product) |
| `ProfessionalReaderUITests/testARegularLightPanelsRestoreReadingArea` | Original source/focus assertions preserved; current routing/save ownership adapted where needed | PASS on `QA-CurrentRoutes` (earlier directed product) |
| `ReaderChromeUITests/testWideHeaderlessPanelsRetainEditorAndAIAndFollowingAdd` | Current control/heading contract migrated | Compiled only; not rerun end to end |
| `ReaderConversationUITests/testNarrowIndependentSettingsDefaultOffAndRetainedDisabledConversation` | Current control/heading contract migrated | PASS on `QA-PinRepair` (latest exact offline candidate) |
| `ReaderConversationUITests/testWideConnectionFiveTasksDialogueStopRetryFollowupAndExplicitNotes` | Current control/heading contract migrated | Compiled only; not rerun end to end |

## Original local18 failures

`CURRENT-AI18-01.xcresult` on `3bfd3db` executed18:0 pass,18 fail,0 skip. This executed supplement is distinct from the frozen18 excluded GUI identities. Failures remain historical failed results.

| Method | Current migration / coverage |
| --- | --- |
| `NativeUITests/testMacConfiguredAPIExplicitRecipientManualSaveAndSharedTranslation` | Current shared configuration/selection method migrated; offline fake-credential GUI pass on QA-CurrentRoutes; named-product GUI proof exists |
| `NativeUITests/testMacDeepSeekSelectionOfflineTransportPDFEPUBAndRestart` | Not fully migrated: uiLegacyAI still requires retired reading-tools; PDF/EPUB transport/restart method unaccepted; not accepted |
| `NativeUITests/testMacEPUBChapterCancelStopsRemainderAndReopenCannotRetryOrRestoreKey` | Shared page/spine menu and configuration helpers migrated; full batch bounds/cancel/partial/save/restart method unexecuted; any later legacy-AI return remains unresolved; not accepted |
| `NativeUITests/testMacEPUBChapterCompleteScopeConsentBilingualManualSaveRestartAndSourceReturn` | Shared page/spine menu and configuration helpers migrated; full batch bounds/cancel/partial/save/restart method unexecuted; any later legacy-AI return remains unresolved; not accepted |
| `NativeUITests/testMacEPUBChapterOversizeRefusesWholeDocumentWithoutKeyOrSend` | Shared page/spine menu and configuration helpers migrated; full batch bounds/cancel/partial/save/restart method unexecuted; any later legacy-AI return remains unresolved; not accepted |
| `NativeUITests/testMacEPUBChapterPartialFailureKeepsFirstSegmentAndStopsAllRemaining` | Shared page/spine menu and configuration helpers migrated; full batch bounds/cancel/partial/save/restart method unexecuted; any later legacy-AI return remains unresolved; not accepted |
| `NativeUITests/testMacJapaneseInvalidOutputAndCancelCannotCreateNotesOrLateReview` | Shared language locator/card accessibility migrated; dedicated structured review/body/search/restart method unexecuted after migration; not accepted |
| `NativeUITests/testMacJapaneseNativeEPUBSelectionManualSaveAndSourceReturnPreservesRuby` | Shared language locator/card accessibility migrated; dedicated structured review/body/search/restart method unexecuted after migration; not accepted |
| `NativeUITests/testMacJapaneseOfflineConsentComponentSwitchManualSaveRestartExactPDFReturn` | Shared language locator/card accessibility migrated; dedicated structured review/body/search/restart method unexecuted after migration; not accepted |
| `NativeUITests/testMacJapaneseSavedBodyEditingSearchKeepsReviewAndCorrections` | Shared language locator/card accessibility migrated; dedicated structured review/body/search/restart method unexecuted after migration; not accepted |
| `NativeUITests/testMacPDFPageCancelStopsRemainderAndReopenKeepsAttemptCount` | Shared page/spine menu and configuration helpers migrated; full batch bounds/cancel/partial/save/restart method unexecuted; any later legacy-AI return remains unresolved; not accepted |
| `NativeUITests/testMacPDFPageScanAndOversizeRefuseWithoutSend` | Shared page/spine menu and configuration helpers migrated; full batch bounds/cancel/partial/save/restart method unexecuted; any later legacy-AI return remains unresolved; not accepted |
| `NativeUITests/testMacPDFWholePageOfflineConsentBilingualNotesAndSourceReturn` | Shared page/spine menu and configuration helpers migrated; full batch bounds/cancel/partial/save/restart method unexecuted; any later legacy-AI return remains unresolved; not accepted |
| `NextBatchUITests/testEnglishManualConsentSaveSearchAndRestartKeepsSourceAndNoKey` | Shared language locator/card accessibility migrated; dedicated structured review/body/search/restart method unexecuted after migration; not accepted |
| `ReadingIntegrationUITests/testMacParagraphCancelDoesNotPublishOrSave` | Not migrated: still requires the retired typed paragraph tools entry; typed evidence, consent, invalid response, cancellation and source GUI assertions remain unaccepted; not accepted |
| `ReadingIntegrationUITests/testMacParagraphEPUBCitationReturnsToCanonicalRange` | Not migrated: still requires the retired typed paragraph tools entry; typed evidence, consent, invalid response, cancellation and source GUI assertions remain unaccepted; not accepted |
| `ReadingIntegrationUITests/testMacParagraphInsufficientAndInvalidResponsesCannotSave` | Not migrated: still requires the retired typed paragraph tools entry; typed evidence, consent, invalid response, cancellation and source GUI assertions remain unaccepted; not accepted |
| `ReadingIntegrationUITests/testMacParagraphTypedEvidenceConsentManualSaveAndSource` | Not migrated: still requires the retired typed paragraph tools entry; typed evidence, consent, invalid response, cancellation and source GUI assertions remain unaccepted; not accepted |

The original EPUB restart/source-return failure, outside these13/18, and the narrow retained-disabled-dialogue case both passed on latest `QA-PinRepair`:2 executed,2 passed,0 failed,0 skipped,0 expected failures. Desk release13:55:14 UTC /21:55:14 Asia/Shanghai. Three PDF methods and the configured shared fake-credential method passed on earlier named directed products. Their counts cannot be combined into latest-product/all73 acceptance.

Current background proof is3 hidden WebKit methods plus1 existing five-task/disable/save/resume method. Seven retired-route cases, wide dialogue, headerless chrome, dedicated structured language methods, complete batch scenarios and typed-paragraph GUI remain unexecuted on the final candidate.

## Current live API blocker

The unique current target is bundle `org.pdfno.integration.professionala20261007.qaMacFourLive20261013.PinRepair.PDFnoMac`, PID68526, window8753, Dock name **PDFno · 当前修复API验证**. Normal window, public DeepSeek endpoint/model and production input hashes were verified. Its QA startup host explicitly creates an NSWindow containing the unchanged complete product `LibraryWorkspace`; it provides no source selections, answers or save actions. Empty startup attempts ended before the user Key report; PID68526 has not restarted since.

User reported applied Key, but current public status remains “填写后点击应用连接” and “尚未测试连接”. Preflight stopped before GUI method or HTTP dispatch. Requests0, responses0, no live API assertion accepted; cause remains unproved. Secure values and other Apps configuration were not read. No Key transfer or repeated Key-entry request was made. One authorized initial activation stopped after front changed, with no reactivation. Formal release14:44:02 UTC /22:44:02 Asia/Shanghai; the release notice was delayed after preflight stopped. Same process stays open for public-state clarification.

Local evidence: `.build/MacGlobal/2026-10-13/CURRENT-FAILURE-MIGRATION-COVERAGE.json`, `TWO-GUI-OUTCOME.json`, per-round official verification, and `CurrentRepair/LiveAPI/PRECHECK-01.json`. Main upload status is reported separately. No App publication or iOS validation is implied.

The current main repair upload uses `[skip ci]` to obey the current no-full-regression instruction. Workflow files and frozen scopes stay unchanged. CI skipped is not accepted or counted as pass. [GitHub skip rule](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs).


## Final real-window verification

`LIVE-03.xcresult` records1 failed/0 passed/0 skipped before business interaction: the QA input interceptor was installed before the existing App initial activation. It sent0 requests. Release14:58:02 UTC /22:58:02 Asia/Shanghai. The QA preparation now installs the interceptor only after the original authorized activation and exact-window `ownDesktop()` admission; all subsequent input guards and original assertions remain. Only the Runner was recompiled and signed. Every App file hash and PID68526 remained unchanged; all73 symbols verified. No App/Key restart or transfer occurred.

`LIVE-04.xcresult` then reached the actual foreground window and read its public status. The original “已配置” assertion failed after15.827 seconds: “填写后点击应用连接；所有 AI 功能共用此配置。” and “尚未测试连接”. Official count1 executed,0 passed,1 failed,0 skipped. Requests0, responses0; explanation/follow-up/save/full-document assertions never executed. Desk released15:06:44 UTC /23:06:44 Asia/Shanghai. The earlier background-state ambiguity is now corroborated by the real foreground UI. User reported configured, but cause of that discrepancy remains unproved. No further automatic retry or repeated Key-entry question is pending. Same App remains open. Real API acceptance stays blocked until this exact window actually applies its configuration.

Authoritative compact record: `.build/MacGlobal/2026-10-13/CurrentRepair/LiveAPI/REAL-API-OUTCOME.json`; official result exports and original failure evidence remain local. This failure does not invalidate the separately accepted2/2 offline repair result, nor establish all73/global acceptance.


## Real API completion on the same current process

The user clarified at15:27 UTC that configuration had not yet been entered, so the earlier unconfigured readings and0 requests were expected. The contradiction diagnosis stopped; no configuration-code change was made from that hypothesis. The user subsequently configured the existing window. Read-only checks found “本次会话已配置 API Key” and “连接成功 · 已验证本次模型与返回格式”, correct DeepSeek URL/model, PID68526 and one normal window. No App restart or Key read/transfer/re-entry request occurred.

The user explicitly permitted only our original samples to be sent to configured `api.deepseek.com` and provided the current desktop handoff at15:54 UTC. `LIVE-05.xcresult` then passed `MacFourLiveUITests/testFinalFourUIRealSelectionAndFullDocumentConsent()` in45.998 seconds. Exact official method, original assertions, compiled product hashes and0 skips were verified. Scenario requests:2 selected-text requests plus1 confirmed whole-document request; responses200/200/200. This count covers the directed reading scenario and excludes any earlier user-operated connection probe. No artificial QA request ceiling or backend cost settings were imposed.

The original “window” quote, saved AI result, empty independent user body, noncached response, explicit1-note commit, same-source follow-up and no automatic save assertions passed. Settings kept the shared connection across AI/tools categories. Full-document panel open and Start/cancel sent nothing; confirmation sent the original2-page sample and accepted the actual response. No private books/notes were used.

The App remained the same process with unchanged executable/debug-library hashes; only the previously repaired Runner was used. No global or offline GUI rerun occurred. Desk release receipt is `CurrentRepair/LiveAPI/LIVE-05-EXECUTION.json`; exact official summary/tests and `REAL-API-OUTCOME-SUCCESS.json` are retained locally. Earlier failure evidence is not overwritten. Current original13/18 method coverage remains as individually listed: this additional live method is not substituted for unexecuted batch, typed-paragraph, language or wider regression methods.
