# Kookit EPUB 源码审计与落地状态

核验日期：**2026-10-03 UTC**。PDFno 基线：`90d91f70f6baa4ab4eefb15285a4ab7768f6d7e1`。

**结论：固定 Kookit core 已作为独立 Mac EPUB adapter 接入，源码构建与原创样本验收通过。** 本文记录静态审计及后续实施状态；不引入 Electron，不选择其他引擎代替 Kookit。完整格式／平台覆盖仍待逐项验收。PDF 继续使用原生 PDFKit；Mac 优先交付，iPhone/iPad 的长期目标保留。

现有 [v0.3 主规格](PDFno_AI_Development_Spec_v0.3_Native.md)、[候选比较](EPUB-ENGINE-AUDIT.md)、[实施状态](NATIVE-TASKS.md)和[验证记录](VALIDATION.md)已同步当前范围与验证状态。本文保留明确日期，源文件证据不被当前实施结论覆盖。

## 1 核验边界与可复现证据

开始核验时 Git HEAD 为上述提交、没有跟踪文件改动，已有未跟踪 Xcode workspace 元数据保留。补证授权后实现了 Mac EPUB 源码／测试／文档；不改变用户元数据、账号、权限、CloudKit 容器或本机记忆，不关机。提交／CI 结果见最终交付及 VALIDATION。

