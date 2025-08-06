//
//  ResponseCacheTests.swift
//  Tachikoma
//

import Testing
import CryptoKit
@testable import Tachikoma

// Helper class for thread-safe mutable value in closures
final class Box<T>: @unchecked Sendable {
    var value: T
    init(value: T) {
        self.value = value
    }
}

@Suite("Response Caching")
struct ResponseCacheTests {
    
    @Test("ResponseCache initialization")
    func testResponseCacheInitialization() async {
        let cache = ResponseCache(maxSize: 50, ttl: 1800)
        let stats = await cache.statistics()
        
        #expect(stats.totalEntries == 0)
        #expect(stats.cacheSize == 50)
        #expect(stats.oldestEntry == nil)
        #expect(stats.newestEntry == nil)
    }
    
    @Test("ResponseCache store and retrieve")
    func testResponseCacheStoreRetrieve() async {
        let cache = ResponseCache()
        
        let request = ProviderRequest(
            messages: [ModelMessage.user("Hello")],
            tools: nil,
            settings: .default
        )
        
        let response = ProviderResponse(
            text: "Hi there!",
            usage: Usage(inputTokens: 5, outputTokens: 10),
            finishReason: .stop
        )
        
        // Store response
        await cache.store(response, for: request)
        
        // Retrieve response
        let cached = await cache.get(for: request)
        
        #expect(cached?.text == "Hi there!")
        #expect(cached?.usage?.inputTokens == 5)
        #expect(cached?.usage?.outputTokens == 10)
        #expect(cached?.finishReason == .stop)
    }
    
    @Test("ResponseCache cache miss")
    func testResponseCacheMiss() async {
        let cache = ResponseCache()
        
        let request = ProviderRequest(
            messages: [ModelMessage.user("Test")],
            tools: nil,
            settings: .default
        )
        
        // Should return nil for uncached request
        let cached = await cache.get(for: request)
        #expect(cached == nil)
    }
    
    @Test("ResponseCache TTL expiration")
    func testResponseCacheTTLExpiration() async throws {
        let cache = ResponseCache(ttl: 0.1)  // 100ms TTL
        
        let request = ProviderRequest(
            messages: [ModelMessage.user("Temporary")],
            tools: nil,
            settings: .default
        )
        
        let response = ProviderResponse(text: "Will expire", usage: nil, finishReason: .stop)
        
        await cache.store(response, for: request)
        
        // Should retrieve immediately
        let cached1 = await cache.get(for: request)
        #expect(cached1?.text == "Will expire")
        
        // Wait for expiration
        try await Task.sleep(for: .milliseconds(150))
        
        // Should be expired
        let cached2 = await cache.get(for: request)
        #expect(cached2 == nil)
    }
    
    @Test("ResponseCache LRU eviction")
    func testResponseCacheLRUEviction() async {
        let cache = ResponseCache(maxSize: 2)  // Small cache
        
        let request1 = ProviderRequest(
            messages: [ModelMessage.user("First")],
            tools: nil,
            settings: .default
        )
        let response1 = ProviderResponse(text: "Response 1", usage: nil, finishReason: .stop)
        
        let request2 = ProviderRequest(
            messages: [ModelMessage.user("Second")],
            tools: nil,
            settings: .default
        )
        let response2 = ProviderResponse(text: "Response 2", usage: nil, finishReason: .stop)
        
        let request3 = ProviderRequest(
            messages: [ModelMessage.user("Third")],
            tools: nil,
            settings: .default
        )
        let response3 = ProviderResponse(text: "Response 3", usage: nil, finishReason: .stop)
        
        // Store first two
        await cache.store(response1, for: request1)
        await cache.store(response2, for: request2)
        
        // Access first to make it more recently used
        _ = await cache.get(for: request1)
        
        // Store third - should evict second (LRU)
        await cache.store(response3, for: request3)
        
        // First should still be cached (recently accessed)
        let cached1 = await cache.get(for: request1)
        #expect(cached1?.text == "Response 1")
        
        // Second should be evicted
        let cached2 = await cache.get(for: request2)
        #expect(cached2 == nil)
        
        // Third should be cached
        let cached3 = await cache.get(for: request3)
        #expect(cached3?.text == "Response 3")
    }
    
