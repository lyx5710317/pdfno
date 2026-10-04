# PDFno

原生 Mac、iPhone、iPad 阅读器，使用 **SwiftUI + AppKit/UIKit + PDFKit**，源码保持 **AGPL-3.0-or-later**。当前包含本地 PDF、Mac EPUB／CBZ、有限 DOCX 阅读、限定选文／PDF当前页 AI 与有限正文转换开发切片，尚未发行。

2026-10-04 所有格式本地联合候选从已验收 main `71d5454` 整合有限 MOBI/AZW/AZW3/FB2、XHTML/MHTML/可读 XML、CBT/CB7/STORE-only CBR，并保留 Bookno 原七种预览协议及 main EPUB 真实选区检查。254项选定 Swift/25项 Node/两端双架构 build-for-testing 通过；完整40项 Mac UI 仅编译，尚未推送或验收。新格式当前只在 Mac 候选开放，精确能力/冲突/证据见[联合交付](docs/ALL-FORMATS-INTEGRATION-2026-10-04.md)。

现在可以导入 PDF、按文件 SHA-256 去重并保存原书副本；用 PDFKit 阅读、选字、翻页、目录和文本搜索；保存选区高亮与笔记、回到来源、恢复阅读进度。高亮只投影到内存中的 PDFDocument，原书副本不被改写。损坏或来自新版本的本地数据会停止保存，并保留原文件。Mac 书库支持列表／网格封面、PDF 首页、EPUB 内置封面与 CBZ 首图；无自动封面时显示稳定占位，可选择本地图片替换或恢复自动封面。缩略图懒加载并限制尺寸／缓存；多文档工作区仍待实现。封面实现与独立验证范围见 [封面交接](docs/COVERS-DEVELOPMENT.md)。

Mac 支持编辑已保存的 PDF／EPUB 笔记与 AI 学习笔记的用户正文，保留引文、锚点及生成结果；草稿独立保存，失败可手动重试。书库搜索覆盖书名、本地补录作者、已保存正文、引文与 AI 结果，保存编辑后自动刷新；草稿和全书正文不进入索引。书目信息旁存用于搜索，原文件名与阅读器标题保留。三片整合的本地验证及待执行 UI 范围见 [统一整合交接](docs/COVERS-NOTE-SEARCH-INTEGRATION-2026-10-04.md)。

本地候选另有 Mac 侧栏“Bookno 离线预览”：默认关闭、明确选书，已保存笔记与既存封面分别勾选，展示原引文／用户正文／AI 原结果及只读 JSON；可运行内存 mock 和同批次重放，关闭清除模拟。包含文本与 EPUB 整章来源适配，实际 Bookno API／同步尚未连接，移动预览入口未实现。见[本地整合与待验收范围](docs/BOOKNO-INTEGRATION-2026-10-04.md)。

Mac 已接入 **Kookit public core 的重排 EPUB**：目录、翻页、横竖排、作者 ruby、真实选区、高亮笔记、原文回跳和重开恢复。EPUB 使用受限 WKWebView 内容模块；书库与工具栏保持 Swift 原生，PDF 继续 PDFKit。移动 EPUB 阅读、固定版式、全面图片/字体保真和全书正文搜索尚未验收。

Mac 已增加 **CBZ / 有限 CBT、CB7、CBR 漫画阅读**：本地导入、稳定自然页序、左右方向、单双页、页跳转及进度恢复。静态PNG/JPEG先经Swift归档／像素校验、下采样，再由固定Kookit模型与受限WKWebView显示；原件不改。CBT仅支持未压缩POSIX USTAR；CB7限明文头、非solid COPY/LZMA/LZMA2；CBR限RAR4/RAR5 STORE。移动阅读、原图缩放／连续滚动、OCR和漫画AI仍未支持。见[新增原生解码边界与验证](docs/COMIC-CODEC-VALIDATION-2026-10-04.md)及[原CBZ边界](docs/ADR-CBZ-KOOKIT.md)与[验证](docs/CBZ-VALIDATION-2026-10-03.md)。

Mac 已合入 **Kookit 参考的实际 Mammoth1.13.0 DOCX 语义阅读**：导入／书库、标准标题目录、简单表格／列表、选文笔记、精确回跳与进度恢复。独立adapter直接调用同一引擎，原始DocxRender类仅作来源参考。图片／分页／字体／页眉页脚与复杂Word内容不保真；旧DOC与移动Word未支持。见[引擎与来源边界](docs/ADR-DOCX-KOOKIT-MAMMOTH.md)及[验证](docs/DOCX-VALIDATION.md)。

