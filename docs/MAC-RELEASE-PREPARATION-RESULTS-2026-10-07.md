# Mac 首版 Release 本地准备结果（2026-10-07）

产品基线 `7c766decd7e7631a30279a31865bf42b4e89fb43`，文档基线 `5961d002ed35814853fc84a01b83367558f088ea`。配置与脚本候选 `16361e89f13e47a653ea849b3fb14e39247f6c0f`，独立分支 `feature/mac-ui-experience-20261006`。源码／archive 冻结在该精确候选；后续 README 与此报告只补充文档。main 与原 Xcode 未跟踪 metadata 保留。没有 push、dispatch、合并、公开发布或公证请求。

证据根目录（R）：主工作区 `.build/ReleasePreparation/2026-10-07/evidence`。原始证据仅保存在本机，没有 Library 附件 ID。可复现流程见 [MAC-RELEASE-PREPARATION](MAC-RELEASE-PREPARATION.md)。

## 已实施及验证

- Mac App Release 启用 Hardened Runtime，空 entitlements、关闭 base entitlement 注入／testability／previews、默认关闭代码签名且 identity／team 为空。没有 App Sandbox、runtime exceptions 或新增文件／网络／iCloud／Keychain 权限。配置差异 `R/configuration-delta.json` 确认其他 build configurations 不变，生成器重复运行结果一致。
- Mac App 打包原始 LICENSE、SOURCE-NOTICES、THIRD_PARTY_NOTICES，原 engine／codec notices 保持原内容。前一轮报告三处用户名绝对路径改为仓库相对路径，私有本地原始证据不删。源码扫描发现的问题及修正如实保留，不称法务 V03 已关闭。
- 无签名 `archive` 实际 exit 0；arm64／x86_64 二者均存在。30 条实际 Swift compile invocation 均 `-O`，无 `DEBUG` 或 `-enable-testing`；首次临时抽取断言误包含版本探测行，收紧至实际 `-module-name` 调用后通过，未改源码／重建来掩盖断言。`R/archive-optimization-evidence.json` 保存修正范围。
- 包检查 exit 0：21 个生产资源与源码逐字节匹配，另有三个顶层 notice 匹配；无 UI test runner、Debug mock symbols、private signing assets 或意外外部 library linkage。`R/UnsignedArchive/package-check.json` 保存逐包文件及资源 SHA-256。
- 本地验收器 5 项正反向测试 PASS：拒绝 runtime 例外／Sandbox／get-task-allow、资源缺失或篡改、DEBUG／单架构／testability、正式签名和私钥类文件。全为自制临时夹具，没有真实密钥。
- `swift test -c release` 选定 50 项／6 suites PASS：EPUBMultiOwner、DraftMultiOwner、JapaneseSaveGeneration、ParagraphExplanation、EPUBWebKit、EPUBChapterWebKit；编译完整测试 target，实际只执行上述 suites，未声称全部 572 项 Release 执行。transport 都是显式 mock，未读真实 Keychain／API／书库。包括 WebKit 实际 DOM／Unicode 来源及来源保存、旧草稿／保存代际边界。

无签名 archive 的 arm64 链接器生成 ad hoc linker signature，`flags=0x20002(adhoc,linker-signed)`、无 Team／Authority、resources 未正式封装签名。配置 `YES` 不等于生产包实际 runtime 签名生效；该项仍 UNVERIFIED。保留 universal archive、明确命名 `PDFno-UNSIGNED-QA.zip` 和对应候选 `git archive` 源码包，均不能发布为官方下载。

## 隔离 ad hoc Release QA

专用 bundle `org.pdfno.integration.releaseprep20261007.PDFnoMac`；快照只对 App 入口增加 bundle／UUID／范围 guard，对 AIHTTPProvider 的网络 send 和 SecurityKeychainClient 作直接拒绝替身，其余生产 package 与全部原 60 UI 方法逐字节相同。两个替身仅在 R 内 QA 快照，未进入生产源码；完整差异 `R/qa-only-source-deviations.patch`。所有库根目录为新的 `/tmp` UUID 目录，0700、当前 owner、外置 session marker，重启只允许本 bundle 已登记目录。进程记录不进入 Library。没有读取用户书籍、笔记、私钥、账户证书、Keychain 内容或发送真实请求；未更改系统主题／安全权限。

