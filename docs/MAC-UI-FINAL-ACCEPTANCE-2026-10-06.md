# Mac UI 最终本地验收 · 2026-10-06

**完整60项实测通过：60 PASS／0 FAIL／0 SKIP，退出0。** 产品代码候选`b6181c49f8a8a4bc7c7fa4d15496136b14151e10`，原56和新增段落4均全部通过。最终启动器一次完整命令，每方法只开始一次；正式xcresult摘要、方法树与实际日志一致。命令墙钟2831.148秒。

这是专用隔离App中的XCTest实际鼠标、键盘、原生文件面板和WebKit运行结果；不是人工体验或VoiceOver验收。没有push、远程CI dispatch、merge或发布。此前33/27、56/4、59/1的完整结果和失败候选全部保留。

## 当前验证

| 检查 | 实际结果 | 证据文件 |
| --- | --- | --- |
| 当前产品全Swift | 552项／70套件PASS，41.214秒 | `settled-input-full-swift-command.json`／`.log` |
| 相关Swift | 50项／5套件PASS；产品包之后未改 | `remaining-search-recovery-related-swift-admitted-command.json` |
| 全部六份Node | 单次25/25 PASS；引擎和资源之后未改，不重复安装／测试 | `approved-all-node-tests-command.json`、`accepted60-node-validity.json` |
| 产品Mac编译 | arm64+x86_64 build-for-testing PASS；App、runner、tests实际lipo均为两架构 | `settled-input-build-command.json`、`settled-input-plan.json` |
| 最终启动器编译／UI | arm64专用编译PASS、实际完整60/0/0 PASS；x86_64 UI未运行 | `clean60-build-command.json`、`clean60-outcome.json`、`Clean60Once.xcresult` |
| 恢复服务定位 | 失败自制库副本上的真实服务1/1 PASS；不计入全Swift552 | `recovery-metadata-forensic-swift-command.json`、`recovery-metadata-confirmed-cause.json` |
| 最终精确进程／锁 | 拥有PID均不存在，heavy lock空闲；main和历史产品／19截图保全 | `clean60-post-run-protection.json` |

最终bundle：`org.pdfno.integration.cleansixty20261006.PDFnoMac`。原方法自行生成UUID，启动器在Scene创建前校验bundle、UUID、offline及允许范围。实际记录98个App PID、64个session；共享锁覆盖完整命令，无过滤／跳过／自动失败重试。60个方法正文与上一完整轮逐字节相同，原702个断言保留，新增真实字段与输入指示层稳定确认，共703个断言调用。

## 本轮四项修复与定位

