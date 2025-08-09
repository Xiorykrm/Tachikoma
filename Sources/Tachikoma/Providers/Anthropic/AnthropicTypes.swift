import Foundation

// MARK: - Helper Types

/// A helper type for encoding/decoding Any values in JSON
enum JSONValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null
    
    init?(value: Any) {
        if let string = value as? String {
            self = .string(string)
        } else if let int = value as? Int {
            self = .int(int)
        } else if let double = value as? Double {
            self = .double(double)
        } else if let bool = value as? Bool {
            self = .bool(bool)
        } else if let array = value as? [Any] {
            self = .array(array.compactMap { JSONValue(value: $0) })
        } else if let dict = value as? [String: Any] {
            self = .object(dict.compactMapValues { JSONValue(value: $0) })
        } else if value is NSNull {
            self = .null
        } else {
            return nil
        }
    }
    
    var value: Any {
        switch self {
        case .string(let s): return s
        case .int(let i): return i
        case .double(let d): return d
        case .bool(let b): return b
        case .array(let a): return a.map { $0.value }
        case .object(let o): return o.mapValues { $0.value }
        case .null: return NSNull()
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .string(string)
        } else if let int = try? container.decode(Int.self) {
            self = .int(int)
        } else if let double = try? container.decode(Double.self) {
            self = .double(double)
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let array = try? container.decode([JSONValue].self) {
            self = .array(array)
        } else if let object = try? container.decode([String: JSONValue].self) {
            self = .object(object)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode JSONValue")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let s): try container.encode(s)
        case .int(let i): try container.encode(i)
        case .double(let d): try container.encode(d)
        case .bool(let b): try container.encode(b)
        case .array(let a): try container.encode(a)
        case .object(let o): try container.encode(o)
        case .null: try container.encodeNil()
        }
    }
}

// MARK: - Anthropic API Types

struct AnthropicMessageRequest: Codable {
    let model: String
    let maxTokens: Int
    let temperature: Double?
    let system: String?
    let messages: [AnthropicMessage]
    let tools: [AnthropicTool]?
    let stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model, temperature, system, messages, tools, stream
        case maxTokens = "max_tokens"
    }
}

struct AnthropicMessage: Codable {
    let role: String
    let content: [AnthropicContent]
}

enum AnthropicContent: Codable {
    case text(TextContent)
    case image(ImageContent)
    case toolUse(ToolUseContent)
    case toolResult(ToolResultContent)

    struct TextContent: Codable {
        let type: String
        let text: String
    }

    struct ImageContent: Codable {
        let type: String
        let source: ImageSource
    }

    struct ImageSource: Codable {
        let type: String
        let mediaType: String
        let data: String

        enum CodingKeys: String, CodingKey {
            case type, data
            case mediaType = "media_type"
        }
    }
    
    struct ToolUseContent: Codable {
        let type: String
        let id: String
        let name: String
        let input: [String: Any]
        
        init(type: String = "tool_use", id: String, name: String, input: [String: Any]) {
            self.type = type
            self.id = id
            self.name = name
            self.input = input
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try container.decode(String.self, forKey: .type)
            self.id = try container.decode(String.self, forKey: .id)
            self.name = try container.decode(String.self, forKey: .name)
            
            // Use custom decoder for Any
            let inputDecoder = try container.superDecoder(forKey: .input)
            self.input = try Self.decodeAnyDict(from: inputDecoder)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(type, forKey: .type)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            
            // Use custom encoder for Any
            let inputEncoder = container.superEncoder(forKey: .input)
            try Self.encodeAnyDict(input, to: inputEncoder)
        }
        
        // Helper methods for encoding/decoding [String: Any]
        private static func decodeAnyDict(from decoder: Decoder) throws -> [String: Any] {
            let container = try decoder.singleValueContainer()
            return try container.decode([String: JSONValue].self).mapValues { $0.value }
        }
        
        private static func encodeAnyDict(_ dict: [String: Any], to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            let jsonDict = dict.compactMapValues { JSONValue(value: $0) }
            try container.encode(jsonDict)
        }
        
        enum CodingKeys: String, CodingKey {
            case type, id, name, input
        }
    }
    
    struct ToolResultContent: Codable {
        let type: String
        let toolUseId: String
        let content: String
        
        init(type: String = "tool_result", toolUseId: String, content: String) {
            self.type = type
            self.toolUseId = toolUseId
            self.content = content
        }
        
