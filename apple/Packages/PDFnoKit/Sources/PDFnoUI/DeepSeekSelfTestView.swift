// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoServices

enum DeepSeekAttemptOutcome: Equatable {
    case requesting, completed(String), failed(DeepSeekTestFailure)
}
struct DeepSeekAttemptRecord: Identifiable, Equatable {
    let id: UUID
    let number: Int
    var outcome: DeepSeekAttemptOutcome
}

@MainActor final class DeepSeekTestModel: ObservableObject {
    @Published var temporaryKey = ""
    @Published var confirmed = false
    @Published private(set) var attemptsUsed = 0
    @Published private(set) var busy = false
    @Published private(set) var result: String?
    @Published private(set) var error: String?
    @Published private(set) var status = "未发送 · 服务尚未验证"
    @Published private(set) var records: [DeepSeekAttemptRecord] = []
    private let service: DeepSeekSelfTest
    private let timeoutSeconds: TimeInterval
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var activeRecordID: UUID?
    init(service: DeepSeekSelfTest = DeepSeekSelfTest(), timeoutSeconds: TimeInterval = DeepSeekSelfTest.timeoutSeconds) {
        self.service = service; self.timeoutSeconds = timeoutSeconds
        Task { [weak self] in
            let used = await service.attemptsUsed()
            guard let self else { return }; attemptsUsed = max(attemptsUsed, used)
        }
    }
    var canSend: Bool { confirmed && CredentialValidation.valid(temporaryKey) && !busy && attemptsUsed < DeepSeekSelfTest.maxAttempts }
    func send() {
        guard canSend else { return }
        let key = temporaryKey
        temporaryKey = ""; confirmed = false; result = nil; error = nil
        generation = UUID(); let token = generation
        busy = true; attemptsUsed += 1
        let recordID = UUID(); activeRecordID = recordID
        records.append(DeepSeekAttemptRecord(id: recordID, number: attemptsUsed, outcome: .requesting))
        status = "第 \(attemptsUsed) 次正在测试 · 结果会显示在上方测试记录 · 无自动重试"
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await service.run(temporaryKey: key, confirmedScopeAndBudget: true, timeoutSeconds: timeoutSeconds)
                guard generation == token else { return }
                finishRecord(recordID, .completed(text))
                result = text; status = "第 \(attemptsUsed) 次收到完整服务响应 · 见上方测试记录"
            } catch {
                guard generation == token else { return }
                let failure = DeepSeekSelfTest.safeError(error)
                finishRecord(recordID, .failed(failure))
                self.error = failure.localizedDescription; status = "第 \(attemptsUsed) 次未成功 · 见上方错误记录"
            }
            let used = await service.attemptsUsed()
            guard generation == token else { return }
            attemptsUsed = max(attemptsUsed, used); busy = false; task = nil; activeRecordID = nil
        }
    }
    private func finishRecord(_ id: UUID, _ outcome: DeepSeekAttemptOutcome) {
        guard let index = records.firstIndex(where: { $0.id == id }), records[index].outcome == .requesting else { return }
        records[index].outcome = outcome
    }
    func close() {
        generation = UUID(); task?.cancel(); task = nil
        temporaryKey = ""; confirmed = false
        if busy, let id = activeRecordID {
            finishRecord(id, .failed(.cancelled)); result = nil; error = DeepSeekTestFailure.cancelled.localizedDescription
            status = "第 \(attemptsUsed) 次已取消 · 记录保留，服务商仍可能计费"
        }
        busy = false; activeRecordID = nil
        // Closing clears credentials, not diagnostic outcomes or the attempt cap.
    }
    func clearRecords() {
        guard !busy else { return }
        temporaryKey = ""; confirmed = false; result = nil; error = nil; records = []
        status = "已清除测试记录 · 已用次数保持 \(attemptsUsed) / 3"
    }
}

