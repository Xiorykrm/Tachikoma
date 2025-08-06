//
//  RealtimeToolExecutor.swift
//  Tachikoma
//

import Foundation

// MARK: - Realtime Tool Executor

/// Executes tools in response to function calls from the Realtime API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor RealtimeToolExecutor {
    // MARK: - Properties
    
    private var tools: [String: RealtimeToolWrapper] = [:]
    private var executionHistory: [ToolExecution] = []
    private let maxHistorySize = 100
    
    // MARK: - Types
    
    /// Wrapper for a tool with metadata
    private struct RealtimeToolWrapper {
        let tool: any RealtimeExecutableTool
        let metadata: ToolMetadata
    }
    
    /// Metadata about a tool
    public struct ToolMetadata: Sendable {
        public let name: String
        public let description: String
        public let version: String
        public let category: ToolCategory
        public let parameters: AgentToolParameters
        
        public enum ToolCategory: String, Sendable {
            case utility
            case information
            case calculation
            case system
            case custom
        }
        
        public init(
            name: String,
            description: String,
            version: String = "1.0.0",
            category: ToolCategory = .custom,
            parameters: AgentToolParameters
        ) {
            self.name = name
            self.description = description
            self.version = version
            self.category = category
            self.parameters = parameters
        }
    }
    
    /// Record of a tool execution
    public struct ToolExecution: Sendable, Codable {
        public let id: String
        public let toolName: String
        public let arguments: String
        public let result: ExecutionResult
        public let timestamp: Date
        public let duration: TimeInterval
        
        public enum ExecutionResult: Sendable, Codable {
            case success(String)
            case failure(String)
            case timeout
        }
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Tool Registration
    
    /// Register a tool for execution
    public func register<T: RealtimeExecutableTool>(_ tool: T) {
        let metadata = tool.metadata
        tools[metadata.name] = RealtimeToolWrapper(
            tool: tool,
            metadata: metadata
        )
    }
    
    /// Register multiple tools
    public func registerTools<T: RealtimeExecutableTool>(_ tools: [T]) {
        for tool in tools {
            register(tool)
        }
    }
    
    /// Unregister a tool
    public func unregister(toolName: String) {
        tools.removeValue(forKey: toolName)
    }
    
    /// Get all registered tools
    public func availableTools() -> [ToolMetadata] {
        tools.values.map { $0.metadata }
    }
    
    /// Get tool metadata
    public func getToolMetadata(name: String) -> ToolMetadata? {
        tools[name]?.metadata
    }
    
    // MARK: - Tool Execution
    
    /// Execute a tool by name with arguments
    public func execute(
        toolName: String,
        arguments: String,
        timeout: TimeInterval = 30
    ) async -> ToolExecution {
        let startTime = Date()
        let executionId = UUID().uuidString
        
        // Find the tool
        guard let wrapper = tools[toolName] else {
            let execution = ToolExecution(
                id: executionId,
                toolName: toolName,
                arguments: arguments,
                result: .failure("Tool '\(toolName)' not found"),
                timestamp: startTime,
                duration: Date().timeIntervalSince(startTime)
            )
            addToHistory(execution)
            return execution
        }
        
        // Parse arguments
        let parsedArgs: RealtimeToolArguments
        do {
            parsedArgs = try parseArguments(arguments, for: wrapper.metadata.parameters)
        } catch {
            let execution = ToolExecution(
                id: executionId,
                toolName: toolName,
                arguments: arguments,
                result: .failure("Failed to parse arguments: \(error)"),
                timestamp: startTime,
                duration: Date().timeIntervalSince(startTime)
            )
            addToHistory(execution)
            return execution
        }
        
        // Execute with timeout
        let task = Task {
            await wrapper.tool.execute(parsedArgs)
        }
        
        let result: String
        do {
            // Create timeout task
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                task.cancel()
            }
            
            // Wait for result
            result = try await withTaskCancellationHandler {
                let executionResult = await task.value
                timeoutTask.cancel()
                return executionResult
            } onCancel: {
                task.cancel()
                timeoutTask.cancel()
            }
        } catch {
            if task.isCancelled {
                let execution = ToolExecution(
                    id: executionId,
                    toolName: toolName,
                    arguments: arguments,
                    result: .timeout,
                    timestamp: startTime,
                    duration: Date().timeIntervalSince(startTime)
                )
                addToHistory(execution)
                return execution
            } else {
                let execution = ToolExecution(
                    id: executionId,
                    toolName: toolName,
                    arguments: arguments,
                    result: .failure("Execution failed: \(error)"),
                    timestamp: startTime,
                    duration: Date().timeIntervalSince(startTime)
                )
                addToHistory(execution)
                return execution
            }
        }
        
        // Success
        let execution = ToolExecution(
            id: executionId,
            toolName: toolName,
            arguments: arguments,
            result: .success(result),
            timestamp: startTime,
            duration: Date().timeIntervalSince(startTime)
        )
        addToHistory(execution)
        return execution
    }
    
    /// Execute a tool and return just the result string
    public func executeSimple(
        toolName: String,
        arguments: String,
        timeout: TimeInterval = 30
    ) async -> String {
        let execution = await execute(
            toolName: toolName,
            arguments: arguments,
            timeout: timeout
        )
        
        switch execution.result {
        case .success(let result):
            return result
        case .failure(let error):
            return "Error: \(error)"
        case .timeout:
            return "Error: Tool execution timed out"
        }
    }
    
    // MARK: - History Management
    
    /// Get execution history
    public func getHistory(limit: Int? = nil) -> [ToolExecution] {
        if let limit = limit {
            return Array(executionHistory.suffix(limit))
        }
        return executionHistory
    }
    
    /// Clear execution history
    public func clearHistory() {
        executionHistory.removeAll()
    }
    
    private func addToHistory(_ execution: ToolExecution) {
        executionHistory.append(execution)
        
        // Trim history if needed
        if executionHistory.count > maxHistorySize {
            executionHistory.removeFirst(executionHistory.count - maxHistorySize)
        }
    }
    
    // MARK: - Private Methods
    
    private func parseArguments(
        _ jsonString: String,
        for parameters: AgentToolParameters
    ) throws -> RealtimeToolArguments {
        guard let data = jsonString.data(using: .utf8) else {
            throw TachikomaError.invalidInput("Invalid JSON string")
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        var arguments = RealtimeToolArguments()
        
        // Parse each parameter
        for (key, value) in json {
            guard let parameterDef = parameters.properties[key] else {
                // Skip unknown parameters
                continue
            }
            
            // Convert based on type
            switch parameterDef.type {
            case .string:
                if let stringValue = value as? String {
                    arguments[key] = .string(stringValue)
                }
            case .number:
                if let numberValue = value as? Double {
                    arguments[key] = .number(numberValue)
                } else if let intValue = value as? Int {
                    arguments[key] = .number(Double(intValue))
                }
            case .integer:
                if let intValue = value as? Int {
                    arguments[key] = .integer(intValue)
                }
            case .boolean:
                if let boolValue = value as? Bool {
                    arguments[key] = .boolean(boolValue)
                }
            case .array:
                if let arrayValue = value as? [Any] {
                    // Convert array elements
                    let convertedArray = arrayValue.compactMap { element -> RealtimeToolArgument? in
                        if let string = element as? String {
                            return .string(string)
                        } else if let number = element as? Double {
                            return .number(number)
                        } else if let int = element as? Int {
                            return .number(Double(int))
                        } else if let bool = element as? Bool {
                            return .boolean(bool)
                        }
                        return nil
                    }
                    arguments[key] = .array(convertedArray)
                }
            case .object:
                if let dictValue = value as? [String: Any] {
                    // For simplicity, convert to JSON string
                    if let jsonData = try? JSONSerialization.data(withJSONObject: dictValue),
                       let jsonString = String(data: jsonData, encoding: .utf8) {
                        arguments[key] = .object(jsonString)
                    }
                }
            case .null:
                // null type doesn't need a value
                break
            }
        }
        
        // Validate required parameters
        for requiredParam in parameters.required {
            if arguments[requiredParam] == nil {
                throw TachikomaError.invalidInput("Missing required parameter: \(requiredParam)")
            }
        }
        
        return arguments
    }
}