    @Test("ResponseCache clear")
    func testResponseCacheClear() async {
        let cache = ResponseCache()
        
        // Store multiple entries
        for i in 1...5 {
            let request = ProviderRequest(
                messages: [ModelMessage.user("Message \(i)")],
                tools: nil,
                settings: .default
            )
            let response = ProviderResponse(text: "Response \(i)", usage: nil, finishReason: .stop)
            await cache.store(response, for: request)
        }
        
        // Verify entries exist
        var stats = await cache.statistics()
        #expect(stats.totalEntries == 5)
        
        // Clear cache
        await cache.clear()
        
        // Verify cache is empty
        stats = await cache.statistics()
        #expect(stats.totalEntries == 0)
        #expect(stats.validEntries == 0)
    }
    
    @Test("ResponseCache statistics")
    func testResponseCacheStatistics() async {
        let cache = ResponseCache(maxSize: 100, ttl: 3600)
        
        // Initial state
        var stats = await cache.statistics()
        #expect(stats.totalEntries == 0)
        #expect(stats.validEntries == 0)
        #expect(stats.cacheSize == 100)
        
        // Add entries
        for i in 1...3 {
            let request = ProviderRequest(
                messages: [ModelMessage.user("Test \(i)")],
                tools: nil,
                settings: .default
            )
            let response = ProviderResponse(text: "Response \(i)", usage: nil, finishReason: .stop)
            await cache.store(response, for: request)
        }
        
        stats = await cache.statistics()
        #expect(stats.totalEntries == 3)
        #expect(stats.validEntries == 3)
        #expect(stats.oldestEntry != nil)
        #expect(stats.newestEntry != nil)
    }
    
    @Test("CacheKey generation deterministic")
    func testCacheKeyDeterministic() {
        let messages = [
            ModelMessage.user("Hello"),
            ModelMessage.assistant("Hi there")
        ]
        
        let request1 = ProviderRequest(
            messages: messages,
            tools: nil,
            settings: GenerationSettings(temperature: 0.7)
        )
        
        let request2 = ProviderRequest(
            messages: messages,
            tools: nil,
            settings: GenerationSettings(temperature: 0.7)
        )
        
        let key1 = CacheKey(from: request1)
        let key2 = CacheKey(from: request2)
        
        // Same requests should generate same keys
        #expect(key1.hash == key2.hash)
        #expect(key1.messageCount == key2.messageCount)
    }
    
    @Test("CacheKey differs for different requests")
    func testCacheKeyDifferent() {
        let request1 = ProviderRequest(
            messages: [ModelMessage.user("Hello")],
            tools: nil,
            settings: .default
        )
        
        let request2 = ProviderRequest(
            messages: [ModelMessage.user("Hi")],
            tools: nil,
            settings: .default
        )
        
        let request3 = ProviderRequest(
            messages: [ModelMessage.user("Hello")],
            tools: nil,
            settings: GenerationSettings(temperature: 0.5)
        )
        
        let key1 = CacheKey(from: request1)
        let key2 = CacheKey(from: request2)
        let key3 = CacheKey(from: request3)
        
        // Different messages = different keys
        #expect(key1.hash != key2.hash)
        
        // Different settings = different keys
        #expect(key1.hash != key3.hash)
    }
    
    @Test("CacheKey includes tools in hash")
    func testCacheKeyIncludesTools() {
        let tool1 = AgentTool(
            name: "tool1",
            description: "First tool",
            parameters: AgentToolParameters(properties: [], required: []),
            namespace: "test",
            execute: { _ in .string("") }
        )
        
        let tool2 = AgentTool(
            name: "tool2",
            description: "Second tool",
            parameters: AgentToolParameters(properties: [], required: []),
            namespace: "test",
            execute: { _ in .string("") }
        )
        
        let request1 = ProviderRequest(
            messages: [ModelMessage.user("Test")],
            tools: [tool1],
            settings: .default
        )
        
        let request2 = ProviderRequest(
            messages: [ModelMessage.user("Test")],
            tools: [tool2],
            settings: .default
        )
        
        let request3 = ProviderRequest(
            messages: [ModelMessage.user("Test")],
            tools: nil,
            settings: .default
        )
        
        let key1 = CacheKey(from: request1)
        let key2 = CacheKey(from: request2)
        let key3 = CacheKey(from: request3)
        
        // Different tools = different keys
        #expect(key1.hash != key2.hash)
        #expect(key1.hash != key3.hash)
        #expect(key2.hash != key3.hash)
    }
    
