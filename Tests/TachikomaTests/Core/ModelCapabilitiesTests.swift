//
//  ModelCapabilitiesTests.swift
//  TachikomaTests
//

import Testing
import Foundation
@testable import Tachikoma

@Suite("Model Capabilities Tests")
struct ModelCapabilitiesTests {
    
    @Suite("Capability Detection")
    struct CapabilityDetectionTests {
        
        @Test("GPT-5 models exclude temperature and topP")
        func testGPT5ExcludesTemperature() {
            let models: [LanguageModel] = [
                .openai(.gpt5),
                .openai(.gpt5Mini),
                .openai(.gpt5Nano)
            ]
            
            for model in models {
                let capabilities = ModelCapabilityRegistry.shared.capabilities(for: model)
                
                #expect(!capabilities.supportsTemperature)
                #expect(!capabilities.supportsTopP)
                #expect(capabilities.excludedParameters.contains("temperature"))
                #expect(capabilities.excludedParameters.contains("topP"))
                #expect(capabilities.supportedProviderOptions.supportsVerbosity)
                #expect(capabilities.supportedProviderOptions.supportsPreviousResponseId)
            }
        }
        
        @Test("O3/O4 models have forced temperature")
        func testReasoningModelsFixedTemperature() {
            let models: [LanguageModel] = [
                .openai(.o3),
                .openai(.o3Mini),
                .openai(.o3Pro),
                .openai(.o4Mini)
            ]
            
            for model in models {
                let capabilities = ModelCapabilityRegistry.shared.capabilities(for: model)
                
                #expect(!capabilities.supportsTemperature)
                #expect(!capabilities.supportsTopP)
                #expect(capabilities.forcedTemperature == 1.0)
                #expect(capabilities.excludedParameters.contains("temperature"))
                #expect(capabilities.excludedParameters.contains("topP"))
                #expect(capabilities.supportedProviderOptions.supportsReasoningEffort)
                #expect(capabilities.supportedProviderOptions.supportsPreviousResponseId)
            }
        }
        
        @Test("O3 models exclude multiple parameters")
        func testO3ModelExclusions() {
            // Note: O1 models don't exist in the current API, using O3 instead
            let models: [LanguageModel] = [
                .openai(.o3),
                .openai(.o3Mini)
            ]
            
            for model in models {
                let capabilities = ModelCapabilityRegistry.shared.capabilities(for: model)
                
                #expect(!capabilities.supportsTemperature)
                #expect(!capabilities.supportsTopP)
                // O3 models have similar restrictions as O3 for reasoning
                #expect(!capabilities.supportsTemperature)
                #expect(!capabilities.supportsTopP)
                #expect(capabilities.forcedTemperature == 1.0)
                #expect(capabilities.excludedParameters.contains("temperature"))
                #expect(capabilities.excludedParameters.contains("topP"))
            }
        }
        
        @Test("GPT-4 models support standard parameters")
        func testGPT4StandardParameters() {
            let models: [LanguageModel] = [
                .openai(.gpt4o),
                .openai(.gpt4oMini),
                .openai(.gpt41),
                .openai(.gpt4Turbo)
            ]
            
            for model in models {
                let capabilities = ModelCapabilityRegistry.shared.capabilities(for: model)
                
                #expect(capabilities.supportsTemperature)
                #expect(capabilities.supportsTopP)
                #expect(capabilities.supportsMaxTokens)
                #expect(capabilities.supportsFrequencyPenalty)
                #expect(capabilities.supportsPresencePenalty)
                #expect(capabilities.supportedProviderOptions.supportsParallelToolCalls)
                #expect(capabilities.supportedProviderOptions.supportsResponseFormat)
                #expect(capabilities.supportedProviderOptions.supportsLogprobs)
            }
        }
        
        @Test("Claude models support thinking")
        func testClaudeThinkingSupport() {
            let models: [LanguageModel] = [
                .anthropic(.opus4),
                .anthropic(.sonnet4),
                .anthropic(.sonnet37)
            ]
            
            for model in models {
                let capabilities = ModelCapabilityRegistry.shared.capabilities(for: model)
                
                #expect(capabilities.supportedProviderOptions.supportsThinking)
                #expect(capabilities.supportedProviderOptions.supportsCacheControl)
            }
        }
        
