# 批准依赖后补测与完整60项 · 2026-10-06

**最新正式结果：56通过、4失败、0跳过，退出65；完整Mac UI尚未验收。** 最终代码候选`50cfa34b834a62aac1be5ebf29359fa50e07ca59`，原56为52通过／4失败，新增段落4项全部通过。一个完整命令、60个唯一方法各一次，正式xcresult摘要／方法树／日志逐项相同。命令墙钟2719.699秒。

父线程要求最近安全边界立即返回状态。完整命令已结束，所有本任务精确拥有PID不存在、共享heavy lock空闲、无GUI排队。命令连接可用，未因断连重新派发。没有push／dispatch／merge／发布或全仓审计。验收后审计已获条件授权，但完整UI仍失败，条件未满足。

本轮本地修复为`f5fa172`（日文解释与转换状态Text身份刷新，原生文件面板实际行鼠标选择）和`50cfa34`（阅读版PDF状态Text身份刷新）。保留`024703e`日文原生只读可选择来源、`b4c2b87` EPUB同词重选／导航点击，以及段落整合。来源校验、Unicode比较、草稿、3/6预算和零自动重试未变。

## 当前检查

| 检查 | 实测结果 | 证据 |
| --- | --- | --- |
| 一次批准的npm ci | PASS，实际平台包67个；官方registry、ignore-scripts、no-audit/no-fund；独立cache／空npmrc；package与lock SHA不变，安装与缓存43.125MiB | `approved-npm-install-command.json`、`approved-npm-and-node-outcome.json` |
| 新补两份ebook Node | 11/11 PASS，0fail／skip／cancel | `approved-ebook-node-tests-command.json`／`.log` |
| 全部六份Node | 实际单次25/25 PASS，0fail／skip／cancel；不是历史14+新11相加 | `approved-all-node-tests-command.json`／`.log` |
| 最终代码全Swift | 552项／70套件PASS，41.382秒 | `export-status-full-swift-command.json`／`.log` |
| 最终Mac build-for-testing | arm64+x86_64 PASS；隔离App和XCTest实际lipo均为两架构；仅arm64实际运行 | `export-status-build-command.json`／`.log`、`export-status-plan.json` |
| 完整60专用编译 | PASS，原四份方法文件与受控源逐字节相同 | `final60-build-command.json`／`.log`、`final60-plan.json` |
| 原先剩余11方法 | 均有修复后实际完整方法PASS、0skip，三个明确候选；不合并为完整通过 | `remaining11-actual-pass-matrix.json` |
| 同候选完整60 | 56 PASS／4 FAIL／0 SKIP，命令65，验收FAIL | `final60-outcome.json`、`final60-{summary,tests}.json`、`Final60Once.xcresult` |

完整60 bundle为`org.pdfno.integration.finalsixty20261006.PDFnoMac`；原方法自行生成新UUID、全部自制fixture、入口强制offline。实际记录95个拥有App PID、64个隔离session（含重启／多scenario），60个方法均只开始一次。无过滤／跳过／失败重试。原700个断言及此前ebook严格输入守卫保留，新面板驱动增加一个XCTUnwrap，目前702个断言调用。

## 四项仍待处理

| 原方法 | 实际结果 | 首个失败与下一定位 |
| --- | --- | --- |
| `NativeUITests/testMacEditedNoteSearchDraftExclusionCoverLayoutsAndExactSource` | FAIL / 64.288秒 | L6556；合成文字粘贴后，XCTest处理84×77的短暂Dialog时AX身份绑定丢失；搜索两项在再次输入，整章项在滚动保存按钮。输入候选／纠错弹层是待验证推断，根因未确认。 |
| `NativeUITests/testMacEPUBChapterCompleteScopeConsentBilingualManualSaveRestartAndSourceReturn` | FAIL / 26.720秒 | L7168；合成文字粘贴后，XCTest处理84×77的短暂Dialog时AX身份绑定丢失；搜索两项在再次输入，整章项在滚动保存按钮。输入候选／纠错弹层是待验证推断，根因未确认。 |
| `NativeUITests/testMacLibrarySearchMetadataUnicodeEmptyNoResultsAndRestart` | FAIL / 22.466秒 | L10309；合成文字粘贴后，XCTest处理84×77的短暂Dialog时AX身份绑定丢失；搜索两项在再次输入，整章项在滚动保存按钮。输入候选／纠错弹层是待验证推断，根因未确认。 |
| `NextBatchUITests/testTrashConfirmationRestoreAndRestartPreserveOriginalBook` | FAIL / 16.408秒 | L14481；未找到期待的local-recovery-trash-UUID Button，发生在移入回收站前。静态代码把ID放在HStack；是否实际暴露为Group、列表是否加载，需隔离实际AX确认。 |

这四项未再次派发，未移除／放宽原断言。下一轮先取具名失败活动与隔离控件证据，再作对应小修；不能依据当前失败直接要求改变系统输入法、TCC或环境。

