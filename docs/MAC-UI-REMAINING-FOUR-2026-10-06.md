# 四个剩余原方法单次验收 · 2026-10-06

**AZW/AZW3/FB2/DeepSeek四个原完整方法均单次PASS、零失败、零跳过、零重试。清除四个原方法门槛，剩余11个原方法未验收。当前完整验收仍NOT ACCEPTED，未进行新的完整60项运行，未启动其他probe。**

父任务确认这四项已由原用户本地开发、修复和验证授权覆盖，无需逐方法再次询问；本轮仅执行该固定四项。用户已要求验收后执行全仓审计，当前是验收条件未达，不是审计整体未获授权。npm安装、新验证环境和公开操作仍须相应许可。本轮没有这些操作。

## 精确实际结果

| 原方法 | 正式结果 | 实测秒数 | 保留的完整范围 |
| --- | --- | --- | --- |
| EbookFormatUITests/testAZWSelectionNoteProgressRestart | PASS / exit0 / 1次 / 0 SKIP | 33.544841 | 原选文、手动笔记、三条件AND、重启字典等值、真实回源、切换PDF。 |
| EbookFormatUITests/testAZW3SelectionNoteProgressRestart | PASS / exit0 / 1次 / 0 SKIP | 32.767589 | 同上，独立AZW3/KF8原fixture。 |
| EbookFormatUITests/testFB2SelectionNoteProgressRestart | PASS / exit0 / 1次 / 0 SKIP | 32.739531 | 同上，独立FB2原fixture。 |
| NativeUITests/testMacDeepSeekSelectionOfflineTransportPDFEPUBAndRestart | PASS / exit0 / 1次 / 0 SKIP | 56.399725 | 原PDF选文/离线替身/用户确认/不自动保存/手动保存/回源，EPUB解释/手动保存/回源，重启后解释保留、session key不保留、start禁用。 |

三电子书各自保存前实际正文严格UTF-8等于`Original ebook observation`；原format/body/progress三个比较均true且AND未改变，进度等待分别AZW/O、AZW3/S、FB2/O。最终manifest在真实回源之后，progress与已存note.anchor相等，不能把该终态当作更早的三条件等待快照。各自己的manifest和原日志保留。

DeepSeek使用原已编译的确认/开始控件滚动修正及原生合成粘贴，原断言全部保留。请求仅走offline拦截，credential为synthetic-reading-ui-credential。此PASS是离线UI闭环实测，不能评价真实模型质量、schema成功率或费用。

## 隔离和证据边界

开工单次实际命令连接PASS；原候选HEAD `7c15366afbb86f8f443c4df926b1e0aa72c98bea` clean、旧精确任务PID全部退出、共享锁空闲后准备。本次新工程`.build/IsolatedRemainingFourProject`、新产物`evidence/RemainingFourBuild`、专用bundle `org.pdfno.integration.remainingfour20261006.PDFnoMac`。每方法独立新UUID临时库；scene前强制bundle/有效UUID/offline/四项scope。runner及App均指专用产物，keepNever附件。每方法在同一共享锁内串行，上一场任务进程退出后才派发下一场，无失败重复或额外方法。

包内405文件逐字节等于上述精确git archive，无生产Package改动。忽略测试副本仅替换两个UUID初始化、添加UUID合法性守卫/DeepSeek退出清理及既有电子书输入日志；原断言未移除。跟踪源码700原断言及新增1个严格UTF-8守卫仍为701，原60方法名/数量、原电子书三比较及AND保持。隔离Mac arm64 ad-hoc build-for-testing PASS；本轮未新增功能、产品源码或测试方法。

正式summary/tests/test-details/activities及实际日志每项均有一个唯一test run、一次method start；所有命令和输出有SHA收据。不导出新截图，旧19张及失败日志、旧GUI副本和构建产物保持。本轮未关闭/替换/重置正式用户App，未读私人书库/笔记/key，未改系统主题、输入法或安全权限。main仍6a67，未跟踪Xcode workspace metadata保留。最早启动隔离偏差的历史UNKNOWN记录保持，不能由本轮隔离结果抹除。

## 11个剩余原方法

