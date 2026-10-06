# Mac 实际 UI 检查与小修 · 2026-10-06

基线 `6a67d1fd883f79737d0e3e12c756b683a662f230`。独立分支 `feature/mac-ui-experience-20261006`，持久 checkout 位于主仓库 `.build/MacUIExperience/2026-10-06/tree`。这是工具驱动的实际 Mac App 像素、原生辅助功能树及键鼠检查，不是人工体验验收；隐藏组件渲染不计入本表。

最终单次完整 UI 在 `95f6e4b3d2f5a3ff0c19756a56ef6878282a4978` 实测 **60项：33通过、27失败、0跳过，命令退出65**；正式xcresult摘要、方法树、日志与静态清单逐项一致，**完整UI验收失败**。新增段落4项全部通过，原56为29通过、27失败。逐项首个断言及保存面板服务崩溃证据见 [完整60项矩阵](MAC-UI-FULL60-2026-10-06.md)，根因尚未全部确认，没有自动重跑。此前4项隔离复测成功与首次4失败/断连记录均保留。生产代码仍等于完整542项Swift验证的ef203f3；新驱动的22项离线/DOM回归与专用build通过。两项电子书Node因安装未获批准仍NOT-RUN，真实服务、移动实际UI、安全专项等边界未因此改变。

## 执行与隔离

环境：arm64 macOS 27.0.1 (26A434)、Xcode 27.0 (27A266a)、Swift 6.4。专用 bundle 为 `org.pdfno.ui.experience20261006.PDFnoMac`，忽略目录内复制工程在 App 初始化前强制绑定 UUID `5125DAB3-0972-4882-9C05-DBE37DD0DEEB`，Library 为 `/tmp/PDFno-UITests-5125DAB3-0972-4882-9C05-DBE37DD0DEEB`，transport 为 offline。App-only 外观/窗口菜单只存在于测试副本；系统主题、权限和受版本管理的 App 入口未改。原书为仓库自制 PDF/EPUB，导入后的两个 Originals 已与仓库 fixture 逐字节比较相同。

首次 CUA 选择专用构建路径时工具自动启动，启动环境尚未注入，进入默认 Library 路径；立即退出该开发进程，未打开书籍/笔记、未截图。启动代码可能自动读取默认 manifest/记录，不能宣称全过程未加载默认数据。随后暂停 GUI，以固定路径 stat 检查默认 Library 的文件大小/时间，没有用工具读取私有文件正文、书名、引文或 ID。已观察时间均早于本次启动，但没有启动前快照，瞬时写入/迁移不能绝对排除，结论为 **UNKNOWN**。隔离 GUI 后同一固定路径 metadata 与暂停检查时相同（`default-library-stat-after-gui.json`）。没有清理、回滚默认 Library。后续先在复制入口硬绑定隔离，再确认构建路径/bundle/PID、初始空书库和 UUID store，才恢复 GUI。用户正式 App 未关闭、替换或重置。

证据根位于主仓库 `.build/MacUIExperience/2026-10-06/evidence`。`session.json`、`isolation-receipt.json`、`running-app-metadata.txt`、`library-metadata-check.json` 记录上述边界。每个检查保存实际命令、退出码、日志 SHA；所有重型操作使用原 `run-heavy-check.py` 和同一 `PDFnoNativeHeavyChecks.lock`，最多两 jobs。

## 实际检查

