# 文本阅读与 EPUB 当前文档翻译：本地整合交接

日期：2026-10-04。独立工作树 `/tmp/pdfno-integration-text-chapter-8cf6ab8-20261004`，本地分支 `feature/integration-text-chapter-20261004`。起点为已完成全部22 UI的 `8cf6ab8e93e057aa73a6607a17e6e2fe42269315`。最终候选 SHA / tree 在交付证据 `LOCAL-VERIFICATION.json` 中记录，**本轮不推送、不合main、不发行、不写共享Library**。

## 输入与保留

| 模块 | 原始候选 | 本地整合提交 |
| --- | --- | --- |
| TXT / MD / Markdown / HTML / HTM | `0bec13886f22ad3b76c553f50437ce5ff97c99dd` | `99e089e`；[原切片交接](TEXT-FORMATS-SLICE.md) |
| EPUB 完整当前 spine 文档翻译 | `3dcc800a7f5a292f61738003b16e8403703696b5` | `fcf70de`；[原切片交接](EPUB-CHAPTER-TRANSLATION-SLICE.md) |

两模块均基于旧11d32265，原分支/工作树保留。此整合没有倒退8cf6ab8的原生正文输入、取消后重开/清空、网格封面子元素、真实备份写入失败fixture；`NativeNoteBodyInput.swift`、`NoteBodyEditor.swift`、`NoteEditingFilesystemUITestFixture.swift`、`LibraryCovers.swift` 逐字相同，其他正文CAS/草稿journal接口保留。

`NativeUITests.swift` 相对8cf6ab8只有新增行，原22个方法及辅助代码未删除或改写。新增3个文本、4个章节方法完整保留；文本方法增加列表/网格可达性与文本封面按钮禁用检查，总数仍为 **29**。UI只编译，**本候选29 UI实际运行数为0**；原22通过事实只属于原8cf6ab8，不能挪用为本候选的运行验收。

## 共享冲突与实际修复

- `LibraryWorkspace` 保留已验收的封面行/网格容器与默认辅助功能/键盘动作，文本书籍在列表和网格均有独立入口。文本封面未实现，相关按钮禁用并解释；没有给文本伪造 CoverIdentity、封面记录或可执行的空动作。
- `LibraryModel` 同时保留正文编辑、封面、文本、章节四个owner。所有新/旧导入与打开路由取消选文、页、章节任务；**直接**文本导入/打开也取消章节并清临时key。活动文本读者不得捕获隐藏PDF/EPUB AI来源、页/章节准备、验证/回跳或PDF进度；后台已授权旧PDF正文提交可保存并刷新搜索，但不投影到文本读者。
- `AIContracts`、学习仓库与模型保留严格schema/CAS/去重和原文/AI结果/用户正文分离，新增 `.epubChapter` 与专用prompt。章节学习笔记接入原搜索索引的EPUB类型、正文编辑、实时搜索刷新、重启及精确来源回跳。文本书目/笔记搜索和文本笔记正文编辑保持首片缺口，窗口明确格式范围；没有借整合扩大为文本AI或全文索引。
- 新跨模块测试证明搜索打开EPUB后过早定位会失败。修复在当前书籍/edition/hash/session下等待WebKit就绪，最多20秒、可取消；切到其他读者立即拒绝，之后仍走精确anchor验证，不弱化定位条件。
- 先合JS源码再重建四个bundle；EPUB 188 inputs、DOCX 301 inputs/13 packages、Text 5 inputs 与原Comic profile均再现一致。没有手改生成JS、换引擎或修改原始fixture。Marked 15.0.12及完整MIT/Markdown notice、Kookit固定原源码/AGPL对应源码/哈希清单保留。
- 原生v0.3规格新增9.4并纠正“章节尚未实现”的全称表述，区分当前spine候选与未实现的逻辑章/整书。需求账本只重绑specLine，全部83定义、基线评估、分类数量逐字/结构保持。

整合时一次UI提取边界断言失败后错误继续了本地中间提交；该未推送中间提交已在本分支修正。最终Swift文件无冲突标记，完整测试名单、仅新增UI差异和原修复文件字节保留均已验证；没有改写远端或原模块历史。

## 本候选的章节范围

