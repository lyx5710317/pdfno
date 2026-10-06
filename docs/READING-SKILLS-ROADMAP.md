# PDFno 阅读 Skills 分阶段实现路线

日期：2026-10-05；本地实施状态更新：2026-10-06。**P0 部分已实现，P1/P2/P3 仍为规划**。原文档授权和快照保留如下，当前开发授权与验证见 [本地整合记录](READING-LOCAL-INTEGRATION-2026-10-06.md)。

依据：[ADR 0010](ADR-0010-READING-SKILLS.md)、[主规格](PDFno_AI_Development_Spec_v0.3_Native.md) 8.5/9.5/17.6/18.1，以及[要求账本](REQUIREMENTS-LEDGER.json)。本次只更新文档与本地文档提交，未授权立即实施、推送合并、模型/MCP调用、安装、真实用户数据迁移。发布基线为 `7bea8ec89ea7273b3b52ee714fbf1180b3d51c73`，仅表示只读源码观察，不表示新功能运行或质量通过。

## 当前 P0 本地实施状态

六项内置契约/计划已存在；翻译、解释、日语、英语与独立 BYOK 选文宿主使用原 coordinator/provider/共享三次预算。英语已在验收基线 ab6695c 中，不再是未合入候选。PDF 页与 EPUB spine 仅登记契约，仍走原独立六次批次链。envelope 为会话内属性，旧学习文件/草稿/CAS 与 source fence 保留；统一批次执行、新仓库、模板导入编辑、单书 QA 和工具运行时尚未实现。下面任务卡是完整目标，不表示 P0 全部完成；实验检索切片未接进产品。

## 当前能力与迁移顺序

以下表格保留 2026-10-05 原文档基线；2026-10-06 已整合状态以本节上方 P0 实施摘要及统一报告为准。

| 能力 | 基线中证据与范围 | Skills接入方式 | 仍缺什么 |
| --- | --- | --- | --- |
| 选文翻译/解释 | `AIContracts.swift`、`DeepSeekSelectionPolicy.swift`、`AILearningModel.swift`；PDF/EPUB，≤500 UTF-16，1024output tokens/30秒/64KiB；显式来源/接收方确认 | RS-P0-03包既有profile，不改变简单按钮；旧prompt/结果保持原validator | 持久Keychain、真实新服务兼容及语言质量不是这次验证 |
| 自定义HTTPS BYOK | `BYOKProviderContracts.swift`、`BYOKProviderSession.swift`；有限非流式chat/completions JSON，全部重定向拒绝；共用选文三次预算 | 注册协议能力，不把“兼容”扩大成SSE/vision/任意工具 | 模型列表/价格/usage/embedding/tool calling未因该协议获得 |
| PDF整物理页双语 | `PDFPageTranslation.swift`、`PDFPageTranslationModel.swift`；全页≤3000 UTF-16，≤6段，每段≤500；独立六次预算，串行，首失败停止 | 作为独立scope/profile；沿用全计划确认、成功段与手动保存 | 不是跨页、扫描OCR、后台续传或批量书籍翻译 |
| EPUB当前spine双语 | `EPUBChapterTranslation.swift`、`EPUBChapterTranslationModel.swift`；同3000/6/500边界，剔除rt/rp；独立六次预算 | 命名明确“当前spine”，沿用typed href/spine与原文校验 | 不称目录逻辑章/屏幕页；未覆盖整书、自动恢复 |
| 日语假名/语法分色 | `JapaneseLearning.swift`、`JapaneseSentenceComponents.swift`、`LibraryModel+JapaneseLearning.swift`；`japanese-selection-2`；作者ruby保留，scalar/grapheme跨度校验，共享selection预算 | 专用语言/结构schema及validator，旧`japanese-selection-1`保护兼容 | 不把JSON通过当语言质量通过；禁止生成读音覆盖作者ruby |
| 保存与本地记录搜索 | `AILearningRepository.swift`、`JapaneseLearningRepository.swift`、`SavedRecordSearchModel.swift`；独立文件、手动保存、已保存记录检索 | 先适配现存文件，新增结果另schema；保持用户正文与AI字段分开 | 记录检索不是一书全文索引；不宣称跨章RAG |
| 英语结构解析 | 发布main没有English学习实现；独立integration候选的说明和CI另维护 | 只有实际合并并完成对应验收后才注册为可用；旧记录协议按落地版本核对 | 本次不合并候选，不宣称英语已发布，不替CI给结论 |
| 新解释/论证/学习卡 | 本基线没有下面RS新schema/runtime | 先原创固定契约，再个人模板；不借用闪念私有模板全文 | 待逐片授权和实现 |

