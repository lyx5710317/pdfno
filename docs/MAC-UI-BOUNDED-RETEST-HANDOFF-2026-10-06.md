# 最后两项有界复验与剩余门槛 · 2026-10-06

**本次授权两项均单次PASS：修正后的原MOBI完整方法，以及同一个修正后的DOCX零面板诊断。MOBI清除一个原失败门槛；DOCX原完整方法仍未验收。现在15个原失败方法未清除，完整验收仍NOT ACCEPTED，不再自动增加小probe。**

## 本轮实际结果

开工只做一次实际命令检查，连接PASS、5056dfbe候选clean、已记录旧进程退出、共享锁空闲后才准备依赖操作；没有断连或重派发。新工程/产物为IsolatedPersistenceRetestProject / PersistenceRetestBuild，独立App ID org.pdfno.integration.persistenceretest20261006.PDFnoMac，runner/test ID同专用前缀。每场景新UUID、scene前offline与bundle守卫、自己的PID收据、同一shared heavy lock、原创fixture、keepNever附件；没有读用户书籍/笔记/key或修改系统权限、主题、输入法。

包源码精确来自5056dfbe9ac72a764b079c3bfb81969d71cde4f6，忽略副本只有已审阅的零面板hook、修正诊断、UUID绑定与本次字段打印。Mac arm64 ad-hoc build-for-testing PASS，不覆盖旧GUI构建。实际两方法及各结果包均只有一个唯一test run，retry0、0 SKIP；正式summary、tests、test-details、activities与日志一致。

| 方法 / 范围 | 正式结果 | 实测证据 |
| --- | --- | --- |
| EbookFormatUITests/testMOBISelectionNoteProgressRestart（原方法） | PASS / exit0；34.179567秒 | 粘贴后的正文严格UTF-8等于Original ebook observation；原format/body/progress等待的mobi/Original ebook observation/O三项均true；所有非nil、重启、保存字典等值与真实回源断言通过。 |
| NativeUITests/testDOCXErrorValueTypeNoPanelProbe（同一个修正诊断） | PASS / exit0；6.710361秒 | 原conversion-status存在，value类型__NSCFString，完整预期错误；label为空；原helper取value并contains=true，原15秒等待通过。单次worker终态、result=nil、output不存在、source bytes未变、savePanel0均通过。 |

DOCX等待前/后均实际读取：valueContainsExpected=true、labelContainsExpected=false、originalHelperContainsExpected=true；完整String为“DOCX 归档损坏、不安全、加密或含当前不支持的 ZIP 结构。 可以重新选择位置再试。”。旧新诊断仅label读取为空的缺陷已由value优先/空值回退修正解决；**原旧full60 DOCX等待失败的完整宿主/面板链根因仍不能由无面板场景排除。** 没有修改生产status Text或共享waitForText。

MOBI最终manifest是在回源之后，progress.quote已变为“Original”，与保存的note anchor完全相同；它不是原等待时的O快照。本轮分别保存日志中的三条件和自己的最终manifest。AZW/AZW3/FB2没有运行，MOBI PASS不能外推。19张旧截图和旧失败日志/源码/产物不变，没有新截图/Library上传。

## 15个尚未清除的原方法

这里列原方法的最新实际验收状态，保留不同候选的历史结果，不把此次诊断PASS算作原完整方法PASS。前一轮16减少的唯一一项是原MOBI方法。

| 组 | 精确原方法（类均为NativeUITests，除注明者） | 尚缺的门槛 |
| --- | --- | --- |
| DeepSeek EPUB | testMacDeepSeekSelectionOfflineTransportPDFEPUBAndRestart | 原方法FAIL；确认/start视口驱动已编译，未实际清除该完整方法。 |
| 日语AX | testMacJapaneseInvalidOutputAndCancelCannotCreateNotesOrLateReview | 原App崩溃；真实role/label重入与Stack Guard证据保留，精确节点循环未定位。路线暂停。 |
| 日语AX | testMacJapaneseNativeEPUBSelectionManualSaveAndSourceReturnPreservesRuby | 原App失联/崩溃；精确identifier后仍有同类故障，暂停。 |
| 日语AX | testMacJapaneseOfflineConsentComponentSwitchManualSaveRestartExactPDFReturn | 原准备/断言失败及runner恢复，完整来源保存闭环未通过。暂停。 |
| 保存面板 | testMacCB7ImportSpreadsDirectionPageJumpAndRestart | 原openAndSavePanelService崩溃，暂停。 |
| 保存面板 | testMacCBRImportSpreadsDirectionPageJumpAndRestart | 同上，暂停。 |
| 保存面板 | testMacCBTImportSpreadsDirectionPageJumpAndRestart | 同上，暂停。 |
| 保存面板 | testMacCoverSelectionGridListRestartAndRestore | 同上，暂停。 |
| 保存面板 | testMacDOCXConversionSavePanelCancelAndOverwriteRefusal | 同上，暂停。 |
| 保存面板 | testMacDOCXReadingPDFEntryCancelExportAndOverwriteRefusal | 同上，暂停。 |
| 保存面板 | testMacMHTMLImportSelectionNotesNavigationAndRestart | 同上，暂停。 |
| 电子书 | EbookFormatUITests/testAZWSelectionNoteProgressRestart | 历史原compound等待FAIL；共用输入修正已编译，本格式修正后NOT-RUN。 |
| 电子书 | EbookFormatUITests/testAZW3SelectionNoteProgressRestart | 同上，NOT-RUN。 |
| 电子书 | EbookFormatUITests/testFB2SelectionNoteProgressRestart | 同上，NOT-RUN。 |
| DOCX完整方法 | testMacDOCXConversionFailureRecoveryAndEscapedHTML | 零面板错误分支/原helper现在PASS，但完整原方法还含输入/保存面板、有效HTML恢复、转义与源字节保护，尚未重跑。 |

