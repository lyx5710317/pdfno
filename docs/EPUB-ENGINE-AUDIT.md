# EPUB 引擎平台与许可审计

核验日期：2026-10-02
状态：**静态源码与官方文档已核验；引擎未选定、未安装、未构建、未做三端实测。**

## 选择条件

PDF 已按 ADR 0002 确定采用 PDFKit，EPUB 独立选型。以下候选用于后续试验排序，不构成引擎实施批准。原生应用内使用 WKWebView 与“把整个应用做成网页”是不同的模块安排；书库、学习界面和数据层继续采用原生路线。

入选引擎须具备可获得源码、可保留的第三方声明和可复现版本；并通过 Mac、iPhone、iPad 的打开、重排、ruby、选区、搜索、定位、安全与内存测试。根许可证核验不等于全部传递依赖、字体、fixture 和可分发产物均已审计。

## 固定证据与平台结论

| 候选与固定基线 | 许可证据 | 已核实的平台事实 | PDFno 评估结论 |
| --- | --- | --- | --- |
| Readium Swift Toolkit **3.11.0**，提交 `d82f44f4f05d87add9e22a8b75abbd61dce745dd` | 根 LICENSE 为 BSD-3-Clause | `Package.swift` 声明 iOS 15.0，Swift tools 5.10；Shared 明确链接 UIKit。不能据此声称支持原生 AppKit macOS | iPhone/iPad 的有力候选；若采用，Mac 需要另一 adapter 或经过单独验证的移植。Mac Catalyst 不自动等同于原生 macOS 支持 |
| foliate-js，提交 `78914aef4466eb960965702401634c2cb348e9b1` | 根 LICENSE 为 MIT；README 列出 zip.js BSD-3-Clause、fflate MIT、PDF.js Apache 的嵌入依赖 | 官方说明面向 WebKitGTK、Firefox、Chromium；未提供 PDFno 的 Apple WKWebView 三端验证。README 明确提示 API 不稳定、目前无发布版本 | 优先评估作为三端共用 EPUB WKWebView adapter 的可行性；仅是建议，不是已选引擎。固定提交并承担维护、安全适配成本 |
| FuturePress epub.js，提交 `eee359d0790002115a1156a9833c54f4bcd44c1d`，源码 package 版本 **0.3.93** | `license` 文件与 package 为 BSD-2-Clause | 浏览器 JavaScript 阅读库；README 描述分页、滚动和选区扩展；没有原生 AppKit/UIKit 的兼容承诺 | 作为同一 WKWebView 路线的对照候选。需独立测 WKWebView、安全配置和依赖升级，不能把浏览器示例当作三端验收 |

