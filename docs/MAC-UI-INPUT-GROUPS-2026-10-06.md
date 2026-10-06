# Mac 输入与凭据分组单批复测 · 2026-10-06

后续本次专用崩溃栈已取证，精确identifier/viewport驱动与DOCX/ebook诊断已通过单元和编译，未GUI复测；见[崩溃与驱动报告](MAC-UI-CRASH-AND-DRIVER-DIAGNOSIS-2026-10-06.md)。以下保留13项原实测，不代表后续修改已通过。

审阅92fe355后，沿已证实的合成粘贴驱动，仅复测其余3输入+10离线凭据。**正式13项、9 PASS、4 FAIL、0 SKIP，退出65；唯一13方法各开始一次。** 已过两个代表、完整60、保存面板7、电子书4、DOCX错误1均未运行；失败不循环重跑。

| 当前分组 | 本批 | 前次代表 | 各方法最新已知状态（不是完整套件结果） |
| --- | --- | --- | --- |
| 输入4 | 3 PASS | 设置1 PASS | 4 PASS / 0 FAIL |
| 凭据11 | 6 PASS / 4 FAIL | BYOK1 PASS | 7 PASS / 4 FAIL |
| 保存面板7 | 未运行 | 原7 FAIL | 单列服务崩溃，不改权限/签名账号绕过。 |
| 电子书4 | 仅静态读取 | 原4 FAIL | 三谓词实际值未记录，仍未复验。 |
| DOCX错误1 | 仅静态读取 | 原1 FAIL | 已发布预期错误AX文本，等待失败仍待定。 |

原27失败方法中后续通过11；本批4失败、本批外12未复验，共16未解决。原完整60仍33 PASS / 27 FAIL / 0 SKIP，未重跑，完整验收未通过。

## 逐项结果与日志

日志路径相对于主仓库 .build/MacUIExperience/2026-10-06/evidence，是同一实际日志的原顺序摘录；首次失败原文/行号、日志SHA与正式结果节点见input-group-method-outcomes.json。

| 方法 | 正式结果 | 秒数 | 实际观察 | 日志 |
| --- | --- | --- | --- | --- |
| NextBatchUITests/testEnglishManualConsentSaveSearchAndRestartKeepsSourceAndNoKey | Passed | 42.845 | 原流程/断言通过。 | input-group-method-logs/testEnglishManualConsentSaveSearchAndRestartKeepsSourceAndNoKey.log |
| ReadingIntegrationUITests/testMacPDFSearchTOCReturnAndTextInputProtection | Passed | 48.986 | 原流程/断言通过。 | input-group-method-logs/testMacPDFSearchTOCReturnAndTextInputProtection.log |
| ReadingIntegrationUITests/testMacToolsRouteRequiresConsentAndManualSave | Passed | 39.941 | 原流程/断言通过。 | input-group-method-logs/testMacToolsRouteRequiresConsentAndManualSave.log |
| NativeUITests/testMacDeepSeekSelectionOfflineTransportPDFEPUBAndRestart | Failed | 46.23 | EPUB确认/开始未生效；PDF翻译与保存已过。 | input-group-method-logs/testMacDeepSeekSelectionOfflineTransportPDFEPUBAndRestart.log |
| NativeUITests/testMacJapaneseInvalidOutputAndCancelCannotCreateNotesOrLateReview | Failed | 89.368 | 隔离App崩溃及后续预算/搜索断言失败。 | input-group-method-logs/testMacJapaneseInvalidOutputAndCancelCannotCreateNotesOrLateReview.log |
| NativeUITests/testMacJapaneseNativeEPUBSelectionManualSaveAndSourceReturnPreservesRuby | Failed | 54.276 | 连接丢失，另有隔离App崩溃记录。 | input-group-method-logs/testMacJapaneseNativeEPUBSelectionManualSaveAndSourceReturnPreservesRuby.log |
| NativeUITests/testMacJapaneseOfflineConsentComponentSwitchManualSaveRestartExactPDFReturn | Failed | 未记录（异常结束） | 准备阶段无search-result；runner随后恢复。 | input-group-method-logs/testMacJapaneseOfflineConsentComponentSwitchManualSaveRestartExactPDFReturn.log |
| NativeUITests/testMacJapaneseSavedBodyEditingSearchKeepsReviewAndCorrections | Passed | 65.528 | 原流程/断言通过。 | input-group-method-logs/testMacJapaneseSavedBodyEditingSearchKeepsReviewAndCorrections.log |
| NativeUITests/testMacEPUBChapterCancelStopsRemainderAndReopenCannotRetryOrRestoreKey | Passed | 24.114 | 原流程/断言通过。 | input-group-method-logs/testMacEPUBChapterCancelStopsRemainderAndReopenCannotRetryOrRestoreKey.log |
| NativeUITests/testMacEPUBChapterCompleteScopeConsentBilingualManualSaveRestartAndSourceReturn | Passed | 42.03 | 原流程/断言通过。 | input-group-method-logs/testMacEPUBChapterCompleteScopeConsentBilingualManualSaveRestartAndSourceReturn.log |
| NativeUITests/testMacEPUBChapterPartialFailureKeepsFirstSegmentAndStopsAllRemaining | Passed | 23.023 | 原流程/断言通过。 | input-group-method-logs/testMacEPUBChapterPartialFailureKeepsFirstSegmentAndStopsAllRemaining.log |
| NativeUITests/testMacPDFPageCancelStopsRemainderAndReopenKeepsAttemptCount | Passed | 15.871 | 原流程/断言通过。 | input-group-method-logs/testMacPDFPageCancelStopsRemainderAndReopenKeepsAttemptCount.log |
| NativeUITests/testMacPDFWholePageOfflineConsentBilingualNotesAndSourceReturn | Passed | 29.205 | 原流程/断言通过。 | input-group-method-logs/testMacPDFWholePageOfflineConsentBilingualNotesAndSourceReturn.log |

