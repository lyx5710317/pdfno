# Mac GitHub／官网首版：本地 Release 准备

此流程只生成本地无签名 QA 产物，不查询账户证书或 Keychain，不签 Developer ID，不公证、不上传、不启动 App。不能将 `UNSIGNED-QA` 包作为正式下载发布。

## 配置与可复现命令

Mac App 的 Release 使用 `-O`、双架构、关闭 testability／previews、Hardened Runtime `YES`、关闭 base entitlements 注入。`apple/Configs/PDFnoMacRelease.entitlements` 是空字典：零 runtime exceptions，未启用 App Sandbox、文件／网络／Keychain／iCloud 权限。默认关闭代码签名并清空 identity／team，后续正式签名必须由获授权的阶段明确覆盖；不会自动发现身份。

Debug、mobile 和 UI test target 的配置保持原值；Mac App 额外打包仓库原始 `LICENSE`、`SOURCE-NOTICES.md`、`THIRD_PARTY_NOTICES.md`。原有各阅读引擎与编解码器 notices 保持原内容。许可证文件完整打包不代表 V03 法务审计已闭环。

提交候选到本地独立分支，然后指定新的输出目录和已存在的共享重型检查锁。脚本持锁串行执行，不要再套同一锁的 wrapper，以免重复锁等待。

```sh
python3 scripts/test-mac-release-check.py
python3 scripts/generate-apple-project.py
git diff --exit-code -- apple/PDFno.xcodeproj apple/PDFno.xcworkspace apple/Packages/PDFnoKit/Sources/PDFnoUI/Resources/study-sample.pdf apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/study-sample.pdf
python3 scripts/build-mac-release.py \
  --output /tmp/pdfno-release-NEW-UNSIGNED-QA \
  --heavy-lock /path/to/existing/PDFnoNativeHeavyChecks.lock
```

生成 Release universal archive、构建日志／实际 settings、逐资源／逐包文件 SHA-256 检查、精确候选 `git archive` 源码包及明确命名的无签名 ZIP。输出目录不得已存在，源码必须 clean，构建期间修改源码会中止打包。构建不会下载远程 Swift 包依赖；仓库当前只有本地 package。复现指同版本源码、配置和验收过程可重复，不承诺不同 Xcode／机器的 Mach-O 或 ZIP 字节相同。

检查器是无签名准备验收，拒绝正式签名包，不能替代正式发布检查。arm64 链接器可能生成本地 ad hoc linker signature；它不是 Developer ID 签名，也不能由此证明 Hardened Runtime 实际生效。`ENABLE_HARDENED_RUNTIME=YES` 的配置证明与签名 `runtime` flag 的运行证明分开记录。

## 正式下载前仍须验收

1. 由用户指定开发者账户／团队的公开 Team ID、所用 Developer ID Application 公开身份名称、确认 bundle ID／版本／最低系统，以及有权限执行签名的环境。无需向聊天提供密码、私钥、证书导出、Keychain 内容或公证凭据。本阶段不请求、不读取这些秘密。
2. 后续独立授权后，以该正式身份和安全时间戳签 archive 内每个需签 code；核对完整包、Team、`runtime` flag、零 runtime exceptions、无 `get-task-allow`，验证内嵌 code。不得添加 allow-jit、unsigned-executable-memory、disable-library-validation 来掩盖未定位问题。
3. 公证 Accepted／log，staple App 后重新生成最终 ZIP，核对源码对应 SHA、notice 及完整哈希。最终 ZIP 的传输验证与 App staple 验证分别记录。
4. 在获授权的 QA 用户／VM 中，使用真实下载且保留 quarantine 的最终包做在线／离线启动与 Gatekeeper 验收；不得重置安全权限、关闭 Gatekeeper、删除 quarantine 或替换用户正式 App。签名／公证通过并不自动等于运行验收。
5. 使用自制 fixture 验证 PDF 与五类 WK 阅读器、选文／笔记／返回／重启、导出取消和备份恢复；假凭据只可由完全拦截的 QA transport 使用。当前 Production App 没有入口级硬隔离 guard，不可只靠环境变量就直接在真实用户环境中启动正式 bundle。

本地优化测试或隔离 QA 构建只能覆盖注明的范围；既有 Debug 572 Swift／25 Node／60 实际 UI 证据不替代 Release、Developer ID 或下载后验收。App Sandbox 暂后置，iOS／iCloud／Bookno／MCP 不属于此阶段。

依据：[Apple Hardened Runtime 配置](https://help.apple.com/xcode/mac/current/en.lproj/devf87a2ac8f.html)、[Apple notarization](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)、[Apple macOS code signing TN2206](https://developer.apple.com/library/archive/technotes/tn2206/_index.html)。Apple 要求按实际需要选运行时例外；这里保持空 entitlement 起点，正式运行兼容性仍待后续验证。
