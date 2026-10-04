# Bookno 离线预览验证与整合交接

本文保留 `89aca0ba68201e2e38acd72f25b982977e033832` 首片的历史记录。后续在绿色 `f3ed484` 上的本地来源适配、Mac 预览入口及实际验证，见 [BOOKNO-INTEGRATION-2026-10-04.md](BOOKNO-INTEGRATION-2026-10-04.md)；本文件的“未来 UI”“未移动编译”等描述仅指首片。

日期：2026-10-04。候选分支：`feature/bookno-sync`。起点：`8cf6ab8e93e057aa73a6607a17e6e2fe42269315`；没有使用未验证的文本/章节候选作为基线。未 push、merge、改 main/release 或共享 Library，也未修改 Bookno 仓库、用户 app、私有书籍/数据库、真实 key/API/账号。

## 实际验证

环境：arm64 Mac，macOS 27.0、Mac SDK 27.0、Apple Swift 6.4（`swiftlang-6.4.0.34.1`）。SwiftPM scratch/cache/config/security/Clang module cache 均指向独立临时目录，测试 fixture 原创且纯离线。

| 检查 | 结果 |
|---|---|
| 新增协议测试 | **25 passed**：disabled、稳定 ID、原样 Unicode、PDF/EPUB locator、AI/用户正文分离、来源不匹配、哈希/严格 schema、重试/去重/epoch、冲突/整批事务、资产/封面保护、tombstone、乱序/迟到/伪造回执 |
| 相关 native 离线回归 | **92 tests in 9 suites passed**，含上述 25 项；覆盖 Contracts、Repository、EPUB、PDF quote、NoteEditing、Cover、LibrarySearch、BoundedFileReader |
| 原创黄金批次 | Python generator 的语义哈希被 Swift 严格 decode 独立核对，再由 mock 接收；固定 UUID、原创引文/备注、synthetic source bytes，没有用户内容 |
| source/provenance guard | `python3 scripts/check-native-source.py` 通过，仍保留固定的原有二进制 fixture 清单、Domain UI boundary 与依赖门禁 |
| 补丁空白检查 | `git diff --check` 通过 |
| Bookno 只读证据 | ADR 列出的文件相对 Bookno `682b9642b7211a0f8d43613a5ed8234dc3c7eb0b` 无差异；跟踪源文件搜索未找到 PDFno 入站 API 实现 |

首次受限 `swift test --filter bookno` 在 SwiftPM manifest 沙箱启动阶段遇到 `sandbox-exec: sandbox_apply: Operation not permitted`，未进入编译。随后执行环境允许的同一正常 SwiftPM 沙箱命令通过；没有使用 `--disable-sandbox`，没有改权限/系统设置。既有安全专项的 **UNVERIFIED 平台阻断保留，未重试或绕过其动作**。首次完整编译仅观察到既有 `PDFPageTranslationTests.swift` 的 sendable closure 捕获后修改变量 warning；本片未修改该文件。

## 可复现命令

在候选 worktree 中使用自己的独立临时目录（以下变量只服务本任务）：

```sh
BOOKNO_TEST_TEMP=$(mktemp -d /tmp/pdfno-bookno-check.XXXXXX)
CLANG_MODULE_CACHE_PATH="$BOOKNO_TEST_TEMP/modules" \
SWIFTPM_MODULECACHE_OVERRIDE="$BOOKNO_TEST_TEMP/modules" \
swift test --package-path apple/Packages/PDFnoKit \
  --scratch-path "$BOOKNO_TEST_TEMP/build" \
  --cache-path "$BOOKNO_TEST_TEMP/cache" \
  --config-path "$BOOKNO_TEST_TEMP/config" \
  --security-path "$BOOKNO_TEST_TEMP/security" --manifest-cache local \
  --filter 'bookno|ContractsTests|RepositoryTests|EPUBTests|PDFQuoteConsistencyTests|NoteEditingTests|CoverTests|LibrarySearchTests|BoundedFileReaderTests'
python3 scripts/check-native-source.py
git diff --check
```

原创 metadata fixture 路径为 `apple/Packages/PDFnoKit/Tests/PDFnoKitTests/Fixtures/Bookno/proposed-preview-v1.json`，由 `python3 scripts/generate-bookno-preview-fixture.py` 确定性生成。source SHA-256 对应声明的 synthetic bytes，不冒充真实 PDF；来源回跳测试验证 typed locator/Unicode 保全及 native reader 现有回归，**没有通过 Bookno 启动真实回跳**。

开发日志在执行者的独立临时目录，仅为本次本地运行证据；不提交构建物/日志，不把临时位置作为 API 或用户交付路径。

## 整合冲突清单

截至本次检查，本片全部新增路径与以下本地分支相对 `8cf6ab8` 的改动路径 **零重叠**：audit-fixes、chapter-translation、comics、conversion、covers、docx、ebook-formats、integration-cover-notes-search-20261004、integration-text-chapter-20261004、integration-ui-fixes-113e055-20261004、note-editing、note-search、page-translation、text-formats（均为 `feature/` 前缀）。这是只读路径比较，没有执行合并，不能代替合并后的编译/测试。

| 整合风险 | 处理要求 |
|---|---|
| 后续格式新增 `LocalBookFormat`/`CoverFormat` case | 补齐 `BooknoExportAdapter.book` 的 format switch 与稳定 ID namespace；不能把未知格式标成 PDF/EPUB。CBZ/DOCX 当前仅 metadata/封面声明 |
| 新的 `NoteBodySnapshot`/`AISelectionAnchor` case | 新增明确 DTO/offset unit/capability 与对应 fixture；不能丢弃来源/AI附件或复用旧 extractor version |
| 新的 EPUB code point locator 或提取器 | 保留旧 UTF-16 locator 与原始拼写；提供资源内映射和新版本，不能改标旧数字 |
| metadata/cover sidecar 与本地编辑机制 | 仅调用 adapter 读取用户选中的已保存 snapshot；native revision 与 exchange revision 分离，不改既有 manifest/schema |
| 未来 UI 入口 | 默认关闭；展示本地预览/mock 回执，不把 feature availability 或“已同步”提前打开 |
| Bookno production 接收/恢复 | 先批准完整来源 payload、字段基线、资产限制、事务、receipt、持久 outbox/epoch 历史；旧 importer 的 NFC/模糊去重不能代替稳定身份 |

## 未执行与剩余边界

- 未运行 Mac UI、WebKit/UI suite、移动编译或真实设备；不重启或替换用户正在使用的 app。所选 package 测试已编译共享 Domain/Services/Readers/UI 模块，但不是新的 app/UI 验收。
- 未运行既有安全专项，未改变 UNVERIFIED 状态、平台阻断或发布门禁。
- 未配置网络、监听端点、OAuth/key/CloudKit，未实际导入 Bookno、共享数据库或真实同步；缺真实端点仍待 Bookno 侧接入。
- 预览 ledger、mock 接收端及确认 tracker 均为内存值；没有 crash-safe 发布历史、多设备修订协调、生产 outbox、冲突解决 UI 或传输认证。丢回执测试通过的是同批次重放语义，不代表完整跨进程灾难恢复已实现。
- 生产 JSON Schema/canonicalization、highlights 样式、AI 来源 metadata、edition 历史、三端传输与删除传播需双方确认；用户决策问题详见 [协议 ADR](ADR-BOOKNO-OFFLINE-PREVIEW.md)。

本片只交付可以本地审阅和测试的协议候选与离线适配骨架；Bookno 同步未上线。
