# Reading Skills 最小基础层（本地切片）

日期：2026-10-05。基线：`82585b1053b8a000f337274fec8ae597255c9135`。分支：`feature/reading-skills-foundation-20261005`。本片只有本地实现与提交，不推送、不合并。没有改动 main 或临时设置布局分支。

已读取独立文档提交 `0b4a58d7c426803db84ca822acfc1b0296cc6d51` 的 `docs/ADR-0010-READING-SKILLS.md`、`docs/READING-SKILLS-ROADMAP.md`，以及本基线主规格、CONTRIBUTING、现有 AI/英日语/页/spine 实现和验证记录。本基线已包含英语接线；独立 ADR 当时的“main 尚无英语”是旧快照，不能沿用为当前结论。仓库与其祖先未找到适用 AGENTS.md，仓库未提供 `.agents/skills`。未夹带文档分支的规格、账本或其他改动。

## 功能与限制矩阵

| 能力 | 本片实际实现 | 路由与限制 |
| --- | --- | --- |
| 内置目录 | 六个稳定 Skill ID；Skill/runtime/manifest/prompt/result/validator 版本；类型化输入、输出和预算描述 | 只允许精确匹配编译内置契约。重复 ID 全部禁用；未来 schema/runtime/Skill 版本、缺 validator、未知 ID、越权范围/工具/输入限制保留原描述并禁用 |
| 选文翻译、简短解释 | `ReadingSkillRequest.text` → 原 `AIJobCoordinator` → 原 `AIResult` 类型 envelope；mock、官方 DeepSeek、既有有限 HTTPS BYOK 描述 | Services 显式薄适配真正转交原 coordinator；测试通过。现有按钮仍走原路径，未接入新目录或面板。Skills seam 限500 UTF-16；旧 mock 入口的8000上限未改 |
| 日语选文 | 既有 `JapaneseLearningRequest`、coordinator、validator、`japanese-selection-2` 与 persistability 检查 | Services 显式薄适配真正转交；作者 ruby 固化在本地计划/结果，未进入请求；没有覆盖作者读音或用户修正 |
| 英语选文 | 既有 `EnglishLearningRequest`、coordinator、validator、`english-selection-1` 与 persistability 检查 | Services 显式薄适配真正转交；仅既有 mock/官方 DeepSeek，未开放自定义 HTTPS 英语协议；语法仍为待审阅候选 |
| PDF 完整物理页 | 注册 scope、原 `PDFPageTranslationPlan` → 离线 Skills 计划/完整来源 references | **仅描述和规划，未通过新适配器执行**；保留原页入口的完整计划确认、串行停止和独立六次预算 |
| EPUB 当前 spine | 注册独立 `epubCurrentSpine` scope；复用原完整正文分段，不称逻辑 TOC 章节 | **仅描述和规划，未通过新适配器执行**；保留原 spine 入口的独立六次预算/批次 claim；没有扩范围 |
| 参数 | 唯一 `targetLanguage` string enum，默认且仅允许 `zh-Hans`；未知字段、错误类型、长度/枚举越界拒绝 | 现有 prompts 固定简体中文；没有伪装成已支持阅读难度、任意语言或用户 system prompt。来源语言为有限声明标签；不执行语言识别 |
| 计划与权限 | 完整来源、选文/页/spine 范围、UTF-16 数、参数、最终 URL/model/config generation、3/6预算、1024/30秒/64KiB/零重试、工具/额外上下文为空 | 纯离线值构造；不读 credential、不请求、不 reserve、不保存。无书目/笔记/历史/其他书/隐形记忆注入 |
| 来源与结果 | 本地 `source-N`、精确 UTF-8 正文 SHA、完整 typed snapshot SHA；类型 payload、版本/配置/输入参数身份、校验类别、cache/usage 状态 | 来源 references 由宿主生成；模型仍只回显原协议 sourceQuote，不新增模型引用协议或自造坐标。envelope 只能由 Services 内部构造，无任意字典/解码“已验证”路径 |
| 确认/取消/迟到 | 新计划确认 + **原宿主 AIConsent 均必需**；来源及配置在转交前/完成后由宿主复核；仍由注入原 coordinator 负责取消/超时/迟到响应 | 不生成 consent，不提供默认 provider/transport/session。宿主必须注入原 AppAISession.selection 绑定的 provider；mock证明翻译/日语/英语共用三次尝试，第四次不提交 |
| 缓存/保存 | 保留原 coordinator 内存缓存；新 `cacheIdentity` 只是完整版本/参数/来源身份；payload 保留原结果类型 | **未实现新缓存或结果仓库**；envelope 仅会话视图。`learning-v1`/日语/英语文件、手动保存、CAS、用户正文、备份/恢复全不改变；没有迁移旧笔记 |
| 后续能力 | `explicitResourceRange`/`singleBookRetrieval` 是保留 scope，不能被注册为可用 | 无个人模板 importer/editor、脚本、任意代码、Skill商店、MCP、外部检索、向量、下载、新模型或网络能力 |

