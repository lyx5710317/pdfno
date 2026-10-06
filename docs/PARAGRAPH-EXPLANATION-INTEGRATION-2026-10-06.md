# 段落解释 Skill 本地候选与整合交接

日期：2026-10-06。此分支将现有 PDF/EPUB 选文“解释”升级为有原文依据的结构化段落解释，完成选文→可见发送确认→解释/推断/引文展示→主动保存→回原文的代码闭环。仅本地候选，未发布、推送、CI dispatch 或合并；实际 GUI 与最后单一整合交给 Mac 体验任务。

## 基线、授权与规范

- 实际起点：`6a67d1fd883f79737d0e3e12c756b683a662f230`；独立持久分支 `feature/paragraph-explanation-20261006`，worktree `../paragraph-explanation-20261006`。未修改 main、原整合树或其他任务树。
- 用户 2026-10-06 07:04 UTC “可以开始工作”，本轮只批准段落解释实现与 Mac 体验并行。此处不操作桌面 App/GUI，不增加论证提纲、学习卡片、账户或依赖。
- 核验 CONTRIBUTING、v0.3 native spec、ADR 0010、Skills foundation/host/roadmap 及实际源码。仓库与相关父目录没有 AGENTS.md；`.agents/skills` 不存在。
- 离线规范真实路径 `../reading-skills-offline-20261006/experiments/reading-skills-offline/`，实际 HEAD `1a6b0375038a9e739b54b5001bbdd13fe4b7f5f5`。仅采用 SPEC/INTEGRATION/common 与 paragraph schema/prompt 中的段落部分，没有整批导入其他未实现任务。
- 新增源码/测试保持 AGPL SPDX；原创样例、虚构凭据、独立临时数据，没有用户书籍、key 或真实 API 调用。安全专项仍为原 UNVERIFIED/platform-blocked，不重试。

## 实际功能边界

| 项目 | 此候选行为 |
| --- | --- |
| 原入口 | 原“选文解释” picker/accessibility ID 及工具路由保留；工具目录说明为“段落解释”。没有第二个同义按钮。官方 DeepSeek 与独立 HTTPS BYOK 两身份继续各自配置/确认。 |
| 任务身份 | `pdfno.reading.paragraph-explanation`；Skill 1.0.1 / manifest schema 1 / result schema 1 / prompt `paragraph-explanation-1`；runtime 仍 1.0.1。 |
| 来源 | 仅现有 PDFKit PDF 与 Kookit EPUB 的真实固定选文；≤500 UTF-16，整页/spine、其他格式、OCR、自动补文均未接入。来源语言不作检测或质量声明，输出仅 zh-Hans。 |
| 输出 | complete 时 1–3 个释义/术语/模型推断项，最多6条引文，每项180 UTF-16、引文120 UTF-16、每项1–2个依据；通常只请求一条简短释义。推断必须 tentative；支持 insufficient_evidence 的空结果。 |
| 预算 | 原 `AppAISession.selection` 共享3次；1024输出 tokens（含 JSON/引文）、30秒、64KiB，0自动 retry。旧翻译/legacy mock 8000 seam 不改；结构化解释 mock 也限500。页/spine预算不借用。 |
| 确认 | 原文全文、UTF-16、任务、接收方域名/完整路径/模型、费用/额度说明和确认控件可见；准备/预览/配置不发请求，用户勾选后点击开始。 |
| 故障降级 | 异常/重复字段 JSON、未知字段、错 quote/ref/span、bool冒充整数、tool/function call、截断一律安全失败，不修 JSON，不返回不受验证的旧 plain text，不自动换模型或加额度。证据不足可读但不可保存/缓存。 |
| 来源回跳 | 引文 scalar 范围经 exact quote + Character边界转换为 UTF-16。EPUB 回到真实 resource/spine 内的子范围（保留 edition/hash/extraction），不搜索第一个重复词；PDF 返回原始 verified selection regions，不从字符偏移捏造子矩形。原生返回仍核验真实 PDF/DOM。 |
| 保存 | 只有点击保存才写原 `learning-v1.json`；保留用户正文、requestID幂等、既有 CAS/备份/写入gate。原有 EnglishLearningSourceCommitFence 在实际事务处核验原件哈希/存在、撤销与 writer epoch；没有第二套任务/仓库。 |
| 生命周期 | 请求前后/缓存入库检查精确来源与配置；取消/超时/切书/会话或版本变化/非nil新选区使旧响应不能发布或保存；保留可读旧结果与按来源字节区分的草稿。焦点转到面板的 nil 选区不误判为新选区。重复 start/save 在进行中不并发写入。 |
| 已存笔记 | 原会话结束后仍可读、编辑、搜索、备份恢复。同版原书的已存解释可再回跳，但继续核验真实 quote/geometry/DOM；不能把旧会话响应重新当作可生成/保存的当前结果。 |

1024 tokens 对完整三项结构不保证够用，因此固定 prompt 默认一条短释义，术语和推断可省略；输出触顶直接报截断。未提高权限或预算，也未验证任何真实服务的结构成功率、解释质量或收费。