9.1/9.4的历史限制记录仍保留原日期；以上2026-10-05快照解决“旧文档预览/候选”和今日代码状态的时间差，不改写原测试或审计结论。当前源码文档参见[四切片整合](FOUR-SLICE-INTEGRATION-2026-10-04.md)、[日语切片](JAPANESE-LEARNING-SLICE.md)、[PDF整页](PDF-PAGE-TRANSLATION-SLICE.md)、[EPUB spine](EPUB-CHAPTER-TRANSLATION-SLICE.md)。

## 运行时模块与边界

以下为拟议类型与职责，不是已存在的API名称；实现应按现有packages归属调整，不能把示例当可编译代码。

| 模块 | 拟议职责 | 依赖/禁止越界 |
| --- | --- | --- |
| Domain：SkillManifest/Registry | 版本、范围/语言/参数/输出枚举、兼容性与内置注册 | 纯Swift值契约；不读key/文件或发网络 |
| Domain：SkillInputPlan/ResultEnvelope | 冻结来源/上下文、validator绑定、权限/预算计划及来源引用 | 复用真实anchors与版本；不伪造坐标或自动全文 |
| Services：SkillPlanner/Runner | 检查能力、准备预览、消耗原预算、调用受限provider、取消/错误/迟到结果 | 复用AppAISession/已有服务；模板不可调用URLSession或原生桥 |
| Services：ResultValidator | 严格schema、输出大小、span、quote/ref、来源版本与语言规则 | 按结果类型注册；模型自报校验无效 |
| Services：SkillRepository | 模板/新结果分仓、备份/原子写、CAS和只读保护 | 无自动旧文件迁移，不改用户正文或原书 |
| Reader adapter | 选择文本/真实page/spine快照、sourceRef与回跳再验证 | PDFKit/EPUB真实能力；以后逐格式适配，WebView无key |
| UI | 现有简单按钮＋可选Skills列表、预览/取消/结果/保存；版本/不可用理由 | 原生SwiftUI/AppKit；快捷键不触发隐形请求 |
| 后期BookIndex/ToolBroker | 本地单书检索；外部只读工具的单独权限边界 | 不放进首期Runner；默认关闭，不暴露任意脚本/文件 |

## P0：统一契约与既有入口，先不增加网络能力

前置：重新核对当时已发布基线、实际合并的英语状态、现有来源/预算/取消/保存回归。此阶段实现本身仍需后续授权。按RS-P0-01→02→03→04顺序，首片可以只完成离线manifest/registry与mock，不为方便一次重构所有入口。

| 任务 | 实现与依赖 | 必测失败案例 | 完成标准 |
| --- | --- | --- | --- |
| RS-P0-01 registry/version | 内置manifest、结果类型/validator注册、runtime兼容范围；强类型参数；无自定义脚本/工具 | 未知/未来schema、重复ID、缺validator、非法语言/字段/长度、未实现scope | 全离线fixture确定性拒绝；只显示真实可用项；未知模板原件保留且禁用 |
| RS-P0-02 input/plan | 已有PDF/EPUB快照→Skill计划；显示范围/正文片段/字数/host/path/model/预算；选择卡，无隐形记忆 | 空/扫描页、3000/500越界、ruby、emoji/组合字、PDF重复引文、EPUB换spine、来源/配置改变后用旧确认 | 来源单位不改；改变接收方/版本/上下文即旧确认失效；预览/切换不开网络 |
| RS-P0-03 runner/adapters | 包装已实现翻译/解释/页/spine/日语；英语只有合并且已验收后接入；旧按钮默认值不变 | 认证/余额/429/超时/截断/畸形JSON、redirect、工具call、切书/取消/迟到、预算共享、缓存命中 | 保留3/6次、500/3000/1024/30s/64KiB与0自动重试；mock/stub全拦截；不会新领额度或fallback |
| RS-P0-04 result/store | 类型payload＋版本/来源provenance；cache key；新结果独立schema；旧文件适配不重写 | 错quote/span/ref、未来/损坏/带秘密字段文件、保存失败、重复保存、CAS冲突、旧版回滚 | 来源/AI与用户字段分离；manual save/idempotence；新旧结果隔离；备份及原子写失败不损坏原件 |

