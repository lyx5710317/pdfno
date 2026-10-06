# Mac 输入/离线凭据有界实验 · 2026-10-06

本轮按后续授权，仅选择两个原失败代表，先保持原 typeText 驱动各执行一次，再仅修测试驱动后对相同两项各复验一次。**初测 0 PASS / 2 FAIL / 0 SKIP，复验 2 PASS / 0 FAIL / 0 SKIP；生产源码未改。** 原完整 60 项证据保持 33 PASS / 27 FAIL / 0 SKIP，未再跑完整套件，不能将全部 11 项凭据失败标为修复。

| 原方法 | 原输入驱动的实测 | 仅测试驱动修复后的实测 |
| --- | --- | --- |
| NativeUITests/testMacBYOKExplicitRecipientManualSaveAndDefaultChainsStaySeparate | 合成凭据应用内匹配 false；实际请求 authMatchesFixture false、payloadValid true、attemptNumber 1；原结果存在断言失败，48.406 秒。 | 相同 App 二进制，合成凭据匹配 true；实际请求 authMatchesFixture true、payloadValid true、attemptNumber 1；原结果、手动保存及默认链断言均 PASS，54.988 秒。 |
| ReadingIntegrationUITests/testMacSettingsCategoriesPreserveUnappliedConfiguration | 切换分类前等值 false；返回后仍 false，实际合成标签 regional棚顶，预期 Original pending label；原等值断言 FAIL，24.678 秒。 | 分类前后均等值 true，实际 Original pending label；原未应用配置保留、取消后不持久化断言 PASS，21.637 秒。 |

初测 xcodebuild 退出 65，suite 73.084 秒，两个失败方法、三个失败记录、零 unexpected。复验退出 0、TEST EXECUTE SUCCEEDED，suite 76.624 秒。两结果包均已收尾；正式 summary 为 Failed/2 和 Passed/2，正式复验方法树只有指定两项，日志确认每阶段各方法只开始一次。

证据证明这两个代表在应用接收输入时已偏离预期，设置值没有在分类切换时进一步改变，离线拒绝来自不匹配的合成凭据。替换输入驱动后，相同二进制与原断言通过，支持输入驱动/组合态诊断。没有修改或独立确认系统输入法，不能据此判定其他 25 项的唯一根因，也不能排除其他产品问题。

## 修复范围

只有两个已跟踪 UI 测试文件改变：Native 的上述凭据 typeText 改为现有 enterSearch 的合成粘贴路径；ReadingIntegration 的设置标签改为现有 paragraphPaste。两个路径保留原点击、选择与原生 Command-V；按本轮明确边界删除剪贴板快照/恢复，不读取系统剪贴板原内容，只写合成 fixture。执行后剪贴板可保留合成串。

共有 4 行新增、19 行删除；没有增加 UI 方法、skip、retry、超时或放宽等值/来源/保存断言。两文件全部 **628 条 XCTest 断言表达式逐字节相同**（Native 595、ReadingIntegration 33），60 个测试方法名及数量保持。原 56 方法中只有上述两处输入语句改变；其余方法正文没有修改。新增段落 4 方法正文保持，共享 paragraphPaste 的剪贴板读取被删除后本轮只编译，没有再次运行这 4 方法；其最新实际 4 PASS 来自此前完整 60 结果，不能当作本提交新增复验。

实际 diff：evidence/input-probe-driver-fix.diff；保护记录：input-probe-assertion-protection.json、input-probe-source-protection.json。正式应用/服务/模型、精确 Unicode 来源保护、草稿、3/6 预算与零自动重试均没有更改。Swift 542/66 suites、Mac/iOS 双架构 build-for-testing、Node 14 PASS 是既有整合实测；本轮只改 Mac 测试输入，未重跑这些套件。诊断离线 transport 的既有 3 方法/6 参数分支 PASS 保持其原证据。

## 隔离与执行证据

专用 App：org.pdfno.integration.inputprobe20261006.PDFnoMac；runner：org.pdfno.integration.inputprobe20261006.PDFnoMacUITests.xctrunner。忽略目录 .build/IsolatedInputDiagnosticProject 使用独立 Tests 和 PDFnoKit 副本，runner 环境 PDFNO_ISOLATED_UI_APPLICATION_ID 与 UITargetApp 路径/ID 均指向此 App。入口在初始化前保障有效 UUID 和 offline；每方法原 helper 生成新 UUID，不采用真实 Library 或凭据。虚构凭据仅 synthetic-reading-ui-credential；没有真实 API 请求或 network fallback。

DEBUG 观测只在这个 bundle、diagnostic=1、offline、有效 UUID 同时成立时启用：现有配置状态行显示合成值匹配布尔值；transport 在自己 UUID 根目录记录 auth/payload 布尔值和次数，测试只读取自己的这一具名文件。不输出密钥或读取其他测试目录。观测只在忽略副本，未提交到产品。除 BYOKSettingsView 与 OfflineSelectionUITestTransport 的观测外，所有复制 package Sources 与已跟踪源码相同；transport 的严格 guard 与其后全部响应代码逐字节相同。

