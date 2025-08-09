//
//  AI-CLI.swift
//  Tachikoma
//

// Comprehensive AI CLI for querying all supported AI providers
// Supports OpenAI, Anthropic, Google, Mistral, Groq, Grok, and Ollama
// Compile with: swift build --product ai-cli
// Run with: .build/debug/ai-cli [options] "Your question here"

import Foundation
import Tachikoma

struct CLIConfig {
    var modelString: String?
    var apiMode: OpenAIAPIMode? // For OpenAI models
    var stream: Bool = false
    var showThinking: Bool = false  // Show reasoning/thinking process
    var showHelp: Bool = false
    var showVersion: Bool = false
    var showConfig: Bool = false
    var query: String?
}

@main
struct AICLI {
    static func main() async {
        // Parse command line arguments
        guard let config = parseArguments() else {
            exit(1)
        }
        
        // Handle special commands
        if config.showVersion {
            showVersion()
            return
        }
        
        if config.showHelp {
            showHelp()
            return
        }
        
        if config.showConfig {
            showConfiguration(config: config)
            return
        }
        
        // Validate query
        guard let query = config.query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            print("❌ Error: No query provided")
            print("Use --help for usage information")
            exit(1)
        }
        
        // Parse and validate model
        let model: LanguageModel
        do {
            if let modelString = config.modelString {
                model = try ModelSelector.parseModel(modelString)
            } else {
                model = .openai(.gpt5) // Default to GPT-5
            }
        } catch {
            print("❌ Error parsing model: \(error)")
            print("Use --help to see available models")
            exit(1)
        }
        
        // Check API key for the provider
        do {
            try validateAPIKey(for: model)
        } catch {
            print("❌ \(error)")
            showAPIKeyInstructions(for: model)
            exit(1)
        }
        
        // Display configuration
        showRequestConfig(model: model, config: config, query: query)
        
