> 这是 N0 文档阶段的设计快照，下面的“本轮只文档/旧源码保留”描述该历史阶段。最新明确授权和实际实现已由 [v0.3 主规格](PDFno_AI_Development_Spec_v0.3_Native.md)、[任务状态](NATIVE-TASKS.md) 与 [迁移记录](NATIVE-MIGRATION.md) 接续；临时开发最低版本为 macOS14/iOS17。历史状态不作为当前执行限制。

# PDFno 原生 Apple 应用实施与迁移计划

日期：2026-10-02
状态：**文档已规划；除明确的用户路线决定外，目录、模型、系统版本、阶段及验收方案均为建议，尚未实现。**

本计划补充现有内部 v0.2 开发规格，不覆盖或公开该私人原件。涉及技术路线的冲突以[ADR 0002](ADR-0002-NATIVE-APPLE.md)中的最新用户决定为准。

## 1 当前状态与本轮范围

当前可运行的是 React/Electron 自制文本 demo 与 macOS `PDFnoBridge` 命令行工具。它们不是原生 GUI 应用，也没有真实 PDF/EPUB 阅读、真实 AI、Keychain、Bookno、iCloud 或转换能力。

保留 `src/`、`electron/`、`shared/`、`tests/`、`native/`、现有依赖及运行方式。旧路线停止新增功能；必要的数据保护或回归修复可以另行界定。现有 `native/PDFno.xcworkspace` 仍仅对应 CLI，不更名、不替换。Xcode 自动生成的本地 workspace 元数据保留原样，不作为产品实现或新配置提交。

本轮只更新文档和来源说明。后续另开明确的原生实现切片，才创建应用 targets、依赖与测试。不注册新 bundle ID、CloudKit container、证书或 token，不迁移真实数据，不上传原书，不发起付费模型请求。

## 2 产品目标保留与格式安排

| 目标 | 原生路线安排 | 当前状态 / 后续门槛 |
| --- | --- | --- |
| Mac 优先，长期三端 | 原生 macOS；一个支持 iPhone/iPad 的移动应用 target；共享领域与服务 | 已决定方向；新 targets 未创建 |
| PDF | PDFKit adapter；展示、目录、搜索、选择、批注与精确来源 | 已选框架；真实阅读/锚点未实现 |
| EPUB | 独立 adapter；重排、作者 ruby、CFI/资源位置、逻辑页快照 | 候选静态核验完成；最终引擎与三端实测待完成 |
| 漫画与其他格式 | 独立格式能力注册；优先评估系统图像能力与合法解析器 | 保留 CBZ/CBR/CBT/CB7、MOBI/AZW3/AZW、TXT/FB2/MD/DOCX、HTML/XML/XHTML/MHTML/HTM 目标；逐项待实现，不宣称 PDFKit 原生支持 |
| 学习与 BYOK | 原生学习栏、服务设置、Keychain、受控 provider 与任务服务 | 保留自定义 endpoint/key/model、选句学习、日语假名与日英语言辅助；真实服务待实现 |
| 整页翻译 | PDF 物理页；EPUB 当前布局可见范围的不可变快照；分段、进度、取消与失败恢复 | 不默认扩展为全书；质量和成本另验收 |
| 高亮/笔记/回跳 | 公共版本化来源 + 各格式 locator；本地可靠保存、备份、冲突保护 | demo 行为可参考；原生实现与旧数据 importer 待完成 |
| Bookno | 书籍、封面、笔记的版本化交换；预览、幂等、冲突、回执 | 不直接写 Bookno 数据库/CloudKit，不假设现成 API |
| iCloud | PDFno 自有同步 adapter；三端共用记录契约 | metadata/笔记/进度优先的建议；原书、封面范围待决定 |
| 转换与 OCR | 受控服务/隔离任务；每种方向独立引擎、质量样本和许可 | 保留 PDF/Word/EPUB 转换目标；不承诺任意互转/无损，不作为 PDFKit 附带功能 |
| 开源与视觉 | AGPL-3.0-or-later；原生自有资产，沿用阅读/导航/学习的信息组织目标 | 不复制 UPDF、Koodo 品牌或私有 Bookno 素材；三端可访问性需实测 |