初测及复验 App executable SHA 均为 129f390f6a1e2188419e423792fd1fce13948aa0ecb19201a41dc713e794ae85，修复后只有测试产物改变。两次 build-for-testing 均 PASS（本机 Mac arm64）；两次 UI 均在共享 run-heavy-check.py 锁内、parallel NO、仅两个 only-testing、180/240 秒预算、默认单次、keepNever，不运行保存面板分组或全 60。执行前核验上一轮精确 PID 已结束；复验前初测已收尾且 App 日志完成两次终止。结束后 xcodebuild/runner/两 App 精确 PID 均不存在，锁非阻塞检查可获取，未删除锁。

准备时发现复制 Tests 目录继承符号链接，临时观测误写两个已跟踪测试。已保存 diff、将新副本 Tests 实体化，再按 HEAD 恢复这两文件，核验源树完全干净后才编译和启动 UI；旧 App 入口未写穿。最初默认沙箱编译在工作区解析阶段退出 66、0 UI，保留日志；改用绝对路径和获批本地编译后通过，不将首次退出计为 UI 失败。见 input-probe-preparation-restoration.json / unintended-source.diff 与 initial-build-command.json。

main 仍 6a67d1fd883f79737d0e3e12c756b683a662f230，未跟踪 Xcode workspace metadata 原样保留；既有 Full60 产品哈希未变、旧日志及结果未覆盖，19 张自制截图 SHA 未变，本轮无新截图导出。既有最早开发 App 自动启动的默认库隔离偏差仍保留在总报告与收据：瞬时写入/迁移 UNKNOWN，未因此重读、回滚或清理真实库。没有修改用户正式 App、系统主题、输入法、安全权限，未安装组件。

## 剩余分组与验收边界

| 历史失败分组 | 本轮后尚未复验的方法数 | 后续边界 |
| --- | --- | --- |
| 原搜索输入 | 3 | 本轮只证明设置代表；搜索结果/焦点仍未复验。 |
| 严格离线凭据 | 10 | BYOK 代表已通过；DeepSeek、日语、整页/整章等只保留历史失败，不能统一判修复。 |
| 打开/保存面板服务 | 7 | 历史 xcresult 有服务崩溃；本轮未跑，禁止面板循环。 |
| 电子书组合谓词 | 4 | format/body/progressQuote 哪项偏离尚未确认，本轮未跑。 |
| DOCX 损坏归档错误 | 1 | 未观测到预期错误的根因仍未确认，本轮未跑。 |

共 25 个历史失败方法本轮未复验；完整 UI 验收仍未通过。真实模型/schema 成功率/解释质量、移动实际 UI/Intel runtime 等未验收；安全专项 UNVERIFIED/platform-blocked 不重试。ebook 两项 Node 仍 NOT-RUN：缺 jsdom，npm 安装尚未批准。既有 npm 安装被自动审批拒绝，本轮没有再次申请或执行安装；没有全仓审计、push、dispatch、merge 或公开发布。官方 Library 上传仍受已有 Python 兼容问题阻塞，只有本地截图路径、没有 library_file_id。

## 本地交付索引

证据根：主仓库内 .build/MacUIExperience/2026-10-06/evidence（不在本地 worktree 内）。

- input-probe-outcome.json：正式结果、观测、剩余分组及保护状态。
- input-probe-{initial,fixed}-plan.json：实际 bundle、路径、哈希和次数边界。
- input-probe-{initial,fixed}-ui-command.json / .log，InputProbeInitial.xcresult / InputProbeFixed.xcresult：两阶段实际执行。
- input-probe-{initial,fixed}-summary-command.json / .log，input-probe-fixed-tests-command.json / .log：正式摘要和方法树。
- input-probe-initial-build-corrected-command.json / .log，input-probe-fixed-build-command.json / .log：两次编译。
- input-probe-driver-fix.diff、input-probe-ignored-observation.diff：提交内驱动修复与未提交观测分开保存。
- input-probe-assertion-protection.json、input-probe-source-protection.json、input-probe-final-process-check-command.json / .log：原断言、产品源码和进程证据。
- input-probe-source-guard{,-corrected}-command.json / .log：报告绝对本机路径触发保护后改为仓库相对路径，未放宽保护。
- FINAL-RECEIPT.json、screenshot-inventory.json：当前汇总收据及 19 张本地截图索引。

完整 60 逐方法矩阵见 [MAC-UI-FULL60-2026-10-06.md](MAC-UI-FULL60-2026-10-06.md)，此前失败分组见 [MAC-UI-FAILURE-DIAGNOSIS-2026-10-06.md](MAC-UI-FAILURE-DIAGNOSIS-2026-10-06.md)，产品小修/人工工具驱动体验及隔离偏差见 [MAC-UI-EXPERIENCE-2026-10-06.md](MAC-UI-EXPERIENCE-2026-10-06.md)。这些均为本地实测和证据报告，不是人工签字验收或发布。
