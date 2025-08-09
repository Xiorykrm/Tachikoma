//
//  ModelCapabilities.swift
//  Tachikoma
//

import Foundation

// MARK: - Model Parameter Capabilities

/// Defines complete capabilities of a model including parameter support and provider options
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ModelParameterCapabilities: Sendable {
    // MARK: Universal Parameter Support
    public var supportsTemperature: Bool = true
    public var supportsTopP: Bool = true
    public var supportsTopK: Bool = false
    public var supportsMaxTokens: Bool = true
    public var supportsStopSequences: Bool = true
    public var supportsFrequencyPenalty: Bool = true
    public var supportsPresencePenalty: Bool = true
    public var supportsSeed: Bool = false
    
    // MARK: Parameter Constraints
    public var temperatureRange: ClosedRange<Double>? = 0...2
    public var maxTokenLimit: Int? = nil
    
    // MARK: Provider-Specific Capabilities
    public var supportedProviderOptions: SupportedProviderOptions = .init()
    
    // MARK: Special Behaviors
    /// Parameters that are forced to specific values (e.g., O1 forces temperature=1)
    public var forcedTemperature: Double? = nil
    
    /// Parameters that should be excluded entirely (e.g., GPT-5 excludes temperature)
    public var excludedParameters: Set<String> = []
    
    public init(
        supportsTemperature: Bool = true,
        supportsTopP: Bool = true,
        supportsTopK: Bool = false,
        supportsMaxTokens: Bool = true,
        supportsStopSequences: Bool = true,
        supportsFrequencyPenalty: Bool = true,
        supportsPresencePenalty: Bool = true,
        supportsSeed: Bool = false,
        temperatureRange: ClosedRange<Double>? = 0...2,
        maxTokenLimit: Int? = nil,
        supportedProviderOptions: SupportedProviderOptions = .init(),
        forcedTemperature: Double? = nil,
        excludedParameters: Set<String> = []
    ) {
        self.supportsTemperature = supportsTemperature
        self.supportsTopP = supportsTopP
        self.supportsTopK = supportsTopK
        self.supportsMaxTokens = supportsMaxTokens
        self.supportsStopSequences = supportsStopSequences
        self.supportsFrequencyPenalty = supportsFrequencyPenalty
        self.supportsPresencePenalty = supportsPresencePenalty
        self.supportsSeed = supportsSeed
        self.temperatureRange = temperatureRange
        self.maxTokenLimit = maxTokenLimit
        self.supportedProviderOptions = supportedProviderOptions
        self.forcedTemperature = forcedTemperature
        self.excludedParameters = excludedParameters
    }
}

// MARK: - Supported Provider Options

/// Defines which provider-specific options a model supports
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct SupportedProviderOptions: Sendable {
    // MARK: OpenAI Options
    public var supportsParallelToolCalls: Bool = false
    public var supportsResponseFormat: Bool = false
    public var supportsVerbosity: Bool = false
    public var supportsReasoningEffort: Bool = false
    public var supportsPreviousResponseId: Bool = false
    public var supportsLogprobs: Bool = false
    
    // MARK: Anthropic Options
    public var supportsThinking: Bool = false
    public var supportsCacheControl: Bool = false
    
    // MARK: Google Options
    public var supportsThinkingConfig: Bool = false
    public var supportsSafetySettings: Bool = false
    
    // MARK: Mistral Options
    public var supportsSafeMode: Bool = false
    
    // MARK: Groq Options
    public var supportsSpeedLevel: Bool = false
    
    // MARK: Grok Options
    public var supportsFunMode: Bool = false
    public var supportsCurrentEvents: Bool = false
    
    public init(
        supportsParallelToolCalls: Bool = false,
        supportsResponseFormat: Bool = false,
        supportsVerbosity: Bool = false,
        supportsReasoningEffort: Bool = false,
        supportsPreviousResponseId: Bool = false,
        supportsLogprobs: Bool = false,
        supportsThinking: Bool = false,
        supportsCacheControl: Bool = false,
        supportsThinkingConfig: Bool = false,
        supportsSafetySettings: Bool = false,
        supportsSafeMode: Bool = false,
        supportsSpeedLevel: Bool = false,
        supportsFunMode: Bool = false,
        supportsCurrentEvents: Bool = false
    ) {
        self.supportsParallelToolCalls = supportsParallelToolCalls
        self.supportsResponseFormat = supportsResponseFormat
        self.supportsVerbosity = supportsVerbosity
        self.supportsReasoningEffort = supportsReasoningEffort
        self.supportsPreviousResponseId = supportsPreviousResponseId
        self.supportsLogprobs = supportsLogprobs
        self.supportsThinking = supportsThinking
        self.supportsCacheControl = supportsCacheControl
        self.supportsThinkingConfig = supportsThinkingConfig
        self.supportsSafetySettings = supportsSafetySettings
        self.supportsSafeMode = supportsSafeMode
        self.supportsSpeedLevel = supportsSpeedLevel
        self.supportsFunMode = supportsFunMode
        self.supportsCurrentEvents = supportsCurrentEvents
    }
}