PDFKit 仅解决 PDF 模块。格式清单是需求库存，不是当前可运行能力；任何新增格式必须有合法 fixture、运行证据、选择/锚点策略和异常行为。

## 3 真正的 Xcode 工程与共享模块

建议在同一仓库新增 `apple/`，保留历史 `native/`。以下是未来文件布局，**本轮没有创建这些路径**：

```text
apple/
  PDFno.xcworkspace
  PDFno.xcodeproj
  Apps/
    Mac/                  # SwiftUI App + AppKit 宿主，产物 PDFnoMac.app
    Mobile/               # SwiftUI App + UIKit 宿主，产物 PDFnoMobile.app
  Packages/PDFnoCore/
    Sources/
      Domain/             # 稳定 ID、来源、书籍、笔记、任务与冲突模型
      Storage/            # 版本化本地 repository、备份与迁移
      Services/           # 学习、provider、交换、同步协调
      ReaderPDFKit/       # PDF 原文、页面、选择、几何与回跳
      ReaderEPUB/         # 引擎门面；依赖选型后才接入
      PlatformSecurity/   # Keychain、文件授权与原生资源边界
    Tests/
  Tests/MacUITests/
  Tests/MobileUITests/
  Fixtures/               # 自制/可分发资源及逐文件来源说明
```

工程采用两个真实应用 targets：`PDFnoMac`（macOS application）和 `PDFnoMobile`（iOS application，支持 iPhone 与 iPad）；共享 scheme、单元测试和独立 UI 测试 targets。不是把 CLI 改显示名，也不是 SwiftUI 窗口嵌入整个 Electron demo。共享 package 内的模块必须明确依赖方向，AppKit/UIKit 类型留在平台宿主，不渗入通用领域模型。

SwiftUI 承载主界面；Mac 的 PDFView 使用 NSViewRepresentable，移动端使用 UIViewRepresentable。ReaderAdapter 统一描述打开/关闭、能力、目录、搜索、选区、页快照、定位与批注；返回版本化 DTO，不让学习服务依赖 PDFView/WKWebView 的私有对象。PDFKit 与 WKWebView UI 工作按平台主线程要求执行；大文件哈希、数据库和转换安排可取消的后台任务，不任意把非 Sendable 框架对象跨 actor 传递。

建议最低系统版本先按 **macOS 14 / iOS 与 iPadOS 17** 评估：Apple 官方 CKSyncEngine 可用性从这些版本开始。最终版本需结合用户设备、已选 EPUB 引擎和实际构建验证决定；当前 CLI 的 macOS 13 最低版本不是新应用决策。[CKSyncEngine](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5)。

将实际依赖固定在 Package.resolved 或引擎 source manifest，并更新分发声明。只有原生实现阶段才加入 CI：共享模块测试、Mac 应用构建、iPhone/iPad Simulator 构建与 UI smoke；设备签名与发行流程另设门槛。现有 npm CI 继续验证历史 demo，不能替代新应用验证。

## 4 三端界面和文件流程

| 设备 | 建议布局与交互 | 必须验收 |
| --- | --- | --- |
| Mac | 书库/阅读窗口、文档标签、可收起导航和学习栏；菜单命令、快捷键、鼠标选区 | 多窗口书籍权限、窄窗/全屏、键盘与 VoiceOver；拖入文件也走同一导入预检 |
| iPad | 宽屏分栏，紧凑宽度改为单正文 + 可返回学习视图；触摸与外接键盘 | 横竖屏、系统分屏/窗口缩放、选区与任务保持；触控栏不遮挡正文 |
| iPhone | 单列 NavigationStack；目录与学习使用 sheet/独立页面；底部操作适配安全区 | 小屏、Dynamic Type、VoiceOver、旋转与后台恢复；返回正文保持来源 |

共享的是状态和行为，不强制共享所有视图布局。面板切换、设备旋转和焦点变化不能重发模型请求、丢草稿或改变来源快照。每本书、每个学习模式与任务使用独立身份；切书和窗口关闭有明确取消/保留规则。多窗口保存需要 repository 修订检查。