## 旧 plain explanation 与存储兼容

`AILearningKind` 仍是 translate/explain。新增的是非持久化 `AIRequest.profile`，默认 `.legacy`；旧直接 provider 请求、`selection-1`/原 DeepSeek prompt、plain 记录读取与显示规则保留。两个选文宿主的 `.explain` 新请求使用 paragraph profile，adapter/envelope 才携带 typed paragraph，旧工具不增加独立按钮。

持久 AIResult/AILearningNote/AILearningState 的字段与 schemaVersion 均未改变；结构 JSON 位于既有 `text` 字段，通过新 promptVersion 区分并在读/写时重验。UI、请求记录、已存搜索用 `displayText` 显示释义和引文，正文编辑不重写 AI 字段。旧 records 与新 records 在本版本同文件往返/备份恢复已测。

回滚到不认识新 promptVersion 的旧二进制不能解释新记录，会按原严格校验关闭整份文件的写入，而不默默删除新记录。若实际部署后需回滚，应另审备份/恢复方案；本候选未迁移或自动恢复用户文件。不要把“当前版本可读旧记录”当作“旧二进制认识新结果”。

## 模块与最小接线

新独立模块：Domain `ParagraphExplanation.swift`，Services `ParagraphExplanationPrompt.swift`，UI `ParagraphExplanationResultView.swift` 与 `LibraryModel+ParagraphExplanation.swift`。复用 ReadingSkillRegistry/Plan/Envelope/SelectionAdapter、AIJobCoordinator、原 DeepSeek/customBYOK transport 与现有存储 fence。

共享文件变更：

- `AIContracts` 仅增加默认 legacy profile 和 prompt identity；registry/plan/envelope/adapter 登记新结果，coordinator 增加验证/当前来源缓存入库检查；不新建模型任务系统。
- `AILearningRepository` 新 prompt验收及可选既有事务fence；`LibrarySearchRepository` 显示可读结果，不改变文件协议或 CAS。
- `AILearningModel` / `BYOKSettingsModel` 接新 profile、typed result 与旧响应/重复保存防护；配置和 prepare 比较用已有 `ReadingSkillIdentity` 精确编码字节，Swift的规范等价字符串不能重用确认。
- `LibraryModel.swift` 只有149–160附近四个既有回调追加：EPUB scope、PDF session、两个真实选文 sink 的 paragraph失效。新原生验证/fence职责在 extension，不改原阅读导航。
- 选文/BYOK结果与确认视图少量接线、工具目录说明，新增4项 UI方法及既有 DEBUG offline transport 场景。未碰 LibraryWorkspace、EPUBWorkspace、PDFnoTemporarySettingsLayout、EPUBReaderSession、engine-build/reader.js、EPUB engine.js 或 EPUBWebKitTests。

Mac 任务负责 EPUB保存后同词重选 noteSelection 修复及导航行命中：与此处逐项职责不同，均需保留。最后只在 Mac 任务树串行整合，不覆盖其事件/选区更新。最小 `LibraryModel` callback patch、完整宿主 UI patch、完整单提交 patch 和证据均放独立 `.build/ParagraphExplanationEvidence/2026-10-06/`（不作为产品源码发布）。完整候选提交是功能整体；callback patch只用于共享点审阅，不能单独替代所有依赖。

## 离线验证与构建

工具链 Xcode 27.0 (27A266a)、Swift 6.4、macOS 27 arm64。重型命令均经过已有 `../pdfno/.build/UIDataEnglishRecovery/2026-10-05/run-heavy-check.py` 同一 flock（script SHA256 `6a0791c963524ec40e9525e812b0945163b029c5941548bb9d4041bc6395d033`）；使用2 jobs与独立 `/tmp/pdfno-paragraph-20261006` 输出，未清理其他输出或锁。

- 段落测试：21个方法，含参数化 Unicode组合字/ZWJ/flag/CRLF、引用类型/边界/重复词、异常JSON、范围与同意、共享第三次/第四次/缓存、不足与截断、两身份拦截HTTP、取消/超时非协作迟到、重复开始/保存、手改/CAS/草稿、事务撤销/替换原件、搜索/备份恢复、旧记录、异步保存来源变化、同视觉不同字节、已存原生PDF跨会话回跳。
- 最终相关回归：276项/27 suites（最终日志与 receipt 为准），覆盖既有翻译/DeepSeek/BYOK/AppAISession、日语/英语、页/spine、格式联动、来源一致性、正文编辑、写入gate、恢复、搜索与临时布局。所有模型响应为 mock/拦截；原生 PDF/未附着 WebKit 与布局 suite 的不显示 NSWindow 是离线组件验证，不是桌面 GUI验收。
- `scripts/check-native-source.py` 与 `git diff --check`：最终结果见 receipt。未改engine资源，不运行npm安装或无关Node重建。
- Mac arm64+x86_64 `build-for-testing`，独立 DerivedData，`CODE_SIGNING_ALLOWED=NO`，编译原56及新增4项UI；最终日志记录 TEST BUILD SUCCEEDED。只编译，不启动App或执行GUI。此前新增回跳测试失败因未先load书库，补齐前置条件后通过；未删断言或改旧测试。
- 未在此处跑完整520基线全套；唯一整合者须在合并候选后跑全套。未跑mobile；真实服务、语义质量、VoiceOver/真实设备不由mock替代。原安全专项 UNVERIFIED/platform-blocked 保持。

