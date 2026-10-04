# 四格式电子书与文本／章节：独立本地整合交接

日期：2026-10-04。分支 `feature/ebook-integration`，新独立 `ebook-integration` 工作树。整合基线为用户指定已验收29 UI的 `f3ed484fee815effed2d955f8eb21bcd66d8546e`，电子书来源为 `3db8c981757491d6428250cd87ebb2c674e616f7`。本次不混入Bookno，不操作其工作树或main，不push、发行、启动用户app或访问真实API/key。未发现AGENTS/.agents/.codex附加约定；已读根贡献说明、v0.3相关规格及文本／章节整合和CI修复记录。

通过验证的精确源码提交为 `77628067c7e981c1f110af1b52c1948ccaedf82c`；其后的交付提交只补充文档／证据。完整源码tree、提交映射、命令、退出状态、日志SHA-256、失败记录、保留文件及33 UI方法名单在[证据JSON](EBOOK-INTEGRATION-EVIDENCE.json)。原[电子书切片记录](EBOOK-VALIDATION.md)和原native证据只描述原8cf基线/d28切片，不替代此次整合结果。

## 实际合成与保留

- 两次本地cherry-pick映射：`d28afe72` → `2a245ced`，`3db8c981` → `e86f7887`。真实8个冲突文件：Package.swift、LibraryModel.swift、LibraryModel+Comics/+NoteEditing/+Search.swift、LibraryWorkspace.swift、engine-build/README.md及package-lock.json。package.json自动合成；锁文件保留f3ed全部既有非根记录，新增jsdom仅开发测试。离线复制既有已固定依赖，67个安装版本核验通过；固定源码／许可和bundle构建器继续校验，没有重新安装或联网取包。
- 文本与电子书各有独立owner、通知转发、导入／打开／详情／选中ID／列表和网格入口；导入类型包含两者。所有格式切换保存当前进度，并在新读者成功打开后停用其他读者。直接电子书导入／打开也取消选文、物理页和章节任务、清临时key；文本直接路由对称关闭电子书。电子书活动时拒绝隐藏PDF/EPUB来源、进度、AI与章节范围。
- 笔记保持原格式／版本／edition/hash/精确anchor，各独立manifest和原件不迁移。已授权旧PDF正文后台保存仍刷新原笔记／搜索，但不投影到电子书。新增3项真实跨模块测试（其中一项含4格式参数）验证双向文本／电子书原件、笔记、进度与重启，章节任务清理，PDF正文／搜索回跳及电子书来源保留。文本／电子书搜索、正文编辑、AI和封面仍未扩展，不伪造类型或封面记录。
- 原 `NativeUITests.swift` 全29方法及断言与f3ed逐字一致；另加独立 `EbookFormatUITests` 四方法，共33 Mac UI。原正文输入／draft失败fixture／封面容器、EPUB工具栏与章节预算展示修复逐字保留。没有删断言、跳case、放宽超时或修改存储／Unicode/来源条件。
- 必要生产修复：全量运行暴露旧章节精确回跳可能丢选区。实际DOM选区事件在native busy期间被忽略，而JS已去重，之后没有新事件；现在受信任父realm的命令state同步回传同一canonical DOM range，native仍校验session/book/edition/hash/documentVersion及anchor，并检查spine。不靠放宽来源或修改书籍脚本sandbox解决。原失败章节测试及全量203项通过，canonical提取版本、Unicode/ruby处理与DRM/限额均不变。仅既有EPUB engine.js因该桥接修复重建；DOCX/漫画/文本资源与f3ed字节一致。
- CI配置在完整Native检查中加入电子书测试、构建、8份样例和输入清单的再现；没有调用CI或推送。原manual ebooks流程只运行4条，不能代替完整33条回归。

## 本地实际验证

| 检查 | 结果 |
| --- | --- |
| 全量正常Swift／真实离屏WebKit | **203/203，32 suites，6.051秒**，覆盖既有193、电子书7、跨模块3；使用UUID临时store、自制fixture及完全拦截的AI/Keychain测试实现 |
| Node回归 | **25/25，0失败、0跳过**；既有14和电子书11 |
| 五个bundle／项目／样例再现 | **PASS**，生成后tracked差异0；完整许可、36份原创库存保留 |
| 源码来源检查／需求账本／项目格式 | **PASS**；账本8/8，最终源码数量以交付时守卫输出为准 |
| Mac build-for-testing | **TEST BUILD SUCCEEDED**，33 UI源码编译；没有执行任何UI或启动PDFno |
| iPhone/iPad generic Simulator build | **BUILD SUCCEEDED**，arm64/x86_64编译；没有启动模拟器/app，不证明移动电子书阅读 |
| 本候选UI执行、远端CI | **NOT-RUN / 0**，不能沿用f3ed的29通过作为此新SHA结论 |

失败历史保留：首次新测试把async放入布尔autoclosure，编译失败后拆为相同两条断言；随后全量203运行有2问题，旧章节丢选区及新取消fixture超3000预算。后者改为真正自制、限额内小EPUB，没有改3000上限、生产范围或原fixture；前者按上述实际桥接修复。失败不计为通过，日志及hash在证据中保留。修复后全量通过，再于同一源码提交完成两端最终编译和资源再现。

环境arm64 macOS27.0、Xcode27.0/27A266a、Swift6.4，部署目标macOS14/iOS17。所有显式SwiftPM/DerivedData/cache/config/security/日志路径为独立`/tmp/pdfno-ebook-integration-build`，Foundation用户目录用CFFIXED_USER_HOME隔离，未重定义HOME。离屏NSWindow属于测试进程且保持不可见。正常功能执行均经自动审查允许；没有此次权限拒绝。独立安全专项仍 **UNVERIFIED / platform blocked**，未重试／禁用sandbox／换编译器／绕过。已有普通套件的受控原始fixture负例通过不构成安全专项验收。

完整原生UI、最低系统／Intel Mac运行、真实设备、VoiceOver、真实翻译质量／费用、发行签名和广泛市场电子书兼容仍未验收。MOBI/AZW受限PalmDB、纯KF8 AZW3、plain UTF-8 FB2边界不变；无DRM解除，HUFF/combo/NCX/guide、FB2 ZIP/binary和版式资源仍不支持，详见[固定引擎与逐格式边界](ADR-EBOOK-KOOKIT.md)。

## 后续隔离CI与整合限制

下一步需要单独授权普通发布最终确切候选到新分支 `feature/ebook-integration`，并在隔离CI运行该SHA的完整Native及CBZ检查。Native不得设置only-testing或跳过旧case，全部33 Mac UI实际执行／通过、0跳过；收集逐方法结果和xcresult。若CI失败，保留断言修复并在新SHA完整重跑。main合并、发行、Bookno验收及共享Library均不包含在该许可中。

本树仅从f3ed整合本电子书候选；Bookno由协调任务在其独立分支处理。将来与Bookno或其他候选组合时仍需人工合成LibraryModel/LibraryWorkspace/资源及通知所有者，保留此次双向路由与来源隔离；不得从别的工作树复制整个共享文件覆盖。本次8个Git冲突已解决，没有待解冲突；后续组合必须重新在确切SHA回归，不能把两分支各自通过相加。
