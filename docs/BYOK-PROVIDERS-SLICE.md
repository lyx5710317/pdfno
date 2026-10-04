# BYOK HTTPS chat provider 首片 — 本地候选

基线：已验收 main `bb6928e1319f85a72c967a6c3f054bb544e9c306`。独立分支 `feature/byok-providers`；仅本地候选，不 push/merge/发行。Mac 优先，AGPL-3.0-or-later。当前主应用入口继续保持原来的官方 DeepSeek；本片按授权交付独立组件与 factory/adapter 契约，尚未接入 Library 入口。

## 实现范围

全部生产变化为新增文件；不修改 `LibraryWorkspace`、`LibraryModel`、原 `AILearningModel`、现有网络／日语／页／章 prompt、任何 manifest 或原测试。

- `BYOKProviderContracts`：只接受明确 HTTPS endpoint 与 model。根路径规范为 `/v1/chat/completions`，基础路径只追加一次 `/chat/completions`，完整路径不重复追加。官方 DeepSeek 的既有可用预设继续解析为原固定 URL。拒绝 HTTP（含 localhost／IPv4／IPv6 loopback）、其他 scheme、userinfo、query、fragment、反斜线、编码 authority、控制字符和无效端口。非 ASCII 域名需用户输入 ASCII/punycode 地址，避免确认显示与发送 host 分歧。
- `BYOKProviderCapability`：区分原官方 DeepSeek 与有限 HTTPS chat JSON 协议。通用协议明确要求 Bearer、system/user、`stream:false`、`max_tokens`、`response_format:json_object`、单个 assistant 完成响应、精确来源回显与严格 JSON 内容。这不证明任意供应商／任意模型均兼容，也不提供自动探测或自动降级。
- `BYOKProviderSession`：endpoint/model/label 与凭据仅在内存。任何配置应用生成新修订和新引用；endpoint 修改包括无效地址都会撤销旧临时凭据。新域名必须手动重新输入密钥。旧 provider 无法借新修订读取密钥，配置改变后迟到结果被拒。无持久 Keychain、账户、签名／权限变化。
- `BYOKProviderFactory.selection`：官方 DeepSeek 走原 `DeepSeekSelectionProvider`；其他配置走独立的受限 chat adapter。factory／preview 创建不读取 key、不联网。仅 PDF／EPUB 选文≤500 UTF-16、1024输出 token 请求上限、≤30秒；拒绝页／章来源，不复用日语 prompt。原 `selection-1` prompt 保持相同文本与 JSON user 数据。
- 新 adapter 使用原 ephemeral `URLSessionAITransport`：无 cookies/cache；所有重定向，包括同 origin，均拒绝；64 KiB 响应预算。保留认证／额度／限流／redirect／server／结构／截断／timeout／cancel 安全错误，不日志化原文、key 或响应。输出为纯文字，来源锚点由原请求保留，模型不能制造导航坐标。
- `BYOKSettingsModel`、`BYOKSettingsView`、`BYOKSelectionConsentView`：独立 SwiftUI 组件，默认显示官方 DeepSeek；可编辑 HTTPS endpoint/model/名称及临时 SecureField。endpoint 编辑立刻清空待输入 secret、撤销凭据标志与旧确认。确认组件显示实际接收域名、最终 URL（含端口／路径）、模型、任务、来源位置和完整原文，用户明确同意并点击后才发送。

## 集成契约

宿主给组件一个长期存活的 `BYOKSettingsModel`，注入与现有学习功能相同的 `AppAISession`，勿为设置窗口另建可重置预算的 owner。模型内部使用 `AIJobCoordinator` 的完整 source/provider/kind/prompt fingerprint、内存缓存、超时与取消；所有真实提交共用原 `AppAISession.selection` 三次额度。失败或取消也计数；改 endpoint/model、清除／重新输入 key、重开组件不会补充额度。probe/page/chapter 额度不受本片影响。

初始化／显示时 `await model.load()`。设置组件应用配置只影响内存；关闭应用后重新配置，不读取旧用户账户或旧书库。宿主在阅读器已捕获不可变且已验证的 PDF/EPUB `AISourceSnapshot` 后调用 `await model.prepareSelection(source, kind:)`，再显示 `BYOKSelectionConsentView(model:sourceIsCurrent:)`。其 callback 必须验证当前 book/session/documentVersion/edition/hash/实际来源。宿主在换书、换选区、reader session 失效和关闭组件时调用 `model.invalidate()`；开始前及结果返回后仍检查当前来源。

