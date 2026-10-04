# 日语选文学习首片与整合契约

本地独立候选：`feature/japanese-learning`，基线 `f3ed484fee815effed2d955f8eb21bcd66d8546e`。只新增模块、原创离线测试、轻量检查脚本和本文件；没有修改已有文件、主分支、Bookno/CBR/CB7 工作树、LibraryWorkspace/LibraryModel、格式引擎、Package.swift、Xcode 工程或原有笔记 schema。**尚未接主界面或持久存储，不是已上线语言功能。**

## 已实现范围

- `PDFnoDomain/JapaneseLearning.swift`：独立 selection-only 请求、code point 半开范围、读音候选、中文译文和中文日语语法解释、作者 ruby、用户修正、手动保存提案及严格运行时校验。
- `PDFnoServices/JapaneseLearningProvider.swift`：复用 AIHTTPTransport、AICredentialStore 及现有 DeepSeek 官方配置门禁。只发送固定选文和任务；不发送书籍身份、文件、几何、选文外 prefix/suffix、作者 ruby、旧笔记、用户修正或历史。
- `PDFnoServices/JapaneseLearningCoordinator.swift`：明确 AIConsent 绑定来源/配置/提示词/预算，独立用途 fingerprint，无缓存或自动重试，单 continuation 管理超时/取消/迟到结果。
- `PDFnoUI/JapaneseLearningModel.swift`、`JapaneseLearningWorkspace.swift`：独立来源卡、接收方/额度/费用确认、手动开始/取消、分开审阅读音/语法/译文、用户假名修正与独立笔记、显式保存回调。打开、prepare、更换来源/服务或再分析都不自动发送/写盘。用户草稿按 byte-exact 来源隔离；模型/提示词更新不覆盖草稿或修正。模型释放/进程退出不恢复未保存内容。

没有引入外部字典、分词器、模型或依赖。英语语法需要独立契约和语料，本片只定义 ja/zh-Hans。mock 明确只演示协议，不伪造真实读音或语法判断。

## 限额与信任边界

固定 PDF/EPUB **选文**最多500 UTF-16，输出最多1024 tokens（包含 JSON/原文回显），非流式/关闭思考、JSON 格式，最长30秒，响应最多64 KiB。超过上限拒绝，不截取后冒充完整范围；物理页/章节 anchor 拒绝。

`DeepSeekJapaneseLearningProvider` 只从注入的 `AppAISession.selection` 取已有计数器，默认是进程级 `.shared`。它与选文翻译/解释**共用三次额度**；没有 japanese 额外 counter，也未改 AppAISession。失败/取消仍计已提交尝试，服务可能收费，客户端不保证人民币账单上限。集成必须注入与现有 AILearningModel 相同的 AppAISession，不能为新窗口创建新 owner。测试创建独立 owner 仅隔离合成样本。

凭据只通过现有 session store 的 UUID 引用交给 provider；组件没有密钥输入、保存或 Keychain 访问逻辑，没有持久密钥/日志。请求层复用原 URLSession transport 的禁重定向、禁 cookie/cache、有限响应行为。自动化测试全部使用自有 fake credential store 与截获 transport，从未调用 URLSession 网络发送或用户凭据。

## 输出与校验

必须是单个完成的 assistant/stop choice，无实际 tool/function call；length 截断拒绝。JSON 根字段及逐条字段集合固定，重复 JSON 成员（含转义键）拒绝，布尔/小数不当作整数。未知根字段、错误 schema/language/offsetUnit、非逐字 sourceQuote、超过数量/长度预算或无效 JSON 降级为 `unavailable`：仅显示可信来源和固定 warning，不展示原始无效响应，也不允许保存为成功结果。错误 HTTP/envelope/截断单独显示安全错误，不重试或自动 mock。

条目范围相对 **本次选文**，采用 `unicode-code-point` `[start,end)`；通过既有 UnicodeOffsets 转成 UTF-16 时再次验证。quote 必须与源 scalar/UTF-8 序列一致，不 normalize/trim、不模糊修复 offset、不取重复词的第一次匹配。边界还必须是 Character 边界，禁止切开组合假名、IVS、surrogate pair、ZWJ/肤色 emoji。每条必须提供紧邻原文的 prefix/suffix，最多各32 code points；重复词缺上下文拒绝。

逐条无效结构/跨度/上下文/假名或重复 ID 会被排除并附固定 warning，其余合法条目仍可审阅。读音仅接受最多4个有限假名候选；ambiguous 保留候选并明确提示核对，不作自动选定。生成读音相互重叠则排除冲突项；与注入的作者 ruby 重叠则保留作者读音并排除生成条目。语法范围允许重叠，每项单独审阅/强调。源匹配不证明语言准确；中文解释及语义读音质量仍需人工验收。

