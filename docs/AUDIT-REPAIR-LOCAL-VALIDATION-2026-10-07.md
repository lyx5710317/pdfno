# 三项审计修复与本地验证

产品候选：`7c766decd7e7631a30279a31865bf42b4e89fb43`；基线：`0fdcbc58c0b4af28412d2edcbf7a727cefde7d74`。工作树位于 `/Users/artsmartluo/pdfno/pdfno/.build/MacUIExperience/2026-10-06/tree`，分支 `feature/mac-ui-experience-20261006`。本轮只做本地开发与验证，未 push、dispatch、合并 main 或发布。

三项修复已经实现，完整 Swift、Node 与 Mac 双架构编译通过。独立审计复核允许在单进程代码和合成证据范围内关闭三项。**本候选完整 60 项 GUI 尚未验收：唯一一次运行在 runner 初始化阶段超时，零方法开始、零 App 启动。** 历史候选的 60 项通过不能代替本候选结果。

## 修改与证据范围

| 原发现 | 修复行为 | 新增回归及证据 |
| --- | --- | --- |
| P1-01 EPUB 多 repository actor 丢写 | 同进程、同规范根的四个写入口，从读 manifest、CAS、资产处理直到备份/提交共享同步事务锁；先取得既有维护 lease，不跨 await 持锁 | 5 个新方法覆盖并发笔记、第二册导入/进度、单胜 CAS、精确 Unicode、符号链接别名/分根、损坏与未来 schema 拒写、维护暂停/旧 epoch；原审计探针正文不变，24 次成功保存后保留 24 条、missing 0 |
| P1-02 多草稿 holder 陈旧整表覆盖 | 同文件共享事务；owner 保存只合并自身改变的键；按键 checkpoint/CAS 检查前像和进程内 revision。普通 load 不授权陈旧覆盖；旧取消/迟到清理遇冲突保留当前输入。显式重新载入基线才采纳该键版本 | 12 个新方法覆盖不同键合并、同键冲突、取消、删除后同字节重建、普通观察读取、别名/分文件、限额、维护拒写、重启、异步保存清理、Note/Record owner、写失败保留正文；原探针现在保留 A/B 两行 |
| P2-01 日语旧 pending save 迟到错误污染新来源 | 成功与 catch 共用捕获的 generation token；旧失败/取消不发布到新 generation；保留 single-flight、defer 释放、当前来源失败提示和显式重试 | 3 个新方法通过受控 continuation 覆盖 A pending→B、成功/失败/取消、关闭/改配置、保留用户正文/修正、当前失败和重试。冻结旧产品源码负对照直接观测旧错误进入新来源 |

仅修改 4 个生产文件并新增 3 个测试文件，共 20 个测试方法。原 4 个 UI 测试文件、60 个方法正文及 703 个断言调用保持字节不变；其余原文件未删改。草稿仍为 schema 1，既有限额和未知字段拒写保留，没有数据迁移。AI 确认、来源、预算 3/6、零自动重试与旧 plain 记录契约保留。

草稿显式 rebase 会采纳同键最新版本，然后 checkpoint 本编辑器保留的正文；这是单键的一份草稿，并非自动合并两方正文。普通 UI 的双 owner 可达性尚未证明，不声称真实用户数据损失已发生或这些是新引入的回归。事务锁和 revision 是单进程保护，不保证跨进程、断电或其他格式仓库。全局 registry 的存续缓存观察 O01 保留，本轮不扩展修复范围。日语磁盘来源提交 fence V02 也不属于这次 generation 修复。

## 实际本地检查

所有原始证据位于 `/Users/artsmartluo/pdfno/pdfno/.build/MacUIExperience/2026-10-07-repair/evidence`（下称 E）。重型检查使用原共享锁 `.build/PDFnoNativeHeavyChecks.lock`，jobs 2，不安装依赖、不使用真实 key/API/书库。

| 检查 | 实际结果 | E 内原始收据/日志 |
| --- | --- | --- |
| 完整 Swift | 572 tests / 73 suites，PASS，exit 0 | `full-swift-command.json`、`full-swift.log` |
| 完整既有 Node 六组 | 25 PASS、0 fail/skip/cancel，exit 0 | `full-node-command.json`、`full-node.log` |
| Mac build-for-testing | arm64 + x86_64，`TEST BUILD SUCCEEDED`，exit 0；App/runner/tests 签名及双架构验证通过 | `mac-dual-build-recovery-command.json`、`mac-dual-build-recovery.log`、`ui60-plan.json` |
| 源码边界 | 707 文件 PASS，exit 0 | `source-guard-after-build-command.json`、`source-guard-after-build.log` |
| 原 P1 探针 | A/B 草稿均保留；EPUB 24/24、错误 0、missing 0 | `post-fix-original-p1-probe-final-command.json`、`PostFixAuditOutputFinal/result.json` |
| 旧日语代码负对照 | 预期 exit 1：3 方法，四个旧行为分支、8 个断言 issue；直接观察错误值 | `pre-fix-japanese-negative-control-direct-values-command.json` 及同名 log |
| 本候选完整 60 UI 单次尝试 | **BLOCKED**，exit 65；0 方法开始/完成，0 App 启动；正式 xcresult 是 1 条 runner 系统失败 | `repair60-once-command.json`、`repair60-once.log`、`repair60-outcome.json`、`Repair60Once.xcresult` |

