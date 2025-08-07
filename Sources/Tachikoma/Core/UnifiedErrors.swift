//
//  UnifiedErrors.swift
//  Tachikoma
//

import Foundation

// MARK: - Unified Error System

/// Unified error type for all Tachikoma operations
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TachikomaUnifiedError: Error, LocalizedError, Sendable {
    public let code: ErrorCode
    public let message: String
    public let details: ErrorDetails?
    public let underlyingError: Error?
    public let recovery: RecoverySuggestion?
    
    public init(
        code: ErrorCode,
        message: String,
        details: ErrorDetails? = nil,
        underlyingError: Error? = nil,
        recovery: RecoverySuggestion? = nil
    ) {
        self.code = code
        self.message = message
        self.details = details
        self.underlyingError = underlyingError
        self.recovery = recovery
    }
    
    public var errorDescription: String? {
        var description = "[\(code.category.rawValue):\(code.rawValue)] \(message)"
        if let recovery = recovery {
            description += "\n💡 \(recovery.suggestion)"
        }
        return description
    }
    
    public var failureReason: String? {
        details?.reason
    }
    
    public var recoverySuggestion: String? {
        recovery?.suggestion
    }
    
    public var helpAnchor: String? {
        recovery?.helpURL
    }
}

// MARK: - Error Codes

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ErrorCode: Sendable, Equatable {
    public let category: ErrorCategory
    public let rawValue: String
    
    public init(category: ErrorCategory, code: String) {
        self.category = category
        self.rawValue = "\(category.rawValue)_\(code)"
    }
    
    // Common error codes
    public static let invalidRequest = ErrorCode(category: .validation, code: "invalid_request")
    public static let missingParameter = ErrorCode(category: .validation, code: "missing_parameter")
    public static let invalidParameter = ErrorCode(category: .validation, code: "invalid_parameter")
    
    public static let authenticationFailed = ErrorCode(category: .authentication, code: "auth_failed")
    public static let invalidAPIKey = ErrorCode(category: .authentication, code: "invalid_api_key")
    public static let expiredToken = ErrorCode(category: .authentication, code: "expired_token")
    
    public static let rateLimited = ErrorCode(category: .rateLimit, code: "rate_limited")
    public static let quotaExceeded = ErrorCode(category: .rateLimit, code: "quota_exceeded")
    
    public static let modelNotFound = ErrorCode(category: .model, code: "not_found")
    public static let modelUnavailable = ErrorCode(category: .model, code: "unavailable")
    public static let unsupportedFeature = ErrorCode(category: .model, code: "unsupported_feature")
    
    public static let networkError = ErrorCode(category: .network, code: "connection_failed")
    public static let timeout = ErrorCode(category: .network, code: "timeout")
    public static let serverError = ErrorCode(category: .network, code: "server_error")
    
    public static let toolExecutionFailed = ErrorCode(category: .tool, code: "execution_failed")
    public static let toolNotFound = ErrorCode(category: .tool, code: "not_found")
    public static let toolTimeout = ErrorCode(category: .tool, code: "timeout")
    
    public static let parsingError = ErrorCode(category: .parsing, code: "parse_failed")
    public static let invalidJSON = ErrorCode(category: .parsing, code: "invalid_json")
    public static let invalidResponse = ErrorCode(category: .parsing, code: "invalid_response")
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum ErrorCategory: String, Sendable {
    case validation
    case authentication
    case rateLimit
    case model
    case network
    case tool
    case parsing
    case `internal`
}

// MARK: - Error Details

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct ErrorDetails: Sendable {
    public let reason: String?
    public let statusCode: Int?
    public let responseBody: String?
    public let provider: String?
    public let modelId: String?
    public let requestId: String?
    public let retryAfter: TimeInterval?
    public let metadata: [String: String]
    
    public init(
        reason: String? = nil,
        statusCode: Int? = nil,
        responseBody: String? = nil,
        provider: String? = nil,
        modelId: String? = nil,
        requestId: String? = nil,
        retryAfter: TimeInterval? = nil,
        metadata: [String: String] = [:]
    ) {
        self.reason = reason
        self.statusCode = statusCode
        self.responseBody = responseBody
        self.provider = provider
        self.modelId = modelId
        self.requestId = requestId
        self.retryAfter = retryAfter
        self.metadata = metadata
    }
}

// MARK: - Recovery Suggestions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct RecoverySuggestion: Sendable {
    public let suggestion: String
    public let actions: [RecoveryAction]
    public let helpURL: String?
    
    public init(
        suggestion: String,
        actions: [RecoveryAction] = [],
        helpURL: String? = nil
    ) {
        self.suggestion = suggestion
        self.actions = actions
        self.helpURL = helpURL
    }
    
    // Common recovery suggestions
    public static let checkAPIKey = RecoverySuggestion(
        suggestion: "Check that your API key is valid and has the necessary permissions",
        actions: [.validateAPIKey, .regenerateAPIKey],
        helpURL: "https://docs.tachikoma.ai/errors/authentication"
    )
    
    public static let retryLater = RecoverySuggestion(
        suggestion: "The service is temporarily unavailable. Please try again later",
        actions: [.retry(after: 60)]
    )
    
    public static let upgradeModel = RecoverySuggestion(
        suggestion: "This feature requires a more capable model",
        actions: [.selectDifferentModel]
    )
    
    public static let checkNetwork = RecoverySuggestion(
        suggestion: "Check your network connection and try again",
        actions: [.retry(after: 5)]
    )
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public enum RecoveryAction: Sendable {
    case retry(after: TimeInterval)
    case validateAPIKey
    case regenerateAPIKey
    case selectDifferentModel
    case reduceRequestSize
    case checkDocumentation
    case contactSupport
}

// MARK: - Error Conversion

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension TachikomaError {
    /// Convert legacy error to unified error
    func toUnifiedError() -> TachikomaUnifiedError {
        switch self {
        case .modelNotFound(let model):
            return TachikomaUnifiedError(
                code: .modelNotFound,
                message: "Model '\(model)' not found",
                details: ErrorDetails(modelId: model),
                recovery: RecoverySuggestion(
                    suggestion: "Check the model name or use a different model",
                    actions: [.selectDifferentModel]
                )
            )
            
        case .invalidConfiguration(let message):
            return TachikomaUnifiedError(
                code: .invalidRequest,
                message: message,
                recovery: RecoverySuggestion(
                    suggestion: "Review your configuration settings",
                    actions: [.checkDocumentation]
                )
            )
            
        case .unsupportedOperation(let operation):
            return TachikomaUnifiedError(
                code: .unsupportedFeature,
                message: "Operation '\(operation)' is not supported",
                recovery: .upgradeModel
            )
            
        case .apiError(let message):
            return TachikomaUnifiedError(
                code: .serverError,
                message: message,
                recovery: .retryLater
            )
            
        case .networkError(let error):
            return TachikomaUnifiedError(
                code: .networkError,
                message: "Network error occurred",
                underlyingError: error,
                recovery: .checkNetwork
            )
            
        case .toolCallFailed(let message):
            return TachikomaUnifiedError(
                code: .toolExecutionFailed,
                message: message
            )
            
        case .invalidInput(let message):
            return TachikomaUnifiedError(
                code: .invalidParameter,
                message: message
            )
            
        case .rateLimited(let retryAfter):
            return TachikomaUnifiedError(
                code: .rateLimited,
                message: "Rate limit exceeded",
                details: ErrorDetails(retryAfter: retryAfter),
                recovery: RecoverySuggestion(
                    suggestion: "You've exceeded the rate limit. Please wait before retrying",
                    actions: [.retry(after: retryAfter ?? 60)]
                )
            )
            
        case .authenticationFailed(let message):
            return TachikomaUnifiedError(
                code: .authenticationFailed,
                message: message,
                recovery: .checkAPIKey
            )
            
        case .apiCallError(let apiError):
            return TachikomaUnifiedError(
                code: ErrorCode(category: .network, code: apiError.errorType.rawValue),
                message: apiError.message,
                details: ErrorDetails(
                    statusCode: apiError.statusCode,
                    responseBody: apiError.responseBody,
                    provider: apiError.provider,
                    modelId: apiError.modelId,
                    requestId: apiError.requestId,
                    retryAfter: apiError.retryAfter
                )
            )
            
        case .retryError(let retryError):
            return TachikomaUnifiedError(
                code: .serverError,
                message: retryError.lastError?.localizedDescription ?? "Retry failed",
                details: ErrorDetails(
                    reason: "Failed after \(retryError.attempts) attempts"
                ),
                underlyingError: retryError.lastError
            )
        }
    }
}

// MARK: - Error Helpers

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension Error {
    /// Convert any error to unified error
    func toTachikomaError() -> TachikomaUnifiedError {
        if let unified = self as? TachikomaUnifiedError {
            return unified
        }
        
        if let tachikoma = self as? TachikomaError {
            return tachikoma.toUnifiedError()
        }
        
        if let modelError = self as? ModelError {
            return modelError.toUnifiedError()
        }
        
        if let toolError = self as? AgentToolError {
            return toolError.toUnifiedError()
        }
        
        // Generic error conversion
        return TachikomaUnifiedError(
            code: .serverError,
            message: self.localizedDescription,
            underlyingError: self
        )
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension ModelError {
    func toUnifiedError() -> TachikomaUnifiedError {
        switch self {
        case .invalidRequest(let message):
            return TachikomaUnifiedError(code: .invalidRequest, message: message)
        case .authenticationFailed(let message):
            return TachikomaUnifiedError(code: .authenticationFailed, message: message, recovery: .checkAPIKey)
        case .rateLimited(let retryAfter):
            return TachikomaUnifiedError(
                code: .rateLimited,
                message: "Rate limited",
                details: ErrorDetails(retryAfter: retryAfter),
                recovery: RecoverySuggestion(
                    suggestion: "Wait before retrying",
                    actions: [.retry(after: retryAfter ?? 60)]
                )
            )
        case .modelNotFound(let model):
            return TachikomaUnifiedError(code: .modelNotFound, message: "Model not found: \(model)")
        case .apiError(let statusCode, let message):
            return TachikomaUnifiedError(
                code: .serverError,
                message: message,
                details: ErrorDetails(statusCode: statusCode)
            )
        case .networkError(let error):
            return TachikomaUnifiedError(code: .networkError, message: "Network error", underlyingError: error)
        case .responseParsingError(let message):
            return TachikomaUnifiedError(code: .parsingError, message: message)
        case .unsupportedFeature(let feature):
            return TachikomaUnifiedError(code: .unsupportedFeature, message: "Unsupported: \(feature)")
        }
    }
}

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
extension AgentToolError {
    func toUnifiedError() -> TachikomaUnifiedError {
        switch self {
        case .missingParameter(let param):
            return TachikomaUnifiedError(
                code: .missingParameter,
                message: "Missing required parameter: \(param)"
            )
        case .invalidParameterType(let param, let expected, let actual):
            return TachikomaUnifiedError(
                code: .invalidParameter,
                message: "Invalid type for '\(param)': expected \(expected), got \(actual)"
            )
        case .executionFailed(let message):
            return TachikomaUnifiedError(code: .toolExecutionFailed, message: message)
        case .invalidInput(let message):
            return TachikomaUnifiedError(code: .invalidParameter, message: message)
        }
    }
}