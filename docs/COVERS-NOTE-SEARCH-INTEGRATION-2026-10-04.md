# 封面、笔记正文编辑与本地搜索统一整合交接

核验日期：2026-10-04。本交付是基于审计修复基线的**本地整合候选**，尚未推送、合入 main 或发行。确切最终 SHA 由本地 Git HEAD 及交付附带的 `VERIFICATION.json` 记录，不能把单片 CI 或历史 main CI 当作此候选的运行结果。

## 隔离与提交身份

- 整合目录：`/tmp/pdfno-integration-11d32265-20261004`，macOS 实际路径为 `/private/tmp/pdfno-integration-11d32265-20261004`。
- 分支：`feature/integration-cover-notes-search-20261004`。
- 固定起点：`11d32265a8b7ee7956f36c6af59dd42e54dcf035`。
- main 保持 `05cbcf537e0ae85b2831a6b86e500e5d7d2b0a94`；原审计工作树、三个交付工作树以及用户 Xcode 自动生成的 `project.xcworkspace` 均保留。
- 当前 checkout/父目录未发现适用的 `AGENTS.md`、`.agents/skills` 或 `.codex` 指令。本轮不修改本机记忆、Library、账号、CloudKit、签名或权限配置。

| 功能 | 交付提交 | 整合提交 |
| --- | --- | --- |
| 笔记正文编辑 | `235807b51701031b2928445dc415a639968cb620` | fast-forward 保留同一 SHA |
| 本地封面 | `d729eccd14996b9163190af2ac49b8b55922fe8f` | `75e04a192614e4d3f2dd812c7b500dfc789398bd` |
| 本地书库与已保存笔记搜索 | `7f02caa334d1400fbbc418930d82ded1a2964eb1` | `95611278bcc411a26903d53e5aa7901291d2fcbc` |

封面产品代码与编辑自动合并。搜索在 `LibraryWorkspace.swift` 的工具栏和 sheet 与封面冲突，最终同时保留两个入口。UI 新增段落冲突按不可变提交内容合并；初次插入边界含文件头，在最终整合修正中去除，最终只有一个测试类。原基线从首个 DOCX 测试起的整个文件后缀保持逐字一致，13 个旧测试及其断言没有删减。现有仓库、阅读器、引擎、原始样本、Xcode 工程、工作流和历史需求账本均保持基线内容。

## 最终行为与跨功能连接

封面支持 PDF 第一物理页、EPUB 明确内嵌光栅封面、CBZ 自然页序首图；无封面的 EPUB/DOCX 显示稳定占位。用户可本地替换和恢复自动封面；列表与网格用同一身份和缓存。尺寸、像素、内存和磁盘边界以及格式限制见 [封面交接](COVERS-DEVELOPMENT.md)。本轮未扩展 EPUB/DOCX 版式支持或 Bookno 封面上传。

正文编辑沿用现有 PDF/EPUB/AI 记录，CAS 检查基线，只改用户正文。PDF revision 按现有结构增长；EPUB 和学习记录不引入新字段。独立 `note-edit-drafts-v1.json` 保存未提交草稿，取消、失败、重开与显式冲突重载均保留原先语义。选文、原文件、来源锚点和 AI 结果不会因正文编辑或封面操作被重写。DOCX 已保存正文编辑不在本片范围。

搜索读取各格式当前有效 manifest、学习文件和可选 `book-metadata-v1.json`，每次请求重建内存索引，无持久 search-index 文件。本地标题/作者旁存只影响搜索目录，封面栏和阅读器继续显示导入标题；未自动解析所有格式的作者。搜索字段限定书目、已保存笔记正文/引文/AI 结果，不扫描全书、OCR、草稿、密钥或远端服务。Unicode、取消、迟到结果与精确来源检查见 [搜索交接](LOCAL-LIBRARY-SEARCH.md)。

