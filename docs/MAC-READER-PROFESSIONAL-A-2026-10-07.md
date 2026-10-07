# Mac 阅读页 A 专业工具方案实装 · 2026-10-07

A 方案已在独立持久工作树实现。正式验收源码为 `7b7c5560fee497abd2f7a05e2943100546fa99f4`，分支 `feature/mac-reader-professional-a-20261007`，基线 `0030bf57f126ba57dc6e9e08690aa1b579b2e4c1`。工作树为 `.build/ReaderProfessionalA/2026-10-07/tree`。编译、真实 GUI、隔离快照与证据保存在同级目录。main 与原 Mac 验收树未替换；无 push、merge、发布、安装新包或正式签名。

## 实装行为与范围

PDF 与 EPUB 使用文档标题栏、分组纵向工具栏、可收起导航和笔记／选文 AI 面板。标题栏集中上一页、下一页、返回旧位置；目录、查找、笔记、AI、工具、日语、英语、整页／整章、BYOK、设置在纵栏分组。矮窗工具栏可滚动；按钮显示展开和选中状态。

PDF 导航把实际目录、页码和搜索结果组织在一个面板，⌘F 打开查找并聚焦真实输入框。宽窗 PDF 可同时展开导航与笔记，保留正文最少 420pt；窄窗优先显示最近打开的覆盖面板。关闭面板恢复正文。EPUB 面板始终覆盖稳定的 WebKit 视口，避免文字重排造成选区变化。被覆盖正文暂时从辅助功能树隐藏，以免真实点击命中背后控件。

AI 面板复用正式 `AILearningWorkspace`，展示选文、任务、接收方、同意、结果、用户草稿与手动保存。日语、英语、整页／整章翻译、BYOK、AI 工具和模型设置继续走原正式入口。普通笔记关闭面板保留未提交草稿，保存成功才清空；AI 草稿与结果保留在原模型中。实际产品没有设计原型切换器，也没有植入测试数据或假联网结果。

产品修改限于 `LibraryWorkspace.swift`、`EPUBWorkspace.swift`、`AILearningWorkspace.swift`、`PDFnoReaderShell.swift` 和新增 `PDFnoProfessionalReaderChrome.swift`。共享 shell 的原 standard 参数仍为默认；professional 导航 210pt、笔记 300pt、正文最少 420pt。PDFKit／WebKit 仍为稳定首个子视图。领域、阅读引擎、服务、App 入口、项目、Release 配置和资源与基线字节相同，核验记录为 `Evidence/unchanged-engine-release-7b7c556.json`。书库外观、其他格式的阅读布局、18 格式支持、数据 schema 与来源锚点未改。

## 最终验收

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| 精确候选 Swift | 577 项／74 套件通过，15.152 秒，退出 0 | `Evidence/CODE-CHECKS-7b7c556.json`、`Evidence/swift-7b7c556-exact.log` |
| 精确候选 Mac Debug | BUILD SUCCEEDED；App 与 debug dylib 均含 arm64、x86_64；普通产品 App 未启动 | `Evidence/mac-7b7c556-exact.log`、同上编译收据 |
| 现有六份 Node 回归 | 25 通过、0 失败、0 跳过；引擎与依赖未改，无安装 | `Evidence/node-regression.log` |
| 真实 GUI 门禁 | 5 通过、0 失败、0 跳过；6 次 App 启动的路径、源码、执行文件与 debug dylib SHA 匹配 | `Evidence/QA13-FIVE-METHOD-OUTCOME.json` |
| 精确候选完整 GUI | 64 通过／0 失败／0 跳过，退出 0；原 60＋A 4 全通过；102 次真实 App 启动身份匹配 | `Evidence/QA13-A64-OUTCOME.json`、`Evidence/qa13-full64-command.json`、`Evidence/qa13-full64.log`、正式 xcresult |
| 原 60 项断言保护 | 60 项完整方法体字节相同；3 份原 UI 文件整体相同；NextBatch 的两个测试方法、verifyPackage 和 confirmInitialDirectory 字节相同 | `Evidence/protection-7b7c556.json` |
| source/provenance | 722 份 source guard 通过；423 份 Apple 输入逐一 SHA 核对 | `QA13/PREPARATION.json`、`QA13/RUN-PLAN.json`、`Evidence/qa13-build.log`、`Evidence/qa13-full64-command.json`、`Evidence/sourceguard-7b7c556-delivery.log` |
| Release／台账／codec | 原检查器 5、台账 8、96 codec 哈希及 6 fixture 通过；相关输入未改 | `Evidence/release-checker-final.log`、`Evidence/requirements-final.log`、`Evidence/codecs-final.log` |
| 窗口截图 | 最终全量运行 5 张原窗口 PNG，逐张原像素人工检查完成 | `QA13/SCREENSHOT-MANIFEST.json`、`Evidence/QA13-FULL-VISUAL-REVIEW.json` |

