# ADR 0002 · Swift 原生应用与 PDFKit

日期：2026-10-02
状态：**方向已批准；后续明确授权已创建真正原生 targets 与最小 PDFKit 闭环。当前实现/验证见 NATIVE-TASKS 与 VALIDATION。**

2026-10-03 状态更新：本文的原生主架构继续有效；EPUB 未选定及文档阶段限制是当时快照，已由 [ADR 0003](ADR-0003-KOOKIT-EPUB.md) 的用户确认、Kookit Mac 切片及分端验收接续。

## 决定

PDFno 的后续主应用采用 Swift 原生界面，以 SwiftUI 组织应用，并在需要时使用 AppKit / UIKit 的平台控件。PDF 阅读采用 Apple PDFKit。EPUB 通过独立 ReaderAdapter 选型，先核验许可证、平台支持和真实样本，再批准引擎。

长期产品支持原生 macOS、iPhone 和 iPad。Mac 优先交付，但共享数据模型、来源锚点、服务边界和移动端适配从工程起点考虑。Mac 目标是原生 macOS 应用，不默认用 Mac Catalyst 代替。

用户明确要求停止旧路线的新增开发、保留已有成果、先完成技术文档，因此本次不创建新应用工程，不改动 React/Electron、Swift bridge 或数据存储，不安装 EPUB 引擎，也不启用 iCloud、签名或账户权限。

这项明确决定取代 ADR 0001 中“等待 Koodo fork / 主阅读引擎路线决策”的未来方向；ADR 0001 描述的现有 demo 与隔离边界仍是历史事实。原 v0.2 规格中的产品目标和安全、数据、验收要求继续有效；涉及 Electron 主应用、低侵入 Koodo fork、原生仅作为 bridge 的实施安排，以本 ADR 和[原生实施计划](NATIVE-APPLE-PLAN.md)为准。

## 保留的目标与成果

- 保留 BYOK、整页翻译、日语假名、日英语言辅助、选区学习、高亮与笔记、来源回跳、Bookno 书籍/封面/笔记交换、iCloud 和逐方向转换目标。
- 保留 PDF、EPUB、漫画与原有多格式目标清单。更换架构不等于 PDFKit 支持所有格式；未接入格式继续明确标为待实现。
- PDFno 自有源码继续使用 **AGPL-3.0-or-later**，根 `LICENSE` 不变；候选引擎及 Apple 系统框架各自的许可不会被根许可证覆盖。
- 现有 React/Electron demo、Unicode/ruby 原文快照、任务隔离、原子笔记存储、受限 IPC、Swift CLI、测试与文档保留，用作行为参考、回归样本与迁移输入。

## 技术边界与依据

Apple 官方文档的可用性信息确认 [PDFKit](https://developer.apple.com/documentation/pdfkit)、[PDFView](https://developer.apple.com/documentation/pdfkit/pdfview)覆盖 macOS、iOS 和 iPadOS。计划分别通过 [NSViewRepresentable](https://developer.apple.com/documentation/swiftui/nsviewrepresentable) 和 [UIViewRepresentable](https://developer.apple.com/documentation/swiftui/uiviewrepresentable)承载平台视图；这是实施设计，不是已经验证的封装。

PDFKit 负责 PDF 展示、原生选择与批注能力。语言分析、持久化、来源校验、Bookno、iCloud、OCR 和格式转换由 PDFno 服务承担，不把它们写成 PDFKit 自带功能。Apple 框架仅通过目标系统 SDK 链接，不复制或再分发 SDK、框架二进制、证书和品牌资产。

EPUB 允许在原生应用中嵌入独立的 WKWebView 阅读引擎；应用的书库、导航、学习栏与数据服务仍是原生界面。引擎不得访问 Keychain、原生数据库、任意文件或通用命令。具体选择保持未定，见[EPUB 审计](EPUB-ENGINE-AUDIT.md)。

## 后果与退出条件

需要真正的 `.app` Xcode targets、原生文件流程、跨平台 PDF/EPUB 锚点与可访问性验证；不能把现有 `PDFnoBridge` CLI 宣称为 Mac 应用。未来在独立目录增量建立工程，旧目录和数据保持可恢复。

三端适配不要求同一窗口布局或同一 EPUB 引擎实现，但要求共享稳定身份、版本化来源和可验证的交换契约。iCloud 原书范围、最终最低系统版本、EPUB 引擎与发布渠道仍待决定；这些问题不阻止完成本轮文档。

原生实现、真实设备验证、数据迁移、云能力与发布分别按实施计划的门槛推进。完成文档不表示上述能力已实现或任何发行渠道已获批准。