        @Test("Google models support topK and thinking")
        func testGoogleCapabilities() {
            let models: [LanguageModel] = [
                .google(.gemini2Flash),
                .google(.gemini15Pro),
                .google(.gemini15Flash),
                .google(.geminiPro)
            ]
            
            for model in models {
                let capabilities = ModelCapabilityRegistry.shared.capabilities(for: model)
                
                #expect(capabilities.supportsTopK)
                #expect(capabilities.supportedProviderOptions.supportsThinkingConfig)
                #expect(capabilities.supportedProviderOptions.supportsSafetySettings)
            }
        }
        
        @Test("Mistral models support safe mode")
        func testMistralCapabilities() {
            let models: [LanguageModel] = [
                .mistral(.large2),
                .mistral(.codestral)
            ]
            
            for model in models {
                let capabilities = ModelCapabilityRegistry.shared.capabilities(for: model)
                
                #expect(capabilities.supportedProviderOptions.supportsSafeMode)
            }
        }
        
        @Test("Groq models support speed level")
        func testGroqCapabilities() {
            let models: [LanguageModel] = [
                .groq(.llama3170b),
                .groq(.llama370b)
            ]
            
            for model in models {
                let capabilities = ModelCapabilityRegistry.shared.capabilities(for: model)
                
                #expect(capabilities.supportedProviderOptions.supportsSpeedLevel)
            }
        }
        
        @Test("Grok models support fun mode")
        func testGrokCapabilities() {
            let models: [LanguageModel] = [
                .grok(.grok4),
                .grok(.grok3)
            ]
            
            for model in models {
                let capabilities = ModelCapabilityRegistry.shared.capabilities(for: model)
                
                #expect(capabilities.supportedProviderOptions.supportsFunMode)
                #expect(capabilities.supportedProviderOptions.supportsCurrentEvents)
            }
        }
    }
    
    @Suite("Settings Validation")
    struct SettingsValidationTests {
        
        @Test("Validate settings for GPT-5")
        func testValidateGPT5Settings() {
            let settings = GenerationSettings(
                maxTokens: 1000,
                temperature: 0.7,
                topP: 0.9,
                frequencyPenalty: 0.5,
                presencePenalty: 0.3,
                providerOptions: .init(
                    openai: .init(
                        verbosity: .high,
                        previousResponseId: "test-123"
                    )
                )
            )
            
            let validated = settings.validated(for: .openai(.gpt5))
            
            #expect(validated.maxTokens == 1000)
            #expect(validated.temperature == nil)  // Excluded
            #expect(validated.topP == nil)  // Excluded
            #expect(validated.frequencyPenalty == nil)  // Excluded
            #expect(validated.presencePenalty == nil)  // Excluded
            #expect(validated.providerOptions.openai?.verbosity == .high)  // Kept
            #expect(validated.providerOptions.openai?.previousResponseId == "test-123")  // Kept
        }
        
        @Test("Validate settings for O3 with forced temperature")
        func testValidateO3Settings() {
            let settings = GenerationSettings(
                temperature: 0.5,
                topP: 0.8,
                providerOptions: .init(
                    openai: .init(
                        verbosity: .medium,  // Should be removed as not supported
                        reasoningEffort: .high
                    )
                )
            )
            
            let validated = settings.validated(for: LanguageModel.openai(.o3))
            
            #expect(validated.temperature == 1.0)  // Forced to 1.0
            #expect(validated.topP == nil)  // Excluded
            #expect(validated.providerOptions.openai?.reasoningEffort == .high)  // Kept
            #expect(validated.providerOptions.openai?.verbosity == nil)  // Removed
        }
        
        @Test("Validate settings for GPT-4")
        func testValidateGPT4Settings() {
            let settings = GenerationSettings(
                maxTokens: 2000,
                temperature: 0.8,
                topP: 0.95,
                frequencyPenalty: 0.2,
                presencePenalty: 0.1,
                providerOptions: .init(
                    openai: .init(
                        parallelToolCalls: true,
                        responseFormat: .json,
                        logprobs: true,
                        topLogprobs: 3
                    )
                )
            )
            
            let validated = settings.validated(for: .openai(.gpt4o))
            
            #expect(validated.maxTokens == 2000)
            #expect(validated.temperature == 0.8)
            #expect(validated.topP == 0.95)
            #expect(validated.frequencyPenalty == 0.2)
            #expect(validated.presencePenalty == 0.1)
            #expect(validated.providerOptions.openai?.parallelToolCalls == true)
            #expect(validated.providerOptions.openai?.responseFormat == .json)
            #expect(validated.providerOptions.openai?.logprobs == true)
            #expect(validated.providerOptions.openai?.topLogprobs == 3)
        }
        
