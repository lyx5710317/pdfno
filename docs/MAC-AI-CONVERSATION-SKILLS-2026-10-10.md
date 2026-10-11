# 阅读页精简、AI连接与五项选文对话

本轮受影响的四个离线 GUI 场景已在同一编译候选上全部通过：**4通过、0失败、4项执行、0跳过**。产品源码为 `f029e2e6440b1dddb4d2e493f79110f9695187a2`，分支 `feature/mac-ai-conversation-skills-20261010`。报告提交只更新文档；唯一既有离线预览的最终构建和版本身份以 `Evidence/PREVIEW-BUILD-RESULT.json` 与 `XcodePreview/PREPARATION.json` 为准。

非AI侧栏去掉重复表头与关闭行，沿用右侧按钮切换；AI表头保留。侧栏显示 bookno，＋跟随文档标签，零标签时紧邻返回按钮。保留已验收的 Aa 阅读模式、笔记与批注、书签和原生窗口工具栏。

设置→AI集中服务商、API URL、会话API Key、模型与连接测试，高级协议、范围及预算折叠。连接测试使用内置原创短句，不发送书籍或对话。会话凭据不回填、不写入磁盘；更换接收地址撤销已有凭据引用。设置→AI工具独立控制日语、英语，两者默认关闭；解释、翻译、总结始终可用。关闭工具保留已有回答和笔记。

五项任务使用现有编译型Skill注册表的不同指令。点击任务自动开始固定选文的第一轮回答；原文可折叠，对话与追问分区。停止取消真实异步任务，重试由用户显式发起；操作令牌约束重复发送与迟到结果。浮层与右侧AI面板复用同一对话；关闭文档取消并清除会话，重开应用不恢复聊天历史。

输入范围限制为选文最多500字符、追问最多1500字符、同线程历史最多12条且总长最多10000字符。来源、文档会话和对话身份绑定；现有禁止额外上下文的Skill输入计划与manifest保持原字节。每条回答有复制与显式加入笔记，稳定回答ID避免重复保存。笔记保留原文锚点和任务类型，旧笔记格式兼容。五项对话是普通文本结果，不宣称经过旧日语ruby/语法或英语结构化校验器；真实API与AI质量未验证。

原生标题栏的空白区明确接收mouseDown并沿用performDrag；仅添加四行手势归属修正，原工具栏所有权与其余逻辑保持。GUI保留真实窗口位移大于8点的原断言并通过。EPUB在原生bounds变化前捕获规范阅读位置，再传入现有浏览器resize命令，避免面板宽度变化后读取已经重排错位的进度。原日本语来源可见性失败已在实际WebKit中复现并修复，GUI不添加辅助原文跳转来掩盖位置问题。

## 当前验证

`SWIFT-CONVERSATION-12`：**60/60定向Swift方法通过**，包含对话契约、原生模型、停止/重试/迟到结果、凭据撤销、显式存笔记与去重、默认关闭、便签、真实标题栏命中、EPUB面板重排/章节/选文来源。`JS-REFLOW-QA06-02`：**7/7原JavaScript检查通过**，测试源码、188项引擎输入清单和许可文件保全。历史重叠套件不能相加。

`QA12`使用专用bundle `org.pdfno.integration.professionala20261007.qaef7c9556c9ad.PDFnoMac`，arm64、严格临时签名、空app权限，仅自制样本与独立临时书库，网络和Keychain传输拒绝真实操作。四项原验收全部执行：

| 原方法 | 窗口与外观 | 结果 |
| --- | --- | --- |
| Chrome窄窗：溢出、bookno、其他格式面板、完整长标题导入 | 720×520深色 | PASS，104.400秒 |
| Chrome宽窗：无表头面板、便签保存/取消、AI表头、＋、真实拖动 | 1280×800浅色 | PASS，109.820秒 |
| Conversation窄窗：独立设置、默认关闭、关闭工具保留回答 | 720×520深色 | PASS，68.384秒 |
| Conversation宽窗：连接、五任务、停止/重试、追问、复制、显式笔记与来源 | 1280×800浅色 | PASS，135.921秒 |

2026-10-11 **06:28:45 UTC**确认app、runner、xcodebuild均已退出，桌面释放。20张自制应用窗口截图在 `GUIValidation/conversation-qa12-ImmediateWindowShots/`；未截桌面或操作生产App。四个运行会话的bundle、源码与二进制身份逐一核验。没有自动GUI重试、继续输入或延长桌面交接。

完整192字符路径保持。实际GoTo层级的Go仅在TouchBar分支，不能当作实体按钮；实际表格补全行由精确identifier NSPredicate定位，避开SDK便捷标识符查询的128字符限制。该分组行不提供AXEnabled，按真实命中点与实体边界校验；原物理Open仍检查启用与可命中。原文件名、真实Open、导入、五标签、长标题和＋断言均保留并通过。SDK树、原生行边界、双击关闭GoTo及各失败原因均有实际证据。

105个原Swift测试文件保持原字节，70个Chrome与39个Conversation原断言保留。此前所有失败产品、xcresult、日志、截图和初始化诊断继续保留，没有用交叉轮次的通过数替代本轮四项门槛。主树a9dd7d4、未跟踪Xcode元数据及此前工作树保全。所有重型检查使用既有全局锁和单进程构建；无包安装。本轮没有新增缓存删除或权限/系统安全设置变更。

## 唯一运行入口与范围

继续使用原入口 `HomeSettingsRedesign/2026-10-09/OPEN-LATEST-UI-IN-XCODE.command`，工作区 **PDFnoLatestUI**，Scheme **PDFno Latest UI (Offline)**，Destination **My Mac**，Cmd-R。只更新这一个离线预览，保留旧14943ae源码检查点、旧构建与Registry/runtime，并核验原用户元数据；不自动打开Xcode或点击Cmd-R。正式源码项目直接运行可能选择普通书库，本任务只交付这个受保护的离线预览入口。

完整12/68/603回归与远程CI仍按当前任务范围暂停。旧ContinuousEPUB三方法/19项问题仍为 **UNRESOLVED**，clean-e0原始证据保留，不被本轮定向通过覆盖。无push、merge、发布、账号或权限设置操作。截图保留本地，无Library附件ID；没有安装Python、修改或绕过上传helper。

主要证据：`GUI-CONVERSATION-QA12-SUMMARY.json`、`GUI-CONVERSATION-QA12-TESTS.json`、`GUI-CONVERSATION-QA12-RECEIPT.json`、`QA12-EXIT-CHECKPOINT.json`、`QA12-OWN-NATIVE-MARKERS.json`、`QA12-FIRST-METHOD-PASS.json`、`SWIFT-CONVERSATION-12-RESULT.json`、`JS-REFLOW-QA06-02-RESULT.json`、`PRESERVATION.json`。报告原始初始化阻塞版本另存 `SOURCE-REPORT-QA01-AUTH-CHECKPOINT.md`。
