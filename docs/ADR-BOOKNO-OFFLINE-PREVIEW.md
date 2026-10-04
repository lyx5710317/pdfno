# ADR: PDFno → Bookno 离线交换预览首片

状态：**PROPOSED 契约／已实现本地预览与 mock；待 Bookno 接入确认**。日期：2026-10-04。

基线为已通过 22 项 Mac UI 的 `8cf6ab8e93e057aa73a6607a17e6e2fe42269315`；该 UI 证据来自交接，本片没有重新运行 UI。主规格第 11 章仍是权威需求；这里实现一份有明确 preview 标识的候选契约，不把规格的说明 JSON 或本片 DTO 声称为已发布 API。

## 只读接收端证据

找到用户的 Bookno 源码 checkout，读取以下跟踪源文件；这些文件相对 `HEAD = 682b9642b7211a0f8d43613a5ed8234dc3c7eb0b` 无工作区差异。没有读取数据库、真实凭据、用户笔记或 app support；没有修改 Bookno。

| 源文件 | 可复用事实与缺口 |
|---|---|
| `BooknoShared/Models/Book.swift` | `coverData` 可保存封面；`syncIdentity` 是备份恢复可重建的物理副本身份，不能充当 PDFno 外部 ID |
| `BooknoShared/Models/BookSource.swift` | 已有 `externalBookID` 与来源关系；尚无本候选的 epoch、revision、哈希基线和完整 locator 字段 |
| `BooknoShared/Models/ReadingNote.swift` | 已有 `externalNoteID`、`importedContentHash`、`highlightText`、`userComment`、位置标签；尚无完整版本化 PDF/EPUB source payload |
| `BooknoShared/Library/ParsedImport.swift` | `ParsedBook` 包含书籍外部 ID、封面字节；`ParsedNote` 包含外部 ID、引文、用户正文、页码等 |
| `BooknoShared/Import/KindleImportIdentity.swift` | 按远端 ID 匹配；通过导入快照保护本地编辑；其模糊内容匹配会 NFC/压空白，本片的稳定 ID/锚点/哈希不能走该模糊路径 |
| `BooknoShared/Import/ImportPreviewCoordinator.swift` | 已有 parser→matching→重复/冲突预览管线，可供未来接入 |
| `BooknoMac/Services/MacImportCommitService.swift` | 保存时重新检查本地冲突；新建书籍可保存封面，已有书籍只补缺 metadata/cover，不是本候选的三方 upsert 实现 |
| `BooknoShared/Models/ReadingSourceType.swift` | 有 pdf/epub 来源，无独立 pdfno namespace/capability 协商实现 |

在检查到的模型、导入服务及跟踪文件清单中未发现 PDFno 接收接口或此交换协议的 API 文档。**真实端点、认证方式、移动端 handoff 均未核验或实现，待 Bookno 侧接入**。不从已有 WeRead 等外部客户端推断 Bookno 有入站服务，也不借用其 CloudKit 容器。

## 契约与身份

`BooknoExchange.swift` 是仅依赖 Foundation 的 DTO。批次固定 `protocolName=pdfno-bookno-exchange-preview`、`schemaVersion=1`、`sourceNamespace=pdfno`、`mode=preview`。它与未来经双方批准的生产版本分隔。

| 对象 | 约定 |
|---|---|
| 书籍 | `pdfno:book:<format>:<book UUID lowercase>`；格式命名空间防止独立 native stores 的 UUID 碰撞。书名、edition、文件哈希、安装实例不改变既有 ID |
| 高亮/笔记 | `pdfno:note:<format>:<highlight or learning>:<note UUID lowercase>`；高亮与学习记录分开，不按标题/引文去重 |
| 原书版本 | 单独携带 edition UUID、格式、原书 SHA-256；哈希不是作品 ID，也不包含原书字节/路径/文件名 |
| 封面 | `sha256:<image SHA-256>`；MIME、字节数、宽高、origin 与 native 封面 revision 独立保存；同封面可被多个不同书籍引用 |
| 高亮 | 显式 `annotationKind=highlight`，引文、用户正文、来源分字段；空白/空正文有效。当前 native store 未保存色彩/样式，本片不生成伪造颜色 |
| 学习笔记 | `annotationKind=learning`；`aiAttachments` 保存作者 `ai`、task、生成正文和 promptVersion，用户正文另存。不导出 provider 配置、endpoint、凭据或临时 reader session |
| 删除 | 显式 tombstone 含 kind、稳定 ID、lastKnownRevision；仅列入 `deletionPreviewIDs`。缺席不删除；本片没有任何远端删除动作 |