// MARK: - Model Capability Registry

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class ModelCapabilityRegistry: @unchecked Sendable {
    public static let shared = ModelCapabilityRegistry()
    
    private var capabilities: [String: ModelParameterCapabilities] = [:]
    private let lock = NSLock()
    
    private init() {
        registerDefaultCapabilities()
    }
    
    /// Get capabilities for a model
    public func capabilities(for model: LanguageModel) -> ModelParameterCapabilities {
        let key = capabilityKey(for: model)
        
        lock.lock()
        defer { lock.unlock() }
        
        // Check for registered capabilities
        if let registered = capabilities[key] {
            return registered
        }
        
        // Return default based on model type
        return defaultCapabilities(for: model)
    }
    
    /// Register custom capabilities for a model
    public func register(_ capabilities: ModelParameterCapabilities, for model: LanguageModel) {
        let key = capabilityKey(for: model)
        
        lock.lock()
        defer { lock.unlock() }
        
        self.capabilities[key] = capabilities
    }
    
    /// Register capabilities for an OpenAI-compatible endpoint
    public func registerOpenAICompatible(endpoint: String, capabilities: ModelParameterCapabilities) {
        let key = "openai-compatible:\(endpoint):default"
        
        lock.lock()
        defer { lock.unlock() }
        
        self.capabilities[key] = capabilities
    }
    
    // MARK: - Private Helpers
    
    private func capabilityKey(for model: LanguageModel) -> String {
        switch model {
        case .openai(let submodel):
            return "openai:\(submodel.modelId)"
        case .anthropic(let submodel):
            return "anthropic:\(submodel.modelId)"
        case .google(let submodel):
            return "google:\(submodel.rawValue)"
        case .mistral(let submodel):
            return "mistral:\(submodel.rawValue)"
        case .groq(let submodel):
            return "groq:\(submodel.rawValue)"
        case .grok(let submodel):
            return "grok:\(submodel.modelId)"
        case .ollama(let submodel):
            return "ollama:\(submodel.modelId)"
        case .lmstudio(let submodel):
            return "lmstudio:\(submodel.modelId)"
        case .openRouter(let modelId):
            return "openrouter:\(modelId)"
        case .together(let modelId):
            return "together:\(modelId)"
        case .replicate(let modelId):
            return "replicate:\(modelId)"
        case .openaiCompatible(let endpoint, let modelId):
            return "openai-compatible:\(endpoint):\(modelId)"
        case .anthropicCompatible(let endpoint, let modelId):
            return "anthropic-compatible:\(endpoint):\(modelId)"
        case .custom(let provider):
            return "custom:\(provider.modelId)"
        }
    }
    
    private func registerDefaultCapabilities() {
        // GPT-5 Series (Responses API only, no temperature/topP)
        let gpt5Capabilities = ModelParameterCapabilities(
            supportsTemperature: false,
            supportsTopP: false,
            supportsFrequencyPenalty: false,
            supportsPresencePenalty: false,
            supportedProviderOptions: .init(
                supportsVerbosity: true,
                supportsPreviousResponseId: true
            ),
            excludedParameters: ["temperature", "topP", "frequencyPenalty", "presencePenalty"]
        )
        
        capabilities["openai:gpt-5"] = gpt5Capabilities
        capabilities["openai:gpt-5-mini"] = gpt5Capabilities
        capabilities["openai:gpt-5-nano"] = gpt5Capabilities
        
        // O3/O4 Series (Reasoning models with fixed temperature)
        let reasoningCapabilities = ModelParameterCapabilities(
            supportsTemperature: false,
            supportsTopP: false,
            supportedProviderOptions: .init(
                supportsReasoningEffort: true,
                supportsPreviousResponseId: true
            ),
            forcedTemperature: 1.0,
            excludedParameters: ["temperature", "topP"]
        )
        
        capabilities["openai:o3"] = reasoningCapabilities
        capabilities["openai:o3-mini"] = reasoningCapabilities
        capabilities["openai:o3-pro"] = reasoningCapabilities
        capabilities["openai:o4"] = reasoningCapabilities
        capabilities["openai:o4-mini"] = reasoningCapabilities
        
        // O1 Series (Earlier reasoning models)
        let o1Capabilities = ModelParameterCapabilities(
            supportsTemperature: false,
            supportsTopP: false,
            supportsFrequencyPenalty: false,
            supportsPresencePenalty: false,
            forcedTemperature: 1.0,
            excludedParameters: ["temperature", "topP", "frequencyPenalty", "presencePenalty"]
        )
        
        // O1 models were renamed to O3 in the API
        // Keep the capabilities registered for backward compatibility
        capabilities["openai:o1-preview"] = o1Capabilities
        capabilities["openai:o1-mini"] = o1Capabilities
        
        // Standard GPT-4 models
        let gpt4Capabilities = ModelParameterCapabilities(
            supportedProviderOptions: .init(
                supportsParallelToolCalls: true,
                supportsResponseFormat: true,
                supportsLogprobs: true
            )
        )
        
        capabilities["openai:gpt-4o"] = gpt4Capabilities
        capabilities["openai:gpt-4o-mini"] = gpt4Capabilities
        capabilities["openai:gpt-4.1"] = gpt4Capabilities
        capabilities["openai:gpt-4.1-mini"] = gpt4Capabilities
        capabilities["openai:gpt-4-turbo"] = gpt4Capabilities
        
        // Claude 4 models with thinking
        let claude4Capabilities = ModelParameterCapabilities(
            supportedProviderOptions: .init(
                supportsThinking: true,
                supportsCacheControl: true
            )
        )
        
        capabilities["anthropic:claude-opus-4-1-20250805"] = claude4Capabilities
        capabilities["anthropic:claude-sonnet-4-20250514"] = claude4Capabilities
        
        // Claude 3.7 with thinking
        let claude37Capabilities = ModelParameterCapabilities(
            supportedProviderOptions: .init(
                supportsThinking: true,
                supportsCacheControl: true
            )
        )
        
        capabilities["anthropic:claude-3-7-sonnet"] = claude37Capabilities
        
        // Google Gemini with thinking
        let geminiCapabilities = ModelParameterCapabilities(
            supportsTopK: true,
            supportedProviderOptions: .init(
                supportsThinkingConfig: true,
                supportsSafetySettings: true
            )
        )
        
        capabilities["google:gemini-2.0-flash"] = geminiCapabilities
        capabilities["google:gemini-2.0-flash-thinking"] = geminiCapabilities
        capabilities["google:gemini-1.5-pro"] = geminiCapabilities
        capabilities["google:gemini-1.5-flash"] = geminiCapabilities
        capabilities["google:gemini-1.5-flash-8b"] = geminiCapabilities
        capabilities["google:gemini-pro"] = geminiCapabilities
        capabilities["google:gemini-pro-vision"] = geminiCapabilities
        
        // Mistral models
        let mistralCapabilities = ModelParameterCapabilities(
            supportedProviderOptions: .init(
                supportsSafeMode: true
            )
        )
        
        capabilities["mistral:mistral-large-2"] = mistralCapabilities
        capabilities["mistral:codestral"] = mistralCapabilities
        
        // Groq models (ultra-fast inference)
        let groqCapabilities = ModelParameterCapabilities(
            supportedProviderOptions: .init(
                supportsSpeedLevel: true
            )
        )
        
        capabilities["groq:llama-3.1-70b"] = groqCapabilities
        capabilities["groq:llama-3.1-8b"] = groqCapabilities
        capabilities["groq:llama-3-70b"] = groqCapabilities
        capabilities["groq:llama-3-8b"] = groqCapabilities
        capabilities["groq:mixtral-8x7b"] = groqCapabilities
        capabilities["groq:gemma2-9b"] = groqCapabilities
        
        // Grok models
        let grokCapabilities = ModelParameterCapabilities(
            supportedProviderOptions: .init(
                supportsFunMode: true,
                supportsCurrentEvents: true
            )
        )
        
        capabilities["grok:grok-4-0709"] = grokCapabilities
        capabilities["grok:grok-3"] = grokCapabilities
    }
    
    private func defaultCapabilities(for model: LanguageModel) -> ModelParameterCapabilities {
        // Check if we have registered capabilities for this specific model
        let key = capabilityKey(for: model)
        if let registered = capabilities[key] {
            return registered
        }
        
        // Return provider-based defaults
        switch model {
        case .openai:
            // Default OpenAI capabilities
            return ModelParameterCapabilities()
            
        case .anthropic:
            // Default Anthropic capabilities
            return ModelParameterCapabilities(
                supportedProviderOptions: .init(
                    supportsCacheControl: true
                )
            )
            
        case .google:
            // Default Google capabilities
            return ModelParameterCapabilities(
                supportsTopK: true,
                supportedProviderOptions: .init(
                    supportsSafetySettings: true
                )
            )
            
        case .ollama, .lmstudio:
            // Local models - basic capabilities
            return ModelParameterCapabilities(
                supportsSeed: true
            )
            
        default:
            // Default capabilities for unknown models
            return ModelParameterCapabilities()
        }
    }
}