    @Test("CachedProvider wraps provider correctly")
    func testCachedProviderWrapper() async throws {
        let cache = ResponseCache()
        
        // Create a mock provider
        let mockProvider = MockProvider(
            model: .openai(.gpt4o),
            response: ProviderResponse(text: "Cached response", usage: nil, finishReason: .stop)
        )
        
        let cachedProvider = await cache.wrap(mockProvider)
        
        #expect(cachedProvider.modelId == mockProvider.modelId)
        // Skip capabilities comparison as it doesn't have Equatable
        #expect(cachedProvider.baseURL == mockProvider.baseURL)
        #expect(cachedProvider.apiKey == mockProvider.apiKey)
    }
    
    @Test("CachedProvider caches generateText")
    func testCachedProviderGenerateText() async throws {
        let cache = ResponseCache()
        
        // Use a simple counter that can be modified in the closure
        let callCount = Box(value: 0)
        let mockProvider = MockProvider(
            model: .openai(.gpt4o),
            response: ProviderResponse(text: "Response", usage: nil, finishReason: .stop),
            onGenerateText: { _ in
                callCount.value += 1
            }
        )
        
        let cachedProvider = await cache.wrap(mockProvider)
        
        let request = ProviderRequest(
            messages: [ModelMessage.user("Test")],
            tools: nil,
            settings: .default
        )
        
        // First call - should hit provider
        let response1 = try await cachedProvider.generateText(request: request)
        #expect(response1.text == "Response")
        #expect(callCount.value == 1)
        
        // Second call - should hit cache
        let response2 = try await cachedProvider.generateText(request: request)
        #expect(response2.text == "Response")  // Same response
        #expect(callCount.value == 1)  // Provider not called again
    }
    
    @Test("CachedProvider doesn't cache streaming")
    func testCachedProviderStreamText() async throws {
        let cache = ResponseCache()
        
        let callCount = Box(value: 0)
        let mockProvider = MockProvider(
            model: .openai(.gpt4o),
            response: ProviderResponse(text: "Test", usage: nil, finishReason: .stop),
            onStreamText: { _ in
                callCount.value += 1
            }
        )
        
        let cachedProvider = await cache.wrap(mockProvider)
        
        let request = ProviderRequest(
            messages: [ModelMessage.user("Test")],
            tools: nil,
            settings: .default
        )
        
        // Streaming should not use cache
        _ = try await cachedProvider.streamText(request: request)
        #expect(callCount.value == 1)
        
        _ = try await cachedProvider.streamText(request: request)
        #expect(callCount.value == 2)  // Called again, not cached
    }
}

// MARK: - Mock Provider for Testing

private struct MockProvider: ModelProvider {
    let model: LanguageModel
    let response: ProviderResponse
    var onGenerateText: (@Sendable (ProviderRequest) -> Void)?
    var onStreamText: (@Sendable (ProviderRequest) -> Void)?
    
    var modelId: String { "mock-model" }
    var baseURL: String? { nil }
    var apiKey: String? { nil }
    var capabilities: ModelCapabilities { ModelCapabilities() }
    
    init(
        model: LanguageModel,
        response: ProviderResponse,
        onGenerateText: (@Sendable (ProviderRequest) -> Void)? = nil,
        onStreamText: (@Sendable (ProviderRequest) -> Void)? = nil
    ) {
        self.model = model
        self.response = response
        self.onGenerateText = onGenerateText
        self.onStreamText = onStreamText
    }
    
    func generateText(request: ProviderRequest) async throws -> ProviderResponse {
        onGenerateText?(request)
        return response
    }
    
    func streamText(request: ProviderRequest) async throws -> AsyncThrowingStream<TextStreamDelta, Error> {
        onStreamText?(request)
        return AsyncThrowingStream { continuation in
            continuation.yield(TextStreamDelta(type: .textDelta, content: "Stream"))
            continuation.finish()
        }
    }
}