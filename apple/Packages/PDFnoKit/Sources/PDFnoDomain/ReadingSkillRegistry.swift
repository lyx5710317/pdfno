// Copyright (C) 2026 PDFno contributors. SPDX-License-Identifier: AGPL-3.0-or-later
import Foundation

public enum ReadingSkillID: String, Codable, Sendable, CaseIterable {
    case translateSelection = "pdfno.reading.translate-selection"
    case explainSelection = "pdfno.reading.explain-selection"
    case japaneseSelection = "pdfno.reading.japanese-selection"
    case englishSelection = "pdfno.reading.english-selection"
    case translatePDFPage = "pdfno.reading.translate-pdf-page"
    case translateEPUBSpine = "pdfno.reading.translate-epub-spine"
}
public enum ReadingSkillScope: String, Codable, Sendable {
    case selection, pdfPhysicalPage, epubCurrentSpine
    // Reserved scopes have no P0 adapter or implicit access grant.
    case explicitResourceRange, singleBookRetrieval
}
public enum ReadingSkillFormat: String, Codable, Sendable { case pdf, epub }
/// A declared task language, not automatic language detection or quality verification.
public enum ReadingSkillLanguage: String, Codable, Sendable, CaseIterable { case unspecified = "und", zh, zhHans = "zh-Hans", ja, en }
public enum ReadingSkillRouting: String, Codable, Sendable { case selectionAdapter, existingBatchHostOnly }
public enum ReadingSkillResultKind: String, Codable, Sendable { case selectionText, japaneseReview, englishReview }
public enum ReadingSkillBudgetPool: String, Codable, Sendable { case selection, pdfPage, epubSpine }
public struct ReadingSkillBudget: Codable, Sendable, Equatable {
    public let pool: ReadingSkillBudgetPool
    public let maxSessionAttempts: Int
    public let maxOutputTokensPerRequest: Int
    public let maxTimeoutSecondsPerRequest: Double
    public let maxResponseBytesPerRequest: Int
    public let automaticRetries: Int
    public init(pool: ReadingSkillBudgetPool, maxSessionAttempts: Int) {
        self.pool = pool; self.maxSessionAttempts = maxSessionAttempts
        maxOutputTokensPerRequest = DeepSeekSelectionPolicy.maxOutputTokens
        maxTimeoutSecondsPerRequest = 30; maxResponseBytesPerRequest = 65536; automaticRetries = 0
    }
}
public enum ReadingSkillParameterValue: Codable, Sendable, Equatable { case string(String), integer(Int), boolean(Bool) }
public struct ReadingSkillParameter: Codable, Sendable, Equatable {
    public let name: String
    public let allowedValues: [String]
    public let defaultValue: String
    public let maxUTF16: Int
    public init(name: String, allowedValues: [String], defaultValue: String, maxUTF16: Int) {
        self.name = name; self.allowedValues = allowedValues; self.defaultValue = defaultValue; self.maxUTF16 = maxUTF16
    }
}
public struct ReadingSkillResultContract: Codable, Sendable, Equatable {
    public let kind: ReadingSkillResultKind
    public let schemaVersion: Int
    public let validatorID: String
    public let validationVersion: Int
    public let promptVersions: [String]
    public init(kind: ReadingSkillResultKind, validatorID: String, promptVersions: [String], schemaVersion: Int = 1, validationVersion: Int = 1) {
        self.kind = kind; self.validatorID = validatorID; self.promptVersions = promptVersions
        self.schemaVersion = schemaVersion; self.validationVersion = validationVersion
    }
}
/// Read-only compiled descriptions. These values grant no IO, tool, save or budget authority.
/// Encodable is for inspection only; there is deliberately no manifest decoding/import path.
public struct ReadingSkillManifest: Encodable, Sendable, Equatable {
    public let skillID: String
    public let skillVersion: String
    public let manifestSchemaVersion: Int
    public let runtimeVersion: String
    public let title: String
    public let scope: ReadingSkillScope
    public let formats: [ReadingSkillFormat]
    public let sourceLanguages: [ReadingSkillLanguage]
    public let maxInputUTF16: Int
    /// Legacy text-only synthetic demonstrations retain their existing 8000-unit gate. No remote grant.
    public let maxMockInputUTF16: Int?
    public let maxSegments: Int
    public let parameters: [ReadingSkillParameter]
    public let result: ReadingSkillResultContract
    public let routing: ReadingSkillRouting
    public let budget: ReadingSkillBudget
    public let tools: [String]
    public let extraContext: [String]
    public let automaticSave: Bool
    public init(skillID: String, skillVersion: String = "1.0.0", manifestSchemaVersion: Int = 1, runtimeVersion: String = "1.0.0",
                title: String, scope: ReadingSkillScope, formats: [ReadingSkillFormat], sourceLanguages: [ReadingSkillLanguage],
                maxInputUTF16: Int, maxSegments: Int, parameters: [ReadingSkillParameter], result: ReadingSkillResultContract,
                routing: ReadingSkillRouting, budget: ReadingSkillBudget, maxMockInputUTF16: Int? = nil, tools: [String] = [], extraContext: [String] = [], automaticSave: Bool = false) {
        self.skillID = skillID; self.skillVersion = skillVersion; self.manifestSchemaVersion = manifestSchemaVersion
        self.runtimeVersion = runtimeVersion; self.title = title; self.scope = scope; self.formats = formats
        self.sourceLanguages = sourceLanguages; self.maxInputUTF16 = maxInputUTF16; self.maxSegments = maxSegments
        self.maxMockInputUTF16 = maxMockInputUTF16
        self.parameters = parameters; self.result = result; self.routing = routing; self.budget = budget
        self.tools = tools; self.extraContext = extraContext; self.automaticSave = automaticSave
    }
    public func resolveParameters(_ supplied: [String: ReadingSkillParameterValue]) throws -> [String: ReadingSkillParameterValue] {
        guard Set(supplied.keys).isSubset(of: Set(parameters.map(\.name))) else { throw ReadingSkillFailure.parameters }
        var values: [String: ReadingSkillParameterValue] = [:]
        for parameter in parameters {
            let value = supplied[parameter.name] ?? .string(parameter.defaultValue)
            guard case .string(let text) = value, text.utf16.count <= parameter.maxUTF16,
                  parameter.allowedValues.contains(where: { $0.utf8.elementsEqual(text.utf8) }) else { throw ReadingSkillFailure.parameters }
            values[parameter.name] = value
        }
        return values
    }
}
public enum ReadingSkillFailure: String, LocalizedError, Sendable {
    case unknownSkill, disabled, parameters, language, scope, input, capability, consent, staleSource, result
    public var errorDescription: String? {
        switch self {
        case .unknownSkill: "阅读 Skill 未注册。"
        case .disabled: "阅读 Skill 契约不兼容或存在重复身份，已禁用。"
        case .parameters: "参数未知、类型错误或超出已实现范围；本片目标语言仅支持简体中文。"
        case .language: "声明的来源语言与此阅读任务不匹配。"
        case .scope: "来源范围与阅读任务不匹配；页与 spine 仍由原批次入口执行。"
        case .input: "原文为空、来源无效或超过现有输入上限；不会截断原文。"
        case .capability: "当前服务没有此阅读任务的已实现适配。"
        case .consent: "来源、参数或服务计划改变，请重新确认本次范围。"
        case .staleSource: "来源或服务配置已改变，结果不能用于当前任务。"
        case .result: "结果类型、版本、来源或候选结构无法验证。"
        }
    }
}
public enum ReadingSkillDisabledReason: String, Sendable {
    case duplicateIdentity, manifestSchema, runtimeVersion, skillVersion, unknownSkill, missingValidator, unsupportedContract
}
public struct ReadingSkillRegistration: Sendable {
    public let manifest: ReadingSkillManifest
    public let disabledReason: ReadingSkillDisabledReason?
    public var isEnabled: Bool { disabledReason == nil }
}
public enum ReadingSkillProviderAvailability: Sendable, Equatable {
    case localSynthetic, boundedRemote, unavailable(AIFailure)
}
/// Finite registry: only exact compiled contracts can become enabled. Disabled originals are retained.
/// Neither a manifest nor a new registry allocates another AppAISession or creates a provider.
public struct ReadingSkillRegistry: Sendable {
    public static let runtimeVersion = "1.0.1"
    public static let builtin = ReadingSkillRegistry(manifests: compiledManifests)
    public let entries: [ReadingSkillRegistration]
    public init(manifests: [ReadingSkillManifest]) {
        let counts = Dictionary(grouping: manifests, by: \.skillID).mapValues(\.count)
        entries = manifests.map { manifest in
            var reason: ReadingSkillDisabledReason?
            if counts[manifest.skillID, default: 0] != 1 { reason = .duplicateIdentity }
            else if ![1, 2].contains(manifest.manifestSchemaVersion) { reason = .manifestSchema }
            else if manifest.runtimeVersion != Self.runtimeVersion { reason = .runtimeVersion }
            else if let reference = Self.compiledManifests.first(where: { $0.skillID == manifest.skillID }) {
                if reference.manifestSchemaVersion != manifest.manifestSchemaVersion { reason = .manifestSchema }
                else if reference.skillVersion != manifest.skillVersion { reason = .skillVersion }
                else if reference.result != manifest.result { reason = .missingValidator }
                // Compare encoded bytes: String equality canonically equates different Unicode spelling.
                else if (try? ReadingSkillIdentity.data(reference)) != (try? ReadingSkillIdentity.data(manifest)) { reason = .unsupportedContract }
            } else { reason = .unknownSkill }
            return ReadingSkillRegistration(manifest: manifest, disabledReason: reason)
        }
    }
    public func manifest(for id: ReadingSkillID) throws -> ReadingSkillManifest {
        guard let entry = entries.first(where: { $0.manifest.skillID == id.rawValue }) else { throw ReadingSkillFailure.unknownSkill }
        guard entry.isEnabled else { throw ReadingSkillFailure.disabled }; return entry.manifest
    }
    public func availability(for id: ReadingSkillID, provider: AIProviderConfig) -> ReadingSkillProviderAvailability {
        guard let manifest = try? manifest(for: id) else { return .unavailable(.configuration) }
        guard provider.isValid else { return .unavailable(.configuration) }
        if provider.mode == .unconfigured { return .unavailable(.unconfigured) }
        if provider.mode == .mock { return manifest.routing == .selectionAdapter ? .localSynthetic : .unavailable(.configuration) }
        if id == .translateSelection || id == .explainSelection {
            return (try? BYOKSelectionPolicy.finalURL(provider)) != nil ? .boundedRemote : .unavailable(.configuration)
        }
        return DeepSeekSelectionPolicy.supports(provider) ? .boundedRemote : .unavailable(.configuration)
    }
    private static var compiledManifests: [ReadingSkillManifest] {
        let parameter = ReadingSkillParameter(name: "targetLanguage", allowedValues: ["zh-Hans"], defaultValue: "zh-Hans", maxUTF16: 7)
        return ReadingSkillID.allCases.map { id in
            let scope: ReadingSkillScope, formats: [ReadingSkillFormat], languages: [ReadingSkillLanguage]
            let title: String, result: ReadingSkillResultContract, pool: ReadingSkillBudgetPool
            switch id {
            case .translateSelection, .explainSelection:
                scope = .selection; formats = [.pdf, .epub]; languages = ReadingSkillLanguage.allCases; pool = .selection
                title = id == .translateSelection ? "选文翻译" : "选文简短解释"
                result = .init(kind: .selectionText, validatorID: "legacy-selection-text-1", promptVersions: ["selection-1", DeepSeekSelectionPolicy.promptVersion])
            case .japaneseSelection:
                scope = .selection; formats = [.pdf, .epub]; languages = [.ja]; pool = .selection; title = "日语选文学习"
                result = .init(kind: .japaneseReview, validatorID: "japanese-learning-2", promptVersions: [JapaneseLearningPolicy.promptVersion], validationVersion: 2)
            case .englishSelection:
                scope = .selection; formats = [.pdf, .epub]; languages = [.en]; pool = .selection; title = "英语选文学习"
                result = .init(kind: .englishReview, validatorID: "english-learning-1", promptVersions: [EnglishLearningPolicy.promptVersion], validationVersion: 2)
            case .translatePDFPage:
                scope = .pdfPhysicalPage; formats = [.pdf]; languages = ReadingSkillLanguage.allCases; pool = .pdfPage; title = "PDF 完整物理页翻译"
                result = .init(kind: .selectionText, validatorID: "legacy-selection-text-1", promptVersions: [PDFPageTranslationPolicy.promptVersion])
            case .translateEPUBSpine:
                scope = .epubCurrentSpine; formats = [.epub]; languages = ReadingSkillLanguage.allCases; pool = .epubSpine; title = "EPUB 当前 spine 文档翻译"
                result = .init(kind: .selectionText, validatorID: "legacy-selection-text-1", promptVersions: [EPUBChapterTranslationPolicy.promptVersion])
            }
            let batch = scope != .selection
            let legacyTextMock = id == .translateSelection || id == .explainSelection
            return ReadingSkillManifest(skillID: id.rawValue, skillVersion: batch ? "1.0.0" : "1.0.1",
                manifestSchemaVersion: legacyTextMock ? 2 : 1, runtimeVersion: runtimeVersion, title: title, scope: scope, formats: formats, sourceLanguages: languages,
                maxInputUTF16: batch ? 3000 : DeepSeekSelectionPolicy.maxSourceUTF16, maxSegments: batch ? 6 : 1,
                parameters: [parameter], result: result, routing: batch ? .existingBatchHostOnly : .selectionAdapter,
                budget: .init(pool: pool, maxSessionAttempts: batch ? 6 : DeepSeekSelectionPolicy.maxAttempts),
                maxMockInputUTF16: legacyTextMock ? 8000 : nil)
        }
    }
}
/// Exact sorted JSON identity shared by offline plans, provenance and adapter binding.
public enum ReadingSkillIdentity {
    public static func data<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; return try encoder.encode(value)
    }
}
