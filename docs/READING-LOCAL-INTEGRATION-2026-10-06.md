# PDFno 阅读 Skills、导航与临时 AI UI 本地整合

日期：2026-10-06。前面的本地验证表是 **02:31 UTC 的历史快照**；后续公开检查记录见文末。基线为已验收 `main ab6695c7bb9de25a9230b2e79053577c33aeaee2`。用户授权持久独立工作树内的本地整合和测试，并于 **02:33 UTC** 明确授权普通 feature push、完整隔离 CI 与本批修复、全绿后合入 main 并完整复验 main。本轮没有把旧验收移植为新 SHA 的验收。发布状态以对应分支/SHA 的 Actions 和最终收据为准，不由历史快照推断。

本地分支：`feature/reading-local-integration-20261006`。工作树相对原仓库：`.build/ReadingLocalIntegration/2026-10-06/tree`。实现提交：`b43da3b5356952d9c760eee013dd5560a14f66fd`；后续本地提交和完整收据以该树 `.build/IntegrationEvidence/FINAL-RECEIPT.json` 为准。main、原交付工作树和主树未跟踪 Xcode workspace 元数据保留。

## 交付来源与合入

| 已有交付 | 原始提交 | 本地整合提交 |
| --- | --- | --- |
| 六项 Skills 基础契约 | `2553edfd8c090bb74cdaeeb09f2f96657a6823a4` | `7a212dc` |
| 四项选文宿主薄适配 | `d10946f104cdc375bfc3383d5dfafc5b9cf82194` | `912fc61` |
| 导航底层及接线补丁 | `300dcfe510b1785d05e649a3e2efa864db941f26` | `7ec6f2e` |
| 临时 AI 设置/工具目录 | `b043522cacf2de57aae2f5b267782db6b2850865` | `8f6ac7a` |
| ADR/规格/路线/账本 | `0b4a58d7c426803db84ca822acfc1b0296cc6d51` | `1483fab` |

先审阅差异/依赖及基线后续修复，再逐项合入。临时 UI 与当前 `LibraryWorkspace` 阅读网格发生一处冲突，手工保留基线导航、翻页、笔记及可访问标识，增加 AI 工具入口。没有用旧树整文件覆盖当前代码。

## 实际用户路径

翻译、解释、日语、英语和独立 HTTPS BYOK 选文从原宿主开始入口进入 `ReadingSkillSelectionAdapter`，沿用原 coordinator/provider/会话密钥/共享三次额度、确认、取消、来源校验和手动保存。六项契约中 PDF 物理页和 EPUB 当前 spine 只登记计划，仍走原独立六次批次链；未建立统一批次执行器或新结果文件。envelope 只在会话内，不重写旧学习记录或用户正文。

`READING-NAVIGATION-INTEGRATION.patch` 已真正应用并适配当前 Mac 网格。PDF 目录和页面列表核对会话，搜索成功才关闭导航面板；PDF 返回按钮在当前阅读区网格内，快捷键仅在当前 PDF canvas 获得焦点时接收。EPUB 目录使用带会话的跳转；返回按钮位于阅读区，避免新增书库工具栏压缩。普通前后页不增长历史，切书/关闭清空，PDF 返回仅恢复物理页，EPUB 返回复用 canonical 原文锚点。原输入、输入法、sheet 和其他窗口事件仍受保护。

完整整合首轮发现已保存日语记录搜索回跳时，宿主重开 PDF 后仍保留旧 document 的 native view。新增的旧文档保护正确拒绝捕获，但原回跳在 SwiftUI 下次更新前未安装当前 document。修复只让校验通过的显式导航安装当前文档；被动选区/页通知仍拒绝旧文档，旧搜索/目录/session 仍拒绝。新增 native 生命周期回归并保留原失败用例断言；首轮失败日志保留。

临时设置采用左分类/右卡片，窄窗使用顶部分类与单列。书库/PDF/EPUB 工具目录只路由现有预览，未实现规划不提供执行或假开关；保留原独立 BYOK 身份。分类变化清空未应用的密钥输入，普通配置草稿保留。单书检索仍是独立实验，没有接入产品；Bookno/iCloud/mobile 专项后置。

