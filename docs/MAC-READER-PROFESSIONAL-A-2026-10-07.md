# Mac 阅读页 A 专业工具方案实装 · 2026-10-07

当前代码候选在 `feature/mac-reader-professional-a-20261007`，基线是 `0030bf57f126ba57dc6e9e08690aa1b579b2e4c1`。持久工作树为 `.build/ReaderProfessionalA/2026-10-07/tree`；编译产物和原始验证记录在其相邻 `Mac`、`Swift`、`Evidence`、`QA` 目录。main 和原 Mac 验收工作树没有替换。仅本地开发和提交，无 push、merge 或发布。

## 实际行为

PDF 与 EPUB 阅读页采用 A 的文档标题栏、分组纵向工具栏、可收起导航和右侧笔记／选文 AI 检查面板。普通阅读保留完整正文；宽窗可以同时展开两个面板，窄窗优先显示最近打开的面板，关掉后立即恢复正文。工具栏在矮窗内滚动。

标题栏只放已有上一页、下一页、返回旧位置等文档操作。PDF 的目录／查找分段组织实际目录、页码和搜索结果；⌘F 打开查找并请求真实输入框焦点。右侧 AI 面板嵌入原 `AILearningWorkspace`，仍显示原始选文、接收方、同意状态、实际结果及手动笔记保存。日语、英语、整页／整章翻译、BYOK、AI 工具和模型设置继续使用原正式功能入口。没有原型方案切换器、展示数据或联网 AI 结果植入生产 UI。

`PDFnoProfessionalReaderChrome.swift` 只负责结构和按钮表达。原 `PDFCanvas`／PDFKit 和 `EPUBCanvas`／WebKit 留在 `PDFnoReaderShell` 的稳定首个子视图。新增 professional 密度参数：导航 210pt、笔记 300pt、双面板保留正文最少 420pt；原 standard 布局参数仍为默认。面板重排不重建引擎会话。普通笔记草稿位于阅读工作区，AI 来源／结果／用户正文仍由正式模型持有。

本次生产修改仅为 `LibraryWorkspace.swift`、`EPUBWorkspace.swift`、`AILearningWorkspace.swift`、`PDFnoReaderShell.swift` 和新增布局组件。书库、其他格式阅读页、领域模型、服务、所有阅读引擎、资源、数据 schema、精确来源锚点、AI 预算／确认／凭据路径、搜索／正文编辑、18 格式支持和 Release 构建配置均保持基线字节。iOS 原阅读导航实现保留且未进行移动验收。

## 已执行验证

| 检查 | 实际结果 | 原始证据 |
| --- | --- | --- |
| 当前精确源码全 Swift | 577 项／74 套件 PASS，43.761 秒，退出 0 | `Evidence/swift-exact-final-admitted.log` |
| 全部六份 Node 回归 | 25 PASS／0 FAIL／0 SKIP，退出 0；复用既有依赖，无安装 | `Evidence/node-regression.log` |
| 当前精确源码 Mac Debug 编译 | BUILD SUCCEEDED；App 和 debug dylib 实际 lipo 均含 arm64、x86_64；未启动 | `Evidence/mac-product-exact-final.log` |
| source/provenance guard | PASS | `Evidence/sourceguard-final.log` |
| Release 检查器回归 | 5 PASS | `Evidence/release-checker-final.log` |
| 需求台账回归 | 8 PASS | `Evidence/requirements-final.log` |
| codec／原始 fixture 守卫 | 96 codec 哈希和 6 原格式 fixture PASS | `Evidence/codecs-final.log` |
| A 隔离 GUI 工程 | 准备工具和新增四方法已编写；编译状态由相邻 QA 收据记录 | `qa/reader-professional/README.md` |
| 当前产品实际 GUI 60＋4 | **NOT RUN：等待桌面独占交接** | 尚无当前 A 的 xcresult 或截图 |

新增五项 Swift 布局测试使用不可见的独立原生窗口，验证真实 PDFView／文档／会话／精确选区身份、草稿和查询在 1280／720 宽度及浅深色切换中保持，以及实际阅读页和嵌入 AI 面板的最小宽度与零发送／零保存。它们不操作系统键盘鼠标，不能代替 GUI 验收。

首轮新测试在 PDFView 挂载前读取视图，导致四项断言失败，原记录 `Evidence/swift-initial.log` 保留；修正测试挂载等待顺序后完整 576 项通过，增加密度边界测试后完整 577 项通过。最后一次受限沙箱构建因 SwiftUI macro server 的嵌套 sandbox 限制未编译成功，记录 `Evidence/swift-exact-final.log`；经允许的正常编译环境重跑后得到上表精确源码通过结果。没有删断言或把失败记录计为通过。

隐藏 SwiftUI host 的 in-process `accessibilityChildren` 实测为 0。因此旧原型的 22 次 `NSAccessibilityProtocol` press 未形成有效的真实控件操作证据；本次验收计划使用专用 bundle 的 XCTest 真鼠标／键盘。历史 60 项通过和旧原型截图不计入当前 A 验收。

## 隔离 GUI 和剩余边界

隔离工具复制当前源码到全新 QA 快照，专用 bundle 为 `org.pdfno.integration.professionala20261007.PDFnoMac`。入口在 SwiftUI Scene 创建前校验 bundle、UUID 和范围，Library 固定到 0700 的 `/tmp/PDFno-UITests-{UUID}`，会话和进程记录在 Library 外；HTTP 和 Security Keychain 在快照中直接拒绝。生产 App 入口没有改动。原四份 GUI 测试 SHA 保持，原 60 方法／断言继续完整运行，另加 4 项 A 回归，零筛选／跳过／自动重试。

新增四项将检查窄窗真实 ⌘F 焦点及笔记草稿、宽窗深色 AI 同意／结果／草稿／手动保存／原文返回、窄窗深色 EPUB 规范来源和草稿、宽窗浅色双面板 420pt 阅读区域及关闭恢复，并仅截自制隔离 App 窗口。GUI 命令必须持既有 `PDFnoNativeHeavyChecks.lock`，收到明确桌面独占交接后才能启动。当前没有启动普通产品 App、读取私人书籍／笔记／密钥、操作其他应用或修改系统权限。

实际点击、键盘、当前产品截图、人工视觉／VoiceOver、真实联网模型、iOS 和受限安全专项仍未验收。正式产品普通 bundle 编译产物可以审查，但不要用于本地隔离验收启动；运行方法见 `qa/reader-professional/README.md`。没有新的 Library 附件 ID。
