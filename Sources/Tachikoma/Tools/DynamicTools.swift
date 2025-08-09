//
//  DynamicTools.swift
//  Tachikoma
//

import Foundation

// MARK: - Dynamic Tool System Extensions
// Core dynamic tool types (DynamicToolProvider, DynamicTool, DynamicSchema) are now in Core/ToolTypes.swift
// This file contains additional dynamic tool functionality and extensions

// MARK: - Dynamic Tool Registry

/// Registry for managing dynamic tool providers
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class DynamicToolRegistry: @unchecked Sendable {
    private var providers: [String: DynamicToolProvider] = [:]
    private let lock = NSLock()
    
    public init() {}
    
    /// Register a dynamic tool provider
    public func register(_ provider: DynamicToolProvider, id: String) {
        lock.withLock {
            providers[id] = provider
        }
    }
    
    /// Unregister a provider
    public func unregister(id: String) {
        lock.withLock {
            _ = providers.removeValue(forKey: id)
        }
    }
    
    /// Get all registered providers
    public var allProviders: [DynamicToolProvider] {
        lock.withLock {
            Array(providers.values)
        }
    }
    
    /// Discover all tools from all providers
    public func discoverAllTools() async throws -> [DynamicTool] {
        var allTools: [DynamicTool] = []
        
        for provider in allProviders {
            let tools = try await provider.discoverTools()
            allTools.append(contentsOf: tools)
        }
        
        return allTools
    }
    
    /// Convert all discovered tools to AgentTools
    public func getAllAgentTools() async throws -> [AgentTool] {
        let dynamicTools = try await discoverAllTools()
        
        return dynamicTools.map { tool in
            tool.toAgentTool { arguments in
                // Find the provider that owns this tool
                for provider in self.allProviders {
                    if let providerTools = try? await provider.discoverTools(),
                       providerTools.contains(where: { $0.name == tool.name }) {
                        return try await provider.executeTool(name: tool.name, arguments: arguments)
                    }
                }
                throw TachikomaError.toolCallFailed("No provider found for tool: \(tool.name)")
            }
        }
    }
}

// MARK: - Mock Dynamic Tool Provider

/// Mock provider for testing dynamic tools
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct MockDynamicToolProvider: DynamicToolProvider {
    private let tools: [DynamicTool]
    private let executor: @Sendable (String, AgentToolArguments) async throws -> AnyAgentToolValue
    
    public init(
        tools: [DynamicTool],
        executor: @escaping @Sendable (String, AgentToolArguments) async throws -> AnyAgentToolValue = { name, _ in
            AnyAgentToolValue(string: "Mock result for \(name)")
        }
    ) {
        self.tools = tools
        self.executor = executor
    }
    
    public func discoverTools() async throws -> [DynamicTool] {
        tools
    }
    
    public func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        guard tools.contains(where: { $0.name == name }) else {
            throw TachikomaError.toolCallFailed("Tool not found: \(name)")
        }
        return try await executor(name, arguments)
    }
}

// MARK: - Dynamic Tool Builders

/// Builder for creating dynamic tools programmatically
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct DynamicToolBuilder {
    /// Create a simple string-input, string-output tool
    public static func simpleStringTool(
        name: String,
        description: String,
        parameterName: String = "input",
        parameterDescription: String = "Input string"
    ) -> DynamicTool {
        DynamicTool(
            name: name,
            description: description,
            schema: DynamicSchema(
                type: .object,
                properties: [
                    parameterName: DynamicSchema.SchemaProperty(
                        type: .string,
                        description: parameterDescription
                    )
                ],
                required: [parameterName]
            )
        )
    }
    
    /// Create a tool with multiple parameters
    public static func multiParameterTool(
        name: String,
        description: String,
        parameters: [(name: String, type: DynamicSchema.SchemaType, description: String, required: Bool)]
    ) -> DynamicTool {
        var properties: [String: DynamicSchema.SchemaProperty] = [:]
        var required: [String] = []
        
        for param in parameters {
            properties[param.name] = DynamicSchema.SchemaProperty(
                type: param.type,
                description: param.description
            )
            if param.required {
                required.append(param.name)
            }
        }
        
        return DynamicTool(
            name: name,
            description: description,
            schema: DynamicSchema(
                type: .object,
                properties: properties,
                required: required
            )
        )
    }
}

// MARK: - Dynamic Schema Extensions

