# 英语结构化选文学习切片

日期：2026-10-05。固定基线：`7bea8ec89ea7273b3b52ee714fbf1180b3d51c73`。分支：`feature/english-grammar-20261005`。本片只新增独立模块与原创离线测试；主界面入口、共享记录搜索/编辑、删除恢复/备份和会话生命周期由本批整合候选接线。没有修改日语契约、既有存储、BYOK、AppAISession、LibraryModel、布局、工程/generator、CI 或既有 50 项 UI 测试。

## 实际范围

`EnglishLearningRequest` 接受固定 PDF/EPUB 选文 `AISourceSnapshot`，拒绝页/章来源、空/失效来源、超过500 UTF-16、无效服务或超过30秒的请求。`EnglishLearningReview` 包含原始快照、原选文 UTF-8 SHA-256、provider/generation、`english-selection-1` prompt、状态、自然中文译文候选、中文结构解释和固定警告。原句/不可变 review 与 `EnglishLearningNote.userText` 分开。

英语角色是 subject/predicate/object/complement/attributive/adverbial/other。补语/表语保持独立标签；英语没有冒用日语 topic。语法维度是 clause/tense/voice/reference/coordination/longSentence，包含被动施事与语法主语的区分、并列分句、关系从句、过去完成时、指代歧义和长句主干说明。所有内容都是待核对候选。

`LocalMockEnglishLearningProvider` 只对八条原创固定语料给出预写候选：主动、被动、并列、嵌套关系从句、duck 词性歧义、祈使省略、重复 read 和复合长句。未知选文没有猜测解析，只保留原句和明确的合成演示警告。它不是本地英语解析器。`OfflineEnvelopeEnglishLearningProvider` 只调用显式注入的离线 fake transport；模块没有 URLSession、key 输入/读取/存储、额外生产计数器或自动请求。

`EnglishLearningPrompt.system` 提供英文专用结构/时态/语态/指代/长句提示词；`userContent(for:)` 只返回固定 sourceText 和任务，不含书目、书ID、几何、选文外上下文、用户正文或历史。`DeepSeekEnglishLearningProvider(transport:credentials:credentialReference:aiSession:)` 已实现真实请求适配代码，仅由宿主既有权限 owner 注入；`aiSession` 参数必须明确传入与 AILearningModel 相同的实例，没有默认新owner。它直接使用 `aiSession.selection`，只接受已有官方DeepSeek配置门禁并使用既定finalURL/model。请求 `stream:false`、`thinking:disabled`、`response_format:json_object`，固定选文和system prompt两条messages；不增加凭据持久化。先验证input/config，再读注入凭据，异步读返回后再次检查取消，然后保守reserve共享尝试，提交前再次检查取消。沿用500 UTF-16、1024输出tokens、64KiB、30秒、三次共享尝试和手动费用确认。失败/取消/超时不重试、不回退mock、不重置额度。本片只以fake凭据/完全拦截transport执行该真实适配器代码；没有真实请求或质量证据。主界面/BYOK factory仍由整合线程接入。

## Unicode 与失败降级

组件/语法的 `EnglishSpan` 保存零起点 Unicode scalar/code point `[start,end)`、quote、紧邻 prefix/suffix。必须逐 scalar/UTF-8匹配本次选文，并处于 Character 边界；不会 split 组合字符、IVS、surrogate/ZWJ/肤色 emoji 或 CRLF。UTF-16 投影通过已有 `UnicodeOffsets` 再次校验。每侧上下文最多32 code points；重复短语的上下文必须能唯一地区分当前出现位置。没有 trim/normalize、模糊匹配、偏移修补或第一次出现回退。

允许重叠/嵌套候选。投影只显示一层，选中项优先，其他候选继续列出；所有 runs 拼回原选文的 UTF-8 必须完全一致。component 点击仅选择当前候选并下划线强调，URL action 拦截为内部选择，不开外部URL，不保存批注，不改 reader 原文。

`omitted` 与 `inferred` 是显式独立字段。所有省略项必须 inferred；所有推断项必须 ambiguous、没有 quote/start/end/span 和上下文，不能被涂色。原文明确但语义不确定的候选保留合法范围和“不确定”标签。

根输出必须严格 schema1/language en/offset unit/字段集合/类型/完整原文。重复JSON键（包括转义键）、未知字段、错误类型、数量或长度超限、畸形JSON降级 `unavailable`，只保留可信来源和固定警告，不展示无效原响应，不允许成功保存。单条无效组件/语法排除并附固定警告，其余可审阅；同ID和同角色同范围重复排除。