`BooknoExportAdapter.book` 接受明确选中的 `LibrarySearchBook` 与可选 `CoverRecord`；`note` 接受已保存的 `NoteBodySnapshot`（PDF/EPUB/学习记录）。不主动扫描书库、生成封面、读取原书或打开文件。CBZ/DOCX 可预览书籍 metadata；其高亮适配尚未实现，其他后续格式应增加 DTO/能力协商，不能静默转成 PDF/EPUB。

封面字节通过 mock 的独立 `assetBytes` 字典提供，不嵌入批次 JSON，也没有 `transferRef` 路径/URL。先验证整个批次及每个引用；mock 有已验证哈希时可省略字节，否则缺失明确失败，不能给封面成功回执。实际类型、单帧完整解码、SHA-256、尺寸、字节数均校验。本片提议 PNG/JPEG、10 MiB、4096×4096 上限，**不是 Bookno 已有生产限额**；native cover 本身常更小，原件不改写。

## 原文与 Unicode 保全

`BooknoSourceDTO` 完整保留 native `AISelectionAnchor`，包括 book UUID、edition/hash、PDF user-space regions 或 EPUB resourceHref/spine/start/end/prefix/suffix/vertical、schema 与 extractionVersion。现有 PDF current-page 学习 anchor 同样可携带。

EPUB 当前 locator 明确为 `epub-canonical-utf16-1`，offsetUnit 为 `utf16CodeUnit`；PDF selection 是 `pdfUserSpace`，PDF current-page anchor 是 UTF-16。不能将这些数字重新标为规格草案的 code point 区间；未来采用 code point 时必须提供资源级文本映射与新版本。`textNormalizationVersion=native-verbatim-1` 表示不 trim、不 NFC、不压空白、不拼全书偏移。

引文按 UTF-8 字节核对，因为 Swift `String` 相等可能认可不同的规范等价拼写。解码/重编码和测试包含代理对 emoji、组合假名、ZWJ emoji、空白与换行。source payload 是未来回跳的依据：接收端必须保全整份 payload，回到 PDFno 后仍通过原生 reader 的 edition/hash/extraction/source 校验。这里没有注册 URL scheme，也没有启动任何应用；回跳通路与缺原书的 UX 待接入，不能把页码标签当作完整来源。

## 哈希、增量与确认

`swift-json-verbatim-1` 用 Swift JSONEncoder 的 sortedKeys、withoutEscapingSlashes 编码、原样 UTF-8 与 SHA-256。语义哈希包括版本与 typed payload（Swift enum 使用 case 标签和 `_0`）；不包含 batch ID/cursor/receiver、网络地址、时间、native `localEditRevision` 或 native `coverSourceRevision`。nil 字段省略；缺省空数组/空正文明确编码。`decode` 拒绝 future version、未知字段（含 nested anchors）、错误类型、重复实体 ID、越界资源、哈希不符和未声明封面。

这是 **Swift 预览编码约定**，不是 RFC 8785/JCS，也不是已冻结的跨语言生产 schema。黄金向量：`{"book":"😀","title":"が"}` 的 UTF-8 SHA-256 为 `2208d213de7944da4e517a27d5197c597ca96cedabf7fbdc3d3c652013ac76aa`。生产接入前须双方确认 numeric/enum/optional 编码、duplicate JSON keys 策略、完整 JSON Schema 与更多端到端黄金样本。

`BooknoOfflinePreview` 默认 disabled。调用方显式选择 preview 后才能 stage；同一次请求重排 payload 顺序仍重用同一个不可变 batch。每实体仅语义变化递增交换 revision，baseRevision 指向上一个已 stage 的源版本；native 笔记编辑 revision 只是诊断字段。调用方可只 stage 明确选中的增量及其父书；没出现在批次的对象不产生删除。

cursor 为 `(single-export-owner epoch UUID, sequence)`，另绑定 receiver UUID。纯内存 ledger 未合并多设备版本，也不是 crash-safe durable outbox。退出后新 session 使用新 epoch，mock 对已有记录的新 epoch 返回 BASE_REVISION_MISMATCH，避免恢复后重复使用 revision 覆盖旧内容。相同 batch 的 JSON 可独立重放，但 **不能把重建内存 ledger 声称为恢复完整发布历史**；生产必须有独立持久 outbox、history、per-receiver 基线、备份与审阅重新对账流程。

