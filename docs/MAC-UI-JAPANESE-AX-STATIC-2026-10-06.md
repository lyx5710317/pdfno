# 日语原句AX静态定位 · 2026-10-06

本阶段没有GUI/NSHostingView/窗口/AX会话，仅比较本仓库代码、读取此前3份已核验专用App的.ips及运行纯内存模型/投影检查。**已确认角色/标签解析重入伴随真实栈耗尽；尚未锁定具体AX节点闭环或造成它的生产modifier，因此没有猜测性生产修复。** 新增1个离线测试方法（2分支）及本报告；原700断言/60方法与AND保持。之前两个限定GUI probe仍均FAIL，原13项9/4/0及完整60项33/27/0未变。

## 已确认的调用链与基线对照

三份App日志的stackPointer及faultAddress均落在对应Stack Guard内，紧贴主线程可读写stack下边界；这比只凭EXC_BAD_ACCESS名称更直接地支持栈耗尽。旧Invalid/Ruby各113帧、新Ruby98帧，SwiftUI AccessibilityNode.accessibilityLabel非objc函数均重复5次。新Ruby是XCTAutomationSession attributesForElement → AXUIElementCopyMultipleAttributeValues → AppKit属性读取 → SwiftUI resolvedRole/labelExposedAs/labelsToResolve/accessibilityLabel重复调用，直接读取japanese-components-source.value时失联。新栈已无旧identifiers/title/KVC筛选链；精确identifier缓解不是根因修复。

重复框架函数和实际栈耗尽不能单独确认“同一个节点自引用”：.ips没有每次调用的AccessibilityNode/platformElement身份、父子关系或实际请求的AX属性名。这里把此前“标签递归”表述收窄为**已证实role/label调用链重入和栈耗尽，具体对象闭环未证实**，也不据此将全部责任归于系统。

以下6个关键文件与已验收6a67逐字节相同，SHA见japanese-ax-static-baseline-comparison.json：JapaneseSentenceComponentsView、JapaneseLearningWorkspace、JapaneseLearningSheet、PDFnoDesignSystem、JapaneseLearningModel、域JapaneseSentenceComponents。现有目录Japanese route及PDF/EPUB的Japanese sheet接线也保持；本批宿主diff仅目录解释描述与导航行命中区域，没有新增日语AX包装。静态相同不等于排除旧产品组合的运行时问题。

## 源码可追溯关系

1. AISelectionAnchor.quote在pdf/epub等case中返回对应anchor存储的String，AISourceSnapshot/review为值类型；没有查询NSAccessibility/XCUI、view.value/label/parent的回调。
2. JapaneseSentenceComponentsView先从固定quote产生非重叠projection runs，拼接AttributedString。只有有效role/componentID和索引才加内部candidate URL；随后Text(attributedSource).textSelection(enabled)，id固定为japanese-components-source，显式label仍为同一原文String，hint为固定说明。源码没有accessibilityValue override或label回读自身的闭包。SDK接口中的StringProtocol label入口不同于PlaceholderContentView builder，本节点没有使用后者。
3. VStack父节点、JapaneseLearningWorkspace Form/Section、JapaneseLearningSheet NavigationStack/toolbar/overlay没有显式children:combine/contain聚合；唯一children:ignore在旁边的色标Label，非原句祖先。SwiftUI内部默认聚合和native selectable Text桥接仍不能由源码静态排除。
4. 日本语组件源的原文、内部链接、七色文字标签、component按钮与下方解释保持原状；没有通过去掉可访问性、label、选择能力、来源值或对AX错误吞错来绕开崩溃。

这些关系支持把问题收窄到原句selectable Text及其SwiftUI/native AX桥接/父层聚合，而不能证明哪个modifier造成环。当前公开SDK接口不提供AccessibilityNode.resolvedRole/labelsToResolve等内部实现，未读取私有内存、内部数据库或其他App日志。

## 新增离线证据：invalid仍进入同一原句视图分支

JapaneseLearningModel.start会把validated result（包括status unavailable）发布到review；JapaneseLearningWorkspace只用if-let-review判断是否渲染JapaneseSentenceComponentsView。因此旧invalid检查translation/subject缺失，不表示原句组件Text不存在。

新增JapaneseUnavailableAXInputTests实际驱动模型/coordinator/validator及projection，使用内存provider返回与UI fixture同样的invalid bytes，分别选择“window”和含分解假名/emoji的日语原文，第二分支有作者ruby。两分支均确认：

- review非nil、status unavailable、错误状态已发布，源quote UTF-8及作者reading完全保留；
- components为空、translation=nil、projection只有无role/componentID的完整原句run，因此该原句没有candidate link；
- provider只调用一次，canSave=false，显式save也不能调用保存闭包，没有存储/真实API/key/Library依赖。

这说明内部链接、有效成分颜色或作者ruby不是两类失败共同必要条件；共同的原句AttributedString/selectable Text/显式label及父层关系仍存在。不能只将链接删除或隐藏unavailable原句称作修复。测试没有运行SwiftUI AX runtime，不证明AX循环消失。

实际过滤运行JapaneseLearningComponentTests与新套件：**10方法/2 suites PASS，exit0，0.065秒**；新增1方法2参数分支，既有9方法保留并覆盖重复词、嵌套层、Unicode/IVS/emoji、持久来源与取消迟到结果。没有运行全量或会创建窗口的layout tests。Swift包本次编译完成；没有重复Mac GUI/build-for-testing批次。

## 尚缺的最小证据与候选边界

缺口仅为该原句节点附近的运行时AX关系：每次重入是哪一个SwiftUI AccessibilityNode/native platformElement、实际属性是role/value/title/description中的哪一个（及SwiftUI的label代理关系），以及父/子/代理身份是否回指同一对象。现有栈只有符号，既不能区分同一节点自引用与不同节点循环，也不能把default Form聚合和selectable Text桥接的贡献拆开。已有静态字符串/投影检查不能补齐这个事实。

在获得这个小范围事实前，没有足够依据提交accessibilityValue/trait/grouping的试探性生产diff，也没有新GUI probe派发。本轮交付的是测试/报告diff及明确缺口；后续若定位具体边，再在保留精确原文AX值、原生选择/链接功能、色标/按钮和全部来源/预算保护的条件下做最小组件修复。不能把全13/60、保存面板组或identifier再改一轮当作定位步骤。

invalid stdout诊断修复继续保存在已执行第二probe的忽略副本及ax-probes-native-insert.swift，SHA仍受保护；没有扩大runner文件权限或重试第一probe。npm、安装、发布、系统权限和全仓审计均未执行。main和未跟踪metadata保留，19截图/原full60产物不变，Library无有效library_file_id。

## 本地证据

主仓库 .build/MacUIExperience/2026-10-06/evidence：

- japanese-ax-static-baseline-comparison.json：6关键文件与6a67的SHA/逐字节对照。
- japanese-ax-static-stack-pointer-evidence.json：仅旧Invalid/Ruby及新Ruby具名App的stack guard、SP、fault、重复调用与身份缺口。
- japanese-ax-static-unit-command.json/.log：过滤10方法/2 suites实际exit0与日志SHA。
- japanese-ax-static-outcome.json、PARENT-STATUS-JAPANESE-AX-STATIC.json、FINAL-RECEIPT.json：本阶段最终提交、测试边界和未解决项。

此前真实GUI结果见[两项限定probe报告](MAC-UI-AX-PROBES-2026-10-06.md)，其失败不因本阶段离线测试通过而改变。