结果是原 `AIResult`，保留原来源与 provider 修订；本片不自动保存笔记或覆盖用户草稿。宿主后续可按原来的显式保存及来源回跳契约消费 `model.result`。清 key／编辑 endpoint 不删除已有结果或外部笔记。新组件与旧 `AISettingsView` 不是同一个入口；不得只把旧预览 adapter 当成此处受绑定的生产 factory 使用。

纯 Services 宿主可以先 `session.configure(candidate, temporarySecret:)` 得到快照，再以 `BYOKProviderFactory.selection(snapshot:session:transport:aiSession:)` 创建 adapter。发送应通过 `BYOKSelectionPreview` 的最终 URL／完整选文展示和 `AIJobCoordinator.run(request, consent:provider:)`；配置／来源变化必须重新 preview。`AIConsent` 为应用契约，不代表服务自动获得用户同意。

## 本地证据

- 轻量 Domain target，`swift build … --target PDFnoDomain --jobs 2`：通过。
- `swift test … --jobs 2 --no-parallel --filter 'BYOKProviderTests|AITests|DeepSeekSelectionTests|AppAISessionTests|PDFPageTranslationTests|EPUBChapterTranslationTests|JapaneseLearningDomainTests|JapaneseLearningFlowTests|JapaneseLearningRepositoryTests|JapaneseLearningComponentTests'`：**99测试／10 suites，2.744秒，通过**；其中新增 BYOK **18项**，全部 URLProtocol URL 均拦截，仅合成文本和假凭据，另有非合作 transport 用于迟到／取消。
- 覆盖实际 URL 与 source preview、PDF/EPUB JSON wire、原官方 DeepSeek wire、共享额度、旧 key 不转新域名、无效 endpoint 撤销、页／章拒绝、源文 Unicode／schema／角色／tool／完成状态／响应体预算、HTTP 错误／不自动重试、同 origin／跨 origin／降级 redirect 拒绝、确认 fingerprint、取消／timeout／endpoint 变更迟到、独立设置 load/edit/manual send/clear/cancel 生命周期和单调预算显示。
- source guard 通过；325个基线源码／测试／资源文件均核对为原字节，含全部原fixtures及43项 UI 方法。`git diff --check` 通过。
- 真实 Mac app／原43项 UI 测试包：最终 unsigned `build-for-testing` **通过，arm64**。iPhone/iPad Simulator target：最终 unsigned `build-for-testing` **通过，arm64＋x86_64**。两者均顺序执行、`-jobs 2 CODE_SIGNING_ALLOWED=NO`；没有启动 App／Simulator 或执行 UI，本地实际桌面 UI **0**。第一次在检测到另一 worker 编译时刚开始的构建已中断，未计为成功；等待空闲后完成两端，最终模型小改动又做了顺序增量确认。

首次测试编译因新组件 catch 变量遮蔽触发当前 Swift6.4 frontend assertion，已改为明确 `self.error`；随后17项运行仅 encoded-host 拒绝一项失败（Foundation 解码 `%72…` host），新增原编码 authority 检查修复。初始失败日志与最终成功日志保留，未缩减断言或修改原测试。

本地外部日志：`/tmp/pdfno-byok-domain-build.log`、`/tmp/pdfno-byok-tests-initial.log`、`/tmp/pdfno-byok-tests-repair.log`、`/tmp/pdfno-byok-regression-final.log`（98项前一轮）、`/tmp/pdfno-byok-regression-delivery.log`（99项最终）、`/tmp/pdfno-byok-source-guard-delivery.log`、`/tmp/pdfno-byok-mac-build.log`（争用中断）、`/tmp/pdfno-byok-mac-build-delivery.log`、`/tmp/pdfno-byok-mobile-build-delivery.log`、`/tmp/pdfno-byok-preservation.json`。日志不包含真实账户、密钥或私人书籍。

## 限制与共享触点

只有 mock 协议／本地编译证据，不证明真实供应商可用、TLS／ATS／代理行为、服务语言质量、账单或完整无障碍。SSE、usage解析、reasoning/vendor 扩展、自动重试、local HTTP 模型、model discovery、持久设置／Keychain、完整移动 UI 和实际桌面 UI 均未交付。真实 Bookno／iCloud 后置；独立安全专项继续 **UNVERIFIED／平台阻断**，未重试或绕过。

文件冲突触点为新增4个生产 Swift 文件、新增测试和本说明；旧入口、Package/project、资源／fixture、prompt 和数据没有改动。运行时的刻意共享触点是 `AppAISession.selection`、`AIJobCoordinator`、`AIRequest/AIResult`、`DeepSeekSelectionProvider`、`SelectionHTTPCodec` 与 `URLSessionAITransport`。后续整合需保留原预算 owner、reader source 校验与手动保存入口；不将本片适配成日语／页／章 adapter。
