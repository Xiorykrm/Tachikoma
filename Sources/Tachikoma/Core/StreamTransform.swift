//
//  StreamTransform.swift
//  Tachikoma
//

import Foundation

// MARK: - Stream Transform Pipeline

/// Protocol for transforming stream elements
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public protocol StreamTransform: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable
    
    func transform(_ input: Input) async throws -> Output?
}

/// A transform that filters stream elements
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct FilterTransform<T: Sendable>: StreamTransform {
    public typealias Input = T
    public typealias Output = T
    
    private let predicate: @Sendable (T) async -> Bool
    
    public init(predicate: @escaping @Sendable (T) async -> Bool) {
        self.predicate = predicate
    }
    
    public func transform(_ input: T) async throws -> T? {
        await predicate(input) ? input : nil
    }
}

/// A transform that maps stream elements
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct MapTransform<Input: Sendable, Output: Sendable>: StreamTransform {
    private let mapper: @Sendable (Input) async throws -> Output
    
    public init(mapper: @escaping @Sendable (Input) async throws -> Output) {
        self.mapper = mapper
    }
    
    public func transform(_ input: Input) async throws -> Output? {
        try await mapper(input)
    }
}

/// A transform that buffers and batches stream elements
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor BufferTransform<T: Sendable>: StreamTransform {
    public typealias Input = T
    public typealias Output = [T]
    
    private let bufferSize: Int
    private let flushInterval: TimeInterval?
    private var buffer: [T] = []
    private var lastFlush = Date()
    
    public init(bufferSize: Int, flushInterval: TimeInterval? = nil) {
        self.bufferSize = bufferSize
        self.flushInterval = flushInterval
    }
    
    public func transform(_ input: T) async throws -> [T]? {
        buffer.append(input)
        
        let shouldFlush = buffer.count >= bufferSize ||
            (flushInterval != nil && Date().timeIntervalSince(lastFlush) >= flushInterval!)
        
        if shouldFlush {
            let result = buffer
            buffer = []
            lastFlush = Date()
            return result
        }
        
        return nil
    }
    
    public func flush() async -> [T]? {
        guard !buffer.isEmpty else { return nil }
        let result = buffer
        buffer = []
        lastFlush = Date()
        return result
    }
}

/// A transform that throttles stream elements
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public actor ThrottleTransform<T: Sendable>: StreamTransform {
    public typealias Input = T
    public typealias Output = T
    
    private let interval: TimeInterval
    private var lastEmit: Date?
    
    public init(interval: TimeInterval) {
        self.interval = interval
    }
    
    public func transform(_ input: T) async throws -> T? {
        let now = Date()
        
        if let lastEmit, now.timeIntervalSince(lastEmit) < interval {
            return nil
        }
        
        lastEmit = now
        return input
    }
}

/// A transform that adds side effects without changing the stream
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TapTransform<T: Sendable>: StreamTransform {
    public typealias Input = T
    public typealias Output = T
    
    private let action: @Sendable (T) async -> Void
    
    public init(action: @escaping @Sendable (T) async -> Void) {
        self.action = action
    }
    
    public func transform(_ input: T) async throws -> T? {
        await action(input)
        return input
    }
}

// MARK: - Stream Extensions