## 基线保护、来源与许可

原 `NativeUITests` 46 项、`EbookFormatUITests` 4 项、`NextBatchUITests` 2 项源码逐字节等于 ab6695c，共 52 项原断言和超时不改。新增 `ReadingIntegrationUITests` 四项独立实际 UI 用例，生成器/工程同步，共 56 项可编译方法。

PDF 原生输入/AX 排序、同步来源核验和落盘命令、存储写入门/恢复协调、英语提交 source fence/备份关联及草稿 journal 的基线文件保持字节一致。3/6 预算、500 UTF-16/3000 UTF-16/6 段、1024 tokens/30 秒/64 KiB、零自动重试和精确 Unicode 单位不变。新代码为原创 AGPL-3.0-or-later；无新依赖、字体、私有模板/图片或引擎更新。96 项选定 codec 源码/许可 hash 和 6 项原创真实容器 fixture 的离线核对通过；`engine-build`、第三方 notices、Package.swift 和原四份 CI 未改。后续增加四项新 UI 的独立诊断及原始 xcresult 归档；完整 Native 检查仍执行全部 56 项。

83 项正式要求 ID、定义、类别数量和历史审计状态保持；只移动规格行号和增加当前本地实施覆盖。ADR/路线中的早期文档授权和快照标明历史日期，当前范围优先。来源检查不替代独立许可或安全审计。

## 本轮验证

环境：arm64 macOS 27.0.1（26A434）、Xcode 27.0（27A266a）、Swift 6.4。所有重型检查使用原批次 `run-heavy-check.py` 的同一 `PDFnoNativeHeavyChecks.lock`、最多两个 jobs、独立 scratch/cache/DerivedData。脚本 SHA256 为 `6a0791c963524ec40e9525e812b0945163b029c5941548bb9d4041bc6395d033`。不清锁、不停止其他进程；`ps` 的沙盒限制意味着没有完整系统进程清单。主树没有被本轮写入代码。

| 检查 | 本轮实际状态 |
| --- | --- |
| 完整离线 Swift | **520 项 / 65 suites 通过**，`swift-final.log`；首轮 519 项出现上述一项回归，`swift-full.log` 保留 |
| Mac build-for-testing | **TEST BUILD SUCCEEDED**，arm64、未签名；编译全部 56 UI 方法 |
| iOS Simulator build-for-testing | **TEST BUILD SUCCEEDED**，arm64+x86_64、未签名；未启动 Simulator |
| 分类/目录组件 | 44 张原创隐藏 NSHostingView 图片，窗口未上屏；宽窄、深浅与原来源/草稿/凭据/零请求/零写入断言通过；人工查看代表像素 |
| 来源/codec/账本/工程 | source guard、96 codec/6 fixture hash、8 项账本回归、生成器再生与 diff 检查通过 |
| 新实际 UI | 独立 app/test bundle ID 的 ad hoc 构建通过；运行退出 65，runner 初始化 `Timed out while enabling automation mode`，**0 / 4 方法执行，NOT-VERIFIED** |

新实际 UI 只指定测试副本 `org.pdfno.integration.reading20261006.PDFnoMac`，不启动 `org.pdfno.PDFnoMac`；用例为每次启动设置 UUID Library 与离线拦截 transport。测试项目复制在 `.build/IsolatedUIProject`，只改变测试副本 bundle ID，未改受版本管理的 app 身份/签名设置。启动前已核对构建产品及 xctestrun 目标/runner 身份，并把显式测试 app ID 传入 runner。runner 在进入测试方法前初始化超时，不能据此声称 app 已运行或新方法已通过。原52项没有在本机重复执行；这不是它们的新SHA通过证据。未改系统权限、重试、重新签名策略或绕过隔离。实际结果不能由离屏组件渲染推断。

