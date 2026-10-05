# 阅读导航与位置恢复：独立本地候选

日期：2026-10-05。分支 `feature/reading-navigation-20261005`，固定基线 `82585b1053b8a000f337274fec8ae597255c9135`。所有编辑仅在本任务独立 worktree；没有 push、merge、真实 API/key、私人书籍、桌面 App/UI、模拟器启动或签名/权限配置变化。已读 CONTRIBUTING、v0.3 相关规格、NATIVE-TASKS、VALIDATION、UI foundation/refinement 和现有目录/搜索交接；本仓库与祖先未发现适用 AGENTS.md 或仓库 skills。

## 实现盘点与实际缺口

基线已经有 PDF 页码、前后翻页、内置目录、最多100项文本搜索、精确笔记来源回跳、lastPageIndex 恢复；EPUB 已有目录、翻页、横竖排、精确 canonical UTF-16 锚点回跳和 progress 恢复。没有重写这些能力，也没有新增书内搜索引擎。EPUB 书内搜索仍未实现，本任务没有把检索技术验证作为用户功能交付。

本候选修复或补充：

- PDF 安装 document 后的延迟恢复有可取消任务及恢复 ID，核验当前 session、document 和 native host。显式翻页/跳转、换书、换宿主、拆卸、关闭使旧任务失效；初始页0通知仍不会覆盖保存页。无效 lastPageIndex 拒绝打开，保留原 reader 状态，不猜页码。
- PDF 搜索结果核对所有 page 的真实 document 身份，旧 PDFSelection 不导航。目录项带当前 readerSessionID；新的 `jump(to: item)` 与 `jump(to: index, in: sessionID)` 拒绝旧会话点击。旧仍挂接的 canvas 无法把其选区绑定给新 book。updatePage 也拒绝外来 document/页索引。
- PDF 目录/页列表用明确 jump API，搜索及既有精确来源导航记录跳转前页。普通 previous/next 不增长返回栈。返回最多32个当前会话页索引，切书/关闭清空；失败不消费历史。**返回单位是物理页，不承诺恢复页内滚动点、缩放、旋转或选区几何**。
- EPUB 的 chapter/navigate 成功回执记录既有 progress 锚点；返回仍走原 `navigate` 的 book/edition/hash、canonical quote/context 与实际 navigationSelection 核验。目录项携带打开会话，`jump(to:)` 拒绝旧书目录。延迟 resize 捕获 session 和 documentVersion，换书或已重排后的旧请求不会执行。没有改 engine、桥接 envelope、AI 提取/发送/保存语义。
- 独立 SwiftUI 返回控件提供禁用状态、help 和新的 `reader-return-location` / `epub-return-location` 标识。PDF 快捷键候选为 Command-Option-←/→ 翻页、Command-Option-↑ 返回前页；只有当前 key window 中获得焦点的 PDF canvas 才接收。NSTextInputClient、TextField/SearchField/ComboBox、sheet、其他窗口、重复按键和其他修饰键全部保留系统行为；失败/边界不消费事件。事件 monitor 在 SwiftUI dismantle 和窗口分离时移除，不安装全局系统监听。**没有为 EPUB web 编辑/输入环境开启快捷键**。

返回历史是内存组件，不是持久化 schema；未改 Domain、repository、manifest、anchor extractionVersion、来源原字节或草稿 owner。PDFSourceAnchor 的真实 PDFKit 区域和 EPUBAnchor 的真实 UTF-16 locator 沿用现有解析，不从页标签或截图制造几何。

## 精确编辑边界与接线

已修改的既有文件仅：

1. `PDFnoReaders/PDFReaderSession.swift`：PDF 导航、安全恢复与当前文档选区校验。
2. `PDFnoReaders/PDFCanvas.swift`：Mac/iOS dismantle 时 detach 对应 host；旧 host 的 teardown 不影响新 host。
3. `PDFnoReaders/EPUBReaderSession.swift`：瞬态返回记录、带会话的 TOC 跳转与延迟 resize 校验。

新文件为 `ReaderNavigationState.swift`、`ReaderNavigationControls.swift`、`ReaderNavigationShortcuts.swift`、`ReaderNavigationTests.swift`，及本交接/证据/补丁。CBR 布局、PDF 保存、AI 入口、provider、费用、凭据和所有其他树都未改动。

**LibraryWorkspace.swift、LibraryModel.swift、EPUBWorkspace.swift 保持逐字节基线；界面接线尚未应用。** 协调者可在整合树先检查并应用 [精确补丁](READING-NAVIGATION-INTEGRATION.patch)：

```sh
git apply --check docs/READING-NAVIGATION-INTEGRATION.patch
git apply docs/READING-NAVIGATION-INTEGRATION.patch
```

补丁只挂接 PDF canvas 的快捷键 host、增加 PDF/EPUB 返回按钮、将 PDF 搜索成功后关闭面板/带会话的目录页码跳转及 EPUB 目录跳转接到新接口，并补 EPUB 无书/忙碌时目录与翻页禁用。不编辑 AI 网格或流程，不改变 searchText/draft/panels 的存储与生命周期。所有原 accessibilityIdentifier 保留。

本 worktree 的新控件和 API 已独立编译；`git apply --check` 对固定基线通过。**补丁应用后的完整 ReaderWorkspace/EPUBWorkspace 组合尚未编译或运行，协调者应用后必须重做两端 build-for-testing。** 在补丁应用前，现有 PDF 搜索/来源跳转和 EPUB command 可记录返回历史，返回按钮、PDF TOC/page-list 新路由及快捷键尚未进入用户界面。不能将这份候选描述成用户已可用的完整阅读导航功能。

