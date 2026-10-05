# Reading Skills 宿主实际接入（本地增量）

日期：2026-10-05。分支：`feature/reading-skills-foundation-20261005`。父提交：`2553edfd8c090bb74cdaeeb09f2f96657a6823a4`，原始基线 `82585b1053b8a000f337274fec8ae597255c9135`。保留首片历史；本增量只本地提交，不 push/merge。依据已读取的独立文档提交 `0b4a58d` 的 ADR 0010/路线图、本基线主规格、CONTRIBUTING 和当前 AI 生命周期。仓库/祖先没有找到适用 AGENTS.md，仓库未提供 `.agents/skills`。

用户已批准把现有四项选文能力实际接入薄适配，保持当前界面、确认、额度、取消、来源和保存行为。以下矩阵替代首片的“UI未接线”状态；不宣称页/spine统一执行或全部路线卡完成。

## 实接入矩阵

| 现有宿主/能力 | 现在实际执行链 | 结果/限制 |
| --- | --- | --- |
| AILearningModel 翻译 | 原开始按钮 → 原 confirmed/来源/服务/会话key门禁 → text Skill plan → ReadingSkillSelectionAdapter.runText → 原 AIJobCoordinator/原 provider | 翻译 ID；返回 envelope 后取原 AIResult，原 history/status/save 全保留 |
| AILearningModel 简短解释 | 相同开始入口，按原 kind 选择 explain Skill | 解释 ID；同一 coordinator/cache/selection budget，原任务 Picker/identifier不变 |
| BYOKSettingsModel 翻译/解释 | 原确认和 BYOKSessionSnapshot/credential 门禁 → 原 BoundBYOK provider factory → text Skill plan/runText → 原 coordinator | 官方 DeepSeek/有限自定义 HTTPS 仍用原 wire/最终 path；无新增模型/provider 或 mock fallback；session revocation 前后核对保留 |
| JapaneseLearningModel | 原确认、prepared.validate、isCurrent/provider-mode → Japanese Skill plan/runJapanese → 原 JapaneseLearningCoordinator/validator | 作者 ruby/用户修正分开保留；原 review、source return、手动保存 callback；共享 selection 三次额度 |
| EnglishLearningModel | 原确认、prepared.validate、isCurrent/provider-mode → English Skill plan/runEnglish → 原 EnglishLearningCoordinator/validator | 原成分/语法候选、source return、手动保存 callback；共享 selection 三次额度 |
| PDF完整物理页/EPUB当前spine | **仍走原批次 model/coordinator/provider，未接新适配器** | 只保留首片目录和离线计划。原全范围确认、500/3000/6分段、独立各六次额度/停止/claim策略不变 |
| UI目录、个人模板、结果仓库 | **未实现** | 没有新按钮/面板/布局/identifier、import/脚本/MCP/索引/向量/新服务；envelope/plan为会话内属性，无新文件schema或旧数据迁移 |

所有四项选文能力现在从实际宿主 start 调用薄适配，不只是描述或独立测试调用。公开只读 `readingSkillPlan`/`readingSkillResult` 供宿主检查 provenance；没有新增 UI。原 result/review 清除时同步清除它们；已取消但未开始的旧任务先检查 generation，不能给新来源留下旧计划。适配器检查源/配置及 token 的前后边界，宿主仍负责在切书/关窗/换provider/key发生时主动取消，原异步结果 guard 全保留。

同一次**原 confirmed 门禁通过之后**才建立新计划确认；不新增确认控件，不自动补确认、不开窗即发请求、不在 prepare/选择/修改参数阶段请求。固定 targetLanguage 仍仅 `zh-Hans`，没有新的用户参数或额外上下文。新 ReadingSkillFailure 经安全 hostFailure 映射回原 AIFailure，所以旧安全消息/attempt history 不丢失。

## 兼容调整及版本