Readium 的 tag 经 GitHub API 解析到上述 commit。其当前 `develop` 是另一基线 `26c2efd6211a829c57187fb1fe9a1a98e6f47ee3`，包的工具版本为 Swift 6.2，仍声明 iOS 平台；不混用 develop 与 3.11.0 的工具链结论。[3.11.0 发布记录](https://github.com/readium/swift-toolkit/releases/tag/3.11.0)、[固定包声明](https://github.com/readium/swift-toolkit/blob/d82f44f4f05d87add9e22a8b75abbd61dce745dd/Package.swift)、[固定许可证](https://github.com/readium/swift-toolkit/blob/d82f44f4f05d87add9e22a8b75abbd61dce745dd/LICENSE)、[develop 包声明](https://github.com/readium/swift-toolkit/blob/26c2efd6211a829c57187fb1fe9a1a98e6f47ee3/Package.swift)。

foliate-js 的浏览器范围、版本状态和依赖许可来自[固定 README](https://github.com/johnfactotum/foliate-js/blob/78914aef4466eb960965702401634c2cb348e9b1/README.md)与[固定 LICENSE](https://github.com/johnfactotum/foliate-js/blob/78914aef4466eb960965702401634c2cb348e9b1/LICENSE)。Apple 的 [WKWebView](https://developer.apple.com/documentation/webkit/wkwebview)在三端可用，仅证明宿主控件存在，不能替代引擎在该控件中的验证。

epub.js 的版本、声明和默认脚本策略分别见[固定 package](https://github.com/futurepress/epub.js/blob/eee359d0790002115a1156a9833c54f4bcd44c1d/package.json)、[固定 license](https://github.com/futurepress/epub.js/blob/eee359d0790002115a1156a9833c54f4bcd44c1d/license)、[固定 README](https://github.com/futurepress/epub.js/blob/eee359d0790002115a1156a9833c54f4bcd44c1d/README.md)。

## 建议比较的两种接入方式

**方案 A：同一个 EPUB JavaScript 引擎，三端分别承载于 WKWebView。** 先比较 foliate-js 与 epub.js。优点是 EPUB 排版、CFI 与来源提取策略有机会共用；代价是必须自己验证 Apple WebKit、安全资源加载、可访问性、内存和 JS/Swift 边界。不得让 JavaScript 引擎处理 PDF；PDF 固定走 PDFKit。

**方案 B：移动端 Readium Swift，Mac 使用独立 WKWebView EPUB adapter。** Readium 的移动端 API 与宿主路径更明确，但存在双引擎维护、排版差异与 locator 互通成本。需要以资源路径、CFI、原文引文与版本化提取为公共契约，跨引擎失败必须标为需重绑，不直接复制引擎私有位置对象。原生 AppKit 移植 Readium 是额外项目，不能估为免费获得。

建议先以方案 A 做后续限范围验证，再用 Readium 的移动端结果对照；最终选择需记录为新 ADR。当前仅完成候选审计，未认可任何候选的完整分发依赖，也未放弃其余多格式目标。

## 必须解决的安全与分发事项

- foliate-js README 明确提到 blob 同源资源及 WebKit iframe sandbox 限制，要求正确 CSP；epub.js 默认关闭书籍脚本，并指出开启脚本会削弱 sandbox。**不能仅靠 iframe sandbox 宣称书籍安全。** 后续必须分别隔离受信的引擎代码与不受信的书籍脚本，验证 CSP、内容清洗、资源请求阻断和原生消息校验；如果封装无法可靠阻止书籍脚本执行，该候选不通过。
- WKWebView 只允许经过内部资源清单授权的当前书籍资源。默认禁止远程图片、样式、字体、脚本、任意 `file://`、外链自动跳转和通用原生消息；归档路径、符号链接、文件数与解压总量设边界。禁止直接用用户书籍测试外部在线 demo。
- Readium 3.11.0 包声明中的 ZIP/XML/HTML/加密/数据库等依赖须逐项记录最终实际选入产品的版本、LICENSE/NOTICE 与资源；“BSD 根许可”不是依赖审计完成。Readium LCP 的额外私有 framework 不进入当前非 DRM 试验，也不借此绕过 DRM。[官方设置说明](https://github.com/readium/swift-toolkit/blob/d82f44f4f05d87add9e22a8b75abbd61dce745dd/README.md)。
- foliate-js 与 epub.js 的传递依赖、嵌入源码、构建产物和 fixture 也需文件级清单；EPUB 路线不应携带不需要的 PDF.js 产物。保留各自的著作权、许可和免责声明，不把它们重新声明为 PDFno 自有代码。
- EPUB 原书内字体可以在获得文件授权后由阅读器按书籍资源使用；测试与发行包不得顺手复制用户字体、字典或未知许可证资源。

## 后续验证矩阵与选型门槛

下列全部为 **未运行**；本轮不为完成表格而安装候选或搭建试验应用。

| 验证组 | 三端都需覆盖的最小用例 | 退出条件 |
| --- | --- | --- |
| 格式与资源 | 自制 EPUB 2/3、重排/固定版式、目录、图像、离线资源、损坏/受限文件 | 能打开合法样本；失败明确；无外部网络加载 |
| 语言与选区 | 日语横排/竖排、作者 ruby、重复句、emoji、组合字符、跨段选区 | 正文快照不混入 rt/rp；Unicode 单位明确；不删作者内容 |
| 排版与位置 | 改字号、旋转、Mac 调窗宽、iPad 分屏、离开/返回与重启 | 原文定位稳定或明确需重绑；页翻译仍引用原始快照 |
| 交互与可访问性 | 鼠标/键盘、触摸、外接键盘、VoiceOver、Dynamic Type | 选区进入原生学习栏后保留；没有不可达核心操作 |
| 安全与资源上限 | 恶意脚本/事件、远程 CSS/font、危险 URL、伪造消息、归档炸弹 | 不执行书籍脚本、不越权读文件、不访问凭据；可取消并报错 |
| 性能与升级 | 小/大书、快速切书、后台/前台、WebContent 进程退出、版本更新 | 记录硬件/OS/内存/延迟；无跨书结果，缓存可清理，异常可恢复 |
| 许可与可复现 | 固定源码及完整实际依赖、原始 notice、可再构建资源 | 公共源码和声明齐全；无未知产物、用户内容或私有框架 |

只有通过上述范围后，才把“候选”改为“已选”、添加依赖并实施正式 EPUB adapter；通过哪种格式/设备就只声明哪种实际能力。

## Koodo/Kookit 研究的修正与保留

旧审计把 Kookit 的许可边界合并描述得过宽。2026-10-02 已核验官方公开的 Kookit core 仓库，固定提交 `95f602ed62d204af0de9278cf53212c309b34bfc`、包版本 1.0.4，提供渲染源码并声明 AGPL-3.0-or-later。[源码入口](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/src/index.ts)、[package](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/package.json)、[LICENSE](https://github.com/koodo-reader/kookit/blob/95f602ed62d204af0de9278cf53212c309b34bfc/LICENSE)。

Koodo 固定提交 `90e659f0188795f9a4f6e1ccc1727fd3793fe4a4` 的架构表具体把 `kookit-extra.min.mjs` 标为闭源；额外引擎涉及文件/配置/存储/同步工具。公开 core 不自动证明 extra bundle 的许可或对应源码，也不证明任何 minified 产物与该 core commit 对应。[原架构说明](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/CLAUDE.md)、[bookUtil 依赖](https://github.com/koodo-reader/koodo-reader/blob/90e659f0188795f9a4f6e1ccc1727fd3793fe4a4/src/utils/file/bookUtil.ts)。

现在停止 Koodo/Electron 新增接入是用户已决定的路线变更，不应解释为“Kookit core 没有公开源码”。研究材料仅作历史参考和多格式能力清单；未将 core、extra、测试二进制、字体或资产加入 PDFno。
