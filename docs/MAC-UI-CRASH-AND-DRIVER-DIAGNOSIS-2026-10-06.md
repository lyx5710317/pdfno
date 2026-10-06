# 专用App崩溃与测试驱动取证 · 2026-10-06

该文记录单元/编译阶段；后续已批准两个限定GUI probe，实际均FAIL，结果与新崩溃见[两项AX probe报告](MAC-UI-AX-PROBES-2026-10-06.md)。下文未GUI结论保留其阶段边界。

本轮只读取InputGroupsOnce.xcresult里两项日语App和对应runner的3个具名.ips附件，实施有证据的测试驱动修改，运行Foundation契约单元测试并编译。**没有启动App/GUI复测，没有将4项失败改为通过；生产代码未改。** 最新实际GUI仍13项9 PASS/4 FAIL/0 SKIP，历史完整60仍33/27/0。

## 崩溃机制与隔离身份

| 对象 | 专用身份/实际进程 | 栈和终止 | 已确认与未确认 |
| --- | --- | --- | --- |
| 日语Invalid/Cancel App | inputprobe PDFnoMac，PID60099 | 主线程EXC_BAD_ACCESS/SIGSEGV，KERN_PROTECTION_FAILURE落在Stack Guard。 | XCTest标识查询触发SwiftUI/AppKit label重复求值；确切递归视图节点/系统与产品修饰符贡献未定位。 |
| 日语EPUB/Ruby App | 同专用bundle，PID60238 | 同上；两故障线程均113帧、accessibilityLabel重复5次。 | 相同AX label机制，不能据此称API、来源或保存链崩溃。实际GUI是否消失未复验。 |
| 日语Component runner | 专用PDFnoMacUITests.xctrunner，PID59919 | 主线程EXC_BREAKPOINT/SIGTRAP，XCTestCore XCTCrashLogTracker.waitForPendingCrashlogs。 | teardown等待崩溃日志时的独立runner故障，随后Xcode恢复继续剩余方法；不是第三项App同栈，也不是方法重跑。 |

每个附件的header/body bundleID均精确匹配本任务专用ID；两个App的loaded PDFnoMac.debug.dylib UUID都匹配已核验构建，路径被系统隐私脱敏，未用脱敏路径字符串误判其他App。没有扫描系统DiagnosticReports、私人其他App、sessions或内部数据库，没有导出全包diagnostics/图片。App加载的初始化守卫保持UUID临时Library/offline；这些栈不支持默认用户库/正式App误启动的诊断。最早另一个开发App启动偏差仍是历史UNKNOWN，不因本轮取证被抹去。

关键故障链（两App相同）：XCTFilteringTransformerIterator → NSComparisonPredicate/NSKeyValueCoding → XCElementSnapshot.identifiers → title → XCTAutomationSession属性读取 → SwiftUI AccessibilityNode.accessibilityLabel/valueForAttribute → AppKit关联属性读取；故障在objc关联对象查找与栈保护区。自有代码仅App.$main和入口，故障线程没有provider、AI解析、repository/fence或来源保存frame。框架栈说明触发机制，不能证明产品视图配置完全无责任。

Native旧japaneseElement使用matching(identifier:)，其实际IN identifiers查询会包括title/label别名；这与捕获栈一致。最小缓解改为NSPredicate的identifier == %@，精确读取目标AX标识，避免为标识筛选去读任意标题；保留可访问性、文本选择与内容。没有禁用AX、改系统权限/注入环境或签名账号。真实XCTest快照是否还在其他路径触发label递归仍待少量probe，不能声明App崩溃已经修复。

## 已实施驱动修改与单元验证

- Native japaneseElement改为精确AX identifier谓词，不接受相同label/title的错误控件。
- DeepSeek在PDF和EPUB确认/开始前调用现有scrollRecordElement检查物理viewport，EPUB开始前保留启用等待；原XCTest断言、用户consent与来源guards保持。此前真实AX确认框Y799.5–816、开始Y828–858，视口底794；value0/startDisabled/预算仍1/3证明第二请求未开始，不能归为结果角色缺失。
- DOCX不猜测动态value类型、不改原waitForText：只在原等待前后记录同一个self-fixture status的exists、value类型、String值与label。旧真实AX前缀含归档损坏，证明错误已发布；旧helper实际读取什么和视图更新warning的贡献未知，所以这里只加诊断，不声称根因已解决。
- Ebook只把同一原format/body/progress三比较分开输出实际值和布尔值，变化时记录一次；原三比较逐字节相同且仍必须全部AND，10秒等待、非nil和重启/来源断言不变。未知测试UUID不猜测、不枚举其他/tmp库，只有原helper自己UUID的manifest读。