        // Execute the request
        do {
            if config.stream {
                try await executeStreamingRequest(model: model, config: config, query: query)
            } else {
                try await executeRequest(model: model, config: config, query: query)
            }
        } catch {
            print("\n❌ Error: \(error)")
            
            // Provide helpful context for common errors
            if let error = error as? TachikomaError {
                showErrorHelp(for: error, model: model)
            }
            exit(1)
        }
    }
    
    // MARK: - Argument Parsing
    
    static func parseArguments() -> CLIConfig? {
        let args = CommandLine.arguments
        var config = CLIConfig()
        var queryArgs: [String] = []
        
        var i = 1
        while i < args.count {
            let arg = args[i]
            
            switch arg {
            case "--help", "-h":
                config.showHelp = true
                return config
            case "--version", "-v":
                config.showVersion = true
                return config
            case "--config":
                config.showConfig = true
                return config
            case "--model", "-m":
                guard i + 1 < args.count else {
                    print("❌ Error: --model requires a value")
                    return nil
                }
                config.modelString = args[i + 1]
                i += 2
            case "--api":
                guard i + 1 < args.count else {
                    print("❌ Error: --api requires a value")
                    return nil
                }
                let apiValue = args[i + 1].lowercased()
                if let mode = OpenAIAPIMode(rawValue: apiValue) {
                    config.apiMode = mode
                    i += 2
                } else {
                    print("❌ Error: --api must be 'chat' or 'responses'")
                    return nil
                }
            case "--stream", "-s":
                config.stream = true
                i += 1
            case "--thinking":
                config.showThinking = true
                i += 1
            default:
                if arg.starts(with: "--") {
                    print("❌ Error: Unknown option '\(arg)'")
                    print("Use --help for available options")
                    return nil
                } else {
                    queryArgs.append(arg)
                    i += 1
                }
            }
        }
        
        if !queryArgs.isEmpty {
            config.query = queryArgs.joined(separator: " ")
        }
        
        return config
    }
    
    // MARK: - Help and Information
    
    static func showVersion() {
        print("AI CLI v1.0.0")
        print("Powered by Tachikoma - Universal AI Integration Library")
        print("Supports: OpenAI, Anthropic, Google, Mistral, Groq, Grok, Ollama")
    }
    
    static func showHelp() {
        print("""
AI CLI - Universal AI Assistant

USAGE:
    ai-cli [OPTIONS] "your question here"

OPTIONS:
    -m, --model <MODEL>     Specify the AI model to use
    --api <API>            For OpenAI models: 'chat' or 'responses' (default: responses for GPT-5)
    -s, --stream           Stream the response (partial support)
    --config               Show current configuration and exit
    -h, --help             Show this help message
    -v, --version          Show version information

EXAMPLES:
    # Use default model (GPT-5)
    ai-cli "What is the capital of France?"
    
    # Use specific models
    ai-cli --model claude "Explain quantum computing"
    ai-cli --model gpt-4o "Describe this image" 
    ai-cli --model grok "Tell me a joke"
    ai-cli --model llama3.3 "Help me debug this code"
    
    # OpenAI API selection
    ai-cli --model gpt-5 --api chat "Use Chat Completions API"
    ai-cli --model gpt-5 --api responses "Use Responses API"
    
    # Streaming responses
    ai-cli --stream --model claude "Write a short story"
    
    # Show thinking process (reasoning models)
    ai-cli --thinking --model o3 "Solve this logic puzzle"
    ai-cli --thinking --model gpt-5 "Complex reasoning task"

PROVIDERS & MODELS:

OpenAI:
  • gpt-5, gpt-5-mini, gpt-5-nano (GPT-5 series, August 2025)
  • o3, o3-mini, o3-pro, o4-mini (Latest reasoning models)
  • gpt-4.1, gpt-4.1-mini (GPT-4.1 series)
  • gpt-4o, gpt-4o-mini (Multimodal)
  • gpt-4-turbo, gpt-3.5-turbo (Legacy)

Anthropic:
  • claude-opus-4-1-20250805, claude-sonnet-4-20250514 (Claude 4)
  • claude-3-7-sonnet (Claude 3.7)
  • claude-3-5-opus, claude-3-5-sonnet, claude-3-5-haiku (Claude 3.5)

Google:
  • gemini-2.0-flash, gemini-2.0-flash-thinking (Gemini 2.0)
  • gemini-1.5-pro, gemini-1.5-flash (Gemini 1.5)

Mistral:
  • mistral-large-2, mistral-large, mistral-small
  • mistral-nemo, codestral

Groq (Ultra-fast):
  • llama-3.1-70b, llama-3.1-8b
  • mixtral-8x7b, gemma2-9b

Grok (xAI):
  • grok-4-0709, grok-3, grok-3-mini
  • grok-2-image-1212 (Vision support)

Ollama (Local):
  • llama3.3, llama3.2, llama3.1 (Recommended)
  • llava, bakllava (Vision models)
  • codellama, mistral-nemo, qwen2.5
  • deepseek-r1, command-r-plus
  • Custom: any-model:tag

SHORTCUTS:
  • claude, opus → claude-opus-4-1-20250805
  • gpt, gpt4 → gpt-4.1
  • grok → grok-4-0709
  • llama, llama3 → llama3.3

API KEYS:
Set the appropriate environment variable for your provider:
  • OPENAI_API_KEY for OpenAI models
  • ANTHROPIC_API_KEY for Claude models
  • GOOGLE_API_KEY for Gemini models
  • MISTRAL_API_KEY for Mistral models
  • GROQ_API_KEY for Groq models
  • X_AI_API_KEY or XAI_API_KEY for Grok models
  • Ollama requires local installation (no API key needed)

For detailed documentation, visit: https://github.com/steipete/tachikoma
""")
    }
    
    static func showConfiguration(config: CLIConfig) {
        print("🔧 Current Configuration:")
        
        // Model information
        if let modelString = config.modelString {
            do {
                let model = try ModelSelector.parseModel(modelString)
                let caps = ModelSelector.getCapabilities(for: model)
                print("📱 Model: \(caps.description)")
                print("🏢 Provider: \(model.providerName)")
                print("🆔 Model ID: \(model.modelId)")
                
                // Show capabilities
                print("✨ Capabilities:")
                print("   • Vision: \(model.supportsVision ? "✅" : "❌")")
                print("   • Tools: \(model.supportsTools ? "✅" : "❌")")
                print("   • Streaming: \(model.supportsStreaming ? "✅" : "❌")")
                
                if case .openai(let openaiModel) = model {
                    let mode = config.apiMode ?? OpenAIAPIMode.defaultMode(for: openaiModel)
                    print("🌐 API Mode: \(mode.displayName)")
                }
            } catch {
                print("📱 Model: \(modelString) (❌ Invalid)")
            }
        } else {
            print("📱 Model: gpt-5 (default)")
            print("🏢 Provider: OpenAI")
        }
        
        // API Key status
        print("\n🔐 API Keys:")
        checkAPIKeyStatus(provider: "OpenAI", envVar: "OPENAI_API_KEY")
        checkAPIKeyStatus(provider: "Anthropic", envVar: "ANTHROPIC_API_KEY")
        checkAPIKeyStatus(provider: "Google", envVar: "GOOGLE_API_KEY")
        checkAPIKeyStatus(provider: "Mistral", envVar: "MISTRAL_API_KEY")
        checkAPIKeyStatus(provider: "Groq", envVar: "GROQ_API_KEY")
        checkAPIKeyStatus(provider: "Grok", envVar: "X_AI_API_KEY")
        checkAPIKeyStatus(provider: "Grok (alt)", envVar: "XAI_API_KEY")
        
        // Ollama status
        print("   • Ollama: Local (no API key required)")
        
        print("\n💫 Options:")
        print("   • Streaming: \(config.stream ? "enabled" : "disabled")")
    }
    
    static func checkAPIKeyStatus(provider: String, envVar: String) {
        let config = TachikomaConfiguration.current
        let prov = Provider.from(identifier: provider.lowercased())
        
        if let key = config.getAPIKey(for: prov), !key.isEmpty {
            let masked = maskAPIKey(key)
            print("   • \(provider): \(masked) (configured)")
        } else if let key = ProcessInfo.processInfo.environment[envVar], !key.isEmpty {
            let masked = maskAPIKey(key)
            print("   • \(provider): \(masked) (environment)")
        } else {
            print("   • \(provider): Not set")
        }
    }
    
    // MARK: - API Key Validation
    
    static func validateAPIKey(for model: LanguageModel) throws {
        let provider = getProvider(for: model)
        let config = TachikomaConfiguration.current
        
        // Check if API key is available (from config or environment)
        if !config.hasAPIKey(for: provider) && provider.requiresAPIKey {
            let envVar = provider.environmentVariable.isEmpty ? "API key" : provider.environmentVariable
            if provider == .grok {
                // Special case for Grok with alternative variables
                throw CLIError.missingAPIKey("X_AI_API_KEY or XAI_API_KEY")
            } else {
                throw CLIError.missingAPIKey(envVar)
            }
        }
        
        // Check for unsupported providers
        switch model {
        case .openRouter, .together, .replicate:
            throw CLIError.unsupportedProvider("Third-party aggregators not yet implemented in CLI")
        case .openaiCompatible, .anthropicCompatible, .custom:
            throw CLIError.unsupportedProvider("Custom providers not yet implemented in CLI")
        default:
            break
        }
    }
    
    static func getProvider(for model: LanguageModel) -> Provider {
        switch model {
        case .openai: return .openai
        case .anthropic: return .anthropic
        case .google: return .google
        case .mistral: return .mistral
        case .groq: return .groq
        case .grok: return .grok
        case .ollama: return .ollama
        case .lmstudio: return .lmstudio
        case .openRouter, .together, .replicate,
             .openaiCompatible, .anthropicCompatible, .custom:
            return .custom(model.providerName)
        }
    }
    
    static func showAPIKeyInstructions(for model: LanguageModel) {
        print("\n💡 Setup Instructions:")
        
        switch model {
        case .openai:
            print("Set your OpenAI API key:")
            print("export OPENAI_API_KEY='sk-your-key-here'")
            print("Get your key at: https://platform.openai.com/api-keys")
        case .anthropic:
            print("Set your Anthropic API key:")
            print("export ANTHROPIC_API_KEY='sk-ant-your-key-here'")
            print("Get your key at: https://console.anthropic.com/")
        case .google:
            print("Set your Google API key:")
            print("export GOOGLE_API_KEY='your-key-here'")
            print("Get your key at: https://aistudio.google.com/apikey")
        case .mistral:
            print("Set your Mistral API key:")
            print("export MISTRAL_API_KEY='your-key-here'")
            print("Get your key at: https://console.mistral.ai/")
        case .groq:
            print("Set your Groq API key:")
            print("export GROQ_API_KEY='gsk_your-key-here'")
            print("Get your key at: https://console.groq.com/keys")
        case .grok:
            print("Set your xAI API key:")
            print("export X_AI_API_KEY='xai-your-key-here'")
            print("# or alternatively:")
            print("export XAI_API_KEY='xai-your-key-here'")
            print("Get your key at: https://console.x.ai/")
        case .ollama:
            print("Install Ollama locally:")
            print("brew install ollama")
            print("ollama serve")
            print("ollama pull llama3.3")
        default:
            print("This provider requires additional setup.")
        }
    }
    
    // MARK: - Request Execution
    
    static func showRequestConfig(model: LanguageModel, config: CLIConfig, query: String) {
        let maskedKey = getCurrentAPIKey(for: model).map(maskAPIKey) ?? "Not required"
        print("🔐 API Key: \(maskedKey)")
        print("🤖 Model: \(model.modelId)")
        print("🏢 Provider: \(model.providerName)")
        
        if case .openai(let openaiModel) = model {
            let apiMode = config.apiMode ?? OpenAIAPIMode.defaultMode(for: openaiModel)
            print("🌐 API: \(apiMode.displayName)")
        }
        
        print("📝 Query: \(query)")
        print("---")
    }
    
    static func executeRequest(model: LanguageModel, config: CLIConfig, query: String) async throws {
        print("🚀 Sending query...")
        
        let startTime = Date()
        
        // Use the global generate function with proper model selection
        let result: GenerateTextResult
        var reasoningText: String? = nil
        
        // Check if we should show thinking for this model
        let actualApiMode: OpenAIAPIMode? = if case .openai(let openaiModel) = model {
            config.apiMode ?? OpenAIAPIMode.defaultMode(for: openaiModel)
        } else {
            nil
        }
        
        let supportsThinking = isReasoningModel(model) && actualApiMode != .chat
        if config.showThinking && !supportsThinking {
            print("⚠️  Note: --thinking only works with O3, O4, and GPT-5 models via Responses API")
        }
        
        if case .openai(let openaiModel) = model, actualApiMode == .chat {
            // Force Chat Completions API (no reasoning available)
            let provider = try OpenAIProvider(model: openaiModel, configuration: TachikomaConfiguration.current)
            let request = ProviderRequest(
                messages: [.user(query)],
                tools: nil,
                settings: GenerationSettings(maxTokens: 2000)
            )
            let providerResponse = try await provider.generateText(request: request)
            result = GenerateTextResult(
                text: providerResponse.text,
                usage: providerResponse.usage,
                finishReason: providerResponse.finishReason,
                steps: [],
                messages: [.user(query)]
            )
        } else if case .openai(let openaiModel) = model,
                  actualApiMode == .responses && config.showThinking {
            // Use Responses API with reasoning extraction for thinking models
            let (response, reasoning) = try await executeResponsesAPIWithReasoning(
                model: openaiModel,
                query: query
            )
            reasoningText = reasoning
            result = GenerateTextResult(
                text: response.text,
                usage: response.usage,
                finishReason: response.finishReason,
                steps: [],
                messages: [.user(query)]
            )
        } else if case .openai(let openaiModel) = model, actualApiMode == .responses {
            // Force Responses API (without reasoning extraction)
            let provider = try OpenAIResponsesProvider(model: openaiModel, configuration: TachikomaConfiguration.current)
            let request = ProviderRequest(
                messages: [.user(query)],
                tools: nil,
                settings: GenerationSettings(maxTokens: 2000)
            )
            let providerResponse = try await provider.generateText(request: request)
            result = GenerateTextResult(
                text: providerResponse.text,
                usage: providerResponse.usage,
                finishReason: providerResponse.finishReason,
                steps: [],
                messages: [.user(query)]
            )
        } else {
            // Use global generate function for all other providers
            result = try await generateText(
                model: model,
                messages: [.user(query)],
                settings: GenerationSettings(maxTokens: 2000)
            )
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        print("✅ Response received in \(String(format: "%.2f", duration))s")
        
        // Display thinking/reasoning if available (before the response)
        if config.showThinking {
            if let reasoning = reasoningText, !reasoning.isEmpty {
                print("\n🧠 Thinking Process:")
                print("-------------------")
                print(reasoning)
                print("-------------------")
            } else if supportsThinking {
                // Show that reasoning occurred but isn't exposed
                if let usage = result.usage,
                   let outputDetails = (usage as? Usage)?.outputTokens {
                    print("\n⚠️  Note: Model used internal reasoning but doesn't expose the thinking process.")
                    print("   The model performed reasoning internally as part of generating the response.")
                }
            }
        }
        
        print("\n💬 Response:")
        print(result.text)
        
        // Show usage information in a single line
        if let usage = result.usage {
            var usageStr = "\n📊 Usage: \(usage.inputTokens) in, \(usage.outputTokens) out, \(usage.totalTokens) total"
            
            // Add cost estimate if available
            if let cost = estimateCost(for: model, usage: usage) {
                usageStr += " (~$\(String(format: "%.4f", cost)))"
            }
            
            // Add finish reason
            if let finishReason = result.finishReason {
                usageStr += " [\(finishReason.rawValue)]"
            }
            
            print(usageStr)
        } else if let finishReason = result.finishReason {
            print("\n🎯 Finished: \(finishReason.rawValue)")
        }
    }
    
    // MARK: - Reasoning Support
    
    static func isReasoningModel(_ model: LanguageModel) -> Bool {
        guard case .openai(let openaiModel) = model else { return false }
        switch openaiModel {
        case .o3, .o3Mini, .o3Pro, .o4Mini, .gpt5, .gpt5Mini, .gpt5Nano:
            return true
        default:
            return false
        }
    }
    
    static func executeResponsesAPIWithReasoning(
        model: LanguageModel.OpenAI,
        query: String
    ) async throws -> (response: ProviderResponse, reasoning: String?) {
        let config = TachikomaConfiguration.current
        guard let apiKey = config.getAPIKey(for: .openai) else {
            throw TachikomaError.authenticationFailed("OpenAI API key not found")
        }
        
        let baseURL = config.getBaseURL(for: .openai) ?? "https://api.openai.com/v1"
        
        // Build request body for Responses API
        let requestBody: [String: Any] = [
            "model": model.modelId,
            "input": [["role": "user", "content": query]],
            "stream": false,
            "reasoning": [
                "effort": "high"  // High effort for detailed reasoning
            ]
        ]
        
        // Make the API call
        let url = URL(string: "\(baseURL)/responses")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TachikomaError.networkError(NSError(domain: "Invalid response", code: 0))
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorText = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TachikomaError.apiError("Responses API Error: \(errorText)")
        }
        
        // Parse the response
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let outputs = json["output"] as? [[String: Any]] else {
            throw TachikomaError.apiError("Invalid response format")
        }
        
        // Extract reasoning and message
        var reasoningText: String? = nil
        var messageText = ""
        var usage: Usage? = nil
        
        for output in outputs {
            let outputType = output["type"] as? String ?? ""
            
            if outputType == "reasoning" {
                // Extract reasoning text if available
                if let summary = output["summary"] as? [[String: Any]] {
                    let reasoningParts = summary.compactMap { item -> String? in
                        if let text = item["text"] as? String {
                            return text
                        }
                        return nil
                    }
                    if !reasoningParts.isEmpty {
                        reasoningText = reasoningParts.joined(separator: "\n")
                    }
                }
                
                // If no summary, try content array (for O3/O4)
                if reasoningText == nil || reasoningText?.isEmpty == true {
                    if let contentArray = output["content"] as? [[String: Any]] {
                        let reasoningParts = contentArray.compactMap { item -> String? in
                            if item["type"] as? String == "text",
                               let text = item["text"] as? String {
                                return text
                            }
                            return nil
                        }
                        if !reasoningParts.isEmpty {
                            reasoningText = reasoningParts.joined(separator: "\n")
                        }
                    }
                }
                
                // If still no reasoning, try raw content string
                if reasoningText == nil || reasoningText?.isEmpty == true {
                    if let content = output["content"] as? String {
                        reasoningText = content
                    }
                }
            } else if outputType == "message" {
                // Extract message content
                if let contents = output["content"] as? [[String: Any]] {
                    for content in contents {
                        if content["type"] as? String == "output_text",
                           let text = content["text"] as? String {
                            messageText = text
                        }
                    }
                }
            }
        }
        
        // Extract usage if available
        if let usageData = json["usage"] as? [String: Any] {
            let inputTokens = (usageData["input_tokens"] as? Int) ?? (usageData["prompt_tokens"] as? Int) ?? 0
            let outputTokens = (usageData["output_tokens"] as? Int) ?? (usageData["completion_tokens"] as? Int) ?? 0
            usage = Usage(inputTokens: inputTokens, outputTokens: outputTokens)
        }
        
        let providerResponse = ProviderResponse(
            text: messageText,
            usage: usage,
            finishReason: .stop
        )
        
        return (providerResponse, reasoningText)
    }
    
    static func executeStreamingRequest(model: LanguageModel, config: CLIConfig, query: String) async throws {
        print("🚀 Streaming response...")
        print("\n💬 Response:")
        
        // Use streaming generate function
        let stream = try await streamText(
            model: model,
            messages: [.user(query)],
            settings: GenerationSettings(maxTokens: 2000)
        )
        
        var fullText = ""
        var usage: Usage?
        
        for try await delta in stream.stream {
            switch delta.type {
            case .textDelta:
                if let content = delta.content {
                    print(content, terminator: "")
                    fflush(stdout)
                    fullText += content
                }
            case .done:
                if let deltaUsage = delta.usage {
                    usage = deltaUsage
                }
                break
            case .toolCall, .toolResult, .reasoning:
                // Handle tool calls if needed in the future
                continue
            }
            
            // Update usage if available
            if let deltaUsage = delta.usage {
                usage = deltaUsage
            }
        }
        
        print("\n")
        
        // Show final usage information in a single line
        if let usage = usage {
            var usageStr = "📊 Usage: \(usage.inputTokens) in, \(usage.outputTokens) out, \(usage.totalTokens) total"
            
            // Add cost estimate if available
            if let cost = estimateCost(for: model, usage: usage) {
                usageStr += " (~$\(String(format: "%.4f", cost)))"
            }
            
            print(usageStr)
        }
    }
    
    // MARK: - Utility Functions
    
    static func getCurrentAPIKey(for model: LanguageModel) -> String? {
        let provider = getProvider(for: model)
        return TachikomaConfiguration.current.getAPIKey(for: provider)
    }
    
    static func maskAPIKey(_ key: String) -> String {
        guard key.count > 10 else { return "***" }
        let prefix = key.prefix(5)
        let suffix = key.suffix(5)
        return "\(prefix)...\(suffix)"
    }
    
    static func estimateCost(for model: LanguageModel, usage: Usage) -> Double? {
        // Rough cost estimates (as of 2025, prices may vary)
        let inputCostPer1k: Double
        let outputCostPer1k: Double
        
        switch model {
        case .openai(let openaiModel):
            switch openaiModel {
            case .gpt5: return nil // Pricing TBD
            case .gpt5Mini: return nil // Pricing TBD
            case .gpt5Nano: return nil // Pricing TBD
            case .gpt4o:
                inputCostPer1k = 0.005
                outputCostPer1k = 0.015
            case .gpt4oMini:
                inputCostPer1k = 0.00015
                outputCostPer1k = 0.0006
            default: return nil
            }
        case .anthropic(let anthropicModel):
            switch anthropicModel {
            case .opus4, .opus4Thinking:
                inputCostPer1k = 0.015
                outputCostPer1k = 0.075
            case .sonnet4, .sonnet4Thinking:
                inputCostPer1k = 0.003
                outputCostPer1k = 0.015
            case .haiku35:
                inputCostPer1k = 0.0008
                outputCostPer1k = 0.004
            default: return nil
            }
        default:
            return nil
        }
        
        let inputCost = (Double(usage.inputTokens) / 1000.0) * inputCostPer1k
        let outputCost = (Double(usage.outputTokens) / 1000.0) * outputCostPer1k
        return inputCost + outputCost
    }
    
    static func showErrorHelp(for error: TachikomaError, model: LanguageModel) {
        print("\n💡 Troubleshooting:")
        
        switch error {
        case .authenticationFailed:
            print("Authentication failed. Check your API key:")
            showAPIKeyInstructions(for: model)
        case .rateLimited:
            print("Rate limit exceeded. Try:")
            print("• Wait a moment and retry")
            print("• Use a different model")
            print("• Check your usage limits")
        case .modelNotFound:
            print("Model not found. Try:")
            print("• Check model name spelling")
            print("• Use --help to see available models")
            print("• Ensure you have access to this model")
        case .networkError:
            print("Network error. Try:")
            print("• Check your internet connection")
            print("• Retry the request")
            print("• Check if the service is down")
        default:
            print("For more help, visit: https://github.com/steipete/tachikoma")
        }
    }
}

// MARK: - Error Types

enum CLIError: Error, LocalizedError {
    case missingAPIKey(String)
    case unsupportedProvider(String)
    case invalidModel(String)
    
    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let key):
            return "Missing API key: \(key) environment variable not set"
        case .unsupportedProvider(let provider):
            return "Unsupported provider: \(provider)"
        case .invalidModel(let model):
            return "Invalid model: \(model)"
        }
    }
}