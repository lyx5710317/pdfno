# PDFno

PDFno 是一款以 Mac 为优先的本地阅读器，把书库、多文档阅读、来源笔记和按需 AI 学习放在同一工作区。应用界面使用 SwiftUI / AppKit，PDF 使用 PDFKit，重排电子书等内容使用受限的 WKWebView 阅读模块。

当前为 **0.3.0 开发版**，尚未正式发行。iPhone / iPad target 已存在，目前以基础 PDF 阅读为主，尚未完成与 Mac 相同的功能与验收。

## 阅读与笔记

- 本地导入并保留原书副本，支持列表 / 网格书库、封面和多文档标签。
- 阅读目录、恢复进度；PDF 支持文字层搜索，EPUB 支持重排、横竖排和作者标注的 ruby。
- 保存选文高亮与笔记、编辑自己的正文、返回原文位置。AI 结果需明确添加为笔记，来源引文、生成结果与用户正文分开保存。
- 搜索书名、本地补录作者和已保存的笔记、引文、AI 结果。未保存草稿与全书正文不进入书库搜索；语义搜索尚未实现。

Mac 当前已接入以下格式。支持扩展名不代表支持该格式的所有文件、排版或压缩方式；各入口仍有范围限制。

| 格式 | 当前范围 |
| --- | --- |
| PDF | 本地阅读、目录、文字层搜索、选文笔记与进度；无文字层的扫描页不能选字或参与全文对话，未解锁的加密文件不导入。 |
| EPUB | 无 DRM 的重排阅读、目录、选文笔记与进度；固定版式和全面图片 / 字体保真未支持。 |
| MOBI / AZW / AZW3 / FB2 | 有限的无 DRM 正文、目录、笔记与进度；完整格式兼容与应用界面验收尚未完成。 |
| TXT / MD / HTML / HTM / XHTML / MHTML / XML | 有限正文与标题导航、选文笔记和进度；XML 仅接受可阅读的限定结构，网页类内容不加载外部页面、图片或样式。 |
| DOCX | 语义重排、标题目录、简单表格 / 列表与笔记；不保留 Word 原版式，不支持旧 DOC。 |
| CBZ / CBT / CB7 / CBR | 静态 PNG / JPEG 漫画、自然页序、左右方向、单双页与进度；CBT 限未压缩 POSIX USTAR，CB7 限明文头、非 solid COPY / LZMA / LZMA2，CBR 限 RAR4 / RAR5 STORE。 |

具体边界见 [EPUB](docs/ADR-0003-KOOKIT-EPUB.md)、[电子书](docs/ADR-EBOOK-KOOKIT.md)、[网页归档](docs/WEB-ARCHIVE-FORMATS.md)、[DOCX](docs/ADR-DOCX-KOOKIT-MAMMOTH.md)与[漫画解码](docs/COMIC-CODEC-VALIDATION-2026-10-04.md)。

## AI 学习

在“设置 → AI”的“配置api”中选择服务商、HTTPS API 地址、模型并填写会话 API Key。DeepSeek 有预设；其他接口须符合当前受限的 JSON chat-completions 协议，并非所有兼容服务都能使用。应用连接配置本身不会发送测试或阅读请求。

PDF / EPUB 选文可发起解释、翻译、总结和后续对话。日语、英语学习可在“AI工具”中按需开启；结构化语言审阅的真实服务目前限 DeepSeek。选文对话发送固定选文、当前问题及该对话的有界消息历史，不自动加入其他书籍或笔记。

全文对话仅用于 **PDF / EPUB 可完整提取的正文**，上限为 60,000 UTF-16 单元；提取不完整或超限时拒绝发送。首次发送前需确认范围，追问复用已确认正文与该会话消息。另有受限的 PDF 当前页 / EPUB 当前正文文档双语翻译，使用同一共享连接并独立确认范围；EPUB 正文文档不等于目录中的逻辑章节。

打开面板不会自动生成，回答不会自动存笔记。本地模拟示例不联网；真实任务与用户主动发起的连接测试会向所选服务发送对应文本。AI 返回内容应结合原文核对，服务可用性、语言质量与费用由实际服务决定；客户端限制不等于账单上限。

## 本地数据、备份与导出

Mac 默认数据目录为 `~/Library/Application Support/PDFnoNative`，导入副本、阅读进度和已保存笔记存放在本机；高亮不改写原书。书库提供本地回收站、校验目录备份及恢复到新目录。备份不包含未保存草稿、缓存或密钥；恢复不会自动切换当前书库。

服务地址、模型等非秘密配置可保存；**API Key 仅在当前应用会话内存中**，不回填、不写入笔记或磁盘，退出后需重新填写，尚未启用 Keychain 持久化。同一连接留空可保留已应用的 Key，改变接收地址或模式会撤销旧引用；也可主动清除会话密钥。

“格式转换”可把 DOCX 正文导出为 UTF-8 TXT / 简化 HTML，或重新分页生成阅读版 PDF。这些是有损副本，不是 Word 原版式还原或 PDF / Word / EPUB 高保真互转；导出不覆盖原件或已有文件。见[转换范围](docs/ADR-0009-LOCAL-CONVERSION.md)与[阅读版 PDF](docs/DOCX-READING-PDF-EXPORT.md)。

iCloud 同步和 Bookno API 尚未接入；Bookno 入口仅为离线预览。OCR、Apple Pencil、语义搜索、MCP、AI 工具调用和在线网页 / 公共搜索仍为规划。

## 本地运行

使用 Xcode 打开 `apple/PDFno.xcworkspace`，选择 **PDFnoMac** 并在本机运行。当前部署基线为 macOS 14、Swift 6，开发工具基线为 Xcode 16.4+。内置原创 PDF / EPUB / DOCX 等示例可用于试读。Mac Debug 使用本机 ad hoc 签名，无需开发者证书；正式签名、公证与下载后验收尚未完成，当前 Release 配置不构成正式发行包。

阅读资源已随源码保存，直接运行无需 Node。共享 `PDFnoKit` 为本地 Swift package，无外部 Swift 包依赖；需要重建阅读资源时参见 [engine-build](engine-build/README.md)。轻量源码检查：

```sh
python3 -B scripts/check-native-source.py
```

构建与测试说明见[验证记录](docs/VALIDATION.md)、[Mac GUI 测试流程](qa/mac-ui-regression/README.md)和[Release 准备](docs/MAC-RELEASE-PREPARATION.md)。GUI 测试须使用隔离的测试应用、原创数据与当前桌面交接，避免影响现存应用和真实书库。

## 开发状态

已实现的入口与已完成的验收分别记录。近期真实 API 检查只验证了原创样例的解释、追问、显式保存及全文确认，不代表所有格式、语言质量或整套界面测试通过。当前覆盖与未完成项见[共享 AI 覆盖记录](docs/MAC-AI-CLEANUP-COVERAGE-2026-10-13.md)及[定向修复记录](docs/MAC-TARGETED-UI-REPAIR-2026-10-13.md)；历史报告仅适用于各自注明的版本。

## 许可证

PDFno 自有代码采用 **AGPL-3.0-or-later**。第三方阅读引擎与编解码组件保留各自许可证及来源声明，详见 [LICENSE](LICENSE)、[SOURCE-NOTICES](SOURCE-NOTICES.md)和[THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md)。