| 范围 | 实际结果与证据 |
| --- | --- |
| 空书库、列表/网格、重开 | 初始空状态可见；自制 PDF/EPUB 导入、列表/网格切换、重启后两本书与已保存笔记保留。图 01、13，`library-grid-narrow-restart.ax.txt`。 |
| PDF 搜索、目录、返回 | `useful` 搜索跳到第 2 页，返回第 1 页；再次将查询准确替换为 `window`；原生输入焦点保留。修复后行中部点击可跳转。图 02、14，`pdf-row-center-fixed.ax.txt`。 |
| PDF 选文与笔记 | 原生搜索选区 `window`；Unicode 用户笔记草稿关闭再开原样保留，保存后清空输入，已保存正文独立保留。编辑中 Command-Option-Right 不翻页。图 03、05，`fixture-store-verification.json`。 |
| 阅读键盘 | PDF 画布焦点下 Command-Option-左右键实际翻页，Command-F 展开导航；Command-Shift-F 打开书库搜索。编辑器/设置 Tab/Escape 流程如相应行。`pdf-canvas-keyboard-next.ax.txt`、`pdf-canvas-keyboard-previous.ax.txt`、`pdf-command-f-opens-navigation.ax.txt`。 |
| EPUB 目录、来源、ruby、竖排 | 英文章节跳到日本语章节后返回；原书 ruby 保留；切竖排后返回原章节恢复横排。目录右侧空白点击修复已实测。图 07、15、16。 |
| EPUB 笔记、同词重选 | Unicode 草稿关闭恢复、保存成功。修复后保存仍确认真实 DOM `window`，关闭、同词重选可再次固定 AI 来源 UTF-16 22–28。图 08、17，`ai-same-word-fixed-source.ax.txt`。 |
| AI 预览、确认、mock、保存 | 空来源时开始禁用；独立核对来源、接收方与费用并手动同意后开始本地 mock；结果先未保存，手动保存用户正文后显示已保存；保存来源按钮返回 EPUB。没有真实 API/key。图 09、11。 |
| 书库笔记搜索、空/错误状态 | Command-Shift-F 打开；`日本語` 找到准确已保存 PDF 用户正文并回源；无匹配提示与清空为空查询提示正常。图 12，`library-search-no-results.ax.txt`、`library-search-cleared.ax.txt`。 |
| 设置、取消、局部错误、焦点 | 分类切换可见；取消/ Escape 回阅读；独立 BYOK `http://fixture.invalid` 仅本地校验出现明确 HTTPS 错误，无密钥/发送；Tab 从服务名称进入 endpoint。图 04、10、19。 |
| 浅/深、常规/最小窗口 | App-only 外观实际切换；常规 1180×780 与内容最小 720×520 实测。最小 EPUB 原生 toolbar 溢出菜单可打开并翻到第 2 页。图 13、14、18、19。 |

截图均为专用 App 单窗口和自制 fixture，无桌面/私人内容。截图编号对应 `evidence/screenshots/*.png`，本地路径是交付；Library 附件只以成功返回的真实标识为准。

## 问题与修复

1. **P1 EPUB 保存后同词来源丢失。** `request()` 清空 native selection；引擎去重使同一 DOM 选区不会再次通知。`notes` 回复新增真实 `noteSelection`，native 仅在既有身份/request/version 核验后解码当前章节合法 anchor；空 DOM selection 仍保持 nil，不恢复缓存。新真实 WebKit 回归覆盖保留、空选区、同词重新选择、精确来源验证和章节切换。
2. **P2 PDF 导航 / EPUB 目录行点击区域偏窄。** 原行中心无效，文字处成功。现有 Button 标签扩为整行并设置 contentShape；原搜索输入顶部布局、IDs、同步 PDF session 核验和 EPUB 原锚点导航保留。实际像素点击已验证。
3. **P3 后续布局事项。** 最小窗阅读工具换行占据较多高度；设置在常规父窗口仍默认窄分类 picker。均可滚动/操作，本次只记录，不作全新视觉设计。

## 本阶段验证

| 检查 | 结果 |
| --- | --- |
| 完整 Swift | 521 tests / 65 suites 通过；基线 520 + 新真实 WebKit 1。`swift-ui-fixes-command.json` / `.log`。 |
| Node | 14/14 通过、0 skipped；loader/rangy/comics/docx。`node-regression-command.json` / `.log`。 |
| EPUB engine 再生 | 188 inputs，vendor SHA 核验通过；使用现有依赖本地复制再生，消除 symlink 路径噪声，清单/Notices 未变。`engine-build-reproducible-command.json`。 |
| 隔离 Mac build + GUI | BUILD SUCCEEDED；两项修复实际回归通过。`mac-harness-fixed-command.json` / `.log`。 |
| 保护字节 | 原 56 UI 方法所在 4 文件逐字节未改；来源/草稿/原设置保护文件相同；两个 Originals 字节未变。`ui-fixes-protection.json`。 |

本表仅本阶段小修候选结果；后续段落解释的单一整合与完整构建/新 UI 结果会有独立收据，不能套用本表或旧 main CI。

## 未验收