双架构 `build-for-testing` PASS，但预检查发现 Xcode 自动将临时 filesystem／mach-lookup 测试 entitlements 注入被测 App。**在 App／GUI 启动前拒绝该产物**，保留 `R/qa-preflight-blocked.json` 和签名／entitlement 原文。随后同隔离快照进行普通 Release `build`，移除测试注入权限；实际 exit 0。两片实际 signature 都是 ad hoc＋runtime，entitlements 都为空，资源签名严格验证通过。没有接受任何权限例外，不修改或重签用户 App；这只证明 QA 包的签名及注明运行范围，不是 Developer ID 或 Gatekeeper 验收。`R/qa-app-both-architecture-runtime.json` 为双片读回证据。

六条原 UI 方法单次串行、默认 `platform=macOS` destination、零重试，实际 **6 PASS／0 FAIL／0 SKIP**，command exit 0，xcresult summary／test tree／scoped log 三处一致，runtimeWarnings 0。每条实际 started／passed 均只有一次，总区间 254.54 秒；12 次 App launch／6 个自制 UUID 书库 session。

| 原 UI 方法 | 实际结果／秒 |
|---|---:|
| EbookFormatUITests/testMOBISelectionNoteProgressRestart | PASS／33.292 |
| NativeUITests/testLocalPDFReadingAndNoteFlow | PASS／23.322 |
| NativeUITests/testMacCBZImportSpreadsDirectionPageJumpAndRestart | PASS／70.830 |
| NativeUITests/testMacDOCXImportSemanticSelectionNotesAndRestart | PASS／48.047 |
| NativeUITests/testMacEPUBSelectionRubyNotesAndRestart | PASS／28.652 |
| NativeUITests/testMacTXTImportSelectionNotesNavigationAndRestart | PASS／48.014 |

正式本地计数 `R/release-qa-formal-receipt.json`；原 summary／tree／log／命令均保留。system/user attachments 为 keepNever；没有导出私人屏幕或 system log archives，不将当前自动 UI 称为人工体验验收。跑后 App／runner／测试 Xcode 均已退出，共享锁释放，QA 三个二进制 SHA 与跑前一致（未在测试时重签／扩大 app 权限）；六个 root 只读 metadata 核验 0700／当前 owner。主树、未跟踪 Xcode metadata、原 60 方法及仍运行的历史 InputProbe 二进制保全，未向任何既存 App 发信号；见 `R/post-validation-protection.json`。

## 正式分发及其他未验收

- R03 无签名 Release 构建／资源／优化 PASS；R04 正式 Developer ID、公开 Team／identity、时间戳／正式包签名与 effective runtime，R05 notarization／staple／最终 ZIP，R06 真实下载 quarantine 在线／离线启动，全部 NOT-RUN。没有访问 cert/private key／Keychain 或配置账户／profile。
- Release 最低 macOS 14、版本 0.3.0／build 1 保持原值。当前只有本机 Apple silicon 运行范围；Intel、macOS 14 实机、正式下载环境未测。
- 完整 Release GUI 60、阅读导出取消／SavePanel／备份恢复 GUI、VoiceOver、真实模型 schema 成功率／解释质量未测；选定优化 storage/backup/mock/DOM 测试不替代这些交互验收。原 Debug 572 Swift／25 Node／60 实际 UI PASS 证据保持，但不冒充 Release 验收。旧 15 条 Debug runtime warning、默认 Library 启动历史 UNKNOWN、历史 CUA 延迟锁窗 UNVERIFIED 保留；安全专项 UNVERIFIED/platform-blocked 不重试，mobile/iCloud/Bookno/MCP 后置。
- 后续所需非秘密信息：获授权开发者环境的公开 Team ID、Developer ID Application 公开身份名称、bundle／版本／最低系统确认，以及执行签名与隔离下载验收的环境。无需提供密码、私钥、证书导出或公证凭据；本次不请求读取任何秘密。签名／公证／发布需后续独立授权。