// MARK: - Protocol for Executable Tools

/// Protocol for tools that can be executed by the Realtime API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol RealtimeExecutableTool: Sendable {
    /// Tool metadata
    var metadata: RealtimeToolExecutor.ToolMetadata { get }
    
    /// Execute the tool with given arguments
    func execute(_ arguments: RealtimeToolArguments) async -> String
}

// MARK: - Tool Arguments

/// Type-safe tool arguments for Realtime API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public typealias RealtimeToolArguments = [String: RealtimeToolArgument]

/// Individual tool argument value for Realtime API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum RealtimeToolArgument: Sendable, Codable {
    case string(String)
    case number(Double)
    case integer(Int)
    case boolean(Bool)
    case array([RealtimeToolArgument])
    case object(String) // JSON string for complex objects
    
    /// Get string value if available
    public var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }
    
    /// Get number value if available
    public var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }
    
    /// Get integer value if available
    public var integerValue: Int? {
        if case .integer(let value) = self { return value }
        return nil
    }
    
    /// Get boolean value if available
    public var booleanValue: Bool? {
        if case .boolean(let value) = self { return value }
        return nil
    }
    
    /// Get array value if available
    public var arrayValue: [RealtimeToolArgument]? {
        if case .array(let value) = self { return value }
        return nil
    }
    
    /// Get object value if available
    public var objectValue: String? {
        if case .object(let value) = self { return value }
        return nil
    }
}