命令“翻译当前文档”只包含当前完整 spine 资源的既有canonical正文，非分页/可见区域、非TOC推断逻辑章、非全书。完整3000 UTF-16/6段上限，段落按Character边界最多500 UTF-16，拼合必须scalar-exact；超限回传真实长度且text=null，拒绝发送而非截断。原ruby基底保留、rt/rp排除，提取版本不变。

用户亲自确认完整范围/接收方/预算/费用并显式发送；固定DeepSeek配置，批次临时key与进程独立6次chapter额度，首发前claim完整计划，串行、无自动重试/恢复。选文/物理页/测试额度与密钥分隔。关闭/切书/版本/重排/文本路由清key和任务generation，已发可能收费；成功段与独立草稿保留供手动保存。只有每段原文/task及固定指示外发，agent自动验证没有真实请求。

## 实际本地验证

| 检查 | 结果 |
| --- | --- |
| 全量Swift | **193/193，29 suites，7.183秒**；171原基线 + 6文本 + 13章节 + 3跨模块；`/tmp/pdfno-next-full-swift.log` |
| 三项跨模块 | 全量中全部通过；独立聚焦3/3亦通过，覆盖学习正文/草稿隔离/搜索/当前及重启回跳、直接文本路由清key、不发送/拒隐藏范围、PDF编辑/封面与文本笔记/进度/原件隔离 |
| Node回归 | **14/14，0失败/跳过**；`/tmp/pdfno-next-node-tests.log` |
| 四个bundle、fixture、Xcode项目再现 | 全部通过；tracked输出`git diff --exit-code`为0；原创fixture库存28份 |
| 来源/样本守卫、需求账本、差异 | 全部通过；账本8/8；最终源文件数量见证据 |
| Mac build-for-testing | **TEST BUILD SUCCEEDED**，全部29 UI编译；`/tmp/pdfno-next-Mac-build.log` |
| iPhone/iPad generic Simulator | **BUILD SUCCEEDED**；`/tmp/pdfno-next-Mobile-build.log`；两新模块阅读UI仍Mac-only |
| 本候选UI执行、远端CI | **NOT-RUN / 0**；不运行用户PDFno，不将编译替代实际验收 |

环境：arm64 macOS27，Xcode27.0/27A266a，Swift6.4。构建目标仍macOS14/iOS17；编译不证明最低系统、真实iPhone/iPad、VoiceOver、真实翻译/费用或发行签名验收。没有用户图书/真实key、Bookno/iCloud、共享Library或真实模型API访问；独立安全专项仍 **UNVERIFIED / platform blocked**，没有重试/绕过，也不把功能验证当安全结论。

## 复核命令与下一步许可

```sh
swift test --disable-sandbox --package-path apple/Packages/PDFnoKit --scratch-path .build/NextIntegrationPackage
node --test engine-build/loader.test.mjs engine-build/rangy-security.test.mjs engine-build/docx.test.mjs engine-build/comics-reader.test.mjs
node engine-build/build.mjs
node engine-build/build-comics.mjs
node engine-build/build-docx.mjs
node engine-build/build-text.mjs
python3 -B scripts/check-native-source.py
python3 -B scripts/test-requirement-ledger.py
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath /tmp/pdfno-next-Mac -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/pdfno-next-Mobile -disableAutomaticPackageResolution -skipPackageUpdates CODE_SIGNING_ALLOWED=NO build
```

本地构建依赖从文本候选复制真实node_modules，按lock/source hashes核验并再现；发布CI须按锁文件正常`npm ci --ignore-scripts --no-audit --no-fund`安装，包含固定Marked。source、notice与原bundle输入检查不等于独立安全审查。

下一步需要用户允许**普通推送最终确切候选SHA到 `lyx5710317/pdfno` 的新分支 `feature/integration-text-chapter-20261004`，并完整运行该SHA的Native + CBZ CI**，逐项确认29 UI全部执行/通过、原22无倒退和其他检查成功。当前已授权边界仅本地整合；旧三功能的持续修复推送许可不自动扩大到这批新模块。main合并、发行及共享Library更新均不包含在该推送许可内。

保存最终代码、tree、日志hash、原22/新增7方法名单及源提交映射后冻结工作树；CI失败需在明确授权范围内保留断言并修复，再以新SHA重跑，不能跳过/删减或根据上一候选判断通过。
