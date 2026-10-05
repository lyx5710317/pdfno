# PDFno UI、回收备份与英语学习整合

核验日期：2026-10-05。基线 `7bea8ec89ea7273b3b52ee714fbf1180b3d51c73`。本批仅在独立整合工作树开发、本地提交；未推送、合并、发布、迁移用户书库或启动桌面 App。源代码仍为 AGPL-3.0-or-later。

原切片与接口依据：

| 切片 | 交付提交 | 说明 |
| --- | --- | --- |
| UI | `15cb42ef7f6a25c2a2a257dcac13310b11fc6059` | [UI 报告](UI-REFINEMENT-2026-10-05.md) |
| 数据 | `fb9a10ad2ea0b470cf86ae4b86cbb55b95aa28b5` | [本地恢复与备份](LOCAL-RECOVERY-BACKUP-2026-10-05.md) |
| 英语 | `eed4eab438f393aaf349f7d66cf8f526c0323ea8` | [英语接口与验证](ENGLISH-LEARNING-SLICE.md) |

三片已经 cherry-pick 到 `feature/integration-ui-data-english-20261005`。本报告描述宿主接线；独立切片的测试数量不能相加当作本候选的统一验收。

## 已接入的行为

Mac 书库工具栏提供“回收站与备份”。书籍先预览关联记录与保留资产，再确认移至本地回收站；恢复有独立预检与冲突检查。支持目录包导出、备份完整预检和确认后恢复至新不存在目录。恢复新目录不会切换当前书库，也不覆盖或合并已有目录。回收站一直保留，原件不删除，没有永久清空或磁盘空间回收承诺。服务层已有单笔记目标；本管理入口当前列出书籍与回收记录，未增加逐笔记删除按钮。

PDF 与 EPUB 的 Mac 阅读器均有“英语结构与语法”入口，固定当前可靠选文后展示完整来源、服务与费用确认，再由用户手动开始、审阅、保存。已保存英语记录进入原书笔记列表、统一本地搜索、正文编辑和精确回到来源。搜索索引只读已保存的正文、原文、译文、结构解释、语法解释及警告；未保存草稿不进入索引。正文更新使用原记录 CAS，不改生成审阅与来源。

英语 factory 复用 `AILearningModel` 现有配置、会话凭据引用、transport 和 `AppAISession.selection`。DeepSeek 英语 adapter 是实际请求适配代码；本批验证只用合成凭据与完全拦截 transport。英语、日语、选文翻译、独立 BYOK 入口共用原三次额度，无新增 key owner 或预算。英语沿用 DeepSeek 已审计 endpoint/model 门禁；未把其他 BYOK 服务自动当作受支持的语法 provider。未配置、缺凭据、协议错误或额度不足会明确拒绝，不能自动切换 mock。

固定 mock 仅覆盖八句原创语料；未知语料不制造语法判断。真实调用仍限 500 UTF-16 选文、1024 输出 tokens、30 秒、64 KiB 响应；有色成分只是可核对候选，省略／推断无虚构跨度。解析、保存和颜色测试均不证明真实语言准确率。

## 写入与恢复生命周期

`LocalStoreWriteGate.shared(root:)` 为同进程、规范根路径的长期 owner。所有 33 个实际 repository／草稿持久化入口已登记；宿主的导入、打开、进度、正文编辑、封面、元数据及 AI 保存还持有跨异步步骤的外层 lease。普通原子 manifest 写入仍保持既有 schema 和路径，不把这些单文件操作称为跨文件事务。

宿主维护步骤为：

1. 检查所有同根 `LibraryModel` 的可见未保存笔记草稿、两个编辑 journal 的未保存改动／错误。存在时保留草稿并拒绝维护。
2. 同步关闭新写入入口并轮换 epoch，标记全部 owner 维护中，取消 AI、搜索和 Bookno 离线预览，撤销旧保存上下文；排空已获许可的宿主及 repository 写入。
3. 排空后再次检查草稿，关闭全部格式阅读 session，才生成 `LocalRecoveryWritePermit`。漫画进度另核对运行 reader、取消状态和捕获 epoch，不能重放旧 reader 的进度。
4. 恢复待决日志，执行已确认操作，再恢复／核对事务状态、完整快照与全部 store；清理封面内存缓存并重载所有 owner。
5. 恢复后旧编辑草稿要求显式重载基线与核对；文件和正文保留。普通健康重启不强制这个维护审阅步骤。历史恢复记录／待决日志存在时，启动先恢复并核对草稿，之后才开放写入。
6. 校验成功才重新开放写入并触发封面重取。失败会保留恢复 fence、禁止导入保存；重新创建 owner 不能绕过同根 fence。取消任务也须完成排空、回滚与重载。

首次进程启动在同一暂停范围内恢复日志、重载，再开放写入。第二窗口复用已完成恢复的同根 owner，不因普通载入关闭第一窗口的阅读器。被维护窗口中的编辑控件禁用；现有 reader 与搜索不能在多文件安装过程中继续公开旧来源。

