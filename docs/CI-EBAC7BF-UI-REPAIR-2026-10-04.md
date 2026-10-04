# ebac7bf 全量 CI 结果与第二次 UI 修复

核验日期：2026-10-04。此片只处理封面、已保存笔记正文编辑、本地书库/笔记搜索的整合验收。起点 `ebac7bfbba4009b705c2e4e66e52a98a2ed76d5e`，目标仍为 `feature/integration-cover-notes-search-20261004`；最终提交与 CI 原始证据另外记录确切 SHA。未混入下一批文本格式或 EPUB 章节翻译，未合 main 或发行。

## 已执行的 ebac7bf 结果

| 检查 | 实际结果 |
| --- | --- |
| [Native checks 37179060438](https://github.com/lyx5710317/pdfno/actions/runs/37179060438) | failure；仅 Mac UI 步骤 exit 65 |
| [CBZ comic checks 37179060388](https://github.com/lyx5710317/pdfno/actions/runs/37179060388) | success |
| 全量 Swift | 168/168，9.252 秒 |
| Node、三个引擎/样本/工程再现、来源守卫、账本守卫 | 全部通过；Node 14/14、270 source files、账本 8/8 |
| Mac / iPhone+iPad generic Simulator build | 全部通过 |
| Mac UI | 全部 22 个方法实际执行，16 通过、6 失败、0 跳过；954.716 秒 |

XCTest 的 16 failure events（含 1 unexpected）来自上述 6 个失败方法；不把事件数当作失败用例数。原基线 13 方法全部通过。原始日志、run/step 状态与逐例结果保存于 `pdfno-ci-ebac7bf-303fzbqi` 系统临时证据目录。

第一修复已经确认搜索 Unicode 分组标题查询、封面列表/重开/恢复，以及 PDF 草稿恢复/保存成功。网格子封面查询仍失败；正文控件在取消后重新编辑、EPUB 首次输入、PDF 清空时仍未可靠更新实际值；传入 TMPDIR 后 runner 和 app 的真实根仍不同，故障用例在读取 manifest 时 Cocoa 260，尚未触发预期写入故障。

## 本片修改与真实断言

- 用 `NSViewRepresentable` 包装纯文本 `NSTextView`，通过 `textDidChange` 同步正文草稿。创建时初始化、首次挂到窗口才请求焦点；相同 UTF-8 内容的 SwiftUI 更新保留文本和光标；禁用自动标点/替换，禁用保存期间输入。取消后重新编辑创建新的控件；用户正文、原文、AI 结果与来源的存储边界保留。
- 网格使用封面行容器，保留图片辅助功能子元素，以点击、默认辅助功能动作及 Return/Space 打开同一本书。列表容器保留第一修复中已验证的 `contain`。封面、落盘、恢复、重开和原件字节断言全部保留，并在原 22 方法内增加从 DOCX 返回网格 PDF 的实际打开检查。
- 移除不成功的 runner TMPDIR 分支。Debug/macOS 的故障 fixture 只在明确 marker、合法 UUID、确切 `/tmp/PDFno-UITests-<UUID>` 且根非符号链接时启用。应用在自己的测试目录把普通 backup 文件换成空目录，真实仓库原子写入因此失败；第二次手动保存移除其自己创建的空目录并真实重试。runner 只读 manifest，不跨沙盒删除应用文件；不改 entitlement、签名或系统权限。
- 新增实际原生输入/删除、草稿 journal、真实仓库写入失败/显式重试共 3 个测试。覆盖精确 Unicode UTF-8、取消后重新打开、清空、失败后 manifest 不变、草稿保留、重试后的备份及原件字节一致。本地验证发现并修复了目录 URL 末尾斜杠比较和 URL 文件类型缓存问题。
- UI 输入即时等待控件真实值与“正文未保存”，清空也明确等待空字符串；保存、来源、旧词消失/新词出现、草稿不参与搜索等既有断言均保留。原 13 方法及从首个 DOCX 方法起的全部辅助方法逐字不变，22 方法名单不变，无跳过或降低断言。

## 最终文件状态的本地验证

| 检查 | 实际结果 |
| --- | --- |
| 全量 Swift | 171/171，24 suites，2.495 秒；`/tmp/pdfno-ui-third-full-swift.log` |
| Mac build-for-testing | TEST BUILD SUCCEEDED；全部 22 UI 方法编译；`/tmp/pdfno-ui-third-Mac-build.log` |
| iPhone/iPad generic Simulator build | BUILD SUCCEEDED；`/tmp/pdfno-ui-third-Mobile-build.log` |
| 来源/样本、账本、差异与原测试保留 | 通过；源文件最终数量见交付证据 |
| 本地 UI 执行 | 0；完整 UI 仅在隔离 CI 主机执行 |

本片没有修改服务层持久化、schema、引擎、锁文件、fixture、工作流或 Xcode 工程。原 ebac7bf 的 Node/引擎再现结果按其原 SHA 保留；修复后的全量 CI 会重新执行所有阶段。本地编译和离屏测试不等于 22 UI 已通过；交付以最终确切 SHA 的 Native + CBZ 工作流终态和逐例日志为准。

## 官方依据

2026-10-04 读取 Apple 官方 Markdown，并保存本地来源副本：

- [NSTextDelegate.textDidChange(_:)](https://developer.apple.com/documentation/appkit/nstextdelegate/textdidchange(_:))：原生正文发生字符或格式变化时通知 delegate；本控件以此更新纯文本草稿。
- [NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable)：在 SwiftUI 中创建、更新 AppKit view，并用 Coordinator 转发 delegate 事件。
- [onKeyPress(_:phases:action:)](https://developer.apple.com/documentation/swiftui/view/onkeypress(_:phases:action:))：拥有焦点时处理硬件键盘事件；支持当前 macOS 14 / iOS 17 构建目标。

独立安全专项仍 **UNVERIFIED**，未重试受阻审查，未把功能测试当作安全专项。没有启动、终止、检查或操纵用户运行的 PDFno；无真实 key/API 请求，无 Bookno/iCloud 操作。
