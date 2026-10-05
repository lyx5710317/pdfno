// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain

/// Mount inside the host's results List using the combined controller's records response.
/// Saved result/source/body fields remain separately available on each typed entry.
struct RecordSearchResults: View {
    let response: RecordSearchResponse
    let error: String?
    let open: @MainActor (RecordSearchTarget) async -> Bool
    @State private var opening = false
    @State private var sourceError: String?
    var body: some View {
        Section("文本、电子书与语言学习记录") {
            ForEach(response.hits) { hit in
                VStack(alignment: .leading, spacing: 6) {
                    Text(hit.entry.title + " · " + hit.entry.target.book.format.label).font(.caption)
                    Text(hit.preview).textSelection(.enabled).lineLimit(4).accessibilityIdentifier("record-search-preview")
                    if hit.entry.target.kind == .japanese { Text("已保存日语建议 · 用户正文与读音修正独立保留").font(.caption).foregroundStyle(.secondary) }
                    if hit.entry.target.kind == .english { Text("已保存英语建议 · 用户正文独立保留").font(.caption).foregroundStyle(.secondary) }
                    Button(hit.entry.target.kind == .book ? "打开书籍" : "回到来源") {
                        opening = true
                        Task {
                            let returned = await open(hit.entry.target); opening = false
                            sourceError = returned ? nil : LibrarySearchFailure.source.localizedDescription
                        }
                    }.disabled(opening || !hit.entry.sourceAvailable)
                    .accessibilityIdentifier("record-search-source")
                    if !hit.entry.sourceAvailable { Text("来源书籍不在书库；引文仍可查看。").font(.caption) }
                }
            }
            if let error = sourceError ?? error { Text(error).foregroundStyle(.red).accessibilityIdentifier("record-search-error") }
        }.onChange(of: response) { _, _ in sourceError = nil }
    }
}
#endif
