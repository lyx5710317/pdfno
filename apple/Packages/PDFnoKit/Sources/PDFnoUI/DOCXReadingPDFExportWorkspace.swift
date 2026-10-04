// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFnoDomain
import PDFnoReaders

@MainActor public final class DOCXReadingPDFExportModel: ObservableObject {
    @Published public private(set) var source: URL?
    @Published public private(set) var isRunning = false
    @Published public private(set) var choosingDestination = false
    @Published public private(set) var phase: ConversionPhase = .reading
    @Published public private(set) var result: ConversionResult?
    @Published public private(set) var status = "选择DOCX原件，导出到新的PDF文件。"
    private let service = DOCXReadingPDFService()
    private var task: Task<Void, Never>?
    private var panel: NSSavePanel?
    private var generation = UUID()
    public var isBusy: Bool { isRunning || choosingDestination }
    public init(source: URL? = nil) { self.source = source }
    public func select(_ source: URL) {
        guard !isBusy else { return }
        self.source = source; result = nil; status = "只读原件；导出阅读版PDF，不覆盖原件或已有文件。"
    }
    public func importFailed(_ error: Error) { status = error.localizedDescription }
    public func chooseDestinationAndStart() async {
        guard let source, !isBusy else { return }
        choosingDestination = true
        let save = NSSavePanel(); panel = save
        save.title = "导出阅读版PDF"
        save.message = "重新分页的语义正文，不能还原Word原版式。请选择新文件名；已有文件不会覆盖。"
        save.allowedContentTypes = [.pdf]; save.isExtensionHidden = false; save.canCreateDirectories = true
        save.nameFieldStringValue = source.deletingPathExtension().lastPathComponent + "-阅读版.pdf"
        let response = await withCheckedContinuation { continuation in save.begin { continuation.resume(returning: $0) } }
        panel = nil; choosingDestination = false
        guard response == .OK, let destination = save.url else { return }
        start(source: source, destination: destination)
    }
    public func start(source: URL, destination: URL) {
        guard !isBusy else { return }
        let token = UUID(); generation = token
        isRunning = true; result = nil; phase = .reading; status = "正在生成阅读版PDF…"
        task = Task { [weak self, service] in
            do {
                let result = try await service.convert(source: source, destination: destination) { [weak self] phase in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == token, self.isRunning, phase.fraction >= self.phase.fraction else { return }
                        self.phase = phase
                    }
                }
                guard let self, self.generation == token else { return }
                self.result = result; self.phase = .completed
                self.status = "已保存阅读版PDF（\(result.readingPDFReport?.pageCount ?? 0)页，\(result.byteCount)字节）。"
            } catch is CancellationError {
                guard let self, self.generation == token else { return }
                self.status = "导出已取消，未生成输出；可以手动重试。"
            } catch {
                guard let self, self.generation == token else { return }
                self.status = error.localizedDescription + " 可以重新选择位置后手动重试。"
            }
            guard let self, self.generation == token else { return }
            self.isRunning = false; self.task = nil
        }
    }
    public func cancel() { panel?.cancel(nil); task?.cancel() }
}

/// Embeddable component; its host owns presentation. No shared LibraryModel/LibraryWorkspace changes.
public struct DOCXReadingPDFExportWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: DOCXReadingPDFExportModel
    @State private var importing = false
    public init(source: URL? = nil) { _model = StateObject(wrappedValue: DOCXReadingPDFExportModel(source: source)) }
    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DOCX → 阅读版PDF").font(.title2.bold())
            Text("本机正文重新分页 · A4 · 48pt页边距 · 12pt正文 · 页码").font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("选择DOCX…") { importing = true }.disabled(model.isBusy).accessibilityIdentifier("reading-pdf-source")
                Text(model.source?.lastPathComponent ?? "尚未选择原件").textSelection(.enabled).lineLimit(2)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(DOCXReadingPDFSettings.lossWarnings, id: \.self) { Text($0).font(.callout).foregroundStyle(.secondary) }
                    if let report = model.result?.readingPDFReport {
                        Text("实际输出：\(report.pageCount)页／\(report.semanticBlockCount)正文块。").textSelection(.enabled)
                        Text("实际字体：" + report.fonts.joined(separator: ", ")).font(.caption).textSelection(.enabled)
                        Text("来源SHA-256：" + report.sourceSHA256).font(.caption).textSelection(.enabled)
                        ForEach(Array(report.semanticWarnings.enumerated()), id: \.offset) { _, warning in Text(warning).font(.caption) }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
            }.accessibilityIdentifier("reading-pdf-quality")
            if model.isRunning {
                ProgressView(model.phase.title, value: model.phase.fraction)
                Text("按阶段显示进度；取消在原子提交前清理暂存文件。").font(.caption).foregroundStyle(.secondary)
            }
            Text(model.status).textSelection(.enabled).accessibilityIdentifier("reading-pdf-status")
            if let result = model.result {
                Text(result.destination.path).font(.caption).textSelection(.enabled)
            }
            HStack {
                Button("选择保存位置并导出阅读版PDF…") { Task { await model.chooseDestinationAndStart() } }
                    .buttonStyle(.borderedProminent).disabled(model.source == nil || model.isBusy).accessibilityIdentifier("reading-pdf-export")
                if model.isRunning { Button("取消导出") { model.cancel() }.accessibilityIdentifier("reading-pdf-cancel") }
                Spacer()
                Button("完成") { dismiss() }.disabled(model.isBusy)
            }
        }.padding(24).frame(minWidth: 640, minHeight: 520)
            .interactiveDismissDisabled(model.isBusy).onDisappear { model.cancel() }
            .fileImporter(isPresented: $importing, allowedContentTypes: [UTType(filenameExtension: "docx") ?? .data]) { result in
                switch result { case .success(let url): model.select(url); case .failure(let error): model.importFailed(error) }
            }
    }
}
#endif
