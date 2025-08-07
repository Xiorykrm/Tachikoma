//
//  AsyncSequenceTests.swift
//  TachikomaTests
//

import Testing
@testable import Tachikoma

@Suite("AsyncSequence Conformance Tests")
struct AsyncSequenceTests {
    
    @Test("StreamTextResult conforms to AsyncSequence")
    func testStreamTextResultAsyncSequence() async throws {
        // Create a test stream
        let testStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                continuation.yield(TextStreamDelta(type: .textDelta, content: "Hello"))
                continuation.yield(TextStreamDelta(type: .textDelta, content: " "))
                continuation.yield(TextStreamDelta(type: .textDelta, content: "World"))
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }
        
        let result = StreamTextResult(
            stream: testStream,
            model: .openai(.gpt4o),
            settings: .default
        )
        
        // Test AsyncSequence iteration
        var contents: [String] = []
        for try await delta in result {
            if case .textDelta = delta.type, let content = delta.content {
                contents.append(content)
            }
        }
        
        #expect(contents == ["Hello", " ", "World"])
    }
    
    @Test("StreamTextResult can be iterated multiple ways")
    func testMultipleIterationStyles() async throws {
        let testStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                for i in 1...3 {
                    continuation.yield(TextStreamDelta(type: .textDelta, content: "Item \(i)"))
                }
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }
        
        let result = StreamTextResult(
            stream: testStream,
            model: .anthropic(.opus4),
            settings: .default
        )
        
        // Test with for-await-in loop
        var count = 0
        for try await _ in result {
            count += 1
        }
        #expect(count == 4) // 3 text deltas + 1 done
    }
    
    @Test("StreamObjectResult conforms to AsyncSequence")
    func testStreamObjectResultAsyncSequence() async throws {
        struct TestData: Codable, Sendable, Equatable {
            let value: Int
        }
        
        let testStream = AsyncThrowingStream<ObjectStreamDelta<TestData>, Error> { continuation in
            Task {
                continuation.yield(ObjectStreamDelta(type: .start))
                continuation.yield(ObjectStreamDelta(
                    type: .partial,
                    object: TestData(value: 1)
                ))
                continuation.yield(ObjectStreamDelta(
                    type: .partial,
                    object: TestData(value: 2)
                ))
                continuation.yield(ObjectStreamDelta(
                    type: .complete,
                    object: TestData(value: 3)
                ))
                continuation.yield(ObjectStreamDelta(type: .done))
                continuation.finish()
            }
        }
        
        let result = StreamObjectResult(
            objectStream: testStream,
            model: .openai(.gpt4o),
            settings: .default,
            schema: TestData.self
        )
        
        // Test AsyncSequence iteration
        var deltaTypes: [ObjectStreamDelta<TestData>.DeltaType] = []
        for try await delta in result {
            deltaTypes.append(delta.type)
        }
        
        #expect(deltaTypes == [.start, .partial, .partial, .complete, .done])
    }
    
    @Test("AsyncSequence works with standard operators")
    func testAsyncSequenceOperators() async throws {
        let testStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                for i in 1...5 {
                    continuation.yield(TextStreamDelta(
                        type: .textDelta,
                        content: String(i)
                    ))
                }
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }
        
        let result = StreamTextResult(
            stream: testStream,
            model: .openai(.gpt4o),
            settings: .default
        )
        
        // Test with compactMap
        let numbers = try await result.compactMap { delta -> Int? in
            guard case .textDelta = delta.type,
                  let content = delta.content,
                  let num = Int(content) else {
                return nil
            }
            return num
        }.reduce(0, +)
        
        #expect(numbers == 15) // 1+2+3+4+5
    }
    
    @Test("AsyncSequence handles errors properly")
    func testAsyncSequenceErrorHandling() async throws {
        struct TestError: Error {}
        
        let testStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                continuation.yield(TextStreamDelta(type: .textDelta, content: "Start"))
                continuation.finish(throwing: TestError())
            }
        }
        
        let result = StreamTextResult(
            stream: testStream,
            model: .openai(.gpt4o),
            settings: .default
        )
        
        var receivedError = false
        do {
            for try await _ in result {
                // Process deltas
            }
        } catch {
            receivedError = true
        }
        
        #expect(receivedError)
    }
    
    @Test("AsyncSequence can be cancelled mid-iteration")
    func testAsyncSequenceCancellation() async throws {
        let testStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                for i in 1...100 {
                    try await Task.sleep(nanoseconds: 1_000_000) // 1ms
                    continuation.yield(TextStreamDelta(
                        type: .textDelta,
                        content: "Item \(i)"
                    ))
                }
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }
        
        let result = StreamTextResult(
            stream: testStream,
            model: .openai(.gpt4o),
            settings: .default
        )
        
        // Start iteration and cancel after a few items
        let task = Task {
            var count = 0
            for try await _ in result {
                count += 1
                if count >= 5 {
                    break // Early termination
                }
            }
            return count
        }
        
        let count = await (try? task.value) ?? 0
        #expect(count == 5)
    }
    
    @Test("StreamTextResult extension methods work with AsyncSequence")
    func testStreamTextResultExtensions() async throws {
        let testStream = AsyncThrowingStream<TextStreamDelta, Error> { continuation in
            Task {
                continuation.yield(TextStreamDelta(type: .textDelta, content: "Hello"))
                continuation.yield(TextStreamDelta(type: .channelStart(.thinking)))
                continuation.yield(TextStreamDelta(type: .textDelta, content: " World", channel: .thinking))
                continuation.yield(TextStreamDelta(type: .channelEnd(.thinking)))
                continuation.yield(TextStreamDelta(type: .textDelta, content: " Done"))
                continuation.yield(TextStreamDelta(type: .done))
                continuation.finish()
            }
        }
        
        let result = StreamTextResult(
            stream: testStream,
            model: .openai(.gpt4o),
            settings: .default
        )
        
        // Test collectText extension
        var texts: [String] = []
        for try await text in result.collectText() {
            texts.append(text)
        }
        
        #expect(texts.contains("Hello"))
        #expect(texts.contains(" Done"))
        #expect(texts.contains(" World")) // From thinking channel
    }
    
    @Test("StreamObjectResult extension methods work with AsyncSequence")
    func testStreamObjectResultExtensions() async throws {
        struct TestItem: Codable, Sendable, Equatable {
            let id: Int
            let name: String
        }
        
        let testStream = AsyncThrowingStream<ObjectStreamDelta<TestItem>, Error> { continuation in
            Task {
                continuation.yield(ObjectStreamDelta(type: .start))
                continuation.yield(ObjectStreamDelta(
                    type: .partial,
                    object: TestItem(id: 1, name: "First")
                ))
                continuation.yield(ObjectStreamDelta(
                    type: .partial,
                    object: TestItem(id: 2, name: "Second")
                ))
                continuation.yield(ObjectStreamDelta(
                    type: .complete,
                    object: TestItem(id: 3, name: "Final")
                ))
                continuation.yield(ObjectStreamDelta(type: .done))
                continuation.finish()
            }
        }
        
        let result = StreamObjectResult(
            objectStream: testStream,
            model: .openai(.gpt4o),
            settings: .default,
            schema: TestItem.self
        )
        
        // Test partialObjects extension
        var partialItems: [TestItem] = []
        for try await item in result.partialObjects() {
            partialItems.append(item)
        }
        
        #expect(partialItems.count == 2)
        #expect(partialItems[0].name == "First")
        #expect(partialItems[1].name == "Second")
    }
}