# 所有格式本地联合候选 — 2026-10-04

本批把 ebook、网页归档、CBT、CB7/CBR 三个已交付候选合到已验收 main `71d54540c417915702506f67fef7d337605aa9e2` 的独立 worktree。解决新格式被误记为 CBZ、Bookno 新枚举无法编译及不支持格式缺乏明确展示的问题，同时保留 main 的真实 EPUB 选区验证和原有功能断言。**本批完成本地候选，不代表完整应用 UI 验收或发布。** 最终候选 SHA 由交付回执绑定；此文与候选代码在同一提交内。

## 输入、范围与冲突处理

| 输入 | 确切提交 | 本批使用方式 |
| --- | --- | --- |
| 已验收 main | `71d54540c417915702506f67fef7d337605aa9e2` | 独立 feature 的唯一父提交，main 工作树未改 |
| ebook＋文本章节整合 | `f7a7afede582e17e2f2fc783437ab8464aaebcd1` | 引入四种 ebook、专用 reader/store、原创建样例、四项 UI 及跨 reader 回归 |
| 网页归档＋CBT | `a751c22ae400a46b2c96d17798a5efd5db62c538` | 引入 XHTML/MHTML/可读 XML 和有限 USTAR；保留各自持久化及三＋一项 UI |
| 原生漫画解码增量 | `90ed6d6329986f6fd909c939b25df90f84e02004` | 仅此增量；CBT 的 `1ca74253b80ce6de5a945be1e4a294126adf8455` 未重复引入 |

分支为 `feature/integration-all-formats-20261004`，独立 worktree 为 `/tmp/pdfno-integration-all-formats-71d5454-20261004`。输入分支/工作树未改，用户原有 Xcode workspace/用户状态元数据按原 SHA-256 保留。最终将本批自己的临时整合历史整理成一个普通本地提交；输入提交及 main 历史保留。

具体冲突及决定：

- `LibraryModel` 同时保留 Bookno preview 与 ebook 状态所有者；切书继续取消隐藏 reader 的 AI/章节来源，四种 reader 保持独立。
- `LibraryWorkspace` 合并所有 Mac 导入类型和实际格式状态。分组声明 `[UTType]`，修复过大单一表达式的 Swift 类型检查失败。移动入口仍只开放已有 PDF，编译通过不宣称新格式移动阅读完成。
- `Package.swift` 同时保留 ebook reader/UI 资源及原生漫画 C target/services 资源；工程生成器保留 ebook UI 文件接入。
- `SOURCE-NOTICES`、`THIRD_PARTY_NOTICES`、任务/验证文档保留各输入来源和完整许可证。生成资源和上游源代码均未为解决冲突而改写。
- ebook 输入也包含 EPUB 选区竞态修复；最终保留 main `71d5454` 的更严格实现，**EPUBReaderSession、reader.js、EPUB engine 与 EPUBChapterWebKitTests 均逐字等于 main**。保持实际 DOM 返回选区及请求/会话/版本/来源/范围/Unicode 引文核验，伪造同长度引文负例仍在。
- `NativeUITests` 保留 main 整个文件的所有行及原 CBZ 方法体，新增方法与 helper 仅追加；继承的 checkbox 状态查询修复保留。新增漫画错误恢复 helper 按 ZIP/USTAR/native archive 区分正确错误提示。
- Bookno 的旧文本参数测试原用 `TextFileFormat.allCases`；新枚举导致它意外给旧纯文本 fixture 增加三个不支持格式。参数明确恢复为原来的 TXT/Markdown/HTML 三项，**原测试方法体、全部断言及三个正例不变**；新格式使用真实 XML/MIME/ebook/漫画样例另做拒绝回归。BooknoExchangeTests 整文件等于 main。

## 当前能力与明确边界

| 新格式 | Mac 候选准入 | 尚未支持 |
| --- | --- | --- |
| MOBI / AZW | 真实 BOOKMOBI PalmDB v6 或有限纯 v8；无压缩/PalmDOC；保留真实扩展名与 contentKind | DRM、HUFF/CDIC、combo、原始 NCX/guide、通用 Kindle、广泛编码/媒体/版式兼容 |
| AZW3 | 真实纯 KF8 v8 skeleton/fragment 索引 | MOBI6 改名、combo、固定版式、内嵌媒体和原始 NCX/guide |
| FB2 | 严格 UTF-8、正确 FictionBook2 命名空间和有限主正文 | ZIP、其他编码、DTD/实体、binary、附加非线性主体 |
| XHTML / XML | 严格 XHTML，或无命名空间 `document` 明确可读词汇，投影到现有 HTML 链 | 任意 XML schema、DocBook/TEI、DTD/未知命名空间、资源与布局保真 |
| MHTML | 平面 multipart/related、唯一 HTML、有限编码/part/资源预算 | 嵌套/alternative、未知媒体、旧编码、原始 CSS/图片显示、网络归档加载 |
| CBT | 未压缩 POSIX USTAR＋已有 PNG/JPEG 漫画路线 | PAX/GNU、压缩包装、链接/特殊条目 |
| CB7 | 真实 7z 明文头、非 solid、简单 COPY/LZMA1/LZMA2、CRC 及实际解码预算 | 加密/编码头、solid、其他 coder/链、多卷/SFX、未知条目 |
| CBR | 有限 RAR4/RAR5 **STORE**，严格头/CRC/结束位置 | **压缩 RAR**、加密/solid/分卷/额外记录等；不承诺通用 CBR |