真实服务/语言质量/费用与 usage、真实密钥、VoiceOver/输入法人工流程、Intel runtime、移动 App 实机/实际 UI、损坏 Library/导入错误与加载过渡均未由本次实际 GUI 验收。已有安全专项保持 **UNVERIFIED / platform-blocked**，未重试。未 push、dispatch 或 merge；新公开发布另行获得授权。

## 段落解释单一整合结果

已审阅段落提交 `0950727f8c1f1b8a3cb70905365d292f08e4b079`、完整交接及 LibraryModel 四处 callback patch。它没有修改本任务 reader.js/EPUBReaderSession/EPUBWebKitTests/导航布局，无冲突合入为 `ef203f3229596d9c2c800e68de2e7b66987173ba`，完整保留 `b4c2b87` 小修。

| 整合候选检查 | 实际结果 |
| --- | --- |
| 完整 Swift | 542 tests / 66 suites PASS，--no-parallel、2 jobs、共享 heavy lock。 |
| Mac build-for-testing | TEST BUILD SUCCEEDED，arm64+x86_64、未签名；60 UI方法全部编译，常规 bundle 不启动。 |
| iOS Simulator build-for-testing | TEST BUILD SUCCEEDED，arm64+x86_64；未启动 Simulator。 |
| 专用 App/runner | TEST BUILD SUCCEEDED，实际产品 Info/xctestrun 核对独立 org.pdfno.integration.experience20261006.PDFnoMac 与 runner，合法测试UUID或硬绑定备用UUID、强制offline。 |
| guards/再生 | source guard685、codec96+原创fixture6、账本8项通过，Xcode工程/原PDF再生无diff；原56方法正文逐字节未改，新总60。 |
| 可用 Node | loader/rangy/comics/docx 14/14 PASS、0 skipped。两个电子书Node文件缺 jsdom@26.1.0，在加载前退出，NOT-RUN。 |
| 新4 UI首次单次 | 实际执行4项，4失败、0通过，共8 failure (3 unexpected)、206.36秒；三个PDF方法在search-result exists/enabled/hittable等待超时，未开始段落请求；EPUB未找到WebView下window StaticText。断连时没有重派发；后续完成诊断/驱动修正后另获授权，复测结果见末节。 |
| 进程与结果包 | 连接断开/ executor key changed 后原session不能恢复。后续有界实际执行只读检查成功；原 xcodebuild PID27858 和 EPUB App PID27908 已不存在，全部4方法失败日志完整。wrapper仍未写最终exit，xcresult仍缺Info.plist；进程退出码与结果包完整性UNKNOWN。 |
| 首次后续段落CUA | 整合harness BUILD SUCCEEDED；真实CUA定位调用返回Transport closed，没有重复尝试或更改权限。随后新增4项通过独立XCTest驱动实际复测，不表示CUA已恢复。 |

首个 PDF 失败的前置干扰已定位到日志：147行输入 `window`，输入值断言未失败；163–168行点击 search-submit 时出现来自目标 App 的 Dialog，232行起含 `window` / `win` 和中文输入候选；538–540行记录 interruption 未被处理，随后 search-result 等待超时。输入法候选弹窗是直接观察证据；输入尚未提交导致搜索绑定不同只是待验证推断，不能据此排除产品问题。没有切换系统输入法、处理权限弹窗或更改原56方法。EPUB 在源码156行等待 WebView 下 `window` StaticText 失败，日志743–748行另记 AXHeading 的 automation type mismatch；原创 fixture 确实含以 window 开头的段落，仍不能确定是加载、AX投影或选择器问题。没有为猜测根因修改产品或削弱断言。

首次只读诊断时最终根因尚未确认，不能排除产品可访问性/布局回归，也不能把选择器失败作为段落功能通过；当时新typed展示/确认/保存/引用、insufficient/invalid/truncated/slow、EPUB引用的实际GUI闭环均NOT-VERIFIED。542离线回归不替代实际GUI。自动与自定义附件均keepNever，只交付此前查看过的19张自制窗口图，未读取/导出自动截图。该阶段只读复核记录见 `ui-readonly-diagnosis.json`，没有重派发。后续驱动修正及实际复测见下面两个阶段。

自动审批拒绝在本独立tree按现有package-lock补齐npm开发依赖（jsdom26.1.0、registry.npmjs.org、ignore-scripts、独立cache/空配置），理由为超出“不安装组件/不依赖外部安装”约束。安装没有执行，也未换路线。主任务已收到具体命令向用户请求新增授权，当前仍暂停；两项NOT-RUN不能称完整Node全绿。