首片的“所有Skill≤500”不能直接用于旧 text mock：旧宿主本来接受≤8000 UTF-16的显式合成演示。现在 text manifest 明示 `maxMockInputUTF16=8000`，只在 **provider.mode==mock** 生效；真实网络仍≤500、1024输出tokens、30秒、64KiB、共用selection三次，重试为零。日语/英语的mock也继续≤500。所有输入仍必须先通过原 AISourceSnapshot/typed anchor 校验；不会trim/normalize/修补原文。空白PDF仍被原 `hasConsistentQuote` 拒绝；没有放宽来源或Unicode validator。

原英日 validator 在根schema/引文失败时返回安全 `unavailable` review，旧UI展示可信原句与固定警告，禁止保存。薄适配现在用 `trustedSourceOnly` 区分这一状态，并要求整个 review 与**同一请求的原 validator 空输入fallback逐编码字节完全一致**；不能携带无效组件、译文、模型警告或自造来源。正常候选仍须原 `isPersistable` 检查。根失败不冒充校验成功、不触发二次请求或mock fallback；原 `canSave` 门禁保持不可保存。

| 版本 | 当前值 | 原协议是否改动 |
| --- | --- | --- |
| compiled runtime | 1.0.1 | 只读契约/适配版本；精确匹配，不加载外部runtime |
| 四项 selection Skill | 1.0.1 | 首片1.0.0历史保留；两个批次描述Skill仍1.0.0 |
| text manifest schema | 2 | 明示新增mock-only范围字段；其他manifest schema仍1；未知/错配schema禁用 |
| 英日 envelope validationVersion | 2 | 区分trustedSourceOnly；原native validator代码未改 |
| prompt/result/note文件schema | 原值 | selection-1/deepseek-selection-1/japanese-selection-2/english-selection-1及原结果schema1都不改 |

缓存仍由原 coordinator 管理，envelope只是当前版本的会话视图。固定语言/任务prompt不变，旧cache键已绑定 source/provider/kind/prompt；缓存命中不再次reserve，不能由新Skill领新额度。后续可变prompt/参数仍须独立扩展缓存与执行契约。保存始终解包原 native AIResult/review，通过原手动保存、writer lifecycle、source commit fence及CAS；没有把envelope写入旧文件或覆盖用户正文。

## 精确共享改动与移植边界

四个现存UI model文件的共享点仅 result/review属性同步及 start 内的计划/调用/解包/错误映射；英日/text还在旧Task入口增加generation守卫。**LibraryWorkspace.swift、LibraryModel.swift、四个Workspace视图、全部按钮identifier逐字节未改。** BYOK配置/传输、AppAISession、AI/英日coordinator、native validators、各repository、reader、CI、工程/generator没有修改。

- `AILearningModel.swift`：result didSet＋只读计划/envelope属性；start转交/完成；`savePageResult`、`saveChapterResult`、`save`及其尾部代码与2553edf逐字节一致。主协调的PDF异步保存修复可随后移植，不被本片替换。
- `BYOKSettingsModel.swift`：result属性同步；start转交；安全消息映射。apply/config/key revocation/invalidate行为保留。
- `JapaneseLearningModel.swift`、`EnglishLearningModel.swift`：review属性同步；start转交及完成；save、回跳/强调逻辑未改。
- 基础层自己的 Domain/Services 四文件按上节补兼容；基础层测试更新版本/边界与可信来源-only期望，新增 `ReadingSkillHostIntegrationTests.swift`。

CBR菜单、PDF异步保存、临时UI `b043522`、阅读体验分支均未修改。不占用LibraryWorkspace。若后续整合在AILearningModel产生同文件冲突，仅比较本片 start/property hunks，保留主协调已验收的保存修复；不能整文件替换。本片不验证临时UI整合结果或main正在执行的CI。

## 验证