合计：DeepSeek1 + 日语3 + 保存面板7 + 电子书3 + DOCX完整1 = **15**。完整60历史仍33 PASS/27 FAIL/0 SKIP；13项历史9/4/0、两个日语probe0/2/0、AX组件基线对照INCONCLUSIVE均保持。不能把不同源码/范围的小批实测拼成当前候选全60通过。

## 其他边界与必须用户决定的事项

| 门槛 | 当前精确状态 | 需要的决定 / 终止边界 |
| --- | --- | --- |
| 其余3电子书格式及DeepSeek原方法 | 已有修正，但未实际验收 | 是否授权一次固定4方法验收批次（AZW/AZW3/FB2/DeepSeek各一次），或明确延期。批次任何失败只保全交付，不再自动衍生probe。 |
| 日语3与面板相关8原方法（7面板+DOCX完整） | 当前平台/读取路线阻塞，保持暂停 | 选择延期/明确排除，或另选已具备隔离验证能力的Mac环境及新授权。不会扩展当前系统权限、注入调试或循环面板。 |
| 当前候选完整60 UI | 未通过；本轮没有全量运行 | 上述门槛解决或明确缩小范围后，是否授权一次最终全60验收；现在不重跑。 |
| engine-build/ebook.test.mjs、ebook-bridge.test.mjs | 缺jsdom26.1.0，NOT-RUN，npm仍未批准 | 明确批准此前受控锁文件依赖安装/测试，或接受继续NOT-RUN；未有批准就不安装。 |
| 19张截图Library附件 | 本地交付；官方helper受现有Python类型标注/依赖通道阻塞；没有library_file_id | 接受本地文件交付，或另授权已核验兼容的官方运行环境。未安装运行时、改helper或绕过官方上传。 |
| 真实模型/schema成功率、解释质量、费用/usage | UNVERIFIED；真实API/key不在当前授权内 | 延期；如要评价，必须另定义范围与条件，离线合成PASS不代表质量验收。 |
| VoiceOver/输入法人工流程、Intel runtime、移动实际UI、损坏Library/导入/加载过渡 | 本次实际GUI未验收 | 决定需要的具体平台/范围或继续列明确排除项；不自动扩展。 |
| 安全专项 | UNVERIFIED / platform-blocked | 保持暂停，不在当前环境重试。 |
| push/dispatch/merge/发布与全仓审计 | 均未授权/执行，完整验收前提未达 | 验收范围和阻塞项确定后再决定；本次不授权任何公开操作或审计。 |

Bookno/iCloud/mobile/MCP扩展保持原先后置，不是本轮通过条件。本交接没有排队任何下一次测试、监控或自动任务。上述有限批次/平台/安装/交付范围是需要用户决定的点；若选择延期，准确保留未验收范围即可结束本轮，不继续空读小探针。

## 本地证据与保全

主仓库 `.build/MacUIExperience/2026-10-06/evidence`：persistence-retest-single-admission.json；persistence-retest-plan.json；persistence-retest-build-command.json / .log；persistence-retest-{mobi,docx}-once-command.json / .log；各自summary/tests/test-details/activities及读取收据；persistence-retest-mobi-own-final-manifest.json；persistence-retest-post-run-protection.json；persistence-retest-remaining-gates.json；persistence-retest-outcome.json；PARENT-STATUS-PERSISTENCE-RETEST.json；FINAL-RECEIPT.json。

本次xcode92113/92169、runner92116/92172、App92121/92136/92173与此前精确PID均已退出，共享锁空闲。原701当前断言（其中700原断言）、60原方法、Unicode来源/草稿/3与6预算/零自动重试及生产文件均未改。main仍6a67、未跟踪Xcode metadata保留；无用户App关闭/替换/重置，无安装/真实API/私人库/系统改动。新本地提交只记录证据和门槛，并更正前一报告runner PID误记：实际为90879，以原执行收据为准，旧收据不改。