/// Extensions for applying transforms to streams
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension AsyncThrowingStream where Element: Sendable {
    /// Apply a transform to the stream
    func transform<T: StreamTransform>(
        _ transform: T
    ) -> AsyncThrowingStream<T.Output, Error>
    where Element == T.Input {
        AsyncThrowingStream<T.Output, Error> { continuation in
            Task {
                do {
                    for try await element in self {
                        if let output = try await transform.transform(element) {
                            continuation.yield(output)
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Filter stream elements
    func filter(
        _ predicate: @escaping @Sendable (Element) async -> Bool
    ) -> AsyncThrowingStream<Element, Error> {
        transform(FilterTransform(predicate: predicate))
    }
    
    /// Map stream elements
    func map<Output: Sendable>(
        _ mapper: @escaping @Sendable (Element) async throws -> Output
    ) -> AsyncThrowingStream<Output, Error> {
        transform(MapTransform(mapper: mapper))
    }
    
    /// Add side effects to stream
    func tap(
        _ action: @escaping @Sendable (Element) async -> Void
    ) -> AsyncThrowingStream<Element, Error> {
        transform(TapTransform(action: action))
    }
    
    /// Buffer and batch stream elements
    func buffer(
        size: Int,
        flushInterval: TimeInterval? = nil
    ) -> AsyncThrowingStream<[Element], Error> {
        let bufferTransform = BufferTransform<Element>(
            bufferSize: size,
            flushInterval: flushInterval
        )
        
        return AsyncThrowingStream<[Element], Error> { continuation in
            Task {
                do {
                    for try await element in self {
                        if let batch = try await bufferTransform.transform(element) {
                            continuation.yield(batch)
                        }
                    }
                    // Flush any remaining buffered elements
                    if let remaining = await bufferTransform.flush() {
                        continuation.yield(remaining)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    /// Throttle stream elements
    func throttle(
        interval: TimeInterval
    ) -> AsyncThrowingStream<Element, Error> {
        transform(ThrottleTransform(interval: interval))
    }
}

// MARK: - StreamTextResult Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension StreamTextResult {
    /// Filter text deltas
    func filter(
        _ predicate: @escaping @Sendable (TextStreamDelta) async -> Bool
    ) -> StreamTextResult {
        StreamTextResult(
            stream: textStream.filter(predicate),
            model: model,
            settings: settings
        )
    }
    
    /// Map text deltas
    func map<Output: Sendable>(
        _ mapper: @escaping @Sendable (TextStreamDelta) async throws -> Output
    ) -> AsyncThrowingStream<Output, Error> {
        textStream.map(mapper)
    }
    
    /// Add side effects to text stream
    func tap(
        _ action: @escaping @Sendable (TextStreamDelta) async -> Void
    ) -> StreamTextResult {
        StreamTextResult(
            stream: textStream.tap(action),
            model: model,
            settings: settings
        )
    }
    
    /// Collect only text content from the stream
    func collectText() -> AsyncThrowingStream<String, Error> {
        textStream
            .filter { delta in
                if case .textDelta = delta.type {
                    return delta.content != nil
                }
                return false
            }
            .map { delta in
                delta.content ?? ""
            }
    }
    
    /// Collect complete text once stream is done
    func fullText() async throws -> String {
        var result = ""
        for try await delta in textStream {
            if case .textDelta = delta.type, let content = delta.content {
                result += content
            }
        }
        return result
    }
}

// MARK: - StreamObjectResult Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension StreamObjectResult {
    /// Filter object deltas
    func filter(
        _ predicate: @escaping @Sendable (ObjectStreamDelta<T>) async -> Bool
    ) -> StreamObjectResult<T> {
        StreamObjectResult(
            objectStream: objectStream.filter(predicate),
            model: model,
            settings: settings,
            schema: schema
        )
    }
    
    /// Map object deltas
    func map<Output: Sendable>(
        _ mapper: @escaping @Sendable (ObjectStreamDelta<T>) async throws -> Output
    ) -> AsyncThrowingStream<Output, Error> {
        objectStream.map(mapper)
    }
    
    /// Add side effects to object stream
    func tap(
        _ action: @escaping @Sendable (ObjectStreamDelta<T>) async -> Void
    ) -> StreamObjectResult<T> {
        StreamObjectResult(
            objectStream: objectStream.tap(action),
            model: model,
            settings: settings,
            schema: schema
        )
    }
    
    /// Collect only partial objects from the stream
    func partialObjects() -> AsyncThrowingStream<T, Error> {
        objectStream
            .filter { delta in
                delta.type == .partial && delta.object != nil
            }
            .map { delta in
                delta.object!
            }
    }
    
    /// Get the final complete object
    func finalObject() async throws -> T {
        for try await delta in objectStream {
            if case .complete = delta.type, let object = delta.object {
                return object
            }
        }
        throw TachikomaError.invalidInput("No complete object received in stream")
    }
}

// MARK: - Composable Transform Chains

/// A composable chain of transforms
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct TransformChain<Input: Sendable, Output: Sendable>: StreamTransform {
    private let transforms: [@Sendable (Input) async throws -> Output?]
    
    public init(transforms: [@Sendable (Input) async throws -> Output?]) {
        self.transforms = transforms
    }
    
    public func transform(_ input: Input) async throws -> Output? {
        var current: Any = input
        
        for transform in transforms {
            guard let transformInput = current as? Input else {
                return nil
            }
            
            if let result = try await transform(transformInput) {
                current = result
            } else {
                return nil
            }
        }
        
        return current as? Output
    }
}

// MARK: - Transform Builder

/// Result builder for composing stream transforms
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
@resultBuilder
public struct TransformBuilder {
    public static func buildBlock<T: StreamTransform>(_ transform: T) -> T {
        transform
    }
    
    public static func buildBlock<T1: StreamTransform, T2: StreamTransform>(
        _ t1: T1,
        _ t2: T2
    ) -> some StreamTransform where T1.Output == T2.Input {
        CombinedTransform(first: t1, second: t2)
    }
}

/// A combination of two transforms
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct CombinedTransform<T1: StreamTransform, T2: StreamTransform>: StreamTransform
where T1.Output == T2.Input {
    public typealias Input = T1.Input
    public typealias Output = T2.Output
    
    private let first: T1
    private let second: T2
    
    public init(first: T1, second: T2) {
        self.first = first
        self.second = second
    }
    
    public func transform(_ input: Input) async throws -> Output? {
        guard let intermediate = try await first.transform(input) else {
            return nil
        }
        return try await second.transform(intermediate)
    }
}