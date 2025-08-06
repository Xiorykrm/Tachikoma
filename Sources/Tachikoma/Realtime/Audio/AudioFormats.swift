//
//  AudioFormats.swift
//  Tachikoma
//

import Foundation
@preconcurrency import AVFoundation

// MARK: - Audio Format Utilities

/// Audio format specifications for the Realtime API
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public struct RealtimeAudioFormats {
    /// Default sample rate for Realtime API (24kHz)
    public static let apiSampleRate: Double = 24000
    
    /// Default device sample rate (48kHz)
    public static let deviceSampleRate: Double = 48000
    
    /// Default number of channels (mono)
    public static let channelCount: AVAudioChannelCount = 1
    
    /// Default buffer size in frames
    public static let bufferSize: AVAudioFrameCount = 1024
    
    /// Create PCM16 format for API
    public static func pcm16Format(sampleRate: Double = apiSampleRate) -> AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: channelCount,
            interleaved: true
        )!
    }
    
    /// Create float format for device
    public static func floatFormat(sampleRate: Double = deviceSampleRate) -> AVAudioFormat {
        AVAudioFormat(
            standardFormatWithSampleRate: sampleRate,
            channels: channelCount
        )!
    }
    
    /// Create format for G.711 µ-law
    public static func g711UlawFormat() -> AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16, // Will be converted
            sampleRate: apiSampleRate,
            channels: channelCount,
            interleaved: true
        )!
    }
    
    /// Create format for G.711 A-law
    public static func g711AlawFormat() -> AVAudioFormat {
        AVAudioFormat(
            commonFormat: .pcmFormatInt16, // Will be converted
            sampleRate: apiSampleRate,
            channels: channelCount,
            interleaved: true
        )!
    }
}

// MARK: - Audio Buffer Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension AVAudioPCMBuffer {
    /// Convert buffer to base64 encoded string
    func toBase64() -> String {
        let audioBuffer = audioBufferList.pointee.mBuffers
        let data = Data(
            bytes: audioBuffer.mData!,
            count: Int(audioBuffer.mDataByteSize)
        )
        return data.base64EncodedString()
    }
    
    /// Create buffer from base64 encoded string
    static func from(base64: String, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        guard let data = Data(base64Encoded: base64) else { return nil }
        
        let frameCount = AVAudioFrameCount(data.count / Int(format.streamDescription.pointee.mBytesPerFrame))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        // Copy data to buffer
        data.withUnsafeBytes { bytes in
            if format.commonFormat == .pcmFormatInt16,
               let audioBuffer = buffer.int16ChannelData?[0] {
                bytes.copyBytes(to: UnsafeMutableBufferPointer(
                    start: audioBuffer,
                    count: Int(frameCount)
                ))
            } else if format.commonFormat == .pcmFormatFloat32,
                      let audioBuffer = buffer.floatChannelData?[0] {
                bytes.copyBytes(to: UnsafeMutableBufferPointer(
                    start: audioBuffer,
                    count: Int(frameCount)
                ))
            }
        }
        
        return buffer
    }
    
    /// Calculate RMS level
    func rmsLevel() -> Float {
        guard let channelData = floatChannelData?[0] else {
            // Try int16 data
            if let int16Data = int16ChannelData?[0] {
                return calculateRMSFromInt16(int16Data, frameLength: frameLength)
            }
            return 0
        }
        
        let frameLength = Int(self.frameLength)
        var sum: Float = 0
        
        for i in 0..<frameLength {
            let sample = channelData[i]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        return min(1.0, rms * 2)  // Normalize and clamp
    }
    
    private func calculateRMSFromInt16(_ data: UnsafePointer<Int16>, frameLength: AVAudioFrameCount) -> Float {
        var sum: Float = 0
        
        for i in 0..<Int(frameLength) {
            let normalized = Float(data[i]) / Float(Int16.max)
            sum += normalized * normalized
        }
        
        let rms = sqrt(sum / Float(frameLength))
        return min(1.0, rms * 2)
    }
}

