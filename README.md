# PDFno

原生 Mac、iPhone、iPad 阅读器，使用 **SwiftUI + AppKit/UIKit + PDFKit**，源码保持 **AGPL-3.0-or-later**。当前包含本地 PDF 与 Mac EPUB 开发切片，尚未发行。

现在可以导入 PDF、按文件 SHA-256 去重并保存原书副本；用 PDFKit 阅读、选字、翻页、目录和文本搜索；保存选区高亮与笔记、回到来源、恢复阅读进度。高亮只投影到内存中的 PDFDocument，原书副本不被改写。损坏或来自新版本的本地数据会停止保存，并保留原文件。书库目前使用系统书籍图标，封面生成、缩略图与多文档工作区仍待实现。

Mac 已接入 **Kookit public core 的重排 EPUB**：目录、翻页、横竖排、作者 ruby、真实选区、高亮笔记、原文回跳和重开恢复。EPUB 使用受限 WKWebView 内容模块；书库与工具栏保持 Swift 原生，PDF 继续 PDFKit。移动 EPUB 阅读、固定版式、全面图片/字体保真和搜索尚未验收。

Mac 的「模型与 BYOK 设置」已提供服务类型、endpoint、最终 API 路径和 model 配置预览。「选文 AI」明确确认固定选文后，可用**本地 mock**演示翻译／解释、来源引用、独立用户笔记和重启恢复。mock 不联网，输出不是真实译文或语法质量证据。阅读 AI 的真实请求与持久密钥仍未启用。设置另有独立「DeepSeek 短句自助测试」，仅处理固定原创短句，由用户手动输入临时密钥、确认范围与费用后亲自发送；设置、打开书籍和打开测试窗口都不会发送。

短句测试固定为 `https://api.deepseek.com/chat/completions`、`deepseek-flash`，关闭思考模式，每次输出至多 128 tokens，每次应用会话至多三次，失败／取消也计次数，无自动重试。拟议预算 ≤1 元人民币需用户明确确认；客户端不能强制服务商人民币账单上限。测试不读取书籍或配置预览密钥，不保存密钥、结果或请求，不外发选文、笔记或文件。密钥输入发送时清空，关闭／重启不会保留；新版本需自行重新输入。**开发和 CI 只使用虚构密钥与完全拦截的网络替身，尚未验证真实 DeepSeek 连通或费用。** 参见 [短句测试边界](docs/ADR-0005-DEEPSEEK-SELF-TEST.md)。

**漫画、其他格式、真实 BYOK 服务、文档问答、页／章节双语翻译、生成假名、英日语法质量、Bookno API、iCloud、OCR、格式转换和 Apple Pencil 尚未接入或验收。** 其他格式优先沿独立 Kookit adapter 路线逐项审计与验收，不因 EPUB 接入自动开放。完整功能目标和三端规划见 [v0.3 主规格](docs/PDFno_AI_Development_Spec_v0.3_Native.md)、[实施状态](docs/NATIVE-TASKS.md) 和 [引擎审计](docs/EPUB-ENGINE-AUDIT.md)。

## 在 Xcode 中运行

打开 `apple/PDFno.xcworkspace`。选择 **PDFnoMac** 并运行于本机；选择 **PDFnoMobile** 并运行于 iPhone 或 iPad Simulator。两者是独立 application targets，移动 target 同时支持 iPhone/iPad；Mac 使用 AppKit，未采用 Catalyst。共享 `PDFnoKit` 包含 Domain、Services、Readers、UI 四个 targets，没有外部 Swift 包依赖。

临时开发基线为 **macOS 14 / iOS 17 / iPadOS 17，Swift 6，Xcode 16.4+**。这些版本适合当前 SwiftUI API，并为候选 CKSyncEngine 留出兼容范围；CloudKit 尚未启用。最终发行设备范围可以调整。工程只使用本机 ad hoc 签名 `-`，未设置开发者 team、证书、账号、entitlements 或云容器；Simulator 不需要开发者账号。真机安装和发行需要另行配置与验证。

