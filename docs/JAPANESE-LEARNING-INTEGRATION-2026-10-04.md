# 日语选文学习整合候选 · 2026-10-04

独立分支 `feature/integration-japanese-learning-20261004`，worktree `worktrees/integration-japanese-learning-20261004`（位于主 checkout 的同级 worktrees 目录），从已验收主线 `71d54540c417915702506f67fef7d337605aa9e2` 建立；首片 `fb8aee9a2513e5d0a94f5012b2030a7e63c491c4` 已 cherry-pick 为本地 `83aa3e6`。交付 SHA 为随本报告提交的 HEAD。此候选只本地提交，未 push/merge/main/Library；主线既有 CI 不构成本候选的验收。

## 可用流程与实现边界

Mac PDF/EPUB 阅读器底部新增“日语选文学习”。点击固定现有 `captureAISource()` 原生来源后，独立 sheet 显示原文、定位、接收方、范围/额度/费用、确认框。手动确认并点击开始才运行。沿用 AILearningModel 已保存的非秘密配置、当前临时 session 凭据引用、同一 transport 和同一个 AppAISession.selection；factory 本身不读密钥、不发送。配置/密钥缺失或配置不受支持时明确拒绝，不隐式切换 mock。用户明确配置 mock 才使用离线演示。

读音候选、中文译文、中文语法解释、句子成分、警告、用户假名修正与独立正文分别展示。新分析不覆盖用户草稿/修正；相同来源重开保留当前结果。换书、格式切换、真实替换选区、reader session、EPUB 重排/文档版本、AI 配置/密钥变化取消旧 scope；聚焦审阅 sheet 导致选区 nil 不丢失固定来源。开始、完成、保存均验证当前 scope；异步凭据读取或额度等待取消后不再提交。非合作迟到输出由 coordinator continuation 与 model generation 双重隔离。

点击“保存审阅后的学习记录”才创建新的独立记录。重启可从当前书的“高亮与笔记”查看；无 session key 也可查看已保存内容和手动回到原文。使用原生 return pipeline 核对书籍、版本/hash/extraction、逐字 quote、资源及几何；不猜测最近位置。保存前 EPUB 还做 canonical chapter anchor 校验。来源失效时显示未跳转提示，仍可审阅记录。生成结果不触碰原书、不创建用户高亮、不覆盖任何旧笔记。

## 成分分色与范围契约

| role | 展示 | 含义 |
| --- | --- | --- |
| subject | 蓝色 · 主语 | 主语候选 |
| predicate | 红色 · 谓语 | 谓语候选 |
| object | 绿色 · 宾语 | 宾语候选 |
| attributive | 紫色 · 定语／修饰语 | 修饰成分候选 |
| adverbial | 橙色 · 状语 | 状语候选 |
| topic | 青色 · 主题 | 与日语主语分开审阅 |
| other | 正文色 · 其他结构 | 未归入上述角色的候选 |

颜色只应用于审阅视图的固定原句。提供文字标签/颜色名称的可访问图例，点击有色片段或成分按钮切换中文解释；解释、状态和原文可被辅助技术读取。支持浅/深色 palette，不能仅凭颜色理解结果。数学检查12组 RGB 在代表性分组背景（浅灰0.94、深灰0.17）上的文本对比度为5.65–9.19:1；该检查不替代实际 SwiftUI link tint、显示、VoiceOver 与布局验收。

同一角色同一跨度重复项排除并 warning；不同角色重叠、嵌套保留为独立候选。原句只显示一个不重叠层，默认从左到右选较外层；选中候选优先显示，其余冲突项仍在列表中可选，不混色或虚构范围。省略成分必须 `omitted:true`、`certainty:ambiguous`、quote/start/end 为 null、prefix/suffix 为空；仅显示推测解释，不在原句中插入或涂色。主题不自动当作主语，置信标记不构成准确率承诺。

