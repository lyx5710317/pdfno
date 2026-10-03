# PDFno AI 开发技术规格

版本：**0.3 原生 Apple 架构＋Mac EPUB 实施稿**
修订与官方来源核验日期：**2026-10-03**（各历史证据保留原日期）
项目标识：`pdfno`；产品显示名：`PDFno`
目标：原生 macOS、iPhone、iPad；Mac 优先交付，先完善 Mac 再适配 iPhone/iPad；长期三端目标保留
用途：产品需求、技术边界、分阶段实现和验收的共同依据
公开源码版：已移除私人路径、Library 标识及私有项目 URL；实施状态见 `NATIVE-TASKS.md` / `VALIDATION.md`。

## 0 阅读与执行规则

**CONFIRMED 用户决定**：主应用全面改为 Swift 原生界面，PDF 阅读使用 Apple PDFKit；其他格式优先通过独立 Kookit adapter 接入，首片为 Mac EPUB。长期支持 Mac、iPhone、iPad。先完成详细技术文档，再修改代码。PDFno 自有源码保持 AGPL-3.0-or-later；关于闭源可行性的提问没有撤回开源决定。

本文完整修订原 v0.2，不以附录继续保留相互冲突的主架构。Electron 主应用、Koodo 低侵入 fork、原生仅作 CLI bridge、iOS 范围未定均不再是未来实施方案。多格式、BYOK、AI 问答、页与章节双语翻译、日语假名、英日语法、高亮笔记、Bookno API、iCloud、PDF/Word/EPUB 转换与 UPDF 交互参考继续保留；这些需求不代表当前已经实现。

### 0.1 状态定义

- **CONFIRMED 用户要求**：用户已决定的产品方向或约束。
- **VERIFIED-SNAPSHOT**：注明日期、路径或提交的只读代码/官方来源事实；不能扩大为运行成功。
- **OBSERVED**：UPDF 脱敏桌面观察，按所述动作与限制成立。
- **PROPOSED**：本文的模型、接口、目录、默认数值、阶段、选型建议和验收目标。
- **DECISION**：尚需决定的系统版本、引擎、存储、同步内容、API 传输或发行配置。
- **NOT-IMPLEMENTED / NOT-RUN**：未来代码不存在，或本轮未执行对应测试。

除用户决定与明确证据外，所有设计均为 PROPOSED。区分“要求已确认、设计已批准、代码已实现、测试已通过、已发布”。有效 JSON、编译成功或 UI mock 都不能证明真实阅读、语言质量或云同步通过。

### 0.2 执行优先级与本轮边界

用户最新指示 → 实际 checkout 的有效工程约束 → 本文确认需求 → 已批准 ADR/当前任务 → 本文建议。后续实现应读取本文件及有效 ADR；冲突时遵从最新用户决定并记录原因。

2026-10-02 的 N0 文档切片已完成，随后用户明确授权创建真正原生 app、最小 PDFKit 闭环、可恢复旧骨架清理与普通 GitHub commit/push。当前执行范围以 `NATIVE-TASKS.md` 和 `NATIVE-MIGRATION.md` 为准；旧文档切片的“不改代码/不提交”不再约束已授权实施。仍不配置开发者账号、证书、entitlements 或云容器，不迁移真实用户数据、不调用付费模型、不配置额外引擎/私有 extra、不发布 release、不关机、不杀其他任务进程。

2026-10-02 用户随后明确确认“Swift＋PDFKit 保留，其他格式优先接 Kookit，并继续 AGPL 开源”，并要求继续开发；2026-10-03 再次要求继续现有 PDFno。当前增加 Mac EPUB 最小片，移动端仍编译保留、后续适配；普通提交/推送按已有授权处理。运行证据与未覆盖范围以 VALIDATION 为准。

### 0.3 原稿来源、版本与文档权威

已通过 Library 官方材料获取流程取得并完整读取原稿 1–1050 行：原文件名 `PDFno_AI_Development_Spec_v0.1.md`，读取时 Library version **1**、内部内容 **v0.2**、字节数 **94,484**，SHA-256 `5c33d02a0b5a973a68d12462e2f8af18a5e284336d7728206b22f48e63a84cbb`。文件名与内部版本是不同概念。

主规格：`docs/PDFno_AI_Development_Spec_v0.3_Native.md`。私人 Library 原项已以 replace 保留身份和版本历史；这里是用于公开仓库的去标识副本。第 22 章保留完整需求覆盖，第 23 章记录 N0 文档阶段验证；后续原生代码状态和真实运行结果以当前实施/验证记录为准。

`docs/ADR-0002-NATIVE-APPLE.md`、`NATIVE-APPLE-PLAN.md`、`EPUB-ENGINE-AUDIT.md` 等是当前 checkout 既有文档，保留其快照。本规格整合完整需求并修订原规格；旧“补充 v0.2”说明及旧路线历史不能推翻 v0.3 的原生决定。参考文件不等于全部已经实现。

## 1 产品要求与追踪表

| ID | 状态 | 要求与修订 | 对应章节 / 验收 |
| --- | --- | --- | --- |
| R01 | CONFIRMED | `pdfno` / `PDFno`，Mac 优先，长期 Mac＋iPhone＋iPad | 4、14、16；T18、T20 |
| R02 | CONFIRMED，架构已修正 | 保留 PDF、EPUB、漫画和原有多格式目标；Kookit public core 已选为其他格式优先路线；首片仅 Mac EPUB，PDF 固定 PDFKit | 5；T01、T02、T03 |
| R03 | CONFIRMED | 自有源码 AGPL-3.0-or-later，免费/收费未定；第三方许可独立核验 | 2、5、16 |
| R04 | CONFIRMED | 用户配置 endpoint / key / model 的 BYOK | 9；T09、T10 |
| R05 | CONFIRMED | 整页翻译与章节双语翻译；PDF 物理页、EPUB 页快照和章节不同 | 8、14；T07、UAT08 |
| R06 | CONFIRMED | 日语假名、日语和英语语法，保留作者 ruby、支持原文回跳 | 7、10；T04–T06 |
| R07 | CONFIRMED | 选字高亮、笔记、学习记录、可靠保存与恢复 | 6、7、15；T11、UAT02 |
| R08 | CONFIRMED | Bookno 独立 API 同步书籍、封面、高亮、笔记；契约与实现尚不存在保证 | 11；T12–T14 |
| R09 | CONFIRMED | PDFno 三端 iCloud；内容和后端待决策，离线可用 | 12；T15、T16、T21 |
| R10 | CONFIRMED | PDF / Word / EPUB 等转换，方向和质量逐项验收 | 13；T17 |
| R11 | CONFIRMED | 参考 UPDF 信息结构和交互，自有品牌，兼顾 Bookno 家族 | 14；UAT01–UAT15 |
| R12 | DECISION | 最终 MVP、定价、收费和发布日期 | 3、19；阶段建议不是承诺 |
| R13 | CONFIRMED，已解除旧未定 | 长期三端支持已定；不再询问是否支持 iOS。具体最低版本、同步数据与设备实测待定 | 4、12、16 |
| R14 | DECISION | 首个转换方向、OCR 首版范围、Bookno 单向/双向及传输 | 11、13、19 |
| R15 | CONFIRMED | Swift 原生主界面＋PDFKit，真正 application targets，共享 Swift packages | 4、5；T20 |
| R16 | CONFIRMED | AI 问答；文档、选区与通用会话范围清晰，引用可校验 | 8、9、14.7；UAT04、UAT12 |
| R17 | PROPOSED | 三端手势、键盘、无障碍；iPad Apple Pencil 分阶段设计 | 14.11；T19、T22 |

“保留目标”意味着继续纳入路线库存。旧 demo 没有真实多格式能力可直接迁移，不以本表宣称已有阅读格式；接入哪项且通过哪端验证，就只开放那项实际能力。

## 2 已有代码基线与可复用范围

### 2.1 PDFno 实际 checkout

**VERIFIED-SNAPSHOT，2026-10-02**：本轮开始 `HEAD = 2c40a8fbac87df39ed39c089b3be28a61bd1662c`，包含上一轮原生规划文档；已知旧骨架提交 `cbd17f38314b626a72059ae1168a2eedef3e1998` 在当前历史中。用户提供 CI `36900456721` 成功事实属该旧骨架；本轮未重新读取该运行，不把它当新应用或当前构建证据。

N0 文档切片开始只有未跟踪 `native/PDFnoBridge.xcodeproj/project.xcworkspace/`。当时 `src/` React demo、`electron/`、`shared/`、`tests/`、`native/` 全部保留。`native/PDFnoBridge.xcodeproj/project.pbxproj` 的 target productType 是 `com.apple.product-type.tool`、SDK 是 macOS，现有最低版本 13.0；**PDFnoBridge 只是命令行辅助工程，不是原生阅读器主应用**。该历史基线没有真正 `.app` targets 或真实阅读整合。后续原生切片已新增 `apple/PDFno.xcworkspace`、两个 app targets、共享 Swift package 和最小 PDFKit 本地闭环；完整验证范围见当前记录。旧目录按明确授权在外部备份后退役，Git 历史保留。

demo 的 Unicode/ruby、不可变来源、任务隔离、原子笔记与 revision、受限 IPC 和 CLI capabilities 可作为行为 fixture；不能直接重命名为真实阅读模块。`extractionVersion: demo-text-1` 的 `sourceFileSha256` 来自 demo 内容 fingerprint，不是原书字节 SHA-256。必须以 legacy-demo 标记迁移，不能虚构 PDF 坐标或 EPUB CFI。

### 2.2 Koodo 历史参考 / Kookit 当前 EPUB 路线

原规格基线是 Koodo `dev` 提交 `90e659f0188795f9a4f6e1ccc1727fd3793fe4a4`、包 2.4.5。其 Electron/React/Redux、数据库/IPC、部分 Go 服务、BYOK 与流式路径、PDF 几何与 EPUB Rangy 字符范围是旧静态参考；不照搬官方账号、Pro、云服务、签名身份与授权素材。名为 `cfi` 的字段不自动是标准 EPUB CFI。旧 ruby/清洗疑似问题仍只作样本设计线索，不称已复现。

**2026-10-02 官方源码修正**：Kookit public core 的固定提交 `95f602ed62d204af0de9278cf53212c309b34bfc`，package 1.0.4 声明 AGPL-3.0-or-later，有公开渲染源码。旧 Koodo 架构说明具体标记 `kookit-extra.min.mjs` 为闭源；不能把 public core 一并描述成“全部无源码”，也不能据 core 许可认可 extra 或其他 minified 产物。见 [Kookit package](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/package.json)、[core LICENSE](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/LICENSE)、[Koodo 架构说明](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/CLAUDE.md)。

用户随后明确确认 Swift＋PDFKit 保留、其他格式优先 Kookit、继续 AGPL。2026-10-03 已接入固定 core 的独立 Mac EPUB adapter；见 ADR-0003-KOOKIT-EPUB、固定 source manifest、实际 lock/许可证和 VALIDATION。Koodo 主应用、闭源 extra、未知 minified/WASM、OpenCC 数据和 upstream PDF 引擎不进入该 bundle。其余格式没有因这一决定自动实现。

### 2.3 JapaneseLearningApp / NihongoFlow / Bookno 历史参考

保留原规格的证据基线，**本轮未重新检出或运行这些工程**：JapaneseLearningApp `ec47f33c6782dcddf1313464477dd6e8d7610232` 的 `_locate`、结构化 schema、fugashi/unidic-lite 思路；其 OCR 仅文本，不能证明气泡坐标。NihongoFlow `9a835ca8dedc3af3e872e4b88b13398576cc49bc` 的 span 校验、版本缓存、并发去重和简单复习调度；不能把其调度称 FSRS，不能证明英语语法。Python/TypeScript/Web 服务是行为参考，不成为 iPhone 必带运行时。

Bookno 原规格基线 `zcode/develop` / `9ae3056bff8dd64fac43185d2bfa5f22b20dc689` 记载原生 Mac/iOS、共享 SwiftData、私有 CloudKit、`Book` / `BookSource` / `ReadingNote`、UUID、external IDs、importedContentHash、coverData 与版本化 importer。这是继承的旧快照，不是今天重新验证的 API 或设备同步事实。`syncIdentity` 恢复时可重置，不作跨应用永久主键。本文不复用、配置或公布其私有容器值；PDFno 使用独立 API 与自身身份。

复制任何参考源码前核验权属、许可证、依赖、字典、字体与再分发许可。可读取私人源码并不证明可以公开发布。优先重新实现纯领域规则并使用合法 golden fixtures；Bookno 设计 token 待通过获准资料取得，不猜色值。

## 3 范围分层与实施门禁

### 3.1 建议阶段

| 阶段 | 交付范围 | 退出条件 |
| --- | --- | --- |
| N0 文档与证据 | 本 v0.3、官方来源、完整原稿覆盖、checkout 快照 | 无旧主架构冲突；建议/未实现分开 |
| N1 真正原生工程 | Mac 与 iOS/iPadOS app targets，共享包，原生书库/空态 | 两个 `.app` 构建，iPhone/iPad Simulator smoke；无账号配置暗改 |
| N2 本地 PDF 闭环 | 系统导入、PDFKit、目录/搜索/选区、稳定高亮/笔记/回跳 | 三端宿主与 Unicode/PDF fixtures、重启恢复/错误通过 |
| N3 EPUB 分端接入 | 已选 Kookit core、官方源码/实际依赖、ADR 0003、独立 adapter | 首片 Mac 重排/ruby/安全/选区/恢复实测；移动先编译，随后单独验收 |
| N4 AI 学习闭环 | Keychain/BYOK、问答引用、页/章双语、假名/英日语法 | mock 状态与真实获准质量测试分别验收 |
| N5 迁移恢复 | 旧 demo 只读导入器、独立新 store、备份/回滚 | 幂等、损坏、未来 schema、冲突、中断恢复通过 |
| N6 iCloud 三端 | 决定记录/原书方案后接入自有容器 | mock 后两设备再三端实机，离线/冲突/退出/配额通过 |
| N7 Bookno / 多格式 / 转换 | 独立 API、封面、高亮笔记；逐格式与逐方向 adapter | 各自契约、许可、合法样本、失败和质量验收 |
| N8 发布准备 | 渠道、签名、升级、源码/声明、隐私与设备报告 | 发行配置明确且实际验证；用户批准发布 |

最新用户顺序：先把 Mac 版做好，再按 Mac 的内容与交互完善 iPhone/iPad。阶段不是删除需求，N6/N7 可按依赖调整；两个 targets 和跨端身份/模型仍从 N1 保留，但移动端 UI 专项验收与完善转到 Mac 里程碑之后。CI 可以先保留轻量移动编译，不以三端功能完备阻止当前 Mac 交付。Mac 优先不把移动端降为网页或无限期取消，也不在后续重新定义来源/存储模型。

### 3.2 保留的后续能力与首期边界

保留扫描 PDF 精确 OCR 锚点、漫画气泡/区域识别与翻译、全文可开关假名、批量全书翻译与派生输出、复杂可编辑 Word 重建、复习扩展、其他格式、双向 Bookno 以及 Apple Pencil 手写。每项独立范围与验收，不因 UPDF 菜单可见就承诺首版具备。原生三端方向已确定，不再把原生 iOS 当未知产品方向。

官方账号/付费体系、论文图谱/深度研究、云模型托管服务只保留扩展点；不通过改名或复用其他产品身份实现。旧 6–12 人周等估算的“无需重做多端”前提已失效；原生三端改造需在 N1–N3 后重新估算，不承诺 AI 编码速度。

## 4 原生工程、模块与权限边界

### 4.1 Xcode 工程与共享 Swift packages

以下描述模块职责。N1 实际采用一个本地 `PDFnoKit` package、四个独立 targets，并创建 Mac/Mobile app 与 UI test targets。其余 Platform、AI、同步、格式 adapters 仍未实现：

```text
apple/
  PDFno.xcworkspace
  PDFno.xcodeproj
  Apps/Mac/                  # PDFnoMac.app，macOS application
  Apps/Mobile/               # PDFnoMobile.app，iOS application，iPhone + iPad
  Packages/PDFnoKit/
    Sources/PDFnoDomain/     # 纯值身份、来源、任务与 Unicode 契约
    Sources/PDFnoServices/   # actor 本地 repository
    Sources/PDFnoReaders/    # PDFKit 与 EPUB 占位接口
    Sources/PDFnoUI/         # SwiftUI 书库、导入、笔记
    Tests/PDFnoKitTests/     # 原生契约/存储/PDFKit tests 与原创 fixture
  Tests/NativeUITests.swift  # 两个 UI test targets 使用同一闭环
```

两个真实 `com.apple.product-type.application` targets：macOS 原生 `PDFnoMac`，iOS `PDFnoMobile` 设置 iPhone/iPad device families；后者运行于 iOS/iPadOS。各自 scheme、单元/集成/UI test targets 和运行入口。不是 CLI 改名，不默认 Mac Catalyst 替代 AppKit，也不把整个 React 页面套进 WebView。模块可按依赖图在包内拆 targets；最终包名/粒度在 N1 固定，领域层不能导入 AppKit/UIKit/PDFView/WKWebView。

