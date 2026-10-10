# AI 连接与五项选文对话候选

候选分支 `feature/mac-ai-conversation-skills-20261010`，实现提交 `b5e3d1181bd52fe0fc76e3e1d20b2c0a648d18ed`。基于上一轮 Aa 与阅读页精简候选 `a2a7963`，保留现有原生阅读、来源锚点、批注与书签能力。当前状态是已实现、定向检查通过、GUI 候选已编译；本轮 GUI 被 XCTest 自动化模式初始化超时阻塞，未验证或同步预览。

设置 → AI 集中服务商、API URL、会话 API Key、模型和连接测试，协议、范围及预算放入折叠的高级区。连接测试只向已应用的配置发送一条内置原创短句，不会把书籍或对话放入连接测试请求。密钥使用现有会话凭据所有者，不回填或写入磁盘。更换接收地址会撤销此前密钥引用。

设置 → AI工具有独立的日语、英语开关，默认关闭，不要求打开文档或选择原文。解释、翻译、总结始终显示；日语、英语只在开启后出现在选文菜单中。关闭开关保留已有回答和笔记。

五项任务映射现有编译型 Skill 注册表中的不同指令。新的对话计划明确验证固定选文和显式同线程消息：选文不超过500字、追问不超过1500字、历史最多12条且总长不超过10000字。来源、文档会话和对话身份绑定；不发送整本书、其他文件、外部检索或工具指令。原有禁止额外上下文的 Skill 输入计划和 manifests 保持原字节。

点击任务自动开始第一轮回答，折叠原文在上、对话在中、追问在下。停止实际取消请求，重试由用户手动发起；重复发送和迟到结果有独立操作令牌约束。关闭面板保留当前文件对话，右侧 AI 面板挂载同一模型；关闭文档取消并清除会话，重开应用不恢复历史。

每条回答提供复制和显式加入笔记，稳定回答ID避免重复保存。笔记保留原文锚点与任务类型，沿用已有提交围栏、存储和导出格式。旧笔记 JSON 可读取；没有破坏性迁移。原有日语、英语结构化审阅接口保留，新对话结果是五任务的普通文本结果，不宣称经过旧结构化 ruby/语法校验器。

本轮还加入两个上轮 GUI 问题的候选修正：笔记容器使用独立的辅助功能分组；便签原生控件禁用自动补全。后者根因尚未通过本轮 GUI 验证，因此不宣称旧文本丢失已经修复。文件导入测试快照增加原生前往路径提交和明确选择自制文件，原有测试源码及所有断言保留。

验证记录：`SWIFT-CONVERSATION-04` 53/53、`05` 52/52、`06` 18/18通过，组间重叠不能相加。新对话契约9项及原生模型9项通过；覆盖五任务 dispatch、来源/线程隔离、同意、停止/超时/迟到结果、凭据撤销、显式保存去重、默认关闭和未知设置格式保全。真实服务与 AI 质量未验证。四个受影响 GUI 场景已 build-for-testing 成功，arm64、严格临时签名和空权限检查通过，本轮于16:46 UTC开始，但四个场景均未进入。

专用 GUI bundle 为 `org.pdfno.integration.professionala20261007.qab31c906e93f5.PDFnoMac`，只使用内置原创内容和 `/tmp/PDFno-UITests-UUID`。快照网络和 Keychain 传输拒绝真实操作。所有重型检查使用原有全局锁、单进程构建，不安装工具或清理缓存。

105个原有 Swift 测试文件保持原字节；主树 `a9dd7d4` 与未跟踪 Xcode 元数据、此前精简候选均保全。完整12/68/603回归和远程CI暂停。旧竖排三方法/19项问题仍为 **UNRESOLVED**，其 clean-e0 原始证据没有被覆盖。上轮精简 GUI 0/2、7项失败及宽窗 signal kill 继续保留。

唯一现有 Xcode 入口仍为 `HomeSettingsRedesign/2026-10-09/OPEN-LATEST-UI-IN-XCODE.command`，当前源码14943ae；需受影响 GUI 通过后才同步。尚未自动点击 Cmd-R。没有推送、合并、发布、新账号、权限或系统安全设置操作。

