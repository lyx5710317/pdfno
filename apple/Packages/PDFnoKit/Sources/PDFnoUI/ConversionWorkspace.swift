// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFnoDomain
import PDFnoServices

#if DEBUG
/// A checkpoint in an isolated UI fixture; still delegates successful work to the real local adapter.
private struct CancelableConversionUITestAdapter: DocumentConversionAdapter {
    var capabilities: [ConversionCapability] { DOCXTextConversionAdapter().capabilities }
    func convert(_ source: Data, to output: ConversionFormat, progress: @Sendable (ConversionPhase) -> Void) throws -> ConvertedDocument {
        progress(.converting)
        for _ in 0..<500 { try Task.checkCancellation(); Thread.sleep(forTimeInterval: 0.02) }
        return try DOCXTextConversionAdapter().convert(source, to: output, progress: progress)
    }
}
#endif
@MainActor
final class ConversionModel: ObservableObject {
    @Published var source: URL?
    @Published var output: ConversionFormat = .plainText
    @Published private(set) var isRunning = false
    @Published private(set) var choosingDestination = false
    @Published private(set) var phase: ConversionPhase = .reading
    @Published private(set) var result: ConversionResult?
    @Published private(set) var status = "选择 DOCX，再选择输出格式和保存位置。"
    private let service: DocumentConversionService
    let cancellationFixture: Bool
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var savePanel: NSSavePanel?
    var isBusy: Bool { isRunning || choosingDestination }

    init() {
        #if DEBUG
        if let token = ProcessInfo.processInfo.environment["PDFNO_UI_TEST_SESSION"], UUID(uuidString: token) != nil,
           ProcessInfo.processInfo.environment["PDFNO_UI_TEST_CONVERSION"] == "cancellation-checkpoint" {
            service = DocumentConversionService(adapters: [CancelableConversionUITestAdapter()]); cancellationFixture = true
        } else { service = DocumentConversionService(); cancellationFixture = false }
        #else
        service = DocumentConversionService(); cancellationFixture = false
        #endif
    }

    func select(_ url: URL) {
        guard !isBusy else { return }
        source = url; result = nil; status = "已选择原文件。转换只读取原件，输出使用新文件。"
    }
    func importFailed(_ error: Error) { status = error.localizedDescription }
    func chooseDestinationAndStart() async {
        guard let source, !isBusy else { return }
        choosingDestination = true
        let panel = NSSavePanel(); savePanel = panel
        panel.title = "导出 DOCX 正文副本"
        panel.message = "请选择新名称或位置。转换不会覆盖已有文件。"
        panel.allowedContentTypes = output == .plainText ? [.plainText] : [.html]
        panel.nameFieldStringValue = source.deletingPathExtension().lastPathComponent + "-converted." + output.fileExtension
        panel.canCreateDirectories = true; panel.isExtensionHidden = false
        let response = await withCheckedContinuation { continuation in panel.begin { continuation.resume(returning: $0) } }
        savePanel = nil; choosingDestination = false
        guard response == .OK, let destination = panel.url else { return }
        start(source: source, destination: destination, output: output)
    }
    func start(source: URL, destination: URL, output: ConversionFormat) {
        guard !isBusy else { return }
        let current = UUID(); generation = current
        isRunning = true; result = nil; phase = .reading; status = "正在后台转换…"
        let request = ConversionRequest(source: source, destination: destination, output: output)
        task = Task { [weak self, service] in
            do {
                let converted = try await service.convert(request) { [weak self] phase in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == current, self.isRunning,
                              phase.fraction >= self.phase.fraction else { return }
                        self.phase = phase
                    }
                }
                guard let self, self.generation == current else { return }
                self.result = converted; self.phase = .completed
                self.status = "已保存副本（\(converted.byteCount) 字节）。"
            } catch is CancellationError {
                guard let self, self.generation == current else { return }
                self.status = "转换已取消，未生成输出。可以重新选择位置再试。"
            } catch {
                guard let self, self.generation == current else { return }
                self.status = error.localizedDescription + " 可以重新选择位置再试。"
            }
            guard let self, self.generation == current else { return }
            self.isRunning = false; self.task = nil
        }
    }
    func cancel() { savePanel?.cancel(nil); task?.cancel() }
}

struct ConversionWorkspace: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model = ConversionModel()
    @State private var importer = false
    @State private var readingPDF = false
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("DOCX 正文转换").font(.title2.bold())
                Button("DOCX → 阅读版PDF（独立导出）") { readingPDF = true }
                    .disabled(model.isBusy).accessibilityIdentifier("reading-pdf-open")
                if model.cancellationFixture { Text("隔离自动测试：本地文件服务取消检查点").accessibilityIdentifier("conversion-fixture") }
                Text("本地导出 UTF-8 TXT 或简化 HTML，最多 20 MiB。转换结果是正文文字副本。").foregroundStyle(.secondary)
                HStack {
                    Button("选择 DOCX…") { importer = true }.disabled(model.isBusy).accessibilityIdentifier("conversion-source")
                    Text(model.source?.lastPathComponent ?? "尚未选择文件").lineLimit(2).textSelection(.enabled)
                }
                Picker("输出格式", selection: $model.output) {
                    Text(ConversionFormat.plainText.title).tag(ConversionFormat.plainText)
                    Text(ConversionFormat.html.title).tag(ConversionFormat.html)
                }.pickerStyle(.segmented).disabled(model.isBusy).accessibilityIdentifier("conversion-format")
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(ConversionWarning.allCases, id: \.rawValue) { Text($0.message).font(.callout).foregroundStyle(.secondary).accessibilityIdentifier("conversion-warning-" + $0.rawValue) }
                }
                if model.isRunning {
                    ProgressView(model.phase.title, value: model.phase.fraction)
                    Text("按转换阶段显示进度").font(.caption).foregroundStyle(.secondary)
                }
                Text(model.status).textSelection(.enabled).accessibilityIdentifier("conversion-status")
                    .id(model.status)
                if let result = model.result {
                    Text(result.destination.path).font(.caption).textSelection(.enabled)
                    Button("在 Finder 中显示") { NSWorkspace.shared.activateFileViewerSelecting([result.destination]) }
                }
                Spacer(minLength: 0)
                HStack {
                    Button("选择保存位置并转换…") { Task { await model.chooseDestinationAndStart() } }
                        .buttonStyle(.borderedProminent).disabled(model.source == nil || model.isBusy)
                        .accessibilityIdentifier("conversion-export")
                    if model.isRunning { Button("取消转换") { model.cancel() }.accessibilityIdentifier("conversion-cancel") }
                    Spacer()
                    Button("完成") { dismiss() }.disabled(model.isBusy).accessibilityIdentifier("conversion-close")
                }
            }.padding(24)
            .navigationTitle("格式转换")
        }
        .frame(minWidth: 560, minHeight: 440)
        .interactiveDismissDisabled(model.isBusy)
        .onDisappear { model.cancel() }
        .sheet(isPresented: $readingPDF) { DOCXReadingPDFExportWorkspace(source: model.source) }
        .fileImporter(isPresented: $importer, allowedContentTypes: [UTType(filenameExtension: "docx") ?? .data]) { result in
            switch result { case .success(let url): model.select(url); case .failure(let error): model.importFailed(error) }
        }
    }
}
#endif