依赖方向：Apps → Platform/Readers/Services → Domain；Domain 只含 Foundation/纯值类型。Reader 返回 DTO；Storage actor 与 provider actor 不依赖具体视图。PDFKit UI / PDFDocument / WKWebView 访问按隔离约束安排在主 actor 或专用受控执行上下文，不假装框架对象都可 Sendable；后台只接收不可变文本/几何/文件句柄抽象。大文件 hash、解析、I/O、OCR 和转换可取消，不阻塞 UI。

### 4.2 SwiftUI / AppKit / UIKit 边界

SwiftUI 实现书库、设置、导航、学习、任务与状态；Mac 用 AppKit 提供 PDFView 宿主、菜单、焦点、窗口/文档协同与拖入；iPhone/iPad 用 UIKit 提供 PDFView、系统选区菜单、手势与需要的 Pencil 宿主。通过 [NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable) / [UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable)及 coordinator 封装生命周期。官方来源只证明宿主能力，封装可靠性待实现测试。

EPUB 如选择 JavaScript 排版引擎，仅阅读内容模块使用 WKWebView；原生书库/设置/学习服务保持 Swift。Web 引擎是格式 adapter 内部实现，不把它定为应用 UI 架构。

当前可调整开发基线：macOS 14 / iOS 17 / iPadOS 17、Swift 6、Xcode 16.4+；符合所用 SwiftUI API 并兼容候选 CKSyncEngine 的 introducedAt。用户已授权选定临时工程基线，不代表最终发行设备范围。更低系统需评估 API 降级成本；当前 CLI 的 macOS 13 或 Readium 的 iOS 15 不决定新 app 范围。Intel 发行为独立验收，账号与云配置仍未设置。

### 4.3 模块职责与原生安全

| 模块 | 输入输出 | 不承担 |
| --- | --- | --- |
| ReaderAdapter / TextExtraction | 受管理 asset、能力、目录/搜索、原文快照、选区、定位/批注投影 | 模型调用、密钥、任意文件读取 |
| AnchorService | 版本化来源、Unicode 映射、定位校验、需重绑报告 | 猜重复短语、改写原文 |
| Storage / NoteService | ID、修订、用户笔记/AI 附注、备份/迁移、outbox | 同步运行中数据库、吞掉写入失败 |
| Provider / Learning / Translation | 明确范围、流式事件、结构校验、队列/缓存/预算/取消 | 扫全库、信任模型 offset、自动扩范围 |
| BooknoExchange | 脱离传输的 DTO、预览、API 适配、资产去重、回执 | 写 Bookno 内部 store/CloudKit |
| SyncCoordinator | 记录/资产状态、账号隔离、冲突/墓碑/对账 | 同步 key、设备 bookmark、墙钟覆盖 |
| Conversion / OCR | 逐方向 plan/result/quality、合法解析引擎 | 承诺 PDFKit 万能转换 |

文件导入统一经过系统选择/拖入权限和格式预检；建议复制到 PDFno 沙盒受管理资产目录，原文件只读。security-scoped access 用后释放，bookmark 仅本机授权，不同步成云端路径。外部引用模式若以后支持，单独处理权限失效、源文件变化与重选。文件类型同时验证字节与 MIME/结构，限制文件数/解压量/像素，拒绝穿越和符号链接逃逸。参见 [fileImporter](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:))。

EPUB 归档、HTML、OCR 和 AI 输出是不可信数据。WKWebView 引擎桥只接受白名单消息、schema/大小/当前 book-session-generation 校验，不能暴露任意 path、exec、SQL、设置或 key。资源清单授权、CSP/清洗、禁止书籍脚本和默认远程资源、允许协议外链确认均须验证；通用消息桥和同源 blob 并不证明安全。日志/诊断不含 key、全文、模型响应，注入指令只是书中数据。旧 Electron IPC 隔离作为历史回归保持，不是新原生安全实现。

## 5 PDFKit、EPUB 与多格式能力

### 5.1 PDFKit reader

