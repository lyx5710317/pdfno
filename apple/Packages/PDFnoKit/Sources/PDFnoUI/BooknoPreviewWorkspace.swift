// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

struct BooknoPreviewWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pdfnoInlineDismiss) private var inlineDismiss
    @ObservedObject var model: BooknoPreviewModel
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Bookno 未连接。请从本地书目明确选择；预览只包含所选书籍的已保存内容，生成内存预览与 mock 回执。关闭后清除本次模拟；不会自动导出或保存发布历史。")
                        .accessibilityIdentifier("bookno-preview-boundary")
                    Toggle("启用本次离线预览", isOn: $model.enabled).accessibilityIdentifier("bookno-preview-enabled")
                    Text("选择书籍（最多20本）").font(.headline)
                    if model.choices.isEmpty { Text("尚无可预览书目；请先导入书籍，或刷新书目。") }
                    ForEach(model.choices) { choice in
                        Toggle(isOn: Binding(get: { model.selectedIDs.contains(choice.id) }, set: { chosen in
                            if chosen { model.selectedIDs.insert(choice.id) } else { model.selectedIDs.remove(choice.id) }
                        })) {
                            Text(choice.book.title + " · " + choice.book.edition.format.rawValue.uppercased())
                        }.accessibilityIdentifier("bookno-book-" + choice.id)
                    }
                    if !model.unsupportedBooks.isEmpty {
                        Text("以下格式尚未适配 Bookno，不能包含在本次预览中：").font(.callout)
                        ForEach(model.unsupportedBooks) { book in
                            Text(book.title + " · " + book.format + " · 暂不可预览")
                                .foregroundStyle(.secondary).accessibilityIdentifier("bookno-unsupported-" + book.id)
                        }
                    }
                    Toggle("包含所选书籍已适配的高亮与学习笔记", isOn: $model.includeSavedNotes)
                        .accessibilityIdentifier("bookno-include-notes")
                    Text("不含编辑草稿。PDF／EPUB 包含已保存AI结果与独立用户正文；TXT／Markdown／HTML 包含普通高亮。日语学习记录尚未适配，本次不包含。漫画／Word 当前仅书目与封面，笔记尚未适配。")
                        .font(.caption).foregroundStyle(.secondary)
                    Toggle("包含所选书籍的既存封面", isOn: $model.includeCovers).accessibilityIdentifier("bookno-include-covers")
                    Text("只读取已保存图片，不生成或改写封面。文本格式封面未开放；缺失会明确说明。")
                        .font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("刷新书目") { Task { await model.refresh() } }.disabled(model.busy).accessibilityIdentifier("bookno-refresh")
                        Button("生成本机预览") { Task { await model.prepare() } }.buttonStyle(.borderedProminent)
                            .disabled(!model.enabled || model.selectedIDs.isEmpty || model.busy).accessibilityIdentifier("bookno-prepare")
                    }
                    if model.busy { ProgressView("正在读取已保存快照…") }
                    Text(model.status).accessibilityIdentifier("bookno-preview-status")
                    if let error = model.error { Text(error).foregroundStyle(.red).accessibilityIdentifier("bookno-preview-error") }
                    ForEach(Array(model.notices.enumerated()), id: \.offset) { _, notice in Text(notice).font(.callout) }
                    if let batch = model.batch {
                        let books = batch.mutations.filter { $0.payload.kind == .book }.count
                        Text(verbatim: "\(batch.mutations.count) 个对象 · \(books) 本书 · \(batch.mutations.count - books) 条已保存笔记 · \(batch.assets.count) 个封面资产")
                            .font(.headline).accessibilityIdentifier("bookno-preview-summary")
                        ForEach(batch.mutations, id: \.payload.externalID) { mutation in
                            VStack(alignment: .leading, spacing: 6) {
                                switch mutation.payload {
                                case .book(let book): Text(book.title).font(.headline)
                                case .note(let note):
                                    Text("引文").font(.caption); Text(verbatim: note.quote).textSelection(.enabled)
                                        .accessibilityIdentifier("bookno-note-quote-" + note.externalID)
                                    Text("已保存用户正文").font(.caption); Text(verbatim: note.userText.isEmpty ? "（空正文）" : note.userText).textSelection(.enabled)
                                        .accessibilityIdentifier("bookno-note-body-" + note.externalID)
                                    ForEach(Array(note.aiAttachments.enumerated()), id: \.offset) { _, result in
                                        Text("AI原结果 · " + result.promptVersion).font(.caption)
                                        Text(verbatim: result.text).textSelection(.enabled)
                                    }
                                }
                            }.padding().frame(maxWidth: .infinity, alignment: .leading).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        }
                        HStack {
                            Button("运行内存 mock／重放同一批次") { model.runMock() }.accessibilityIdentifier("bookno-run-mock")
                            Button("模拟提交后丢回执") { model.runMock(loseReceipt: true) }.accessibilityIdentifier("bookno-mock-lose-receipt")
                        }.disabled(!model.enabled || model.busy)
                        Text(verbatim: "mock 记录 \(model.mockRecordCount) · mock 封面 \(model.mockAssetCount) · 连续确认游标 \(model.confirmedCursor)")
                            .accessibilityIdentifier("bookno-mock-counts")
                        if let receipt = model.receipt {
                            ForEach(receipt.items, id: \.externalID) { item in
                                Text(item.externalID + " · " + label(item.status)).font(.caption)
                            }
                        }
                        DisclosureGroup("协议 JSON（本机只读）") {
                            Text(verbatim: model.json).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                                .accessibilityIdentifier("bookno-preview-json")
                        }
                    }
                }.padding(24).frame(maxWidth: .infinity, alignment: .leading)
            }.accessibilityIdentifier("bookno-preview-scroll").navigationTitle("Bookno 离线预览")
                .toolbar { ToolbarItem { Button("完成（清除本次模拟）") { model.close(); if let inlineDismiss { inlineDismiss() } else { dismiss() } }.accessibilityIdentifier("bookno-preview-close") } }
        }.frame(minWidth: inlineDismiss == nil ? 620 : 0, minHeight: inlineDismiss == nil ? 600 : 0)
            .task { await model.refresh() }.onDisappear { model.close() }
    }
    private func label(_ status: BooknoReceiptStatus) -> String {
        switch status {
        case .applied: "内存更新"
        case .unchanged: "内容一致"
        case .localEditDiverged: "字段编辑冲突，未更新"
        case .blockedDependency: "整批保留，未更新"
        case .missingParent: "缺少来源书籍"
        case .staleRevision: "旧修订，未更新"
        case .revisionContentMismatch: "修订内容不一致"
        case .baseRevisionMismatch: "需重新对账"
        case .deletionPreviewOnly: "仅删除预览"
        }
    }
}
#endif