| 组 | 精确方法（均NativeUITests） | 状态 |
| --- | --- | --- |
| 日语AX | testMacJapaneseInvalidOutputAndCancelCannotCreateNotesOrLateReview | 旧失败、读取/崩溃路线暂停，精确AX循环节点未定位。 |
| 日语AX | testMacJapaneseNativeEPUBSelectionManualSaveAndSourceReturnPreservesRuby | 旧失败，真实AX栈耗尽证据保留，暂停。 |
| 日语AX | testMacJapaneseOfflineConsentComponentSwitchManualSaveRestartExactPDFReturn | 旧准备/断言失败与runner恢复，来源保存闭环未通过，暂停。 |
| 保存面板 | testMacCB7ImportSpreadsDirectionPageJumpAndRestart | 旧openAndSavePanelService崩溃，暂停。 |
| 保存面板 | testMacCBRImportSpreadsDirectionPageJumpAndRestart | 同上。 |
| 保存面板 | testMacCBTImportSpreadsDirectionPageJumpAndRestart | 同上。 |
| 保存面板 | testMacCoverSelectionGridListRestartAndRestore | 同上。 |
| 保存面板 | testMacDOCXConversionSavePanelCancelAndOverwriteRefusal | 同上。 |
| 保存面板 | testMacDOCXReadingPDFEntryCancelExportAndOverwriteRefusal | 同上。 |
| 保存面板 | testMacMHTMLImportSelectionNotesNavigationAndRestart | 同上。 |
| DOCX完整流程 | testMacDOCXConversionFailureRecoveryAndEscapedHTML | 错误分支/helper已单次PASS，含输入/保存面板、HTML恢复/转义/源字节保护的原完整方法仍未验收。 |

合计日语3 + 面板7 + DOCX完整1 = **11**。不同源码和范围的历史批次不能拼成当前完整60项PASS；历史完整60仍33 PASS/27 FAIL/0 SKIP，原13项9/4/0和旧诊断失败等保持。先前MOBI完整方法PASS也保持。

## 其他剩余门槛和条件

| 门槛 | 精确状态 / 后续条件 |
| --- | --- |
| 当前候选完整60 UI | NOT ACCEPTED；这11个原方法继续未验收，不能排除/跳过后宣称完整通过。本轮四项结束后保持现场，不自动开启probe。 |
| 日语AX与面板相关验证环境 | 当前路线继续暂停；换新的适合隔离验证环境需要用户许可，当前系统权限不变。 |
| engine-build/ebook.test.mjs、ebook-bridge.test.mjs | 缺jsdom26.1.0，NOT-RUN；npm安装仍未批准，不绕过。 |
| 19张截图Library附件 | 本地文件交付，官方helper现有Python兼容性/依赖通道阻塞，无library_file_id；兼容官方环境另需条件和许可。 |
| 真实模型/schema成功率/解释质量/费用usage | UNVERIFIED，真实API/key不在当前范围，延期。 |
| VoiceOver/输入法人工流程、Intel运行、移动实际UI、损坏库/导入/加载过渡 | 未验收，明确保留该范围，不由离线自动化结果代替。 |
| 安全专项 | UNVERIFIED/platform-blocked，保持暂停，不重试。 |
| 用户要求的验收后全仓审计 | **已要求、尚未启动，当前完整验收条件未达。** 不记成整体未授权；本轮不提前启动。 |
| push/dispatch/merge/公开发布 | 未获本次授权，未执行；验收后公开操作另确认。 |

Bookno/iCloud/mobile/MCP扩展仍后置。四项固定授权已完成，无监控、任务或新probe排队。

证据根目录为主仓库`.build/MacUIExperience/2026-10-06/evidence`：`remaining4-single-admission.json`、`remaining4-plan.json`、`remaining4-source-protection.json`、`remaining4-isolation-driver.diff`、`remaining4-build-command.json`/`.log`、`remaining4-{azw,azw3,fb2,deepseek}-once-command.json`/`.log`、各summary/tests/test-details/activities及读取收据、三个own-final-manifest、`remaining4-post-run-protection.json`、`remaining4-remaining-gates.json`、`remaining4-outcome.json`、`PARENT-STATUS-REMAINING-FOUR.json`、`FINAL-RECEIPT.json`。正式结果包分别`Remaining4-{scope}-once.xcresult`；最后提交只记录这些结果及审计条件更正。
