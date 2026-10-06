# 两项日语AX限定probe · 2026-10-06

已按单项一次、独立UUID/结果路径执行两个批准的probe，**两次正式结果均FAIL，0 PASS / 2 FAIL / 0 SKIP（两份独立结果的合计）**；没有重跑第一项，也没有运行全13/60、7保存面板或DeepSeek/MOBI/DOCX后续probe。原完整60仍33/27/0，最近原方法13项仍9/4/0；没有解除任何原日语方法的失败。已提交的700断言、60原方法和所有AND谓词保持逐字节，生产代码未改。

## 每项实际结果与边界

| Probe | 正式结果/耗时 | 实际到达 | 首失败与未验收 |
| --- | --- | --- | --- |
| JapaneseInvalidBudgetExactIDProbe | FAIL，25.314807秒，exit65，方法start1次 | 真实PDF选文和offline假凭据准备完成。 | 我新增的checkpoint向App临时库写诊断文件，被runner权限拒绝（NSCocoaError513/EPERM）；发生在startJapaneseReview之前。invalid错误、预算1/3和相关功能未测。无截获请求记录；正式失败不是App崩溃。 |
| JapaneseEPUBRubyComponentExactIDProbe | FAIL，59.091926秒，exit65，方法start1次 | 真实EPUB第2章ruby存在，原生选文“日本語”；手动确认/开始，单次截获请求，authMatchesFixture=true、payloadValid=true、attemptNumber=1。结果状态“收到可审阅建议”和组件source控件存在的等待已结束。 | 读取组件source AX value时失去PID87459 App连接并崩溃；原句组件UTF-8一致性尚未完成，点击解释、预算和请求后ruby未到达。没有保存manifest，不以无保存或未崩的部分步骤替代功能通过。 |

第一项失败后保留已执行的源码/产物SHA、xcresult和日志；仅把忽略目录测试副本的checkpoint改为标准输出，再编译并首次执行第二项。没有移除功能断言、放宽权限或重跑第一项。第一项新增诊断写文件是本轮驱动错误，当前stdout版invalid功能仍NOT-RUN。

## 本次专用App崩溃证据

只从第二项方法activities中取得一个去重后的具名.ips附件；header/body bundleID都等于org.pdfno.integration.inputprobe20261006.PDFnoMac，PID87459，loaded PDFnoMac.debug.dylib UUID匹配当前隔离产物。没有扫描系统DiagnosticReports、其他App、sessions或内部数据库。

故障为主线程EXC_BAD_ACCESS/SIGSEGV、KERN_PROTECTION_FAILURE，98帧；SwiftUI AccessibilityNode.accessibilityLabel非objc函数重复5次。链路为XCTAutomationSession attributesForElement → AXUIElementCopyMultipleAttributeValues → AppKit属性读取 → SwiftUI label/role解析重复求值；自有frame仍仅App入口，没有provider/parser/repository/fence frame。与此前两App的label递归机制一致，但**本次栈没有旧XCElementSnapshot.identifiers/title或NSComparisonPredicate/KVC筛选frame**。

实际失败位置是textValue中读取japanese-components-source.value（随后才可能fallback label）。这证明精确identifier查询未能消除直接AX属性读取时的App崩溃；不能宣称只改测试查询就修好了产品/平台问题。框架栈还不能确定确切递归视图节点或系统与产品modifier贡献。

静态范围已收窄到JapaneseSentenceComponentsView的原句Text：AttributedString内部链接、textSelection(enabled)、显式accessibilityLabel及其在JapaneseLearningWorkspace Form中的组合。这里只标记下一步取证范围，未改该产品视图、未删除label/文本选择/色标或绕开真实来源读取。

## 隔离、保护与编译

每份xctestrun的target和runner环境在最初启动前绑定同一个新UUID/offline，dispatch前该root不存在；helper只启动明确的专用bundle，并在假凭据前核对offline标志。App初始化仍强制临时Library与offline；transport没有网络fallback。只写合成剪贴板，不读原剪贴板。签名使用既有ad-hoc配置，没有系统主题/权限/账号变更。

两项分别90/120秒上限、only-testing一个方法、parallel=NO、默认单次，没有网络/方法自动重试。第二项平台内部出现一次matching snapshot retry，但方法start仍只有一次，transport也只有一次。keepNever截图配置保持；Xcode保留了具名崩溃附件，未生成/导出新的截图。

最终两个probe编译PASS；首次受执行沙盒限制的build exit66、xcresulttool TestReport缓存写入失败也保留，后续仅编译/metadata读取获得已有授权的执行准入，不计GUI复测。App主程序SHA始终129f390f6a1e2188419e423792fd1fce13948aa0ecb19201a41dc713e794ae85，主程序及debug dylib在两次GUI之间均未变；第一项与第二项测试产物SHA单独保存，避免把诊断修改后的产物冒充第一项源码。

已核验所有已知专用旧/新PID结束、共享heavy锁空闲；main仍6a67d1f、未跟踪Xcode metadata保留。19既有截图、完整60日志和3个原产物SHA不变。Library没有有效library_file_id；npm仍未批准且未重试，没有安装、全仓审计或push/dispatch/merge/发布。

## 下一步（只提议，未执行）

当前两项未通过，后续GUI停止。先静态检查上述日语原句AX节点，只有证据支持时才做最小产品修改并单元/编译验证，保持原文、链接/颜色、原生可访问性、来源fence、预算和零自动重试。后续新的GUI取证需另行明确方向：stdout版invalid单项仍需功能验收；EPUB必须真正完成组件来源UTF-8、点击解释、预算与ruby检查。DeepSeek viewport、DOCX动态value、MOBI三谓词以及保存面板组保持待验，不扩大到整组。

## 本地证据索引

主仓库 .build/MacUIExperience/2026-10-06/evidence：

- ax-probes-dispatch-plan.json、ax-probes-initial-admission.json：新UUID、专用bundle/产物、两个精确命令及实际次数、退出/后态。
- JapaneseInvalidBudgetExactIDProbe.xcresult、JapaneseEPUBRubyComponentExactIDProbe.xcresult：两份正式结果；ax-probe-{invalid,ruby}-ui-command.json/.log及summary/tests/details/activities.json。
- ax-probes-native-base-909ee03.swift、ax-probes-native-invalid-executed.swift、ax-probes-native-insert.swift：已提交基线、第一次实际源码、第二次stdout诊断插入；原方法只是忽略副本中插入新方法。
- ax-probe-ruby-own-http.json：唯一截获请求的Boolean/次数，不含真实key/payload。
- ax-probe-ruby-crash.ips、ax-probe-ruby-crash-export-command.json、ax-probe-ruby-crash-analysis.json：具名崩溃、身份/代码UUID及98帧原分析。
- ax-probes-build-{only,admitted,bound}-command.json、ax-probe-ruby-build-stdout-command.json：编译过程与最后PASS。
- ax-probes-outcome.json、PARENT-STATUS-AX-PROBES.json、FINAL-RECEIPT.json：结果边界与最终本地提交。此前[取证报告](MAC-UI-CRASH-AND-DRIVER-DIAGNOSIS-2026-10-06.md)保持其未GUI阶段的历史结论。