`JapaneseLearningNote` 是新的保存提案：完整 immutable review、独立 userText、按准确原文范围绑定的用户读音修正。不会用修正覆盖生成结果或作者 ruby。保存失败保留草稿，重试同一结果沿用同一个新 note UUID，便于宿主实现幂等创建；没有现有笔记更新接口。

## 最少后续整合触点

1. **现有 BYOK owner 的小型 factory**：在 AILearningModel 所属权限内，用其现有 transport/session credential reference 与同一个 AppAISession 建立 Japanese provider。因该 model 的凭据目前是 private，本片不添加访问器。清 key/服务 generation 改变必须 cancel/prepare 新 scope 或替换 provider，撤销旧确认；不新增独立 key 存储或额度。
2. **选文入口与生命周期**：把现有 `captureAISource()` 的固定 PDF/EPUB snapshot 交给 `JapaneseLearningRequest`；明确选择 mock 或已支持 DeepSeek 配置；选书/reader session/document version/reflow/服务变动时 prepare/cancel。注入 `sourceIsCurrent` 同时验证来源及当前配置 generation，在开始、完成、保存和强调时执行。EPUB 原文当前 adapter 排除 rt/rp，不扩大发送范围。作者 ruby 的选文内范围提取/映射尚未接入，未来可通过 `authorReadings` 提供；不从模型恢复作者内容。
3. **呈现/回跳/独立保存**：展示独立 workspace；使用既有 native return pipeline 二次校验 edition/hash/extraction/quote/资源与当前来源。可选 emphasis 回调只拿到已验证局部 span，宿主需做 scalar→UTF-16→原生几何/DOM 映射；本片没有绘制高亮。PDF 几何无法精确映射时回到完整固定选文，不能伪造词级坐标。可选 save 回调必须再次验证来源，原子、幂等**创建新记录**并处理 schema/备份；没有回调时保存禁用。现有 learning-v1.json 不接受本新 review 类型，不能强转成 explain 或覆盖原笔记来规避校验。

这些集成变动留给同一整合候选集中处理；本片没有偷偷修改共享 AILearningKind/AIRequest/AIResult 或 repository 白名单。新 Codable DTO 是候选契约，尚无可直接打开的持久文件格式；未来反序列化还必须重新验证 schema/来源/条目，不能只依赖 Codable。

## 需求对应与待验收

对应 R06、S03、J03、UAT02 及 T04/T05/T06 的首片实现；需求账本的83个定义和冻结 auditBaselineAssessment **未改写**。T09/T10 仅新增离线协议/额度/来源/取消证据，不等于真实账号、TLS、语言质量或费用验收。English grammar、全文注音、PDF版式改写、字典、移动端 UI、持久记录/重启恢复、实际 ruby 提取映射、原生词级强调、实际 UI/VoiceOver/布局、真实服务质量与发布均未完成。

独立安全专项仍 **UNVERIFIED / platform blocked**，没有重试、替代或绕过。源码守卫与功能测试不改变该状态。

## 轻量离线验证

`python3 scripts/test-japanese-learning-light.py` 在临时目录复制**真实、未替换的**15个 domain、10个 service 依赖、本片2个 UI 文件和2个测试文件，以正常 SwiftPM sandbox、`-j 2` 编译运行26个测试/2个 suite。排除其他 readers/UI/测试；不启动 App，不全量 Xcode build，不获取/发送用户 key，不读取私人书库、不触发真实 API。新测试同样位于原 Package 的测试路径，可在后续完整整合 CI 运行。

覆盖：精确重复词上下文、语法重叠、错误 offset/quote/unit/未知字段/布尔/小数/数量/JSON重复成员、IVS/组合假名/emoji边界、作者ruby优先、歧义候选、用户修正和正文分离、输入配置预算门禁、wire body 最小范围、HTTP/截断/tool拒绝、已有翻译/解释与日语学习共用三次额度、取消仍消耗尝试、timeout/cancel非合作迟到响应、不自动发送/保存、跨书/服务更改保护、保存失败幂等UUID、无有效输出降级与禁保存、未接存储禁用、引用强调门禁及草稿保留。

环境：arm64 macOS27、Swift6.4；Mac deployment target14编译，不证明 macOS14实际运行或iOS/iPadOS验收。最终检查编译完成13.22秒，26 tests / 2 suites 全部通过，新切片无 warning/error；日志为 `/tmp/pdfno-japanese-light-final.log`。前两次检查发现编译错误并修正，第三次26测试通过后清理测试捕获 warning，最终以交付日志为准。轻量运行无资源争用提示；未启动长时全量检查。

`python3 scripts/check-native-source.py`、`python3 scripts/test-requirement-ledger.py`（8 tests）及 `git diff --check` 作为源码/需求绑定/空白检查。没有改主规格/账本来声称完整功能已验收。

最终源码守卫检查327个文件通过；需求账本8个测试通过；stage 后再次检查变更仅为9个新增文件和空白合法性，再本地 commit。未推送、合并或发布。