Envelope 拒绝非单个 assistant、非完整 stop、tools/functions/refusal、未知字段/类型、重复成员和超过64KiB；`finish_reason:length` 或报告 completion_tokens >1024 是 truncated。正文超过16000 UTF-16同样拒绝。usage 接受并严格验证官方 [缓存命中字段](https://api-docs.deepseek.com/guides/kv_cache/) `prompt_cache_hit_tokens` / `prompt_cache_miss_tokens`，没有为了兼容忽略未知字段。1024是模型请求的候选输出上限，不是账单保证；本模块没有本地 tokenizer，不声称可根据字符数证明真实token数。JSON太长时必须减少候选并完整返回，不能扩大请求预算或接受截断JSON。离线预写语料不代表实际模型的token、费用或质量证据。

## 颜色与独立界面

`EnglishSentenceComponentsView` 使用与现有日语完全一致的实际 sRGB，并附中文成分名称和颜色名称，颜色之外保留候选/不确定/省略/推断文字。

| 角色 | 浅色 RGB | 深色 RGB |
| --- | --- | --- |
| subject 蓝 | 0.02,0.25,0.55 | 0.40,0.67,1 |
| predicate 红 | 0.65,0.08,0.12 | 1,0.48,0.54 |
| object 绿 | 0.03,0.36,0.14 | 0.62,0.87,0.60 |
| attributive 紫 | 0.40,0.17,0.60 | 0.81,0.61,1 |
| adverbial 橙 | 0.55,0.24,0.02 | 1,0.75,0.40 |
| complement/other | SwiftUI primary + 标签 | SwiftUI primary + 标签 |

`EnglishLearningWorkspace(model:returnToSource:)` 按注入配置区分“离线合成演示”与远程固定选文AI；远程预览接收方/模型、500/1024/30秒限制、共享尝试次数和失败/取消可能收费。确认来源、接收方、模型、费用和范围后才手动开始。打开、prepare、换书、换provider/generation、再分析都不自动发送或写盘。更换来源/配置/替身、取消、超时或关闭取消工作并挡住迟到结果；完成时再次询问宿主 `sourceIsCurrent`。没有保存或来源回跳 callback 时相关按钮禁用，不伪造成功。未经验证结果仅显示可信原句/警告。未执行桌面 UI 或真机测试，不宣称视觉/无障碍实测通过。

## 持久化、备份与删除恢复 seam

公开接口：

```swift
EnglishLearningRepository.filename // "english-learning-v1.json"
EnglishLearningRepository.maxBytes // 5 * 1024 * 1024
EnglishLearningState(notes: [])    // schemaVersion == 1, 最大1000条
EnglishLearningRepository.decode(_ data: Data) throws -> EnglishLearningState
EnglishLearningRepository(root: URL)
repository.load() async throws -> EnglishLearningState
repository.saveNote(_ note: EnglishLearningNote) async throws
repository.updateNoteBody(expected: EnglishLearningNote, text: String) async throws -> EnglishLearningNote
```

书关联为 `state.notes[].review.source.bookID`；来源含 edition、fileSHA256、reader session/version 与强类型 PDF/EPUB anchor。备份/恢复适配器应先 `decode`，读关联bookID，使用 typed notes 过滤/组合后再 encode+decode；任何未知字段、未来版本、损坏、重复note/requestID、无效source/hash/prompt/status/span/context、原文或用户正文字节变化都不能静默放过。不要把该文件误纳入旧 learning schema。

同进程各 repository 实例通过私有 file gate 串行同步事务，写前完整重验 candidate 和旧文件。先原子写上一版 `.json.backup`，再原子替换 manifest；失败保留旧manifest与用户草稿。相同稳定 noteID 和全部字节相同的重放不改文件或backup；同ID不同正文或同requestID不同noteID拒绝。正文编辑是 CAS：`expected` 全部编码字节必须与当前记录一致，只改 userText，保留review/quote/source/hash，单正文最多16000 UTF-16。再分析得到新review/requestID，不能覆盖旧用户编辑。

本 repository 只知道固定快照，不能独立证明当前书还在书库/Originals，未提供跨进程锁或删除/恢复全文件事务。整合线程必须让保存/编辑/删除恢复/备份通过同一宿主 writer lifecycle/暂停门，并在获得写入权后再次核对 book/source。不能仅凭模型一次同步 `sourceIsCurrent` 守卫来保证异步期间来源未删除。

## 宿主整合触点

`EnglishLearningModel(provider:sourceIsCurrent:saveReviewedNote:)` 不持有书库/key/额度，仅从注入provider读取已有尝试数用于展示。宿主BYOK factory按配置注入 `LocalMockEnglishLearningProvider` 或 `DeepSeekEnglishLearningProvider`，远程参数复用当前transport/credential reference/同一AppAISession；缺key/config采用 `UnavailableEnglishLearningProvider`，不得自动mock。`prepare(_:provider:failure:)` 在固定来源、读者会话/版本、选区、换书、服务/凭据generation或关闭时调用；替换provider也使确认revision失效。宿主返回每个来源/配置是否仍有效。保存 callback 必须重验并使用独立repository；来源回跳 callback 必须走原PDF/EPUB的已有native校验，错误书/缺失源返回失败，不能猜位置。`currentSourceForReturn()`/`emphasisSource(for:)` 只返回已核验快照；句子组件点击默认不调用宿主强调。

共享 SavedRecord/search/editor 接线由整合线程实现：stable noteID；原句和 immutable review为只读；可搜索 userText、quote、translationZh、component/grammar explanation及角色标签；用户正文更新用上述CAS。不要将草稿或无效原响应进入已保存索引；该切片没有修改现有 `RecordBodySnapshot`、kind白名单或Bookno导出规则。

## 验证与限制

工具链：Xcode27.0 (27A266a)、Apple Swift6.4、arm64 macOS27，Python3.9.6。重型检查使用本批共同 `run-heavy-check.py` 串行锁与 `--jobs/-jobs 2`。本片独立 scratch/cache/derivedData/logs 位于批次的 `english-evidence`；不在Git中保存构建产物或机器私人绝对路径。

专项命令：

```sh
CLANG_MODULE_CACHE_PATH="$PWD/../english-evidence/ModuleCache" SWIFTPM_MODULECACHE_OVERRIDE="$PWD/../english-evidence/ModuleCache" python3 ../run-heavy-check.py -- swift test --package-path apple/Packages/PDFnoKit --scratch-path ../english-evidence/Package --cache-path ../english-evidence/Cache --jobs 2 --filter EnglishLearning
python3 ../run-heavy-check.py -- xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath ../english-evidence/Mac -jobs 2 CODE_SIGNING_ALLOWED=NO build
python3 ../run-heavy-check.py -- xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath ../english-evidence/Mobile -jobs 2 CODE_SIGNING_ALLOWED=NO build
python3 scripts/check-native-source.py
git diff --check
```

首次默认cache和嵌套manifest sandbox编译失败；在工具授权的编译权限、独立cache下成功。没有自动审批拒绝，也没有重试独立安全扫描。最终冻结源码验证：**48项英语专项＋53项相关日语/共享会话回归，共101项/11 suites通过**（2.464秒）；Mac arm64 与 iOS Simulator arm64/x86_64 两端 `build` 通过，均 `CODE_SIGNING_ALLOWED=NO`。source guard检查626个源文件通过，diff --check通过。现有UI两文件与基线字节完全一致，分别46＋4项；没有运行这些桌面UI测试。日志为 `english-evidence/verified-tests.log`、`verified-mac.log`、`verified-mobile.log`，命令及exitCode在 `final-command-receipt.json`，UI原字节hash在 `ui-preservation.json`。

仅使用自制选文、synthetic PDF anchor、fake transport和临时store。原50项UI测试逐字保留，本片不运行桌面UI/XCTest用户会话，不启动应用或模拟器，不读用户书库/真实key，不做真实请求、不改签名/云账号/服务权限，不push/merge。真实服务/账单/语法质量、实际PDF/EPUB阅读选区到该新入口的UI闭环、两端布局/VoiceOver、真机/最低系统/Intel、跨进程/崩溃/文件提供者恢复未验证。独立安全专项仍 `UNVERIFIED / platform-blocked`，source guard仅是来源/边界检查，不冒充安全验收。

回滚：撤掉整合入口后保留 `english-learning-v1.json` 与backup，旧构建忽略而不删除该独立文件。不可丢弃用户正文或把英语review迁入旧learning/japanese schema；不要恢复覆盖主书库或原书。
