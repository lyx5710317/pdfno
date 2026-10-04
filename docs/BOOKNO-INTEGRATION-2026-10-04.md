# Bookno 默认关闭离线预览：本地整合候选

本文保留最初本地候选的验证与未推送状态。用户后续允许开发分支完整CI、成功后合入main；实际首轮结果、必要修复和精确SHA验收边界见 [BOOKNO-CI-2026-10-04.md](BOOKNO-CI-2026-10-04.md)。

日期：2026-10-04。worktree：`/tmp/pdfno-integration-bookno-f3ed484-20261004`；分支：`feature/integration-bookno-offline-20261004`。绿色基线 `f3ed484fee815effed2d955f8eb21bcd66d8546e`，cherry-pick 来源 `89aca0ba68201e2e38acd72f25b982977e033832`，本地落点 `140435374328fab204612d17d20f2723e4672c58`。其后仅做本次来源适配、预览 UI、测试与文档修订；最终 SHA/tree 在本地交付 receipt 中绑定。不 push、合 main、改共享 Library、release，不改 Bookno 源码/真实库、用户 app、账号、真实凭据或运行时权限。不混入独立 `feature/ebook-formats` 候选；其验证许可单独处理。

基线实际 [Native 37186538104](https://github.com/lyx5710317/pdfno/actions/runs/37186538104) 与 [CBZ 37186538095](https://github.com/lyx5710317/pdfno/actions/runs/37186538095) 均成功，29/29 Mac UI 全执行、0失败/跳过。那是 `f3ed484` 的证据，本文件下面的 30 用例编译不能替代新 SHA 的实际 UI/CI。

## 用户可测试入口

1. 在获准的独立 Mac 测试环境构建/运行该分支的 `PDFnoMac`。侧栏底部“Bookno 离线预览”打开 sheet，显示“默认关闭 · Bookno 未连接”，无预选、无自动批次。此任务未启动/更新用户正在使用的 PDFno。
2. 打开启用本次预览，明确选择书籍；已保存笔记和既存封面均需另勾选。点“生成本机预览”，展示书目、原引文、已保存用户正文、AI 原结果各自字段与只读协议 JSON。不会把未保存草稿放入批次，也不读取原书文件。
3. “模拟提交后丢回执”只更新内存 mock，确认游标不进；“运行内存 mock／重放同一批次”验证同批次回执/去重。UI 明确显示不是实际同步、Bookno 未连接。scope 变化需要重新生成，批次是准备时的已保存快照。
4. “完成（清除本次模拟）”或关闭开关会清除 ledger、mock 数据、回执和游标；重新打开默认关闭。未实现跨退出发布历史/outbox，也没有自动导出或文件导出按钮。

Mac 入口实际已接入，**不限于领域模块**。iPhone/iPad 本轮仅共享模块编译，没有此预览入口。原 reader toolbar 保持基线内容，新增入口放书库侧栏；原29个 UI 方法、断言与超时完整保留，新增1个预览流程/独立 scroll helper，未跳过或删减原断言。

## 来源与编辑/封面映射

| 来源 | 当前映射与边界 |
|---|---|
| PDF | 书目、明确版本的已保存封面；普通高亮、选文学习和物理页学习保留 typed anchor/user-space 或 UTF-16 定位 |
| EPUB | 书目/既存封面、普通高亮、选文学习；新增整章学习完整保留 `.epubChapter` locator、translate promptVersion、不可变 AI 原结果与独立已保存用户正文 |
| TXT / Markdown / HTML | 独立 `BooknoFormat` 和稳定 ID namespace；已保存普通高亮/UTF-16 block anchor/extractionVersion；无伪 EPUB locator、无伪造封面 |
| CBZ / DOCX | 当前仅书目/既存封面，若勾笔记明确说明未适配；未静默标成 PDF/EPUB |
| 已保存编辑 | 生成时重新读 manifest/metadata；正文 byte-exact 保留空白/换行/组合假名/代理对/ZWJ，草稿排除；native edit/metadata/cover revision 是诊断，语义 hash 不含这些计数。PDF note 有 native revision；EPUB/学习/文本旧 schema 无此字段，保持 nil、不伪造计数或改 manifest |
| 封面 | 读取 `Covers/Assets` 的原 PNG 字节，独立内存资产按 hash 去重；不拿重采样 thumbnail 冒充原件。缺 record 提示，已有 record 缺/损坏资产拒绝整次，不修复/生成/重绑/缓存 |

生成前重新校验 parent book/edition/hash，选书范围、笔记与封面开关、资产引用和原字节均验证，再提交内存 ledger/tracker；失败没有半批次。关闭/范围变化时迟到读取丢弃。建议 UI 上限20本/1000对象/封面20MiB合计，协议 JSON4MiB及单资产10MiB/4096×4096上限仍为未发布提案，不是 Bookno 已有配额。七格式覆盖本候选已合入的阅读模块，不开放其余格式。

## 实际本地验证

环境：arm64 macOS27、Xcode27.0/27A266a、Swift6.4；部署目标仍 macOS14/iOS17，未修改签名账号、容器/entitlements。测试自建原创 fixture/UUID 临时根，不使用私有图书或真实 key。使用正常 SwiftPM sandbox，无 `--disable-sandbox`。

| 检查 | 结果与证据 |
|---|---|
| 聚焦 Bookno | **35 tests、1 suite，通过，0.106秒**：原25协议测试完整保留，新增10整合测试（文本测试内含3参数 case）；`/tmp/pdfno-bookno-integration-tests.log` |
| 全量 Swift | **228/228，30 suites，3.630秒**：193基线 +25协议 +10整合测试；含既有 PDFKit/离屏 WebKit/文本/整章/Word/漫画/编辑/搜索/封面回归；`/tmp/pdfno-bookno-full-swift.log` |
| 跨模块实际证据 | 真实原创 native manifest 保存/修改/restart 重新加载；草稿与原文件字节/全目录文件快照隔离；整章学习 AI 原结果/定位保全；800×1000原封面与重采样缓存不同 hash，mock 校验正确原字节；损坏、缺封面、旧 edition、越界范围拒绝；迟到关闭及失回执重放验证 |
| Mac build-for-testing | **TEST BUILD SUCCEEDED**，30条 Mac UI 编译，未执行；`/tmp/pdfno-bookno-Mac-build.log` |
| iPhone/iPad generic Simulator build | **BUILD SUCCEEDED**；`/tmp/pdfno-bookno-Mobile-build.log`。不证明设备/最低系统/UI验收 |
| 源码/原创样本守卫、需求账本 | **332 source files通过，账本8/8**；83个正式 ID/定义/基线状态保持原样，只重绑规格行号；原29 UI 文件只有新增、原25协议断言未变，逐字校验记录在独立receipt |
| Xcode项目与黄金 Bookno fixture 再现 | generator 后 **44份受保护资源/fixture/工程文件字节不变**；旧黄金批次经新 strict decode/hash/mock 再次通过 |
| Node及四资源 bundle | **14/14，0失败/跳过，430.775ms**；锁文件正常 `npm ci --ignore-scripts --no-audit --no-fund`（独立cache）后四个 bundle、原28二进制 fixture库存、项目与黄金批次再现，所有 tracked 输出字节不变。首跑缺独立 worktree 的 jszip/rangy，依赖补齐后完整重跑；`/tmp/pdfno-bookno-node-tests.log` |
| 新候选 UI实际运行、远端 CI | **NOT-RUN / 0**；原29的实际通过仅归属绿色基线，新候选含30条需另获准完整CI |

已有 `NativeUITests.swift` 两个未使用 `broken` 变量及 AppIntents metadata warning 保留，非本次引入。Swift 全量 warning 不作安全结论。没有 actual Bookno、iCloud、真实服务/费用、真实回跳、灾难恢复、多设备同步、VoiceOver/Apple Pencil 或真实设备验收。独立安全专项仍 **UNVERIFIED / platform blocked**，未重试、替代或绕过；本地功能成功不解除发布门禁。

## 决策、下一步与复核

[ADR 五项未决策](ADR-BOOKNO-OFFLINE-PREVIEW.md) 全部保留：单向 upsert/删除预览边界；真实 native bridge 或 loopback 与三端跨设备通道；Bookno 独立 importer/完整 source/字段基线/rich text保护；封面限制与事务粒度；持久 revision owner/epoch/outbox/多设备协调。完整生产 schema/canonicalization/capabilities 尚未冻结。`FeatureAvailability.bookno.available` 仍 false，实际 API 同步没有上线。

```sh
BOOKNO_TEST_TEMP=$(mktemp -d /tmp/pdfno-bookno-check.XXXXXX)
CLANG_MODULE_CACHE_PATH="$BOOKNO_TEST_TEMP/modules" SWIFTPM_MODULECACHE_OVERRIDE="$BOOKNO_TEST_TEMP/modules" \
swift test --package-path apple/Packages/PDFnoKit --scratch-path "$BOOKNO_TEST_TEMP/build" \
  --cache-path "$BOOKNO_TEST_TEMP/cache" --config-path "$BOOKNO_TEST_TEMP/config" \
  --security-path "$BOOKNO_TEST_TEMP/security" --manifest-cache local
python3 scripts/check-native-source.py
python3 -B scripts/test-requirement-ledger.py
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMac -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath /tmp/pdfno-bookno-Mac CODE_SIGNING_ALLOWED=NO build-for-testing
xcodebuild -workspace apple/PDFno.xcworkspace -scheme PDFnoMobile -configuration Debug \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath /tmp/pdfno-bookno-Mobile CODE_SIGNING_ALLOWED=NO build
```

最终候选只作本地 commit，SHA/tree、验证日志 hash、原29/新增1方法名单及 unchanged 校验保留到独立 receipt。下一步需用户明确允许该精确候选普通推送到 `lyx5710317/pdfno` 的新分支 `feature/integration-bookno-offline-20261004`，并完整运行 Native + CBZ CI，确认30条全部执行/通过及全部检查终态；main合并/发行/真实Bookno连接仍需各自授权。本轮不借先前文本/整章的推送许可上传此新功能。
