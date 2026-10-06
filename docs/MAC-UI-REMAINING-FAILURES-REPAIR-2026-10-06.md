# 剩余失败修复与平台阻塞 · 2026-10-06

**本轮没有清除新的原 UI 方法门槛，剩余仍为11。** 文件面板的两种测试驱动候选均实际失败并已撤回；日语原生文本候选已通过完整552项 Swift 回归，但隔离 XCTest runner 在启用自动化模式时超时，原方法尚未开始、App没有启动，因此不能宣称日语 AX 或完整 UI 已修复。历史四个原方法 PASS 与完整60项33 PASS/27 FAIL/0 SKIP均保留，不能跨源码批次拼成完整验收。

用户15:39UTC“继续修复这些失败问题”授权本地修复和有界隔离验证。本轮由 `74baf766d99deb00a2dee2ffdea5a72ae30fdf75` 开始，实际命令连接/状态检查成功；继续在 `feature/mac-ui-experience-20261006` 的原持久独立树工作。main仍为6a67，未跟踪Xcode workspace metadata保全。没有修改系统输入法、主题、TCC或其他安全权限，没有终止系统服务、安装组件、切换验证环境或执行公开操作。

## 文件面板与 DOCX 共用链

原七个面板失败都在原创路径已粘贴、PathTextField等值断言通过后，经Return提交路径时发生。原工程pbxproj与6a67逐字节相同；旧完整60和四项复测App的实际签名及Xcode测试生成entitlements相同，均为本地ad-hoc、无Team。最小基线组件harness并非UI测试构建，其entitlements不同，不能当作同条件基线。没有为诊断增加entitlement、关闭sandbox或降低系统保护。

| 候选 / 原完整方法 | 实际结果 | 结论 |
| --- | --- | --- |
| `c85ca91`：对PathTextField发送Return；`testMacDOCXConversionFailureRecoveryAndEscapedHTML` | FAIL，exit65，30.428834秒；1次method start、1个正式run、0 SKIP、0重试。 | 改Return目标没有消除面板服务崩溃。其余七方法未派发。 |
| `78de368`：点击实际Go/前往动作；同一原完整方法 | FAIL，exit65，34.878905秒；1次method start、1个正式run、0 SKIP、0重试。 | 此平台没有可命中的Go/前往按钮，等待超时；未发送Return，原完整流程未通过。其余七方法未派发。 |
| `5166c7e` | 撤回上述两个候选。 | 当前NativeUITests.swift恢复为74baf766逐字节相同；失败提交、隔离副本、产物和结果包保留。 |

只从第一场自己的结果包导出一个具名服务`.ips`，没有扫描系统DiagnosticReports或导出面板截图。其header/body确认：服务为`com.apple.appkit.xpc.openAndSavePanelService`，PID94126，responsibleApp PID94119，coalition为本场专用bundle；异常为EXC_BREAKPOINT/SIGTRAP。异常回溯始于`NSTextStorage ensureAttributesAreFixedInRange:`，包含`NSTextInputContext.handleTSMEvent`及56个输入事件相关帧（包括重复的`IMKInputSession_Modern.coreAttributesFromRange`）。这提供了系统面板文本存储／输入事件异常的直接证据；异常的具体range及完整触发条件尚未确认，不能据此排除产品或驱动贡献，也不能断言签名或权限是根因。

服务日志SHA256：`3be026d3115df7961c9f42d74f0fd11ed7f0fa6d4ec42b3148d8e7d1603ae1d7`。详见`panel-repair-service-crash.ips`、`panel-repair-service-crash-analysis.json`及导出命令收据。原DOCX零面板诊断此前的PASS不替代含面板、恢复与HTML转义的原完整方法。本轮没有新增产品导出hook或绕过保存面板来宣称通过。

## 日语原生来源候选

本地代码提交 **`024703e7b291555ed405d5d8cba2a0b5dcfd1db7`**，相对74baf766净代码差异仅三个文件：`JapaneseSentenceComponentsView.swift`、新增`NativeJapaneseSourceText.swift`和对应两个单元测试。Mac原句改由原生只读、可选文NSTextView展示，保留原`japanese-components-source` identifier、精确quote的label/value、候选颜色／本地链接和选区；没有隐藏来源AX节点，没有额外复制来源替代字段，没有删除原断言。iOS保留原SwiftUI Text路径。

这针对旧实际来源查询进入SwiftUI role/label重入链的证据，但具体递归节点仍未证实。领域、provider、repository、reader、来源fence、Unicode比较、3/6预算、草稿和零自动重试协议不变。两个新测试在真实原生文本对象上反复读取公开role/label/value，严格UTF-8核验组合字符及emoji，重绘保留选区；链接delegate仅处理本地候选，其他URL不打开。它们没有创建窗口或App scene，不能代替宿主真实布局和AX验收。

