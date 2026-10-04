# 全格式候选完整 CI — 2026-10-04

用户直接授权将 `c048c07d81828f21e6887b5f7543af86c7026eb1` 普通上传至 `lyx5710317/pdfno` 的 `feature/integration-all-formats-20261004`，继续完整验收、修正与通过后的联合合并。原先审批不认可云线程转交授权的三次拒绝记录保留；直接授权后普通 push 成功。main 保持 `71d54540c417915702506f67fef7d337605aa9e2`，用户 Xcode 元数据不变。

## 第一次确切 SHA 验收

- [漫画 CI 37205376497](https://github.com/lyx5710317/pdfno/actions/runs/37205376497)：成功。46 项 Swift（1.054s）、4 项 Node（0 fail/skip），96 项 selected codec 源/头/许可与6个真实原创建容器 fixture 核验通过。GitHub workflow 元数据仍显示原名称 CBZ comic checks；该候选实际执行的是已扩展的 Bounded comic archive checks，含 CBT/native-comic/cover 用例。
- [完整 Native CI 37205376532](https://github.com/lyx5710317/pdfno/actions/runs/37205376532)：**失败，不能作为完整验收**。资源复现、源/fixture守卫、需求ledger、未筛选完整 Swift **272项／21.351s**、Mac/iPhone+iPad Simulator app构建均通过。此前本地延期的窗口测试包含在该完整 Swift 命令内，没有添加 skip。
- UI 阶段在 **Xcode16.4** 编译 `NativeUITests.swift` 的新增 `original7zCopy` fixture helper 时，原第905行的复杂位运算表达式触发“compiler is unable to type-check this expression in reasonable time”。**实际 UI 尚未执行**；该失败不是应用交互断言失败。本地 Xcode27 双架构 UI 编译曾通过，因此旧本地编译结果不能替代 CI 工具链兼容验证。

## 本批修正与保持项

把7z varint首字节的同一计算拆为显式 UInt64 的 prefixMask/upperValue、UInt8 的 firstByte，再构造 Data。运算顺序、编码字节、CRC/容器构造、原 fixture 条目不变。只修改这一新增 helper 表达式；全部40个 UI 方法、断言、主流程和180/240秒单项限额保留，产品代码/decoder/引擎/源定位未变。main 原30 UI 全部内容以及严格 EPUB 选区校验/负例继续保留。

修正后本地标准 SwiftPM 沙箱、jobs=2 的 Mac build-for-testing 成功，arm64+x86_64 全部40 UI源码编译；没有运行用户应用或本地 UI。源码守卫与完整40方法清点通过。272项 CI Swift 成功属于原 `c048c07` 的结果；当前修正须普通推送后，按新确切 SHA **完整重跑 Native 和漫画 CI及全部40实际UI**，不能只重跑失败步骤或筛选三个漫画流程。

原始本地证据 [ALL-FORMATS-LOCAL-EVIDENCE.json](ALL-FORMATS-LOCAL-EVIDENCE.json) 的源码哈希和结果绑定初始 `c048c07`，保留历史，不冒称后续修正已获相同SHA验收。首轮失败/成功完整日志、修正编译日志及授权/审批记录保存在隔离证据目录 `/tmp/pdfno-all-formats-ci-c048c07-20261004-iznwz3ra`。后续交付回执绑定最终通过SHA、完整UI实际名称/计数/0fail/0skip/0missing/0duplicate与日志哈希。

日语仍由原 worker 独立修正验收，尚未接收其最终通过SHA，本批不改其分支。只有两批各自通过后才联合整合、完整联合验收，全部通过才普通合入 main 并核验 main CI和远端SHA。AGPL路线、有限CB7/STORE-only CBR、Bookno七协议/十种明确拒绝、真实API/密钥/私人书库隔离保持；安全专项仍 **UNVERIFIED**，不重试，mock不证明真实语言质量。
