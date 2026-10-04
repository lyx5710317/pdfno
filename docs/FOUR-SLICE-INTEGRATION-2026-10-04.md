# 四片原生功能串行整合候选

日期：2026-10-04；验证完成于本机本轮执行。基线为已验收 main `bb6928e1319f85a72c967a6c3f054bb544e9c306`。新分支为 `feature/integration-four-slices-20261004`。本轮只进行独立工作树内的本地整合、测试和编译；候选的完整 SHA 见外部 `FINAL-LOCAL-INTEGRATION-RECEIPT.json`。AGPL-3.0-or-later 保留。

## 输入与整合结果

四个输入均以同一基线开始，按下表顺序使用普通本地 merge 保留历史，Git 合并没有文本冲突。其独立交付说明描述各片合并前的状态；本说明描述完成宿主接线后的候选。

| 输入 | 完整提交 SHA | 本候选接线 |
| --- | --- | --- |
| UI foundation | `0d673106e399053569d883517c03f3361bed0bb4` | 自有字体、间距、语义颜色、书库列表/网格/空态；Mac PDF 左侧导航/搜索与右侧笔记，窄宽切换保持原 PDFView、来源和草稿 |
| Saved-record parity | `f8c30e293abcb3784be4a5dde472530d6d2d7344` | 六种文本、四种 ebook 和日语学习的已保存正文编辑；统一已保存记录搜索和验证后的来源回跳 |
| Bounded HTTPS BYOK | `57a200beceea33ace37a228c48ddf46ef3ef0e1f` | 独立设置入口、PDF/EPUB 固定选文预览/确认/发送、显式手动保存；与旧学习功能共享原 AppAISession |
| DOCX reading PDF | `c289184db1d80c849a80ac096f9f8f262421eb25` | 原转换窗口新增“DOCX 阅读版PDF”独立入口、损失说明、PDF 保存面板、取消和显式重试 |

生产入口均已接入 **Mac** 主应用。iPhone/iPad 仍是共享包/现有应用/测试包的编译兼容性验证，新编辑/BYOK/阅读版PDF宿主流程没有在移动端启用。所有四片提交均是最终候选的祖先；没有修改任何输入工作树。

## 保存、来源与入口契约

- LibraryModel 保留一个库生命周期的 RecordEditingAdapter，文字、ebook、日语已保存行使用同一个编辑器和 checkpoint owner。PDF、EPUB、一般 AI 的旧编辑入口继续使用原别名；旧 `note-edit-drafts-v1.json` 与新 `record-edit-drafts-v1.json` 仍独立。换书/关面板不丢失草稿；保存只更新正文，CAS 冲突、失败、显式重载/重试沿用原契约。
- 统一书库搜索由一个 SavedRecordSearchModel 驱动；旧索引与新记录共用总计 300 项展示预算，合并统计完整。搜索只纳入已保存记录及既有可用书目字段，不纳入草稿或整书提取。原本地书目编辑仍使用旧支持范围，不新增 text/ebook 作者元数据或封面命名空间。
- 日语正文编辑放在完整原 review、假名修订和引用展示旁。结果、来源、prompt/provider/request 和用户假名修订均保留；生成草稿与保存正文编辑互相独立。
- 新记录回跳使用当前存储解析身份、独立真实 reader 预检和 reader-session fence。PDF/EPUB 仍走既有原生验证。缺失或不符来源不会自动构造新锚点。
- BYOK 设置由原 AI 设置中的独立按钮打开；PDF/EPUB 阅读器有独立选文入口。关闭、换书、来源失效或真实选区改变都会取消未完成请求。聚焦面板暂时失去原生 selection 不会改写已捕获来源。开始和返回后均检查当前不可变 book/session/version/edition/hash/source。
- BYOK 结果只有用户点击保存时才写入原 `learning-v1.json`，使用原学习笔记模型，不改旧配置；requestID 防重复保存。用户正文与模型原结果独立。旧 DeepSeek、日语、页和章节入口仍走原链，候选不会把 BYOK provider 接入那些 prompt。
- 阅读版PDF以独立不可见 DOCXReaderSession 调用原固定 Mammoth 语义引擎，再由 Core Text/Core Graphics 排版。活动阅读器的会话、选区、来源、草稿和原文件不会被导出替换。既有 TXT/HTML 转换仍可用，整个 pinned-fd 输出事务类逐字节保持基线。

## 有限范围和未完成事项

BYOK 当前只支持明确 HTTPS endpoint 的有限 OpenAI chat JSON 协议及原官方 DeepSeek adapter，不能据此声明任意供应商/模型兼容。只接收 PDF/EPUB ≤500 UTF-16 固定选文，输出请求上限 1024 token、30 秒、64 KiB response；失败/取消仍计入同一进程 selection 三次额度。界面在发送前展示实际域名、最终 URL、模型和完整原文，要求用户明确确认。endpoint 变化立即撤销旧临时凭据，新域名需重新输入；所有重定向（含同 origin）拒绝。设置/key 仅内存，未实现持久 Keychain、SSE、自动探测、自动重试、HTTP 本地模型、真实 API 验收或供应商语言质量验收。

阅读版PDF固定 A4/12 pt/有限页数，包含明确标题、损失警告和实际质量报告。它保留既有语义 reader 发出的文字与基本结构；图片为惰性文本占位、表格转为有标记的段落，不重建 Word 布局/分页、复杂对象或字体。不是原规格七个高保真转换方向的完成证明。PDFKit 原样本提取/渲染证据保留；第三方 pypdf 普通提取会有兼容部首差异，不能用于稳定定位迁移。没有 PDF/UA 或完整 tagged-PDF 验收。

