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
            PDFnoProfessionalReaderChrome(title: session.book?.title ?? "漫画", format: "") {
                Menu {
            VStack(spacing: 8) {
                Picker("阅读方向", selection: Binding(get: { session.direction }, set: { value in Task { await session.setDirection(value) } })) {
                    Text("从左到右").tag(ComicDirection.leftToRight); Text("从右到左").tag(ComicDirection.rightToLeft)
                }.disabled(session.busy).accessibilityIdentifier("comic-direction")
                Picker("页面布局", selection: Binding(get: { session.layout }, set: { value in Task { await session.setLayout(value) } })) {
                    Text("自动").tag(ComicLayout.automatic); Text("单页").tag(ComicLayout.single); Text("双页").tag(ComicLayout.double)
                }.disabled(session.busy).accessibilityIdentifier("comic-layout")
                Button("关闭漫画") { close() }.accessibilityIdentifier("comic-close")
            }.padding(10)
                } label: { Image(systemName: "slider.horizontal.3") }.help("漫画页面设置").accessibilityLabel("漫画页面设置").accessibilityIdentifier("comic-settings")
                    .accessibilityValue(settingsSummary)
            } actions: {
                PDFnoReaderRailButton(title: "页面", symbol: "list.bullet", identifier: "comic-pages", active: pages, disabled: session.book == nil) { pages.toggle() }
            } content: {
                PDFnoReaderShell(panels: readerPanels, profile: .professional) {
                    ComicCanvas(session: session).overlay(alignment: .bottom) {
                        ReadingPageButtons(previousEnabled: !session.busy && session.hasPrevious,nextEnabled: !session.busy && session.hasNext,previous: { Task { await session.previous() } },next: { Task { await session.next() } })
                    }
                }
                    navigation: { pagesContent } notes: { EmptyView() }
            }
            HStack { Text(session.position).accessibilityIdentifier("comic-position"); Spacer(); Text("点击阅读区边缘翻页 · 单页／双页") }.font(.caption).padding(10)
            if let error = session.error { Text(error).foregroundStyle(.red).padding().accessibilityIdentifier("comic-error") }
        }.navigationTitle(session.book?.title ?? "漫画")
        .overlay { if session.busy { ProgressView("正在打开漫画…").padding().background(.regularMaterial) } }
    }
    private var settingsSummary: String {
        let layout: String
        switch session.layout { case .automatic: layout = "自动"; case .single: layout = "单页"; case .double: layout = "双页" }
        return layout + "，" + (session.direction == .rightToLeft ? "从右到左" : "从左到右")
    }
    private var readerPanels: PDFnoReaderPanels {
        var result = PDFnoReaderPanels()
        if pages { result.show(.navigation, profile: .professional) }
        return result
    }
    private var pagesContent: some View {
        PDFnoPanel(title: "漫画页面", icon: "list.bullet", closeIdentifier: "comic-pages-close", close: { pages = false },surface: PDFnoDesign.Palette.surface,showsHeading: false,showsHeader: false) {
            List(Array((session.book?.pages ?? []).enumerated()), id: \.offset) { index, page in
                Button("\(index + 1). \(page.path)") { Task { await session.go(to: index); pages = false } }
                    .disabled(session.busy).accessibilityIdentifier("comic-page-\(index)")
            }
        }
    }
}
#endif