整合新增 `LibrarySearchModel.observeChanges(in:)` / `stopObservingChanges()`，把原视图中的八组已提交数组订阅集中到模型，并由搜索窗口生命周期启停。该方法直接观察 PDF/EPUB/DOCX/漫画书库与 PDF/EPUB/DOCX/AI 已存笔记。正文编辑成功发布原有集合后重建当前查询，未保存草稿不发布到这些集合。测试与真实搜索窗口使用同一连接，避免只验证手工调用 refresh。

## 本机实际验证

环境：arm64，macOS 27.0 (26A428)，Xcode 27.0 (27A266a)，Swift 6.4，Node 20.20.2。CI 的 macos-15/Node 22 是另一个环境，须另行运行。使用原创样本、构造数据、UUID 临时存储和独立构建目录；没有启动/终止/探查用户 PDFno，没有真实 key、模型发送或私人书籍。

| 检查 | 实际结果 | 证据日志 |
| --- | --- | --- |
| 三片及新整合测试 | 48/48，5 suites，0.180 秒 | `/tmp/pdfno-integration-cross-feature.log` |
| 完整 Swift 功能套件 | 168/168，24 suites，3.408 秒 | `/tmp/pdfno-integration-full-swift.log` |
| Mac app + 全部 UI 编译 | `TEST BUILD SUCCEEDED`，不执行 UI | `/tmp/pdfno-integration-Mac-build-final.log` |
| iPhone/iPad generic Simulator | `BUILD SUCCEEDED`，arm64/x86_64 编译 | `/tmp/pdfno-integration-Mobile-build.log` |
| 既有 Node 回归 | 14/14，0 failure | `/tmp/pdfno-integration-node-rebuild-final.log` |
| EPUB/漫画/DOCX 引擎重建 | 三条命令 exit 0，生成文件与提交逐字一致 | 同上 |
| 原始样本与原生边界守卫 | 通过，最终数量见交付证据 | `source-guard.log` |
| 需求账本守卫 | 8/8，通过 | `ledger-guard.log` |
| Diff whitespace 与旧 UI 保留核对 | 通过 | `VERIFICATION.json` |

48 = 编辑 13 + 封面 14 + 搜索 16 + 新整合 5；168 含这 48 与基线 120，不重复累计。参数化实参覆盖另列于既有测试中。全量 Swift 套件包含原有未附着窗口的 WebKit 单元测试，与启动应用的 UI 测试不同。

新增 5 项整合测试逐项验证：

1. PDF 编辑成功后，已打开搜索自动移除旧正文、检索新正文；清空正文仍保留引文；编辑其他书的笔记不替换当前 reader/session。
2. EPUB 与已保存 AI 正文编辑自动刷新同一搜索，清空 AI 用户正文仍可检索保存结果，原 EPUB/引用/result 不变。
3. 真正写入独立 journal 的草稿，重建搜索及应用模型重开后均不入索引；取消后只移除草稿，原笔记仍可搜。
4. 构造备份写入失败时，新正文不上索引，草稿保留；修复临时测试目录并显式重试成功后自动出现新正文。
5. 手动封面替换、恢复、本地书目修改与正文编辑后，搜索目标跨书准确回到原 PDF 第二页；重建应用模型后仍准确，原书和封面输入字节不变。

Mac 构建仅有基线两个 UI 未使用变量警告及 AppIntents 无依赖的 metadata 提示，未出现新增功能编译错误。引擎初次用依赖符号链接重建时，esbuild 把真实跨目录路径写入 bundle/input 清单，字节核对未过；随后复制基线锁定依赖至本工作树的独立 `node_modules`，重跑 14 测试和三条构建后核对通过。未把中间差异提交。

本地复现命令（工作目录为独立整合工作树；构建操作使用正常获准环境）：