`82231ee`把回收站操作的accessibilityIdentifier从HStack移到真实Button，并在两个字面输入框关闭自动纠正。后者是局部输入行为修正，不能解释InputSource弹层；首次草稿方法仍失败。SwiftUI控件的公开行为见[Apple autocorrectionDisabled文档](https://developer.apple.com/documentation/swiftui/view/autocorrectiondisabled(_:))。

`b6181c4`仅在搜索框和整章笔记的粘贴辅助步骤中核对真实字段值，并等待具名InputSource指示层自然消退后再点击／滚动。未发送Escape、处理权限弹窗或改变系统输入法。实际旧日志捕获InputSource按钮；三项原失败方法在局部及最终完整套件中均通过。操作系统内部根因仍未确认，不能把修复归因于系统权限。

回收站在四项局部测试通过后，旧完整启动器仍失败。该启动器把owned-process记录写入Library根；恢复清单故意拒绝未知文件。对原失败自制书库的副本调用真实LocalRecoveryService，先明确得到unsupportedStore("owned-process-61663.json")；仅将该文件移到副本Library外，原书籍立即可列出，原件字节不变。原失败库的manifest／metadata SHA保留。

最终启动器将进程记录放在Library外的独立scope目录；没有放宽恢复白名单、备份校验或事务保护。未改原回收站方法在此启动器单次完整PASS，42.393秒，然后才派发最终完整60。这是有证据的启动器修正，旧59/1结果仍为实际失败。

| 四项原方法 | 局部完整方法秒数／PASS | 最终完整60秒数／PASS |
| --- | --- | --- |
| `NativeUITests/testMacEditedNoteSearchDraftExclusionCoverLayoutsAndExactSource` | 75.688 | 74.521 |
| `NativeUITests/testMacEPUBChapterCompleteScopeConsentBilingualManualSaveRestartAndSourceReturn` | 44.851 | 45.348 |
| `NextBatchUITests/testTrashConfirmationRestoreAndRestartPreserveOriginalBook` | 45.741 | 45.515 |
| `NativeUITests/testMacLibrarySearchMetadataUnicodeEmptyNoResultsAndRestart` | 53.473 | 51.378 |

保留`b4c2b87` EPUB同词重选／导航命中修复，`024703e`原生日文只读可选来源，`f5fa172`组件／转换状态身份和原生面板父行双击，以及`50cfa34`阅读版PDF状态身份。段落源`0950727f8c1f1b8a3cb70905365d292f08e4b079`已整合为`ef203f3229596d9c2c800e68de2e7b66987173ba`；旧plain记录、精确Unicode来源、DOM／事务fence、草稿、3／6预算与零自动重试保持。

## 正式结果中的运行时警告

正式方法树还记录15项Runtime Warning。方法结果均PASS；警告的内部根因尚未定位，保留给后续全仓审计。没有为消除警告重跑GUI或改系统。

| 实际方法 | 记录的警告 |
| --- | --- |
| `NativeUITests/testMacBooknoExplicitOfflinePreviewSavedBodyMockReplayAndClose` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacDOCXConversionFailureRecoveryAndEscapedHTML` | Publishing changes from within view updates is not allowed, this will cause undefined behavior. |
| `NativeUITests/testMacDOCXImportSemanticSelectionNotesAndRestart` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacEditedNoteSearchDraftExclusionCoverLayoutsAndExactSource` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacEPUBSelectionRubyNotesAndRestart` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacHTMLAliasImportSelectionNotesNavigationAndRestart` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacJapaneseNativeEPUBSelectionManualSaveAndSourceReturnPreservesRuby` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacMarkdownImportSelectionNotesNavigationAndRestart` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacMHTMLImportSelectionNotesNavigationAndRestart` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacPDFBodyEditingCancelDraftRestartEmptyAndSource` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacReadableXMLImportSelectionNotesNavigationAndRestart` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacSavedMOBIBodyDraftRestartUnifiedSearchAndExactSource` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacSavedTextBodyDraftRestartUnifiedSearchAndExactSource` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacTXTImportSelectionNotesNavigationAndRestart` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |
| `NativeUITests/testMacXHTMLImportSelectionNotesNavigationAndRestart` | [Internal] Thread running at User-interactive quality-of-service class waiting on a lower QoS thread running at Default quality-of-service class. Investigate ways to avoid priority inversions |

## 截图和未验收边界

19张原自制fixture截图在证据目录`screenshots/`，路径及SHA见`FINAL-RECEIPT.json`。实际JPEG、旧扩展名png；没有改像素／改名，也没有把历史图称为最终启动器新截图。没有有效library_file_id。当前官方Library helper需要Python3.10，宿主仅3.9.6，bundled runtime工具未给替代路径；没有新增Python环境或新上传API。

[Library SKILL.md](skill://plugin_connector_1p_1b8ff8edfc1481918b252c8277e23125/library/SKILL.md)要求多文件且prepared工具可用时：“Use the bundled prepared-upload helper below.”；因此没有手工prepare／finalize或降级直接create。证据`library-current-compatibility-block.json`。

真实API／模型schema成功率及解释质量、人工VoiceOver、当前iOS编译／移动UI、安全专项仍未验收或后置。先前iOS动作因mobile明确后置被自动审批拒绝，未执行／未重试；安全UNVERIFIED／platform-blocked未重试。Bookno联网／iCloud／mobile／MCP未新增。未改变系统主题、输入法、TCC、安全权限或服务；现有用户App未关闭或替换。

早期默认Library启动偏差仍UNKNOWN；CUA超时参数未被遵守、迟到启动跨越锁窗口的历史边界仍UNVERIFIED。最新守卫和通过结果不能抹去这些历史；旧报告／收据保留。所有后续XCTest命令均持共享锁。

## 单一整合交接

持久tree：`.build/MacUIExperience/2026-10-06/tree`；branch：`feature/mac-ui-experience-20261006`。证据：`.build/MacUIExperience/2026-10-06/evidence`。main仍`6a67d1fd883f79737d0e3e12c756b683a662f230`，未跟踪Xcode workspace metadata保全。最终docs提交只更新报告，产品候选仍上述完整SHA。没有公开发布动作。验收后的全仓审计前提已满足；本任务未执行全仓审计，不能把UI通过称为审计通过。

收据`FINAL-RECEIPT.json`保留所有历史边界；旧56/4收据为`FINAL-RECEIPT-9981501-full60-four-failures.json`。具体60方法如下。

| 实际方法 | 结果 | 秒数 |
| --- | --- | --- |
| `EbookFormatUITests/testAZW3SelectionNoteProgressRestart` | Passed | 32.958 |
| `EbookFormatUITests/testAZWSelectionNoteProgressRestart` | Passed | 32.576 |
| `EbookFormatUITests/testFB2SelectionNoteProgressRestart` | Passed | 32.514 |
| `EbookFormatUITests/testMOBISelectionNoteProgressRestart` | Passed | 32.863 |
| `NativeUITests/testLocalPDFReadingAndNoteFlow` | Passed | 24.141 |
| `NativeUITests/testMacAISelectionConsentMockNotesAndRestart` | Passed | 50.450 |
| `NativeUITests/testMacBooknoExplicitOfflinePreviewSavedBodyMockReplayAndClose` | Passed | 53.456 |
| `NativeUITests/testMacBYOKExplicitRecipientManualSaveAndDefaultChainsStaySeparate` | Passed | 52.902 |
| `NativeUITests/testMacCB7ImportSpreadsDirectionPageJumpAndRestart` | Passed | 71.619 |
| `NativeUITests/testMacCBRImportSpreadsDirectionPageJumpAndRestart` | Passed | 75.912 |
| `NativeUITests/testMacCBTImportSpreadsDirectionPageJumpAndRestart` | Passed | 70.752 |
| `NativeUITests/testMacCBZImportSpreadsDirectionPageJumpAndRestart` | Passed | 71.108 |
| `NativeUITests/testMacCoverSelectionGridListRestartAndRestore` | Passed | 38.308 |
| `NativeUITests/testMacDeepSeekSelectionOfflineTransportPDFEPUBAndRestart` | Passed | 57.060 |
| `NativeUITests/testMacDOCXConversionFailureRecoveryAndEscapedHTML` | Passed | 57.382 |
| `NativeUITests/testMacDOCXConversionSavePanelCancelAndOverwriteRefusal` | Passed | 50.174 |
| `NativeUITests/testMacDOCXConversionWorkerCancellationLeavesNoOutput` | Passed | 37.853 |
| `NativeUITests/testMacDOCXDefaultCoverInListGridAndRestart` | Passed | 10.748 |
| `NativeUITests/testMacDOCXFailureRecoveryAndPDFEPUBTransitions` | Passed | 46.221 |
| `NativeUITests/testMacDOCXImportSemanticSelectionNotesAndRestart` | Passed | 48.226 |
| `NativeUITests/testMacDOCXReadingPDFEntryCancelExportAndOverwriteRefusal` | Passed | 51.457 |
| `NativeUITests/testMacEditedNoteSearchDraftExclusionCoverLayoutsAndExactSource` | Passed | 74.521 |
| `NativeUITests/testMacEPUBBodyEditingBookSwitchRestartAndSource` | Passed | 44.343 |
| `NativeUITests/testMacEPUBChapterCancelStopsRemainderAndReopenCannotRetryOrRestoreKey` | Passed | 22.954 |
| `NativeUITests/testMacEPUBChapterCompleteScopeConsentBilingualManualSaveRestartAndSourceReturn` | Passed | 45.348 |
| `NativeUITests/testMacEPUBChapterOversizeRefusesWholeDocumentWithoutKeyOrSend` | Passed | 6.601 |
| `NativeUITests/testMacEPUBChapterPartialFailureKeepsFirstSegmentAndStopsAllRemaining` | Passed | 22.147 |
| `NativeUITests/testMacEPUBSelectionRubyNotesAndRestart` | Passed | 28.721 |
| `NativeUITests/testMacHTMLAliasImportSelectionNotesNavigationAndRestart` | Passed | 48.220 |
| `NativeUITests/testMacJapaneseInvalidOutputAndCancelCannotCreateNotesOrLateReview` | Passed | 90.182 |
| `NativeUITests/testMacJapaneseNativeEPUBSelectionManualSaveAndSourceReturnPreservesRuby` | Passed | 90.387 |
| `NativeUITests/testMacJapaneseOfflineConsentComponentSwitchManualSaveRestartExactPDFReturn` | Passed | 97.604 |
| `NativeUITests/testMacJapaneseSavedBodyEditingSearchKeepsReviewAndCorrections` | Passed | 67.488 |
| `NativeUITests/testMacLearningBodyEditingPreservesResultRestartAndSource` | Passed | 42.608 |
| `NativeUITests/testMacLibraryLayoutSelectionAndOriginalSampleEntrypoints` | Passed | 5.826 |
| `NativeUITests/testMacLibrarySearchMetadataUnicodeEmptyNoResultsAndRestart` | Passed | 51.378 |
| `NativeUITests/testMacLibrarySearchUserNoteSavedLocalMockAIAndExactSource` | Passed | 58.474 |
| `NativeUITests/testMacMarkdownImportSelectionNotesNavigationAndRestart` | Passed | 48.248 |
| `NativeUITests/testMacMHTMLImportSelectionNotesNavigationAndRestart` | Passed | 48.662 |
| `NativeUITests/testMacPDFBodyEditingCancelDraftRestartEmptyAndSource` | Passed | 66.454 |
| `NativeUITests/testMacPDFBodyEditingDiskFailureKeepsDraftAndExplicitRetry` | Passed | 32.116 |
| `NativeUITests/testMacPDFPageCancelStopsRemainderAndReopenKeepsAttemptCount` | Passed | 15.731 |
| `NativeUITests/testMacPDFPageScanAndOversizeRefuseWithoutSend` | Passed | 14.101 |
| `NativeUITests/testMacPDFPanelSwitchRetainsOriginalSelectionAndUnsavedDraft` | Passed | 19.710 |
| `NativeUITests/testMacPDFWholePageOfflineConsentBilingualNotesAndSourceReturn` | Passed | 30.156 |
| `NativeUITests/testMacReadableXMLImportSelectionNotesNavigationAndRestart` | Passed | 48.052 |
| `NativeUITests/testMacSavedMOBIBodyDraftRestartUnifiedSearchAndExactSource` | Passed | 62.680 |
| `NativeUITests/testMacSavedTextBodyDraftRestartUnifiedSearchAndExactSource` | Passed | 70.989 |
| `NativeUITests/testMacTXTImportSelectionNotesNavigationAndRestart` | Passed | 48.134 |
| `NativeUITests/testMacXHTMLImportSelectionNotesNavigationAndRestart` | Passed | 48.071 |
| `NextBatchUITests/testEnglishManualConsentSaveSearchAndRestartKeepsSourceAndNoKey` | Passed | 42.451 |
| `NextBatchUITests/testTrashConfirmationRestoreAndRestartPreserveOriginalBook` | Passed | 45.515 |
| `ReadingIntegrationUITests/testMacEPUBTOCAndCanonicalReturnUseActualRuntime` | Passed | 20.382 |
| `ReadingIntegrationUITests/testMacParagraphCancelDoesNotPublishOrSave` | Passed | 41.403 |
| `ReadingIntegrationUITests/testMacParagraphEPUBCitationReturnsToCanonicalRange` | Passed | 37.970 |
| `ReadingIntegrationUITests/testMacParagraphInsufficientAndInvalidResponsesCannotSave` | Passed | 115.434 |
| `ReadingIntegrationUITests/testMacParagraphTypedEvidenceConsentManualSaveAndSource` | Passed | 58.039 |
| `ReadingIntegrationUITests/testMacPDFSearchTOCReturnAndTextInputProtection` | Passed | 49.001 |
| `ReadingIntegrationUITests/testMacSettingsCategoriesPreserveUnappliedConfiguration` | Passed | 21.465 |
| `ReadingIntegrationUITests/testMacToolsRouteRequiresConsentAndManualSave` | Passed | 39.589 |
