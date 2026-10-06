# 完整Mac UI失败分组诊断 · 2026-10-06

后续两个代表已2 FAIL→2 PASS，最新剩余13方法单批正式9 PASS/4 FAIL/0 SKIP，唯一方法各一次，未重跑失败。分组最新输入4 PASS、凭据7 PASS/4 FAIL，面板7/ebook4/DOCX1未复验。新静态读取确认DOCX错误AX文本含预期词，原等待失败待定。逐项结果与日志见[分组报告](MAC-UI-INPUT-GROUPS-2026-10-06.md)，前次见[输入实验](MAC-UI-INPUT-PROBE-2026-10-06.md)。以下保留初诊阶段原记录，不作为当前验收状态。

保留d2c52a7与95f6e4完整60项原证据：33 PASS、27 FAIL、0 SKIP。此次只读现有结果、对照基线，并新增离线诊断单元测试；没有再次运行GUI或60项。**尚无已确认的真实产品回归，也没有排除产品回归。**

| 分组 | 方法数 | 实际发现 / 最早失败 | 同根因候选 |
| --- | --- | --- | --- |
| 原搜索与设置输入 | 4 | ReadingIntegration:131 actual regional棚顶 ≠ Original pending label；搜索在NextBatch:14或ReadingIntegration:26等待search-result。输入helpers仍使用typeText；原保护测试及临时设置布局没有改。 | 输入事件/组合态候选；设置的实际输入不一致已确认，其他方法的唯一根因未确认。 |
| 严格离线fixture凭据拒绝 | 11 | BYOK Native:192 missing byok-result；DeepSeek:1915 missing ai-result；日语/整章/整页在Native:2088等待状态。已读取BYOK/日语PDF/整页取消/整章取消的自有AX文本：全部显示当前会话密钥未配置或已清除；BYOK预算1/3。真实OfflineSelectionUITestTransport严格校验Bearer与payload、无network fallback。 | 4个代表方法实际返回credentials错误已确认。虚构凭据输入变形为最强候选；实际输入字节未捕获，11项不能全部判为同根因。 |
| 保存/打开面板服务崩溃 | 7 | 7个正式Test Case都有com.apple.appkit.xpc.openAndSavePanelService crashed in main。后续首断言分别Native:1580/2088/832/1554/1334/1071。CBZ及其他多种导入用例通过，表明并非所有文件面板都失败。 | 正式结果的服务崩溃是已确认现象；OS/工具链、XCTest XPC注入与产品面板流程仍是候选，不能据此统一归因。 |
| 电子书保存/进度组合谓词 | 4 | 4项只在EbookFormat:45组合谓词超时；savedAnchor/savedProgress非nil断言未失败。正文typeText后保存点击有未处理Dialog，暂无对应最终完整AX文本。采用paste的Native MOBI正文编辑/保存/重开方法通过；EbookLibraryModel与6a67逐字节相同。 | 保存正文组合态是候选；格式/正文/进度三项中究竟哪一项不匹配尚未确认，不能直接称持久化产品回归。 |
| DOCX损坏归档错误状态 | 1 | Native:1278调用等待归档损坏，实际失败记录在通用waitForText:2088、log5980。输入/输出面板路径粘贴及OKButton点击已执行；尚未到恢复转换/HTML断言。DocumentConversionService与6a67相同，先前完整Swift的ConversionTests已通过。 | 损坏归档后未观测到预期错误；尚不能区分面板未提交、任务状态或产品错误文案。该方法没有记录上述服务崩溃。 |

## 隔离harness与6a67对照

原56方法正文保留；App启动后的有效UUID没有被改成公共fallback，所有scenario保留。完整60 App副本只增session fallback与强制offline，未改UI主体；bundle/App/runner/xctestrun正确一致。所有远端原用例本身已显式offline，非远端用例不会因此自动配置服务或发送。核心默认AIConfig仍unconfigured，未发现UI/services写UserDefaults。复制App的Info与常规构建对照仅bundle不同，NSPrincipalClass/ATS/aqua/LSUIElement所检查值相同。完整60副本没有强制aqua代码或Info，不能把先前手动体验harness的局部外观设置套用于本产物。

整页、整章、日语模型、EbookLibraryModel、TemporarySettingsLayout、DocumentConversionService、日语provider与Mac正式入口共8文件对照6a67逐字节相同；段落改造在legacy翻译时保留原序列化/解码路径。原CI工作流选择macos-15，本次本地是macOS27.0.1/Xcode27；未独立拉取旧CI精确工具链。生成的XCTest/XPC环境变量保留，暂无证据证明是崩溃根因，不关闭诊断或保护。