wire JSON 根仍为 schemaVersion1、language ja、sourceQuote、offsetUnit unicode-code-point、translationZh、readings、grammar、warnings，新增可选 components 数组（最多16）。新提示词版本 `japanese-selection-2` 要求 components；缺失时兼容旧读音/语法输出，显示无可验证成分。每条 components 固定字段：id、role、quote、start、end、prefix、suffix、certainty、omitted、explanationZh；未知字段/非法角色/布尔或小数 offset/错误 boolean 拒绝条目，超过总数组限额或错误根结构降级为不可保存的可信来源审阅。

所有非省略跨度使用选文内 Unicode scalar 半开范围 `[start,end)`，quote 必须 byte-exact，紧邻 prefix/suffix 核对重复词上下文。还须通过 Character 边界校验，保留 IVS、组合假名、surrogate pair、肤色/ZWJ emoji；不 normalize/trim、模糊匹配、修复 offset 或取第一次命中。投影拼接保持原文 UTF-8 字节。合法范围不证明语言或角色判断准确；不确定结果保留候选和警告供手动审阅，无效输出不展示原始模型文本。

成分分析在同一日语请求内完成，没有额外 API/额度。选文最多500 UTF-16，非流式、关闭思考、JSON 输出最多1024 tokens，最长30秒，响应最多64KiB，与选文翻译/解释共享3次发送尝试。失败和取消消耗已提交的尝试，客户端不保证金额上限；无自动重试、成功缓存或追加上下文。仅发送本次 sourceText 与 task，不发送私库/书籍标识、文件路径、几何、选文外上下文、ruby、旧笔记、用户草稿或修正。没有新字典、模型或依赖。

## 独立存储与最少共享改动

`japanese-learning-v1.json` schemaVersion1：notes 中保留 note UUID、immutable review（来源、provider、promptVersion、readings/grammar/components/warnings）、userText、corrections。读盘有5MiB/1000条限额、递归字段白名单和重复 JSON key 拒绝；Codable 后再次验证来源、prompt1/2、逐字 span、角色/省略一致性、唯一 ID 与用户修正。旧 prompt1 且没有 components 的日语记录可读。未知未来 schema、篡改范围或损坏文件拒绝读写，既有内容不被悄悄覆盖。

事务由私有全进程 actor 串行，覆盖多窗口/多个 repository 同时 append。保存前对既有有效 manifest 写 `.backup`，再 atomic 写新文件；备份失败保留当前 manifest 与草稿。相同稳定 note ID/相同字节幂等确认，不重写；相同 ID 内容变化或相同 requestID 换新 note ID 拒绝，避免覆盖与重放。没有普通笔记编辑器更新入口。该实现不声明跨进程锁或灾难恢复；备份不自动加载。session secret 从不进入持久 DTO。

共享触点集中如下：

- `AILearningModel.swift`：同 owner BYOK factory 与 scope invalidation 回调；保持旧 AIRequest/AIResult/AILearningKind、旧 repository 与额度协议不变。
- `LibraryModel.swift` + 新 `LibraryModel+JapaneseLearning.swift`：独立 repository/学习模型、选择/会话订阅、保存前核对与原生来源返回；测试 transport 注入使用全新合成根目录。
- `LibraryWorkspace.swift` / `EPUBWorkspace.swift`：阅读器底部入口、独立 sheet、只读已保存日语记录。旧 AI toolbar 未增加拥挤动作。
- `OfflineSelectionUITestTransport.swift` / `NativeUITests.swift`：UUID 隔离且明确 offline 的 Debug transport 合成响应、成分切层/省略和错误/取消场景。原有30条 UI 用例代码完整保留，新增3条。

未改格式/解码引擎、reader资源、Bookno、外部依赖、Package.swift、Xcode工程或既有 library-v1.json/epub-v1.json/learning-v1.json schema。离线测试以原始 fixture 验证旧 manifest 和原书字节不变；没有访问当前用户 App、密钥或私人书库。

## 验证与待验收

最终本机结果如下（arm64 macOS27/Swift6.4，Mac deployment14、iOS deployment17；编译不证明最低系统实际运行）：

