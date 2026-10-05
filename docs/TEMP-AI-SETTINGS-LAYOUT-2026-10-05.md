# 临时 AI 工具与设置布局 · 独立本地候选

2026-10-05。分支 `feature/temp-ai-settings-layout-20261005` 严格依赖冻结候选 `82585b1053b8a000f337274fec8ae597255c9135`，不依赖建树时的 main `7bea8ec`。建树时该候选正由原协调任务完整验收；本片不抢先合入、不更改 CI、不推送或发布。后续只读检查见 main 已由原协调推进到 `82585b1`，原未跟踪 Xcode workspace 元数据仍保留，本片未操作 main。若父候选随后变化，后续整合者负责重放并重新验收，不能把本片本地结果移植为其他 SHA 的通过证据。

实施前已核实工作区及上级无适用 `AGENTS.md`、`.agents` 或 `.codex` 指令文件，并读取 CONTRIBUTING、v0.3 原生规格相关界面/来源/门禁、当前 UI、BYOK、英语、数据整合记录及实际任务源码。本片没有调用 Figma、操作闪念或 PDFno 桌面、读取私人书库或真实凭据。

## 已核实的参考

使用独立研究交付的 `layout-spec.md`（SHA256 `8b6bb8a579c11382b7b721648e20d378b5e3e1d91134ea57675d0669475d8be6`），并通过像素查看三张已脱敏截图。只借鉴设置分类、纵向卡片、状态块和目录组织；没有复制截图、私有代码、logo、付费会员条、字体或图标素材。

| 研究图片 | SHA256 |
| --- | --- |
| `01-ai-tools.png` | `ee667d0effd20cc9ee632a320e62a267f5413c460da44eeb2ae1b7ec730cf171` |
| `02-local-tools-permissions.png` | `88d7a23b2d89b0aa90a869708a01074787ad58d1f87580b6b197225cc61f4c08` |
| `03-client-capability-modes.png` | `f7cdc33f99370ebb40b2d01838e6e41bd335a9a28b4b67e2a27158f22ea4fc17` |

闪念的窄窗、模板详情和真实开关依赖未实测。本片的 760 pt 设置断点、196 pt 侧栏、880 pt 内容上限、12 pt 卡片圆角属于 PDFno 适配值；颜色、字体、间距与 SF Symbols 沿用现有 PDFno tokens 和系统框架。Figma 最终稿到来后可替换展示组件。

## 实施范围与状态

设置统一为“通用／AI／AI工具／同步与备份／快捷键／诊断／关于”。宽度 ≥760 pt 使用左侧分类；更窄时是顶部“设置分类”选择器与单列内容。既有 `ai-settings` 入口默认定位 AI。设置内容在同一父容器内随宽度调整；普通配置草稿由原父视图保留，分类变化清空尚未应用的临时密钥输入，不保存配置、不测试、不发送，也不清除已应用的原会话凭据。保存、取消、关闭、独立 BYOK 应用及短句测试沿用原调用。

AI 页分别展示官方 DeepSeek/原有阅读配置、独立 HTTPS BYOK 身份、会话/预算说明与短句自测。没有统一 provider 选择器把日语、英语、页或 spine 切换到任意 BYOK。新字段标签持续可见；最终接收 URL、原错误与状态可换行。原用例直接点击的 `ai-session-key` 在预设按钮后先显示，`byok-settings-open` 在固定工具栏保留唯一实例，避免较长卡片把旧入口推离初始视口；独立身份说明卡另有打开详情入口。真实可点击性仍由后续原 UI 用例验证。

书库侧栏及 PDF/EPUB 既有学习网格新增 AI 工具入口。目录按“阅读与语言／知识与模板／外部能力”分组，并可只看现有入口。选文翻译/解释、日语、英语、当前 PDF **物理页**、当前 EPUB **spine 文档**、独立 HTTPS BYOK、书名与已保存笔记搜索均连接原工作区。翻译/解释切换复用原任务切换的取消/结果清理规则，保留用户正文。其他原入口全部保留。

状态只读现有 reader/配置 owner：缺来源显示需选文，缺配置显示需配置，错误格式明确禁用，适用格式可进入原预览。进入不直接生成；实际预算、完整来源验证、外发确认与开始仍由原模型门禁控制。页/spine 可以在没有密钥时进入范围预览，原开始按钮继续要求本次密钥与确认。英语基线已有实际路由及离线测试证据，因此保留入口，并明确真实服务语言质量尚未验收。

