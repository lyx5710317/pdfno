# DOCX错误 / 电子书保存进度：限定诊断与输入驱动修正 · 2026-10-06

**MOBI原等待的唯一false条件已取得：笔记正文不是原预期。测试输入驱动已修正并编译，但未GUI复验。DOCX模型能正确发布预期错误；实际AX状态字段仍缺证据，原失败未清除。** 两个授权代表各执行一次，正式0 PASS/2 FAIL/0 SKIP，没有重试、其他格式或全suite执行。本轮不改生产代码、不放宽断言。

## 两次实际执行与保留结果

两次都使用 org.pdfno.integration.persistenceprobe20261006.PDFnoMac 独立App/runner、场景专属新UUID、初始化前offline守卫、自制fixture和同一共享heavy lock。实际包来源为21d7bf78b79b3a073eb3c7db8dd06a69d8f4c384；仅忽略副本加入DOCX零面板接线和诊断方法、MOBI绑定该次UUID及打印，原方法/比较保留。App在自身临时根记录自己的PID；未读其他App、用户书库/笔记/key、系统剪贴板或内部数据库。

| 单次代表 | UTC命令范围 | 正式结果 | 方法耗时与边界 |
| --- | --- | --- | --- |
| NativeUITests/testDOCXErrorValueTypeNoPanelProbe（新增诊断，非完整旧方法） | 13:50:18.276769–13:50:57.020850 | 1 FAIL，exit65，0 SKIP | 25.479650秒；辅助证据label为空，20秒等待及空JSON解析失败，原状态读取未达。 |
| EbookFormatUITests/testMOBISelectionNoteProgressRestart（原方法） | 13:54:20.597358–13:55:35.142696 | 1 FAIL，exit65，0 SKIP | 64.688150秒；唯一正式失败是原10秒三条件等待，之后重启/回源原断言无新增失败。 |

正式summary、tests、test-details与活动均已读取，两个唯一方法各开始一次，retry0；没有App或runner崩溃记录。DOCX合成worker只由一次真实按钮点击启动，未调用任何文件面板；MOBI原流程的退出/重启是该单个方法的一部分。两个新结果路径均收尾，不覆盖此前full60、13项、日语probe或AX组件对照。

## MOBI的三条件实际值

原三表达式逐字节保留，仍必须全部AND：

| 条件 | 原预期 | 原等待时真实值 | 布尔值 |
| --- | --- | --- | --- |
| book.format | mobi | mobi | true |
| note.userText | Original ebook observation | regional eBook | **false** |
| progress.quote | 第二章首字符O | O | true |

原日志只记录这组一次，没有通过延长等待或删条件获得通过。代码中EbookWorkspace把draft交给EbookLibraryModel.saveNote，EbookNote直接保存userText，repository追加同一note；没有发现把此ASCII正文改为regional eBook的持久化转换。此前设置/凭据的typeText与原生合成粘贴对照已经实测支持输入驱动问题；这里取得正文不等值的直接事实，与该诊断一致，不能用它统一判定其他三个格式或排除所有产品问题。

单次方法随后正常重启并检查保存的anchor/progress字典等值，再回到笔记原文。**最终manifest不是上述等待时快照**：它的progress已合法变为回源选区“Original”（26–34），与该saved note的anchor完全相同；userText仍regional eBook。分别保存原等待日志与自己的最终manifest，不误把回源后progress变化记为第二个原条件失败，也不猜测旧UUID或枚举其他临时库。

已作最小测试驱动修正：EbookFormatUITests共用flow把原typeText换成既有输入组已使用的原生合成粘贴，只写预期原创字符串、不读/备份系统剪贴板、不切输入法。保存前新增一次XCTUnwrap，要求AX正文UTF-8完全等于Original ebook observation；否则该方法先失败，不继续保存错误fixture。原format/body/progress三个比较、AND、10秒等待、非nil、重启与来源断言全部保留。没有更改EbookWorkspace、reader、domain或repository，也没有修改已执行的忽略副本/GUI二进制来抹去失败。

原4文件全部700个XCTest断言表达式按原顺序保留，新增该正文检查后为701；原60方法名称/数量保持。新驱动本次仅编译，**四格式仍未取得修正后GUI通过结果**，不能把此次原MOBI失败改标PASS。

## DOCX已知事实与未取得的字段

旧full60实际AX文本已经含“DOCX 归档损坏、不安全、加密或含...”，因此不能归因于未发布预期错误。本次零面板场景使用真实ConversionModel.start和同一ConversionWorkspace状态Text、完全相同29字节损坏fixture及自己的不存在输出路径，不经过原7项受阻面板服务。

