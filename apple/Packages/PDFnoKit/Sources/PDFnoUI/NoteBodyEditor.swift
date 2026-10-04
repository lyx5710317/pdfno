// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

/// Shared body editor; the immutable quote/result/source remain in their rows.
struct NoteBodyEditor: View {
    @ObservedObject var editor: NoteEditingModel
    let note: NoteBodySnapshot
    let identifier: String
    let save: @MainActor () async -> Void
    let reload: @MainActor () async -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let draft = editor.drafts[note.key] {
                TextField("编辑用户正文", text: Binding(get: { editor.drafts[note.key]?.text ?? draft.text },
                    set: { editor.setText($0, for: note) }), axis: .vertical)
                    .lineLimit(3...8).disabled(editor.saving.contains(note.key))
                    .accessibilityIdentifier(identifier + "-edit-input")
                Text("留空会清空用户正文；引文、来源与 AI 结果保留。")
                    .font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("保存正文") { Task { await save() } }
                        .disabled(editor.saving.contains(note.key) || !draft.baseline.accepts(draft.text))
                        .accessibilityIdentifier(identifier + "-edit-save")
                    Button("取消编辑") { editor.cancel(note) }.disabled(editor.saving.contains(note.key))
                        .accessibilityIdentifier(identifier + "-edit-cancel")
                }
                if !draft.baseline.accepts(draft.text) { Text(draft.baseline.limitDescription).foregroundStyle(.red) }
                if editor.conflicts.contains(note.key) {
                    Button("重新载入基线（保留草稿）") { Task { await reload() } }
                        .accessibilityIdentifier(identifier + "-edit-reload")
                }
            } else {
                Button("编辑正文") { editor.begin(note) }.accessibilityIdentifier(identifier + "-edit")
            }
            if let error = editor.journalError { Text(error).foregroundStyle(.red).accessibilityIdentifier(identifier + "-draft-error") }
            if let feedback = editor.feedback[note.key] {
                Text(feedback).font(.caption).accessibilityIdentifier(identifier + "-edit-status")
            }
        }.buttonStyle(.borderless)
        .onAppear { editor.reconcile(note) }
        .onChange(of: note) { _, current in editor.reconcile(current) }
    }
}
#endif