Mac 的现有「模型与 BYOK 设置」和「选文 AI」已接入 **DeepSeek 选文翻译／简短解释**，复用 PDF/EPUB 来源引用和独立学习笔记。用户在设置里选择 DeepSeek 预设、手动输入会话临时 key 并保存，再在阅读窗口确认固定选文、接收方与费用后亲自点击开始。仅官方 HTTPS origin 和 `deepseek-flash` 支持真实发送；其他配置仍为预览，本地 mock 必须明确选择。打开设置／书籍／学习窗口、改选区或换模式均不发送，没有失败后自动 mock。

远程选文最多 **500 UTF-16 单元、1024 输出 tokens、30 秒、每次应用会话三次网络尝试**；失败／取消也计次数，无自动重试。1024 包含 JSON 和回显引文，并非人民币费用硬上限。仅固定选文和任务发送，不添加前后文、书目、笔记、其他页或历史。响应须完整结束、JSON 有效且引文逐 Unicode scalar 匹配，引用由原生快照生成；结果不会自动保存，用户明确保存后才写独立学习文件。密钥仅在内存，清除或退出失效；空 key 保存会清除旧值。当前结果与本书最近请求记录在会话内保留；关闭学习窗口取消未完成工作。持久 Keychain、其他真实服务、SSE 与完整语言质量验收仍待实现。详见 [选文请求边界](docs/ADR-0006-DEEPSEEK-SELECTION.md)。

Mac PDF 另有受限“翻译当前页”：完整物理页≤3000 UTF-16、最多6段／每段≤500，逐scalar／grapheme保留原文。完整范围预览、用户独立临时key和确认后手动开始，独立6次会话尝试；每段1024输出tokens／30秒、失败停止余段、取消／换书阻断迟到结果，无自动重试或费用保证。双语文本对照与手动分段学习笔记保留来源，不是版式叠加或OCR。见[页翻译边界](docs/PDF-PAGE-TRANSLATION-SLICE.md)。

设置中原有独立「DeepSeek 短句自助测试」继续只处理固定原创短句，使用独立临时 key 和三次额度，不读取阅读设置密钥或书籍。
短句测试固定为 `https://api.deepseek.com/chat/completions`、`deepseek-flash`，关闭思考模式，每次输出至多 128 tokens，每次应用会话至多三次，失败／取消也计次数，无自动重试。拟议预算 ≤1 元人民币由用户在发送前确认；客户端不能强制服务商人民币账单上限。测试不读取书籍或配置预览密钥，不向磁盘保存密钥、结果或请求，不外发选文、笔记或文件。密钥输入发送时清空，关闭／重启不会保留。响应和安全错误显示在顶部「测试记录」，变化时自动滚到最新记录，也可用工具栏「查看测试记录」。关闭窗口保留本次应用会话的记录；明确「清除测试记录」也不会重置次数。3 / 3 只表示额度用完，不表示成功，旧版已被清除的结果无法恢复。

**开发和 CI 的模型请求只用虚构密钥与完全拦截的网络替身。** 2026-10-03 用户报告独立短句测试“三次测试都成功了”，记为用户报告的认证生成证据；agent 未读取真实 key、提交请求或核验账单，新选文语言质量尚未实测。 2026-10-03 无凭据检查确认官方域名 DNS、证书／主机名与 TLS 可达，`GET /models` 返回401；这不证明密钥有效、余额充足或模型生成成功。参见 [短句测试边界](docs/ADR-0005-DEEPSEEK-SELF-TEST.md)。

Mac 增加 **XHTML／MHTML／可阅读 XML** 的有限离线正文阅读，复用既有 HTML/Kookit 链路：标题目录、精确选文笔记、原文回跳及进度。XHTML 要求有效命名空间，XML 只接受限定文档结构；MHTML 只接受受限平面 MIME、单一 HTML 正文和严格编码。图片／CSS／字体不显示，外部原页面不联网加载；完整原生 UI 待隔离 CI。详见[格式边界](docs/WEB-ARCHIVE-FORMATS.md)与[本地验证](docs/WEB-ARCHIVE-VALIDATION.md)。