命令UTC：2026-10-06T11:14:17.498107+00:00 至 2026-10-06T11:23:32.172864+00:00，engine elapsed553.027秒。Xcode在日语Component后恢复runner一次，继续未执行方法；各13方法只有一次start，没有重跑失败方法。恢复后日志末尾仅打印6项0失败，不能代表整批；正式summary/tests树为13、9/4/0、Failed。Component缺普通Test Case结束行及方法耗时，以正式树Failed为准，不虚构精确耗时。

## 驱动范围与隔离

92fe355只覆盖BYOK与设置标签。本轮Native6处合成凭据改为现有enterSearch；ReadingIntegration搜索及保护用正文改为现有paragraphPaste；NextBatch5处合成输入使用write-only pasteFixture，保留原焦点/viewport/正文等值检查。Native本批日语正文编辑的enterRecordBody删除剪贴板快照/恢复，原值/保存状态检查保持。

仅3个测试文件改变，20行新增/21行删除；Native595与ReadingIntegration33共628条原XCTest断言逐字节相同，NextBatch48亦相同，总676。60个方法名称/数量不变，不添加skip/retry或放宽来源、保存、等值及超时保护。生产源码、Unicode/fence、草稿、3/6预算及零自动重试未变。新4段落和已过2代表本轮未重复运行。

build-for-testing PASS（本机Mac arm64）。独立inputprobe App/runner/UITargetApp路径与ID核验；原helper新UUID，App初始化前保障UUID/offline，合成凭据全拦截、无network fallback。只写合成剪贴板，不读原内容或恢复；未执行原保存面板pastePath。共享heavy lock内parallel NO、180/240秒预算、默认单次、keepNever，新InputGroupsOnce.xcresult与一次性派发guard。旧精确PID已结束后才派发；结束所有日志具名自有PID不存在、锁可获取。PID0是崩溃占位，未作为检查目标。

运行前后App/runner/test bundle SHA一致，App与两个代表实验相同：129f390f6a1e2188419e423792fd1fce13948aa0ecb19201a41dc713e794ae85。main仍6a67d1f，Xcode未跟踪metadata、Full60原日志/结果、19张自制截图SHA保持。Swift542/66 suites、Mac/iOS双架构build、Node14和离线transport6参数分支是此前实测，本轮没有重跑。修复/报告是本地结果，不是人工签字或发布。

## 本批四失败与最小下一步