完整 GUI 使用独立唯一 bundle `org.pdfno.integration.professionala20261007.qa41badb97fd42.PDFnoMac`，单次命令、64 个方法、无筛选／跳过／自动重试。原 60 与新增 A 4 项分别统计；日志 start/end、xcresult 方法树和正式总表必须一致且每项只运行一次。每次启动在 Scene 创建前记录精确 App 路径、候选 SHA、执行文件和 debug dylib SHA；正式范围要求路径与编译产物完全相同。正式 App entitlement 为空，原项目和 Release entitlement 未改。重型检查串行持有现有 `PDFnoNativeHeavyChecks.lock`。

新增四项使用 XCTest 真鼠标／键盘，覆盖窄窗 PDF ⌘F 焦点、页码快捷键与 Unicode 草稿保留、深色 AI 确认／离线结果／草稿／手动保存／回到原文、窄窗 EPUB 规范来源与草稿、宽窗双面板 420pt 正文与关闭恢复。五项 Swift 布局测试只是隐藏窗口的布局／身份验证，不替代实际 GUI。

## 隔离与历史试验

QA 快照在 Scene 前强制检查唯一 bundle、UUID 与范围，自制 Library 固定在拥有匹配 Registry 的 0700 临时目录。HTTP 和 Security Keychain 在快照直接拒绝；离线传输使用固定原创结果，画面明确写明 mock。生产入口和服务没有这些替换。未启动生产 App、读私人书籍／笔记／密钥、操作其他应用或改系统权限。截图仅为 `app.windows.firstMatch` 的自制窗口，原 PNG 原样复制并核验 SHA；自动附件禁用。没有桌面截图。

早期准备器曾因从方法表重复计数而在构建前拒绝；改为原最终 Passed 表的 60 个方法。早期输入清单因绝对路径中的 `.build` 误过滤而为空；后续改为相对路径检查，QA13 的 423 项完整清单不是旧空清单的推断。旧 QA 快照共享 bundle，实际启动可能被 Launch Services 指向旧诊断 App；旧运行全部保留为历史试验，不算当前精确候选验收。唯一 bundle、精确路径和运行时二进制收据解决了该缺口。

旧全量试验为 63／64，恢复方法在原生 Go To 文件夹中以 Return 完成路径时出现系统文件面板服务退出。没有获得当次崩溃栈，不能引用旧日栈代替。NextBatch 仅调整路径输入辅助函数：双击实际可命中的自制文件夹行，断言目录 URL 后点击真实确认按钮；保留所有测试方法和行为断言，并只写自制剪贴板内容。新候选先通过恢复门禁，再执行完整验收。另一旧门禁的窄窗失败来自 Unicode 输入后 XCTest 解析暂态输入对话框；新测试重新取得并点击实际文本框，用相同快捷键，同时断言草稿正文完全保留。没有移除断言或把旧失败算通过。

编译及运行日志中的 debugger 参数和 DisplayManager 警告保留。测试清理自己的部分 0700 fixture 目录曾遇权限拒绝，未扩展权限或操作其他目录。本次正式结果有 22 条运行时警告：21 条 QoS 优先级反转、1 条 DOCX 转换页的 view-update 发布警告。基线同一 DOCX 方法已记录相同发布警告，ConversionWorkspace.swift 与基线字节相同；警告根因没有确认，也没有在本次 A UI 任务中修复。不能把 64／64 解释为零警告。记录见 Evidence/QA13-RUNTIME-WARNINGS.json。Mac 编译另外保留重复 destination 与未使用 AppIntents 的 metadata 警告，Swift 无编译警告。

## 查看与运行

最终对比图库为同级 `Delivery/gallery.html`；五张图来自最终全量测试，宽窗外框 1280×800、窄窗外框实际 720×572（原最小内容 720×520 加原生 52pt 工具栏）。不得把窄窗外框称为 720×520。深色模式仍保留原阅读引擎的白色文档页面；长面板内容可滚动。书库侧栏保留原样，可用原生侧栏按钮收起。截图均为原创 fixture 与测试笔记。

安全预览使用 `QA13/source/apple/PDFno.xcworkspace`，Scheme `PDFnoMac`、My Mac、Debug，使用已有 ad hoc 配置，无开发者证书。已编译隔离 App 位于 `QA13/DerivedData/Build/Products/Debug/PDFnoMac.app`；直接打开它会进入独立 preview UUID，只打开内置原创示例，不联网、不读 Keychain。此预编译包的 Registry 路径属于当前 Mac；可审查的源代码与自制数据另见本地 ZIP。不要启动同级 `Mac` 的普通产品 App 来做隔离预览。

`Delivery` 提供源码、受保护的隔离工程、自制窗口截图、图库及精简验证收据。正式原始 xcresult 和运行日志保留在 `Evidence`／`QA13`，不将系统标识或临时 Library 装入交付 ZIP。没有 push／merge／发布。Library 官方 helper 在当前既有 Python 运行时无法执行，不安装新 Python、不修改 helper 或绕过官方上传；此次交付保留本地，**无新的 Library 附件 ID**。

人工窗口视觉和真鼠标键盘已验收；VoiceOver、iOS、Intel 上的 GUI、真实联网模型质量、正式签名／发布及受限安全专项未验收。双架构编译不等于 Intel GUI 测试。最终文档提交可晚于验收提交，须另记交付 HEAD，并核验 423 份 Apple 输入仍与验收候选相同。