ebook 选文、笔记、精确回跳与进度使用专用 `ebook-kookit-v1.json`、edition/hash/format/contentKind/section/block/精确 UTF-16 引文；网页使用既有文本 store 的独立真实类型；漫画保持独立 CBZ/CBT/CB7/CBR manifest 与原件，不自动迁移或改写原格式。混合格式切换、重启、元数据、封面、进度和笔记的交叉回归仅使用原创 fixture 和 UUID 临时 store。旧版 app 遇到新增 enum/manifest 值可能明确拒绝，降级前须保留 manifest、backup 和 Originals；本批没有实际用户迁移。

新漫画进入书库搜索/元数据时按实际 `.cbt/.cb7/.cbr` 识别，原 `.comic="CBZ"` 身份保持。覆盖源格式和 CoverIdentity 一致；伪装成 CBZ 的 CB7 搜索返回被拒绝。漫画 OCR/AI/选区笔记、原图缩放/连续滚动、ebook 搜索/笔记正文编辑/AI、新文本格式 AI、移动新格式阅读、真机/旧 OS/完整无障碍仍不因本批自动完成。

## Bookno 联合适配

Bookno 的七种 wire namespace 仍是 PDF/EPUB/CBZ/DOCX/TXT/Markdown/HTML，没有擅自拓宽同步协议。本批新增 `BooknoPreviewCatalog` 把可选书目与不支持书目分开：**CBT、CB7、CBR、XHTML、MHTML、XML、MOBI、AZW、AZW3、FB2** 在 preview 显示标题和真实格式，标注“暂不可预览”，不构造假 DTO。旧 choices-only catalog 遇到不支持格式明确抛错；snapshot 调用允许用户继续选择已支持书目。materialize 再核最新 edition/format/hash，伪装 CB7→CBZ 被拒绝。

Bookno 原先的默认关闭、明确范围、已保存笔记正文、既存封面 SHA 去重、内存 mock/回执/重放/关闭清除仍保留。新拒绝不会删除、转码或改写原件/笔记。**Bookno API 仍未连接，此次不是真实同步。** 不读取 Keychain/真实 API/key，也未产生实际 Bookno 发送、导出文件或账户设置。

## 许可证、资源复现及原有成果

AGPL-3.0-or-later 项目路线保留。原来获批的 Kookit 1.0.4 固定源码及完整 AGPL/foliate MIT 来源记录保留；本批未重新选引擎。原生漫画路线沿用用户已明确批准的 libarchive **3.8.9**＋liblzma **5.8.4** selected source，固定官方源/hash/原许可证/原配置见 [codec evidence](COMIC-CODEC-VALIDATION-2026-10-04.md) 及 SOURCE.json。96 项源/头/许可核验通过；108 个该增量源码与资源文件逐字等于输入 `90ed6d6`。不引入 UnRAR、CLI/WASM/全局安装或新 decoder。

本轮从既有 ebook worktree 只读复制其忽略的 node_modules 到自己的隔离树；67 个已安装包版本与合并 lock 一致，39 个测试依赖原许可记录核验。没有联网下载或 npm 安装。EPUB/comics/DOCX/text/ebook 五个资源 build、三个新增 fixture generator、原样例 inventory 和 Apple project generator 均成功；169 个已跟踪资源/fixture/project/codec 文件前后 SHA-256 相同。

main 的 **83 项正式需求定义与状态未改，ledger 字节未改**。格式矩阵只更新候选状态/有限边界，不宣称全部阅读目标验收。旧说明里的“CBR 尚无 decoder”按新获批增量纠正，ebook 的“待实现”改为本地候选。未把历史分支 UI 编译或 main 的旧 CI 成功当作本批实际 UI 通过。

原样上游 C、许可证和完整 notices 带有105项空白诊断（19文件，含space-before-tab），保持原来源字节；排除这些**已核对原始输入**后的自有改动 `git diff --check` 无诊断。没有通过格式化原许可证消除告警。现有 libarchive 整数精度、DOCX 测试 unused-local、AppIntents metadata 告警保留在日志；构建成功不等于零告警或安全审计完成。

## 本地实测结果与未运行门槛

工具链：Xcode **27.0 / 27A266a**；Apple Swift **6.4**；Node **20.20.2**；Python **3.9.6**。构建与 SwiftPM 均 jobs=2，两个平台顺序进行、独立 HOME/module/package/derived-data 目录、标准 SwiftPM 沙箱、unsigned，不运行用户应用/窗口/模拟器。