Mac 的“格式转换”入口可将普通 DOCX 正文导出为 UTF-8 TXT／简化 HTML：选择原件、输出格式与新保存位置，后台阶段进度、取消和失败后手动重试。原件及已有文件不会覆盖；图片、页眉页脚、复杂版式等明确不保真。见[转换矩阵与 ADR](docs/ADR-0009-LOCAL-CONVERSION.md)及[实际验证](docs/CONVERSION-VALIDATION.md)。

**其他漫画容器、其他格式阅读、其他真实 BYOK 服务、文档问答、EPUB章节／多页／整书双语翻译、生成假名、英日语法质量、Bookno API、iCloud、OCR、PDF/Word/EPUB 高保真互转和 Apple Pencil 尚未接入或验收。** 其他格式优先沿独立 Kookit adapter 路线逐项审计与验收，不因 EPUB 接入自动开放。完整功能目标和三端规划见 [v0.3 主规格](docs/PDFno_AI_Development_Spec_v0.3_Native.md)、[实施状态](docs/NATIVE-TASKS.md) 和 [引擎审计](docs/EPUB-ENGINE-AUDIT.md)。

最终阅读目标完整保留18种扩展名：**EPUB、MOBI、AZW、AZW3、FB2、PDF、TXT、DOCX、MD、CBZ、CBR、CBT、CB7、HTML、HTM、XHTML、MHTML、XML**。逐项实现状态、三端缺口和验收门槛见[完整目标矩阵](docs/PDFno_AI_Development_Spec_v0.3_Native.md#53-完整18种格式阅读目标与实际状态)。输入限定DRM-free；XML指可阅读标记文档，`.doc`不在这18种内。未来漫画AI翻译仍是目标。阅读支持与有向转换矩阵分别验收。

## 在 Xcode 中运行

打开 `apple/PDFno.xcworkspace`。选择 **PDFnoMac** 并运行于本机；选择 **PDFnoMobile** 并运行于 iPhone 或 iPad Simulator。两者是独立 application targets，移动 target 同时支持 iPhone/iPad；Mac 使用 AppKit，未采用 Catalyst。共享 `PDFnoKit` 包含 Domain、Services、Readers、UI 四个Swift模块与私有系统zlib C target `PDFnoDOCXZIP`，没有外部 Swift 包依赖。

临时开发基线为 **macOS 14 / iOS 17 / iPadOS 17，Swift 6，Xcode 16.4+**。这些版本适合当前 SwiftUI API，并为候选 CKSyncEngine 留出兼容范围；CloudKit 尚未启用。最终发行设备范围可以调整。工程只使用本机 ad hoc 签名 `-`，未设置开发者 team、证书、账号、entitlements 或云容器；Simulator 不需要开发者账号。真机安装和发行需要另行配置与验证。

打开应用后，点击「打开示例 PDF」即可试读自制两页样例，Mac 也可点击「打开示例 EPUB／DOCX」；「导入书籍 / 文本」使用系统文件选择器。移动端目前只开放 PDF。未解锁的加密 PDF 会明确拒绝；当前文件上限为 200 MiB。PDF 没有文字层时不能选字和搜索。选中文字后打开「高亮与笔记」，可以保存引文和自己的笔记。

Mac EPUB 首片接受非加密重排内容。限额为 20 MiB 归档、1000 条目、4 MiB 单项、50 MiB 实际解压；只接受有像素限额的静态 PNG/JPEG，外部字体、SVG、动画及其他资源暂不支持。书籍脚本和未经授权的网络资源会被清洗／阻断，失败会明确报告。

## 构建与验证

EPUB 资源已经随源码保存，直接在 Xcode 运行无需 Node。需要重建资源时使用 Node 22+：

```sh
npm ci --prefix engine-build --ignore-scripts --no-audit --no-fund --registry=https://registry.npmjs.org
node --test engine-build/loader.test.mjs engine-build/rangy-security.test.mjs engine-build/comics-reader.test.mjs engine-build/docx.test.mjs
node engine-build/build.mjs
node engine-build/build-comics.mjs
node engine-build/build-docx.mjs
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/PDFnoKit
python3 scripts/check-native-source.py
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Mac CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/Mobile CODE_SIGNING_ALLOWED=NO build
```

在 Xcode 的 Test 菜单，或对所选 scheme 执行 `xcodebuild test`，运行完整真实 UI 流程。Mac全套须在独立CI／VM／没有现存PDFno的OS用户执行：相同bundle ID的XCTest会终止正在运行的应用，临时书库本身不隔离进程。测试只用自制样例，不读用户书库；详见[全项目验收／独立审计交接](docs/UNIFIED-VALIDATION-AND-AUDIT-HANDOFF.md)。Mac XCTest runner 需要本机 ad hoc 签名；使用 `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`。Simulator destination 选择本机已安装的设备，不复制其他机器的 UUID。实际设备、工具链、命令和未测范围记录在 [验证报告](docs/VALIDATION.md)。GitHub Actions 检查公开源文件、Swift 测试、Mac 构建/界面流程与轻量移动编译。当前顺序已调整为先把 Mac 做好，再据共享内容完善 iPhone/iPad；移动端功能完备不是这阶段门槛。

工程与样例可通过 `python3 scripts/generate-apple-project.py` 确定性再生。它不下载依赖或配置账号；修改生成的 pbxproj/scheme 时须同步更新该脚本。

## 数据与迁移

Mac 数据目录为用户 Application Support 下的 `PDFnoNative`；移动端使用自己的 app 容器。`library-v1.json` 保存书目、进度和笔记，`Originals/<sha256>.pdf` 保存导入副本。EPUB 使用独立 `epub-v1.json` 与 `Originals/<sha256>.epub`；漫画CBZ使用 `comics-v1.json` 与 `Originals/<sha256>.cbz`，CBT另用 `comics-cbt-v1.json` 与 `Originals/<sha256>.cbt`（不迁移CBZ数据），有限CB7/CBR使用各自comics-cb7/cbr-v1.json与原扩展名；学习数据另存 `learning-v1.json`，AI 结果／来源与用户正文分字段，不保存密钥，不改 PDF/EPUB schema；Word另存 `docx-mammoth-v1.json` 与原始hash.docx，旧候选 `docx-v1.json` 不自动迁移；学习文件接受 `selection-1`、`deepseek-selection-1`、`deepseek-pdf-page-1` prompt 及严格page anchor。回滚到不接受新 prompt／page anchor 的 AI 版本会保护性拒绝该学习文件，降级前备份或恢复原有学习副本，不能承诺旧版本读取新结果；每次有效更新先备份上一版 manifest，再原子替换。单窗口 repository actor 管理本地写入，尚未承诺跨进程写入、SQLite 事务、云冲突或崩溃后自动修复。手工恢复前退出应用并复制 manifest、backup 和 Originals；校验备份后再恢复。旧 Electron notes/localStorage 不会被读取或重写；需要单独的 legacy-demo 只读导入器，旧文本 fingerprint 不能转成虚构 PDF 坐标。

用户已授权旧 Electron/React/Node/CLI 骨架退役。移出文件、未跟踪元数据和运行缓存有仓库外备份，完整 Git 历史保留；[迁移与恢复记录](docs/NATIVE-MIGRATION.md) 给出保留/移出理由及回滚方式。历史审计文档保留并标明时态。原 `PDFnoBridge.xcodeproj` 只是 CLI 辅助工程，不是当前原生阅读器主应用。

EPUB的Rangy依赖已最小升级至官方1.3.2，修复旧bundle包含的原型污染问题；当前npm audit零已知漏洞，实际源码／回归证据见[安全修复记录](docs/RANGY-SECURITY-2026-10-03.md)。这不表示用户数据已受损，也不自动更新正在运行的旧应用。

## 许可证与来源

[LICENSE](LICENSE)、[SOURCE-NOTICES](SOURCE-NOTICES.md)、[THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md) 记录 AGPL、原创样例和系统框架边界。没有复制 UPDF 私有代码/图片/字体，Kookit 固定源码、实际 npm lock、许可证及对应构建源保存在 `engine-build/`；未引入 Koodo 主应用、闭源 extra、私有 Bookno 代码、OpenCC 字典或未知 minified/WASM 资源。UPDF 仅提供已脱敏的信息组织参考，PDFno 使用自己的名称与系统视觉元素。旧 npm 依赖清单作为 [历史记录](docs/historical/dependency-inventory.json) 留存，不是当前运行依赖。
