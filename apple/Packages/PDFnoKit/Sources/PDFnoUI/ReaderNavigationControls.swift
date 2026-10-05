// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import SwiftUI
import PDFnoReaders

struct PDFReturnToPreviousLocationButton: View {
    @ObservedObject var session: PDFReaderSession
    var body: some View {
        Button { session.returnToPreviousLocation() } label: { Label("返回跳转前页面", systemImage: "arrow.uturn.backward") }
            .disabled(session.book == nil || !session.canReturnToPreviousLocation)
            .accessibilityIdentifier("reader-return-location").help("返回目录、搜索或来源跳转前的 PDF 页；仅当前阅读会话")
    }
}

#if os(macOS)
struct EPUBReturnToPreviousLocationButton: View {
    @ObservedObject var session: EPUBReaderSession
    var body: some View {
        Button { Task { await session.returnToPreviousLocation() } } label: { Label("返回跳转前位置", systemImage: "arrow.uturn.backward") }
            .disabled(session.book == nil || session.busy || !session.canReturnToPreviousLocation)
            .accessibilityIdentifier("epub-return-location").help("通过原文锚点返回目录或来源跳转前的位置；仅当前阅读会话")
    }
}

struct PDFReaderNavigationShortcuts: View {
    @ObservedObject var session: PDFReaderSession
    var body: some View {
        ReaderNavigationShortcuts(enabled: session.book != nil && session.document != nil,
            canvas: { session.view }, perform: { command in
                switch command {
                case .previousPage: return session.go(to: session.pageIndex - 1)
                case .nextPage: return session.go(to: session.pageIndex + 1)
                case .returnToPreviousLocation: return session.returnToPreviousLocation()
                }
            }).frame(width: 0, height: 0)
    }
}
#endif