构建/测试证据都在本工作树 `.build/IntegrationEvidence`，含命令、日志 hash、保护字节收据和最终本地 SHA。既有 codec 精度、原 UI 未使用变量、无 AppIntents 依赖提示保留；没有借此改无关模块。

## 未验证与待发布

真实语言质量、费用/usage、真实服务兼容、持久 Keychain、VoiceOver/输入法人工流程、Intel runtime、iPhone/iPad 实机与移动阅读 UI 尚未验收。独立安全专项保持 **UNVERIFIED / platform-blocked**，未重试或绕路。规划的个人模板/新任务、统一批次执行、结果仓库、单书问答、外部研究/MCP、实际 Bookno/iCloud 同步未实施。

02:31 UTC 时仍只有本地整合，实际 UI 被本机 automation mode 初始化阻塞。02:33 UTC 后的普通 feature push、完整隔离 CI、本批修复、全绿后合入 main 和完整 main 复验已获明确授权，不需要重复确认。无新持久 schema/原书迁移，不删除用户书库、旧工作树或构建数据。本工作树本身是持久交付，请在清理可再生 `.build` 产物时保留 `tree` checkout。

## 首轮公开检查与修复记录

feature `a9641d0382840ff293e0abb59b651893891156bd` 的 [Native 37404809652](https://github.com/lyx5710317/pdfno/actions/runs/37404809652) 于 03:35 UTC 正常失败，未超时：Swift 520 项和 Mac/iOS build 通过，实际执行全部 56 UI，原 52 项全过，新四项为 2 通过、2 失败方法（3 条 failure 记录），0 跳过。六项隔离诊断 37404857043、漫画 37404809633、电子书 37404860874 均通过。失败批次不满足 main 合并条件。

PDF 新用例的搜索 helper 重复切换已经展开的面板，且未替换之前的查询；修复为核对面板状态后打开、全选替换查询，并断言实际输入值。工具新用例点击后没有出现 `ai-start`；先补足 plain 工具按钮整个标签的点击区域，并在打开工具目录之前固定 PDF 选区。新增来源、可进入状态和实际预览关闭控件断言，独立四项诊断用于确认是否还存在 sheet 路由问题。保留原 52 项源码、所有断言和 180/240 秒单方法限制，完整最终 SHA 的 feature 与 main 检查不可由诊断代替。

首轮完整失败日志、方法清单及后续准确分支/SHA 验收在该工作树 `.build/ReleaseAcceptance`；进度文件为原仓库 `.build/ReadingLocalIntegration/2026-10-06/LIVE-STATUS.md`。本节记录已观察事实和修复方向；后续通过状态以每次实际检查的收据为准。本机安全专项仍保持 UNVERIFIED/platform-blocked，未重试或绕路。

修复候选 `e247a006` 的四项诊断 [37411199544](https://github.com/lyx5710317/pdfno/actions/runs/37411199544) 实际为 3 通过、1 失败、0 跳过：工具来源预览、确认、生成及手动保存已通过，EPUB 与设置也通过；PDF 第二次编辑搜索字段仍出现 AX 代理没有键盘焦点的派发错误。保留 110 MB 原始 xcresult。继续修正新用例的 Mac List 字段编辑驱动：显式双击进入编辑，再向活动应用的字段编辑器发送键盘事件，仍以准确字段值断言验证目标。该候选不作为最终 feature/main 验收；最终通过结论仍需完整准确 SHA 的实际检查。

候选 `7239f8e7` 的四项诊断 [37413648746](https://github.com/lyx5710317/pdfno/actions/runs/37413648746) 仍为 3 通过、1 失败、0 跳过。双击及向活动应用派发键盘事件没有修复输入：准确值断言证明第二次查询仍为 `useful`，未变成 `window`。据此修复产品布局，将 PDF 查询输入和提交移到 List 外的独立顶部区域，保留搜索结果、目录、页面和已有标识/事件；测试恢复直接向字段输入，全部准确查询、页码、快捷键输入保护及草稿断言保留。该历史失败候选不能作为最终验收。