        enum CodingKeys: String, CodingKey {
            case type
            case toolUseId = "tool_use_id"
            case content
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = try .text(TextContent(from: decoder))
        case "image":
            self = try .image(ImageContent(from: decoder))
        case "tool_use":
            self = try .toolUse(ToolUseContent(from: decoder))
        case "tool_result":
            self = try .toolResult(ToolResultContent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .text(content):
            try content.encode(to: encoder)
        case let .image(content):
            try content.encode(to: encoder)
        case let .toolUse(content):
            try content.encode(to: encoder)
        case let .toolResult(content):
            try content.encode(to: encoder)
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
    }
}

struct AnthropicTool: Codable {
    let name: String
    let description: String
    let inputSchema: AnthropicInputSchema

    enum CodingKeys: String, CodingKey {
        case name, description
        case inputSchema = "input_schema"
    }
}

struct AnthropicInputSchema: Codable {
    let type: String
    let properties: [String: Any]
    let required: [String]

    init(type: String, properties: [String: Any], required: [String]) {
        self.type = type
        self.properties = properties
        self.required = required
    }

    enum CodingKeys: String, CodingKey {
        case type, properties, required
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.required = try container.decode([String].self, forKey: .required)

        if
            let data = try? container.decode(Data.self, forKey: .properties),
            let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        {
            self.properties = dict
        } else {
            self.properties = [:]
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.type, forKey: .type)
        try container.encode(self.required, forKey: .required)

        // Encode properties directly as JSON object, not as base64 data
        var propertiesContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .properties)
        try self.encodeAnyDictionary(self.properties, to: &propertiesContainer)
    }

    private func encodeAnyDictionary(
        _ dict: [String: Any],
        to container: inout KeyedEncodingContainer<AnyCodingKey>
    ) throws {
        for (key, value) in dict {
            let codingKey = AnyCodingKey(stringValue: key)!

            switch value {
            case let stringValue as String:
                try container.encode(stringValue, forKey: codingKey)
            case let intValue as Int:
                try container.encode(intValue, forKey: codingKey)
            case let doubleValue as Double:
                try container.encode(doubleValue, forKey: codingKey)
            case let boolValue as Bool:
                try container.encode(boolValue, forKey: codingKey)
            case let arrayValue as [Any]:
                // Encode arrays properly as actual arrays, not JSON strings
                var arrayContainer = container.nestedUnkeyedContainer(forKey: codingKey)
                for element in arrayValue {
                    try encodeAnyElement(element, to: &arrayContainer)
                }
            case let dictValue as [String: Any]:
                // Encode nested objects properly as nested containers
                var nestedContainer = container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: codingKey)
                try self.encodeAnyDictionary(dictValue, to: &nestedContainer)
            default:
                // Fallback: convert to string
                try container.encode(String(describing: value), forKey: codingKey)
            }
        }
    }
    
    private func encodeAnyElement(_ value: Any, to container: inout UnkeyedEncodingContainer) throws {
        switch value {
        case let stringValue as String:
            try container.encode(stringValue)
        case let intValue as Int:
            try container.encode(intValue)
        case let doubleValue as Double:
            try container.encode(doubleValue)
        case let boolValue as Bool:
            try container.encode(boolValue)
        case let arrayValue as [Any]:
            // Nested arrays
            var nestedContainer = container.nestedUnkeyedContainer()
            for element in arrayValue {
                try encodeAnyElement(element, to: &nestedContainer)
            }
        case let dictValue as [String: Any]:
            // Dictionary within array
            var nestedContainer = container.nestedContainer(keyedBy: AnyCodingKey.self)
            try encodeAnyDictionary(dictValue, to: &nestedContainer)
        default:
            // Fallback: convert to string
            try container.encode(String(describing: value))
        }
    }
}

struct AnthropicMessageResponse: Codable {
    let id: String
    let type: String
    let role: String
    let content: [AnthropicResponseContent]
    let model: String
    let stopReason: String?
    let stopSequence: String?
    let usage: AnthropicUsage

    enum CodingKeys: String, CodingKey {
        case id, type, role, content, model, usage
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

enum AnthropicResponseContent: Codable {
    case text(TextContent)
    case toolUse(ToolUseContent)

    struct TextContent: Codable {
        let type: String
        let text: String
    }