英语保存 callback 在 writer admission 后做 PDF／EPUB 原生来源核验；`EnglishLearningSourceCommitFence` 又在英语文件事务内核对完整来源、epoch、撤销状态、当前 bookID／editionID／hash 和原件 SHA256。更换来源、清密钥、切书或维护会撤销 fence。同步模型 scope 守卫不能单独证明异步期间书籍仍存在。

`LocalRecoveryAdditionalAdapter.englishLearning()` 仅注册 `english-learning-v1.json`，执行完整 `EnglishLearningRepository.decode`，从 note UUID 与 source 的 bookID／editionID／hash／PDF 或 EPUB 类型建立关联。未来 schema、未知字段、错误来源或未注册文件拒绝备份，不静默遗漏英语笔记。

备份限额仍为 256 MiB／20000 文件、单 manifest 5 MiB；英语 schema1／最多1000记录／5 MiB。草稿、缓存、密钥、账户及事务暂存不进入备份。数据组件的阶段日志、SHA 清单、CAS、故障回滚和重启恢复边界保持原报告；没有跨进程锁、fsync 断电持久性或云冲突保证。

## 统一验证

最终精确命令、退出码、源文件／日志 SHA256、环境和保护核对见本批外部交付目录的 `INTEGRATION-FINAL-RECEIPT.json`，原始日志在整合工作树 `.build/IntegrationGateEvidence/`。所有 Swift/Xcode 重型检查使用批次共同锁、独立 scratch／DerivedData、两个编译任务。

| 检查 | 状态 |
| --- | --- |
| 完整 Swift 套件 | 470 项／59 suites 通过；最终日志 `FINAL-swift.log` |
| 新宿主闭环 | 英语手动保存／搜索／CAS／重启原生返回；四入口共用额度；多 owner 排空／重载；草稿阻止维护；失败 fence；prepared 日志启动回滚；健康重启草稿回归 |
| 数据与英语存储整合 | 真实持久化入口拒绝暂停写入、撤销 source、原件被替换拒绝保存、英语备份／书籍删除／准确恢复 |
| Mac build-for-testing | 未签名 arm64；只编译全部实际 UI 方法 |
| iOS Simulator build-for-testing | 未签名 arm64＋x86_64，generic destination；未启动模拟器 |
| JavaScript | 25 项引擎／桥接／安全回归；锁定依赖及资源再生核对；本机 Node 20.20.2，远程 CI 仍需用其 Node 22 环境复验 |
| source guard／需求账本／diff | 649 源文件检查、8 项账本回归与 diff 检查通过 |

保留 `NativeUITests.swift` 的原46项与 `EbookFormatUITests.swift` 的原4项文件，逐字节与基线相同，未降低断言、skip 或扩大超时。新增 `NextBatchUITests.swift` 两项：英语同意／保存／搜索／重启无密钥，以及回收站确认／恢复／目录选择／SHA备份预检／恢复到新目录／重启原书；生成器与工程同步登记。共52项实际 Mac UI 方法已具备编译入口，首个本地收据产生时实际执行为0。编译、不可见 in-process host 和上一批 main CI 都不是本候选的实际 UI 通过证据。

统一回归曾发现第二窗口启动关闭旧 EPUB reader，已修正宿主恢复复用，保留旧章节回归的断言与超时。英语拦截响应补齐严格 index=0；生成结果的字节比对用排序键编码，避免 JSON 字段顺序的不确定性。失败与最终复验日志均保留。

## 后续验收与回滚