`BooknoConfirmationTracker` 分别记录 staged batches、每实体已确认 revision/hash 与连续已确认 cursor。回执必须绑定 receiver、epoch、batch ID/hash、cursor、完整实体 ID/revision/hash 及已验证封面引用；任一字段错误不产生确认。只有 applied/unchanged 推进相应实体，stale/conflict 不确认。乱序回执可提高实体确认版本，但连续 cursor 需等待前序 batch；迟到回执不倒退。删除列表回执只确认“见过预览”，不确认删除已执行。

## 离线 mock 接收决策

`BooknoMockReceiver` 是具体内存 mock，没有可被替换成网络的 transport 接口。它先验证全部资产再处理父书和笔记，保留 accepted source snapshot 与各字段基线/本地值。

| 输入 | 决策 |
|---|---|
| 同 batch ID、同 batch hash | 返回缓存的同一回执；模拟“接收端已提交、发送端未存回执”也不重复创建 |
| 同 batch ID、不同 batch hash | BATCH_CONTENT_MISMATCH，拒绝 |
| revision 小于 accepted | STALE_REVISION，不更新 |
| revision 相同、hash 相同 | unchanged，不覆盖本地编辑 |
| revision 相同、hash 不同 | REVISION_CONTENT_MISMATCH，拒绝 |
| revision 更大但 base/epoch 不符 | BASE_REVISION_MISMATCH，等待对账 |
| 更大且基线匹配 | 字段级三方比較：只源端改取源；只本地改保留；两端同字段不同字节为 LOCAL_EDIT_DIVERGED |
| 缺父书/edition/hash 不匹配 | missingParent 或 sourceMismatch，无孤儿记录或错误来源绑定 |

三方字段包括书名、作者、edition、封面引用/来源组合，及笔记用户正文、完整 source、AI attachments。接收端独有标签/手写新增备注应保存在映射之外，不能因为源 DTO 未含它们而清除。本片 mock 不伪造 Bookno 模型上的标签、rich text 或真实数据库事务。

首片选择保守的 **整批 upsert/资产原子提交**：任意 conflict/stale/base failure 导致本批所有新变化 blockedDependency，已确认 unchanged 项保留；缺失/损坏资产或 sourceMismatch 抛出明确错误，既有记录不变。tombstone 始终是独立预览列表，不参与删除。conflict 回执也是不可变批次结果；将来用户解决冲突后应产生新的计划/批次，不能悄悄重用旧 batch ID 改其内容。

## 默认关闭与接入顺序

没有修改 `FeatureAvailability.bookno`（仍为不可用），没有 UI 自动导出，没有 URLSession、listener、OAuth/key/CloudKit、shared Library 写入或实际 Bookno 导入。

开发调用顺序：用明确的已保存 snapshot 创建 DTO → `BooknoOfflinePreview(mode: .preview)` stage → `BooknoExchangeCodec.encode/decode` 校验预览 → `BooknoMockReceiver.receive` 验证计划/回执 → `BooknoConfirmationTracker` register/acknowledge 验证恢复语义。接收端 receipt 类型明确包含 Mock，不能展示为“Bookno 已同步”。

未来真实接入必须先在 Bookno 批准 namespace/ID、存储完整 locator/AI/highlight、导入 revision/hash/field baselines、资产限制/事务与回执；然后冻结版本协商/schema，再实现默认关闭的受保护传输与显式用户配置/确认。本机 API 不能被描述为三端跨设备通路。

## 需要用户/Bookno 侧决策

1. 是否批准首阶段 PDFno → Bookno 单向 upsert，Bookno 本地编辑保留、删除仅预览？双向编辑和删除传播另立契约。
2. 首个真实通道采用同一 Mac 的受保护 native bridge 还是 loopback API？移动/跨设备另需明确方案，不能推断 OAuth/云服务已存在。
3. Bookno 是否增加独立 pdfno importer/source payload 与导入基线侧表？高亮样式、AI 来源、edition 历史/重绑、用户 rich text/标签保护需要一起确认。
4. 双方是否接受上述封面上限与整批事务，或改成每本书及其依赖原子提交？大批次、分页/冲突解决规则要同步变化。
5. 生产导出 revision 由哪个持久协调责任者产生？多设备/备份 epoch 重新对账在实现前保持阻止状态。

## 整合与验证

变更全部为新增 Domain/Services/测试/本 ADR 与验证记录，无现有模型、manifest、UI、Package.swift、Xcode project、引擎或审批门禁修改。相关测试和明确未验证范围见 [BOOKNO-OFFLINE-VALIDATION.md](BOOKNO-OFFLINE-VALIDATION.md)。现有安全专项 UNVERIFIED 平台阻断原样保留；本片不重试其受阻动作，不将 mock 成功计作安全/真实 API/真实回跳/同步上线验收。