**CONFIRMED 框架；已实现本地最小 PDFKit 闭环，完整能力仍分阶段**。官方 [PDFView](https://developer.apple.com/documentation/pdfkit/pdfview)、[PDFSelection](https://developer.apple.com/documentation/pdfkit/pdfselection)、[PDFPage](https://developer.apple.com/documentation/pdfkit/pdfpage) 可用于原生 macOS、iOS、iPadOS。PDFKit 承担显示、缩略图、目录、文本选择/搜索和原生批注基础；PDFno 实现永久来源、任务、笔记与批注投影。其存在不证明多栏阅读顺序、OCR、语言分析、iCloud 或 Word 转换已经完成。

PDF adapter 负责文档 session、解锁/受限状态、页索引/页码标签、MediaBox/CropBox/rotation、选择字符串与逐行/逐页几何、跨页 snapshot 和回跳。App 级笔记存 store，PDFAnnotation 为可重建投影；显式导出带批注副本时才写新 PDF。导入既有 PDF 批注需保存类型、作者、颜色、内容、页/几何与稳定本地映射，未知类型可读保留，不重复导入、不静默删除。扫描/混合页可显示；无可靠文字则显示“需 OCR”。文字 permission 不足就禁用对应提取/导出，不绕过限制。

### 5.2 独立 Reader / EPUB adapter 契约

**PROPOSED**：通用 reader 提供 `open(asset,edition,session)`、`capabilities`、`outline`、增量 `search`、`captureSelection`、`captureScope(page/viewport/chapter/range)`、`navigate(anchor)`、`projectAnnotations`、`close/cancel`。返回强类型值：BookSessionID、GenerationID、SourceSnapshot、ReaderLocator、NavigationResult、CapabilityReason；事件可用 AsyncStream。UI 宿主由平台创建；无 SwiftUI View / DOM / PDFSelection 私有对象进入持久化 DTO。

EPUBEngineAdapter 独立负责 publication manifest、规范资源路径/spine、作者 ruby、原文到引擎 offset、重排/固定版式、搜索/定位和引擎版本。公共 SourceAnchor 与 Bookno/iCloud 不直接保存可执行 JS、任意序列化对象或引擎专用类。更换引擎只换 adapter；定位不能互通时保存旧引文并需重绑，不能强行转换私有 locator。

| 官方候选固定基线 | 许可证 | 官方源码/平台证据 | PDFno 结论与缺口 |
| --- | --- | --- | --- |
| Readium Swift Toolkit 3.11.0，`d82f44f4f05d87add9e22a8b75abbd61dce745dd` | BSD-3-Clause 根许可 | Package.swift 是 Swift tools 5.10、仅声明 iOS 15、Shared 链接 UIKit | iPhone/iPad 候选；**不能当原生 AppKit macOS 可用**。Mac 另一个 adapter 或专项移植，Catalyst 不替代已定 Mac 目标 |
| foliate-js，`78914aef4466eb960965702401634c2cb348e9b1` | MIT；README 列 zip.js BSD-3、fflate MIT、PDF.js Apache | 浏览器 JS，目标 WebKitGTK/Firefox/Chromium；API 不稳定、该基线无 release | 三端 WKWebView 路线候选；Apple WebKit 兼容、安全、无障碍与维护需实测；不携带其 PDF.js 替换 PDFKit |
| FuturePress epub.js，`eee359d0790002115a1156a9833c54f4bcd44c1d`，package 0.3.93 | BSD-2-Clause 根许可 | 浏览器库，分页/滚动；默认关闭 scripted content | WKWebView 对照候选；浏览器示例不是三端验收，JSZip 等实际依赖需审计 |
| Kookit public core，`95f602ed62d204af0de9278cf53212c309b34bfc`，1.0.4 | AGPL-3.0-or-later；内嵌/实际依赖各自声明 | Mac WKWebView 重排 EPUB adapter；实际证据见 VALIDATION；移动尚未运行 | 已选优先路线；首片 EPUB-only，PDF/extra/其他格式未进入 bundle |

2026-10-02 的候选比较只做静态审计；2026-10-03 Kookit 专用 EPUB profile 已构建并接入 Mac，其他候选仍未安装。Readium [固定 Package](https://github.com/readium/swift-toolkit/blob/d82f44f4f05d87add9e22a8b75abbd61dce745dd/Package.swift) / [LICENSE](https://github.com/readium/swift-toolkit/blob/d82f44f4f05d87add9e22a8b75abbd61dce745dd/LICENSE) / [发布](https://github.com/readium/swift-toolkit/releases/tag/3.11.0)；foliate [README](https://github.com/johnfactotum/foliate-js/blob/78914aef4466eb960965702401634c2cb348e9b1/README.md) / [LICENSE](https://github.com/johnfactotum/foliate-js/blob/78914aef4466eb960965702401634c2cb348e9b1/LICENSE)；epub.js [package](https://github.com/futurepress/epub.js/blob/eee359d0790002115a1156a9833c54f4bcd44c1d/package.json) / [README](https://github.com/futurepress/epub.js/blob/eee359d0790002115a1156a9833c54f4bcd44c1d/README.md) / [license](https://github.com/futurepress/epub.js/blob/eee359d0790002115a1156a9833c54f4bcd44c1d/license)。

比较两条方案：A，同一 JS EPUB 引擎分别由三端 WKWebView 宿主；B，Readium 移动端＋Mac 独立 EPUB adapter。A 可减少排版差异但安全/适配维护自担；B 有移动端工具链优势但双引擎/locator/许可维护更重。建议先用 A 的有限样本试验，再与 Readium 移动端对照；这段保留选型比较的理由；用户后续已明确选择 Kookit core 的 A 路线，不因比较而自动更换引擎。

foliate 官方 README 提到 WebKit iframe sandbox 与 blob 同源的安全限制，epub.js 开启脚本削弱隔离；不能只宣称 sandbox=true 即通过。必须分别隔离受信引擎与书籍内容，可靠禁止书籍 JS/事件/远程 CSS/font/图片/危险 URL、验证消息与归档上限；做不到则淘汰候选。Readium LCP 的额外私有 framework 不进入当前非 DRM 试验；根许可不是传递依赖或发行许可完成。

N3 完整能力验收库存（首片未覆盖项继续保留）：合法 EPUB 2/3 重排/固定样本；日语横竖排/ruby、跨段选择/重复句/emoji；字号/旋转/窄窗/iPad 分屏/重启位置；目录/搜索；鼠标/触摸/键盘/VoiceOver；恶意脚本/归档资源；大书/切书/WebContent 退出；依赖/字体/notice 可复现。每组在 Mac、iPhone、iPad 都记录 OS、硬件、结果、失败与许可清单，尚未运行的格式/平台/功能保持 NOT-RUN；不以移动完整验收阻止已通过的 Mac 切片交付。

### 5.2.1 当前 Mac EPUB 实现边界

当前源包为 `engine-build/`：23 个原始 Kookit 文件保留 blob 哈希；JSZip 3.10.1、Rangy 1.3.0、Underscore 1.13.8 和 esbuild 0.25.11 的实际 lock 与声明已保存。Node 只用于构建；派生 engine.js 与完整 Notices.txt 进入原生 reader 资源。独立 EPUB 入口替换不受限 fallback loader，强制禁书籍脚本，排除 PDF 引擎/Chinese mapping/extra/其他格式；不引入 Electron。

Mac SwiftUI 原生书库、目录、翻页、横竖排和笔记宿主通过受限 WKWebView 承载正文。脚本禁用 frame 的选区由可信父页读取；CSP、资源清洗、逐协议规则、非持久 WebKit store 和原生桥白名单保持有效。桥校验 session/book/edition/hash/documentVersion/requestID，串行导航、超时和取消使旧 generation 失效。首片归档限 20 MiB/1000 条目/单项 4 MiB/实际总解压 50 MiB；静态 PNG/JPEG 有单图 4M/总 16M 像素预算。字体、SVG、动画、固定版式、加密、全面资源保真和移动阅读仍未验收。

`epub-v1.json` 与原有 PDF manifest 分开；`Originals/<sha256>.epub` 保持原始字节。笔记与进度使用 edition/hash/resource/spine、canonical UTF-16 半开 span、exact quote/context/extractionVersion；正文 walker 排除 rt/rp，作者 ruby 保留展示。回跳先验证引文，不模糊选择重复短语；高亮投影不改源文本，关闭/重开从持久化 anchor 恢复。未来增加提取、CFI、搜索、字体/字号和三端能力时继续使用公共来源契约；当前页只作视图状态，不当永久位置。

许可、源码修正、回滚和具体测试范围见 ADR 0003、KOOKIT-EPUB-STATIC-AUDIT-2026-10-03、VALIDATION。CFI 上游声明 AGPL-3.0 不自动改为 or-later；foliate/MIT、npm MIT/ISC/zlib 等分别保留。OpenCC 数据本片排除；将来启用转换须另核其来源、Apache 声明和 NOTICE。漫画/DOCX/其他格式与转换保留目标，但没有通过 EPUB 切片自动开放。

### 5.3 漫画与其他格式的保留清单

| 格式目标 | 拟议实现 | 学习/稳定位置 | 阶段与实际缺口 |
| --- | --- | --- | --- |
| PDF 文本/扫描/混合 | PDFKit | 页＋原文＋PDF 几何；OCR 另版本 | N2；当前无真实 reader |
| EPUB 2/3 重排/固定 | 独立 Kookit EPUB adapter | 资源/spine/canonical UTF-16 半开 span＋引文/context/hash；逻辑页非主键 | N3；Mac 原创重排样本已接入，固定版式和移动阅读待验收 |
| CBZ / 图片序列 | 原生图像显示＋经许可 ZIP parser | 图片 hash＋顺序＋归一化区域；无文字默认不开放语法 | N7 可优先试 CBZ；解析器/内存/RTL/双页待测 |
| CBR / CBT / CB7 | RAR/TAR/7z 各自受控解包 adapter | 同图片定位；气泡检测/OCR 后续 | N7；各库许可证与 iOS 构建能力未定，不能自动执行 Mac CLI |
| MOBI / AZW3 / AZW | 经审计非 DRM parser，或明确转换后阅读 | 资源/块＋引文，转换生成新 edition | N7；AZW 变体与 DRM 限制明确，不承诺全部可开 |
| TXT / MD / FB2 | 原生文本/受控渲染＋解析 adapter | 文档 hash、编码/提取版本、块/span | N7；编码、ruby/样式/脚注待验证 |
| DOCX | 独立 OOXML parse/preview 或转换为新 PDF/EPUB | 源与派生版本分开，不能用预览替代稳定提取 | N7；不承诺 Word 全对象保真 |
| HTML / XML / XHTML / MHTML / HTM | 受控离线资源与净化 adapter | 资源/结构/提取版本/引文 | N7；远程资源、主动内容、未知 schema 不直接开 |

保留旧格式库存，不把所有类别写成“已有阅读”。各 adapter 运行时返回显示/选择/搜索/批注/OCR/学习/转换能力与理由。学习不可用时已实现 reader 仍能阅读；格式本身未实现则明确说明并保留导入记录，不能伪造打开成功。DRM、加密、损坏、权限受限和无文本有各自可操作状态。PDFKit 不支持 EPUB、漫画或任意格式转换。

## 6 领域模型与本地数据

### 6.1 共享 Swift 值模型草案

以下为 **PROPOSED** 领域契约，未编译，引用的辅助类型需在 N1/N2 补齐。Swift `Codable` 不替代 schema/范围/UUID/hash 验证；JSON/Bookno DTO 与 UI 框架对象分离。

```swift
struct BookRecord: Codable, Sendable, Identifiable {
    let id: UUID
    var title: String
    var authors: [String]
    var language: String?
    var identifiers: [BookIdentifier]   // scheme + value，ISBN 非主键
    var editionIDs: [UUID]
    var cover: AssetRef?
    var createdAt: Date
    var updatedAt: Date
    var revision: RevisionEnvelope
    var deletedAt: Date?
}
struct EditionRecord: Codable, Sendable, Identifiable {
    let id: UUID
    let bookID: UUID
    let sourceFileSHA256: String        // 真实原书字节 hash
    let sourceFormat: String
    let sourceBytes: Int64
    let originalAssetID: UUID
    var textFingerprint: String?       // 不替代文件 hash
    var extractionVersion: String
    var importedAt: Date
    var derivedFromEditionID: UUID?    // 转换/新版本关系
}
struct AssetRef: Codable, Sendable {
    let assetID: UUID
    let sha256: String
    let mimeType: String
    let byteLength: Int64
    let width: Int?
    let height: Int?
    let role: AssetRole                // original/cover/thumbnail/attachment
}
struct LearningNote: Codable, Sendable, Identifiable {
    let id: UUID
    let bookID: UUID
    let editionID: UUID
    var anchor: SourceAnchor
    var quote: String                  // 原文，不能混译文/读音
    var userText: String
    var aiAttachmentIDs: [UUID]
    var annotation: AnnotationRecord?  // 高亮/下划线/手写等独立类型
    var colorToken: String?
    var tags: [String]
    var revision: RevisionEnvelope
    var createdAt: Date
    var updatedAt: Date
    var deletedAt: Date?
}
struct AnalysisRef: Codable, Sendable {
    let id: UUID
    let kind: AnalysisKind             // translation/grammar/reading/qa
    let sourceTextHash: String
    let providerConfigID: UUID         // 无 key
    let model: String
    let promptVersion: String
    let schemaVersion: String
    let createdAt: Date
    let provenance: ResultProvenance   // mock/model/dictionary/user
}
```

稳定 UUID 首次创建后不因改名、封面、重装/备份恢复或账号切换改变；账号空间隔离不是改写实体 ID。同字节去重、同作品合并、同版关联是三种操作，后两者提供可审阅匹配。Edition 保存真实指纹与提取版本；文件替换创建新版本，不改老锚点的含义。

RevisionEnvelope 记录 `revisionID`、`parentRevisionIDs`、`deviceID`、`deviceSequence`、`changeID`、`schemaVersion`、语义 `contentHash`、时间与墓碑。本地整数仅在同设备/序列内递增，三端并发不按整数或墙钟比较大小。Bookno 的线性 source revision 是导出层已合并快照序列，见 11.4；不是把三个本地计数混为全局 revision。

### 6.2 批注与可靠 repository

AnnotationRecord 至少区分 highlight / underline / strikeout / note / ink / imported-opaque，保存 ID、edition、来源锚点、几何 schema、颜色/样式/作者、创建/修订、导入来源映射和 attachment 引用。文本批注保存逐行/逐页多个区域；手写笔画记录页空间和笔画版本。语法强调、导航临时强调与永久批注不同；点击引用不保存高亮。用户正文、AI 附注、原 PDF 批注与生成读音各有来源，不合成不可撤销字符串。

**PROPOSED 存储**：先比较版本化 SQLite repository 与 Core Data/SwiftData；默认建议独立 SQLite＋显式 CloudKit adapter，以便把修订/冲突/Bookno 协议掌握在领域层。后续 ADR 才固定实现和依赖。若用系统 CloudKit 镜像，需完整说明 schema/冲突/迁移控制边界，不让镜像与 CKSyncEngine 同时拥有同一组云记录。旧 JSON 是 importer 输入，不当三端数据库。

逻辑集合保留 `books/editions/assets/notes/analysis_results/translation_jobs/translation_segments/provider_configs/external_mappings/change_log/sync_state/conflicts/schema_migrations`，增加 annotations、reading_positions、outbox、migration_receipts 和账号空间。asset bytes 存沙盒受管理目录，hash 去重、引用计数/下载校验与清理；缓存可删，用户笔记不可当缓存。当前 store 不放入 iCloud Drive。

一次领域写入与 outbox 追加同事务，提交后才显示“本地已保存”；写入失败保留编辑缓冲。同进程多窗口经 actor/repository revision 检查；跨设备经修订分支合并。导入/备份采用一致性快照、版本/大小/hash 检查、临时区和原子提交，失败不损坏唯一副本。破坏性迁移前验证备份可读；未来 schema 拒绝写入。敏感索引/结果/草稿按本地保护策略存储，原文不进入诊断日志。

Keychain 存 API key，provider_configs 只存 credential reference；不进入普通 JSON、备份、Library、Git、Bookno、CloudKit 或 EPUB JS。跨设备默认各配 key；未来 iCloud Keychain 同步与 access group 另决策。

### 6.3 封面与书库资产

Bookno 包含封面与书籍稳定映射，不能只传标题。封面记录来源、MIME、字节数、像素、SHA-256；不依赖临时路径/过期 URL。候选交换 JPEG/PNG，经实际解码验证 MIME/像素/大小。**PROPOSED** 上限单封面 10 MiB、最长边 4096；超限兼容副本保留原件，最终与 Bookno/云配额协商，不称既有限制。

封面优先级建议：用户指定/明确关联的 Bookno 封面 → 文件内封面或 PDF 缩略页 → PDFno 自有占位。封面更新不改 bookID，局部换封面不被外部同步静默覆盖。缩略图可重建，cover 原件与 original asset 分角色；相同 hash 去重字节仍保留各自实体关系。

## 7 原文锚点与 Unicode 规范

### 7.1 统一锚点外壳与格式 locator

**PROPOSED** SourceAnchor schema v1 保留原规格全部语义：editionID、真实 sourceFileSHA256、extractionVersion、textNormalizationVersion、quote(exact/prefix/suffix)、offsetUnit=`unicode-code-point`、resource/block 内的 canonicalSpan `[start,end)`、强类型 locator。来源 lineage 可标记 legacy-demo、native-text 或 ocr；UI 标签独立，不拿页码显示字串作稳定键。

| locator | 必须保存 | 禁止假设 |
| --- | --- | --- |
| PDF | 一个或多个 page segment：0 起物理 pageIndex、pdf-user-space、MediaBox/CropBox、原 rotation、区域 quads/rects、原文范围/提取块；可选 textItemRefs | 一屏像素、仅 UI 页码、仅单页 selection 是永久来源 |
| EPUB | canonical resourceHref、spineIndex/资源身份、blockID、engine name/version/locatorType、经过 schema 校验 value；只有验证标准 CFI 后独立 epubCFI | 引擎字段名叫 cfi 就是标准、spineIndex 单独稳定、重排页号稳定 |
| Image / 漫画 | pageIndex、imageSHA256、归一化 region 0..1、方向/尺寸、可选 OCR version | OCR 字符串等于精确气泡坐标、屏幕位置不变 |
| Opaque / 其他 | engine/format/version、有限 schema payload、可读位置 | 任意可执行对象可跨应用保存、未经验证可跳转 |

prefix/suffix 建议各最多 64 code points；canonicalSpan 始终限定明确资源/提取块，不能用不稳定全书拼接偏移。跨页选择保存各页 segment 和总原文有序关系，所有坐标有格式版本；旧单页锚点兼容读取，扩展 schema 时显式版本迁移。

### 7.2 原始、规范与显示三层

原始文档结构 → 规范原文/提取块 → 显示层，保持双向 offset 映射。作者 ruby 基字进入主文，rt/rp 另存作者读音；新增假名/译文/工具按钮不进入规范原文。SwiftUI/NSAttributedString 或 EPUB DOM 的显示变化不修改请求快照。空白/换行/连字符/组合字符/Unicode normalization 有版本，不随意 trim/替换后沿用原 offset。

Swift `String.Index`/Character 的 grapheme cluster、Swift Unicode scalar、NSString/PDFKit 及 JavaScript DOM 的 UTF-16 code unit 不同。内部外部契约采用 code point 半开区间（Swift scalar 语义），明确 scalar↔UTF-16↔显示映射；UI 截断按 grapheme cluster。不要用 `String.count` 当 UTF-16 offset。NFC 若用于匹配须保留到原始序列映射；作者原引用不被偷偷规范化。

PDFKit selection/bounds 是输入线索，不保证阅读顺序或精确逐字映射。adapter 根据 page extraction 与多个 selected ranges 校验逐字一致；不一致时标低置信/仅区域，不把不存在文字用于 AI。OCR 原文记录识别器、版本、语言、图像 hash、页区域与置信度，能重算但不覆盖 native text 来源。

### 7.3 恢复算法

1. 核对源文件 hash、edition、提取/normalization 版本与 locator 类型；同版先走 reader 原生定位。
2. 在同资源/页/块核对 exact 和上下文，再标 exact；跨页分段分别校验。
3. 布局改变重算显示几何；提取变化只在原资源候选中结合上下文和近邻匹配。
4. 重复引文不唯一、跨 edition、弱置信或引擎不支持时返回 needs-rebind；保留旧引文和可读标签。
5. 用户重绑创建新修订并保存旧锚点/撤销记录，不静默改旧历史。

恢复状态：exact、context-matched、needs-rebind、source-missing、unsupported。不给虚构置信小数。PDF 坐标往返覆盖 PDF 原点、两种 page box、rotation、缩放、高 DPI、跨行、跨页、竖排/多栏/连字；EPUB 覆盖字体/行距/横竖排/旋转/分屏/ruby。

## 8 AI 问答、整页与章节双语翻译

### 8.1 任务范围与页的定义

- PDF：点击时物理页索引＋edition；标签罗马数字仅显示。可单页或显式页范围。
- EPUB 重排页：点击时可见原文快照、资源和起止锚点＋layout snapshot；排版后仍绑定该快照。
- 滚动视口：显示本次涵盖完整正文块，不能暗中扩整章。
- 章节：用户选择章节/spine 对应的明确范围；长章预检、分段、预算/取消/恢复，与“当前页”不同命令。
- 扫描/漫画：没有可靠正文就显示 OCR/区域识别要求，不能发送空文本伪造成功。

提供前后文时单独标记上下文与目标片段；展示实际外发范围，输出只对应目标。仅译文/双语段落对照/原文译文切换为候选输出，PDF 并排需足够宽度；不承诺保版式、表格或字体全部重建。章节/全书产生持久派生文件另按输出任务验收。

文档问答 **CONFIRMED 需求 / NOT-IMPLEMENTED**：以本地已提取片段及校验锚点建立索引；来源包含 bookID/edition/page-or-resource/span/hash。问题检索限定用户选定的文档/页/章集合，预览上下文；模型引用回查通过才可定位。无依据、OCR 低置信、索引未完成、旧版本分别反馈。通用聊天默认无文档上下文；多文件/联网 embedding/论文图谱/研究属于扩展，不自动扫描全书库或上传全文。

### 8.2 分段与确定性缓存

按段落、句子与页阅读顺序分段，保留 segmentID、anchor、语言/内容 hash；不固定字数切坏字符或文本项。provider/model 的上下文上限需能力配置，未知用保守预算。索引/分段实现不绑定 PDFView 或 EPUB 私有对象。

```text
cacheKey = SHA256(canonicalJson({
  cacheSchemaVersion, taskKind, editionFingerprint, extractionVersion,
  segmentSourceHash, sourceLanguage, targetLanguage,
  contextSnapshotHash, glossaryHash, userInstructionHash,
  providerIdentity, modelIdentifier, modelRevisionIfKnown,
  promptVersion, outputSchemaVersion, generationOptionsHash
}))
```

contextSnapshotHash 覆盖实际有序外发上下文/补句/检索片段；术语表/用户指示也入 hash。canonicalJson 固定键序、缺省/null/数字/UTF-8 规则，保留语义数组顺序与实际字符串，不直接拼接字段或遗漏上下文。key、任务 ID/时间不入 cacheKey。模型别名 revision 未知可手工刷新。

缓存是可清理结果，用户保存笔记不可被失效清理。相同语义请求由 actor/coordinator 并发去重，各订阅独立取消，最后订阅取消才尝试取消共享请求。章节恢复仅复用校验通过的成功段落；输入/模型变化创建新任务版本，不覆用户改写。缓存落盘、状态恢复与驱逐限额需要测试。

### 8.3 Swift 并发、取消与状态

`queued → extracting → awaiting-consent-if-needed → requesting → streaming → completed`，分支 partial/cancelled/failed；taskID 绑定 book/edition/snapshot/provider/config-generation。每段保存状态、error、attempt、usage 和 result provenance。UI 独立投影状态，不能靠 spinner/计时器造完成。

Swift structured concurrency＋URLSession task 取消；后台处理检查 CancellationError/Task.isCancelled，关闭 AsyncStream continuation 并移除订阅。迟到响应必须核对 taskID/generation，只能回原任务。任务关闭/切书/关窗的保留或取消策略显式显示；iOS 后台不保证网络继续，恢复后校验已提交段和未知结果，不假设能跨设备继续活动请求。

**PROPOSED 默认** 单服务并发 2、可重试网络错误最多自动重试 2 次、退避尊重 Retry-After。认证/余额/内容拒绝/schema/输入错误不循环重试。未知网络提交结果不贸然自动重发可能收费请求；若 provider 有幂等键则按实际能力使用。排队段取消后不再发送；已到服务方请求可能仍收费，如实反馈。重试失败段不重新提交成功段，部分结果可读保存。

### 8.4 成本、外发与质量

显示字符/token、服务/模型与范围；价格无可信配置就“费用未知”，usage 缺失也标未知。估算不是账单。批量页/章/全书有独立范围确认、计划、预算上限和停止入口，不复用单页命令扩大范围。首次服务说明外发目的/数据；正常操作的已授权范围无需重复确认，新增文件/范围/远程 OCR 另明确。连接测试用无文档最小短句，真实烟测受样本和预算限制。

本地模型说明实际 host；iPhone loopback 是手机自身，不是 Mac 的 Ollama。局域网/代理不称完全离线。PDF/EPUB/漫画源文件、图片和 OCR 不作为自动 fallback 上传。语言质量独立人工评分，结构合法不等于译文、读音、语法正确。

## 9 BYOK 与原生模型服务

```swift
struct ProviderConfig: Codable, Sendable, Identifiable {
    let id: UUID
    var label: String
    var endpoint: URL
    var protocolKind: ProviderProtocol // openAICompatible / ollama / custom
    var model: String
    var credentialRef: String?
    var capabilities: ProviderCapabilities // stream/schema/vision/usage
}
protocol ProviderAdapter: Sendable {
    func validate(_ config: ProviderConfig) async -> ValidationResult
    func analyze(_ request: AnalysisRequest) -> AsyncThrowingStream<ModelEvent, Error>
}
```

草案引用类型待实现，取消由订阅终止/任务取消契约固定，不能只取消视图。第一轮建议 OpenAI-compatible 文本接口；Ollama native/兼容路线后续评估。model list、SSE、JSON Schema、vision、usage、token limits 按能力验证，不以“兼容”推断全部可用。语义请求和 Keychain 解析在原生 service；书籍 WebView 从来不拿 key。

设置提供 endpoint/key/model/能力/费用配置，key 安全输入与遮蔽，错误区分配置、连接、认证、限流、额度、超时、取消、输入过长、能力、结构/服务器错误。endpoint 显示 scheme/host/port/最终 API path，防重复 `/v1`/`chat/completions`；默认 HTTPS，loopback HTTP 可设，远端明文 HTTP 必须显式选择。网络实现尊重 ATS 和平台限制，不为“兼容”加通用任意联网例外。

URLSession delegate 默认停止带认证重定向；受允许适配需检查完整 origin(scheme/host/port)，禁止 TLS 降级和跨 origin Authorization 转发。连接测试不读取当前书或 key 到日志。Keychain 服务/access group、iOS accessibility 与 Mac access policy 在实现/签名 ADR 中固定；默认非 synchronizable，不自动启用钥匙串同步。删除 key 清理配置引用但保留历史模型标签，账号切换不把旧凭据/队列迁给新账号。参见 [Apple Keychain services](https://developer.apple.com/documentation/security/keychain-services)。

模型不能调用工具读取其他文件、邮件、系统命令或改变设置；输出仅数据，HTML/Markdown 清洗并使用允许协议。高亮/语法 span 和问答引用须按第 7、10 章校验，不接受模型自报“已验证”。

## 10 假名与日英语法辅助

### 10.1 日语读音

先保留作者已有 ruby。用户可选择“隐藏辅助读音”“侧栏显示”“仅生词或选区显示”；全文注音属于后续阶段。PDF N4 读音放侧栏，不重排原 PDF。

**PROPOSED 管线**：原文分词 → 本地词典候选读音 → 上下文消歧 → 校验 → 展示。fugashi 等只作为旧研究参考；实际是否采用原生词法库、跨平台原生分词器/可分发词典方案通过 ADR 比较体积、三端实际支持、许可证、离线能力和准确率后决定，不预先锁定未经验证的库与版本。

读音数据保存原文 span、reading、来源、版本及可选置信标签。人名、地名、生僻字和混合语种允许用户修改；用户修正的优先级高于生成建议。正确区分可读汉字基底、送假名、标点和作者 ruby，避免对整个句子机械标一串读音。

### 10.2 语法结果契约

```swift
struct GrammarAnalysis: Codable, Sendable {
    let schemaVersion: Int             // 草案1，需运行时验证
    let language: AnalysisLanguage     // ja/en分别测试
    let sourceText: String
    let sourceTextHash: String
    let sentenceTranslation: String?
    let items: [GrammarItem]
    let warnings: [String]
}
struct GrammarItem: Codable, Sendable {
    let id: String
    let quote: String
    let span: CodePointSpan            // start/end半开区间
    let label: String
    let explanation: String
    let reading: String?
    let confidence: ConfidenceLabel?  // high/medium/low
    let provenance: ItemProvenance    // dictionary/model/user
}
```

上述是未编译契约草案，辅助类型和运行时校验由 N4 实现，不能当现有 API。

模型输出的 quote 必须在本次原文中回查；span 必须满足边界及逐字一致。重复短语用上下文定位，不能只取第一次；找不到则丢弃该条并记录可读 warning，不能虚构范围。语法可以重叠，采用分层或选中强调，不沿用“一律跳过重叠标注”的简单规则。

英语应单独设计词组、时态、从句、指代与长句结构的测试和提示词，不能只替换日语标签。解释使用用户指定语言，保留原句、自然译文和结构解释的区别。模型可能误判，提供纠错、重试和来源提示，不声称权威语法判断。

### 10.3 保存与再分析

原句、锚点、模型结果和用户编辑独立保存。切换模型或提示词生成新分析版本，不覆盖用户笔记。保存 UI 显示哪些内容将成为笔记；自动缓存不等于自动创建用户学习记录。复习功能可作为后续模块，先保证提取、定位与笔记闭环。


### 10.4 原生呈现与词典审计

EPUB 可开关新增逐词/句读音层，不替作者 ruby；PDF 在词浮卡或侧栏展示，不改原文版式。读音显示可选平假名/片假名/罗马字、常见词隐藏与用户校正；这些偏好是 PROPOSED 扩展。英日语法分别提供结构、助词/接续或主谓宾/从句/时态、解释语言与示例，不能复制日文标签当英文实现。

本地分词/词典引擎、字典资源、体积/准确率和三端构建仍待 ADR。fugashi/unidic-lite 是历史参考，不强制在 iPhone 安装 Python，不把系统分词等同权威读音词典。AI 不确定结果可修改，用户修正不被再分析覆盖；没有确切引用就保留 warning 而非画错高亮。

## 11 Bookno 交换协议草案

### 11.1 集成原则

用户要求 API，因此目标是明确可实现的跨应用 API 契约。本文不假定 Bookno 已运行 HTTP 服务。首先将交换 DTO、验证器、导入预览和幂等引擎做成与传输方式无关的模块，再决定采用 loopback 本地 API、原生 app bridge 或其他经批准的服务方式。

**PROPOSED 最小方向**：PDFno → Bookno 书籍、封面、笔记的单向 upsert。Bookno → PDFno 回传状态、双向编辑与删除传播另行批准。文件交换可作为开发测试和故障恢复通道，不把它冒充用户要求的最终 API。

双方共同拥有契约版本；建议 Bookno 定义接收模型并复用现有 importer，PDFno 实现 export adapter。禁止直接写 Bookno 的 CloudKit schema、SwiftData 或内部数据库。也不借用 Bookno 容器作为 PDFno 自己的同步后端。

### 11.2 稳定身份与字段映射

| PDFno 字段 | 交换语义 | Bookno 接收建议 |
|---|---|---|
| `book.id` | `externalBookID`，配合固定 source namespace | 复用 `BookSource` 与导入映射，不能只按标题去重 |
| `note.id` | `externalNoteID` | 复用 `ReadingNote` 外部身份与内容哈希 |
| `edition.sourceFileSha256` | 具体原书版本标识 | 保存导入来源 metadata，不当作作品唯一 ID |
| `book.cover` | 带 hash、MIME、字节数的资产 | 校验后转为 `coverData`；本地换封面需保护 |
| `note.quote` 与 `anchor` | 引文及可回跳来源 | 可读位置标签＋版本化来源 payload |
| `userText` 与 AI 附注 | 明确作者及来源 | 不混写成 Bookno 用户手写笔记 |

固定 source namespace 建议 `pdfno`，跨应用身份为 `(sourceNamespace, externalId)`。安装实例 ID 仅追踪设备；重装、备份恢复不改变既有书籍与笔记的外部 ID。Bookno `syncIdentity` 不承担该用途。

### 11.3 JSON 示例

以下是拟议契约示例，所有 ID、哈希、书名和文本均为说明数据；重复数字哈希未按实际内容计算，此示例不能直接作为通过完整校验的测试包。正式开发需配套 JSON Schema、规范化规则和真实计算哈希的黄金样本。

```json
{
  "protocol": "pdfno-bookno-exchange",
  "schemaVersion": "1.0",
  "batchId": "84dfb1a1-6961-444c-967b-f00aa7d4b221",
  "source": { "namespace": "pdfno", "appVersion": "0.1.0" },
  "createdAt": "2026-10-01T00:00:00Z",
  "mode": "upsert",
  "books": [{
    "externalBookID": "3fca52d9-5cb0-4108-9cbc-05f502c04603",
    "revision": 3,
    "baseRevision": 2,
    "contentHash": "1111111111111111111111111111111111111111111111111111111111111111",
    "title": "语言学习测试样书",
    "authors": ["测试作者"],
    "language": "ja",
    "identifiers": [],
    "edition": {
      "id": "c735a706-e74e-4f28-aecf-50dbb2b4daec",
      "format": "epub",
      "sourceFileSha256": "2222222222222222222222222222222222222222222222222222222222222222"
    },
    "coverAssetId": "cover-1",
    "updatedAt": "2026-10-01T00:00:00Z"
  }],
  "notes": [{
    "externalNoteID": "873609e5-b0cf-4d64-9495-a5e6460e3793",
    "externalBookID": "3fca52d9-5cb0-4108-9cbc-05f502c04603",
    "revision": 1,
    "baseRevision": 0,
    "contentHash": "3333333333333333333333333333333333333333333333333333333333333333",
    "quote": "本を読みます。",
    "userText": "测试笔记",
    "aiAttachments": [],
    "sourceLocation": {
      "schemaVersion": 1,
      "editionId": "c735a706-e74e-4f28-aecf-50dbb2b4daec",
      "format": "epub",
      "label": "第 1 章",
      "anchorRef": "anchor-1"
    },
    "updatedAt": "2026-10-01T00:00:00Z"
  }],
  "assets": [{
    "assetId": "cover-1",
    "role": "cover",
    "mimeType": "image/png",
    "byteLength": 2048,
    "sha256": "4444444444444444444444444444444444444444444444444444444444444444",
    "transferRef": "assets/cover-1.png"
  }],
  "anchors": [{
    "anchorId": "anchor-1",
    "schemaVersion": 1,
    "editionId": "c735a706-e74e-4f28-aecf-50dbb2b4daec",
    "sourceFileSha256": "2222222222222222222222222222222222222222222222222222222222222222",
    "extractionVersion": "fixture-1",
    "textNormalizationVersion": "fixture-1",
    "quote": { "exact": "本を読みます。", "prefix": "", "suffix": "" },
    "offsetUnit": "unicode-code-point",
    "canonicalSpan": { "start": 0, "end": 7 },
    "locator": {
      "kind": "epub", "resourceHref": "chapter1.xhtml", "spineIndex": 0,
      "engine": { "name": "fixture", "version": "1", "locatorType": "test", "value": "p1" }
    }
  }],
  "tombstones": []
}
```

原始书文件不默认包含在交换包；先满足书籍 metadata、封面与笔记。用户要发送原书时另行定义权限、体积和版权边界。封面可先按哈希询问接收端是否已有，再独立上传字节；`transferRef` 只接受本批次声明的相对资产引用，不能让接收端任意抓取 URL 或读取发送端路径。

### 11.4 幂等与本地编辑保护

接收端先校验完整 batch 和资产，再给出新增、更新、跳过、冲突、失败预览。每项按 `(sourceNamespace, externalId)` 查找，按内容哈希和修订去重。相同 `batchId` 与相同内容重试返回同一结果；相同 `batchId` 内容不同拒绝。

接收端按实体保存 `lastAcceptedSourceRevision` 与对应 `contentHash`，在同一事务中检查并更新，防止并发请求跨过检查：

- 输入 revision 小于已接受 revision：返回 `ignored / STALE_REVISION`，不更新业务字段，不倒退导入基线；较新的时间戳不能让旧修订重新生效。
- revision 相同且哈希相同：返回 `unchanged`，视为幂等重放，不重复创建或覆盖。
- revision 相同但哈希不同：拒绝 `REVISION_CONTENT_MISMATCH`，要求发送方修复协议或重新编号。
- revision 更大但 `baseRevision` 与接收端基线不一致：进入 `BASE_REVISION_MISMATCH`，请求缺失基线或可审阅的完整快照；不能仅凭较大数字强行覆盖。
- revision 更大且基线匹配：仍须检查本地编辑，再按三方比较决定 applied 或 conflict。

批次重放和实体重放是两层检查：换一个 batchId 发送旧实体，也不能绕过上述规则。备份恢复后不能重新使用已发布 revision 表示不同内容；恢复流程需保留修订历史，或建立明确的新同步 epoch 与人工审阅的重新对账，不能静默将历史版本覆盖到 Bookno。

每项保存上一次成功导入的规范化源快照或其字段哈希、源修订与接收端本地修订。新版本到达时做三方比较：上次导入基线、Bookno 当前值、PDFno 新值。仅源端变化且本地未改的字段可更新；双方改同字段进入冲突；Bookno 用户新增的备注、标签、封面不被静默覆盖。

`contentHash` 仅对版本化规范化 DTO 的语义字段计算，固定键排序、Unicode 与缺省值规则；不包含 batch 时间、传输地址或本地路径。契约变更必须相应升级规范化版本，避免每次导出都被误判为内容变化。

源端修订号由 PDFno 的统一实体修订机制产生，不能把不同设备各自递增的计数直接当成全局可比较版本。交换记录还应按接收端保存已确认基线；多设备尚未合并的分支先解决本地冲突，再决定导出内容。

**默认不删除**：源端某条记录未出现在批次，不代表删除。交换协议 v1 不执行远端删除；即便携带 tombstone，也只作预览或待确认。若后续批准传播删除，需定义软删除、恢复窗口、已编辑内容保护、离线设备和 tombstone 保留策略。

### 11.5 回执与失败恢复

```json
{
  "protocol": "pdfno-bookno-exchange",
  "schemaVersion": "1.0",
  "batchId": "84dfb1a1-6961-444c-967b-f00aa7d4b221",
  "status": "partial",
  "items": [
    { "kind": "book", "externalId": "3fca52d9-5cb0-4108-9cbc-05f502c04603", "status": "applied", "acceptedRevision": 3, "contentHash": "1111111111111111111111111111111111111111111111111111111111111111" },
    { "kind": "note", "externalId": "873609e5-b0cf-4d64-9495-a5e6460e3793", "status": "conflict", "code": "LOCAL_EDIT_DIVERGED" }
  ],
  "assetResults": [{ "assetId": "cover-1", "status": "verified" }],
  "committedAt": "2026-10-01T00:00:05Z"
}
```

“已发送”不等于“已同步”。PDFno 只有收到明确提交回执后才推进对应项的 confirmed revision。回执必须关联 batch、实体、修订和内容哈希；确认游标只能单调前进，迟到回执不能使其倒退。`STALE_REVISION` 可返回接收端已接受的修订作为对账信息，但不能把本次旧内容标为新提交成功；无法对应本地内容哈希时先对账。超时视为结果未知，以同 batchId 查询或重试，不能新建重复批次。单书和依赖封面、笔记的事务边界需明确；缺父书的笔记不得变成孤儿数据。接收成功但本地未保存回执的崩溃场景必须在测试中覆盖。

### 11.6 传输与身份验证待决策

若选择本机 HTTP，服务仅监听 loopback，校验 Origin、Host 与调用者，使用明确配对和受保护的认证机制，限制请求体、并发、速率与资产类型，防止网页访问本地 API。不能仅凭 CORS 当作认证；不能把持久 token 放 URL 或日志。

若选择 native bridge 或 deep link，深链只携带短期操作引用，不能携带整段笔记、封面或秘密。Bookno 未启动、版本不兼容、用户拒绝导入时给明确状态。若选择云 API，新增服务、账号、隐私、费用和运营责任必须独立批准。本文未决定具体方案。


### 11.7 原生三端 API 与高亮/封面补充契约

目标仍是独立 API，不共享 PDFno/Bookno 的 SwiftData/SQLite/CloudKit records。建议操作语义：协商 capabilities/schema → plan batch/import preview → inquire missing asset hashes → upload declared assets → commit idempotent batch → query receipt/conflicts。URL 路由、认证和后台服务实际未定，此处不是已运行 HTTP API。

批次增加明确 annotations/highlights DTO 或 LearningNote annotation 字段：类型、颜色/样式、引文、稳定 sourceLocation/anchor、revision/baseRevision/hash；不只把高亮压为用户正文。Bookno 接收端需要支持的字段/映射由双方当前模型确认，未知能力给出预览/保留，不丢失。

封面按 SHA-256 + MIME + byteLength +尺寸预检去重；接收端已有 verified asset 就关联不重复传字节，没有就受控上传。损坏/缺字节可让书籍待补封面，但回执不得标封面成功。引用同一封面不等于同一本书。Bookno 用户自改封面遵循共同基线冲突保护，不覆盖。交换 v1 的原始文件/tombstones仍不默认上传或执行远端删除。

多设备修订先合并父链，导出层保存 per-receiver 已确认语义基线和线性 sourceRevision/epoch；禁止多个设备独立发相同 revision 不同 hash。可采用经批准的单导出责任者或可证明的协调协议，在协议未定时拒绝分叉导出并展示冲突。备份恢复保留 cursor/history，不复用已发布 revision 表示新内容。

本机 loopback API 仅可能解决同一 Mac 两 app，**不能作为 iPhone/iPad 跨应用或跨设备 API 的完整方案**。移动端需验证获准 app handoff/受保护传输或独立服务；云 API 的账号/费用/运营待决定。文件包是契约测试与恢复通道，不把文件导出冒充用户要求的最终 API。反向回链用经过校验的短操作引用与 book/edition/anchor 映射，缺原书提示下载/重选；不在 URL 携带 key、整段笔记或封面。

## 12 iCloud：文档资产、结构化记录与三端离线

### 12.1 产品和身份边界

**CONFIRMED** PDFno 长期 Mac、iPhone、iPad 的自身同步与 Bookno 跨应用交换是两条独立链路，各自开关、身份、回执、冲突与诊断。Bookno 已有 CloudKit 不能证明 PDFno 已实现同步。PDFno 不沿用 Koodo iCloud 目录或 Bookno 内部容器，不共享业务数据库。

**DECISION** Apple Developer team、注册发行 bundle IDs、CloudKit/ubiquity container、环境及 entitlements 尚未确定。临时开发 bundle IDs 已写入工程，未注册账号身份；开发最低版本采用 4.2 的可调整基线。本轮不申请或修改账号/权限/容器。候选名称仅在未来 ADR 中描述，不在规格写一个看似已生效的容器 ID。

### 12.2 后端与数据分类方案

**PROPOSED** 首选评估 PDFno 自有 CloudKit private database＋CKSyncEngine，同步版本化小记录和封面等 CKAsset；原书是否同步由用户决定。官方 [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5) 在 macOS 14/iOS 17/iPadOS 17 引入，辅助记录传输，不替应用决定本地 store/领域冲突。参见 [privateCloudDatabase](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase)、[CKAsset](https://developer.apple.com/documentation/cloudkit/ckasset)。

| 类别 | 本地与拟议云对象 | 默认/待定 |
| --- | --- | --- |
| Book/Edition/封面 manifest | 稳定 ID/hash/schema/revision records；Book 引用 cover asset | 建议同步，尚未启用 |
| 高亮/笔记/作者/标签 | Annotation/Note records，旧修订/基线/墓碑 | 建议同步并保护离线编辑 |
| 阅读进度 | edition＋anchor＋设备来源/历史 | 建议同步；多设备进度分叉可选择，不能覆盖笔记 |
| 封面/附件 | 不可变 hash asset＋本机下载缓存/校验 | 建议封面同步；附件大小/限额待定 |
| 文档原件 | local Asset＋可选 CKAsset 或自有 iCloud Drive 文件 manifest | 原书不默认上传；内容/配额/Wi-Fi/删除策略待定 |
| 已完成 AI 附注/草稿 | 与用户笔记分离的 result/draft record | 哪些同步待定；运行请求不跨设备继续 |
| 可重建索引/临时译文/缩略图 | 本机缓存，必要时根据原文件重建 | 默认不云同步，可清理 |
| API key/bookmark/路径/数据库 | Keychain、本机文件权限与本地 store | 不进入云 DTO；无 key 或运行 SQLite 同步 |

保留三个候选并说明差异：A，CloudKit records＋CKAsset 统一；B，自有 iCloud Drive 版本化文档包/manifest，同步记录另做文件变更协议；C，CloudKit 小记录＋iCloud Drive 大书，仅在明确资产/记录一致性后采用。A 建议最先评估；B 要文件协调/占位下载/冲突副本，C 双后端恢复成本最高。SwiftData/Core Data 系统镜像也是结构化候选，但不能与自写 CKSyncEngine 同管 records。后端/原书范围仍是 DECISION。

### 12.3 文档资产生命周期与文件协调

云书以内容 hash、byteLength、mime、edition、asset availability 表示；不同设备重新获得本机 URL，永不同步绝对路径或 security-scoped bookmark。metadata 已到而文档未下载仍可见封面/笔记/引文，打开显示下载/缺失/重选，不跳错 edition。下载写临时区→大小/hash 验证→原子安装→本机 availability 更新；中断、空间不足、配额/网络失败可重试，不损已有副本。上传也只引用完成的 immutable asset，不能让记录指向一半字节。

若选择 iCloud Drive，使用自己的 ubiquity container API 和 [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator) / file presenter 协调，在文件可用后阅读，处理占位文件、系统下载状态和 conflict versions；不硬编码 `~/Library/Mobile Documents` 或另一 app 目录。manifest 版本化、临时写/校验/原子提交，接收端不消费未完成提交。源书不被翻译/批注改写。应用数据 store、WAL、正在写的 JSON、Keychain 从来不当云文件传。

大文件策略需固定最大体积/网络和前后台政策/储存预算/暂停恢复；无可靠进度则显示阶段。后台推送或系统调度不是实时保证，UI 不承诺每次关窗就已跨端同步。iPhone/iPad 不依赖 Mac 进程继续下载或 CLI 执行。

### 12.4 同步事件、冲突与确认

设备本地持久化为离线工作真值入口；本地写＋outbox 在同事务。每次 change 带 changeID/deviceID/deviceSequence/entityID/parentRevision/schema/hash/op；序号只在设备内比较，时间只显示。持久化 CKSyncEngine serialized state 与 pending changes，在重启中恢复；同 zone/entity 的写入责任唯一。不通过重启创建新 ID 规避未知回执。

接收按修订父链/共同基线比较：不同字段可自动合并；同字段并发保留双方版本和可解决 conflict；不能墙钟 last-write-wins 丢用户文字/封面。CloudKit server change token/changeTag/serverRecordChanged 由 adapter 处理；应用笔记冲突仍按领域规则。资产与父书依赖明确，缺资源可待下载，不产生不可恢复孤儿。

状态独立区分本地已保存、待发送、已发送、云端确认、资产未下载、冲突、暂停/失败；收到服务确认才推进确认游标。重试幂等，迟到 ack 不倒退；失败不丢本地编辑。账号退出/切换建立账号空间与队列隔离，不把旧账号 pending 上传新账号，不删除未同步本地内容；重新登录需明确对账。

### 12.5 删除、长离线与迁移

区分“移除本机下载”“从书库删除”“跨设备删除”，永久删除另有明确动作。删除用墓碑/恢复窗口，asset 垃圾回收等无引用/期限/已确认与离线设备规则满足后执行。具体保留天数未定；不能短期墓碑却允许无限旧设备回传而误复活。超支持窗口设备先全量 reconciliation/epoch 检查，再恢复写入。

云迁移前验证本地一致备份、schema/epoch/mapping，在只读验证后切换唯一写后端；不无协议双写。老客户端遇未知 schema 停写提示升级。关闭 iCloud、配额不足、容器不可用均保持本地可读。

N6 实施：先本地 outbox/冲突 mock→决定内容/后端/身份→明确获准配置自己的 development 能力→两台真实设备→Mac/iPhone/iPad 三端→production schema/发行另验收。必须测离线两端同笔记/封面、删除恢复、时钟异常、账号切换、长离线、CKAsset/iCloud 下载失败、配额、重启未知回执和旧 schema。

## 13 格式转换能力矩阵

用户提出“PDF、Word、EPUB 等转换”，尚未决定方向。转换是独立文档处理子系统，不与阅读格式支持等同。下表以现代 Word `.docx` 为候选格式；旧 `.doc`、宏文档和其他变体是否纳入需单独确认，不将“Word”笼统视为全部已支持。

| 方向 | 可能目标 | 关键损失或风险 | 建议安排 |
|---|---|---|---|
| DOCX → PDF | 固定版式分享与打印 | 字体、分页、复杂对象、批注是否保留 | 候选首个方向，待用户选定 |
| EPUB → PDF | 将重排内容输出固定页面 | 页眉页脚、竖排、ruby、CSS 和图片布局 | 与阅读渲染一致性做专项评估 |
| 文本 PDF → DOCX | 可编辑文本 | 分栏、表格、公式、脚注、阅读顺序难还原 | 质量报告与用户预览必须具备 |
| 扫描 PDF → DOCX | OCR 后编辑 | OCR 错误、坐标与版式重建 | 后续，不能等同普通 PDF 转换 |
| PDF → EPUB | 重新排版阅读 | 原固定布局难结构化，可能严重重排 | 单独试验，先做文本型样本 |
| DOCX → EPUB | 生成语义化电子书 | 标题、目录、注释、公式和媒体映射 | 结构优先，需阅读器验证 |
| EPUB → DOCX | 编辑电子书内容 | CSS、ruby、竖排与章节语义损失 | 待明确实际使用场景 |
| 其他或批量转换 | 用户后续指定 | 输入输出组合增长 | 每方向单独批准，不宣称全格式互转 |

**PROPOSED 接口**：`probe(input) → capabilities`、`plan(input,target,options) → warnings`、`convert(plan,signal) → output + qualityReport`。每个 adapter 记录引擎版本、许可证、平台和可恢复错误。候选工具以当前官方文档与样本评估选择，不在本规格中锁定未经验证的商业 SDK、命令行工具或版本。

默认本地转换；若任何方案需向第三方上传原文件，必须在执行前说明具体服务、文件与目的并取得相应授权。不得自动上传作为本地失败的 fallback。

输出新文件，绝不覆盖原书。转换后按新 edition 入库并记录源版本关系；旧锚点不自动宣称兼容，只能经引文与结构重新匹配。质量报告至少列页数或章节数变化、缺失字体、未支持对象、OCR 页、警告和实际转换设置。成功完成进程不代表版式合格。


### 13.1 原生三端引擎与 OCR 缺口

上表全部方向当前 NOT-IMPLEMENTED。PDFKit 不提供通用 PDF↔Word↔EPUB 重建能力。每个 ConversionAdapter 输出本机/远程处理地点、平台、引擎来源/版本/许可、probe/plan/convert/quality/cancel；只对通过样本和平台开放主动入口。

DOCX→PDF 需独立排版/字体/分页引擎；EPUB→PDF 可研究已选 EPUB renderer 的受控打印管线；PDF→DOCX/EPUB 需布局/语义恢复，不能仅复制抽出的字符串称保真。预览/Quick Look 不代替可编辑文档解析。Word旧doc/宏仍未纳入确定范围。Mac外部工具/子进程候选不能直接在iOS执行或分发，若三端引擎缺口则该端明确未支持，不偷偷上传代替本地失败。

本地 OCR 优先评估 [Vision VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest)，官方三端 API 可用不证明日文竖排、漫画气泡或字级定位准确；具体语言/OS/样本实测。结果记录图像、识别版本/语言、区域与置信度，转换不混充原生文本。字体缺失/表格/注释/公式/ruby/章节损失写入质量报告；取消清理临时产物但保留原书/已提交结果。

## 14 界面与交互规格

### 14.1 视觉方向

**PROPOSED**：借鉴 UPDF 清晰的文档工具分区、阅读画布和辅助侧栏，使用 PDFno 自有品牌、图标与配色，并与 Bookno 家族保持一致的文字、留白和状态语言。先取得可用的 Bookno 设计 token 或参考画面；不要凭名称假定其色值或复制 UPDF 素材。

### 14.2 核心屏幕

1. **书库**：封面、格式、最近阅读、同步状态、搜索与导入。空书库提供导入；解析失败显示原因和可重试操作；封面缺失使用自有占位，不阻止阅读。
2. **阅读工作区**：可收起目录或缩略图、中央阅读画布、右侧学习栏。选区菜单提供翻译、语法、读音、高亮、笔记；无能力的操作说明原因。
3. **整页翻译**：原文与译文按段对应；显示当前任务页定义、模型、进度、部分失败、取消和重新生成。窄窗口优先切换视图，避免压缩原文到不可读。
4. **学习侧栏**：保留原句，提供译文、语法、读音及保存按钮。点击分析片段能强调来源；无法定位时显示状态而非跳错位置。
5. **笔记列表**：按书、章节、标签筛选；区分用户笔记和 AI 附注；回跳、导出、冲突与失效锚点修复入口。
6. **模型设置**：服务名称、endpoint、model、密钥安全输入、能力测试、费用配置；不展示完整已存密钥。
7. **Bookno 连接**：未连接、等待配对、可导入、预览、同步中、部分冲突、已确认、版本不兼容。明确展示书籍、封面和笔记的数量。
8. **iCloud 状态**：账号不可用、离线、本地待发、下载中、已同步、冲突、空间不足、暂停；不把本地保存显示成云端已同步。
9. **转换任务**：方向选择、文件预检、预计质量限制、进度、取消、输出位置和质量报告。

### 14.3 可访问性与 Mac 行为

键盘可完成选书、阅读导航、侧栏切换与笔记保存；焦点清晰，快捷键不覆盖常见系统行为。VoiceOver 能读到按钮、状态、原文与译文；流式结果避免每个 token 触发播报。支持深浅色、足够对比度、可调整字号、减少动画；错误不能只用颜色区分。

多窗口、全屏、分屏、拖入文件、系统打开方式、窗口恢复和高 DPI 需纳入 Mac 测试。首次版本不必照搬全部原生行为，但必须写明支持与已知限制。对转换、同步、模型任务的关闭确认只在会造成真实损失或仍有外部请求时出现。

### 14.4 UPDF 桌面实机参考与证据边界

**CONFIRMED 用户要求**：UI 界面以及后续 AI 功能全面参考用户正在使用的 UPDF；通过实际桌面操作理解界面和交互，再写成 PDFno 的实现规格。这里的“全面参考”覆盖信息架构、入口、点击路径、反馈与异常状态，不自动把 UPDF 的每项功能、账号体系或云服务列入 PDFno 首版。

**OBSERVED 桌面事实**：2026 年 10 月 1 日在用户 Mac 上实际操作 UPDF 2.5.7（1371），打开自制两页英日测试 PDF，进行界面观察和低风险导航。下表只记录不含私人文档与聊天正文的结构。可见入口不等于功能已跑通；本次未提交 AI 请求、未上传文件、未执行转换，未以编辑动作验证选区工具。已有聊天记录不是本次生成效果的证据。本规格不附桌面截图，也不复制其品牌、图标或界面素材。

| 参考 ID | 区域 | 实际可见或已操作的结构 | 验证级别与限制 |
|---|---|---|---|
| U01 | 首页 | 最近项目与收藏入口、封面卡片网格；搜索、排序和列表／缩略图切换；右上打开文件及云上传入口；底部工具、AI、云盘 Dock | 观察界面与入口；回首页保留文档标签；未执行云上传 |
| U02 | 文档框架 | 顶部文档标签；左侧窄导航轨及可收起的缩略图、目录、搜索区域；中央阅读画布 | 已观察；不把某次窗口布局当作固定尺寸 |
| U03 | 阅读工具 | 画布上三组浮动工具条；左侧工具与 AI，中间注释／编辑／表单等，右侧保存与撤销等；未编辑时保存与撤销禁用 | 已查看工具条；未验证保存或编辑；收起／展开 AI 后保留阅读位置与选区 |
| U04 | 目录与搜索 | 目录点击成功跳到测试 PDF 第二页，并出现返回原页入口；普通搜索经历“正在搜索”后返回四项按页分组结果 | 已实际测试导航和搜索；不代表所有文件或复杂版式均通过 |
| U05 | 文本选区 | 辅助功能树确认 AI、高亮、删除线、下划线、波浪线、笔记、编辑、书签、朗读、复制；注释面板有“暂无注释”空状态 | 普通工具名已确认；AI 下拉独立弹窗按钮无名称且截图异常，具体项目未可靠辨认；未执行编辑、批注写入或朗读效果测试 |
| U06 | 右侧 AI 栏 | 位于阅读工作区右侧；当前测试窗口中 AI 约占 17%，左侧约 13%，中央约 70% | 截图估算比例，非官方尺寸；不作为 PDFno 默认宽度 |
| U07 | AI 模式 | PDF 对话、通用对话、翻译、PDF 全文翻译、总结、解释、多文件问答、论文搜索与图谱、深度研究；翻译／总结／解释为上输入下结果 | 已观察入口和空状态；右轨切换不会把当时选文自动填入输入；未验证其他快捷链路或生成效果 |
| U08 | 全文翻译配置 | 文件信息、目标语言、仅译文或双语模式卡、页面范围、预计使用次数；测试时仅译文默认选中 | 已打开配置；未提交翻译；“保留原始布局”等文案不作为版式验证结果 |
| U09 | AI 额度状态 | 两页测试文件显示预计消耗两次，剩余次数为 0；开始按钮仍呈蓝色；文本工具空输入时发送按钮禁用 | 未点击开始，不能推断后续购买拦截、实际扣费或账号权益 |
| U10 | Word 转换配置 | 文件 → 导出到 → Word；模态中有格式、预览、页范围、内容样式与版式、OCR；当前为流动样式且 OCR 关闭 | 已进入配置并取消；未执行转换，不能承诺质量、时长、处理位置或费用 |
| U11 | AI 设置与会话 | 设置本页仅见 AI 助手开关和输出语言；通用对话显示既有全局历史 | 本页未见 BYOK 不等于整个产品无 BYOK；不记录历史正文，不把旧历史算作新生成 |
| U12 | 阅读显示 | 可见单页／滚动／双页、适合页面／宽度／高度等，已执行适合页面；日文测试页文字正常显示 | 未测试 EPUB、竖排、ruby、主题切换和窄窗口；不能推断语言学习能力 |
| U13 | 文件选择器 | macOS 打开文件面板可见 iCloud 云盘位置 | 仅证明系统文件选择器提供该位置；不能据此认定 UPDF 实现 iCloud 同步 |

当前窗口可见深灰应用壳、浅灰画布、蓝色选中状态与细线图标；这些只是本次环境外观。截图估计顶部与浮动工具条约 40 pt，左轨约 52 pt，左内容面板约 200 pt，右侧含 AI 功能轨约 328 pt。字体名称未读取，色彩和尺寸不是官方 token；自制 PDF 的纸张颜色也不是 UPDF 主题。PDFno 不直接沿用这些数值或截图取色。

阅读页是参考的核心：文档始终可见，工具按上下文出现，导航和 AI 解释有各自区域。PDFno 应复制这种任务组织方式的优点；具体菜单名称、资产、尺寸与实现全部属于自己的设计。

### 14.5 PDFno 屏幕地图与布局规则

**PROPOSED**：以下是 PDFno 的屏幕与组件契约，不是 UPDF 测量结果，也不是当前代码清单。保留 14.2 的九个核心屏幕，并用同一应用框架组织它们。

| 屏幕 ID | 页面或区域 | 主要组件与动作 | 必须持续可见的信息 |
|---|---|---|---|
| S01 | 书库首页 | 最近、收藏、全部；封面网格或列表；搜索、导入、打开；工具与任务入口 | 文件格式、阅读位置、导入错误；同步状态不能混作收藏状态 |
| S02 | 阅读工作区 | 文档标签栏、左导航轨、可折叠导航面板、中央正文、浮动阅读工具、右侧辅助栏 | 当前书和版本、页或章节位置、当前交互模式 |
| S03 | 学习工作区 | 选区来源卡、翻译、语法、假名、笔记；模型与范围选择；生成及取消 | 原文、定位标签、模型、外发范围、结果与保存状态 |
| S04 | 文档 AI | 当前文档问答、总结、解释；可回跳的来源引用；历史会话 | 当前绑定文档、使用的页或章节范围、来源是否已验证 |
| S05 | 翻译任务 | 当前页、单章节与批量范围分开；原文和译文对照；任务明细 | PDF 物理页、EPUB 原文快照或明确章节范围、完成与失败片段、费用估算可信度 |
| S06 | 工具中心 | 按实际支持方向显示转换、可选 OCR、任务队列；高级能力说明 | 本地或远程处理方式、质量限制、输出新文件位置 |
| S07 | 连接与同步 | Bookno 交换预览和回执；PDFno iCloud 设备与状态 | 两套连接的独立状态、冲突和最后确认时间 |
| S08 | 模型与阅读设置 | BYOK 配置、密钥引用、能力与费用设置；语言、主题、阅读偏好 | 当前生效配置；未配置、测试失败与不支持能力 |

组件应有单一职责：`DocumentTabs` 管文档切换，`NavigationRail` 管导航入口，`NavigationPane` 管目录、缩略图和搜索，`ReaderCanvas` 管正文，`SelectionActions` 管选区动作，`AssistPane` 管学习或 AI，`TaskStatus` 管异步任务反馈。名字是逻辑示例；实施时遵循真实工程结构，不借此重建或改名现有全部组件。

**PROPOSED 初始布局 token**：基础间距 4/8/12/16/24，导航轨约 52 pt，左面板初始约 232 pt，右辅助栏初始约 360 pt；左右面板可拖动调整并独立收起。它们是待验证的设计起点，绝非对 UPDF 的像素测绘。正文最小可用宽度、断点、字号和触控目标先在实际 Mac 渲染环境中确定，不能仅凭截图缩放换算。配色 token 先定义语义角色，例如背景、正文、分隔线、强调、警告和危险；具体色值待 Bookno 设计证据与对比度验证后决定。

宽窗口优先三栏；宽度不足先收起左展开面板，保留窄导航轨。仍不足时，辅助栏改为可返回原文的单栏或临时面板；翻译对照改为“原文／译文”切换，不能把两列继续挤压到难以阅读。拖动分隔条、开关侧栏、全屏与系统分屏都不能清除未保存笔记或改变任务来源。每个窗口保存自己的布局；书籍保存自己的阅读位置，两者不能互相覆盖。

### 14.6 实际点击路径与 PDFno 对应流程

下列左侧路径只陈述观察或测试到的范围；右侧是待实现的 PDFno 流程。没有实测生成态的步骤必须使用本地 mock 和合法样本设计、验收，不能借用用户旧聊天内容作演示。

| 流程 | UPDF 参考路径与已知终点 | PDFno 建议点击闭环 |
|---|---|---|
| J01 进入阅读 | 首页最近／收藏入口与文档标签工作区可见；未把“从最近项目打开”的完整链路列为已测试 | 选封面或打开文件 → 本地解析 → 恢复锚点；失败保留书库条目并说明原因 |
| J02 导航定位 | 左侧目录或搜索 → 选择结果 → 正文跳转；跳转已测试 | 目录、页缩略图、搜索共用导航服务；记录返回位置；搜索失败不改变阅读位置 |
| J03 选句学习 | 选择正文 → 可见选区浮层；普通工具名已确认，AI 下拉具体项未识别；从右轨切入翻译／总结／解释未自动带入选文 | 选句 → 浮动菜单“翻译／语法／假名” → 固定来源卡 → 选择或确认范围 → 生成 → 校验 → 保存笔记 → 回跳原文 |
| J04 文档问答 | 右侧 AI → PDF 问答与通用聊天等入口；未提交请求 | 打开文档 AI → 显示绑定文档与范围 → 提问 → 检索预览或来源说明 → 回答 → 点击引用回原文；无依据时明确说明 |
| J05 当前页翻译 | 翻译相关入口已可见；本次未验证输出 | 点击“翻译当前页”（章节用独立命令） → 展示 PDF 页索引或 EPUB 快照 → 模型与费用说明 → 开始 → 分段进度 → 对照与失败重试 |
| J06 批量翻译 | 全文翻译 → 目标语言、输出形式、页范围、预计次数；止于设置 | 另设“批量翻译” → 选择页或章节范围 → 提取预检与费用估算 → 按批准范围执行；首版未支持时显示说明而非可点击假入口 |
| J07 格式转换 | 文件 → 导出到 → Word 配置，OCR 关闭 → 取消返回；未转换 | 工具 → 选择输入与明确方向 → 预检 → OCR 等选项 → 输出位置 → 开始 → 质量报告；原文件不覆盖 |
| J08 数据连接 | 首页云入口可见；本次未上传 | 独立“Bookno 交换”和“iCloud 同步”入口 → 各自预览、进度、错误和确认状态；不连接 UPDF 官方云 |

快捷操作不应绕过数据与费用语义。点击选区“翻译”可以创建待执行来源快照和打开面板；是否立即发送由已明确的服务与内容授权、当前设置及任务范围决定，不把“打开面板”本身当作发送许可。普通阅读、打开标签、搜索、切换 AI 模式都不自动上传整本书。

### 14.7 AI 模式与产品范围映射

**PROPOSED**：按用户要完成的任务分组，而不是把 UPDF 所有 AI 入口平铺在 PDFno 首屏。当前建议 N4 包含选句学习、页/章节双语与文档问答；以后功能已预留信息架构，但需独立批准范围和验收。

| 模式 | 文档来源范围 | PDFno 内容与输出契约 | 阶段与边界 |
|---|---|---|---|
| 选区翻译 | 固定选区＋明确必要上下文 | 原句、自然译文、来源定位、模型与版本 | 建议 N4；不暗中扩为整章 |
| 日英语法 | 固定句子或片段 | 第 10 章结构化语法、原文跨度、纠错与来源 | 建议 N4；不是通用聊天文本套一个标签 |
| 假名与读音 | 作者 ruby 或当前选区 | 原文 span、读音候选、来源、用户修正 | 建议 N4 侧栏显示；不重排原 PDF |
| 当前页翻译 | 第 8.1 节定义的 PDF 页或 EPUB 快照 | 段落对应、可取消、部分完成、继续和费用 | 建议 N4；与全文翻译是不同命令 |
| 章节双语翻译 | 用户选择的一章或明确 spine 资源集合 | 原文/译文逐段对应、章节计划、范围/预算、恢复与来源回跳 | 建议 N4C；不从当前页命令暗中扩大范围 |
| 文档问答 | 明确选定的文档、页或章节集合 | 回答＋已校验来源；区分引文、释义和模型推断 | N4D 独立任务；先做提取、检索和引用试验 |
| 总结与解释 | 选区、页或用户确认的章节 | 标注范围的摘要或解释；必要时可回跳来源 | 可先作为选区学习的受控模板试验；不等于自动总结全书 |
| 通用聊天 | 默认不带书籍文本 | 明确“未使用当前文档”；用户主动附加范围后才使用该内容 | 后续；单独会话，不能误称为有文献依据 |
| 批量或整书翻译 | 显式页范围、章节集合或全书 | 预检、分段计划、输出形式、预算、断点和质量报告 | 后续；保留 3.2 的范围门禁 |
| 多文件问答 | 用户显式加入且有权处理的文档集合 | 每条引用带文档与版本；单独说明索引和外发范围 | 后续研究项；不能自动扫描书库 |
| 论文与深度研究 | 尚未决定的数据源与工具 | 需先定义检索来源、引用、联网、费用和权限边界 | 只保留信息架构扩展点，不承诺复刻 UPDF 后端 |

每个模型请求显示服务名称、模型和作用范围。UPDF 的“预计使用次数”只能作为预检反馈的交互参考；PDFno BYOK 应根据真实配置展示字符、token、费用估算或“费用未知”，不能造一个统一 AI 点数余额，更不能把 UPDF 账号的次数映射为 PDFno 可用额度。

文档问答若后续实现，应以已提取原文和可验证锚点为基础：检索结果记文档 ID、版本、页或章节与 span；模型生成的引用先做原文回查，再允许跳转。未找到依据、OCR 置信度低、索引未完成、来源已变化都有独立提示。索引位置、本地或远程 embedding、缓存与删除行为需另行 ADR；不得因打开“PDF 问答”自动把全文传到某服务。

### 14.8 侧栏模式与任务状态机

**PROPOSED**：布局、模式、来源和后台任务分开建模。右栏关闭是布局变化，不等于取消后台请求；模式切换也不是自动重发。状态由任务服务的真实事件驱动，不能用计时器伪造生成完成。

```text
WorkspaceView
  activeDocumentId + activeEditionId + activeTabId
  leftPane = collapsed | thumbnails | outline | search | notes
  rightPane = closed | learning | documentAi | translation | taskDetails
  assistMode = translateSelection | grammar | reading | documentChat |
               generalChat | summarize | explain | translatePage | translateChapter
  source = none | captured | stale | missing | unsupported
  task = idle | preparing | needsConfiguration | awaitingConsent |
         queued | requesting | streaming | completed | partial | failed | cancelled
```

以上是 UI 投影草案；第 8.3 节的任务生命周期仍由领域服务负责。`preparing` 可映射提取与快照校验，`needsConfiguration` 对应缺少模型或能力，`awaitingConsent` 对应仍缺外发授权；不要让 UI 枚举与持久化任务状态各自发明一套互不一致的真相。保存笔记的 `unsaved/saving/saved/saveFailed` 独立于模型任务完成状态。

| 事件 | 状态变化或行为 | 必须保持的不变量 |
|---|---|---|
| 在正文重新选区 | 生成新的来源快照；未发送前可替换待执行输入 | 已发请求继续绑定旧快照，不能被新选区改写 |
| 点击模式 | 切换内容模板与能力检查；保留各模式草稿 | 不自动发请求；通用聊天不继承隐形书籍上下文 |
| 点击生成 | 校验来源、范围、provider 和授权；满足后入队 | 按固定 taskId 关联响应，防双击重复请求 |
| 收到流式片段 | 在相应任务视图追加，提供取消 | 引文仍待校验；半成品不能冒充已保存笔记 |
| 点击停止 | 请求取消、停止未发片段，并显示最终已知结果 | 已发送请求可能计费；取消不删除可读结果 |
| 切书、切标签或关侧栏 | 保留窗口与文档各自状态；显示后台任务入口 | 不把 A 书回答显示成 B 书结果；不暗中追加范围 |
| EPUB 重排或 PDF 缩放 | 重新映射显示锚点；任务快照不变 | 页面标签变化不能改变请求文本和缓存键 |
| 来源文件替换或提取版本改变 | 标记 stale，允许查看旧结果和重新定位 | 不能把旧引用无提示地跳到新版本 |
| 部分失败后继续 | 只重试仍失败且获准的片段 | 成功片段不重复发送；用户编辑不被覆盖 |
| 保存结果或修改 | 单独提交笔记与修订；成功后显示保存状态 | AI 缓存不等于用户笔记，失败保留编辑缓冲 |

右栏的共同结构建议为：模式与文档范围栏 → 来源卡或任务摘要 → 结果区域 → 跟随模式的输入／控制区。来源卡可折叠但不可省略，至少保留书名、页或章节、原文摘要与“回到原文”。长结果独立滚动；正文滚动与侧栏滚动互不劫持。自动滚动只在用户位于输出末端时启用，用户向上查看时不强行拉回。

### 14.9 选区持久化与阅读交互细则

文本选择与编辑模式必须明确分开，避免拖动阅读变成标注或编辑。浮动菜单在选区附近避让系统边缘、正文关键行与侧栏；视口不足时用稳定工具区，并提供键盘等价入口。长按、右键、鼠标选择和键盘选择最终走同一动作接口，不能依赖仅鼠标可达的悬停。

用户选择正文后，先由 adapter 捕获规范原文、locator、quote 和显示高亮信息。把焦点移到侧栏、点击语法标签、调整面板宽度或打开菜单时，不能只依靠瞬时 PDFSelection 或 EPUB DOM Selection。模型输入来自不可变来源快照；显示高亮可以重绘但不改原始锚点。EPUB 因重排需要重新定位，PDF 因缩放需要重算视图矩形，两者都遵守第 7 章，不保存一次截图的屏幕坐标。

来源回跳包括“定位并临时强调”与“永久高亮”两种语义；点击引用只临时强调，不静默写一条批注。跳转前保留返回位置，失效锚点进入修复说明，不跳到同名短语的第一个匹配。多标签下笔记草稿按文档与笔记 ID 保存，关闭有真实未保存内容的标签时才提示。

### 14.10 视觉状态与可访问性验收补充

按钮和面板覆盖正常、悬停、焦点、选中、禁用、忙碌、错误与部分完成。禁用项说明缺少什么：未选正文、扫描页需 OCR、模型不支持、服务未配置或功能尚未开放，不能所有原因都显示“失败”。仅在任务范围得到确认后使用进行中进度；未知进度显示阶段文字，不能编造百分比。

图标使用自有设计或许可明确的图标集，图标按钮有可访问名称与可见 tooltip。导航组、文档标签、分隔条、工具栏、来源卡、输入与结果有清楚的语义和焦点顺序；分隔条能够键盘调宽并恢复默认。关闭临时面板或菜单后焦点回到触发位置；Escape 关闭当前临时层，不清空选区、草稿或自动停止后台任务。

VoiceOver 能识别当前文档、被选模式、展开状态、任务阶段、来源与保存状态。流式 token 合并后按可理解的阶段或段落更新播报，保留可手动阅读的完整结果。翻译对照和日语 ruby 验证朗读顺序，不把原句、译文、读音连成重复且不可理解的文本。字号、对比度、深浅色、减少动态效果与系统分屏都纳入测试，而不是仅检查静态截图。


### 14.11 Mac、iPad、iPhone 的原生布局/手势与 Apple Pencil

| 设备 | 原生结构与输入 | 验收重点 |
| --- | --- | --- |
| Mac | SwiftUI 书库/文档窗口；AppKit PDFView；可折叠目录/缩略图/搜索和学习栏；菜单/快捷键/鼠标/触控板/拖入 | 多窗口revision/焦点、窄窗/全屏/高DPI/VoiceOver；窗口布局不覆盖书籍阅读位置 |
| iPad | 宽度足够 NavigationSplitView/正文/学习，窄分屏改可返回单正文＋sheet；UIKit PDFView；触摸/键盘/Pencil | 横竖屏、系统多任务/窗口缩放、安全区/软键盘、外接键盘/VoiceOver；源与草稿保持 |
| iPhone | NavigationStack 单列；目录/笔记/学习用 sheet或独立页；底部安全区原生动作 | 小屏/Dynamic Type/软键盘/旋转/后台重开；回正文仍同source，不硬塞三栏 |

共享状态和行为，平台布局可以不同。短按阅读控件、拖动选字、长按菜单、双指缩放/滚动、翻页、辅助面板滚动互不抢占；UIKit选字菜单走同一ReaderAction接口。所有动作有键盘/VoiceOver替代，触控目标建议至少44pt并实际检查，不依赖仅悬停浮层。减少动画、增强对比度、大字/VoiceOver下正文可用，图标均有名称；颜色之外有标签/形状标示类别与状态。

iPad Pencil 为分阶段 PROPOSED 能力：先文本阅读与手指选择，后独立标注模式/笔工具/橡皮/撤销、笔绘与手指滚动政策，最后可选导出带墨迹PDF副本。Pencil专用手势按实际硬件/OS能力开放，不承诺所有笔都支持；手写识别/AI解释不是默认能力。建议 UIKit [PKCanvasView](https://developer.apple.com/documentation/pencilkit/pkcanvasview) 页overlay捕获，存页坐标/versioned stroke/attachment，不存画布像素。该API没有原生macOS支持，Mac提供通用墨迹投影/已导出PDF阅读，不能声称同一canvas三端可编译。

ink和PDFKit缩放/旋转/CropBox变换需要往返测试、分页/内存/撤销/保存中断/重启；EPUB重排手写区域无法天然稳定，先限固定页或独立学习卡，未验证不覆正文。后台不保证继续AI/转换：进入后台持久化草稿/页锚点/任务段落，回前台按真实状态恢复，未知请求结果不重发假成功。Share Extension/系统分享导入为后续独立target与权限范围，不本轮建立。

## 15 旧成果、数据迁移与回滚

### 15.1 保留清单

| 现有内容 | 后续处理 |
| --- | --- |
| `src/`、`electron/`、`shared/`、锁文件、npm 工具链 | 保留旧 demo 与运行方式；停止新增旧路线功能，必要保护/回归修复另定 |
| `tests/`、Unicode/ruby/任务/笔记/安全 fixtures | 作为 Swift golden behavior 来源，合法样本/映射单位重验；不计为新 reader passed |
| `native/PDFnoBridge.xcodeproj`、workspace、CLI 源 | 保留命令行验证；新 app 在 `apple/` 独立创建，不改名冒充主应用 |
| Xcode 自动生成 workspace/用户元数据 | 原样保留，不删除、不当产品配置提交 |
| `docs/` ADR、计划、审计、CI 与授权记录 | 保留快照，未来写明被 v0.3 替代的主架构；不改写历史通过结论 |
| `notes-v1.json`＋backup、浏览器 demo 数据 | 原生只读 importer/用户导出输入；新 store 独立，不覆盖源 |
| Koodo/其他参考项目 | 不写入其存储；如将来导入先备份/只读预览，保留原 locator/来源标签 |

新工程/应用数据目录、bundle 身份、更新源与 Bookno/Koodo/旧 demo 分开。数据与持久 ID 可映射，不复用官方账号状态、插件、签名和内部 schema。阅读模板、UI 结构和通用行为可以参考，不把 JSX 转 SwiftUI 或 CLI 在 iPhone 运行当迁移。

### 15.2 迁移流程与兼容

1. 记录当前 commit/工作树/其他任务改动，原 JSON/store/backup 只读备份并核验 hash，保留最后可运行旧版本。
2. 新 store 创建独立 schema/目录；源数据预检 schema、ID、revision、quote、容量和资产，未来版本拒绝写入。
3. 用自制旧数据测合法/损坏/重复/中断/冲突/取消；Browser localStorage 须未来用户发起版本化导出，当前无现成跨浏览器读取/导出保证。
4. 展示新增、保留、冲突、需重绑数量和内容预览；不因导入 API 自动覆盖当前库。
5. 原子写新 store，保存 sourceDigest/batch/mapping/receipt；重复导入幂等，写失败源与新库有效已提交数据仍在。
6. 校验 ID、引文、用户文字、作者 ruby、AI provenance/revision、重启和恢复；未知 locator 保持可读并报告，不丢记录。
7. 回滚切回旧 app/旧 store，新库另可导出备份；不开未设计的双向双写，不用旧 app 写新 schema。

legacy `demo-text-1` 的 sourceFileSha256 是内容 fingerprint，保留 `legacy-demo` 与原 ID/hash 语义；除对原自制文本恢复，不直接绑定真实 PDF/EPUB。mock aiText 保持 mock 标识，不升级成真实模型质量证据。转换或更换文件创建新 edition/旧锚点需重绑，不能复用屏幕矩形。

Koodo 将来导入属于另项能力；不直接改用户数据库。未知设置/插件/官方服务不迁。上游比较/更新固定版本、完整依赖与回归；不再计划合并 Koodo fork 作为主应用维护。用户已明确授权旧骨架在备份后退役，具体移出、保留及恢复方式见 `NATIVE-MIGRATION.md`；旧数据不受影响，自动迁移仍未实现。

## 16 三端构建、签名与发布门禁

### 16.1 开发与 CI

**PROPOSED**：N1 在本仓库 `apple/` 新建真正 workspace/project/两个 application targets，共享 Swift packages；后续 CI 分共享包 unit tests、macOS app build/UI、iPhone/iPad Simulator build/UI。包资源/EPUB source manifest/Package.resolved 固定实际依赖，更新第三方 notice，不升级旧 npm 链解决新架构。

验证同时记录 Xcode/Swift/SDK、OS、架构/设备、scheme/destination、configuration、commit、实际命令/退出码、测试数量与未测项目。Mac arm64/Intel 支持看实际构建和设备范围，Intel 发布范围待定。模拟器 unsigned build 可以验证工程，不能代替 iCloud/Keychain/Pencil/手势/后台实机。现有 npm CI 只验证旧 demo/CLI，不能拿旧绿色 CI 证明原生阅读完成。

推荐 future commands 是任务卡示例而非本轮执行记录：`swift test`（指定实际包目录）；`xcodebuild`（显式 workspace/scheme/destination/derivedDataPath）build/test。N1/N2 的实际路径、命令、结果与未覆盖范围见 `VALIDATION.md`；原 CLI 类型证据只用于历史说明。

### 16.2 身份、最低版本与能力

最低 macOS/iOS/iPadOS、最终 Swift/Xcode、Developer team、bundle IDs、CloudKit/ubiquity containers、Keychain groups、sandbox/network/file capabilities、push/background modes、签名、公证、hardened runtime、更新源均 **DECISION**。不自动复用上游/Bookno 身份，不索取或写日志中的凭据。候选 macOS14/iOS17/iPadOS17 与 CKSyncEngine 关联只是建议；系统版本在正式工程配置前固定。

### 16.3 发行验收

开发、内部测试和发行包分开。Mac 直接发行/商店、iPhone/iPad TestFlight/App Store/其他允许渠道的签名和条款各自核验；AGPL 开源选择不自动改成闭源，也不保证任何商店条款兼容。分发前检查实际代码/依赖/字体/字典/notice/对应源码/修改声明/来源获取方式与渠道要求，未知则发行项保持未通过。

干净安装、同时安装旧 app/Bookno、打开方式、数据隔离、升级迁移/备份、卸载、降级可读、无 key/原文泄漏、Gatekeeper/公证和移动签名/实机均按渠道实际通过。高级转换引擎/子进程在 iOS 不默认可执行；Mac 成功不能扩大到移动分发。发布需要用户给定范围；本规格和本轮文档不是发布动作。

## 17 测试矩阵与验收目标

### 17.1 测试语料

使用自制、公共领域或有明确测试授权的样本；记录来源、许可证和是否允许放入公开仓库。不得将用户私人书籍、购买电子书、账号数据和模型密钥提交为 fixture。测试报告可以记录样本 ID 与哈希，不必公开全文。

语料至少覆盖：横排及竖排日语、作者 ruby、送假名、英语长句、重复短语、emoji、代理对、组合字符、中英日混排；EPUB 多章节与字号变化；PDF 单栏、双栏、旋转、CropBox、连字、跨行选区、扫描混合页；漫画图片归档；大小写扩展名、损坏文件与大文件。

### 17.2 验收矩阵

| ID | 范围 | 可重复操作 | 建议通过标准 |
|---|---|---|---|
| T01 | 格式回归 | 已接入格式清单每格式至少正常与异常样本 | 保留旧demo基线；已接入原生格式阅读/导航不回归，未接入目标明确待实现；异常不崩溃 |
| T02 | EPUB 锚点 | 高亮后改字号、窗口、竖排、重启 | 固定黄金样本 100% 返回同一原文；不确定匹配明确提示 |
| T03 | PDF 锚点 | 缩放、旋转、裁切、高 DPI | 页面与引文一致；矩形误差按固定 PDF 单位阈值测试 |
| T04 | Unicode | 生成、转换、恢复所有边界 offset | 不切代理对或组合字形；quote 与 span 完全一致 |
| T05 | ruby | 选区、上下文、保存、恢复 | 假名不混入主原文；作者 ruby 不丢失 |
| T06 | 语法校验 | 错 offset、重复短语、重叠、不存在引文 | 所有无效跨度被拒绝或标 warning，无错位高亮 |
| T07 | 页翻译 | 重排后重开任务、部分失败和重试 | 结果仍对应原文快照；成功片段不重复扣请求 |
| T08 | 取消与并发 | 取消、切书、关窗、共享请求 | 不再发送排队片段；任务终态可解释，无泄漏 |
| T09 | BYOK | 不同服务 mock 与真实获准服务 | 错误分型、SSE、超时、配额与能力降级一致 |
| T10 | 安全 | 恶意 EPUB、HTML、提示注入、路径穿越 | 不获得越权文件、原生桥、秘密或任意执行能力 |
| T11 | 本地数据 | 迁移中崩溃、磁盘满、恢复旧备份 | 可恢复已提交数据；失败不损坏唯一副本 |
| T12 | Bookno 幂等 | 同批重试、乱序、断网、重复 ID、同修订异哈希、迟到回执 | 不重复建书与笔记；旧修订不覆盖；确认游标不倒退 |
| T13 | Bookno 冲突 | 两端改同笔记或封面 | 保留 Bookno 本地编辑，产生可解决冲突 |
| T14 | 封面 | 相同哈希、损坏 MIME、大图、缺字节 | 校验、去重、明确失败；书籍可保留待补封面 |
| T15 | iCloud | 双设备离线编辑、时钟错乱、账号退出 | 无静默数据丢失，不依赖墙钟最后写入 |
| T16 | 删除 | 离线旧设备重新上线与恢复 | 不误复活已删记录，不清除未确认的新记录 |
| T17 | 转换 | 每方向黄金样本、字体缺失、取消 | 输出新文件；可阅读；质量报告覆盖已知损失 |
| T18 | 三端发布 | Mac与iPhone/iPad安装、升级、卸载；已定Mac架构 | 数据隔离、签名与公证按渠道通过 |
| T19 | 可访问性 | 键盘、VoiceOver、缩放、暗色 | 核心闭环可操作；状态可感知 |

“100%”仅针对固定、可审计的黄金样本，不承诺所有现实书籍准确率。语言质量采用人工评分，单独报告翻译忠实度、语法正确性、读音和来源匹配，不以输出合法 JSON 代替语义质量。

### 17.3 性能和质量基线

**PROPOSED**：先在声明硬件与固定语料上记录导入、打开、选区提取、锚点恢复、内存和资产体积。UI 不能因解析大文档、OCR 或转换长时间阻塞；后台actor/受控任务执行；可用隔离方式须按Mac/iOS平台分别核验。具体性能阈值由 N2/N3 基线测量后设定，避免凭空承诺秒开任意大文件。

模型延迟与本地处理延迟分别统计；测试默认 mock，不消耗真实模型额度。真实服务烟测必须经授权且限制样本与预算。端到端日志使用关联 ID，不记录密钥和全文。

### 17.4 UPDF 参考界面的 PDFno 验收增量

下列为 **PROPOSED PDFno 验收目标**，不是声称 UPDF 已通过这些测试。先用不联网 mock 和自制／已授权样本走通状态，再在获准环境做真实集成。验收时记录屏幕、窗口宽度、字体、格式、模型 mock 事件与结果，不能只交付一张正常态截图。

| ID | 范围 | 操作序列 | 通过标准 |
|---|---|---|---|
| UAT01 | 应用框架 | 首页开书 → 目录跳转 → 搜索跳转 → 返回 → 切标签 | 当前文档、位置与返回栈正确；导航不触发模型请求或文件上传 |
| UAT02 | 选区到学习 | 选择带 ruby 的句子 → 点击语法 → 焦点进侧栏 → 调宽面板 | 来源原文、选区与锚点仍一致；ruby 不混入主文本；草稿不丢 |
| UAT03 | 多任务隔离 | A 书发请求 → 切到 B 书 → A 流式返回 → 再回 A | 结果只归属 A 的任务和来源；B 不显示 A 的文字或引用 |
| UAT04 | 模式切换 | 选句翻译 → 通用聊天 → 文档问答 → 返回选句 | 每个模式的来源与草稿清楚；无隐形上下文继承；切换不发请求 |
| UAT05 | 缺配置与能力 | 未配置模型、扫描页、无选区、不支持结构化输出 | 分别展示可操作的原因；不发送空请求或伪造成功结果 |
| UAT06 | AI 全状态 | mock 排队、流式、限流、认证失败、部分失败、取消 | 状态机与真实事件一致；终态可解释；不靠计时器转完成 |
| UAT07 | 重排与缩放 | EPUB 改字号／调宽，PDF 缩放／旋转；继续看旧译文 | 原请求快照与缓存键不变；能准确回原文或明确需要重绑 |
| UAT08 | 当前页与批量 | 点击当前页；另开批量范围设置；改变范围后取消 | PDF 与 EPUB 页定义明确；不默认为全书；取消前后无额外请求 |
| UAT09 | 成本与保存 | 价格未知、usage 缺失、保存失败、用户改笔记后再生成 | 如实显示未知；缓存、结果、保存分离；不覆盖用户编辑 |
| UAT10 | 窄窗口与分屏 | 双侧栏展开 → 拖窄 → 系统分屏 → 恢复宽度 | 正文仍可用；必要时切视图；输入、选区、位置和任务保持 |
| UAT11 | 键盘与 VoiceOver | 不用鼠标完成选书、切栏、提问、取消、回跳、保存 | 所有核心动作可达；焦点顺序和恢复正确；状态及引用可理解 |
| UAT12 | 引用校验 | 正确、虚构、重复、旧版本引用分别返回 | 仅校验成功引用可直接回跳；失败不绑定任意相同短语 |
| UAT13 | 工具中心 | 转换预检 → 取消；未来获准后运行单方向样本 | 不覆盖原文件；未支持功能不假装可用；输出有实际设置和质量报告 |
| UAT14 | 连接状态 | Bookno 待回执、iCloud 离线、冲突同时出现 | 各自状态独立；“本地保存”“已发送”“已确认”不混用 |
| UAT15 | 资产与隐私 | 检查界面、fixture、日志、导出和演示素材 | 不包含 UPDF 商标素材、用户桌面截图、私人原文、旧聊天或密钥 |


### 17.5 三端新增门槛与真实执行记录

| ID | 范围 | 操作/通过标准 |
| --- | --- | --- |
| T20 | 真正原生工程 | Mac application＋iPhone/iPad application构建/运行，Domain无UI依赖；CLI不充app，所有设备/SDK结果逐项报告 |
| T21 | 云文档与账号 | metadata先到/资产缺失、下载中断/hash失败/存储满、退出换账号、长离线墓碑/未知schema；不丢本地内容、不误上传旧账号 |
| T22 | 触摸/Pencil/生命周期 | 选择与手势不抢占，iPad分屏/笔画页空间/撤销重启、iPhone大字/软键盘、三端VoiceOver/后台返回；未实施Pencil则明确未支持 |

T01–T22及UAT01–UAT15是完整目标；N0 文档阶段全部原生运行 NOT-RUN，当前最小 PDFKit／Mac EPUB 切片只验证 `VALIDATION.md` 中列出的子集。不能把这些子集扩大为全部目标通过。未来每项记录测试ID/fixture hash、硬件/OS、commit/config/实际结果、失败原因与未覆盖；模拟器不代真实设备云/内存/手势测试。旧demo单元/桌面CI只能作对应历史行为证据。

语言评分区分译文忠实度、语法、日语读音和引用匹配，用授权固定语料及人工评审；performance报告本地打开/提取/定位与网络延迟分开，不承诺秒开任意大书。页/章断点恢复与取消要检查发出的实际请求计数而不是只看按钮状态。

## 18 AI 编码任务拆分与完成定义

### 18.1 实施顺序

一次推进一个可独立验证切片。任务卡明确输入证据、允许目录、依赖、实际验证、异常路径、数据副作用和回滚，不把本文所有目标视为单次实施范围。旧 A00–A15 的领域工作被下列原生任务重排，完整保留原文/Unicode、BYOK、学习、翻译、笔记、Bookno、iCloud、转换、发布的完成门槛。

| 任务 | 依赖 / 范围 | 交付与验收 |
| --- | --- | --- |
| N0 文档 | 完整原规格与当前 checkout | v0.3、官方来源、覆盖、缺口；N0 已完成 |
| N1A 工程设计/共享包 | N0，当前工作树无覆盖；最低版本决策 | `apple/` 结构、Domain 契约、schema/golden cases；旧代码可恢复备份与 Git 历史保留 |
| N1B 原生 targets | N1A，明确系统版本/工具链 | 两真实 `.app` targets、SwiftUI 原生书库/空态，Mac+iPhone/iPad Simulator smoke；不启用云/签名账号 |
| N2A PDF 打开/导航 | N1B | 原生系统导入/asset hash、PDFKit 宿主、目录/缩略图/搜索/返回；损坏/加密/无文本明确 |
| N2B PDF 锚点/批注 | N2A | Unicode/旋转/CropBox/多页多矩形、选择来源卡、repository/高亮笔记/重启；T03–T06/T11 |
| N3A EPUB 固定源码与审计 | N1B，已确认 Kookit 路线 | 固定 core/实际依赖/许可/bundle 源码和 ADR 0003；每端单独报告 |
| N3B EPUB adapter | N3A / ADR 0003 | 首片 Mac 重排/目录/ruby/选区/笔记/恢复；搜索、字号及三端完整回跳继续验收 |
| N4A BYOK | 来源契约/Keychain 设计 | URLSession/provider、endpoint/key/model、全错误/SSE/mock/取消/日志检验；T09/T10 |
| N4B 学习与读音 | N4A/N2B或N3B | 日英语法 schema/span/纠错、侧栏假名/作者 ruby；原文回跳、用户编辑保护 |
| N4C 页/章双语 | N4A、稳定 SourceSnapshot | 分段/缓存/预算/取消/部分恢复与原译文视图；T07/T08/UAT07–09 |
| N4D 文档问答 | N4A、提取/检索 ADR | 限定范围/索引状态/引用回查；正确/虚构/重复/过期来源，UAT12；真实质量另验 |
| N5 迁移 | 新 repository/schema/revision | 自制旧 JSON importer、映射/预览/幂等/中断/回滚；真实数据仅用户指定输入 |
| N6 iCloud | 数据内容/后端/身份已决定，outbox/mock通过 | 自有容器，两设备后 Mac/iPhone/iPad 离线/冲突/墓碑/账号/配额；生产配置另验 |
| N7A Bookno API | Bookno 接收侧当前代码/契约确认 | DTO/schema/cover/highlight/note、资产去重、预览/配对/回执；T12–T14 |
| N7B 漫画/其他格式 | 每个 parser 许可/设备范围 | 逐格式打开与能力/定位、RTL/大图/损坏/解包安全；无未知格式成功假象 |
| N7C 首个转换 | 方向/质量/引擎明确 | plan/output/quality，新 edition、原件不覆盖；该方向独立测试，其余未支持 |
| N7D OCR/Pencil/批量 | 相应能力与样本范围 | Vision OCR/区域映射、iPad 手写与导出、整书任务等各自验收，不相互代替 |
| N8 三端发行 | 计划发行功能全部门槛通过 | 许可源码/安装升级/签名/渠道/实机/备份报告；发布另按用户指令 |

### 18.2 UI 与扩展任务的对应

保留旧 UI01–UI07、AI01–AI03 的功能语义，改为三端原生：UI01 设计 token/屏幕与 OBSERVED 边界→N1A；UI02 阅读框架→N1B/N2A/N3B；UI03 来源/选区→N2B/N3B；UI04 模式/独立草稿/全状态→N4A/N4B；UI05 页/章双语→N4C；UI06 Bookno/iCloud/转换状态→N6/N7；UI07 键盘/VoiceOver/分屏→所有切片及 N8。AI01 文档问答→N4D，AI02 批量翻译→N7D，AI03 多文件/论文/深度研究继续仅扩展点，用户明确范围后才试验。

每个切片交付真实可用主路径、至少一种异常、合法样本说明、测试报告、未支持状态与代码证据。UI 相似度不能抵销锚点、数据与安全；没有服务/引擎支持的可点按钮不能算完成。正文、source、模式和任务独立，源书和跨书结果不得混用。

### 18.3 通用完成定义

- 本任务允许目录内实施，保护其他任务/用户改动、原书与旧源码；格式目标保留并明确每项未实现。
- 运行适当的 Swift unit/integration/UI、相关三端 build/实机检查；不可运行时给真实原因与未覆盖范围。
- 持久数据有版本、校验、迁移、备份/恢复，重复/未来版本/中断/磁盘满路径可解释。
- 无配置、空选区、无文本、损坏、取消、离线、部分完成与冲突有真实状态，无假同步/假 AI 完成。
- key/私有内容/未授权资产不进入代码、fixture、日志/导出；实际依赖/notice/source manifest 更新。
- PROPOSED 转 IMPLEMENTED/PASSED 时附提交和测试证据；编译成功不覆盖语言质量/实机或云测试。
- 报告实际文件、验证、风险/限制和回滚；没有实施的计划仍标 NOT-IMPLEMENTED。

## 19 风险登记与少数必要决策

### 19.1 风险

| 风险 | 影响 / 当前事实 | 下一步 |
| --- | --- | --- |
| EPUB 平台误判 | Readium iOS/UIKit 不等于原生 macOS；Kookit 仅已测 Mac 范围 | N3 移动实际阅读/设备测试；编译不等于阅读验收 |
| 归档/书籍脚本与消息桥 | 同源/blob/sandbox 不能独立保证安全 | 禁脚本/远程资源/授权清单/消息校验，恶意样本 |
| PDF 文本顺序/OCR | 多栏/连字/扫描会导致错误学习 | 能力降级、逐字/区域校验、OCR provenance |
| 显示改变锚点 | ruby/字体/旋转/转换错位 | 分层映射、稳定 edition、明确需重绑 |
| 三端并发/删除 | 本地计数/墙钟简单比较会丢记录 | 修订父链、共同基线、墓碑/离线 epoch |
| Bookno API 未实现 | 不能靠共享 SwiftData/CloudKit 实现独立 API | 两端契约、移动传输、配对、回执/编辑保护 |
| 云原书/大文件 | 配额、下载、两后端一致性影响体验 | 内容分级、hash manifest、暂停恢复与账号隔离 |
| 转换与移动限制 | Mac CLI/Word 保真不自动适用 iPhone/iPad | 逐引擎许可/平台审计和质量报告 |
| 密钥与实际成本 | redirect/日志/自动重试可泄漏/重复费用 | Keychain、origin 检查、预算/取消/未知请求处理 |
| 旧成果误标 | demo/CLI/绿色 CI 被误称原生阅读 | 历史证据与新测试分开，迁移 legacy provenance |
| 资源/许可/发行 | 根 AGPL不覆盖字体字典/第三方/商店条款 | 逐项来源、notice/源码与发行渠道核验 |

### 19.2 后续实施需要决定的事项

1. **系统与工程**：目标设备最低 macOS/iOS/iPadOS、Swift/Xcode、Intel Mac 范围。候选 macOS14/iOS17/iPadOS17 对应 CKSyncEngine；最终版本未定。
2. **存储/云与 EPUB 完善**：Kookit WKWebView 路线已确认；移动适配/固定版式/资源覆盖仍待验收；本地 SQLite/系统持久化；iCloud 是否传原书、封面/AI草稿/附件，CloudKit/Drive 分工。自有容器/team/签名未定，配置前确认。
3. **Bookno API**：初期单向 upsert 是否先行，是否必须跨设备、移动端怎样调用、配对/身份方案；文件交换只作测试恢复，不替最终 API。
4. **转换与扩展优先级**：首个转换方向及“可编辑/保版式”目标；OCR/手写/批量首期范围。收费/域名/渠道/发布日期后续独立决定。

以上不阻止本轮文档，也不重新询问 Swift/PDFKit/三端/AGPL/仓库位置。建议系统/引擎/后端并非用户已批准配置。无需为了文档去修改账户权限。

### 19.3 工作量

旧 v0.2 粗略估计在不重做多端的假设下提出，不能继续当本次原生三端承诺。N1/N2 后记录真实工程/锚点成本，N3 再估引擎维护与三端兼容，按获准功能和设备范围估 N4–N8。未知 API、字典、转换和云服务没有“零成本复用”保证。

## 20 原生执行提示词与下一切片

首个 N1/N2 执行范围已经用户授权并启动；其实施记录在 `NATIVE-TASKS.md`。后续可使用以下提示词，按明确范围推进，不能把完整规格当一次性全部授权：

```text
在当前 PDFno 仓库继续原生工作。先读取有效 AGENTS.md/.agents/skills、README、
v0.3 主规格、NATIVE-TASKS、VALIDATION 与 NATIVE-MIGRATION，并核验 Git 工作树。
本轮目标：[填入一个明确、可验收的切片，例如 Mac EPUB 来源、缩放与资源覆盖增强]。
使用真正 Mac/Mobile app targets 与共享 Swift 包；保持 Mac+iPhone+iPad 范围、
AGPL、PDFKit 和已选 Kookit 独立 EPUB 边界；不暗中更换引擎。开发基线暂为 macOS14/iOS17，可调整但需说明 API 与验证影响。
使用原创或明确许可 fixtures、隔离 store；不改变开发者账号、云容器或真实数据。
验证源文件/许可证、Swift 单元测试及受影响平台实际运行；记录未测范围。
既有锚点不能仅按引文模糊重绑；损坏/未来 store 不覆盖。保护并发任务和未知文件。
普通提交/推送按当前用户授权范围处理，不 force-push、不发布 release、不关机。
首个 Mac EPUB 切片后继续完善其明确范围；真实 BYOK/Keychain、Bookno/iCloud/转换与签名分发各需独立范围。
```

## 21 来源、核验日期与证据限制

### 21.1 2026-10-02 官方 Apple 技术来源

本轮读取 Apple DocC 官方内容与 availability：PDFView/PDFSelection/PDFPage 三端 API、SwiftUI wrappers、CKSyncEngine、CKAsset/private database、文件协调/fileImporter、Keychain、Vision 与 PencilKit。普通网页需 JS，已读取同域官方 DocC JSON 的内容和 metadata，不把网页空壳当技术证据。

| 来源 | 支持的事实 | 本文设计/尚未验证部分 |
| --- | --- | --- |
| [PDFView](https://developer.apple.com/documentation/pdfkit/pdfview)、[PDFSelection](https://developer.apple.com/documentation/pdfkit/pdfselection)、[PDFPage](https://developer.apple.com/documentation/pdfkit/pdfpage) | macOS/iOS/iPadOS 框架存在，显示/选择/页操作 | 本 reader、Unicode/多栏/精确批注待实测 |
| [NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable)、[UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable) | AppKit/UIKit 视图纳入 SwiftUI | lifecycle/焦点/选区宿主未实现 |
| [CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5)、[CKAsset](https://developer.apple.com/documentation/cloudkit/ckasset)、[privateCloudDatabase](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase) | 记录同步/关联文件/私有数据库；CKSyncEngine macOS14/iOS17/iPadOS17 | 容器/领域冲突/实际配额/三端同步未配置验证 |
| [NSFileCoordinator](https://developer.apple.com/documentation/foundation/nsfilecoordinator)、[ubiquity container URL](https://developer.apple.com/documentation/foundation/filemanager/url(forubiquitycontaineridentifier:))、[fileImporter](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:)) | 系统文件导入/协调/iCloud container API | 受管理 asset/文档包同步与权限恢复未实现 |
| [Keychain services](https://developer.apple.com/documentation/security/keychain-services) | 平台秘密小数据安全存储 | 具体 service/group/accessibility、三端 policy 待实现 |
| [VNRecognizeTextRequest](https://developer.apple.com/documentation/vision/vnrecognizetextrequest) | macOS/iOS/iPadOS 文本识别 API | 日文实际语言/质量、竖排/漫画/精确映射待测 |
| [PKCanvasView](https://developer.apple.com/documentation/pencilkit/pkcanvasview) | iOS/iPadOS 的 Pencil 输入 canvas；该 API 无原生 macOS availability | iPad 页面 overlay/坐标/同步/导出需实现，Mac 用通用墨迹投影 |

### 21.2 EPUB 官方源码与标准

固定提交/根许可证/README 已在第 5.2 章逐项引用并读取。Readium 3.11.0 iOS-only/UIKit 的结论来自固定 Package.swift；foliate/epub.js 的 browser support 与 scripted-content 边界来自固定 README，这些独立候选仍未在 Apple WKWebView 运行。Kookit core 与 extra 的修正来自官方固定源码与架构说明；Kookit 限定 Mac 实测见 ADR 0003 / VALIDATION。

格式参考 [W3C EPUB 3.3](https://www.w3.org/TR/epub-33/) 与引擎实际 locator 实现；标准不是 parser 能力保证。根许可证只核验根文本，完整实际 transitive dependencies、字典/字体/fixture、对应产物与发行路径待 N3/N7 清单审计。此句描述 N0 静态阶段；2026-10-03 Kookit 的源码构建、实际许可、Mac WebKit 与 UI 证据见 ADR 0003 / VALIDATION，不能扩大到全部候选或移动阅读。

### 21.3 继承的项目参考（未重新运行）

保留原稿指向固定快照的引用：

- JapaneseLearningApp 分析（私人原稿参考，公开版不披露 URL）、OCR（私人原稿参考，公开版不披露 URL）：原文回查/仅文本 OCR。
- NihongoFlow 跨度（私人原稿参考，公开版不披露 URL）、复习（私人原稿参考，公开版不披露 URL）：Unicode/调度思路。
- Bookno 基线（私人原稿参考，公开版不披露 URL）、共享持久化（私人原稿参考，公开版不披露 URL）、Mac 入口（私人原稿参考，公开版不披露 URL）、Mac 说明（私人原稿参考，公开版不披露 URL）：原稿的 importer/字段依据。
- [Koodo 固定架构](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/CLAUDE.md)、[LICENSE](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/LICENSE)、[AI 设置](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/src/containers/settings/aiSetting/component.tsx)、[请求](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/src/utils/request/common.ts)、[笔记](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/src/utils/reader/noteUtil.ts)、[选区](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/src/utils/reader/mouseEvent.ts)、[package](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/package.json)：保留旧研究线索，不作为主依赖。

上述私人参考保留功能依据，公开版移除私有 URL；未改变可见性、未下载/复制私有源码，不宣称其 API/模型质量/Pro/跨设备通过。

### 21.4 UPDF 脱敏观察

原观察日期 2026-10-01，本机 UPDF 2.5.7（1371），自制两页英日 PDF。原报告 `UPDF桌面考察报告.txt` 已读取，仅保留第 14 章结构/菜单/操作/状态描述；不附用户桌面截图，不复制图标/Logo/品牌球或私人资源。目录跳页和普通搜索实测，选字浮层/AI/Word 转换配置多为可见入口，未提交 AI、转换、OCR、批注写入、云同步或付费动作。

剩余 AI 次数 0 与未提交限制意味着无法评价模型质量、译文保版式、真实费用/用时、取消重试、引用或转换质量。旧聊天不是新生成证据，macOS 文件面板里的 iCloud Drive 不是应用同步证明。未测 EPUB/竖排/ruby/假名/语法/窄窗/触控；本规格这些方案均 PROPOSED。Bookno token 未读，具体品牌 token 待核验。

## 22 原 v0.2 完整需求覆盖核对

### 22.1 按原章节逐项核对

完整原稿已读，不只依据标题/摘要。以下保留的是功能/约束与验证语义；被用户撤回的架构按明确新决定替换，非删产品目标。

| 原章节 | 原内容/关键子项 | v0.3 对应与处理 |
| --- | --- | --- |
| 0、0.1–0.3 | 状态/优先级/版本/只文档 | 0；增加证据快照、原稿 hash、原生决定，移除默认 fork |
| 1、R01–R14 | 产品/BYOK/翻译/语言/笔记/Bookno/云/转换/UI/决策 | 1 全部保留；R02 架构修正、R13 三端已定；增 R15–R17 |
| 2.1 | Koodo/AI/选区/打包/许可疑点 | 2.2、5.2、21；保留参考，修正 public core 与 extra，不默认依赖 |
| 2.2 | 两个学习项目/span/OCR/复习/许可 | 2.3、10、21.3；行为参考，非移动端 Python/Web 架构 |
| 2.3 | Bookno模型/导入/封面/稳定ID/云边界 | 2.3、6、11、12；继承快照不冒充现成 API |
| 3.1–3.2 | 阶段/后续能力/MVP不等全部 | 3、18、19；保留 OCR/漫画/全文/转换/复习，三端不再未定 |
| 4.1–4.3 | 模块、IPC、文件/提示注入/日志 | 4；主架构重写为 app targets/Swift packages/原生权限，Web reader 受限桥 |
| 5 | 各格式/能力/无文本/受限降级 | 5.1–5.3；补全格式库存、EPUB审计/阶段/三端真实缺口 |
| 6.1–6.3 | Book/Edition/Asset/Note/Analysis字段、ID、备份、封面 | 6；Swift语义、修订父链/批注模型、cover所有约束保留 |
| 7.1–7.3 | anchor/locator/Unicode/ruby/规范化/恢复 | 7；保留全部关键字段/状态，多页/PDFKit/Swift单位明确 |
| 8.1–8.4 | 页定义、分段/cacheKey、并发/取消/成本/隐私 | 8；保留语义、加整章双语/问答、Swift取消与后台恢复 |
| 9 | endpoint/key/model、能力、redirect/错误 | 9；Swift/URLSession/三端Keychain，全部安全规则保留 |
| 10.1–10.3 | 本地读音、作者ruby、语法schema/span、保存/再分析 | 10；保留原文验证/重复/重叠/用户修正，原生词典候选待定 |
| 11.1–11.6 | API、字段/JSON、幂等/乱序/冲突/回执/传输 | 11 完整保留并补高亮/移动传输/封面去重；API独立于store |
| 12.1–12.4 | 云与Bookno分开、Drive/CloudKit、变更、墓碑/迁移 | 12；三端、文档资产/容器/后台/冲突方案完整重写 |
| 13 | DOCX↔PDF↔EPUB方向/预检/质量/不覆盖 | 13；全方向保留，补原生移动约束/OCR引擎差异 |
| 14.1–14.3 | 品牌、九核心屏幕、键盘/VoiceOver/多窗 | 14；原生三端自适应，token未猜 |
| 14.4、U01–U13 | UPDF入口/实测/未测/估值 | 14.4 原观察表保留；21.4完整限制，无私有资源 |
| 14.5、S01–S08 | 组件/三栏/断点/状态保持 | 14.5＋14.11；Mac/iPad/iPhone分别实现 |
| 14.6、J01–J08 | 操作闭环/范围/配置/连接 | 14.6；保留全部，页/章分别操作，原生统一action |
| 14.7 | 10种AI模式/范围与扩展点 | 14.7；问答/章节确认为目标，通用/多文件/研究范围仍受控 |
| 14.8–14.10 | mode/source/task/save状态、事件、选区、视觉/无障碍 | 14.8–14.11；保留每事件不变量，原生选择不依赖DOM |
| 15.1–15.2 | 只读迁移/旧locators/数据隔离/回归 | 15；保留成果/旧JSON、重写fork维护为adapter/version审计，补回滚 |
| 16 | 构建、身份/签名/许可/渠道/安装升级 | 16；三端Xcode与共享包取代Electron主构建，旧CI保持历史 |
| 17.1–17.4 | 语料、T01–T19、性能/质量、UAT01–15 | 17 保留全部 IDs/不变量，增T20–T22与三端实机 |
| 18、18.1–18.2 | A00–A15、UI01–07、AI01–03及完成定义 | 18 N任务重排全部能力，18.2 显式旧UI/AI映射，不丢未实现目标 |
| 19.1–19.3 | 风险、6项旧问、工期限制 | 19；解除路线/三端/仓库已定问题，只列必要系统/引擎/云/API/转换 |
| 20 | 首次AI只读P0提示 | 20 改为明确切片的原生执行提示；临时最低版本和实施授权按最新任务记录 |
| 21.1–21.5 | 固定项目/Bookno/UPDF证据与限制 | 21；保留历史链接并标未重验，增官方Apple/EPUB当前核验 |

### 22.2 核对结论与实施状态

原 R01–R14 均有去向，原 T01–T19、U01–U13、S01–S08、J01–J08、UAT01–UAT15 全部保留标识和行为要求；新增三端构建/同步/Pencil 验收。没有把 Koodo/Electron、CLI-only 原生或“是否要 iOS”留为主架构必选。多格式目标保留；当前已实现限定 PDF／Mac EPUB 子集，其余能力继续分阶段；未把旧 demo 或官方框架支持当功能完成。

AI 缓存/取消/保密、Unicode/ruby、Bookno两层重放/修订/回执、本地编辑/封面保护、云离线/墓碑、转换全部方向、UPDF观察限制与自有品牌均继续有效。既有 v0.2 的 TypeScript 类型不是新 app 代码，领域与provider草案已换 Swift语义；外部JSON仍是传输格式。

## 23 N0 文档阶段验证与交付记录（历史）

本节是先文档阶段的历史证据；原生实施、清理和提交状态见当前 `VALIDATION.md` / `NATIVE-MIGRATION.md`，以下历史边界不限制后来已授权工作。日期：2026-10-02。N0 检查当前仓库及祖先 `AGENTS.md`、checkout `.agents/skills` / `.codex`：没有发现适用文件或本地技能目录。常用 Codex memory_summary 路径及可见目录未发现该文件；没有读其他私有记忆数据库，没有修改记忆。

| 检查 | 实际结果 |
| --- | --- |
| 原稿完整性 | 1050 行/94484 字节；内部v0.2、Library version1；原稿SHA-256见0.3；1–1050行完整读取 |
| Git/文档 | 起始HEAD2c40a8f；既有原生规划保留；起始仅Xcode workspace未跟踪元数据 |
| 工程产品类型 | PDFnoBridge=`com.apple.product-type.tool`、macOS SDK、CLI最低13.0；无新阅读app工程 |
| 源码静态核验 | demo-text-1/content fingerprint、mockProvider、notes-v1路径与现有架构相符 |
| 官方来源 | Apple DocC内容/availability与EPUB固定源码/根license读取；未构建候选 |
| 需求与冲突 | 第22章逐原章节覆盖，正文替换旧主架构；保留全部已有需求/验收与未测限制 |
| 文档静态校验 | 24章顺序/代码围栏/JSON示例解析通过；原R/T/U/S/J/UAT共77项编号覆盖；17项格式库存与7个原具体转换行保留；未发现旧路线必选指令 |
| 原生/语言/云/转换测试 | NOT-RUN，本轮未改实现；旧绿色CI不作为这些测试证据 |
| 源码/账号/元数据 | 本轮只新增v0.3文档，未改/删除旧源码/工程/依赖/配置，未提交/推送 |

其他任务状态不能从旧线程放置方式推出；本轮不假定已停止，不杀进程。私人 Library 已使用版本 guard 替换原项，保留身份和历史；公开副本不披露内部 ID。最终交付时再核验实际工作树，发现并发变化须如实报告，不归为本任务改动。