```sh
swift test --disable-sandbox --package-path apple/Packages/PDFnoKit --scratch-path .build/IntegrationPackage
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/pdfno-integration-Mac -clonedSourcePackagesDirPath /tmp/pdfno-integration-Mac-Packages -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/pdfno-integration-Mobile -clonedSourcePackagesDirPath /tmp/pdfno-integration-Mobile-Packages -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build
node --test engine-build/loader.test.mjs engine-build/rangy-security.test.mjs engine-build/docx.test.mjs engine-build/comics-reader.test.mjs
node engine-build/build.mjs
node engine-build/build-comics.mjs
node engine-build/build-docx.mjs
python3 -B scripts/check-native-source.py
python3 -B scripts/test-requirement-ledger.py
git diff --check
```

实际 Xcode 命令另为 Mac/Mobile 设置了独立 `CLANG_MODULE_CACHE_PATH` 与 `SWIFTPM_MODULECACHE_OVERRIDE`；完整命令、exit 状态与日志 hash 在外部交付证据中保存。全量 Swift 通过后未改运行逻辑；最终给新增 UI 场景补充等待封面 revision 落盘的断言并重新完成 Mac 测试编译，随后只更新文档和证据。

## UI 执行与完整 CI 计划

总共 **22 个 UI 方法**：基线 13 + 编辑 4 + 封面 2 + 搜索 2 + 整合 1。22 个均已编译，**本地执行数为 0**。方法全集在证据 `EXPECTED-UI-TESTS.json`，须以最终候选 SHA 的 CI 日志核对实际运行/通过/跳过数；不能以 TEST BUILD 或历史 13 项通过替代。

新增跨片方法 `testMacEditedNoteSearchDraftExclusionCoverLayoutsAndExactSource` 用独立原创 PDF 和 UUID store，验证未保存草稿不出搜索、取消与保存、旧词消失新词出现、封面列表/网格与恢复自动封面之后，从第二页经搜索回到原选区所在第一页并核对锚点与原书字节。单片新增 8 个 UI 方法的详细范围见各自交接。

推送获准后，普通推送最终确切 SHA 到 `feature/integration-cover-notes-search-20261004`，等待 **Native checks + CBZ comic checks**。Native 工作流执行引擎再现、Node 14、样本/项目/账本守卫、Swift 168、Mac/iOS 构建，以及全部 Mac UI 22。CBZ 的 14 Swift 与 4 Node 是子集，不另加进总数。UI 只在隔离 CI/VM/OS 用户运行；留意现有 35 分钟总超时和逐例限制，若失败保留完整日志/结果而非减少用例。不得以分支运行替代 main 合并授权。

## 旧推送请求与仍未关闭事项

用户对 `77aea2b1c9942431c648ae1f884f9793da4af0c3` 普通推到 main 的授权已核对：该提交早已在远端 main 历史中，main 当前为其后继 `05cbcf5`。其 [漫画 CI](https://github.com/lyx5710317/pdfno/actions/runs/37133129257) 通过，[Native CI](https://github.com/lyx5710317/pdfno/actions/runs/37133129268) 在 Mac UI 步骤失败，其余阶段通过。后继 `05cbcf5` 的 [Native CI](https://github.com/lyx5710317/pdfno/actions/runs/37134425136) 与 [漫画 CI](https://github.com/lyx5710317/pdfno/actions/runs/37134425214) 已全部成功；本轮没有把 main 倒退到旧提交。

旧授权只指定 77aea2b/main，不涵盖本次新整合候选。下一步所需许可仅为：普通推送交付的确切新 SHA 到上述 integration 分支并跟进完整 CI；本地整合、测试、构建和提交已在授权范围内完成。

独立安全专项复核因先前平台限制保持 **UNVERIFIED**，未重试或绕过。这里的既有功能/守卫测试不替代该复核。签名发行、持久 Keychain、最低系统实际运行、VoiceOver、真实大书库性能、全书搜索、增量/跨进程事务索引、iCloud/Bookno、移动端新功能 UI 和真实模型质量亦未在本轮验收。历史需求账本的 auditBaselineAssessment 为冻结基线，未改写成新增功能已全盘满足的声明。
