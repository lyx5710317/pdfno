// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoReaders

struct ComicWorkspace: View {
    @ObservedObject var session: ComicReaderSession
    let close: () -> Void
    @State private var pages = false
    var body: some View {
        VStack(spacing: 0) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), alignment: .leading)], alignment: .leading, spacing: 8) {
                Picker("阅读方向", selection: Binding(get: { session.direction }, set: { value in Task { await session.setDirection(value) } })) {
                    Text("从左到右").tag(ComicDirection.leftToRight); Text("从右到左").tag(ComicDirection.rightToLeft)
                }.disabled(session.busy).accessibilityIdentifier("comic-direction")
                Picker("页面布局", selection: Binding(get: { session.layout }, set: { value in Task { await session.setLayout(value) } })) {
                    Text("自动").tag(ComicLayout.automatic); Text("单页").tag(ComicLayout.single); Text("双页").tag(ComicLayout.double)
                }.disabled(session.busy).accessibilityIdentifier("comic-layout")
            }.padding(10)
            ComicCanvas(session: session)
            HStack { Text(session.position).accessibilityIdentifier("comic-position"); Spacer(); Text("CBZ · 本地") }.font(.caption).padding(10)
            if let error = session.error { Text(error).foregroundStyle(.red).padding().accessibilityIdentifier("comic-error") }
        }.navigationTitle(session.book?.title ?? "漫画")
        .overlay { if session.busy { ProgressView("正在打开漫画…").padding().background(.regularMaterial) } }
        .toolbar {
            ToolbarItemGroup {
                Button("页面") { pages = true }.disabled(session.book == nil).accessibilityIdentifier("comic-pages")
                Button { Task { await session.previous() } } label: { Label("上一页", systemImage: session.direction == .rightToLeft ? "chevron.right" : "chevron.left") }
                    .disabled(session.busy || !session.hasPrevious).accessibilityIdentifier("comic-previous")
                Button { Task { await session.next() } } label: { Label("下一页", systemImage: session.direction == .rightToLeft ? "chevron.left" : "chevron.right") }
                    .disabled(session.busy || !session.hasNext).accessibilityIdentifier("comic-next")
                Button("关闭漫画") { close() }.accessibilityIdentifier("comic-close")
            }
        }
        .sheet(isPresented: $pages) {
            NavigationStack {
                List(Array((session.book?.pages ?? []).enumerated()), id: \.offset) { index, page in
                    Button("\(index + 1). \(page.path)") { Task { await session.go(to: index); pages = false } }.disabled(session.busy).accessibilityIdentifier("comic-page-\(index)")
                }.navigationTitle("漫画页面").toolbar { ToolbarItem { Button("完成") { pages = false } } }
            }.frame(minWidth: 350, minHeight: 400)
        }
    }
}
#endif