复现相关回归：

```sh
python3 ../pdfno/.build/UIDataEnglishRecovery/2026-10-05/run-heavy-check.py -- swift test --package-path apple/Packages/PDFnoKit --scratch-path /tmp/pdfno-paragraph-20261006/swift --jobs 2 --filter 'ParagraphExplanationTests|ReadingSkillFoundationTests|ReadingSkillHostIntegrationTests|AITests|DeepSeekSelectionTests|BYOKProviderTests|AppAISessionTests|JapaneseLearning.*Tests|EnglishLearning.*Tests|PDFPageTranslationTests|EPUBChapterTranslationTests|FormatsJapaneseIntegrationTests|NoteEditingTests|LocalStoreWriteGateTests|LocalRecoveryTests|LibrarySearchTests|PDFQuoteConsistencyTests|TemporaryAILayoutTests|RecoveryEnglishIntegrationTests'
python3 ../pdfno/.build/UIDataEnglishRecovery/2026-10-05/run-heavy-check.py -- xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'generic/platform=macOS' -derivedDataPath /tmp/pdfno-paragraph-20261006/mac -jobs 2 CODE_SIGNING_ALLOWED=NO 'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO build-for-testing
```

## 交给唯一整合者的实际 UI 待执行清单

此处只编译，以下4项 NOT-RUN，不能计入UI通过：

1. `ReadingIntegrationUITests.testMacParagraphTypedEvidenceConsentManualSaveAndSource`：PDF选文→接收方/全文确认→三类标签→引用→输入独立正文→手动保存→返回原选区。
2. `testMacParagraphInsufficientAndInvalidResponsesCannotSave`：insufficient、invalid、truncated三场景，分别显示安全状态且不能保存。
3. `testMacParagraphCancelDoesNotPublishOrSave`：slow替身→取消→无迟到结果/保存。
4. `testMacParagraphEPUBCitationReturnsToCanonicalRange`：实际WebKit选择window→解释→依据→回到原资源位置，无EPUB错误。

原56 UI测试方法正文与基线逐字节比较不变，未改原断言、timeout、skip或焦点步骤。只给原 `app()` helper 加默认nil可选 paragraph scenario，并新增helper/方法。保存/来源按钮在ScrollView外时，新helper滚到真实可点击位置；这部分仍需实际隔离GUI调试，不能仅凭build通过声称命中正确。EPUB方法的精确scalar→UTF16期望由Domain重复词/Unicode测试覆盖；实际UI步骤仍需整合者确认。

### 隔离运行配置

不要在当前用户运行此处常规bundle `org.pdfno.PDFnoMac` 的XCTest。必须用整合者已经核验的独立 app、独立runner 与 ad hoc签名构建，或专用CI/VM/OS用户。不能仅换数据root却使用会终止用户同bundle App的runner。

- 独立 App bundle ID 必须是实际构建注册的 `org.pdfno.integration.*`；runner的 `EnvironmentVariables.PDFNO_ISOLATED_UI_APPLICATION_ID` 设置为同一值，`UITargetAppBundleIdentifier`/target path也必须指向该隔离App。helper只在此prefix下允许显式bundle启动。
- DEBUG构建下，每个方法helper自动设置全新 `PDFNO_UI_TEST_SESSION` UUID、`PDFNO_UI_TEST_DEEPSEEK=offline` 与 `PDFNO_UI_TEST_PARAGRAPH_RESPONSE`。有session时源代码选择隔离临时root；本轮不会访问真实书库。不要复用用户已有session目录。
- UI虚构密钥固定 `synthetic-reading-ui-credential`，transport完全拦截且无 URLSession fallback；不输入真实key。prepareParagraph通过设置窗口选官方DeepSeek，仅为验证原确认界面和既有预算通路。
- 单独执行4个 `-only-testing:PDFnoMacUITests/ReadingIntegrationUITests/<method>`，`-parallel-testing-enabled NO`、独立resultBundle、共享heavy锁。此候选的普通未签名build产物只用于编译证据，不适合直接 test-without-building。
- 实际CUA若不跑XCTest：隔离App启动时同样设置session/offline，typed场景按上述PDF与EPUB动作；每个不足/错误/截断/slow场景重新启动新UUID。仍需实际系统AX可见确认与手工保存/回跳观察。切书/EPUB重排后旧未存结果可读但不能新保存，重选重新确认；已存正文编辑保留。

当前尚未完成：最后单一整合、上述真实隔离GUI、新功能真实服务结构成功率/解释质量。候选可交接，不宣称已发布或已通过实际UI。
