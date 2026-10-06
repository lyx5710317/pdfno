# 日语原句组件：6a67 / 当前候选受控对照 · 2026-10-06

**两次对照均止于公开节点暴露缺口，结论 INCONCLUSIVE。** 两个最小 App 各启动一次并正常退出，但自身 NSHostingView 的公开 accessibilityChildren 返回空数组，未定位 japanese-components-source，role、label、value 实际调用数均为0。不能把进程退出0记为组件AX通过，也不能判断“基线也复现”或“仅整合宿主触发”，更不能以6关键文件相同排除回归。本阶段没有生产或测试源码修复。

## 精确对照边界

| 项目 | 基线 | 当前候选 |
| --- | --- | --- |
| 实际包源码 Git revision | 6a67d1fd883f79737d0e3e12c756b683a662f230 | 51a8f3506234b7e3826320442358a1130bfdfb64 |
| 独立包 ID | org.pdfno.integration.axcomparison.baseline20261006.PDFnoMac | org.pdfno.integration.axcomparison.candidate20261006.PDFnoMac |
| Git archive 核对文件数 | 397 | 405 |
| 构建 | arm64 Debug App build，exit0 / BUILD SUCCEEDED | 同设置，exit0 / BUILD SUCCEEDED |
| 唯一启动 UTC | 13:28:42.306012–13:28:44.604175 | 13:29:08.028197–13:29:09.990707 |
| 本次自己创建的 PID | 88984，已退出/reap | 89001，已退出/reap |
| 生命周期 | 2.298秒，exit0，无timeout/cleanup signal | 1.962秒，exit0，无timeout/cleanup signal |
| 原句节点 / 三属性调用 | 未找到；role0、label0、value0 | 未找到；role0、label0、value0 |
| 明确状态 | SOURCE_NODE_NOT_EXPOSED_BY_PUBLIC_PROTOCOL | SOURCE_NODE_NOT_EXPOSED_BY_PUBLIC_PROTOCOL |

两份项目分别从精确 Git archive 实体化包源码，最终逐文件与同 revision 的 archive 核验相等；无共享包符号链接。两个项目设置归一化专用bundle前缀后逐字节相同，构建使用同Xcode/SDK、同架构/配置/jobs2、同ad-hoc签名设置，签名只读verify均退出0。公共App入口/fixture/harness源码逐字节相同，SHA256为 `5fda7a9eed2bc1cd3917c97f2bf42c36ef33d952d5cd41ed36ac72b8fdee5b7d`。此前 full App/runner 不参与这两次对照，没有运行 XCTest 或全suite。

最小视图保持真实 JapaneseSentenceComponentsView，在 grouped Form/Section 中渲染固定原文“日本語”、作者ruby“にほんご”和4个合成成分（两个同范围歧义候选、一个嵌套范围、一个省略候选）。fixture经过真实 JapaneseLearningValidator，确认有效review及严格原文UTF-8，两个进程记录的payload字节相同。原AttributedString内部链接、textSelection、显式label、色标和按钮均由各revision的生产组件产生，没有去掉任何修饰符来规避问题。

harness只在内存创建review，不实例化 LibraryModel、provider、App AI session或真实书籍入口。每个App在scene创建前核验专用bundle、新UUID和offline；两个UUID隔离根在准备/启动/结束时均不存在，没有创建书库。使用App自身dark设置，未改系统主题。App路径精确绑定后直接启动，只记录自己的stdout；共享heavy lock覆盖构建及各次运行，30秒上限，各一次、retry0，正常由自身NSApplication.terminate结束。没有外部AX client、调试器、注入、私有API、权限请求、剪贴板或其他App读取。

## 实际节点与访问序列

两次均记录8个事件：isolated-start → fixture-ready → own-host-ready → identifier before/after → children before/after → end。以下地址是对应进程一次生命周期内的 ObjectIdentifier，不是跨进程可比较的逻辑身份：

| 进程 | 本进程NSHostingView身份 | identifier返回 | children返回 |
| --- | --- | --- | --- |
| 基线 | ObjectIdentifier(0x0000007cb9141400) | nil | count0 |
| 候选 | ObjectIdentifier(0x00000077010c9400) | nil | count0 |

own-host-ready是在该NSHostingView已挂到自身window并layout之后记录的，随后限定访问其公开 NSAccessibilityProtocol 子树。此处确实获得了宿主节点地址及两项显式调用的before/after顺序；**没有获得原句节点地址、父链或role/label/value序列**。公开 children 为空的具体原因没有实验证据，本报告不推断是初始化时机、外部客户端登记、宿主结构还是框架桥接。没有使用 perform/KVC/private implementation fallback或开启辅助功能权限来填补它，也没有第三次执行。

两个进程没有收到崩溃signal，但触发原先失败的属性读取尚未发生，因此“无signal”无法回答原先问题。即使未来最小组件可读，静态内存review/grouped Form和真实整合workspace/sheet、结果发布时序及XCUI多属性快照仍有差别；本次更没有足够证据选择其中一个原因。

## 保全与未解决项

原 full60仍为33 PASS/27 FAIL/0 SKIP，后续13项仍为9/4/0，两个限定日语probe仍为0/2/0，三个已核验专用App的Stack Guard/role-label重入证据继续保留。本次没有实际原方法通过数，不把两次诊断启动加入PASS计数；完整UI验收仍未通过。

原4个UI文件哈希与前一保护收据相同，700条断言及60方法源保持；原full60日志和App/runner/test二进制、忽略副本及stdout诊断插入、19张自制截图逐项哈希保持。没有新截图、转码或附件上传，Library仍无有效library_file_id。main仍6a67，未跟踪Xcode metadata原样保留；全部已记录旧测试PID及新创建两个PID退出，共享锁收尾空闲。

尚缺的是能够在允许边界内暴露精确原句节点的已核验读取路径，以及该节点一次role/label/value访问。当前两次授权对照已结束；未追加权限/风险操作或另一种GUI尝试。没有生产diff、npm/install、全suite、面板循环、独立审计、安全专项重试、push/dispatch/merge或公开发布。

## 本地交付

证据位于主仓库 `.build/MacUIExperience/2026-10-06/evidence`，可由相对路径复核：

- AXComparisonHarness.swift、run-ax-comparison.py、ax-comparison-plan.json：精确公共harness、受单次守卫的执行器、两个revision/产品/UUID/启动次数。
- ax-comparison-product-preflight.json、ax-comparison-initial-admission.json：专用包/签名/二进制/公共源码哈希及精确旧PID、项目设置对照。
- ax-comparison-{baseline,candidate}-build-command.json / .log：两个实际构建的命令、起止UTC、exit0及日志SHA。
- ax-comparison-{baseline,candidate}-runtime.json / .log：本进程fixture、节点地址、显式调用序列、结束状态与退出码。
- ax-comparison-post-run-protection.json、ax-comparison-outcome.json、PARENT-STATUS-AX-COMPARISON.json、FINAL-RECEIPT.json：保全、收尾、不可判定结论及最终本地提交。

此前证据与限制见[静态定位报告](MAC-UI-JAPANESE-AX-STATIC-2026-10-06.md)、[两项实际probe](MAC-UI-AX-PROBES-2026-10-06.md)和[整体体验/整合报告](MAC-UI-EXPERIENCE-2026-10-06.md)。本次只提交对照结论和保全说明，不改变此前失败状态。