struct DeepSeekSelfTestView: View {
    @ObservedObject var model: DeepSeekTestModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pdfnoInlineDismiss) private var inlineDismiss
    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
            GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                Text(model.status).accessibilityIdentifier("deepseek-test-status").fixedSize(horizontal: false, vertical: true)
                GroupBox("测试记录 · 关闭窗口后仍保留到应用退出") {
                    VStack(alignment: .leading, spacing: 14) {
                        if model.records.isEmpty {
                            wrapped("尚无测试记录。每次发送的响应或错误会显示在这里；3 / 3 只表示次数用完，不表示测试成功。")
                        }
                        ForEach(model.records) { record in
                            VStack(alignment: .leading, spacing: 6) {
                                Text("第 \(record.number) 次").font(.headline)
                                switch record.outcome {
                                case .requesting: wrapped("正在等待服务响应 · 最多30秒，可取消")
                                case .completed(let text):
                                    Text("已收到完整服务响应").foregroundStyle(.green)
                                    Text(verbatim: text).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                        .accessibilityIdentifier("deepseek-test-result")
                                case .failed(let failure):
                                    Text(verbatim: failure.localizedDescription).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
                                        .accessibilityIdentifier("deepseek-test-error")
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading).id(record.id).accessibilityIdentifier("deepseek-attempt-\(record.number)")
                        }
                        if !model.records.isEmpty {
                            Button("清除测试记录（不重置次数）") { model.clearRecords() }.disabled(model.busy)
                                .accessibilityIdentifier("deepseek-clear-records")
                        }
                        wrapped("记录只在内存中，不保存密钥、请求或原始错误。完整响应只证明这次短句收到回应，不代表阅读 AI 已接入。")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }.id("test-records")
                GroupBox("固定服务与发送范围") {
                    VStack(alignment: .leading, spacing: 8) {
                    Text("DeepSeek 官方 API · deepseek-flash")
                    wrapped(DeepSeekSelfTest.endpoint + "/chat/completions").font(.caption)
                    wrapped("仅发送下面的原创短句与固定翻译指令；不发送书籍、选文、笔记或文件。")
                    wrapped(DeepSeekSelfTest.instruction).font(.caption)
                    wrapped(DeepSeekSelfTest.sentence).textSelection(.enabled)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("费用与次数") {
                    VStack(alignment: .leading, spacing: 8) {
                    wrapped("拟议预算 ≤1 元人民币；本次应用会话最多 3 次，每次输出最多 128 tokens，关闭思考模式。")
                    wrapped("客户端不能强制人民币账单上限。请先在服务商确认费用与余额；失败、超时或取消仍可能计费，均占一次，不自动重试。")
                    wrapped("已用 \(model.attemptsUsed) / 3 次；重开此窗口或清除记录不会重置次数。")
                    if model.attemptsUsed >= DeepSeekSelfTest.maxAttempts {
                        wrapped("三次额度已用完，发送已停用。请先查看上方每次记录；此版本不能恢复旧版已被清除的结果。")
                            .accessibilityIdentifier("deepseek-limit-message")
                    }
                    Toggle(isOn: $model.confirmed) { wrapped("我确认仅发送上方内容，并同意此费用范围") }
                        .disabled(model.busy || model.attemptsUsed >= DeepSeekSelfTest.maxAttempts).accessibilityIdentifier("deepseek-budget-consent")
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("由你手动输入并发送") {
                    VStack(alignment: .leading, spacing: 8) {
                    Text("新的临时 DeepSeek API key")
                    SecureField("在此手动输入", text: $model.temporaryKey)
                        .disabled(model.busy || model.attemptsUsed >= DeepSeekSelfTest.maxAttempts).accessibilityIdentifier("deepseek-temporary-key")
                    wrapped("密钥仅供本次请求，发送时清空输入框；不保存到文件或钥匙串，不从配置预览复制。请勿将真实密钥发到聊天中。")
                    Button("向 DeepSeek 发送一次短句测试") { model.send() }
                        .disabled(!model.canSend).accessibilityIdentifier("deepseek-user-send")
                    if model.busy { Button("取消请求（保留记录）") { model.close() }.accessibilityIdentifier("deepseek-cancel") }
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
                }.frame(width: max(0, geometry.size.width - 40), alignment: .leading).padding(20)
            }
            }.navigationTitle("DeepSeek 短句自助测试")
            .toolbar {
                ToolbarItem { Button("查看测试记录") { proxy.scrollTo(model.records.last?.id as AnyHashable? ?? AnyHashable("test-records"), anchor: .top) }.accessibilityIdentifier("deepseek-show-records") }
                ToolbarItem { Button("关闭（清除密钥，保留记录）") { model.close(); if let inlineDismiss { inlineDismiss() } else { dismiss() } }.accessibilityIdentifier("deepseek-close") }
            }
            .onChange(of: model.records) { _, records in
                if let last = records.last { withAnimation { proxy.scrollTo(last.id, anchor: .top) } }
            }
            }
        }.frame(minWidth: inlineDismiss == nil ? 560 : 0, minHeight: inlineDismiss == nil ? 620 : 0)
        .onDisappear { model.close() }
    }
    private func wrapped(_ text: String) -> some View {
        Text(verbatim: text).fixedSize(horizontal: false, vertical: true).frame(maxWidth: .infinity, alignment: .leading)
    }
}
#endif