本阶段复用 `R04–R07/R16` 与 `T04–T10/T11`、`UAT02–09/UAT12`，不更改它们原定义。真实服务兼容/语法质量、系统Keychain、移动真实UI不由mock通过代替。验收记录应分源码、编译、mock、实际UI、真实服务/语言质量五类，明确NOT-RUN。

## P1：三种原创阅读任务

依赖P0完整来源/版本/保存闭环。第一片仍限PDF/EPUB明确选文与现有预算；“段落”是用户实际选定的有限文本，不自动寻找整章。现有1024输出tokens不足时限制卡数/结构或显示不支持，不能静默提高额度。先固定契约和prompt，用户编辑模板放P2。

| 任务 | 原创结果契约与交互 | 必测失败案例 | 完成标准 |
| --- | --- | --- | --- |
| RS-P1-01 段落解释 | `explanation`，术语/简释、引文、推断/不确定标记，每项sourceRef；选择阅读难度/目标语言 | 资料不足、不同版本引文、模型新增外部知识装作原文、注入“访问文件”、长度截断 | 所有原文依据回查；推断清楚；不触发工具；保持简单解释按钮 |
| RS-P1-02 论证结构 | `claims/evidence/relations`有本地ID；作者明示/模型推断区分；每条依据绑定span/ref；列表先行 | 悬空/循环关系、重复ID、原文不含因果、无论点/证据、错误归因 | 结构schema/引用全部验证；无法确定可空/不足，不制造思维导图节点依据 |
| RS-P1-03 引用学习卡 | 有限`cards`：question/answer/evidenceRefs/uncertainty；生成预览后逐卡选保存 | 无依据答案、同句重引歧义、模板输出HTML/脚本、重新生成覆盖用户改卡 | 每张卡至少一项有效依据，回跳准确或stale；保存幂等/CAS；复习算法/云同步不包含在本片 |

语言质量用原创与有合法使用权的小样本人评，中文/日语/英语分开；记下漏解释、错误推断、伪引用比例及样本覆盖。不预设模型质量分数已经达到。段落解释优先于图形化论证，卡片保存优先于复习调度，避免同时引入新UI和新后端。

## P2：单书检索、跨章节引用及个人模板

P2分两条独立线：RS-P2-01/02/03为本地检索→QA；RS-P2-04为模板管理，仅依赖P0/P1，不强迫先做向量模型。首片按实际文本覆盖选择词法索引，embedding选型要单独ADR、固定来源/许可/大小和本地执行验证，不默认下载或远程embedding。

| 任务 | 实现与依赖 | 必测失败案例 | 完成标准 |
| --- | --- | --- | --- |
| RS-P2-01 extraction/chunks | 每书source/edition/extraction版本；按真实PDF页/EPUB资源分块，稳定chunkID/locator/quote、token/字节上限和重叠策略 | 扫描页、损坏/不可提取资源、重复段落、ruby、页顺序、span跨grapheme | 覆盖率有真实分母和跳过原因；扫描/OCR缺口显式；chunk可回查而非复制整书到请求 |
| RS-P2-02 local index | 版本化词法首片；后台增量重建/取消，staging+原子换代，资源变更失效、旧index只读 | sourceHash/extraction/chunker变化、索引损坏、磁盘不足、取消、锁冲突、同名不同版 | 不混新旧版；保存原书；旧索引标旧版；可删除/重建；没有外部embedding流量 |
| RS-P2-03 singlebook QA | 明确一书及范围；本地取有限topK，弱命中阈值和确定排序，逐片预览/预算；外发问题和已选命中，不整书 | 跨书泄漏、无命中/弱命中、过期chunk、假页码/quote、重复引用、来源注入、超预算 | 无证据回答不足；逐句引用通过宿主回查；外部知识不冒充书内证据；跨章QA不自动扩大到书库 |
| RS-P2-04 personal templates | 离线编辑、fork、lint/mock预览、版本/兼容检查、用户选定导入导出/脱敏分享包 | 未知变量/版本/validator、zip路径穿越/过大、脚本或密钥、内置ID冲突、偷偷增工具/URL | 导入不生成/联网；不兼容禁用保留；导出无私人正文/配置/凭据；可恢复旧版；分享与发布另显式操作 |