负对照在冻结旧 package 中只追加新测试，旧生产源码保持字节一致；测试与新候选对应。8 个 issue 是四分支各有直接值与复合状态断言，不是 8 个产品缺陷；不是新候选失败，也没有把预期失败藏入通过计数。前期相关 78/8 suites、草稿 47/3 suites 等日志另留 E，不与完整 572 相加。

第一次 Mac 编译的执行 session 消失，原日志停在编译中，收据缺 exit/end，保留为 **UNKNOWN**。随后确认该 DerivedData 无打开文件、无编译器进程、重型锁空闲，才用新 `MacBuildRecovery` 完成一次连接恢复；没有覆盖原日志/产物或伪造原退出码。

## GUI 阻塞与隔离

本轮专用 bundle 为 `org.pdfno.integration.auditrepair20261007.PDFnoMac`。隔离入口必须在 Scene 前验证 bundle、UUID session、offline 与 full60 scope，否则退出；书库在 `/tmp/PDFno-UITests-<UUID>`，进程记录仅放在 Library 外。测试 helper 每次新 UUID，使用合成 fixture 和拦截 transport，没有网络 fallback。专用 bundle 有独立偏好域；PDFnoKit 无 UserDefaults 调用，不宣称 UUID session 是一个另建的 defaults suite。

启动前发现历史 `org.pdfno.integration.inputprobe20261006.PDFnoMac`、PID 89684 仍运行。只读核验不同 bundle/路径后保留不动，未关闭、替换或发送信号；本轮 App 没有启动。启动记录完整保留在 `repair60-blocked-admission.json`、`existing-input-probe-identity.json` 和 `repair60-admission.json`。

runner 的明确错误为 `Timed out while enabling automation mode`。正式 summary/tree 与 log 相符；summary 的 1 个 failed test 是 System Failures 节点，不能称一个原方法失败，更不能把未执行 60 方法记为 skipped。结束后只读选定 session 布尔值观测到 `CGSSessionScreenIsLocked=true`，与初始化阻塞一致，但没有证明唯一根因。当前 runner/xcode PID 已退出，共享锁空闲，没有排队 GUI，也没有自动重试、更改 TCC、权限、系统主题、输入法或自行解锁。

桌面可用性已请求确认。全 60 GUI 要在桌面可用、环境重新核验后另行完成；本收据未批准或执行第二次。旧 19 张自制 fixture 截图保留原路径与 SHA，没有新增截图，也不作为本候选 GUI 证据或 Library 附件。

## 独立复核与剩余边界

独立报告：`/Users/artsmartluo/pdfno/pdfno/.build/IndependentAudit/2026-10-07-7c766dec/REPAIR-REVIEW.zh-CN.md`。审阅者核验冻结源码、探针正文、负对照和原始日志/收据，**未重跑测试或 GUI**；其三项限定关闭结论不等同于本候选 GUI 签收。本轮后来完成的 Mac 编译和 GUI 阻塞由实施收据记录，不改写独立报告。

其他仓库同类事务风险、V01 旧 EPUB callback 身份、V02、D01/D02、V03、旧 15 条 runtime warning 保持原状态；本轮没有 GUI 方法执行，不能声称警告已消除。真实模型/解释质量、真实 API、VoiceOver、Intel runtime、最旧系统与广泛书籍兼容未测。安全专项仍 UNVERIFIED / platform-blocked；iOS/mobile 后置，均未执行或重试。历史默认 Library metadata 启动偏差 UNKNOWN、CUA 迟到锁窗口 UNVERIFIED 保留。

main 保持 `6a67d1fd883f79737d0e3e12c756b683a662f230`，既有未跟踪 `apple/PDFno.xcodeproj/project.xcworkspace/` 保留。旧日志、编译产物和截图只读保全。新本地 `FINAL-RECEIPT.json`、`FINAL-HANDOFF.json`、`audit-repair-local.patch` 由 E 保存最终文档 commit、逐文件 SHA、执行收据与未验收项；没有有效 `library_file_id`，不冒称附件交付或发布完成。
