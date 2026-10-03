// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation
import Testing
import PDFnoServices
@testable import PDFnoUI

private let syntheticKey = "synthetic-probe-credential"
private let syntheticReply = Data("{\"choices\":[{\"finish_reason\":\"stop\",\"message\":{\"role\":\"assistant\",\"content\":\"离线短句回应\",\"tool_calls\":null}}]}".utf8)
private actor ProbeTransport: AIHTTPTransport {
    let response: AIHTTPResponse
    private(set) var requests: [URLRequest] = []
    init(status: Int = 200, body: Data = syntheticReply) { response = AIHTTPResponse(status: status, body: body) }
    func send(_ request: URLRequest) -> AIHTTPResponse { requests.append(request); return response }
}
private actor DeferredProbeTransport: AIHTTPTransport {
    private var continuation: CheckedContinuation<AIHTTPResponse, Error>?
    func send(_ request: URLRequest) async throws -> AIHTTPResponse {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }
    func started() -> Bool { continuation != nil }
    func finish() { continuation?.resume(returning: AIHTTPResponse(status: 200, body: syntheticReply)); continuation = nil }
}
private final class ProbeRequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var captured: URLRequest?
    func save(_ request: URLRequest) { lock.lock(); defer { lock.unlock() }; captured = request }
    func read() -> URLRequest? { lock.lock(); defer { lock.unlock() }; return captured }
}
private final class OfflineProbeURLProtocol: URLProtocol, @unchecked Sendable {
    static let capture = ProbeRequestCapture()
    override class func canInit(with request: URLRequest) -> Bool { true } // No URL can escape to the network.
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.capture.save(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: syntheticReply); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

struct DeepSeekSelfTestTests {
    @Test func consentAndCredentialValidationPrecedeAnySubmission() async throws {
        let transport = ProbeTransport(), service = DeepSeekSelfTest(transport: transport)
        await #expect(throws: DeepSeekTestFailure.consent) { try await service.run(temporaryKey: syntheticKey, confirmedScopeAndBudget: false) }
        for invalid in ["", "synthetic\r\nheader", "synthetic space"] {
            await #expect(throws: DeepSeekTestFailure.credentials) { try await service.run(temporaryKey: invalid, confirmedScopeAndBudget: true) }
        }
        #expect(await service.attemptsUsed() == 0)
        #expect(await transport.requests.isEmpty)
    }
    @Test func fixedOfficialHostModelAndBooklessJSONWithFakeAuthorization() async throws {
        let transport = ProbeTransport(), service = DeepSeekSelfTest(transport: transport)
        #expect(try await service.run(temporaryKey: syntheticKey, confirmedScopeAndBudget: true) == "离线短句回应")
        let request = try #require(await transport.requests.first)
        #expect(request.url?.absoluteString == "https://api.deepseek.com/chat/completions")
        #expect(request.httpMethod == "POST" && request.timeoutInterval == 30 && !request.httpShouldHandleCookies)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer " + syntheticKey)
        let body = try #require(request.httpBody)
        let json = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(Set(json.keys) == Set(["model", "stream", "max_tokens", "thinking", "messages"]))
        #expect(json["model"] as? String == "deepseek-flash" && json["stream"] as? Bool == false && json["max_tokens"] as? Int == 128)
        #expect((json["thinking"] as? [String: String]) == ["type": "disabled"])
        #expect((json["messages"] as? [[String: String]]) == [
            ["role": "system", "content": DeepSeekSelfTest.instruction], ["role": "user", "content": DeepSeekSelfTest.sentence]
        ])
        #expect(!String(decoding: body, as: UTF8.self).contains(syntheticKey))
    }
    @Test func threeAttemptsIncludingFailuresAndNoAutomaticRetries() async throws {
        let transport = ProbeTransport(status: 429, body: Data("sensitive-synthetic-body".utf8)), service = DeepSeekSelfTest(transport: transport)
        for _ in 0..<3 {
            await #expect(throws: DeepSeekTestFailure.rateLimit) { try await service.run(temporaryKey: syntheticKey, confirmedScopeAndBudget: true) }
        }
        await #expect(throws: DeepSeekTestFailure.limit) { try await service.run(temporaryKey: syntheticKey, confirmedScopeAndBudget: true) }
        #expect(await service.attemptsUsed() == 3)
        #expect(await transport.requests.count == 3)
    }
    @Test func HTTPAndInvalidResponsesProduceOnlySafeErrors() async throws {
        for (status, expected) in [(301,DeepSeekTestFailure.redirect),(401,.authentication),(403,.authentication),(402,.quota),(429,.rateLimit),(500,.server)] {
            let transport = ProbeTransport(status: status, body: Data("sensitive-synthetic-body".utf8))
            await #expect(throws: expected) { try await DeepSeekSelfTest(transport: transport).run(temporaryKey: syntheticKey, confirmedScopeAndBudget: true) }
            #expect(!expected.localizedDescription.contains("sensitive-synthetic-body") && !expected.localizedDescription.contains(syntheticKey))
            #expect(await transport.requests.count == 1)
        }
        let invalidBodies = [Data("invalid synthetic JSON".utf8), Data(repeating: 65, count: 65537),
            Data("{\"choices\":[{\"finish_reason\":\"length\",\"message\":{\"role\":\"assistant\",\"content\":\"partial\"}}]}".utf8),
            Data("{\"choices\":[{\"finish_reason\":\"stop\",\"message\":{\"role\":\"assistant\",\"content\":\"text\",\"tool_calls\":[{}]}}]}".utf8)]
        for body in invalidBodies {
            await #expect(throws: DeepSeekTestFailure.output) { try await DeepSeekSelfTest(transport: ProbeTransport(body: body)).run(temporaryKey: syntheticKey, confirmedScopeAndBudget: true) }
        }
        #expect(DeepSeekSelfTest.safeError(URLError(.timedOut)) == .timeout)
        #expect(DeepSeekSelfTest.safeError(URLError(.cancelled)) == .cancelled)
        #expect(DeepSeekSelfTest.safeError(NSError(domain: "synthetic-sensitive-error", code: 1)) == .network)
    }
    @Test func cancellationAndTimeoutIgnoreUncooperativeLateResponse() async throws {
        for timedOut in [false, true] {
            let transport = DeferredProbeTransport(), service = DeepSeekSelfTest(transport: transport)
            let task = Task { try await service.run(temporaryKey: syntheticKey, confirmedScopeAndBudget: true, timeoutSeconds: timedOut ? 0.1 : 30) }
            let deadline = Date().addingTimeInterval(2)
            while !(await transport.started()), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
            #expect(await transport.started())
            await #expect(throws: DeepSeekTestFailure.busy) { try await service.run(temporaryKey: syntheticKey, confirmedScopeAndBudget: true) }
            if !timedOut { task.cancel() }
            do { _ = try await task.value; Issue.record("A cancelled or expired probe returned a result") }
            catch { #expect(error as? DeepSeekTestFailure == (timedOut ? .timeout : .cancelled)) }
            #expect(await service.attemptsUsed() == 1)
            await transport.finish()
        }
    }
    @Test func URLSessionProbeInterceptedOfflineAndCrossHostRedirectNeverForwarded() async throws {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [OfflineProbeURLProtocol.self]
        let service = DeepSeekSelfTest(transport: URLSessionAITransport(configuration: config))
        #expect(try await service.run(temporaryKey: syntheticKey, confirmedScopeAndBudget: true) == "离线短句回应")
        #expect(OfflineProbeURLProtocol.capture.read()?.value(forHTTPHeaderField: "Authorization") == "Bearer " + syntheticKey)
        let session = URLSession(configuration: config); defer { session.invalidateAndCancel() }
        let request = URLRequest(url: URL(string: "https://api.deepseek.com/chat/completions")!)
        let task = session.dataTask(with: request) // Never resumed, even though URLProtocol intercepts all URLs.
        let response = HTTPURLResponse(url: request.url!, statusCode: 302, httpVersion: nil, headerFields: [:])!
        var redirected = URLRequest(url: URL(string: "https://other.invalid/collect")!)
        redirected.setValue("Bearer " + syntheticKey, forHTTPHeaderField: "Authorization")
        RejectAIRedirects().urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: redirected) { forwarded in #expect(forwarded == nil) }
    }
    @Test @MainActor func nativeModelRequiresManualConsentClearsKeyAndIgnoresClosedResult() async throws {
        let transport = ProbeTransport(), model = DeepSeekTestModel(service: DeepSeekSelfTest(transport: transport))
        model.temporaryKey = syntheticKey; model.send()
        #expect(!model.busy && !model.canSend && model.attemptsUsed == 0)
        model.confirmed = true; model.send()
        #expect(model.temporaryKey.isEmpty && !model.confirmed)
        let deadline = Date().addingTimeInterval(2)
        while model.busy, Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        #expect(model.result == "离线短句回应" && model.attemptsUsed == 1)
        model.clear(); #expect(model.result == nil && model.temporaryKey.isEmpty && model.attemptsUsed == 1)
        let deferred = DeferredProbeTransport(), closed = DeepSeekTestModel(service: DeepSeekSelfTest(transport: deferred))
        closed.temporaryKey = syntheticKey; closed.confirmed = true; closed.send()
        while !(await deferred.started()), Date() < deadline { try await Task.sleep(for: .milliseconds(10)) }
        closed.clear(); await deferred.finish(); try await Task.sleep(for: .milliseconds(20))
        #expect(closed.result == nil && !closed.busy && closed.temporaryKey.isEmpty && closed.attemptsUsed == 1)
    }
}