## 实际离线对照

新增OfflineUITestTransportTests直接使用真实严格OfflineSelectionUITestTransport与当前DeepSeek/BYOK/日语模型。3方法×正确/错误虚构凭据两分支：正确凭据均有结果，错误凭据均复现credentials错误和budget1，均不自动保存；3测试方法、6参数分支全部PASS，退出0。测试采用合法原创快照及源有效闭包，隔离验证凭据/请求响应契约，不替代真实reader session/布局验收。首次编译用了不存在的setSessionCredential接口，修正为现有saveConfig后通过；首轮失败日志保留。sourceguard687 PASS。生产代码、旧56、新4UI均未改。

BYOK、日语PDF、整页取消、整章取消四个实际用例的具名App UI hierarchy是UTF-8辅助功能文本，包含credentials错误；BYOK已用1/3。仅从各自已核验fixture方法的现有xcresult导出这些文本，没有读取UI Snapshot图片、系统诊断、私有库或真实密钥，未输出凭据内容或剪贴板数据；原keepNever配置不能保证所有文本附件都不存在。普通Debug description只有查询链，不能用它推断实际状态。当前证据支持严格fixture拒绝虚构凭据，输入变形为最强候选；需要有界probe才能确认实际输入在哪一步改变。

## 最小下一步（尚未执行GUI）

- 原搜索与设置输入：先单一原创搜索probe比较原生typeText与已有安全paste路径，确认输入值、失焦提交后的搜索结果；两次独立UUID、最多各一次搜索，90秒/次。旧56方法不改，probe不能计为旧56通过。
- 严格离线fixture凭据拒绝：优先仅新增一个BYOK诊断probe：两独立UUID分别typeText/paste相同虚构凭据，各手动同意且最多发送一次；专用DEBUG副本只记录authMatchesFixture/payloadValid/任务/计数布尔metadata，不记录凭据或剪贴板字节。保持精确Authorization guard、来源核验、3/6预算与零自动重试；180秒/次。若auth一致但仍失败则停止，保全产品错误。此方案尚未实现或启动GUI。
- 保存/打开面板服务崩溃：先从现有同方法activities定位崩溃与面板动作的先后；之后仅一个原创open/save/cancel probe做6a67与当前候选同专用bundle隔离A/B，各一次、各120秒。保持默认XCTest诊断/全部保护，不改DYLD或系统权限；首次服务崩溃即停止，不循环。baseline对照须新忽略副本，不改主树/现有产物。
- 电子书保存/进度组合谓词：仅原创MOBI probe一次：严格输入正文等值后保存、点第二章；只读该probe自己UUID下ebook-kookit-v1.json，把format/body/progressQuote三个谓词分别记录。180秒一次；禁止枚举/tmp其他库，不改旧组合断言。若显示真实progress错误，再做针对reader/repository的离线修复。
- DOCX损坏归档错误状态：先用同一原创损坏DOCX直接驱动离线转换模型记录phase/error/无输出；只有此路径通过且文件面板问题可控后，才单一GUI probe对比输出选择是否完成与模型阶段。90秒一次，停止于首异常，不重跑整个方法或60项。

优先顺序：凭据probe→原搜索/设置与MOBI正文；文件面板先确认现有活动时序，再做baseline/候选同隔离A/B；DOCX先离线直接模型。每个probe有独立UUID、专用bundle、明确次数与超时、共享heavy lock；新probe结果不冒充原56复测。出现权限弹窗或隔离失效则暂停，不改系统设置、不放宽来源/预算/密钥校验，不自动重试。

## 证据与边界

JSON总收据为evidence/diagnose-failure-groups.json，含27方法首失败逐项归组；完整逐方法矩阵仍见[MAC-UI-FULL60-2026-10-06.md](MAC-UI-FULL60-2026-10-06.md)。现有活动文本导出记录为diagnose-*-activities/export-command.json与fixture-hierarchy.data，源对照见diagnose-baseline-source-equality.json，输入干扰见diagnose-input-interruptions.json，新测试命令/日志见diagnose-offline-transport-swift{,-corrected}-command.json/.log与diagnose-source-guard-command.json/.log。

没有修改或重新收尾旧xcresult/完整60日志；没有读取真实API/key或Library，没有npm安装、公开push/CI/merge或全仓审计。安全专项仍UNVERIFIED/platform-blocked，不重试。完整UI验收仍FAILED，27方法未从失败改为通过。