用户已明确批准本批普通推送、完整隔离 CI、相关失败修复，以及全部通过后合入 main 并复验。首个候选 `1938c5c0e8d9ec904cfdca1813abe685176af71f` 已上传至本批 feature 分支；其[漫画 CI](https://github.com/lyx5710317/pdfno/actions/runs/37289962009)与[电子书专项 CI](https://github.com/lyx5710317/pdfno/actions/runs/37290041549)已通过，[Native 完整 CI](https://github.com/lyx5710317/pdfno/actions/runs/37289962008)在本次文档更新时仍运行。此后补充的目录 UI 往返需要在后续精确提交上重新运行完整检查。

新增 `learning-maintenance.yml`，在隔离 GitHub macOS runner 诊断两项新 UI 及受影响的原有 BYOK／DeepSeek 设置用例，沿用现有 ad hoc 测试身份与180／240秒单例限制。它由本批 feature 分支推送触发，也保留登记到 main 后可用的手动入口；不能替代 `checks.yml` 的完整52项 UI、Swift／资源／移动编译与其他专项。最终 CI 状态、实际方法数量、feature 与 main 精确 SHA 应以最终外部 CI 收据和对应运行日志为准，不能沿用初版本地收据中的未上传状态。

首轮[新增 UI 诊断](https://github.com/lyx5710317/pdfno/actions/runs/37291477257)记录了两个辅助逻辑问题：密钥和正文控件未先进入真正的滚动视口，以及导出前在通用 `/tmp` 创建测试目录发生权限错误。后续修复给设置表单增加可访问标识，按实际 `scrollViews` 视口定位并保留完整可见／可点击断言；备份输入目录使用测试 runner 的 `temporaryDirectory`。新增阶段日志核对清单 SHA、原件字节和当前书库未替换；原50项文件与每例超时均保留。修复必须以新的实际 UI 运行验证，不能用编译成功代替。

[第二轮新 UI](https://github.com/lyx5710317/pdfno/actions/runs/37292863167)完成目录 SHA 与新目录恢复检查，但在最终重启前超过180秒；英语正文实际保存成功，仍因 TextView 的按钮式 AX enabled 等待失败。后续辅助器采用原有编辑测试已使用的可见坐标点击，并新增实际编辑值断言；目录路径通过保留／恢复原剪贴板的粘贴输入，准备就绪的控件直接核验后点击，减少逐字输入与重复轮询，保留全部备份、原件与重启断言。

首轮 Native 取消前另记录了原 BYOK 密钥焦点和 DeepSeek 结果未在可访问列表出现的问题。修复让设置中的凭据先于较长预览／其他工具，并让短文本视口按实际内容高度收缩，长文本仍受既有高度上限约束、可独立滚动；两个原用例加入诊断，原测试源码不改。候选必须重新完整运行52项，不能把取消前部分通过的方法当作整体验收。

[四项诊断](https://github.com/lyx5710317/pdfno/actions/runs/37294477069)中，原 DeepSeek、英语和目录备份／恢复／重启均实际通过，目录用例用时139秒。原 BYOK 在点击应用配置后事件循环不再响应；后续把其状态动作区从重复候选的自适应布局改为单一稳定纵向布局，继续用原用例验证。三项诊断通过仍不等于四项或完整52项通过；最终结果由后续精确候选收据核对。

[后续诊断](https://github.com/lyx5710317/pdfno/actions/runs/37296332316)验证原 BYOK 实际通过，但暴露窄窗工具栏中的选文 AI 不可点击，以及三次目录路径导航在较慢 runner 再次超过180秒。PDF／EPUB 的选文 AI 与 PDF 整页翻译移入阅读区的单一自适应学习工具网格，标识与任务／确认行为保留。Mac 目录入口采用真实 `NSOpenPanel`；会话内保存刚导出的父目录和包 URL，用作后两次面板的初始位置，显示位置并仍要求用户确认实际面板返回 URL。未持久化目录授权、未自动预检或恢复，iOS 保留系统 fileImporter。用例保留三次真实目录面板、所有 SHA／原件／当前书库／重启断言及原超时，新增核对面板显示初始位置。

API 核验：Apple 的 [`directoryURL`](https://developer.apple.com/documentation/appkit/nssavepanel/directoryurl) 与 [`beginSheetModal(for:completionHandler:)`](https://developer.apple.com/documentation/appkit/nssavepanel/beginsheetmodal%28for%3Acompletionhandler%3A%29) 官方接口及本机 SDK 编译已核对（2026-10-05）。初始位置提示不替代用户选择或服务完整校验；正式签名／沙盒实际目录授权仍须独立验收。

[目录面板诊断](https://github.com/lyx5710317/pdfno/actions/runs/37299244807)中，BYOK、DeepSeek、英语三项实际通过，目录用例在143秒内完成全部服务／原件／SHA／新目录／重启检查，但系统 `message` 的路径提示没有进入预期 AX label。后续使用 Apple [`accessoryView`](https://developer.apple.com/documentation/appkit/nssavepanel/accessoryview) 加入可访问的当前目录文本，并由 `NSOpenSavePanelDelegate` 的目录变化回调更新实际位置；测试继续核验完整目录路径，不再把配置提示当作面板实际位置。全部业务断言和原超时保留，新候选仍须完整 CI。

未保存草稿拒绝维护、恢复后编辑基线核对、窄窗／深浅色／键盘仍需人工闭环。不能在当前用户桌面运行同 bundle ID XCTest。

实际 VoiceOver、真实 iPhone/iPad／Apple Pencil、实际云同步／Bookno API、真实服务语法质量与账单均未验收。移动端共享模块编译成功不能当作移动阅读入口完备。EPUB resize 清除临时 selection 是既有边界，本批未声称消除。独立安全专项仍为 `UNVERIFIED / platform-blocked`，Figma 配额阻塞未重试；功能与源码检查不能替代独立安全或未取得设计稿的像素验收。

主 checkout、原有工作树与 Xcode 用户元数据保留，无本批实际用户数据变化。发布前可回退本地整合提交。若未来使用了回收站，先保留完整根目录／备份并通过当前模块恢复所需条目，再降级；旧应用不识别 `local-recovery-v1.json` 或英语记录／英语编辑 draft case，不能承诺旧版本可读取或覆盖。保留全部 Git 历史与切片提交，不用删源文件或全目录替换实现回滚。
