# PDFno

原生 Mac、iPhone、iPad 阅读器，使用 **SwiftUI + AppKit/UIKit + PDFKit**，源码保持 **AGPL-3.0-or-later**。这是首个可运行的本地 PDF 开发切片，尚未发行。

现在可以导入 PDF、按文件 SHA-256 去重并保存原书副本；用 PDFKit 阅读、选字、翻页、目录和文本搜索；保存选区高亮与笔记、回到来源、恢复阅读进度。高亮只投影到内存中的 PDFDocument，原书副本不被改写。损坏或来自新版本的本地数据会停止保存，并保留原文件。书库目前使用系统书籍图标，封面生成、缩略图与多文档工作区仍待实现。

**EPUB、漫画、其他格式、AI/BYOK、问答、双语翻译、日语假名、英日语法、Bookno API、iCloud、OCR、格式转换和 Apple Pencil 尚未接入。** EPUB 适配边界已保留，引擎没有选定。完整功能目标和三端规划见 [v0.3 主规格](docs/PDFno_AI_Development_Spec_v0.3_Native.md)、[实施状态](docs/NATIVE-TASKS.md) 和 [引擎审计](docs/EPUB-ENGINE-AUDIT.md)。

## 在 Xcode 中运行

打开 `apple/PDFno.xcworkspace`。选择 **PDFnoMac** 并运行于本机；选择 **PDFnoMobile** 并运行于 iPhone 或 iPad Simulator。两者是独立 application targets，移动 target 同时支持 iPhone/iPad；Mac 使用 AppKit，未采用 Catalyst。共享 `PDFnoKit` 包含 Domain、Services、Readers、UI 四个 targets，没有外部 Swift 包依赖。

临时开发基线为 **macOS 14 / iOS 17 / iPadOS 17，Swift 6，Xcode 16.4+**。这些版本适合当前 SwiftUI API，并为候选 CKSyncEngine 留出兼容范围；CloudKit 尚未启用。最终发行设备范围可以调整。工程只使用本机 ad hoc 签名 `-`，未设置开发者 team、证书、账号、entitlements 或云容器；Simulator 不需要开发者账号。真机安装和发行需要另行配置与验证。

打开应用后，点击「打开示例 PDF」即可试读自制两页样例，或点击「导入 PDF」使用系统文件选择器。未解锁的加密 PDF 会明确拒绝；当前文件上限为 200 MiB。PDF 没有文字层时不能选字和搜索。选中文字后打开「高亮与笔记」，可以保存引文和自己的笔记。

## 构建与验证

```sh
swift test --package-path apple/Packages/PDFnoKit --scratch-path .build/PDFnoKit
python3 scripts/check-native-source.py
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' -derivedDataPath .build/Mac CODE_SIGNING_ALLOWED=NO build
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath .build/Mobile CODE_SIGNING_ALLOWED=NO build
```

在 Xcode 的 Test 菜单，或对所选 scheme 执行 `xcodebuild test`，运行真实 UI smoke。测试使用独立临时书库和自制样例，不读用户书库。Mac XCTest runner 需要本机 ad hoc 签名；使用 `CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-`。Simulator destination 选择本机已安装的设备，不复制其他机器的 UUID。实际设备、工具链、命令和未测范围记录在 [验证报告](docs/VALIDATION.md)。GitHub Actions 检查公开源文件、Swift 测试、Mac 构建/界面流程与轻量移动编译。当前顺序已调整为先把 Mac 做好，再据共享内容完善 iPhone/iPad；移动端功能完备不是这阶段门槛。

工程与样例可通过 `python3 scripts/generate-apple-project.py` 确定性再生。它不下载依赖或配置账号；修改生成的 pbxproj/scheme 时须同步更新该脚本。

## 数据与迁移

Mac 数据目录为用户 Application Support 下的 `PDFnoNative`；移动端使用自己的 app 容器。`library-v1.json` 保存书目、进度和笔记，`Originals/<sha256>.pdf` 保存导入副本；每次有效更新先备份上一版 manifest，再原子替换。单窗口 repository actor 管理本地写入，尚未承诺跨进程写入、SQLite 事务、云冲突或崩溃后自动修复。手工恢复前退出应用并复制 manifest、backup 和 Originals；校验备份后再恢复。旧 Electron notes/localStorage 不会被读取或重写；需要单独的 legacy-demo 只读导入器，旧文本 fingerprint 不能转成虚构 PDF 坐标。

用户已授权旧 Electron/React/Node/CLI 骨架退役。移出文件、未跟踪元数据和运行缓存有仓库外备份，完整 Git 历史保留；[迁移与恢复记录](docs/NATIVE-MIGRATION.md) 给出保留/移出理由及回滚方式。历史审计文档保留并标明时态。原 `PDFnoBridge.xcodeproj` 只是 CLI 辅助工程，不是当前原生阅读器主应用。

## 许可证与来源

[LICENSE](LICENSE)、[SOURCE-NOTICES](SOURCE-NOTICES.md)、[THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md) 记录 AGPL、原创样例和系统框架边界。没有复制 UPDF 私有代码/图片/字体，未引入 Koodo/Kookit、私有 Bookno 代码、字典或 EPUB 引擎。UPDF 仅提供已脱敏的信息组织参考，PDFno 使用自己的名称与系统视觉元素。旧 npm 依赖清单作为 [历史记录](docs/historical/dependency-inventory.json) 留存，不是当前运行依赖。
