//
//  GroqProvider.swift
//  Tachikoma
//

import Foundation

/// Provider for Groq models
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class GroqProvider: ModelProvider {
    public let modelId: String
    public let baseURL: String?
    public let apiKey: String?
    public let capabilities: ModelCapabilities

    private let model: LanguageModel.Groq

    public init(model: LanguageModel.Groq, configuration: TachikomaConfiguration) throws {
        self.model = model
        self.modelId = model.rawValue
        self.baseURL = configuration.getBaseURL(for: .groq) ?? "https://api.groq.com/openai/v1"

        if let key = configuration.getAPIKey(for: .groq) {
            self.apiKey = key
        } else {
            throw TachikomaError.authenticationFailed("GROQ_API_KEY not found")
        }

        self.capabilities = ModelCapabilities(
            supportsVision: model.supportsVision,
            supportsTools: model.supportsTools,
            supportsStreaming: true,
            contextLength: model.contextLength,
            maxOutputTokens: 4096
        )
    }

    public func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        throw TachikomaError.unsupportedOperation("Groq provider not yet implemented")
    }

    public func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        throw TachikomaError.unsupportedOperation("Groq streaming not yet implemented")
    }
}