工具链：Xcode27.0（27A266a）、Swift6.4、arm64 macOS27。所有 fixture/句子/key均自制或既有原创fixture，存储隔离到随机临时目录；HTTP完全注入fake/拦截，无URLSession fallback。没有读取真实书库/key，未执行真实API、桌面App/UI或Simulator运行。重型检查沿用已核实批次 `run-heavy-check.py` 锁、独立新输出、最多2jobs。

| 检查 | 收据 |
| --- | --- |
| Skills + 既有AI/英日/页/spine/来源/保存/额度回归 | PASS：178 tests / 17 suites；包含12项新增宿主集成测试，参数化取消/超时、source/config变化、BYOK撤销覆盖全部case |
| 实际宿主路由 | PASS：翻译/解释/英日返回各自类型envelope；BYOK原官方/HTTPS路径；prepare/未确认不请求、不reserve、不自动save |
| 预算/cache | PASS：实际model翻译1次→cache仍1→英语2→日语3→解释/新BYOK宿主拒绝；没有重复扣、重置或借页/spine/probe池 |
| 来源/晚到/取消 | PASS：排队任务取消不遗留旧计划；text取消/超时、source/config失效、英日provider/source替换、BYOK关闭/地址/key撤销；迟到结果无envelope/保存 |
| 原语义/存储 | PASS：mock8000、remote501拒绝；根失败仅可信来源不可保存；缓存重分析另存新request，旧用户CAS编辑保留；保存函数byte-identical |
| Mac arm64+x86_64 build-for-testing | PASS：unsigned，原app与UI test bundle均构建成功；lipo确认两架构 |
| iOS Simulator arm64+x86_64 build-for-testing | PASS：unsigned，原app与UI test bundle均构建成功；lipo确认两架构 |
| 原52 UI方法/断言/skip/timeout | 源文件逐字节保留；实际UI NOT-RUN |
| source/provenance guard、diff检查 | PASS：659 source files；git diff --check；最终源文件SHA/52 UI逐字节复核 |
| 真实服务/语言质量/费用、真实设备、实际桌面UI | NOT-RUN |
| 累计独立安全专项 | UNVERIFIED；没有重试被拒专项，普通source guard不替代专项 |

首轮一个foundation fixture误把纯空白PDF当有效来源，原PDF validator正确拒绝；已只修正测试期望，没有改validator。最终只澄清了一行适配器注释：计划consent绑定宿主已确认范围；再次178项通过后冻结10个Swift文件的SHA，双端构建与提交复核使用同一版本。中间一轮磁盘不足，未能写入新SHA/启动构建；仅清理首片独立/tmp目录中的可再生mac/ios/swift缓存，保留全部日志与首片收据后恢复。没有清理其他任务或用户数据。

可复现回归：

```sh
python3 "$PDFNO_HEAVY_CHECK" -- swift test --package-path apple/Packages/PDFnoKit --scratch-path "$PDFNO_CHECK_OUTPUT/swift" --jobs 2 --filter 'ReadingSkill.*Tests|AITests|BYOKProviderTests|AppAISessionTests|JapaneseLearning.*Tests|EnglishLearning.*Tests|PDFPageTranslationTests|EPUBChapterTranslationTests|FormatsJapaneseIntegrationTests'
python3 "$PDFNO_HEAVY_CHECK" -- xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath "$PDFNO_CHECK_OUTPUT/mac" -jobs 2 CODE_SIGNING_ALLOWED=NO 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build-for-testing
python3 "$PDFNO_HEAVY_CHECK" -- xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath "$PDFNO_CHECK_OUTPUT/ios" -jobs 2 CODE_SIGNING_ALLOWED=NO 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build-for-testing
python3 scripts/check-native-source.py
git diff --check
```

交付消息链接独立临时目录的日志/最终receipt。本地增量可直接revert，回到2553edf仅基础层状态；没有持久schema变更、迁移或真实用户数据写入。未新增UI验收结果，不替代后续实际UI/并行分支整合和发布批准。