// MARK: - Audio Data Extensions

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public extension Data {
    /// Convert PCM16 data to float samples
    func pcm16ToFloat() -> [Float] {
        withUnsafeBytes { bytes in
            let samples = bytes.bindMemory(to: Int16.self)
            return samples.map { Float($0) / Float(Int16.max) }
        }
    }
    
    /// Convert float samples to PCM16 data
    static func fromFloatSamples(_ samples: [Float]) -> Data {
        var data = Data(capacity: samples.count * 2)
        
        for sample in samples {
            let clamped = Swift.max(-1.0, Swift.min(1.0, sample))
            let int16Value = Int16(clamped * Float(Int16.max))
            Swift.withUnsafeBytes(of: int16Value) { bytes in
                data.append(contentsOf: bytes)
            }
        }
        
        return data
    }
    
    /// Calculate audio energy
    func audioEnergy() -> Float {
        let samples = withUnsafeBytes { bytes in
            bytes.bindMemory(to: Int16.self)
        }
        
        var sum: Float = 0
        for sample in samples {
            let normalized = Float(sample) / Float(Int16.max)
            sum += normalized * normalized
        }
        
        let energy = sqrt(sum / Float(samples.count))
        return Swift.min(1.0, energy)
    }
    
    /// Detect voice activity
    func detectVoiceActivity(threshold: Float = 0.01) -> Bool {
        audioEnergy() > threshold
    }
}

// MARK: - Audio Stream Buffer

/// Buffer for streaming audio data
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class AudioStreamBuffer: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()
    private let chunkSize: Int
    private let maxBufferSize: Int
    
    public init(chunkSize: Int = 4096, maxBufferSize: Int = 65536) {
        self.chunkSize = chunkSize
        self.maxBufferSize = maxBufferSize
    }
    
    /// Append audio data
    public func append(_ data: Data) {
        lock.lock()
        defer { lock.unlock() }
        
        buffer.append(data)
        
        // Trim if exceeds max size
        if buffer.count > maxBufferSize {
            let excess = buffer.count - maxBufferSize
            buffer.removeFirst(excess)
        }
    }
    
    /// Get next chunk if available
    public func nextChunk() -> Data? {
        lock.lock()
        defer { lock.unlock() }
        
        guard buffer.count >= chunkSize else { return nil }
        
        let chunk = buffer.prefix(chunkSize)
        buffer.removeFirst(chunkSize)
        return Data(chunk)
    }
    
    /// Get all available data
    public func flush() -> Data {
        lock.lock()
        defer { lock.unlock() }
        
        let data = buffer
        buffer = Data()
        return data
    }
    
    /// Current buffer size
    public var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return buffer.count
    }
    
    /// Clear the buffer
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        buffer = Data()
    }
}

// MARK: - Voice Activity Detection

/// Simple voice activity detector
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public final class VoiceActivityDetector: @unchecked Sendable {
    private let energyThreshold: Float
    private let silenceDuration: TimeInterval
    private var lastVoiceTime: Date?
    private let lock = NSLock()
    
    public init(energyThreshold: Float = 0.01, silenceDuration: TimeInterval = 0.5) {
        self.energyThreshold = energyThreshold
        self.silenceDuration = silenceDuration
    }
    
    /// Process audio data and detect voice activity
    public func processAudio(_ data: Data) -> (hasVoice: Bool, isSpeaking: Bool) {
        let energy = data.audioEnergy()
        let hasVoice = energy > energyThreshold
        
        lock.lock()
        defer { lock.unlock() }
        
        if hasVoice {
            lastVoiceTime = Date()
            return (true, true)
        } else if let lastTime = lastVoiceTime {
            let elapsed = Date().timeIntervalSince(lastTime)
            let stillSpeaking = elapsed < silenceDuration
            return (false, stillSpeaking)
        } else {
            return (false, false)
        }
    }
    
    /// Reset the detector
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastVoiceTime = nil
    }
}