DeepSeek已通过PDF翻译、手动保存和回源；EPUB解释在Native:1928等结果失败。3个去重具名自制App UI hierarchy是UTF-8文本：来源window、会话密钥已输入、预算仍1/3、确认value0、开始Disabled、来源已固定/确认后开始。ai-notes-list视口Y218.5–794，确认Y799.5–816、开始Y828–858均在下方，结果任何角色都不存在。证据支持缺少物理viewport/确认状态检查，不能称结果角色缺失或再次凭据拒绝。最小下一probe：一个新UUID EPUB解释，沿现有滚动helper确保原确认/开始在viewport，记录点击前后确认/启用/来源状态，有效且保持同意后最多提交一次，不放宽consent/source guard。本轮未实现/运行此probe。

日语Invalid/Cancel在预算元素读取附近记录隔离App崩溃；Native EPUB/Ruby在结果状态/组件读取时丢连接，另有App崩溃。确切栈/根因尚未确认，不统一归为输入问题。日语Component首次在prepareOriginalPDFNoteEditing的search-result存在/点击失败（当前Native:529/2120），随后runner意外退出恢复，不能算凭据路径通过。后续先读本次自有崩溃metadata/步骤时序，再提出单场景/新UUID最小probe，不默认重跑这4方法或改权限。

## 其他三组静态结论

电子书原compound predicate为format等于指定格式、userText等于Original ebook observation、progress.quote等于第二章首字符。四项原记录未保存三个实际值；savedAnchor/savedProgress非nil断言未失败，只能证明曾读到结构。AZW3唯一去重Debug description仅94字节Query chain；活动无可核验测试UUID，未猜测UUID或枚举/tmp其他库。最小probe仍为一个MOBI新UUID：粘贴并先验正文等值、保存/选第二章，只读自己manifest，分别记录三谓词一次，保留原组合断言；本轮未运行。

DOCX原失败方法首/末两个具名Debug description均3884字节UTF-8实际AX文本，conversion-status前缀DOCX 归档损坏、不安全、加密或含...，确实包含原预期归档损坏。错误已发布，这修正此前未读取真实文本时的候选，不能再说未出现对应产品错误。原waitForText正式失败仍保留；实际XCUI value动态类型、helper当时String/label及输出不存在未分别记录，尚未确认根因。最小probe一次新UUID、零保存面板：真实ConversionModel.start+原损坏fixture/自有输出，渲染同status，记录label/value类型/contains/exists、result/error/输出不存在；本轮未实现/运行。

保存面板7只保留原正式服务崩溃，未运行/关闭诊断/改XPC环境、系统权限或签名账号。安全专项UNVERIFIED/platform-blocked不重试；npm仍未批准，不安装，两ebook Node仍NOT-RUN；无全仓审计/push/dispatch/merge/发布。既有最早开发App启动默认库瞬时写入/迁移UNKNOWN仍记录，未重读/回滚真实库。Library上传仍阻塞，截图只有本地路径，无library_file_id。

## 证据

证据根：主仓库 .build/MacUIExperience/2026-10-06/evidence。

- input-group-plan.json、input-group-ui-command.json/.log、InputGroupsOnce.xcresult：单次执行。
- input-group-summary/tests-command.json/.log、input-group-formal-methods.json：正式13方法及9/4/0。
- input-group-method-outcomes.json、input-group-method-logs/：表中逐项结果、首次失败原文/行及日志SHA。
- input-group-build-command.json/.log、input-group-driver-fix.diff、input-group-assertion-protection.json：编译、驱动diff、676条断言保持。
- input-group-deepseek-attachments/hierarchy-exports/readonly-diagnosis.json、input-group-deepseek-hierarchy-0/1/2.txt：结果/viewport具名文本，无图片/系统诊断导出。
- input-group-static-export-plan/text-receipt.json、input-group-static-azw3-0-debug.txt、input-group-static-docx-0/1-debug.txt、input-group-other-groups-static.json：旧ebook/DOCX实际值与未运行probe边界。
- input-group-final-process-check-command.json/.log、input-group-outcome.json、FINAL-RECEIPT.json、PARENT-STATUS-INPUT-GROUPS.json：进程与最新分组/提交收据。

前次代表见[输入实验](MAC-UI-INPUT-PROBE-2026-10-06.md)，历史矩阵见[完整60](MAC-UI-FULL60-2026-10-06.md)。本次没有改判或覆盖原完整结果。