打开应用后，点击「打开示例 PDF」即可试读自制两页样例，Mac 也可点击「打开示例 EPUB」；「导入 PDF / EPUB」使用系统文件选择器。移动端目前只开放 PDF。未解锁的加密 PDF 会明确拒绝；当前文件上限为 200 MiB。PDF 没有文字层时不能选字和搜索。选中文字后打开「高亮与笔记」，可以保存引文和自己的笔记。

Mac EPUB 首片接受非加密重排内容。限额为 20 MiB 归档、1000 条目、4 MiB 单项、50 MiB 实际解压；只接受有像素限额的静态 PNG/JPEG，外部字体、SVG、动画及其他资源暂不支持。书籍脚本和未经授权的网络资源会被清洗／阻断，失败会明确报告。

## 构建与验证

EPUB 资源已经随源码保存，直接在 Xcode 运行无需 Node。需要重建资源时使用 Node 22+：

```sh
npm ci --prefix engine-build --ignore-scripts --no-audit --no-fund --registry=https://registry.npmjs.org
node --test engine-build/loader.test.mjs
node engine-build/build.mjs
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/PDFnoKit
python3 scripts/check-native-source.py
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Mac CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/Mobile CODE_SIGNING_ALLOWED=NO build
```

在 Xcode 的 Test 菜单，或对所选 scheme 执行 `xcodebuild test`，运行真实 UI smoke。测试使用独立临时书库和自制样例，不读用户书库。Mac XCTest runner 需要本机 ad hoc 签名；使用 `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`。Simulator destination 选择本机已安装的设备，不复制其他机器的 UUID。实际设备、工具链、命令和未测范围记录在 [验证报告](docs/VALIDATION.md)。GitHub Actions 检查公开源文件、Swift 测试、Mac 构建/界面流程与轻量移动编译。当前顺序已调整为先把 Mac 做好，再据共享内容完善 iPhone/iPad；移动端功能完备不是这阶段门槛。

工程与样例可通过 `python3 scripts/generate-apple-project.py` 确定性再生。它不下载依赖或配置账号；修改生成的 pbxproj/scheme 时须同步更新该脚本。

## 数据与迁移

Mac 数据目录为用户 Application Support 下的 `PDFnoNative`；移动端使用自己的 app 容器。`library-v1.json` 保存书目、进度和笔记，`Originals/<sha256>.pdf` 保存导入副本。EPUB 使用独立 `epub-v1.json` 与 `Originals/<sha256>.epub`；学习数据另存 `learning-v1.json`，AI 结果／来源与用户正文分字段，不保存密钥，不改 PDF/EPUB schema；每次有效更新先备份上一版 manifest，再原子替换。单窗口 repository actor 管理本地写入，尚未承诺跨进程写入、SQLite 事务、云冲突或崩溃后自动修复。手工恢复前退出应用并复制 manifest、backup 和 Originals；校验备份后再恢复。旧 Electron notes/localStorage 不会被读取或重写；需要单独的 legacy-demo 只读导入器，旧文本 fingerprint 不能转成虚构 PDF 坐标。

用户已授权旧 Electron/React/Node/CLI 骨架退役。移出文件、未跟踪元数据和运行缓存有仓库外备份，完整 Git 历史保留；[迁移与恢复记录](docs/NATIVE-MIGRATION.md) 给出保留/移出理由及回滚方式。历史审计文档保留并标明时态。原 `PDFnoBridge.xcodeproj` 只是 CLI 辅助工程，不是当前原生阅读器主应用。

## 许可证与来源

[LICENSE](LICENSE)、[SOURCE-NOTICES](SOURCE-NOTICES.md)、[THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md) 记录 AGPL、原创样例和系统框架边界。没有复制 UPDF 私有代码/图片/字体，Kookit 固定源码、实际 npm lock、许可证及对应构建源保存在 `engine-build/`；未引入 Koodo 主应用、闭源 extra、私有 Bookno 代码、OpenCC 字典或未知 minified/WASM 资源。UPDF 仅提供已脱敏的信息组织参考，PDFno 使用自己的名称与系统视觉元素。旧 npm 依赖清单作为 [历史记录](docs/historical/dependency-inventory.json) 留存，不是当前运行依赖。