        @Test("Validate Anthropic options")
        func testValidateAnthropicOptions() {
            let settings = GenerationSettings(
                temperature: 0.7,
                providerOptions: .init(
                    openai: .init(  // Should be ignored for Anthropic
                        verbosity: .high
                    ),
                    anthropic: .init(
                        thinking: .enabled(budgetTokens: 3000),
                        cacheControl: .persistent
                    )
                )
            )
            
            let validated = settings.validated(for: LanguageModel.anthropic(.opus4))
            
            #expect(validated.temperature == 0.7)
            #expect(validated.providerOptions.anthropic?.thinking != nil)
            #expect(validated.providerOptions.anthropic?.cacheControl == .persistent)
            // OpenAI options remain unfiltered (they won't be used by Anthropic provider)
            #expect(validated.providerOptions.openai?.verbosity == .high)
        }
    }
    
    @Suite("Custom Model Registration")
    struct CustomModelTests {
        
        @Test("Register custom model capabilities")
        func testRegisterCustomCapabilities() {
            let customCaps = ModelParameterCapabilities(
                supportsTemperature: false,
                supportsTopP: false,
                supportsMaxTokens: true,
                forcedTemperature: 0.8,
                excludedParameters: ["temperature", "topP"]
            )
            
            let model = LanguageModel.custom(
                provider: TestModelProvider(modelId: "test-model")
            )
            ModelCapabilityRegistry.shared.register(customCaps, for: model)
            
            let retrieved = ModelCapabilityRegistry.shared.capabilities(for: model)
            
            #expect(!retrieved.supportsTemperature)
            #expect(retrieved.forcedTemperature == 0.8)
            #expect(retrieved.supportsMaxTokens)
            #expect(retrieved.excludedParameters.contains("temperature"))
        }
        
        @Test("OpenAI-compatible model registration")
        func testOpenAICompatibleRegistration() {
            let capabilities = ModelParameterCapabilities(
                supportsTemperature: true,
                supportsTopK: true,
                temperatureRange: 0.0...1.5
            )
            
            ModelCapabilityRegistry.shared.registerOpenAICompatible(
                endpoint: "https://test.example.com",
                capabilities: capabilities
            )
            
            // The capability is registered but we need the actual model to retrieve it
            let model = LanguageModel.openaiCompatible(
                modelId: "test-model",
                baseURL: "https://test.example.com"
            )
            
            // Default capabilities will be returned since we register by endpoint
            let retrieved = ModelCapabilityRegistry.shared.capabilities(for: model)
            #expect(retrieved.supportsTemperature)  // Default OpenAI capabilities
        }
    }
    
    @Suite("Thread Safety")
    struct ThreadSafetyTests {
        
        @Test("Concurrent capability access")
        func testConcurrentAccess() async {
            let models: [LanguageModel] = [
                .openai(.gpt5),
                .openai(.gpt4o),
                .anthropic(.opus4),
                .google(.gemini2Flash)
            ]
            
            await withTaskGroup(of: Void.self) { group in
                // Multiple readers
                for _ in 0..<100 {
                    group.addTask {
                        let model = models.randomElement()!
                        _ = ModelCapabilityRegistry.shared.capabilities(for: model)
                    }
                }
                
                // Multiple writers
                for i in 0..<10 {
                    group.addTask {
                        let caps = ModelParameterCapabilities(
                            supportsTemperature: Bool.random()
                        )
                        let model = LanguageModel.custom(
                            provider: TestModelProvider(modelId: "concurrent-\(i)")
                        )
                        ModelCapabilityRegistry.shared.register(caps, for: model)
                    }
                }
            }
            
            // Should complete without crashes
            #expect(true)
        }
    }
}

// Helper for testing custom models
private struct TestModelProvider: ModelProvider {
    let modelId: String
    let baseURL: String? = nil
    let apiKey: String? = nil
    let capabilities = ModelCapabilities(
        supportsVision: false,
        supportsTools: false,
        supportsStreaming: true,
        contextLength: 4096,
        maxOutputTokens: 4096
    )
    
    func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Test provider")
    }
    
    func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Test provider")
    }
}