// MARK: - GenerationSettings Extension

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension GenerationSettings {
    /// Validates and adjusts settings based on model capabilities
    public func validated(for model: LanguageModel) -> GenerationSettings {
        let capabilities = ModelCapabilityRegistry.shared.capabilities(for: model)
        
        var adjustedTemperature = temperature
        var adjustedTopP = topP
        var adjustedFrequencyPenalty = frequencyPenalty
        var adjustedPresencePenalty = presencePenalty
        var adjustedProviderOptions = providerOptions
        
        // Handle excluded parameters
        if capabilities.excludedParameters.contains("temperature") {
            adjustedTemperature = nil
        }
        if capabilities.excludedParameters.contains("topP") {
            adjustedTopP = nil
        }
        if capabilities.excludedParameters.contains("frequencyPenalty") {
            adjustedFrequencyPenalty = nil
        }
        if capabilities.excludedParameters.contains("presencePenalty") {
            adjustedPresencePenalty = nil
        }
        
        // Apply forced temperature
        if let forcedTemp = capabilities.forcedTemperature {
            adjustedTemperature = forcedTemp
        }
        
        // Validate provider options
        adjustedProviderOptions = validateProviderOptions(
            adjustedProviderOptions,
            capabilities: capabilities,
            model: model
        )
        
        return GenerationSettings(
            maxTokens: maxTokens,
            temperature: adjustedTemperature,
            topP: adjustedTopP,
            topK: topK,
            frequencyPenalty: adjustedFrequencyPenalty,
            presencePenalty: adjustedPresencePenalty,
            stopSequences: stopSequences,
            reasoningEffort: reasoningEffort,
            stopConditions: stopConditions,
            seed: seed,
            providerOptions: adjustedProviderOptions
        )
    }
    
    private func validateProviderOptions(
        _ options: ProviderOptions,
        capabilities: ModelParameterCapabilities,
        model: LanguageModel
    ) -> ProviderOptions {
        var validated = options
        let supported = capabilities.supportedProviderOptions
        
        // Only validate options for the current provider
        // Other provider options are kept as-is for flexibility
        
        // Validate OpenAI options only for OpenAI models
        if case .openai = model, let openaiOpts = options.openai {
            var validatedOpenAI = openaiOpts
            
            if !supported.supportsVerbosity {
                validatedOpenAI.verbosity = nil
            }
            if !supported.supportsReasoningEffort {
                validatedOpenAI.reasoningEffort = nil
            }
            if !supported.supportsParallelToolCalls {
                validatedOpenAI.parallelToolCalls = nil
            }
            if !supported.supportsResponseFormat {
                validatedOpenAI.responseFormat = nil
            }
            if !supported.supportsPreviousResponseId {
                validatedOpenAI.previousResponseId = nil
            }
            if !supported.supportsLogprobs {
                validatedOpenAI.logprobs = nil
                validatedOpenAI.topLogprobs = nil
            }
            
            validated.openai = validatedOpenAI
        }
        
        // Validate Anthropic options only for Anthropic models
        if case .anthropic = model, let anthropicOpts = options.anthropic {
            var validatedAnthropic = anthropicOpts
            
            if !supported.supportsThinking {
                validatedAnthropic.thinking = nil
            }
            if !supported.supportsCacheControl {
                validatedAnthropic.cacheControl = nil
            }
            
            validated.anthropic = validatedAnthropic
        }
        
        // Validate Google options only for Google models
        if case .google = model, let googleOpts = options.google {
            var validatedGoogle = googleOpts
            
            if !supported.supportsThinkingConfig {
                validatedGoogle.thinkingConfig = nil
            }
            if !supported.supportsSafetySettings {
                validatedGoogle.safetySettings = nil
            }
            
            validated.google = validatedGoogle
        }
        
        // Note: We don't remove options for other providers as they may be used
        // when switching between providers or for debugging purposes
        
        return validated
    }
    
    /// Filters settings to only include supported parameters (legacy compatibility)
    public func filtered(for model: LanguageModel) -> GenerationSettings {
        return validated(for: model)
    }
}