| 检查 | 结果 | 本机证据 |
| --- | --- | --- |
| 最终轻量目标 | 44 tests / 4 suites 通过，无 warning/error | `/tmp/pdfno-japanese-components-light.log` |
| 最终相关宿主回归 | 84 tests / 12 suites 通过，其中日语50项 | `/tmp/pdfno-japanese-regression.log` |
| Mac build-for-testing | TEST BUILD SUCCEEDED，编译所有33条 UI 测试代码 | `/tmp/pdfno-japanese-mac-build.log` |
| iPhone/iPad simulator build | BUILD SUCCEEDED | `/tmp/pdfno-japanese-mobile-build.log` |
| 源码守卫 / 需求账本 | 353个文件通过 / 8 tests 通过 | `scripts/check-native-source.py` / `scripts/test-requirement-ledger.py` |
| 保留范围与颜色数学检查 | 旧30 UI 方法原文、冻结协议/账本、reader/工程/旧仓库保持；12组 palette 对比度通过 | `/tmp/pdfno-japanese-integration-preservation.log` / `/tmp/pdfno-japanese-palette-check.log` |

Mac 构建仅有两处原有 UI 测试 `broken` 未使用变量 warning 与 AppIntents metadata 提示；未改动这些原用例。mobile 仅有 AppIntents metadata 提示。没有新日语源码 warning/error。全部只用假凭据和离线 transport，未执行真实API或 actual UI。最终 `git diff --check` 通过。

以下命令用于本独立 worktree，并按顺序运行编译，使用单作业和独立 /tmp 缓存。SwiftPM 正常 sandbox 保持启用。实际 PDFKit 和 EPUB 测试仅用自有临时根目录与原始 bundled fixture；EPUB 使用不显示的 NSWindow，未启动用户 App。

```sh
python3 scripts/test-japanese-learning-light.py
swift test --package-path apple/Packages/PDFnoKit --scratch-path /tmp/pdfno-japanese-integration-swift -j 1 --filter 'JapaneseLearning|AITests|DeepSeekSelectionTests|AppAISessionTests|AuditFunctionalTests|LibraryIntegrationTests|EPUBChapterWebKitTests|TextChapterIntegrationTests'
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/pdfno-japanese-integration-mac -jobs 1 CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS=-j1 build-for-testing
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/pdfno-japanese-integration-mobile -jobs 1 CODE_SIGNING_ALLOWED=NO OTHER_SWIFT_FLAGS=-j1 build
python3 scripts/check-native-source.py
python3 -B scripts/test-requirement-ledger.py
git diff --check
```

覆盖严格输出/跨度/上下文/歧义、省略/重叠/重复/Unicode、共享额度、取消/超时非合作迟到结果、异步假凭据取消、明确开始/手动保存、备份失败、同进程并发、旧 schema 字节、PDF 来源保存重启返回、实际原始 EPUB ruby base canonical selection 与重排取消、版本/引文篡改拒绝，以及受影响旧选文/搜索/章节宿主回归。离线 fake credentials 和 intercepted transports 不触发真实 API、Keychain、用户密钥或外部字典。

仍未验收/接入：完整日语语言质量与语料、真实服务/TLS/账单、英语语法、全文注音、作者 ruby 的选文内 metadata 导入、词级原生强调、浮动选文菜单、移动端入口、日语记录的普通编辑/搜索/删除/导出/Bookno。作者 ruby 保持原生渲染并排除于 canonical 发出原文；当前宿主未读取 rt 自动填入 authorReadings，不能将生成读音当作作者内容。actual UI33、浅/深色显示、点击片段 link tint、VoiceOver/窄窗口仍须隔离 CI/人工验收。本机 build-for-testing 只证明编译，未运行 UI。

本候选的 R06/S03/J03/UAT02 仍为部分覆盖；未改83项需求定义或冻结 auditBaselineAssessment，未将编译/离线测试写成“完整日英学习已验收”。独立安全专项仍 **UNVERIFIED / platform blocked**，未重试或绕过。没有新增权限流程或真实网络检查。