## 离线验证与构建

环境：arm64 macOS27.0 (26A428)、Xcode27.0 (27A266a)、Apple Swift6.4。执行前逐行核验批次共享 heavy-check wrapper：独占 flock、原样运行子命令、无权限/安全重配；SHA-256 `f5673d761040495cb7b01647ca951621371c550161e20ed98fcad205113c1532`。每个 Swift/Xcode 重型检查均经此锁，jobs=2，各自独立 scratch/cache/DerivedData。锁等待期间没有启动第二个检查。

最终命令摘要：

```sh
python3 "$PDFNO_HEAVY_WRAPPER" -- swift test \
  --package-path apple/Packages/PDFnoKit \
  --scratch-path /tmp/pdfno-reading-navigation-20261005-build \
  --cache-path /tmp/pdfno-reading-navigation-20261005-cache \
  --config-path /tmp/pdfno-reading-navigation-20261005-config \
  --security-path /tmp/pdfno-reading-navigation-20261005-security \
  --jobs 2 --no-parallel \
  --filter 'ReaderNavigationTests|PDFReaderTests|PDFQuoteConsistencyTests|EPUBTests'
python3 "$PDFNO_HEAVY_WRAPPER" -- xcodebuild \
  -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath /tmp/pdfno-reading-navigation-20261005-Mac \
  -clonedSourcePackagesDirPath /tmp/pdfno-reading-navigation-20261005-Mac-Packages \
  -disableAutomaticPackageResolution -skipPackageUpdates -jobs 2 \
  CODE_SIGNING_ALLOWED=NO build-for-testing
python3 "$PDFNO_HEAVY_WRAPPER" -- xcodebuild \
  -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/pdfno-reading-navigation-20261005-Mobile \
  -clonedSourcePackagesDirPath /tmp/pdfno-reading-navigation-20261005-Mobile-Packages \
  -disableAutomaticPackageResolution -skipPackageUpdates -jobs 2 \
  CODE_SIGNING_ALLOWED=NO build-for-testing
python3 -B scripts/check-native-source.py
git diff --check
```

最终 Swift：**21个方法 / 4套件通过**，包含11个新导航方法；既有旋转/空白参数化用例保留。测试读取既有自制 sample PDF/EPUB，实际 PDFKit page/selection/outline 校验及 UUID 临时 manifest 重开。覆盖显式跳转胜过延迟恢复、保存页恢复、新旧宿主、detach/close、换书时旧 search/TOC/page-list/selection 拒绝、搜索和来源返回且 immutable selection 保留、无效页/来源无假定位、32项返回栈/失败保留、EPUB 原 schema roundtrip/edition 与 layout version、关闭 EPUB 不创建 webView、快捷键焦点/文字编辑保护。所选测试代码不创建 NSWindow/NSHostingView/WKWebView，没有展示界面或联网请求。

首次编译曾报告 event monitor 的 Any? 不能从 Swift6 非隔离 deinit 访问；修复为 main-actor 的 SwiftUI dismantle/window-detach 生命周期清理，之后最终测试与构建复验。没有放松 actor 安全或测试断言。

最终 Mac arm64 与 iPhone/iPad Simulator arm64＋x86_64 **build-for-testing 均为 TEST BUILD SUCCEEDED**，签名仅使用命令行 NO。首次移动构建因磁盘仅余135MiB而在 UIKit PCM 写入时失败；保留失败日志后，在共享锁内只删除本任务已完成的 Swift/Mac 可再生构建目录，释放至约1GiB，再用同一最终源码/原参数重试通过，没有碰其他任务或用户文件。成功日志均保留，已清理的输出可按命令重建。源检查结果、日志摘要/hash 在 [机器收据](READING-NAVIGATION-EVIDENCE-2026-10-05.json)。全部52项原 UI方法（Native46＋Ebook4＋NextBatch2）源文件逐字节保留；只编译，不运行。编译中的既有 codec 精度/unused UI变量与 AppIntents metadata skip 警告保留；没有修订这些无关模块。

## 限制与后续验收

- App/窗口/UI/VoiceOver/焦点实际事件路由、EPUB runtime 返回/重排与目录切换、真实设备、Intel runtime：NOT-RUN/NOT-VERIFIED。EPUB 的离线证据为 canonical/history/ticket/关闭状态契约与编译，不能冒称真实 WebKit 回跳通过。
- 不实现 EPUB 书内搜索、PDF 增量全文搜索、后退/前进跨书栈、文档标签、多窗口位置同步、页内精确视口恢复或持久返回历史。
- 草稿变量、journal、AI结果/请求与原始52项UI断言均未编辑；关闭导航/返回只处理导航。既有 EPUB resize 会清 selection 的边界没有被本轮消除。
- 本地重建与单元测试不是完整52UI验收。协调者接线后需要在另行获准的隔离CI/OS用户执行完整UI，重点覆盖文本输入/输入法、主副窗口/sheet、页边界、目录/搜索→返回、切书旧事件、重排/来源失效和未保存草稿。
- 全项目独立安全专项保持 **UNVERIFIED / platform-blocked**；未重试或绕过。没有读真实 key/书库，未改安全、权限或签名配置。

回滚可撤销本地候选提交及未应用接线补丁；没有 schema/数据迁移需要反向处理。
