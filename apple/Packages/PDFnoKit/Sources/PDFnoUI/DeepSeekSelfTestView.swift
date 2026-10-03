// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
#if os(macOS)
import SwiftUI
import PDFnoDomain
import PDFnoServices

@MainActor final class DeepSeekTestModel: ObservableObject {
    @Published var temporaryKey = ""
    @Published var confirmed = false
    @Published private(set) var attemptsUsed = 0
    @Published private(set) var busy = false
    @Published private(set) var result: String?
    @Published private(set) var error: String?
    @Published private(set) var status = "未发送 · 服务尚未验证"
    private let service: DeepSeekSelfTest
    private var task: Task<Void, Never>?
    private var generation = UUID()
    init(service: DeepSeekSelfTest = DeepSeekSelfTest()) { self.service = service }
    var canSend: Bool { confirmed && CredentialValidation.valid(temporaryKey) && !busy && attemptsUsed < DeepSeekSelfTest.maxAttempts }
    func send() {
        guard canSend else { return }
        let key = temporaryKey
        temporaryKey = ""; confirmed = false; result = nil; error = nil
        generation = UUID(); let token = generation
        busy = true; attemptsUsed += 1; status = "正在测试 DeepSeek · 无自动重试"
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let text = try await service.run(temporaryKey: key, confirmedScopeAndBudget: true)
                guard generation == token else { return }
                result = text; status = "收到服务响应 · 仅本次短句，不代表阅读 AI 已接入"
            } catch {
                guard generation == token else { return }
                self.error = DeepSeekSelfTest.safeError(error).localizedDescription; status = "本次测试未完成"
            }
            let used = await service.attemptsUsed()
            guard generation == token else { return }
            attemptsUsed = used; busy = false; task = nil
        }
    }
    func clear() {
        generation = UUID(); task?.cancel(); task = nil
        busy = false; temporaryKey = ""; confirmed = false; result = nil; error = nil
        status = "已清除输入和结果 · 不会自动重试"
        // Keep the conservative attempt count across sheet close/reopen.
    }
}

struct DeepSeekSelfTestView: View {
    @ObservedObject var model: DeepSeekTestModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("固定服务与发送范围") {
                    Text("DeepSeek 官方 API · deepseek-flash")
                    Text(verbatim: DeepSeekSelfTest.endpoint + "/chat/completions").font(.caption)
                    Text("仅发送下面的原创短句与固定翻译指令；不发送书籍、选文、笔记或文件。")
                    Text(verbatim: DeepSeekSelfTest.instruction).font(.caption)
                    Text(verbatim: DeepSeekSelfTest.sentence).textSelection(.enabled)
                }
                Section("费用与次数") {
                    Text("拟议预算 ≤1 元人民币；本次应用会话最多 3 次，每次输出最多 128 tokens，关闭思考模式。")
                    Text("客户端不能强制人民币账单上限。请先在服务商确认费用与余额；失败、超时或取消仍可能计费，均占一次，不自动重试。")
                    Text("已提交 \(model.attemptsUsed) / 3 次；重开此窗口不会重置次数。")
                    Toggle("我确认仅发送上方内容，并同意此费用范围", isOn: $model.confirmed)
                        .disabled(model.busy).accessibilityIdentifier("deepseek-budget-consent")
                }
                Section("由你手动输入并发送") {
                    SecureField("新的临时 DeepSeek API key", text: $model.temporaryKey)
                        .disabled(model.busy).accessibilityIdentifier("deepseek-temporary-key")
                    Text("密钥仅供本次请求，发送时清空输入框；不保存到文件或钥匙串，不从配置预览复制。请勿将真实密钥发到聊天中。")
                    Button("向 DeepSeek 发送一次短句测试") { model.send() }
                        .disabled(!model.canSend).accessibilityIdentifier("deepseek-user-send")
                    if model.busy { Button("取消并清除") { model.clear() } }
                    Text(model.status).accessibilityIdentifier("deepseek-test-status")
                    if let error = model.error { Text(error).foregroundStyle(.red) }
                    if let result = model.result { Text(verbatim: result).textSelection(.enabled).accessibilityIdentifier("deepseek-test-result") }
                }
            }.padding().navigationTitle("DeepSeek 短句自助测试")
            .toolbar { ToolbarItem { Button("清除并关闭") { model.clear(); dismiss() } } }
        }.frame(minWidth: 580, minHeight: 680)
        .onDisappear { model.clear() }
    }
}
#endif
