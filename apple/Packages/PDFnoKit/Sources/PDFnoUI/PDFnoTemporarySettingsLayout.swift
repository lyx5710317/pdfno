// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI

/// Temporary presentation only. Replace these metrics when the final design arrives.
enum PDFnoTemporaryLayout {
    static let settingsBreakpoint: CGFloat = 760
    static let sidebarWidth: CGFloat = 196
    static let contentMaximum: CGFloat = 880
    static let corner: CGFloat = 12
    static func usesSidebar(width: CGFloat) -> Bool { width.isFinite && width >= settingsBreakpoint }
    static func directoryColumns(width: CGFloat) -> Int { width.isFinite && width >= 640 ? 2 : 1 }
}

enum PDFnoSettingsCategory: String, CaseIterable, Identifiable {
    case general, ai, tools, backup, shortcuts, diagnostics, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .general: "通用"
        case .ai: "AI"
        case .tools: "AI工具"
        case .backup: "同步与备份"
        case .shortcuts: "快捷键"
        case .diagnostics: "诊断"
        case .about: "关于"
        }
    }
    var symbol: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .ai: "sparkles"
        case .tools: "square.grid.2x2"
        case .backup: "archivebox"
        case .shortcuts: "keyboard"
        case .diagnostics: "doc.text.magnifyingglass"
        case .about: "info.circle"
        }
    }
}

/// Content always has the same parent across resizing; state belongs to the caller.
struct PDFnoSettingsShell<Content: View>: View {
    @Binding var category: PDFnoSettingsCategory
    @ViewBuilder var content: () -> Content
    var body: some View {
        GeometryReader { geometry in
            let wide = PDFnoTemporaryLayout.usesSidebar(width: geometry.size.width)
            HStack(alignment: .top, spacing: PDFnoDesign.Space.section) {
                if wide {
                    VStack(spacing: PDFnoDesign.Space.small) {
                        ForEach(PDFnoSettingsCategory.allCases) { item in
                            Button { category = item } label: {
                                Label(item.title, systemImage: item.symbol)
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }.buttonStyle(PDFnoActionStyle(role: .quiet))
                                .background(category == item ? PDFnoDesign.Palette.selection : .clear,
                                    in: RoundedRectangle(cornerRadius: PDFnoTemporaryLayout.corner))
                                .accessibilityIdentifier("settings-category-" + item.rawValue)
                                .accessibilityValue(category == item ? "已选中" : "未选中")
                                .accessibilityAddTraits(category == item ? .isSelected : [])
                        }
                    }.padding(PDFnoDesign.Space.small).pdfnoCard()
                        .frame(width: PDFnoTemporaryLayout.sidebarWidth)
                        .accessibilityIdentifier("settings-sidebar")
                }
                VStack(alignment: .leading, spacing: PDFnoDesign.Space.regular) {
                    if !wide {
                        Picker("设置分类", selection: $category) {
                            ForEach(PDFnoSettingsCategory.allCases) { item in Text(item.title).tag(item) }
                        }.accessibilityIdentifier("settings-category-picker")
                    }
                    content().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }.frame(maxWidth: PDFnoTemporaryLayout.contentMaximum, maxHeight: .infinity, alignment: .topLeading)
            }.padding(PDFnoDesign.Space.section).frame(maxWidth: .infinity, alignment: .center)
        }.background(PDFnoDesign.Palette.chrome)
    }
}

struct PDFnoSettingsCard<Content: View>: View {
    let title: String
    var detail = ""
    var symbol = ""
    var status: String? = nil
    @ViewBuilder var content: () -> Content
    init(_ title: String, detail: String = "", symbol: String = "", status: String? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.title = title; self.detail = detail; self.symbol = symbol; self.status = status; self.content = content
    }
    var body: some View {
        VStack(alignment: .leading, spacing: PDFnoDesign.Space.regular) {
            VStack(alignment: .leading, spacing: PDFnoDesign.Space.small) {
                if symbol.isEmpty { Text(title).font(PDFnoDesign.TypeStyle.section) }
                else { Label(title, systemImage: symbol).font(PDFnoDesign.TypeStyle.section) }
                if let status { Text(status).font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary) }
                if !detail.isEmpty { Text(detail).foregroundStyle(.secondary) }
            }.fixedSize(horizontal: false, vertical: true)
            content()
        }.font(PDFnoDesign.TypeStyle.body).frame(maxWidth: .infinity, alignment: .leading)
            .padding(PDFnoDesign.Space.regular)
            .background(PDFnoDesign.Palette.surface, in: RoundedRectangle(cornerRadius: PDFnoTemporaryLayout.corner))
            .overlay { RoundedRectangle(cornerRadius: PDFnoTemporaryLayout.corner).strokeBorder(PDFnoDesign.Palette.border) }
    }
}

struct PDFnoSettingsField<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content
    init(_ title: String, @ViewBuilder content: @escaping () -> Content) { self.title = title; self.content = content }
    var body: some View {
        VStack(alignment: .leading, spacing: PDFnoDesign.Space.tight) {
            Text(title).font(PDFnoDesign.TypeStyle.metadata).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            content()
        }
    }
}

struct PDFnoPlannedCapability: Identifiable {
    let id: String
    let title: String
    let detail: String
    let dependency: String
    let symbol: String
    static let settings = [
        Self(id: "semantic", title: "本地索引与语义搜索", detail: "规划本机索引和语义检索。现有书名与已保存笔记搜索仍走原入口。", dependency: "索引、模型及范围授权尚未实现。", symbol: "magnifyingglass"),
        Self(id: "mcp-client", title: "连接外部工具 · MCP Client", detail: "规划由 PDFno 主动连接外部工具。", dependency: "连接协议、工具配置及逐次授权尚未实现。", symbol: "point.3.connected.trianglepath.dotted"),
        Self(id: "tool-calling", title: "允许 AI 工具调用", detail: "规划受控调用链；当前阅读任务只使用原有固定指令。", dependency: "工具运行时与调用审阅尚未实现。", symbol: "gearshape.2"),
        Self(id: "mcp-server", title: "对外只读访问 · MCP Server", detail: "规划让外部 AI 读取经授权的本地范围。", dependency: "只读服务、读取范围与访问控制尚未实现。", symbol: "server.rack")
    ]
}

struct PDFnoPlannedCapabilityCard: View {
    let capability: PDFnoPlannedCapability
    var body: some View {
        PDFnoSettingsCard(capability.title, detail: capability.detail, symbol: capability.symbol,
                          status: "未实现 · 默认关闭") {
            PDFnoStatusMessage(text: capability.dependency)
        }.accessibilityIdentifier("planned-" + capability.id)
    }
}

struct PDFnoPlannedDirectory: View {
    @State private var width: CGFloat = 0
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .top),
                                 count: PDFnoTemporaryLayout.directoryColumns(width: width)),
                  alignment: .leading, spacing: PDFnoDesign.Space.regular) {
            PDFnoSettingsCard("网页阅读", detail: "规划读取经授权的公开网页正文。", status: "规划中") {
                Text("正文获取、来源验证与逐次授权尚未实现。")
            }
            PDFnoSettingsCard("公共搜索", detail: "规划检索公开信息并保留来源。", status: "规划中") {
                Text("搜索连接、引用核验与费用范围尚未实现。")
            }
        }.background {
            GeometryReader { geometry in
                Color.clear.onAppear { width = geometry.size.width }
                    .onChange(of: geometry.size.width) { _, value in width = value }
            }
        }.accessibilityIdentifier("planned-tool-directory")
    }
}
#endif