知识规划组可折叠，过滤到现有入口后不展示规划项。语义搜索、MCP Client、工具调用、MCP Server 分别显示“未实现 · 默认关闭”和具体依赖，没有假开关或连接、下载、添加、安装动作。网页阅读/公共搜索只有说明卡，实际内容宽度 ≥640 pt 两列，否则一列。本片不实现 15 张 Skills 功能卡、模板编辑器、索引或运行时。

本地回收站与校验备份、Bookno 离线预览走原宿主入口和禁用条件；实际 Bookno/iCloud 同步单独标未实现。通用、快捷键与关于只说明现有行为，没有新的设置写入。诊断只打开原短句自测，页面切换不发送。

选文学习详情改为来源、任务/接收方/现有限制、结果、请求记录、已保存笔记的纵向卡片；独立 BYOK 先展示完整来源，再展示接收方。页/spine 的既有来源、限制、凭据/确认、状态整理在同一卡内，分段对照仍使用原有限宽度分支和绑定。日语、英语现有分色、审阅、用户修正与保存组件继续使用。所有保存/取消/回原文调用、ID、预算和门禁保持。Mac 改动使用平台条件，iPhone/iPad 保留原显示路径；仅进行移动编译。

## 文件与整合冲突点

| 文件 | 改动 |
| --- | --- |
| `PDFnoTemporarySettingsLayout.swift`（新增） | 分类壳、临时卡片/字段、规划说明与目录列数 |
| `ReadingToolsWorkspace.swift`（新增） | 分组、只读能力状态、原路由 |
| `AILearningWorkspace.swift` | 原 AISettingsView 分类/卡片，原选文详情卡片 |
| `BYOKSettingsView.swift` | Mac 独立设置卡片、原确认组件的来源顺序；移动显示保留 |
| `LibraryWorkspace.swift` | 书库/PDF 工具入口，向设置传递现有 LibraryModel |
| `EPUBWorkspace.swift` | EPUB 工具入口 |
| `PDFPageTranslationWorkspace.swift` / `EPUBChapterTranslationWorkspace.swift` | 来源/接收方/范围视觉卡片 |
| `TemporaryAILayoutTests.swift`（新增） | 原创组件、真实临时来源、格式/身份/零副作用回归 |
| `README.md` / `SOURCE-NOTICES.md` / 本文 | 本地候选状态、来源和交接 |

新增 `AISettingsView` 的可选 `library` 与默认 AI 类别参数不影响原调用者；新宿主传现有 model，不创建新的 key、budget 或持久化 owner。工具枚举/状态是 UI 展示类型，不向 Domain 注册能力。未来编辑 Settings/Library/PDF/EPUB 入口时容易发生同文件冲突，应保留原路由及全部 identifier，不能整文件覆盖。Service、Domain、Persistence、LibraryModel/AI models、reader、原 fixtures、Package.swift、CI、Xcode工程/生成器、权限和签名配置均未改。

原 `NativeUITests.swift`、`EbookFormatUITests.swift`、`NextBatchUITests.swift` 与基线逐字节相同，保留全部 52 项实际 Mac UI 方法、原断言与超时。新工具的真实点击、分类/草稿切换、保存/取消/来源返回与键盘回归须在最终精确提交上集中隔离执行。

## 本地验证

工具链：Xcode 27.0 (`27A266a`)、Apple Swift 6.4、arm64 macOS。重型检查使用原批次 `run-heavy-check.py` 锁、两个 jobs、独立 scratch/cache/DerivedData；不与本批其他重型检查共享产物。环境审批仅用于用户明确授权的本树测试和 build-for-testing，不禁用 SwiftPM 沙箱、不配置权限、不启动用户 App。

证据在本树 `.build/TempAILayoutEvidence/`（不提交生成图片/日志）：

