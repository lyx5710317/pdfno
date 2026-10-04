# 文本阅读与 EPUB 当前文档翻译：CI 修复候选

日期：2026-10-04。范围仅限 `feature/integration-text-chapter-20261004` 的两模块必要整合修复。用户已明确批准该分支普通推送及范围内修复、推送、完整重跑直到通过；本轮不合 main、不发行。此记录补充最初[本地整合交接](TEXT-CHAPTER-INTEGRATION-2026-10-04.md)，其中推送前的 NOT-RUN 状态是历史记录。

## 实际失败证据

提交 `36c46db6c410f623c7ab41510acd0b9e9428a8a4` 已普通推送。[Native 37184704395](https://github.com/lyx5710317/pdfno/actions/runs/37184704395) 完成但失败；[CBZ 37184704379](https://github.com/lyx5710317/pdfno/actions/runs/37184704379) 成功。Native 的资源再现、来源守卫、193 Swift、Mac 和移动端构建全部成功。

29 UI 全部实际执行，26 通过、3 失败、0 跳过、0 意外失败，UI 总时长 1411.396 秒。3 个失败方法产生 4 次断言失败，不能把断言次数当作失败方法数：

- `testMacAISelectionConsentMockNotesAndRestart`：找不到 `epub-ai` 按钮。
- `testMacDeepSeekSelectionOfflineTransportPDFEPUBAndRestart`：同一按钮不可访问。
- `testMacEPUBChapterCompleteScopeConsentBilingualManualSaveRestartAndSourceReturn`：完整预算文本等待断言不满足，随后同一 `epub-ai` 按钮不可访问。

完整失败日志、终态 JSON 和逐例结果保留于 `/var/folders/s6/g995lx310_d8lh2z5xp9dsrh0000gn/T/pdfno-ci-36c46db-20261004-zs_z0o4n`。两次监控连接 EOF 不是 CI 结论；真实结论来自 GitHub 终态和完整日志。

## 候选修复

1. 新增的“翻译当前文档”从共享工具栏移到 EPUB 阅读区域底栏，保留同一操作、辅助功能身份和 busy 禁用条件。原工具栏内容与已完成 22 UI 的 `8cf6ab8` 逐字一致，避免新增长文本入口挤占原选文 AI 等动作。
2. 完整计划预算使用 `Text(verbatim:)`，把已有计算结果作为直接字符串显示，避免整数本地化插值改变 `6144` 等技术值的字符表示。来源、分段、预算计算、确认、发送、取消和存储逻辑均未改。日志未输出失败时的实际文本，因此此处不把某个分组符断言为已观察事实；新 SHA 的完整 UI 才能确认修复。

全部 `NativeUITests.swift` 与 `36c46db` 字节一致：原 22 和新增 7 的方法、断言、超时均保留。没有跳过测试、删断言、换 fake 成功结果、扩大请求范围或追加新模块。

Apple 官方接口参考：[Text.init(verbatim:)](https://developer.apple.com/documentation/swiftui/text/init(verbatim:))、[LocalizedStringKey.StringInterpolation](https://developer.apple.com/documentation/swiftui/localizedstringkey/stringinterpolation)，核验日期 2026-10-04。官方网页入口可访问，自动读取 Markdown 被内容类型限制阻止；实际 API 编译由本机 Apple SDK 和两端构建验证。

## 新候选本地验证

| 检查 | 结果 |
| --- | --- |
| Swift 全量 | 193/193，29 suites，3.074 秒；`/tmp/pdfno-next-ci-fix-swift.log` |
| Mac build-for-testing | TEST BUILD SUCCEEDED；全部 29 UI 编译，未在本机执行 UI；`/tmp/pdfno-next-ci-fix-Mac-build.log` |
| iPhone/iPad generic Simulator build | BUILD SUCCEEDED；`/tmp/pdfno-next-ci-fix-Mobile-build.log` |
| 来源守卫 | 318 source files 通过（包含新增交接文档） |
| 需求账本 | 8/8 通过 |
| 差异 | 两个 UI 文件的布局/显示修复及本文；无生成资源、fixture、数据模型或引擎改动 |

新候选完整 Native + CBZ CI 仍待普通推送后的实际结果。最终 SHA、tree、远端状态、原 22/新增 7 逐例结果和日志哈希将单独保存，不能用本地编译或 `36c46db` 的 26 个通过用例代替新 SHA 的验收。

未启动或操作用户 PDFno，未使用用户图书、真实 key、Bookno/iCloud 或模型 API。独立安全专项仍为 UNVERIFIED / platform blocked，未重试或替代。Bookno `89aca0b` 是下一批离线协议候选，未合入此树；真实同步未上线。