索引对象和AI上下文各有权限：允许建本地索引不允许向服务发送整书；允许外部问答不允许读取全部私人笔记。模型输出只引用宿主提供的sourceRef集合，不能通过页码或URL任意索取新资料。用户实际文档不可作为自动化fixture。

## P3：外部研究与MCP，先Client后Server

在单书引用和任务权限稳定后再评估。不需要MCP才能完成P0–P2。RS-P3-01/02是外部Client线；RS-P3-03是方向相反的Server独立切片；有限workflow是最后可选项。所有网络默认关；本路线不授权连接现有闪念目录服务。

| 任务 | 实现与依赖 | 必测失败案例 | 完成标准 |
| --- | --- | --- | --- |
| RS-P3-01 外部来源卡/目录 | 显式问题/短引文→读网页/公共搜索；显示工具、运营者、来源、URL、认证/费用/日期；默认不包含私书 | URL未实际读取、恶意正文/注入、重定向/SSRF/私网地址、过大响应、服务端改变工具/费用 | URL与已获取证据区分；预览最小数据/接收方；拒绝未获准地址/范围；上限/取消与日志脱敏 |
| RS-P3-02 MCP Client | 固定已核验HTTPS服务与只读工具allowlist；原生ToolBroker；认证/工具发现不自动调用业务工具 | 工具schema变更、未经批准工具、模型提权、OAuth失败/令牌泄漏、断线/未知提交、预算耗尽 | 每次真实调用按批准策略检查参数与数据；关闭即停止新调用；不支持任意命令/Node安装/文件访问 |
| RS-P3-03 MCP Server | 独立ADR定访问方认证、绑定地址、来源范围/撤销、只读响应限额与审计；默认off | 未认证/跨用户、遍历书库、路径注入、被撤销资料、旧会话、输出私有笔记 | 仅用户选定资料；访问/停止可见；无写/删除/任意导出；Client开启不自动启用Server |
| RS-P3-04 有限workflow | P0任务DAG/步骤schema、来源转移、接收方与总预算；明确暂停与失败传播 | 步骤循环、输出提权、后续扩大书/网络范围、失败后继续、重复重试扣费 | 不执行任意代码；取消停止后续；成功段可读；不可把工作流批准扩大成无限agent循环 |

真实网络、安全和许可验收独立开展；模型输出声称“工具已成功”不能代替宿主调用记录。书/网页提示注入样例必须同时验证数据与权限边界；提示词写“不允许”不能替代原生拒绝。OAuth/开放端口/本地服务/凭据持久化均需专门设计，不因闪念有入口就照搬。

## 原创manifest形状示例

以下是设计示例，字段/数值需P0最终固定；不表示已安装、可导入或能发请求。变量只是数据槽，`validatorID`必须宿主已有注册，不允许模板提供代码。

```json
{
  "manifestSchemaVersion": 1,
  "skillID": "pdfno.reading.explain-selection",
  "skillVersion": "1.0.0",
  "runtimeCompatibility": { "min": "1.0.0", "maxExclusive": "2.0.0" },
  "origin": "pdfno-original-proposal",
  "input": {
    "formats": ["pdf", "epub"],
    "scope": "selection",
    "sourceLanguages": ["zh", "ja", "en"],
    "maxUTF16": 500,
    "context": "explicit-source-only"
  },
  "parameters": {
    "targetLanguage": { "type": "enum", "values": ["zh", "ja", "en"], "default": "zh" },
    "readingLevel": { "type": "enum", "values": ["plain", "academic"], "default": "plain" }
  },
  "requiredCapabilities": ["chat-completions-json-stop"],
  "promptVersion": "reading-explain-1",
  "variables": ["sourceText", "targetLanguage", "readingLevel", "sourceRefs"],
  "result": { "kind": "explanation", "schemaVersion": 1, "validatorID": "explanation-1", "validationVersion": 1 },
  "permissions": { "tools": [], "extraContext": [], "automaticSave": false },
  "budget": { "sessionPool": "selection", "maxOutputTokens": 1024, "timeoutSeconds": 30, "maxResponseBytes": 65536, "automaticRetries": 0 }
}
```