首次整合证据为 evidence 下各 command.json/log、isolated-uitest-execution-identity.json、integrated-original-ui-protection.json、paragraph-ui-once.log、ParagraphUI.xcresult（未收尾）。当时实际源码候选为ef203f3，75e83aa/a0d15fe仅改文档；随后5fa3843修正测试驱动，生产代码不变。未push/dispatch/merge，公开发布另批。

Library保存没有开始API写入：当前/usr/bin/python3不支持官方helper的`str | None`类型标注，helper在导入时退出；现有环境依赖查询也返回Transport closed。没有改helper、安装Python或换直接写入路线，没有有效library_file_id；图片与报告仅按本地路径交付。

## 后续独立审计索引

本阶段不提前扩展全仓审计。完整套件已验证的源码候选为 `ef203f3229596d9c2c800e68de2e7b66987173ba`；`75e83aa` / `a0d15fe` 只更新本报告。后续新增测试入口修正见下一节，生产代码仍等于 ef203f3，最终完整 HEAD 和逐项实际命令/日志哈希见 `evidence/FINAL-RECEIPT.json`。验收仍有上列阻塞，不能当作已满足后续审计的启动前提或发布门槛。

- 格式有限子集矩阵：[ALL-FORMATS-INTEGRATION-2026-10-04.md](ALL-FORMATS-INTEGRATION-2026-10-04.md#当前能力与明确边界) 28–37行；旧/新格式边界并读 [WEB-ARCHIVE-FORMATS.md](WEB-ARCHIVE-FORMATS.md)、[TEXT-FORMATS-SLICE.md](TEXT-FORMATS-SLICE.md) 和 [ADR-COMIC-ARCHIVE-FORMATS.md](ADR-COMIC-ARCHIVE-FORMATS.md)。本次实际窗口检查仅 PDF/EPUB。
- 来源与许可证：根目录 `LICENSE`、`SOURCE-NOTICES.md`、`THIRD_PARTY_NOTICES.md`；`engine-build/vendor/kookit/LICENSE`、`engine-build/licenses/`、`engine-build/test-licenses/` 与四份 `*BUNDLE-INPUTS.json`；`PDFnoReaders/Resources/{EPUB,Comics,DOCX,TextFormats,Ebooks}/Notices.txt`；`PDFnoComicCodecs/SOURCE.json`、`PDFnoComicCodecs/Licenses/` 和 `PDFnoServices/Resources/ComicCodecs/{SOURCE.json,NOTICES.txt}`。路径相对本 worktree 的 `apple/Packages/PDFnoKit/Sources`。
- 既有审计交接范围：[UNIFIED-VALIDATION-AND-AUDIT-HANDOFF.md](UNIFIED-VALIDATION-AND-AUDIT-HANDOFF.md)。它是审阅索引，历史测试数字不替代本候选证据，也不授权安装依赖、公开发布或重试受阻安全专项。

## 四 UI 前置修正阶段

收到继续本轮验收的指令后，单次只读执行连接成功，仍在原独立树工作。对照原 `NativeUITests` 已有 `enterSearch` / `webText` 与保存的原创 AX 树，新增段落入口存在两个明确遗漏：直接 typeText 会经过用户输入法组合态，而原路径通过原生粘贴输入；只查 StaticText 的 label，遗漏原路径对任意 AX 角色 label 及字符串 value 的兼容。它们与已有失败日志吻合，但只能确认测试前置缺陷，不能在实际复测前宣称产品最终根因已排除。

仅修改 `ReadingIntegrationUITests.swift` 新段落 helpers/typed 方法并导入 AppKit；原 `search` helper 和原56方法不动。新 `paragraphPaste` 仅粘贴原创查询、虚构凭据、原创用户正文，旧剪贴板各类型数据只在内存保留，changeCount 未被其他写入改变时恢复，不输出剪贴板内容、不切系统输入法。新 `paragraphWebText` 使用原生 suite 的 label/value 查询，仍通过真实 WebKit 坐标双击选文，没有 JS 构造选区。原4项所有断言保留，另外增加固定来源必须严格等于 `window`、用户草稿必须严格等于输入正文的检查。

前置验证：`paragraph-ui-preflight-swift-command.json` 退出0，22 tests / 2 suites PASS（21段落方法＋真实 DOM 同词重选）；`paragraph-ui-preflight-build-command.json` 退出0，专用 App/runner TEST BUILD SUCCEEDED，60项UI已编译，没有运行App。`paragraph-ui-preflight-protection.json` 确认原56方法逐字节保留、新4项原断言保留、生产代码没有修改。专用 App executable SHA256仍为 `285f3c83cffb1c365d46b9b7e44f3d442b72e7f161695f881e32923091608fc3`，与失败那次相同。原 xcodebuild/runner/EPUB App 三个精确PID27858/27861/27908的后续只读ps检查均不存在，未终止其他进程；原退出码仍UNKNOWN。

该阶段准备隔离复测方案但未派发：独立 `ParagraphPreflight.xctestrun`，同一经核验 App/runner ID与路径，runner环境 `PDFNO_ISOLATED_UI_APPLICATION_ID` 指向专用 App；每方法 helper 自动新 UUID Library、offline scenario，UI附件 keepNever。共享 heavy lock 内串行 only-testing 原新增4方法、180/240秒预算，结果写入全新 `ParagraphUIPreflight.xcresult`，不覆盖第一次日志/结果包。开始前再核实际连接/产品身份/锁；断连则只保全现有日志，不能把失联当成功或自动重派发。具体方案、产品/测试bundle SHA、边界见 `paragraph-ui-retest-plan.json`。这一前置阶段仍保留首次4失败状态；随后收到一次隔离复测授权，执行结果如下。

## 新增四 UI 隔离复测实际结果

在5fa3843干净树单次只读执行连接成功；App、runner、测试bundle、测试源码及xctestrun全部哈希与已编译方案相同，独立App入口UUID/offline守卫保持，45.4GiB可用空间，共享锁检查空闲。随后只派发一次已授权复测，08:48UTC进入测试，08:52UTC收尾；没有改系统输入法、权限或用户App/Library，没有安装npm。

| 实际方法 | 结果 | 方法秒数 |
| --- | --- | --- |
| testMacParagraphCancelDoesNotPublishOrSave | PASS | 42.384 |
| testMacParagraphEPUBCitationReturnsToCanonicalRange | PASS | 37.751 |
| testMacParagraphInsufficientAndInvalidResponsesCannotSave | PASS，覆盖insufficient/invalid/truncated三个独立App场景 | 115.237 |
| testMacParagraphTypedEvidenceConsentManualSaveAndSource | PASS，保留原断言并通过严格来源window/用户正文等值检查 | 58.451 |

总计 **4 tests、0 failures、0 unexpected、0 skipped**；suite 253.822秒。`paragraph-ui-retest-command.json` 实际退出码 **0**，日志 `TEST EXECUTE SUCCEEDED`；新 `ParagraphUIPreflight.xcresult/Info.plist` 存在，正式 `xcresulttool get test-results summary` 返回 Passed / passedTests4 / failedTests0 / skippedTests0 / totalTestCount4。首次默认沙箱读摘要因TestReport缓存保存权限退出64；只对该自有结果路径获批读取后退出0，没有修改权限或重新启动测试。结果包已收尾、摘要可解析；首次未收尾的ParagraphUI.xcresult不被修写或代替。

证据：`paragraph-ui-retest-execution-identity.json`、`paragraph-ui-retest-command.json` / `.log`、`paragraph-ui-retest-outcome.json`、`paragraph-ui-retest-xcresult-summary-approved-command.json` / `.log`。首次日志SHA与既有失败收据相同，全部专用产品哈希复测后仍相同；生产App二进制没有改变，而两项前置修正后真实流程均越过首次阻塞，支持测试驱动遗漏的诊断。没有把该结果包装为人工或真实模型语言质量验收。

上述4项复测阶段，原56项只保留/编译，随后另获完整60项单次执行授权，实际结果如下。本任务自制PDF/EPUB实际体验及小修截图仍为19张，仅本地交付，未新增导出自动截图。两项ebook Node仍NOT-RUN（npm待批准），Library官方上传仍在导入前受Python版本阻塞；真实服务/解释质量/usage、VoiceOver/输入法人工流程、移动实际UI/Intel runtime/损坏库加载错误等仍未验收，安全专项UNVERIFIED/platform-blocked不重试。最终HEAD见FINAL-RECEIPT；尚未开展全仓审计、push/dispatch/merge或公开发布。

## 最终单次完整60项UI

在95f6e4干净候选上重新核对专用App、runner、测试bundle、xctestrun和测试源码哈希，原56正文保持，新增4原断言与精确来源/正文断言保持。复用5fa3843同源码产品；两提交之间只有文档差异。旧复测xcodebuild/runner精确PID不存在，锁空闲，45.4GiB可用后才派发。环境继续是独立bundle、每方法新UUID隔离Library、App初始化前强制offline、自制fixture、串行、keepNever附件；未改系统主题、输入法或权限。

第一次命令多余设置 `-test-iterations 1`，Xcode要求值大于1，在任何UI方法开始前退出64；当时结果包目录及Info已经被初始化，不能用Info存在推断执行成功。保留 `full60-ui-once-command.json` / `.log` 和 `Full60UIOnce.xcresult`，去掉参数后按默认单次在全新结果路径启动以下一次完整UI，没有过滤、跳过、自动重试或重复方法。

| 完整套件实测 | 结果 |
| --- | --- |
| 候选 / 实际命令UTC | 95f6e4；2026-10-06 09:11:50.105120至09:58:21.293950。 |
| 原56 | 29 PASS、27 FAIL。 |
| 新段落4 | 4 PASS：取消41.699秒、EPUB引用37.295秒、异常响应116.509秒、typed确认/保存/回源58.500秒。 |
| 全部60 | 33 PASS、27 FAIL、0 SKIP；79 failure记录（2 unexpected），suite2780.805秒；xcodebuild/wrapper退出65、TEST EXECUTE FAILED。 |
| 正式结果包 | Full60UIComplete.xcresult已收尾；正式summary与tests树读取退出0，60个唯一方法及每项结果与日志/静态清单相同，result Failed。 |
| 完成后状态 | 实际xcodebuild PID36360、runner36363不存在；共享锁空闲且未删除/改写；App/runner/test bundle二进制哈希未变。main仍6a67d1f，未跟踪project.xcworkspace保持。 |

失败涉及电子书持久化谓词、BYOK/DeepSeek与日语学习结果、整页/整章结果与取消、封面/转换、CBT/CB7/CBR、MHTML、原搜索/设置入口。[逐方法矩阵](MAC-UI-FULL60-2026-10-06.md)记录每项首个失败文件/行、完整日志行和消息；`full60-ui-outcome.json`还保留全部后续断言与正式方法节点。这里是观察结果，尚未判定全部属于产品、测试驱动或环境，不把它们全部归咎于输入法，也未修改旧测试来获得通过。

正式结果包为7个方法记录 `com.apple.appkit.xpc.openAndSavePanelService crashed in main`：CB7、CBR、CBT、封面、DOCX转换保存面板、DOCX阅读PDF入口和MHTML。它解释存在服务崩溃这一实际现象，不能排除其他产品问题。还有main-thread/QoS及SwiftUI view update中发布状态的runtime warning，尚未确认调用点。设置断言实际输入与原创预期不同，原PDF/工具搜索等待失败；输入法干扰只是已有日志支持的局部现象，不是27项统一根因。

证据：`full60-ui-complete-plan.json`、`full60-ui-complete-command.json` / `.log`、`full60-ui-outcome.json`、`full60-ui-first-failures-final.json`、`full60-ui-xcresult-{summary,tests}-command.json` / `.log`、`full60-ui-post-run-state.json`。新文档提交只记录结果，不改测试或生产代码。没有继续派发UI、安装npm、开始独立全仓审计或公开发布；完整验收仍受27项失败阻塞。

交接时另修正19张截图收据的元数据：实际像素文件为JPEG，历史文件名后缀为`.png`；此前按PNG固定偏移读取尺寸不正确，现依据JPEG SOF读取真实尺寸并补充`image/jpeg`。图片SHA/字节与原清单逐项相同，未重命名、转码或编辑。原错误清单保留为`screenshot-inventory-original-metadata.json`，修正见`screenshot-inventory.json` / `screenshot-metadata-correction.json`。仍只有本地路径交付，library_file_id为空，不能当作已上传附件。