各端经原生文件选择/受控拖入导入；后续 Share Extension 若要支持属于单独扩展任务。读取用户选定 URL 时使用适用的 security-scoped access，并在完成后结束访问；bookmark 只代表本设备授权，不是跨设备可用书籍路径。默认建议导入 PDFno 私有、按内容哈希管理的书库副本，保存来源元数据、不覆盖原文件；是否保留外部引用需另定长期权限与文件变更规则。[Apple 文件导入](https://developer.apple.com/documentation/swiftui/view/fileimporter(ispresented:allowedcontenttypes:allowsmultipleselection:oncompletion:))。

导入预检检查可读性、类型内容、大小、加密/受限状态和重复指纹。解析损坏、取消、存储不足、符号链接与 EPUB 归档炸弹均保留原文件并给出可操作错误。PDF 批注写回只面向显式保存/导出副本；语言学习记录先存应用 repository，不悄悄改变用户原 PDF。

## 5 PDF/EPUB 来源、学习和凭据

公共来源模型建议使用版本化 envelope：书籍/版本稳定 ID、真实源文件 SHA-256、提取器与版本、原文及前后文、Unicode offset 单位、格式 locator、来源校验状态。不是直接照搬 demo 的类型签名。

PDF locator 保存物理页索引、页面盒/旋转信息、PDF 页面坐标中的多个矩形和原文范围；不存窗口像素作为永久锚点。先测 PDFKit 选择与坐标转换，再支持缩放、旋转、跨行/跨页恢复；分栏、扫描页和混合页根据文本置信度降级。扫描页仍可阅读，但不能凭空显示“已提取正文”；OCR 后来源含 OCR 版本与区域，不能混充原生文本。

EPUB locator 保存 canonical 资源路径、spine 身份、引擎 ID/版本、经过验证的 locator/CFI、原文和上下文。逻辑页编号不作为稳定身份；重排后保留请求时的范围与布局快照，并重新校验回跳。跨引擎/跨版本找不到位置就显示旧引文和需重绑状态，不匹配到任意重复句。

领域文本继续明确使用 Unicode code point 范围；Swift String 的字符索引、NSString/PDFKit 常见 UTF-16 范围及 JavaScript DOM UTF-16 offset 分别映射并验证边界，不用 `String.count` 代替。保留作者 ruby，提取正文时 rt/rp 不混入主文；不以 normalize/trim 或删除假名来“修正”来源。把已有测试迁成同一批 golden cases，再补真实 PDF/EPUB 样本。

学习服务保留不可变请求快照、provider/schema 版本、任务 ID、取消、限流、部分完成与错误状态；保存结果和用户编辑分开，引用在回跳前校验。无配置、扫描页、空选区和不支持能力都有明确原因。真实质量验收单独评估译文、读音和语法，不能以合法 JSON 或 mock 成功代替。

BYOK 继续允许 endpoint/key/model；非敏感配置与 Keychain 中的密钥引用分开。默认密钥仅本设备保存；不同平台的 Keychain 服务/access group 在实现阶段核验，不把“使用相同 Apple ID”写成密钥已同步。EPUB 消息桥、书籍文本、日志、备份、Bookno 和 CloudKit 记录都拿不到 key。网络请求由原生受控 provider 发起，只发送用户确认的来源范围；连接测试和付费烟测另有样本/预算批准。

## 6 iCloud 记录、资产和冲突计划

建议以 PDFno 自有 **CloudKit private database + CKSyncEngine** 为候选同步路径；本地版本化 repository 是离线可用的真值入口，同步按记录与不可变资产处理，不把正在使用的 SQLite/JSON 文件放进 iCloud Drive。这个选型仍是建议，当前未创建 container 或 entitlements。[private database](https://developer.apple.com/documentation/cloudkit/ckcontainer/privateclouddatabase)、[CKSyncEngine 状态持久化](https://developer.apple.com/documentation/cloudkit/cksyncengine-5sie5/state-swift.class)。

本地存储建议先比较 versioned SQLite repository 与系统持久化方案，再固定为存储 ADR；领域模型不绑 SwiftData 自动同步。若改用 SwiftData/Core Data 的系统镜像，需重新说明谁管理 CloudKit zones、迁移和冲突；不能让系统镜像与自写 CKSyncEngine 同时管理同一组记录。现有 JSON 是迁移源而非直接云端数据库。

| 数据类别 | 建议处理 | 尚待确认 |
| --- | --- | --- |
| 书籍元数据/阅读进度/笔记/学习附注 | 稳定 ID、schema/revision、来源指纹及墓碑；三端按记录同步 | 是否同步所有 AI 附注、草稿和进度冲突呈现 |
| 封面与原书 | 不可变 asset manifest + 内容 hash；记录与资产状态分离，下载后校验 | 封面默认范围、是否同步原书、大小/配额/Wi-Fi策略；原书不默认上传 |
| Keychain/API key | 不进入 CloudKit 数据 schema 或普通备份 | 如以后要求凭据跨设备，另审 Keychain 同步/access group |
| 临时缓存/运行任务 | 可重建索引和设备布局留本机；运行中任务不当作跨设备可继续请求 | 已完成结果的同步与敏感内容策略 |

CKAsset 是记录关联文件的候选机制，需测试大小、配额、重试和下载失败；不是全书同步的自动许可。[CKAsset](https://developer.apple.com/documentation/cloudkit/ckasset)。不同设备各自拥有下载缓存与文件授权，绝不同步 security-scoped bookmark、绝对路径或运行中的数据库。

每次本地变更先原子保存，再写 outbox；CKSyncEngine 的序列化状态单独持久化并在重启时恢复。同步通知与后台调度不是即时保证，前台展示“本地已保存 / 等待同步 / 已发送 / 云端确认 / 其他设备未下载 / 冲突”各自状态。请求去重与重试不能制造重复笔记；账号退出/切换隔离本地空间和队列，不把旧账号数据上传到新账号。

笔记并发编辑采用共同基线与修订关系识别冲突，不能只按设备时钟后写覆盖；无法自动合并时保留双方版本供用户处理。删除用墓碑与恢复窗口，资产回收等待确认和引用检查。原书/版本变更保留旧锚点；设备尚无文件时先显示记录和引文，定位能力明确不可用。

实施顺序：确定数据/设备范围 → 本地 store/outbox 与 mock 冲突恢复 → 批准并配置 PDFno 自有容器与能力 → 开发环境两台真实设备测试 → Mac/iPhone/iPad 三端测试 → 分别确认 production schema 与发行构建。不能复用 Bookno 的容器或因本计划擅自申请账户权限。

## 7 旧成果与数据迁移

| 现有成果 | 后续处理 |
| --- | --- |
| React/Electron UI、样本与 IPC | 保留可运行参考。原生重做宿主与权限边界，不翻译 JSX 成 SwiftUI，不把 Electron 的 sender 校验当成原生保护 |
| anchors/tasks/provider 领域行为 | 用 golden fixture 验证 Swift 的对应实现；保留偏移单位、任务隔离、来源快照和失败语义 |
| `notes-v1.json` 与 backup | 原生 importer 只读预检，验证 schema/版本/ID/修订/引文，展示导入预览后写入新的独立 store；不改写源文件 |
| Browser demo localStorage | 不能直接从原生读取所有浏览器空间；未来增加用户发起的版本化导出再导入。当前没有该导出功能 |
| `PDFnoBridge` CLI / workspace | 保留构建与能力协议的历史验证。新 App 中服务在进程内重建，不强制让 iPhone 执行 CLI |
| 既有 README、CI、测试和授权记录 | 历史证据保留。新原生测试另行增加；不把旧 passed 状态转为新应用 passed |

特别处理旧笔记中的 `extractionVersion: demo-text-1`：其 `sourceFileSha256` 实际是 demo canonical 内容指纹，不是 PDF/EPUB 文件字节哈希。导入后保留 `legacy-demo` 来源及原 ID 映射；可以展示原有自制样本或显示需重绑，不能悄悄映射到真实书籍、捏造 PDF 页坐标或 EPUB CFI。mock 的 `aiText` 继续标记为 mock，不能迁移成真实模型生成证据。

迁移步骤建议：

1. 记录旧应用最后可运行 commit、环境与 fixture；原始数据库/JSON/backup 做只读备份并核验 hash。
2. 新应用使用独立的应用数据目录、store schema 与 bundle 身份，确认没有指向旧 store 或 Bookno 内部库。
3. 用自制旧数据测试预检、合法/损坏/未来版本拒绝、重复批次幂等、冲突保护、取消和中断恢复。
4. 用户选择迁移文件，先预览数量、来源类型、保留/冲突/需重绑项；真实迁移须有明确操作授权。
5. 原子导入新 store，记录 source digest 与 item 映射/receipt；比较 ID、引文、用户文字、mock 标识和修订，重启验收后报告。
6. 回滚只切回保留的旧应用/旧 store；新库另行导出备份。不开双写，不在未设计双向协议时合并两套并发编辑。
7. 原生核心验收和用户确认后再决定归档旧代码；当前不删除、不移动旧代码，也不把迁移完成写成应用已发布。

Bookno 单独走 versioned exchange/importer；metadata/cover/note、来源 hash、外部 ID、冲突与确认回执均在契约内。用户私人源码或另一应用的 CloudKit、数据库和同步身份不成为捷径。

## 8 实施任务与验收门槛

以下不是本轮执行命令；每张卡须在实现前明确允许目录、fixture、数据副作用、验证和回滚。

| 阶段 | 依赖与交付 | 完成标准 |
| --- | --- | --- |
| A0 文档路线 | ADR 0002、原生计划、EPUB 静态审计、历史记录纠正 | 本轮交付；仅文档变更，未宣称新能力 |
| A1 原生工程 | 新增 apple 目录、两个 `.app` targets、共享 domain、原生书库/空态 | Mac 与 iPhone/iPad Simulator 构建；独立运行窗口；无证书/云能力暗改；旧 demo 可保留运行 |
| A2 本地 PDF 切片 | A1；原生导入、PDFKit、目录/搜索/选择/返回、本地笔记 | 自制文本/扫描/旋转/损坏/受限 PDF；页坐标、Unicode、选区保持、保存重启与拒绝路径；三端宿主验证 |
| A3 EPUB 选型试验 | A1；批准限范围试验、候选来源清单；不影响 A2 的 PDFKit | 按 EPUB 审计矩阵比较三端结果；选型 ADR 后才安装正式依赖/实现 adapter |
| A4 原生学习闭环 | A2/A3 来源与锚点可靠；Keychain/service 契约 | 先 mock 验证草稿/隔离/取消/失败；真实 BYOK 及质量试验另获服务/预算授权；不上传全书 |
| A5 迁移与恢复 | 新 store/versioning 就绪 | 自制旧 JSON/browser 导出样本、幂等/冲突/损坏/中断/回滚通过；真实导入单独确认 |
| A6 iCloud | 设备/数据/账号范围明确，store/outbox 就绪 | mock 冲突恢复后，获云能力批准；两设备再三端实测离线编辑、删除恢复、账号切换、配额/资产失败 |
| A7 Bookno / 转换 | 各自契约/引擎/许可/质量范围批准 | 独立完成接收预览/回执或某一转换方向；其他功能继续明示未支持 |
| A8 三端发布准备 | 原生核心、数据恢复、许可和设备验收通过 | 源码/notice、签名/渠道/隐私/升级审查。AGPL 保持；各发行条款需单独核验，不预设 App Store 自动可发布 |

每个阅读/学习切片至少交付主路径、异常路径、合法样本说明、测试实际结果和未覆盖项。Mac 构建成功不代表 iPhone/iPad 实机通过；Simulator 通过不代替 PDF 手势、后台、内存、VoiceOver 和 iCloud 的真实设备验证。

## 9 保持开放的决定

EPUB 引擎/单引擎或双引擎、最终最低系统版本、本地持久化方案、iCloud 原书/封面/草稿范围、Bookno 第一种传输方式、首个转换方向和发行渠道保持开放。可以先按 A1/A2 的独立范围推进未来实现；本轮按用户要求停在文档交付，不据建议自动启用这些能力。