完整界面视觉验收、VoiceOver/键盘焦点、最小窗口实际操作、EPUB/其他格式布局的统一设计、Intel/最低系统/真机、移动端流程、跨进程正文并发、巨型书库性能、文件提供商与崩溃持久性均未完成。真实 Bookno/iCloud 同步继续后置。独立安全专项仍为 UNVERIFIED/平台阻断，本轮没有重试或绕过。没有新增账号、权限、签名配置、CloudKit 容器或远程服务。

## 验证证据

实际工具链为 macOS 27.0、Xcode 27.0 (27A266a)、Swift 6.4，arm64 主机。全程使用独立缓存/DerivedData，Swift 和 Xcode 大型构建顺序执行、jobs=2、关闭签名。测试只用原授权合成样本、UUID 临时存储、拦截/非合作 transport 和测试进程内不可见原生 reader；未启动实际 PDFno 应用或 Simulator，未发送真实 API。

| 检查 | 本候选实际结果 |
| --- | --- |
| 完整 Swift 套件 | **381 tests / 50 suites PASS**；完整未筛选、未并行，27.445 秒 |
| 交叉整合回归 | 上述全套内 **6/6 PASS**：长期 adapter、PDF 面板选区/双草稿连续性、共享 BYOK 预算与旧链独立、换格式迟到取消/凭据撤销、文本/ebook保存和精确回跳、日语 review/修订保留、导出不改活动来源/原 TXT/HTML/拒覆盖 |
| 完整 Node 套件 | **25/25 PASS**；0 failure/cancel/skip，六个原测试文件串行 |
| Mac | **TEST BUILD SUCCEEDED**，arm64，应用和 UI 测试包编译；实际 UI 执行 **0** |
| iPhone/iPad Simulator | **TEST BUILD SUCCEEDED**，arm64 + x86_64，应用和测试包编译；设备/Simulator运行 **0** |
| 旧 UI 保留 | 原 43 项名字与全部源码行按序保留；EbookFormatUITests 全文件字节不变；foundation 两项也保留 |
| 当前 UI 清单 | **50 个唯一 Mac UI 方法**：原 43 + foundation 2 + 整合 5；源清单及编译二进制均含全部方法，见 FOUR-SLICE-UI-INVENTORY.json |
| 资源/保护核验 | **294 个基线文件逐字节一致**：原 fixtures、engine、codec/许可、scripts、应用/工程/工作区、全部原单元测试、Bookno 和 83 项 ledger；原 LibraryWorkspace 34 个标识符保留，原 fd 事务逐字节一致 |
| 仓库检查 | source guard、codec pin/原样本检查、8 项 ledger 检查和 git diff --check 通过 |

原生成 engine/fixture/project 及锁文件均未修改，本轮按字节核验其已验收基线，没有重新生成或安装依赖。Node 使用已验收独立工作树中的同一锁文件依赖只读拷贝到本候选的 ignored 目录；没有网络安装。

新增五项 UI 方法分别验证文字正文草稿/重启/搜索/回跳、MOBI 同流程、日语正文编辑保留 review/修订、BYOK 接收者明确确认/手动保存/旧链独立、阅读版PDF保存面板取消/实际输出/拒覆盖。它们编译成功，不宣称已在本机执行。完整名单保存在旁边 JSON，后续 CI 必须逐个核对全部 50 项实际运行结果。

外部日志保存在：
`/var/folders/s6/g995lx310_d8lh2z5xp9dsrh0000gn/T/pdfno-four-slices-20261004-fx1tzf_o`。
关键文件为 `swift-complete.log`、`node-complete.log`、`mac-ui-compile.log`、`mobile-compile.log`、`guards.log`、`PRESERVATION.json` 和 `FINAL-LOCAL-INTEGRATION-RECEIPT.json`。初次 sandbox 受限、测试编译/fixture 假设错误的失败日志也保留；修正仅限新增测试使用方式和原 fixture 路径，没有删断言、降低安全/转换限额或改原测试。

## 交付、验收和回滚

本地分支和候选提交可直接评审；main、原输入工作树和用户 Xcode 自动元数据不参与本候选提交。外部 receipt 记录最终 main/元数据核验结果，不恢复或覆盖用户并发改动。

下一步的最小授权是：**普通推送这个新分支的确切候选 SHA，并执行完整 CI**。旧 c048c07/main 的授权不扩展到此新候选；本轮不推送、不合并 main。CI 应完整执行 Native、相关 comic/ebook gates 和全部 50 项实际 UI，禁止过滤/跳过或以基线 43 项结果代替本候选。核验 run 对应候选确切 SHA，全部通过后 main 合并仍需针对本轮候选的明确授权。

CI 中任何失败按具体实际证据修复；保留全部原测试、安全限制和完整日志，修复后重跑受影响完整 gates。Native 原 50 分钟 job 上限不变，只将说明更新为 50 个方法；若实际超时，报告而不是预先删测试或扩大权限。

回滚时在新分支撤销宿主接线及四片提交，保留用户已写正文/草稿/学习笔记，不删除旧源码或书籍。各持久 manifest 仍为 v1；本轮没有旧草稿迁移、来源锚点迁移或原文件转换替换。
