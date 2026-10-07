# A 专业阅读器：书库外壳整合（2026-10-07）

独立分支 `feature/mac-reader-professional-a-20261007`。产品整合提交 `27e97b5`，最终产品修复 `9c902d1`，QA 驱动与原型窗口标记提交 `cfb1707`。此前 `7b7c556` / QA13 的 64 项验收与交付包冻结，本批次不能继承该结论。可运行交付已编译，完整 68 项 GUI 验收尚未完成。

## 已实现

- 阅读时默认移除外层“我的书库”栏，以“返回书库”与“继续阅读”切换显示。阅读视图持续保留，选择当前书籍会直接恢复当前会话。
- 书库使用 A 的蓝色操作色、统一字体与间距；宽窗分类侧栏、窄窗横向分类，提供列表／网格、书名与格式筛选、笔记搜索、导入、封面编辑。分类整个区域可点击，封面状态和行键盘操作可单独访问。
- 内置 PDF、EPUB、DOCX、电子书示例集中到“帮助与示例”，不再铺在主阅读界面。Bookno 离线预览、AI 工具、BYOK 设置、转换、恢复管理保留在“工具与设置”。
- 新增可选 `bundled-examples-v1.json` 来源记录，不修改原书籍／笔记 schema、不删除文件、不按标题迁移旧记录。导入仓库直接报告新建／复用；只有明确示例入口的新建书籍、完整身份与资源哈希吻合时才写来源。复用个人书籍及旧的来源不明记录保持个人分类。
- 来源记录纳入既有备份校验、回收站删除和还原，保留损坏／未来版本记录。
- PDFKit／WKWebView、AI 逐次确认、预算与来源校验继续使用现有实现。网络 AI 未用于本次检查。

## 已通过与阻塞

- Swift：582 项、75 个测试组通过；新增来源测试 5 项另有一次定向通过，覆盖过期窗口列表、相同内容个人书籍去重、新建身份、损坏记录、回收站和真实备份恢复。
- Node：既有 25 项通过，0 失败／跳过。
- Mac：arm64 与 x86_64 均编译成功；普通产品构建未启动。
- 源码检查：727 个文件通过。
- 四个既有 GUI 文件中的原断言行全部保留，新增导航驱动适应入口移动；另加 4 项书库／阅读切换测试，连同原 64 项共计划 68 项。
- QA02 首次诊断遇到 `Timed out while enabling automation mode.`，实际方法 0、应用启动 0。随后确认诊断 xctestrun 被错误放在 QA 根目录，使十五处 `__TESTROOT__` 相对路径指向不存在的目录；将相同文件放回 `Build/Products` 后，默认 `platform=macOS` destination 正常启动并实际执行 12 项：4 通过、8 失败，13 次应用启动身份全部匹配。
- 实际诊断：QA02 4 通过／8 失败，QA03 6／6，QA04 10／2。已据此修正书库容器、书籍行与封面子元素、恢复后的导航、窄窗分类点击区域。QA05 仅编译，未作为验收。
- 最终产品 QA06 的正式结果为 12 项、8 通过／4 失败／0 跳过：三项由 `XCTHTestOperationCoordinatorErrorDomain Code=5: Test crashed with signal kill.` 中断，runner 三次失去连接后由 XCTest 继续剩余方法；另有一项 ⌘F 搜索焦点失败。15 次实际应用启动的路径、源码身份、可执行文件和 debug dylib 哈希均匹配。未识别终止者或资源原因，不能归因为权限拒绝或产品异常。完整 68 项未派发。
- QA07 `cfb1707` 快照编译与签名／二进制核验通过，427 个生产 Apple 输入与 QA06 `9c902d1` 完全一致，变化仅在 QA 入口、测试驱动和说明。搜索驱动等待真实 PDF 页出现，只激活该自制 App，再发送 ⌘F，保留键盘焦点断言；专用窗口标有“设计原型 · 自制离线示例”。此驱动已编译，GUI 待稳定会话恢复后验证。完整 68 方法清单无筛选／跳过／自动重试。
- 系统权限、账户与安全设置未改变。自身窗口内容渲染仅作辅助视觉检查，实际 GUI 截图和回归结果另存。

## 本地运行与证据

本批次工作与证据根：仓库根下的 `.build/ReaderProfessionalA/2026-10-07/ShellIntegration`。

交付见 `Delivery`。当前 Mac 运行 `RUN-PREVIEW.command`：专用 bundle、固定原创示例、独立 0700 临时 Library，HTTP AI 与 Keychain 在快照中拒绝，无需正式签名或开发者证书。隔离工程为 `Delivery/IsolatedPreviewSource/apple/PDFno.xcworkspace`；普通 `ProductSource` 会使用默认数据目录，仅用于审查。跨机器运行须重新执行 `qa/reader-professional/prepare.py` 创建新快照。本次未自动打开预览。

`gallery.html` 使用实际自制 XCTest 窗口 PNG，保留逐图源码轮次与 SHA。部分参考图来自 QA04 `41c774b` 的已通过方法，QA06 保留两张常规浅色图。runner 中断丢失八张先前输出，缺失只记录，不补造；辅助自身窗口内容渲染没有冒充 GUI 验收。

关键证据：`Evidence/FINAL9C902D1-CODE-CHECK-COMMANDS.json`、`Evidence/QA06-GUI-EXECUTION-BLOCKER.json`、`Evidence/qa06-interrupted12-OUTCOME.json`、`Evidence/QA06-QA07-PRODUCTION-INPUT-IDENTITY.json`、各快照的 `PREPARATION.json`／`RUN-PLAN.json`。旧 `GUI-BLOCKER.json` 只保留早期失败，恢复说明另存。Library 官方 helper 在现有 Python 3.9.6 上于参数初始化报错，无附件 ID，未安装或改写运行时。

最小恢复条件：稳定的当前 macOS GUI/XCTest 会话，确保专用 runner 不被终止；使用保存的新快照先跑相关门槛，全部通过后执行完整 68 项。现有证据不足以指定需要改变哪项系统设置；没有盲重跑同一命令或操作账户／安全设置。

尚待验证：完整 68 项 GUI、搜索驱动修复、最新窄窗深色书库截图、VoiceOver、iOS、Intel GUI、最低系统版本、联网 AI 质量及正式签名／发布。未 push／merge／发布。