## 小修的直接证据

日文PDF旧候选的同一快照已选中“宾语”，解释仍为上一“主语”文字；为Selectable Text加component身份后，原完整PDF方法在局部及本轮完整60均PASS。文件面板实际双击父cell／row关闭文件与目录overlay，原始DOCX损坏／恢复完整流程PASS，保留原件／HTML／拒绝覆盖断言。阅读版PDF旧候选仅两个状态等待失败、PDF及原件／输出字节断言无其他失败；刷新状态身份后原完整方法局部及本轮完整60均PASS。见`jpdf-component-stale-explanation-evidence.json`、`feedback-repair-evidence-and-protection.json`、`export-status-observed-evidence.json`。

准备时一次沙箱ps停止后误调用不存在工程、一次旧result前缀被保护断言拦截、首次metadata临时TestReport权限失败均保留；没有旧结果覆盖或额外GUI派发。成功编译和正式元数据采用独立文件名。`feedback-repair-preparation-corrections.json`记录准备更正。

## 截图与仍未验收边界

19张原自制fixture截图SHA均未改变，仍是本地交付；实际JPEG、旧扩展名png，不改名或改像素。当前官方Library脚本使用Python3.10特性，宿主仅有3.9.6，bundled runtime工具未提供替代路径。没有安装新Python／环境，没有启动新上传API，没有library_file_id，不能称截图已附到Library。[Library SKILL.md](skill://plugin_connector_1p_1b8ff8edfc1481918b252c8277e23125/library/SKILL.md)要求多个文件且两个prepared工具可用时：“Use the bundled prepared-upload helper below.”，因此没有手工prepare/finalize或降级直接create。见`library-current-compatibility-block.json`。

本轮CUA按精确隔离App路径最终返回实际空Library AX，但超时参数未被遵守，App在180秒锁窗口结束后才迟到启动；全过程GUI读取受锁保护未核验。只清理核验后的本任务PID20912；证据`gui-readiness-observation-and-late-cleanup.json`。后续所有XCTest实际执行均持共享锁。此前更早默认Library启动偏差仍UNKNOWN，新守卫不能抹去历史，旧报告与收据保留。

真实API／模型schema成功率与解释质量、人工VoiceOver、当前iOS编译／移动实际UI、安全专项依旧未验收或后置。iOS曾被自动审批因mobile明确后置拒绝，未执行／未重试；安全UNVERIFIED/platform-blocked未重试。未读取privateLibrary／密钥、受限sessions或内部数据库；未改变系统主题／TCC／输入法／安全权限或重启服务。

## 本地交接

持久tree：`.build/MacUIExperience/2026-10-06/tree`；branch：`feature/mac-ui-experience-20261006`。证据根：`.build/MacUIExperience/2026-10-06/evidence`。最新收据`FINAL-RECEIPT.json`、收尾保护`approved-completion-post-run-protection.json`；此前收据完整备份`FINAL-RECEIPT-9ae245a-remaining11.json`。main仍`6a67d1fd883f79737d0e3e12c756b683a662f230`，未跟踪Xcode workspace metadata保全。历史33/27/0完整60与所有失败候选、11局部PASS、此前四局部PASS及截图均保留。

| 原先11方法 | 候选 | 秒数 / 结果 |
| --- | --- | --- |
| `NativeUITests/testMacJapaneseNativeEPUBSelectionManualSaveAndSourceReturnPreservesRuby` | `9ae245a` | 89.286 / PASS |
| `NativeUITests/testMacJapaneseInvalidOutputAndCancelCannotCreateNotesOrLateReview` | `9ae245a` | 90.574 / PASS |
| `NativeUITests/testMacDOCXConversionFailureRecoveryAndEscapedHTML` | `f5fa172` | 62.564 / PASS |
| `NativeUITests/testMacJapaneseOfflineConsentComponentSwitchManualSaveRestartExactPDFReturn` | `f5fa172` | 96.577 / PASS |
| `NativeUITests/testMacCB7ImportSpreadsDirectionPageJumpAndRestart` | `f5fa172` | 71.443 / PASS |
| `NativeUITests/testMacCBRImportSpreadsDirectionPageJumpAndRestart` | `f5fa172` | 71.155 / PASS |
| `NativeUITests/testMacCBTImportSpreadsDirectionPageJumpAndRestart` | `f5fa172` | 71.142 / PASS |
| `NativeUITests/testMacCoverSelectionGridListRestartAndRestore` | `f5fa172` | 38.363 / PASS |
| `NativeUITests/testMacDOCXConversionSavePanelCancelAndOverwriteRefusal` | `f5fa172` | 50.331 / PASS |
| `NativeUITests/testMacDOCXReadingPDFEntryCancelExportAndOverwriteRefusal` | `50cfa34` | 52.311 / PASS |
| `NativeUITests/testMacMHTMLImportSelectionNotesNavigationAndRestart` | `50cfa34` | 48.125 / PASS |