extension DynamicSchema.SchemaProperty {
    /// Create a string property with constraints
    public static func string(
        description: String,
        enumValues: [String]? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        format: String? = nil
    ) -> Self {
        Self(
            type: .string,
            description: description,
            enumValues: enumValues,
            format: format,
            minLength: minLength,
            maxLength: maxLength
        )
    }
    
    /// Create a number property with constraints
    public static func number(
        description: String,
        minimum: Double? = nil,
        maximum: Double? = nil
    ) -> Self {
        Self(
            type: .number,
            description: description,
            minimum: minimum,
            maximum: maximum
        )
    }
    
    /// Create an array property
    public static func array(
        description: String,
        items: DynamicSchema.SchemaItems
    ) -> Self {
        Self(
            type: .array,
            description: description,
            items: items
        )
    }
    
    /// Create an object property
    public static func object(
        description: String,
        properties: [String: DynamicSchema.SchemaProperty]? = nil,
        required: [String]? = nil
    ) -> Self {
        Self(
            type: .object,
            description: description,
            properties: properties,
            required: required
        )
    }
}

// MARK: - Composite Dynamic Tool Provider

/// Combines multiple dynamic tool providers into one
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct CompositeDynamicToolProvider: DynamicToolProvider {
    private let providers: [DynamicToolProvider]
    
    public init(providers: [DynamicToolProvider]) {
        self.providers = providers
    }
    
    public func discoverTools() async throws -> [DynamicTool] {
        var allTools: [DynamicTool] = []
        
        for provider in providers {
            let tools = try await provider.discoverTools()
            allTools.append(contentsOf: tools)
        }
        
        return allTools
    }
    
    public func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        // Try each provider until one can execute the tool
        for provider in providers {
            let tools = try await provider.discoverTools()
            if tools.contains(where: { $0.name == name }) {
                return try await provider.executeTool(name: name, arguments: arguments)
            }
        }
        
        throw TachikomaError.toolCallFailed("Tool not found in any provider: \(name)")
    }
}

// MARK: - Filtering Dynamic Tool Provider

/// Wraps a provider and filters its tools based on criteria
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct FilteringDynamicToolProvider: DynamicToolProvider {
    private let baseProvider: DynamicToolProvider
    private let filter: @Sendable (DynamicTool) -> Bool
    
    public init(
        baseProvider: DynamicToolProvider,
        filter: @escaping @Sendable (DynamicTool) -> Bool
    ) {
        self.baseProvider = baseProvider
        self.filter = filter
    }
    
    public func discoverTools() async throws -> [DynamicTool] {
        let allTools = try await baseProvider.discoverTools()
        return allTools.filter(filter)
    }
    
    public func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        // Check if the tool passes the filter
        let tools = try await discoverTools()
        guard tools.contains(where: { $0.name == name }) else {
            throw TachikomaError.toolCallFailed("Tool filtered out or not found: \(name)")
        }
        
        return try await baseProvider.executeTool(name: name, arguments: arguments)
    }
}

// MARK: - Caching Dynamic Tool Provider

/// Wraps a provider and caches tool discovery results
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor CachingDynamicToolProvider: DynamicToolProvider {
    private let baseProvider: DynamicToolProvider
    private var cachedTools: [DynamicTool]?
    private let cacheDuration: TimeInterval
    private var lastCacheTime: Date?
    
    public init(
        baseProvider: DynamicToolProvider,
        cacheDuration: TimeInterval = 60 // 1 minute default
    ) {
        self.baseProvider = baseProvider
        self.cacheDuration = cacheDuration
    }
    
    public func discoverTools() async throws -> [DynamicTool] {
        // Check if cache is valid
        if let cachedTools = cachedTools,
           let lastCacheTime = lastCacheTime,
           Date().timeIntervalSince(lastCacheTime) < cacheDuration {
            return cachedTools
        }
        
        // Refresh cache
        let tools = try await baseProvider.discoverTools()
        cachedTools = tools
        lastCacheTime = Date()
        return tools
    }
    
    public func executeTool(name: String, arguments: AgentToolArguments) async throws -> AnyAgentToolValue {
        // Ensure the tool exists in our cache
        let tools = try await discoverTools()
        guard tools.contains(where: { $0.name == name }) else {
            throw TachikomaError.toolCallFailed("Tool not found: \(name)")
        }
        
        return try await baseProvider.executeTool(name: name, arguments: arguments)
    }
    
    /// Clear the cache
    public func clearCache() {
        cachedTools = nil
        lastCacheTime = nil
    }
}