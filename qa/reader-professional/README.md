# A 专业工具布局的隔离 GUI 验收

此目录是本地 QA 工具，生产 App 入口、Xcode 工程和 Release 配置不使用这里的替换。`prepare.py` 和 `configure.py` 均不启动 GUI。

先用 `python3 qa/reader-professional/prepare.py --output <全新 QA 目录>` 创建快照。它复制当前工作树、保留原四份 UI 测试字节，再仅向隔离工程增加 `ProfessionalReaderUITests.swift` 的四项回归。专用 bundle 为 `org.pdfno.integration.professionala20261007.PDFnoMac`。所有真实 HTTP 发送和 Security Keychain 调用在快照中直接拒绝；已有自制 fixture 和离线测试传输仍走正式模型。

编译命令必须包在项目既有 `run-heavy-check.py --` 共享锁中：

```sh
xcodebuild -workspace <QA目录>/source/apple/PDFno.xcworkspace \
  -scheme PDFnoMac -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath <QA目录>/DerivedData -jobs 1 \
  ARCHS=arm64 ONLY_ACTIVE_ARCH=YES CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM= \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO CODE_SIGN_ENTITLEMENTS= build-for-testing
python3 qa/reader-professional/configure.py --output <QA目录>
```

配置器验证专用 App、runner、测试 bundle 的签名和 arm64 二进制，拒绝 App 带有调试或测试 entitlement，核对快照与生产输入及原四份 UI 测试 SHA。它生成 `RUN-PLAN.json` 和一次完整 64 方法的 xctestrun，零筛选、零跳过、零自动重试。

**收到明确的桌面独占交接之后**，才可以把 `RUN-PLAN.json` 中的完整命令放入既有共享锁执行。该命令会实际启动隔离 App，发送 XCTest 鼠标／键盘及打开原生文件面板。不要启动普通产品 bundle、旧隔离 App 或用 CUA `getApp` 自动选择 App。不要在其他桌面任务仍持有焦点时派发。

启动入口在 SwiftUI Scene 创建前强制检查 bundle、UUID 和范围，自制 Library 固定到 `/tmp/PDFno-UITests-{UUID}`；权限为 0700，进程／会话记录放在 Library 外的 `Registry`。已有目录只能由该入口自己的匹配会话记录恢复。每个原 GUI 方法仍自行生成 UUID，`preview` 则使用独立固定 UUID 并仅打开内置原创示例。

原 60 方法的完整结果须和新增四项分别核对 xcresult 方法树、实际日志及运行次数。四项新增方法覆盖真实 ⌘F 焦点、窄窗笔记草稿、AI 确认和手动保存、EPUB 规范来源与草稿、宽窗双面板恢复。显式截图只取自制 App 的 `app.windows.firstMatch`，写入 runner 自己的 `FileManager.default.temporaryDirectory` 下以固定 QA UUID 命名的 `PDFno-A-WindowShots-*` 专用目录，不捕获桌面。日志中的 `PDFNO_A_WINDOW_SHOT` JSON 提供准确图片路径；收集到本地 `Screenshots` 时须逐张核对原始 PNG 与 SHA，不改像素。工作树和任意 `/tmp` 路径并不保证 runner 可写。测试系统自动附件设为 `keepNever`。

未执行 GUI 时，不得将编译、隐藏 NSHostingView 布局测试、历史 60 项通过或原型截图称为当前 A 产品验收。
