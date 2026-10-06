# Mac 实际 UI 检查与小修 · 2026-10-06

基线 `6a67d1fd883f79737d0e3e12c756b683a662f230`。独立分支 `feature/mac-ui-experience-20261006`，持久 checkout 位于主仓库 `.build/MacUIExperience/2026-10-06/tree`。这是工具驱动的实际 Mac App 像素、原生辅助功能树及键鼠检查，不是人工体验验收；隐藏组件渲染不计入本表。

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
| 新4 UI单次 | 实际执行4项，4失败、0通过，共8 failure (3 unexpected)、206.36秒；三个PDF方法在search-result exists/enabled/hittable等待超时，未开始段落请求；EPUB未找到WebView下window StaticText。没有重派发。 |
| 进程与结果包 | 连接断开/ executor key changed 后原session不能恢复。后续有界实际执行只读检查成功；原 xcodebuild PID27858 和 EPUB App PID27908 已不存在，全部4方法失败日志完整。wrapper仍未写最终exit，xcresult仍缺Info.plist；进程退出码与结果包完整性UNKNOWN。 |
| 后续段落CUA | 整合harness BUILD SUCCEEDED；真实CUA定位调用返回Transport closed，没有重复尝试或更改权限。 |

首个 PDF 失败的前置干扰已定位到日志：147行输入 `window`，输入值断言未失败；163–168行点击 search-submit 时出现来自目标 App 的 Dialog，232行起含 `window` / `win` 和中文输入候选；538–540行记录 interruption 未被处理，随后 search-result 等待超时。输入法候选弹窗是直接观察证据；输入尚未提交导致搜索绑定不同只是待验证推断，不能据此排除产品问题。没有切换系统输入法、处理权限弹窗或更改原56方法。EPUB 在源码156行等待 WebView 下 `window` StaticText 失败，日志743–748行另记 AXHeading 的 automation type mismatch；原创 fixture 确实含以 window 开头的段落，仍不能确定是加载、AX投影或选择器问题。没有为猜测根因修改产品或削弱断言。

上述UI失败的最终根因尚未确认，不能排除产品可访问性/布局回归，也不能把选择器失败作为段落功能通过。新typed展示/确认/保存/引用、insufficient/invalid/truncated/slow、EPUB引用的实际GUI闭环仍NOT-VERIFIED；542离线回归不替代它们。自动与自定义附件均keepNever，只交付此前查看过的19张自制窗口图，未读取/导出自动截图。只读复核记录见 `ui-readonly-diagnosis.json`；没有重新派发UI测试。

自动审批拒绝在本独立tree按现有package-lock补齐npm开发依赖（jsdom26.1.0、registry.npmjs.org、ignore-scripts、独立cache/空配置），理由为超出“不安装组件/不依赖外部安装”约束。安装没有执行，也未换路线。主任务已收到具体命令向用户请求新增授权，当前仍暂停；两项NOT-RUN不能称完整Node全绿。

证据为 evidence 下各 command.json/log、isolated-uitest-execution-identity.json、integrated-original-ui-protection.json、paragraph-ui-once.log、ParagraphUI.xcresult（未收尾）。末次实际源码候选为ef203f3；后续报告提交只改文档。未push/dispatch/merge，公开发布另批。

Library保存没有开始API写入：当前/usr/bin/python3不支持官方helper的`str | None`类型标注，helper在导入时退出；现有环境依赖查询也返回Transport closed。没有改helper、安装Python或换直接写入路线，没有有效library_file_id；图片与报告仅按本地路径交付。

## 后续独立审计索引

本阶段不提前扩展全仓审计。冻结源码候选为 `ef203f3229596d9c2c800e68de2e7b66987173ba`；后续本任务提交只更新本报告，最终完整 HEAD 和逐项实际命令/日志哈希见 `evidence/FINAL-RECEIPT.json`。验收仍有上列阻塞，不能当作已满足后续审计的启动前提或发布门槛。

- 格式有限子集矩阵：[ALL-FORMATS-INTEGRATION-2026-10-04.md](ALL-FORMATS-INTEGRATION-2026-10-04.md#当前能力与明确边界) 28–37行；旧/新格式边界并读 [WEB-ARCHIVE-FORMATS.md](WEB-ARCHIVE-FORMATS.md)、[TEXT-FORMATS-SLICE.md](TEXT-FORMATS-SLICE.md) 和 [ADR-COMIC-ARCHIVE-FORMATS.md](ADR-COMIC-ARCHIVE-FORMATS.md)。本次实际窗口检查仅 PDF/EPUB。
- 来源与许可证：根目录 `LICENSE`、`SOURCE-NOTICES.md`、`THIRD_PARTY_NOTICES.md`；`engine-build/vendor/kookit/LICENSE`、`engine-build/licenses/`、`engine-build/test-licenses/` 与四份 `*BUNDLE-INPUTS.json`；`PDFnoReaders/Resources/{EPUB,Comics,DOCX,TextFormats,Ebooks}/Notices.txt`；`PDFnoComicCodecs/SOURCE.json`、`PDFnoComicCodecs/Licenses/` 和 `PDFnoServices/Resources/ComicCodecs/{SOURCE.json,NOTICES.txt}`。路径相对本 worktree 的 `apple/Packages/PDFnoKit/Sources`。
- 既有审计交接范围：[UNIFIED-VALIDATION-AND-AUDIT-HANDOFF.md](UNIFIED-VALIDATION-AND-AUDIT-HANDOFF.md)。它是审阅索引，历史测试数字不替代本候选证据，也不授权安装依赖、公开发布或重试受阻安全专项。