这是 RS-P0 的最小基础，不代表四张 P0 卡或全部15张路线任务卡完成。RS-P0-01 已有编译目录及离线契约拒绝；RS-P0-02 已有输入计划但没有新 UI；RS-P0-03 只有既有选文能力的显式转交 seam；RS-P0-04 只有临时类型化 envelope，没有新结果持久仓库。manifest 仅 Encodable，没有 Decodable/文件导入通道；不声称未知文件字段/包/未来文件已完成导入保护。

## 集成说明与共享点

新增文件只有 Domain 的 `ReadingSkillRegistry.swift`/`ReadingSkillPlan.swift`，Services 的 `ReadingSkillSelectionAdapter.swift`/`ReadingSkillResultEnvelope.swift`，原创测试 `ReadingSkillFoundationTests.swift` 和本文。未修改 LibraryModel、任何 UI、reader、provider、现有 validator/repository、AppAISession、工程/generator、依赖或 CI。共享文件冲突清单：**零项**。后续如果其他分支新增同名 ReadingSkill 文件，应先比较契约，不直接覆盖。

未来宿主接线的最小位置是现有 AI、日语、英语 model 的显式 start 完成路径。操作顺序为：

1. 用原 typed request 创建 `ReadingSkillInputPlan`，展示完整来源、固定参数、最终接收方/model、限制与费用未知；准备计划不会执行。
2. 用户明确确认后同时保留 `ReadingSkillConsent(taskID:planFingerprint:)` 和原 `AIConsent`。修改任何来源/配置/版本/参数/作者 ruby/请求期限后重建计划；不能从打开面板或历史点击自动补确认。
3. 向对应 `runText`/`runJapanese`/`runEnglish` 注入现有 coordinator、现有 credential-generation 绑定 provider 和同一 host AppAISession.selection。必须提供实际 `sourceAndConfigurationAreCurrent` 检查，不能在生产传恒 true。
4. 取消/切书/关窗沿用原 coordinator 或取消调用 Task；变更来源/credential/config generation 时撤销原 provider 与确认。两次来源复核是完成边界，不能替代宿主在变化发生时主动取消。
5. envelope payload 仍是原 `AIResult`/英日 review。需要保存时再由用户操作进入现有 repository、writer gate 与来源提交 fence；用户正文独立，不能直接将 envelope 自动保存。新 ReadingSkillFailure 有安全中文说明，接线时明确处理它，不通过通用未知错误映射吞掉原因。

`cacheIdentity` 绑定完整 manifest（所有版本/validator）、实际 prompt、精确 sources、作者 ruby、全部参数、来源语言声明、最终 receiver、provider/model/generation、scope metadata 与请求期限；排除 requestID/key。它目前未新增 cache，更没有磁盘缓存。原 legacy cache 继续使用原 fingerprint，本片固定契约/唯一目标语言不改变原请求语义。未来新增可变参数/模板/版本必须另扩展执行与缓存契约，不能只改 manifest 后仍复用旧 cache。