| 检查 | 本批实际结果 |
| --- | --- |
| 选定 Swift 离线/非附着 WebKit 回归 | **254 tests / 34 suites，3.392s，通过**，包含三项新增所有格式联合回归 |
| Node 六组回归 | **25/25，0 fail/skip，534.959ms，通过** |
| 资源/fixture/project 复现 | **169 文件哈希未变化** |
| Source guard / ledger | 最终统计见 [本地证据](ALL-FORMATS-LOCAL-EVIDENCE.json)；**8/8 ledger 回归通过**，83定义/状态保持 |
| 原生 codec guard | **96** 个 selected source/header/license 与 **6** 个真实原创建容器 fixture，通过 |
| Mac build-for-testing | **TEST BUILD SUCCEEDED**；app/UI bundle 均 arm64＋x86_64；两份 Mac UI 文件均双架构编译 |
| iPhone/iPad Simulator build-for-testing | **TEST BUILD SUCCEEDED**；app arm64＋x86_64；真实移动 target 支持 iPhone/iPad |
| 本地实际 UI 自动化 | **0 项执行**；已编译的完整 Mac 清单为 **40 项** |
| 本批远端 CI / 发布 | **未运行 / 未推送 / 未合并 main** |
| 独立安全专项 | **UNVERIFIED / 原平台阻塞**，未重试、未替代或改变结论 |

选定 Swift 回归明确排除需要 NSWindow 的16个方法定义：ComicWebKitTests 2、EPUBWebKitTests 4、EPUBChapterWebKitTests 4、TextChapterIntegrationTests 3、DeepSeekSelfTest 的 isolatedNativeView 1、EbookReader 的 actualKookitSourceNotesAndProgressReopen 1（参数化四格式）、EbookTextChapterIntegration 的 directEbookImportAndOpenCancel… 1。它们保留并编译，之后须在同一最终 SHA 的完整隔离 CI 执行；**254不是完整 Swift 验收计数**。

三项新联合回归实际覆盖：混合书库支持/不支持 Bookno 标识和原件不变；四漫画搜索/元数据/封面/来源一致与伪造别名拒绝；真实 MOBI/三网页/CB7 reader 切换、笔记/独立进度、重启和明确 Bookno 拒绝。WebKit 为非附着视图，无 NSWindow/用户界面自动化。

失败记录没有抹去：初始普通 SwiftPM 被外层 OS sandbox 的 `sandbox_apply: Operation not permitted` 阻止，尚未编译；按已授权普通回归范围使用受审批工具执行**同一标准命令**后继续，不使用 disable-sandbox。第一次编译遇到导入类型表达式类型检查失败，改为有类型分组。随后254项执行有5个 issue：旧 Bookno 参数意外扩展的3项及新联合测试把 viewport 进度错误等同于六字符选区的2项；前者恢复原三项，后者设置独立、真实的一个 scalar 阅读 checkpoint，并保留六字符笔记精确引文和重启断言，**未改生产进度/reader代码**。之后同一选择范围全通过。所有失败/成功日志及哈希保留。早期自己的临时 cherry 冲突标记在后续整合中清除，最终提交源码及扫描无冲突标记；未改输入历史。

## 全部 UI 与后续验收安排

[ALL-FORMATS-UI-INVENTORY.json](ALL-FORMATS-UI-INVENTORY.json) 列出全部方法：**原29＋Bookno1＋ebook4＋网页3＋CBT1＋CB7/CBR2＝40**。NativeUITests 36、EbookFormatUITests 4，缺失/重名均0。原30完整内容保留。编译结果不计成实际执行；之前 main/各分支测试数字仅是历史证据。

下一步若获授权，普通推送这个确切候选到自己的 feature 分支，执行原 unfiltered **Native checks**（完整 Swift、双端 build、全部40 UI）及 **Bounded comic archive checks**；ebook workflow 也保留，将按实际触发结果记录，不作为完整验收的替代。UI 180/240秒单项限额不变；Native job 总预算35→50分钟，只给新增10项及源码构建留足总时间，无 only-testing/跳过/缩减原断言。CI 须核对实际40项名称/数量/0fail/0skip/0missing/0duplicate及确切 head SHA。失败只修本批、保留历史证据、对新SHA完整重跑。**本轮未获该推送/CI授权，更未获本批 main 合并授权。**

日语候选 `55405ad8e221b38d2a3f710ba277bf85ec94ccc6` 未引入。只读比较其变更路径，和本批重叠三项：`PDFnoUI/LibraryModel.swift`、`PDFnoUI/LibraryWorkspace.swift`、`apple/Tests/NativeUITests.swift`。后续另获范围授权才整合：合并独立状态所有者、保留各 reader 来源屏障和默认额度/取消逻辑，追加 UI 后重新精确清点并统一完整验收。此处不代表日语源码/测试已在本批验证。

本批未触碰 main、输入工作树、其他工人、账户/签名/CloudKit 权限、Library、真实 key/API、用户应用/书库或夜间关机；也未发布/合并/实际 UI运行。当前没有本地实施阻塞。唯一交付门槛是后续明确授权的候选推送与完整隔离 CI；安全专项仍保留原独立缺口。
