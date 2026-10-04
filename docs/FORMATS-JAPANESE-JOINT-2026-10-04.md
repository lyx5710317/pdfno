# 全格式与日语联合验收 — 2026-10-04

本批在独立联合分支整合两条已通过完整隔离 CI 的确切输入。既有全格式、日语文档是各自阶段的历史记录；本文件说明随后获授权的联合范围与合并门槛。AGPL 开源、三端长期目标、有限格式边界和未完成项保持。Bookno/iCloud 实际同步后置，仅保留既有离线预览。

| 输入 | 最终提交 | 独立 CI 证据 |
| --- | --- | --- |
| 全格式 | `7a82581e0fd5891b504935df5036f302d68e80ae` | [Native 37206365703](https://github.com/lyx5710317/pdfno/actions/runs/37206365703)：272 Swift、25 Node、双端构建、40/40 实际 Mac UI；[漫画 37206365698](https://github.com/lyx5710317/pdfno/actions/runs/37206365698)：46 Swift、4 Node |
| 日语 | `84d23e6245cf6fb4aa9dbdccbe79771ee8a1b2ae` | [Native 37210431806](https://github.com/lyx5710317/pdfno/actions/runs/37210431806)：279 Swift、14 Node、双端构建、33/33 实际 Mac UI；[漫画 37210431843](https://github.com/lyx5710317/pdfno/actions/runs/37210431843)：通过 |

这些成功只证明各自确切提交，不计入联合或 main 的执行结果。共同基线为 `71d54540c417915702506f67fef7d337605aa9e2`；合并保留两条最终历史及此前失败修复。普通推送已获用户明确授权；只有联合确切提交全部通过，才普通合入 main，并再次执行 main CI。不强推或发布。

## 整合变化与保留证明

唯一冲突在 `LibraryModel` 初始化：同时保留 ebook 变化通知、PDF/EPUB 选区/会话失效观察和日语取消回调。各格式导入/打开继续通过既有 learning 取消入口失效日语任务。保存时仍验证当前 PDF/EPUB、真实版次/哈希、配置与规范选区；非 PDF/EPUB 不能取得隐藏阅读器的 AI 来源。明确打开原书后，已保存记录才能执行原来的精确返回校验。

原 main 30 项 UI、全格式 40 项 UI、日语 33 项 UI 文件的全部原始行按序保留。并集为 **43 项**：[完整清单](FORMATS-JAPANESE-UI-INVENTORY.json)。保留全格式 7z fixture 的 Xcode 16 类型拆分，以及日语最终 named Form viewport、可点击入口与单 AX 角色图例修复。无缩减断言、超时、跳过或 Native only-testing；Native 总预算仍为50分钟，单项仍180/240秒。

原 main 的 EPUB reader/engine/实际章节验证测试、Bookno 协议测试及83项需求台账原样保留。原批准漫画 codec 的108项源码/资源/许可证原样保留；96项 pin 和6个真实容器 fixture 继续校验，不增加解码器。独立工作树保留其他工人、本机主工作树及其 Xcode 用户元数据。

Bookno 离线预览新增明确文案/内存提示：日语独立学习记录尚未适配，本次不包含。原支持的 PDF/EPUB 高亮及旧 AI 学习记录、TXT/Markdown/HTML 高亮继续使用既有协议；7种 wire namespace 保持，新10种格式仍可见但不可选择。预览不读取日语存储，不增加 DTO/导出/网络/同步/outbox；无实际 Bookno/iCloud 实现。

新增两项跨功能回归，仅使用原创建夹具、隔离 UUID 书库、原生 PDFView 和未附着的 WebKit：四种 ebook、三种网页、四种漫画切换后，非合作迟到响应被拒、额度保持、日语存储和原件不变，明确重开原 PDF 后精确返回与重启保留；离线预览诚实提示日语记录排除、旧 PDF 笔记仍导出、日语存储即使损坏也不被预览读取或改写。测试不调用实际 API。

## 本地预检

联合候选本地非窗口范围 **305 Swift／40 suites，4.354s** 通过，包括两项新边界回归；**25 Node** 通过；**169** 个资源/fixture/project/codec 文件复现前后哈希与通过的全格式输入一致。source guard **581** 文件、96项 codec pin／6个原创建容器、8项台账检查通过。Mac 与 iPhone/iPad Simulator unsigned build-for-testing 均成功，app 及完整43项 Mac UI 包均编译 arm64/x86_64。本地实际 UI **0**，窗口方法全部保留待完整 CI。

新回归第一次运行错误地要求其他格式活动时直接返回后台 PDF，共11个失败；现有来源屏障正确拒绝。仅修正新增测试为先断言拒绝、明确打开原 PDF，再精确返回并校验存储/原件不变；未放宽生产来源检查。失败与成功日志均保留。

## 确切提交验收与合入门槛

联合分支与随后 main 各自必须执行完整 Native checks 和 bounded comic checks。Native 必须包含无筛选完整 Swift（所有 NSWindow 回归）、25项 Node、资源/fixture/project 复现、source/codec/8项台账检查、Mac 与 iPhone/iPad Simulator 构建，以及 **43/43 实际 UI，0失败/跳过/缺失/重名**。漫画工作流的有限离线筛选保持，但不能替代完整 Native。

日志、API 返回的 head SHA/结论、逐项实际 UI 事件、原件与用户元数据哈希组成独立验收回执。CI 失败只修相关问题，保留43项及断言，对新 SHA 完整重跑；未经联合确切 SHA 全部通过不改 main。合入后再次核对 main 远端 SHA、两条输入祖先、实际 UI 和完整 CI。此文随候选提交，**不预先宣称联合/main 通过**；最终状态由确切提交的 CI 与交付回执绑定。

## 实际能力边界

MOBI/AZW 仅有限 PalmDB v6/pure v8，AZW3 仅有限纯 KF8，FB2 仅有限无二进制 XML；网页仅规范 XHTML、平面 MHTML 和有限可读 XML；CBT 仅未压缩 USTAR，CB7 仅明文非 solid COPY/LZMA1/LZMA2，CBR 仅 RAR4/5 STORE，压缩 RAR 明确拒绝。没有通用 Kindle、任意 XML、归档附件还原或新增转换能力。

日语仅 PDF/EPUB 有限选文、明确同意、手动审阅/保存、独立记录、模型建议假名/语法和句子角色。字节/来源/取消/额度测试不证明真实模型语言准确性；实际 API/TLS/账单、完整 VoiceOver/像素审阅、移动日语入口、英语语法、全书批注及日语记录编辑/搜索/删除/导出/Bookno 均未完成或未核验。原独立安全专项仍 **UNVERIFIED／平台阻塞**，未重试。83项台账不因候选整合自动改为全完成。