这次新增诊断在辅助docx-probe-evidence字段只读label，得到空字符串，继而空JSON解析失败；这是诊断代码的遗漏。原conversion-status的value动态类型、String值、label和原helper contains均**NOT-REACHED**，不能从这次结果给它们填false/true，或声称原DOCX等待已解决。自己的损坏文件字节未变、输出不存在，只是文件事实；GUI中的worker终态证明未读取。具名文本附件只包含100字节自有App query chain，未补齐真实字段，没有导出图片或全包diagnostics。

为把模型层与AX读取缺口分开，新增纯模型测试用同一损坏bytes调用真实ConversionModel.start；不创建View、NSHostingView、窗口、AX客户端或面板。实际记录：status为“DOCX 归档损坏、不安全、加密或含当前不支持的 ZIP 结构。 可以重新选择位置再试。”；containsExpected=true、workerStopped=true、isBusy=false、resultPresent=false、outputExists=false、sourceUnchanged=true，根内只有原件。连同既有失败后恢复测试，**2方法/1 suite PASS，exit0，0.022秒**。它验证生产者及本地事务行为，不能代替UI字段或原完整转换/HTML流程验收。

新诊断另准备最小修正patch：把原状态value/label/helper记录与原等待移到辅助JSON读取之前，辅助文本复用已有value优先/空值回退label的textValue。修正候选独立保存，原已执行insert、project和二进制保持。候选类型检查先因漏XCTest Swift overlay路径退出1；保留该失败，随后使用成功Xcode命令的同一overlay路径在共享锁内退出0，仅有原未用变量警告。**这是已可审阅/类型检查的诊断修正，NOT-RUN；没有第三次GUI。** 没有据此猜测修改生产状态Text、其label/value或共享waitForText。

## 验证、交付与剩余门槛

修正后Mac arm64 build-for-testing退出0 / TEST BUILD SUCCEEDED，编译原60方法到全新PersistenceFixCompile目录；CODE_SIGNING_ALLOWED=NO，普通包产物仅用于编译，未启动，不代替已隔离的GUI产品。两个模型测试及上述诊断类型检查通过；sourceguard和diff-check收据见最终outcome。只改EbookFormatUITests测试输入、ConversionTests纯模型证据和文档；生产文件及Unicode来源/草稿/3与6预算/零自动重试不变。

仍有16个原失败方法没有实际清除：此前凭据/日语/DeepSeek4、保存面板7、电子书4、DOCX错误1。日语AX路线已暂停，不追加权限或空读probe；保存面板7保留系统服务崩溃阻塞。完整60历史仍33 PASS/27 FAIL/0 SKIP，13项历史9/4/0、两日语probe0/2/0及基线组件对照INCONCLUSIVE均保持，不将不同候选的小范围结果合并成全量通过。下一最小缺口为修正后电子书代表的实际输入/三AND闭环，以及DOCX原status的字段读取；本次授权次数已用完。

全部已记录旧PID及本次App90824/90880/90900、runner90819/90879、xcode90816/90874已退出，锁空闲；main仍6a67，未跟踪Xcode metadata、原full60日志/产物、19自制截图、原两次AX对照与本次失败GUI产物哈希保持。没有新截图或有效library_file_id。npm仍等待批准、两ebook Node仍NOT-RUN；没有安装、真实API/用户数据、系统权限更改、安全专项重试、全suite、发布或全仓审计。runner原误记90877已按执行收据更正，收据未改；后续两项新授权单次复验见[最终有界交接](MAC-UI-BOUNDED-RETEST-HANDOFF-2026-10-06.md)，本报告0/2/0保留为修正前阶段结果。

证据位于主仓库 `.build/MacUIExperience/2026-10-06/evidence`：persistence-probes-plan.json；persistence-{docx,mobi}-once-command.json / .log及对应summary/tests/test-details/activities；persistence-probes-pre-fix-protection.json；persistence-mobi-own-manifest.json；persistence-fix-assertion-protection.json；persistence-fix-model-unit-command.json / .log；persistence-fix-mac-compile-command.json / .log；persistence-docx-diagnostic-correction.patch及typecheck两份原始收据；persistence-fix-outcome.json、PARENT-STATUS-PERSISTENCE.json、FINAL-RECEIPT.json。完整既有门槛见[体验/整合报告](MAC-UI-EXPERIENCE-2026-10-06.md)和[失败分组](MAC-UI-INPUT-GROUPS-2026-10-06.md)。