本地 sourceRef 只能回查本次既有 typed snapshot；文件是否仍为当前 edition/extraction、真实回跳是否唯一，仍须原 reader 校验。没有把 sourceRef hash 当真实文件存在证明，也没有将 UTF-16 locator 转成 code point。原 scalar-exact/grapheme/span/重复引文校验原封保留。结构/来源通过不表示翻译、语法或读音质量通过。

## 验证证据

所有 fixture 是原创假句、现有原创 fixture 和 mock/fake credentials/完全拦截 transport。没有读取真实书库或 key，没有真实 API 请求、外部 MCP、网络检索、向量或安装。所有重型检查使用已核实的批次 `run-heavy-check.py` 锁，独立输出，最大2 jobs。

工具链：Xcode27.0（27A266a）、Apple Swift6.4、arm64 macOS27。

| 检查 | 结果 |
| --- | --- |
| Foundation + AI/英日/页/spine/来源/保存/预算选定 Swift 回归 | PASS：166 tests / 16 suites；基础层17 tests（其中取消/超时有2个参数化case） |
| 原始52项 Mac UI 方法 | 基线逐字节一致；46 Native + 4 Ebook + 2 NextBatch，断言、skip和超时未修改 |
| Mac 双架构 build-for-testing | PASS：arm64 + x86_64，CODE_SIGNING_ALLOWED=NO；52项实际 UI 方法只编译 |
| iOS Simulator 双架构 build-for-testing | PASS：arm64 + x86_64，generic destination；未启动 Simulator |
| 源码/fixture/provenance guard、diff whitespace | PASS：657个源文件；原fixture、纯Domain、两app target及无检测到私人材料检查通过；diff无空白错误 |
| 桌面实际 UI、移动真机/模拟器实际运行、真实服务兼容/语言质量/费用 | NOT-RUN；build-for-testing 不代表这些通过 |
| 累计独立安全专项 | UNVERIFIED；未重试被拒专项，普通 source guard 不替代专项 |

可复现命令（设置 `PDFNO_HEAVY_CHECK` 为已核实的批次锁，`PDFNO_CHECK_OUTPUT` 为独立临时目录）：

```sh
python3 "$PDFNO_HEAVY_CHECK" -- swift test --package-path apple/Packages/PDFnoKit --scratch-path "$PDFNO_CHECK_OUTPUT/swift" --jobs 2 --filter 'ReadingSkillFoundationTests|AITests|BYOKProviderTests|AppAISessionTests|JapaneseLearning.*Tests|EnglishLearning.*Tests|PDFPageTranslationTests|EPUBChapterTranslationTests|FormatsJapaneseIntegrationTests'
python3 "$PDFNO_HEAVY_CHECK" -- xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath "$PDFNO_CHECK_OUTPUT/mac" -jobs 2 CODE_SIGNING_ALLOWED=NO 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build-for-testing
python3 "$PDFNO_HEAVY_CHECK" -- xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath "$PDFNO_CHECK_OUTPUT/ios" -jobs 2 CODE_SIGNING_ALLOWED=NO 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build-for-testing
python3 scripts/check-native-source.py
git diff --check
```

原始日志与最终 receipt 在本任务独立临时输出目录；交付消息提供本地链接。最初测试编译的 actor await 表达式问题已修正；收尾将 manifest 限制为 Encodable，禁止自动解码静默丢字段，最终选定回归与两端构建据此重新通过。第三方 C 编译及既有英语测试 Sendable capture warning 属既有基线范围，本片不宣称零警告。

回滚：只移除本片新增文件或 revert 本地提交；没有持久格式或用户数据变更。实际主入口尚未接线，因此回滚不会要求迁移或重写旧笔记。推送、合并、UI接线、新参数、新结果仓库、外部服务与真实语言质量验证留待各自明确范围。