- `final-verified-swift.log`：**120 项 / 13 suites 通过**。包含新 4 项方法，以及选文/独立 BYOK、日语/英语、page/spine、用户编辑、恢复整合、既有 UI 基础与精炼回归。
- 新测试在宽度 360、759、760、1120 pt、深浅色渲染真实设置/目录，另外渲染所有分类、独立 BYOK、选文详情和 1/2 列规划卡、长原创 URL，共 44 张原创组件 PNG。不可见 NSHostingView/NSWindow 从未 ordered on screen；不是用户桌面截图。真实 PDFCanvas/source/anchor/result/用户草稿、两套已应用虚构凭据、共享次数零和 learning manifest 字节均保持；拦截 transport 计数 **0**。像素已查看宽/窄、深/浅、规划双列、独立 BYOK 与选文详情的代表图片，不声称逐张覆盖全部滚动内容。
- source guard、8 项需求账本回归和 diff 检查通过；许可证/第三方资源未新增。
- `mac-build.log`：最终未签名 Mac arm64 **TEST BUILD SUCCEEDED**；`mobile-build.log`：最终 iPhone/iPad Simulator arm64 + x86_64 **TEST BUILD SUCCEEDED**。最终控件位置调整后两端都进行了增量复验；此前构建日志另行保留。build-for-testing 只编译 App/UI targets，不执行 UI。原 codec 精度、已有未使用变量及无 AppIntents 依赖提示不是本片新增代码警告。
- `FINAL-RECEIPT.json` 记录最终提交、变动文件、日志/组件 PNG SHA256、受保护源码无差异及原 UI 文件字节核对，提交后补入 commit 字段。

可复现命令（`PDFNO_HEAVY_CHECK` 指向父批次获准的锁脚本）：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/.build/TempAILayoutCaches/clang" \
SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/TempAILayoutCaches/clang" \
PDFNO_TEMP_AI_LAYOUT_PREVIEW="$PWD/.build/TempAILayoutEvidence" \
python3 "$PDFNO_HEAVY_CHECK" -- swift test \
  --package-path apple/Packages/PDFnoKit --scratch-path .build/TempAILayoutSwift \
  --cache-path .build/TempAILayoutCaches/SwiftPM --jobs 2 --no-parallel \
  --filter 'TemporaryAILayoutTests|UIRefinementTests|UIFoundationTests|BYOKProviderTests|DeepSeekSelectionTests|PDFPageTranslationTests|EPUBChapterTranslationTests|JapaneseLearningFlowTests|EnglishLearningFlowTests|EnglishLearningRemoteTests|RecoveryEnglishIntegrationTests|FourSliceIntegrationTests|NoteEditingTests'
python3 "$PDFNO_HEAVY_CHECK" -- xcodebuild -workspace apple/PDFno.xcworkspace \
  -scheme PDFnoMac -configuration Debug -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath .build/TempAILayoutMac -jobs 2 CODE_SIGNING_ALLOWED=NO build-for-testing
python3 "$PDFNO_HEAVY_CHECK" -- xcodebuild -workspace apple/PDFno.xcworkspace \
  -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath .build/TempAILayoutMobile -jobs 2 CODE_SIGNING_ALLOWED=NO build-for-testing
python3 scripts/check-native-source.py
python3 scripts/test-requirement-ledger.py
git diff --check
```

初次 SwiftPM 因 `sandbox_apply: Operation not permitted` 在编译前失败；在已授权操作的环境审批通过后用相同测试路线执行，未使用 `--disable-sandbox`。新增 fixture 初次编译有 await 宏错误，随后缺少 PDFCanvas 宿主，最后错误地比较配置保存前 identity/generation；均修正 fixture 并保留源码状态/来源/草稿/零副作用断言，失败日志未删除。进程清单读取被沙箱拒绝，未重试；因此未声称核实系统内所有其他 worker 进程，批次互斥只覆盖使用同一锁的任务。

## 未验证与回滚

本片真实 Mac UI 执行 **0**，没有完整 52 UI 或新入口点击通过声明。系统焦点/Tab/VoiceOver、文字放大、滚动控件实际可点击性、分类切换密钥清理与普通草稿保持的人工闭环、所有新入口保存/取消/返回闭环、真实 Mac 最小窗口与 iPhone/iPad/Intel 实机仍待隔离验收。组件图片不证明全应用无裁切、全部控件可达或语言质量。原候选验收结果由原协调任务负责，不能借用为本功能提交通过。

真实服务语言质量、费用/usage、Keychain持久化、独立安全专项仍未验收；安全专项继续 `UNVERIFIED / platform-blocked`。没有请求、下载、发布包、UI应用启动、系统权限变化或用户书库变化。本片只改展示，可以反向应用本片提交恢复布局；无 schema/资产迁移，不使用删目录或覆盖其他 worktree 的回滚方式。