证据在同目录 `Evidence`：`PRESERVATION.json`、`TARGETED-VERIFICATION-INDEX.json`、各定向日志与结果、`BUILD-CONVERSATION-GUI-01-RESULT.json`；四场景运行计划在 `QA01/RUN-PLAN.json`。

## GUI 阻塞与运行入口

2026-10-10 16:46:32 UTC 用户本轮交接后，检查器确认解锁、前台 Codex、输入空闲23.6秒、无其他测试进程，运行四项标准 XCTest。Xcode 在约72秒后报告：`The test runner failed to initialize for UI testing. (Underlying Error: Timed out while enabling automation mode.)`，退出65。官方统计0通过、1失败；这1项是 runner 初始化错误，不能写成四项产品断言失败。计划四个场景、实际执行0个；应用启动注册记录0、窗口截图0。

16:49 UTC核对专用应用、runner和xcodebuild均已退出，桌面释放。没有自动重试、替代输入方法、权限/系统设置变更。四场景运行计划及候选继续保留；重跑需要新的完整运行产物、可用的标准 XCTest 环境和新的桌面交接。旧 GUI 0/2、7问题和旧竖排3方法/19问题均不被此次初始化错误覆盖。

源码与 Xcode 项目在 `tree/apple`；已编译的离线 QA 项目在 `QA01/source/apple/PDFno.xcodeproj`，仅用于本轮隔离验证。正式源码项目直接运行可能选择普通书库，未授权这种运行方式。本轮不增加第二个用户预览入口。唯一已有运行入口仍是 `../../HomeSettingsRedesign/2026-10-09/OPEN-LATEST-UI-IN-XCODE.command`，源码14943ae；待受影响 GUI4/4通过后用已准备的预览脚本更新，再用既有 Scheme 和 My Mac Cmd-R。

预览更新脚本已有严格4/4门槛，尚未执行。真实服务/AI质量、GUI实景与完整12/68/603回归尚未验证。无本轮截图，无 Library 附件ID；未安装 Python、修改 helper 或构造附件ID。

追加证据：`Evidence/GUI-CONVERSATION-QA01-SUMMARY.json`、`GUI-CONVERSATION-QA01-TESTS.json`、`GUI-CONVERSATION-QA01-BLOCKER-RECEIPT.json`、`conversation-qa1.log`、`conversation-qa1-execution.json`。

## 标准自动化恢复诊断

追加只读诊断：runner与测试守护进程授权成功；本次阻塞位于其后的自动化模式writer。本任务导出的unified log记录 `Writer daemon requires authentication to enable automation mode.`，随后LocalAuthentication以 `Enable UI Automation` 为原因调用本机认证，60秒内未完成。此前成功Aa QA02使用相同Xcode2700/27A259、XCTAutomationSupport25228、runner权限和标准环境变量，开启模式在约12毫秒内完成；该成功时段没有要求本机认证的记录。尚未推断认证状态改变的原因。

`DevToolsSecurity -status`只读返回Developer mode disabled；守护进程明确授权成功，因此不把该状态单独当作根因，也不改动它。没有本任务runner、app、xcodebuild残留。系统testmanagerd保留，未杀死系统服务。没有清缓存、重置权限、修改系统安全设置或使用替代输入。

已准备一次新的标准手动重试，`QA01/RUN-PLAN-RETRY02.json`使用新的测试/截图nonce、xctestrun与xcresult路径，沿用已验证的专用签名产品和全部四场景断言。`run-gui-retry02.py`同时要求明确的本机认证授权与新的桌面交接，尚未执行。需要用户亲自处理macOS的Enable UI Automation认证提示；不会询问、接收或代输密码。授权回复待收到，依赖GUI的验证与预览更新继续暂停。

诊断依据：`Evidence/AUTOMATION-INITIALIZATION-DIAGNOSIS.json`、`QA01-OWN-PID-UNIFIED.log`、`SUCCESS-AA-QA02-AUTOMATION.log`及两次官方diagnostics导出。