固定上游为 `koodo-reader/kookit` 提交 **`95f602ed62d204af0de9278cf53212c309b34bfc`**，package 版本 **1.0.4**。通过官方 GitHub API 获取完整树（79 条目，`truncated: false`），物化其中 `src/**` 及 LICENSE、README、package.json、package-lock.json、tsconfig.json、rollup.config.js 共 **55 个 UTF-8 文件**，全部逐文件验证 Git blob SHA-1。算法为 `SHA1("blob " + byteCount + NUL + originalBytes)`。没有执行这些源码。来源：[固定树](https://api.github.com/repos/koodo-reader/kookit/git/trees/95f602ed62d204af0de9278cf53212c309b34bfc?recursive=1)、[固定 package](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/package.json)。

未物化 `test/` 的 minified JS、WASM 工具、下载脚本和其他测试产物；最终只保留 23 个匹配原始 blob 的 Kookit 源文件，构建专用 EPUB bundle；相关原始源码和修改记录在 engine-build。没有使用用户书籍、用户笔记、私有字体或未经许可的样本。

| 关键原文件 | 字节数 | 已匹配的 Git blob SHA-1 |
| --- | ---: | --- |
| package.json | 2025 | `95b278b6d78a26e30bfca1e516610ad233907411` |
| package-lock.json | 226633 | `c34e12a48cd29be0d44a1aa0bc125eaa0bab9782` |
| src/renders/EpubRender.ts | 6677 | `0a4076fa7cff1924945ee048a21f1a483f3a0c13` |
| src/renders/GeneralRender.ts | 63345 | `69c599fa090d468f2922e5b630892d46f97e57f4` |
| src/utils/layoutUtil.ts | 30431 | `1547b4bf1b635938a5ed053dfcf9d424cb77ffb3` |
| src/libs/cfi.ts | 30064 | `2f9b7d05cab74ee8c21515d46df12c45f9ef2349` |
| src/libs/zh-convert.ts | 120470 | `b99c4ef9011e09cd6a05f4300117b00b9f0b651d` |

修订前主规格本地 SHA-256 为 `b3b87b37652e77433f460958421471730e466eab814b52b5029073cc56af50e9`。当日完整读取 Library version **3** 的 1–1183 行，129,476 字节，与该本地基线逐字节一致。随后按当前工作副本修订主规格，同项写回保留版本守卫；实际返回版本见交付。

## 2 许可证据及实际分发缺口

以下同时区分官方源码证据与实际 npm 包审计。最终 profile 的实际 lock、integrity、许可证和 bundle 输入已保存；不能扩大为其他格式或发行包全面许可审核。PDFno 自有源码继续 AGPL-3.0-or-later。第三方源码必须保留各自著作权、原许可、免责声明和修改声明；不将第三方源码重新标为 PDFno 自有代码。

| 对象 | 固定证据与声明 | 本次结论 / 缺口 |
| --- | --- | --- |
| Kookit public core 1.0.4 | [package](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/package.json) 声明 AGPL-3.0-or-later；[LICENSE](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/LICENSE) 为 AGPL v3 正文 | 保存固定源码和后续补丁，提供对应源码与构建方法；不能据此认可闭源 extra 或未知 minified 文件 |
| CFI 来源 fread-ink/epub-cfi-resolver | Kookit `src/libs/cfi.ts` 有来源注释；上游参考提交 `a0d7e4e39d5b4adc9150e006e0b6d7af9513ae27` 的 [LICENSE](https://github.com/fread-ink/epub-cfi-resolver/blob/a0d7e4e39d5b4adc9150e006e0b6d7af9513ae27/LICENSE) 为 AGPL，[package](https://github.com/fread-ink/epub-cfi-resolver/blob/a0d7e4e39d5b4adc9150e006e0b6d7af9513ae27/package.json) 声明 `AGPL-3.0` | 这是已验证的上游参考，尚未证明 Kookit 拷贝对应这个精确提交。保留准确声明，不自动升级为 or-later；接入前补全文件级来源与修改记录 |
| 内嵌 foliate-js | Kookit [README](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/README.md) 指认引擎来源；参考提交 `78914aef4466eb960965702401634c2cb348e9b1` 的 [LICENSE](https://github.com/johnfactotum/foliate-js/blob/78914aef4466eb960965702401634c2cb348e9b1/LICENSE) 为 MIT | 保存 John Factotum 著作权和 MIT 声明；尚未完成 Kookit 内嵌文件与原上游版本的逐文件对应，不能仅靠 Kookit 根 LICENSE 代替 |
| JSZip 3.10.1 | 官方 tag 的 [LICENSE.markdown](https://github.com/Stuk/jszip/blob/v3.10.1/LICENSE.markdown) 为 MIT 或 GPLv3 双许可 | 采用 MIT 路径；实际 npm 包、锁定依赖及原始声明已保存 |
| Underscore 1.13.8 | 官方 tag 的 [LICENSE](https://github.com/jashkenas/underscore/blob/1.13.8/LICENSE) 为 MIT | 实际 npm 包与输入清单已核验，原始声明已保存 |
| Rangy 1.3.0 | 上游 [master LICENSE](https://github.com/timdown/rangy/blob/master/LICENSE) 为 MIT，读取时该文件 blob 为 `f9d34cd42bd0592fa16485d1555bb5f6180ab2bb` | 后续已读取实际 npm 1.3.0 包内 LICENSE，为 MIT，保留全文；不再以 master 证据代替固定包审计 |
| esbuild 0.25.11 | 官方 tag 的 [LICENSE.md](https://github.com/evanw/esbuild/blob/v0.25.11/LICENSE.md) 为 MIT | 已安装并用于构建；MIT 声明保留，不是产品运行时 |
| OpenCC 来源映射 | Kookit `zh-convert.ts` 注释指向 [STCharacters.txt](https://github.com/BYVoid/OpenCC/blob/master/data/dictionary/STCharacters.txt) | 未在本次固定映射来源版本/NOTICE。最小 EPUB profile 已排除该转换模块和数据；如保留，须另核实际来源许可与声明，不由 Kookit 根许可包揽 |

实际最小 profile 使用 JSZip 3.10.1、Rangy 1.3.0、Underscore 1.13.8，加构建期 esbuild 0.25.11。`engine-build/package-lock.json` 有 43 条目，包括根和 esbuild 可选平台包；`DEPENDENCIES.json` 记录 16 个实际 JS／构建包、integrity 和原始许可文件。安装成功为 17 个包（含本机平台 compiler）。isarray 的 MIT 全文保留自实际包 README，pako 同时保留 MIT 与原 zlib 著作权／条件。生成 Notices.txt 合并声明，BUNDLE-INPUTS.json 保存 188 个实际输入；原始 Kookit 23 个文件保持 Git blob 匹配。根许可和 lock 元数据不代替这些实际证据。

## 3 构建及 registry 结论的纠正

完整上游 `package-lock.json` 有 487 个 package 条目，其中 486 个含 `resolved` URL，**全部 host 为 `registry.npmjs.org`**；其余为根 package 条目。此前将 `npmmirror` 请求归因于上游 lock 的判断不成立。

当日只读核验显示本机 npm 默认 registry 的 host 为 `registry.npmmirror.com`。本次获准安装在单次命令显式指定官方 registry，保留全局设置；不改系统网络或 npm 全局配置。源证据：[固定 lock](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/package-lock.json)。

上游 [rollup.config.js](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/rollup.config.js) 使用硬编码 Windows 输出目录、以全格式 `src/index.ts` 为入口、外置多个依赖，并移除注释。不可原样当作 PDFno 的可复现构建。需要独立的 EPUB 专用入口、相对输出路径、准确锁文件、保留声明和 bundle 内容核验；Node 仅参与构建，不成为原生应用运行时。

## 4 接入前必须处理的源码问题

以下记录固定源码问题及处理依据。当前 profile 已替换 loader／wrapper、强制禁脚本、禁用额外资源路径、建立 canonical anchor；原始问题不扩大为所有书籍已覆盖，实际测试子集见第 6 节。

| 发现 | 源码证据 | 对 PDFno 的影响与拟处理 |
| --- | --- | --- |
| 入口导出全格式，包括 PDF | [src/index.ts](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/index.ts) | 专用入口只导入 EpubRender；不调用通用 BookHelper 分流。最终 bundle 检查不含 PDF 引擎或 PDF JS 路由；保留 PDFKit |
| 移动配置强制开启脚本 | [GeneralRender.ts L199](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/renders/GeneralRender.ts#L199)：PDF 或 `isMobile === "yes"` 将 `isAllowScript` 设为 yes | 不能仅传 `isAllowScript: no` 就称安全。PDFno adapter 必须始终禁止书籍脚本并关闭相关上游分支，移动适配也须复测 |
| iframe sandbox 依赖该开关 | [layoutUtil.ts L241](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/utils/layoutUtil.ts#L241) | `allow-same-origin` 只是其中一层；仍需可信引擎与不可信书籍的隔离、清洗、CSP、资源/导航阻断和原生桥校验 |
| 解压没有应用级预算 | [EpubRender.ts L31](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/renders/EpubRender.ts#L31) 的 JSZip、zip.js、fflate 三段 fallback；loadText/loadBlob 直接分配输出 | 首片只保留一个审计后的 loader。Native 校验归档结构和声明大小，loader 对实际输出字节、总量、缓存和资源分配设上限；失败不得转到不受限 fallback |
| 渲染失败可能不能正确返回调用者 | [EpubRender.ts L15](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/renders/EpubRender.ts#L15) 使用 async Promise executor；`await parse()` 未向外层 reject 转发，缺少 document 时直接 return | 控制流推断：失败可能留下未结束的 outer Promise。需改为可 await 的明确返回、超时和取消契约，再用错误 fixture 验证 |
| 可选功能依赖另一些运行时资源 | [layoutUtil.ts L334](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/utils/layoutUtil.ts#L334) 包含 fetchHighlightAsset、脚本注入与 bookLayout CSS 读取 | 最小片禁用并排除代码高亮、附加 layout 资源及中文转换等路径，不复制未知预编译资源。所有运行时请求须经过资源清单 |
| 引文/位置读取多处使用 textContent | [GeneralRender.ts](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/renders/GeneralRender.ts)、[navigationUtil.ts](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/utils/navigationUtil.ts) | 不直接作为永久来源模型；作者 ruby 的 rt/rp、重复文本和 DOM 改写可能影响锚点。需独立 canonical text/DOM 映射和引文校验，保留作者 ruby 展示 |

局部禁用配置不证明不安全代码已从 bundle 移除；必须审计依赖闭包和最终产物。现有 EpubRender/GeneralRender 使用浏览器 DOM、Blob、File 和 iframe，可以据此提出 WKWebView 试验，仅凭静态 API 不能宣称平台兼容；现已完成限定 Mac 宿主验证，iPhone/iPad 阅读仍未验收。

## 5 Mac EPUB 范围与验收库存

本节保留完整验收库存；首片实现范围及通过证据见第 6 节，字体／固定版式／移动／全矩阵仍未验收。各项验收只证明实际跑过的格式和设备。漫画、DOCX、AI、云同步、转换不纳入首片，但原规格目标保留。

1. **可复现源码构建。** 固定 Kookit 源码、实际 npm lock 和补丁；只构建 EPUB 入口，排除 PDF 引擎、未审计资源和全格式依赖。CI 重建与受管资源一致；保存 Kookit、CFI、foliate 和实际传递依赖声明。
2. **Native 书库与隔离 store。** 原始 EPUB 只读、导入后按文件 hash 去重。首片可建立独立 EPUB manifest/notes schema，避免改变现有严格 PDF schema；Swift 原生书库、目录、页面控制和笔记编辑宿主，内容由受限 WKWebView 承载。书籍切换关闭旧 session；旧 PDF 数据与操作须回归。
3. **归档与资源限制。** 实施前固定具体预算；建议初始 20 MiB 压缩大小、1000 条目、单条目 4 MiB、合计 50 MiB，并检查实际解压和缓存量。拒绝穿越、绝对路径、反斜线、NUL、驱动器路径、重复/歧义名字、符号链接、加密/不支持结构；central directory 与 local header 必须一致。不能只相信声明大小或压缩比。
4. **脚本、网络与桥。** 只由可信 app 资源执行引擎代码；禁止书籍脚本/事件、活跃嵌入、DTD/entity 和未经授权的资源。WKWebView 使用隔离数据 store、资源白名单、网络/导航阻断及受限原生消息。桥带版本、随机 session、book/edition/hash、generation/documentVersion/requestID；校验来源、主 frame、字段、长度和命令白名单。迟到结果忽略，取消使 generation 失效，进程退出和超时有明确错误。不给 JS 凭据或任意本机路径。
5. **稳定来源与恢复。** 持久化 edition/file hash、extractionVersion、spine/resource、明确单位的半开正文 span、exact quote 和上下文。canonical walker 排除 rt/rp/script/style，保留正文 Unicode/空白；CFI 是辅助位置，不能替代引文校验。高亮投影避免改变 canonical 源文本；重复短语不猜位置。重排、换字号、重开后恢复；不匹配标记需重绑。
6. **原创 fixture 与真实选区。** 自制 EPUB 覆盖英文、日文横排/竖排、作者 ruby、emoji/组合字符、重复句、多章节和足够分页文本。验证导入、TOC、翻页、真正鼠标/键盘文本选择、高亮、笔记、关闭/重开、回跳。脚本、远程 CSS/font/图片、路径穿越、超限输出和伪造/迟到消息另用自制负面样本；不使用用户原书测试。
7. **范围准确的验证。** Swift tests、Mac build、上述真实 Mac UI 路径和 PDF 回归通过后再报告 Mac EPUB 切片；移动端现阶段仅编译，之后专项验证触摸、重排、ruby、VoiceOver 和桥隔离。不把 Simulator 编译称为移动阅读验收，也不把静态哈希一致称为运行通过。

## 6 实际完成与未覆盖范围

已完成固定源文件物化与 55 个 Git blob 哈希匹配、官方和实际 npm 许可核验、registry 归因纠正、23 文件源码 profile、可复现 EPUB-only bundle、Mac 原生导入／书库／目录／翻页／横竖排／高亮笔记／原文回跳／重开恢复、原创 EPUB 和恶意 markup fixture，以及主规格路线修订。18 个 Swift/WebKit 测试、2 个实际解压安全测试、2 个 Mac EPUB/PDF UI 测试均通过；移动 target 编译通过。最终收尾复核与 exact-SHA CI 见 VALIDATION／交付。

具体运行修正：WebKit 内容规则不支持正则分支，改为逐协议规则；书籍无脚本 frame 的选区监听受抑制，改从可信父页读取选区，不开放书籍脚本；上游 locator 的 page 可为空，视图页码改按实际排版几何计算。没有降低选区／恢复断言以获得成功。

未覆盖：移动 EPUB 真实阅读、固定版式／加密、完整图片／字体／SVG／动画保真、任意大书、搜索、笔记编辑删除、崩溃注入、跨进程协调和全面无障碍。当前静态 PNG/JPEG 单图 4M／总 16M 像素限额，其余资源类型未开放。漫画／DOCX／AI／Bookno／iCloud／转换没有纳入此片。

初次临时 npm 安装曾被自动审批拒绝，理由是它未接受代理转述的开发授权。父线程随后提供用户原话证据；同一原命令、目录和安装参数仅重试一次，审批接受并成功安装。此授权问题已解决，无需再次询问，也没有绕过拒绝。技术／许可条件不满足时仍报告具体缺口，不暗中换引擎。