| 验证 | 本轮结果 / 边界 |
| --- | --- |
| 新原生文本回归 | 2 tests / 1 suite PASS；公开原生AX getter与选区、URL处理。 |
| 相关日语领域／投影／unavailable回归 | 20 tests / 3 suites PASS。 |
| 完整Swift | **552 tests / 70 suites PASS**，41.699秒；共享heavy lock、2 jobs、no-parallel。 |
| Source guard（代码候选） | 701 files PASS。 |
| 收尾Source guard／diff-check | 报告加入后702 files PASS；diff-check PASS。 |
| 专用Mac arm64 ad-hoc build-for-testing | PASS；原60项UI方法已编译。 |
| Mac arm64+x86_64 build-for-testing | PASS；新独立JapaneseNativeMacCompile产物，CODE_SIGNING_ALLOWED=NO，未启动App。 |
| iOS Simulator双架构编译 | **NOT-RUN / 自动审批拒绝**：用户明确将mobile后置，当前Mac修复授权未覆盖提前移动检查。wrapper、xcodebuild和模拟器均未启动；未换路重试。如需现在补做须新增明确授权。 |
| 原日语EPUB/ruby方法的单次隔离派发 | exit65；**runner system failure，method start 0，App start 0**，自动化模式初始化60秒超时。正式summary的1 failedTest为runner错误，不是执行过的原方法断言失败。 |
| 其余两日语原方法 | 未派发；主方法未执行成功后停止，不重试，不另建空AX probe。 |

此次专用bundle为`org.pdfno.integration.japanesenative20261006.PDFnoMac`，App与runner路径及签名核验，包内407文件逐字节等于024703e Git archive。App在scene前要求专用bundle、新有效UUID、offline和允许scope；每方法临时库独立，invalid/slow两场另有不同新UUID。仅忽略测试副本三个UUID初始化绑定runner环境，原方法与全部断言不变；不使用真实API、key、书籍或笔记。

第一场UUID `D7BD0695-6CFB-475E-AD93-F7A67A86DE10` 对应临时root在派发后仍不存在，专用入口未留下App进程记录；实际日志只有xcode PID2660和runner PID2663，均已退出。正式summary/tests保留。按原方法identifier读取test-details失败，是结果树不存在该方法；该读取错误和stderr单独保留，没有覆盖或重跑GUI。`japanese-native-jepub-classification.json`准确标记`PLATFORM_BLOCKED_BEFORE_METHOD`、0执行原方法及1系统失败，不能标记为日语PASS，也不能追加一个原方法断言FAIL。

## 仍未验收的原方法与后续条件

11个精确原方法名单保持[前阶段报告](MAC-UI-REMAINING-FOUR-2026-10-06.md#11个剩余原方法)：日语3、保存面板7、DOCX完整1。本轮未重新运行其他七个面板方法、AZW/AZW3/FB2/DeepSeek、MOBI或完整60。需要先获得正常可用的隔离XCTest自动化会话，才可实际判断日语候选；文件面板仍需一个可复现、证据支持的修复。若后续诊断确实需要修改系统输入法／安全权限或迁移验证环境，该操作须另获用户明确授权。本轮未做这些操作，也没有将它们认定为唯一解决方案。

收尾已核验12个旧／本轮专用App、runner、test二进制以及忽略副本／xctestrun哈希，历史完整60产物和日志不变；此前四项PASS日志与16份正式元数据SHA不变。全部本任务精确拥有PID不存在，共享heavy lock空闲。main HEAD和未跟踪metadata状态不变；原60方法、700原断言及新增1个严格正文守卫保留。没有额外GUI/probe在运行或排队。

用户要求的**验收后全仓审计已获条件授权，完整验收尚未达标，未启动**。npm/jsdom、Library官方上传、真实模型／schema／解释质量、VoiceOver／输入法人工流程、Intel实际运行、移动实际UI及损坏库／加载错误等原有门槛保持；安全专项UNVERIFIED/platform-blocked不重试。19张历史自制截图仍仅按本地路径交付、SHA不变，无新增截图或library_file_id。

证据根目录：主仓库`.build/MacUIExperience/2026-10-06/evidence`。本轮核心索引为`remaining11-single-admission.json`、`remaining11-signature-comparison.json`、`panel-repair-plan.json`、`panel-go-plan.json`、两个`*-docxfull-once`日志／command收据及正式summary/tests/test-details/activities、服务具名IPS与收据；`japanese-native-plan.json`、`japanese-native-assertion-protection.json`、`japanese-native-jepub-once`日志／收据／summary/tests/classification，Swift和编译命令收据；最后的`remaining11-repair-outcome.json`、`remaining11-repair-post-run-protection.json`、`PARENT-STATUS-REMAINING-FAILURES-REPAIR.json`和`FINAL-RECEIPT.json`。原结果包分别为`Panel-repair-docxfull-once.xcresult`、`Panel-go-docxfull-once.xcresult`、`Japanese-native-jepub-once.xcresult`，不覆盖历史结果。