新增UITestIdentityPredicateTests实际调用Foundation/KVC与带getter计数的NSObject快照：3方法/4参数分支/1 suite PASS、exit0。证明精确谓词不访问title/label、label别名不会误匹配、带引号标识仍当数据；这是实际SDK谓词契约验证，不能代替真实AX或GUI崩溃验收。Mac arm64隔离build-for-testing PASS（补齐DOCX前后快照后的最终编译也PASS），未运行App。全部旧XCTest断言表达式与60方法名称/数量保持；原628及NextBatch48保持，Ebook所有原断言也保持。生产源码、Unicode来源、fence、草稿、3/6预算、零自动重试不变。

本轮编译只更新测试产物，App SHA仍129f390f6a1e2188419e423792fd1fce13948aa0ecb19201a41dc713e794ae85。最新实际13项源码是28a7c92，当前候选是后续已编译未GUI实测的驱动变更；不把旧9/4/0当作当前变更已通过。原完整60产物、结果及19截图不变，main仍6a67d1f、Xcode未跟踪metadata保持。所有重型动作共享锁内，已经结束，未派发GUI。

## 精确少量probe方案（只拟定，未执行）

第一阶段建议只做两个独立单次probe，每个新的UUID、结果路径、专用bundle和共享锁，单probe首崩溃结束，不默认继续下一probe：

1. 日语invalid预算AX：仅原invalid第一场景，真实PDF选文、手动确认和一次截获请求；原错误+预算1/3/no saved manifest，精确标识读。90秒；不运行slow第二场景或完整方法。
2. 日语EPUB/ruby AX：仅原创ruby选文、一请求、结果状态/组件source精确读及原Unicode/ruby来源检查。120秒；不重跑整条保存/重启链。

这两个probe结果先回报，之后再单独决定：一个EPUB DeepSeek viewport/确认/typed结果probe120秒（确认和来源有效后最多一次提交）；一个DOCX零保存面板真实ConversionModel.start/同status视图读取probe60秒；一个现有instrumented MOBI原方法180秒（原typeText、三AND与所有断言保持，只获取真实三值）。这些probe不能冒充完整旧方法或整组通过。具体步骤/guard和次数见crash-next-small-probes-plan.json；没有在本轮执行或注册自动任务。

保存面板7继续单列，不跑面板循环；安全专项UNVERIFIED/platform-blocked不重试。npm未批准、未安装，两ebook Node仍NOT-RUN；没有真实API/用户库/系统改动、全仓审计、push、dispatch、merge或公开发布。Library上传仍阻塞，只有既有本地截图，没有library_file_id。

## 证据索引

根目录：主仓库 .build/MacUIExperience/2026-10-06/evidence。

- crash-{invalid,ruby,runner}-activities/details-command.json/.log、crash-specific-attachment-metadata.json：具名方法metadata，runner详情另提供23.503秒，此前简表方法树未记录该值。
- crash-{invalid,ruby,runner}.ips与*-export-command.json/.log：3个原具名崩溃附件，SHA见crash-specific-stack-analysis.json。
- crash-specific-recurrence.json、crash-isolated-binary-identity.json：重复AX栈、故障线程及bundle/二进制UUID身份。
- crash-driver-fix.diff、crash-driver-assertion-protection.json：驱动与诊断最小diff、原断言及三条件保护。
- crash-identity-predicate-unit-command.json/.log、crash-driver-build-{only,with-final-diagnostics}-command.json/.log：实际单元测试与两次编译结果。
- crash-driver-diagnosis-outcome.json、crash-next-small-probes-plan.json、FINAL-RECEIPT.json：本轮边界、未执行probe与最新提交。

前次13实际结果与逐项日志见[分组报告](MAC-UI-INPUT-GROUPS-2026-10-06.md)。本轮得到具体崩溃触发机制和最小驱动缓解，仍未得到真实GUI修复验收。