真实计划还要绑定本次source/provider/config generation/参数、缓存身份和用户确认；这些运行值不是分享模板的一部分。`sourceLanguages`是首片目标，不代表语言已验收。P1结果schema必须有有限数组/字符串/unknown-field规则，以及宿主sourceRef/quote/span校验，不能只复用一个`json_object`请求选项。

## 验收、迁移与发布记录格式

每张RS卡完成后记录：获准范围、基线与最终提交、改动文件、输入/输出版本、旧按钮行为、可复现原创fixture、正/反向验证、真实UI是否执行、网络/费用/语言质量是否执行、设备/安全审计边界和回滚办法。只有通过的具体格式/语言/profile开放；其余项保持不可用并说明原因。

旧记录迁移先离线备份/样例dry-run，保留prompt/schema/anchor单位与用户revision；不把旧书摘要当真实文件hash、不把Rangy定位命名为标准CFI。旧文件未来/损坏保护与独立新仓并存；未来导入只在明确兼容器存在时进行。回滚可恢复旧文件，不假称旧版能读取所有新结果；删除临时key不删除笔记。

本地文档检查、mock通过与独立累计安全审计分开；后者仍UNVERIFIED。主规格83正式ID及基线审计评语冻结，只更新文档行号和路线引用。Bookno实际API/iCloud传输、账户/云容器、签名发布和iPhone/iPad实际UI继续按各自任务推进，不成为阅读Skills先决同步条件。

## 闪念参考与工具商店来源核验

交互上可借鉴：按阅读任务选择入口；模板与输入范围一起预览；工具/索引/外部连接分别开关；解释清楚数据去向；无配置明确不可用。不能据观察宣称有可编辑prompt全文、链式工作流、完整个人模板或本地模型效果。录音/会议、待办执行、生活助手和跨应用个人记忆与PDFno首期阅读目标不匹配。

下表仅用实际UI地址与相应官方/维护者文档核对来源，日期2026-10-05；没有连接MCP、OAuth、发工具调用、测试收费或读取用户数据。其他目录项没有在本轮逐一核验。服务费用、条款和可用性将变更，未来接入时重新核对。

| UI服务与地址 | 谁运营/上游来源 | 认证与费用边界 | 一手来源 |
| --- | --- | --- | --- |
| Exa：`https://mcp.exa.ai/mcp` | Exa官方MCP；底层Exa搜索/抓取服务 | 无key有免费限额；OAuth/APIkey与agent任务按实际计划，不称无限免费 | [Exa官方MCP文档](https://exa.ai/docs/get-started/exa-mcp) |
| Jina：`https://mcp.jina.ai/v1?include_tools=read_url,primer,guess_datetime_url` | Jina官方server，封装Reader/Search/Embedding等API；闪念URL只选择三工具，不代表整个server工具集 | read_url允许无key有限使用；primer/date不需key；其他搜索/embedding等可能需key，计划/限额另核验 | [Jina官方MCP仓库](https://github.com/jina-ai/MCP) |
| Arxiv：`https://arxiv.caseyjhand.com/mcp` | cyanheads维护的社区wrapper/public host；底层arXiv API/OAI-PMH与HTML/ar5iv/PDF | README说明只读、无需认证；上游公开API有限流；不是arxiv.org官方MCP | [维护者仓库](https://github.com/cyanheads/arxiv-mcp-server) |
| Microsoft Learn：`https://learn.microsoft.com/api/mcp` | Microsoft官方文档知识服务 | 官方说明无认证、MCP免费；调用模型的token费用另算 | [Microsoft Learn官方MCP说明](https://learn.microsoft.com/en-us/training/support/mcp) |

Flash界面提供的是推荐外部服务配置目录；谁维护目录、怎样更新、是否静态打包或从某registry获取，未从公开证据确认。不能说所有条目出自同一个工具商店，也不能把社区wrapper标成上游官方产品。PDFno未来目录须分三层说明“目录维护者→server运营者→上游数据”，并分别标核验与未知。目录本身不提供索引、权限隔离或任意能力；复制URL不是完成集成。