    struct ToolUseContent: Codable {
        let type: String
        let id: String
        let name: String
        let input: Any

        enum CodingKeys: String, CodingKey {
            case type, id, name, input
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.type = try container.decode(String.self, forKey: .type)
            self.id = try container.decode(String.self, forKey: .id)
            self.name = try container.decode(String.self, forKey: .name)

            // Decode input as generic value
            // Try to decode directly as a JSON object first (standard Anthropic API format)
            if container.contains(.input) {
                // Use a nestedContainer to get the raw JSON value
                do {
                    let inputContainer = try container.nestedContainer(keyedBy: AnyCodingKey.self, forKey: .input)
                    // Convert the nested container to a dictionary
                    var inputDict: [String: Any] = [:]
                    for key in inputContainer.allKeys {
                        if let stringValue = try? inputContainer.decode(String.self, forKey: key) {
                            inputDict[key.stringValue] = stringValue
                        } else if let intValue = try? inputContainer.decode(Int.self, forKey: key) {
                            inputDict[key.stringValue] = intValue
                        } else if let doubleValue = try? inputContainer.decode(Double.self, forKey: key) {
                            inputDict[key.stringValue] = doubleValue
                        } else if let boolValue = try? inputContainer.decode(Bool.self, forKey: key) {
                            inputDict[key.stringValue] = boolValue
                        }
                        // Add more types as needed
                    }
                    self.input = inputDict
                } catch {
                    // Fallback to the old Data-based approach
                    if
                        let data = try? container.decode(Data.self, forKey: .input),
                        let obj = try? JSONSerialization.jsonObject(with: data)
                    {
                        self.input = obj
                    } else {
                        self.input = [:]
                    }
                }
            } else {
                self.input = [:]
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.type, forKey: .type)
            try container.encode(self.id, forKey: .id)
            try container.encode(self.name, forKey: .name)

            let data = try JSONSerialization.data(withJSONObject: self.input)
            try container.encode(data, forKey: .input)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)

        switch type {
        case "text":
            self = try .text(TextContent(from: decoder))
        case "tool_use":
            self = try .toolUse(ToolUseContent(from: decoder))
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown content type: \(type)"
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .text(content):
            try content.encode(to: encoder)
        case let .toolUse(content):
            try content.encode(to: encoder)
        }
    }

    enum CodingKeys: String, CodingKey {
        case type
    }
}

struct AnthropicUsage: Codable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}

// MARK: - Streaming Types

struct AnthropicStreamEvent: Codable {
    let type: String
    let message: AnthropicStreamMessage?
    let index: Int?
    let contentBlock: AnthropicStreamContentBlock?
    let delta: AnthropicStreamDelta?
    let usage: AnthropicUsage?
    
    enum CodingKeys: String, CodingKey {
        case type, message, index
        case contentBlock = "content_block"
        case delta, usage
    }
}

struct AnthropicStreamMessage: Codable {
    let id: String
    let type: String
    let role: String?
    let model: String?
    let usage: AnthropicUsage?
}

struct AnthropicStreamContentBlock: Codable {
    let type: String
    let id: String?
    let name: String?
    let text: String?
    let input: Any?
    
    enum CodingKeys: String, CodingKey {
        case type, id, name, text, input
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.type = try container.decode(String.self, forKey: .type)
        self.id = try? container.decode(String.self, forKey: .id)
        self.name = try? container.decode(String.self, forKey: .name)
        self.text = try? container.decode(String.self, forKey: .text)
        
        // Decode input as generic JSON if present
        if container.contains(.input) {
            // Try to decode as Data and convert to JSON object
            if let data = try? container.decode(Data.self, forKey: .input),
               let obj = try? JSONSerialization.jsonObject(with: data) {
                self.input = obj
            } else {
                self.input = nil
            }
        } else {
            self.input = nil
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(text, forKey: .text)
        if let input = input {
            let data = try JSONSerialization.data(withJSONObject: input)
            try container.encode(data, forKey: .input)
        }
    }
}

struct AnthropicStreamDelta: Codable {
    let type: String
    let text: String?
    let partialJson: String?
    let stopReason: String?
    let stopSequence: String?
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case partialJson = "partial_json"
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
    }
}

struct AnthropicErrorResponse: Codable {
    let type: String
    let error: Error

    struct Error: Codable {
        let type: String
        let message: String
    }
}

