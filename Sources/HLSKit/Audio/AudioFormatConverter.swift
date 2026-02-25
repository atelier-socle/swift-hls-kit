// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Converts between PCM audio formats in pure Swift.
///
/// Supports format conversions:
/// - Bit depth: Int16 ↔ Float32 ↔ Int32
/// - Layout: interleaved ↔ non-interleaved (planar)
/// - Endianness: little-endian ↔ big-endian
///
/// All operations work identically on macOS and Linux (no AudioToolbox dependency).
///
/// ```swift
/// let converter = AudioFormatConverter()
/// let float32Data = converter.int16ToFloat32(pcmData, channels: 2)
/// let monoData = converter.deinterleave(float32Data, channels: 2, sampleFormat: .float32)
/// ```
public struct AudioFormatConverter: Sendable {

    // MARK: - Types

    /// PCM sample format.
    public enum SampleFormat: String, Sendable, Equatable, CaseIterable {

        /// 16-bit signed integer (-32768...32767).
        case int16

        /// 32-bit signed integer.
        case int32

        /// 32-bit IEEE float (-1.0...1.0).
        case float32

        /// Bytes per sample (single channel).
        public var bytesPerSample: Int {
            switch self {
            case .int16: return 2
            case .int32, .float32: return 4
            }
        }
    }

    /// Audio data layout.
    public enum Layout: String, Sendable, Equatable {

        /// Interleaved: L R L R L R ...
        case interleaved

        /// Non-interleaved (planar): LLLL... RRRR...
        case nonInterleaved
    }

    /// Endianness.
    public enum Endianness: String, Sendable, Equatable {

        /// Little-endian (Intel, ARM).
        case little

        /// Big-endian (network byte order).
        case big
    }

    /// Complete PCM format descriptor.
    public struct PCMFormat: Sendable, Equatable {

        /// Sample format.
        public var sampleFormat: SampleFormat

        /// Sample rate in Hz.
        public var sampleRate: Double

        /// Number of channels.
        public var channels: Int

        /// Data layout.
        public var layout: Layout

        /// Byte order.
        public var endianness: Endianness

        /// Creates a PCM format descriptor.
        public init(
            sampleFormat: SampleFormat = .float32,
            sampleRate: Double = 48000,
            channels: Int = 2,
            layout: Layout = .interleaved,
            endianness: Endianness = .little
        ) {
            self.sampleFormat = sampleFormat
            self.sampleRate = sampleRate
            self.channels = channels
            self.layout = layout
            self.endianness = endianness
        }

        /// Standard format: Float32, 48kHz, stereo, interleaved, little-endian.
        public static let standard = PCMFormat()

        /// CD quality: Int16, 44.1kHz, stereo, interleaved, little-endian.
        public static let cdQuality = PCMFormat(
            sampleFormat: .int16, sampleRate: 44100
        )

        /// Podcast: Float32, 44.1kHz, mono, interleaved, little-endian.
        public static let podcast = PCMFormat(
            sampleRate: 44100, channels: 1
        )

        /// Bytes per sample (single channel).
        public var bytesPerSample: Int { sampleFormat.bytesPerSample }

        /// Bytes per frame (all channels for one time point).
        public var bytesPerFrame: Int { bytesPerSample * channels }
    }

    /// Creates an audio format converter.
    public init() {}

    // MARK: - Bit Depth Conversion

    /// Convert Int16 PCM to Float32 PCM.
    ///
    /// Int16 range [-32768, 32767] maps to Float32 range [-1.0, ~1.0].
    /// - Parameters:
    ///   - data: Int16 PCM data.
    ///   - channels: Number of channels (unused, for API consistency).
    /// - Returns: Float32 PCM data.
    public func int16ToFloat32(_ data: Data, channels: Int = 2) -> Data {
        guard !data.isEmpty else { return Data() }
        let count = data.count / 2
        var output = Data(count: count * 4)
        data.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                let src = raw.bindMemory(to: Int16.self)
                let dst = out.bindMemory(to: Float.self)
                for i in 0..<count {
                    dst[i] = Float(src[i]) / 32768.0
                }
            }
        }
        return output
    }

    /// Convert Float32 PCM to Int16 PCM.
    ///
    /// Float32 range [-1.0, 1.0] maps to Int16 range [-32767, 32767], with clamping.
    /// - Parameters:
    ///   - data: Float32 PCM data.
    ///   - channels: Number of channels (unused, for API consistency).
    /// - Returns: Int16 PCM data.
    public func float32ToInt16(_ data: Data, channels: Int = 2) -> Data {
        guard !data.isEmpty else { return Data() }
        let count = data.count / 4
        var output = Data(count: count * 2)
        data.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                let src = raw.bindMemory(to: Float.self)
                let dst = out.bindMemory(to: Int16.self)
                for i in 0..<count {
                    let clamped = max(-1.0, min(1.0, src[i]))
                    dst[i] = Int16(clamped * 32767.0)
                }
            }
        }
        return output
    }

    /// Convert Int16 PCM to Int32 PCM.
    ///
    /// Values are left-shifted by 16 bits.
    /// - Parameters:
    ///   - data: Int16 PCM data.
    ///   - channels: Number of channels (unused, for API consistency).
    /// - Returns: Int32 PCM data.
    public func int16ToInt32(_ data: Data, channels: Int = 2) -> Data {
        guard !data.isEmpty else { return Data() }
        let count = data.count / 2
        var output = Data(count: count * 4)
        data.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                let src = raw.bindMemory(to: Int16.self)
                let dst = out.bindMemory(to: Int32.self)
                for i in 0..<count {
                    dst[i] = Int32(src[i]) << 16
                }
            }
        }
        return output
    }

    /// Convert Int32 PCM to Int16 PCM.
    ///
    /// Values are right-shifted by 16 bits, with clamping.
    /// - Parameters:
    ///   - data: Int32 PCM data.
    ///   - channels: Number of channels (unused, for API consistency).
    /// - Returns: Int16 PCM data.
    public func int32ToInt16(_ data: Data, channels: Int = 2) -> Data {
        guard !data.isEmpty else { return Data() }
        let count = data.count / 4
        var output = Data(count: count * 2)
        data.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                let src = raw.bindMemory(to: Int32.self)
                let dst = out.bindMemory(to: Int16.self)
                for i in 0..<count {
                    dst[i] = Int16(clamping: src[i] >> 16)
                }
            }
        }
        return output
    }

    /// Convert Float32 PCM to Int32 PCM.
    ///
    /// - Parameters:
    ///   - data: Float32 PCM data.
    ///   - channels: Number of channels (unused, for API consistency).
    /// - Returns: Int32 PCM data.
    public func float32ToInt32(_ data: Data, channels: Int = 2) -> Data {
        guard !data.isEmpty else { return Data() }
        let count = data.count / 4
        var output = Data(count: count * 4)
        data.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                let src = raw.bindMemory(to: Float.self)
                let dst = out.bindMemory(to: Int32.self)
                for i in 0..<count {
                    let clamped = max(-1.0, min(1.0, src[i]))
                    dst[i] = Int32(Double(clamped) * 2_147_483_647.0)
                }
            }
        }
        return output
    }

    /// Convert Int32 PCM to Float32 PCM.
    ///
    /// - Parameters:
    ///   - data: Int32 PCM data.
    ///   - channels: Number of channels (unused, for API consistency).
    /// - Returns: Float32 PCM data.
    public func int32ToFloat32(_ data: Data, channels: Int = 2) -> Data {
        guard !data.isEmpty else { return Data() }
        let count = data.count / 4
        var output = Data(count: count * 4)
        data.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                let src = raw.bindMemory(to: Int32.self)
                let dst = out.bindMemory(to: Float.self)
                for i in 0..<count {
                    dst[i] = Float(Double(src[i]) / 2_147_483_648.0)
                }
            }
        }
        return output
    }

    /// Generic conversion between any two sample formats.
    ///
    /// Routes to the appropriate specific conversion method.
    /// - Parameters:
    ///   - data: Input PCM data.
    ///   - from: Source sample format.
    ///   - to: Target sample format.
    ///   - channels: Number of channels.
    /// - Returns: Converted PCM data.
    public func convert(
        _ data: Data, from: SampleFormat, to: SampleFormat,
        channels: Int = 2
    ) -> Data {
        guard from != to else { return data }
        switch (from, to) {
        case (.int16, .float32): return int16ToFloat32(data, channels: channels)
        case (.float32, .int16): return float32ToInt16(data, channels: channels)
        case (.int16, .int32): return int16ToInt32(data, channels: channels)
        case (.int32, .int16): return int32ToInt16(data, channels: channels)
        case (.float32, .int32): return float32ToInt32(data, channels: channels)
        case (.int32, .float32): return int32ToFloat32(data, channels: channels)
        default: return data
        }
    }

    // MARK: - Layout Conversion

    /// Convert interleaved to non-interleaved (planar).
    ///
    /// Input: L0 R0 L1 R1 ... Output: L0 L1 ... R0 R1 ...
    /// - Parameters:
    ///   - data: Interleaved PCM data.
    ///   - channels: Number of channels.
    ///   - sampleFormat: Sample format for byte size calculation.
    /// - Returns: Non-interleaved (planar) PCM data.
    public func deinterleave(
        _ data: Data, channels: Int, sampleFormat: SampleFormat
    ) -> Data {
        guard channels > 1, !data.isEmpty else { return data }
        let bps = sampleFormat.bytesPerSample
        let totalSamples = data.count / bps
        let samplesPerChannel = totalSamples / channels
        let src = [UInt8](data)
        var dst = [UInt8](repeating: 0, count: data.count)
        for ch in 0..<channels {
            for s in 0..<samplesPerChannel {
                let srcOff = (s * channels + ch) * bps
                let dstOff = (ch * samplesPerChannel + s) * bps
                for b in 0..<bps {
                    dst[dstOff + b] = src[srcOff + b]
                }
            }
        }
        return Data(dst)
    }

    /// Convert non-interleaved (planar) to interleaved.
    ///
    /// Input: L0 L1 ... R0 R1 ... Output: L0 R0 L1 R1 ...
    /// - Parameters:
    ///   - data: Non-interleaved (planar) PCM data.
    ///   - channels: Number of channels.
    ///   - sampleFormat: Sample format for byte size calculation.
    /// - Returns: Interleaved PCM data.
    public func interleave(
        _ data: Data, channels: Int, sampleFormat: SampleFormat
    ) -> Data {
        guard channels > 1, !data.isEmpty else { return data }
        let bps = sampleFormat.bytesPerSample
        let totalSamples = data.count / bps
        let samplesPerChannel = totalSamples / channels
        let src = [UInt8](data)
        var dst = [UInt8](repeating: 0, count: data.count)
        for ch in 0..<channels {
            for s in 0..<samplesPerChannel {
                let srcOff = (ch * samplesPerChannel + s) * bps
                let dstOff = (s * channels + ch) * bps
                for b in 0..<bps {
                    dst[dstOff + b] = src[srcOff + b]
                }
            }
        }
        return Data(dst)
    }

    // MARK: - Endianness Conversion

    /// Swap byte order for the given sample format.
    ///
    /// - Parameters:
    ///   - data: PCM data.
    ///   - sampleFormat: Sample format for byte size calculation.
    /// - Returns: Byte-swapped PCM data.
    public func swapEndianness(
        _ data: Data, sampleFormat: SampleFormat
    ) -> Data {
        guard !data.isEmpty else { return data }
        let bps = sampleFormat.bytesPerSample
        var output = Data(data)
        output.withUnsafeMutableBytes { raw in
            let count = data.count / bps
            for i in 0..<count {
                let off = i * bps
                if bps == 2 {
                    let tmp = raw[off]
                    raw[off] = raw[off + 1]
                    raw[off + 1] = tmp
                } else if bps == 4 {
                    let t0 = raw[off]
                    let t1 = raw[off + 1]
                    raw[off] = raw[off + 3]
                    raw[off + 1] = raw[off + 2]
                    raw[off + 2] = t1
                    raw[off + 3] = t0
                }
            }
        }
        return output
    }

    // MARK: - Full Format Conversion

    /// Convert audio data between two complete PCM formats.
    ///
    /// Handles bit depth, layout, and endianness in the optimal order.
    /// Does not handle sample rate or channel count changes.
    /// - Parameters:
    ///   - data: Input PCM data.
    ///   - from: Source format descriptor.
    ///   - to: Target format descriptor.
    /// - Returns: Converted PCM data.
    public func convert(_ data: Data, from: PCMFormat, to: PCMFormat) -> Data {
        guard !data.isEmpty else { return data }
        var result = data

        // Step 1: Swap to native endianness if input is big-endian
        if from.endianness == .big {
            result = swapEndianness(result, sampleFormat: from.sampleFormat)
        }

        // Step 2: Convert sample format
        if from.sampleFormat != to.sampleFormat {
            result = convert(
                result, from: from.sampleFormat, to: to.sampleFormat,
                channels: from.channels
            )
        }

        // Step 3: Convert layout
        if from.layout != to.layout {
            if to.layout == .nonInterleaved {
                result = deinterleave(
                    result, channels: from.channels,
                    sampleFormat: to.sampleFormat
                )
            } else {
                result = interleave(
                    result, channels: from.channels,
                    sampleFormat: to.sampleFormat
                )
            }
        }

        // Step 4: Swap to target endianness if big-endian
        if to.endianness == .big {
            result = swapEndianness(result, sampleFormat: to.sampleFormat)
        }

        return result
    }

    // MARK: - Utilities

    /// Calculate the number of samples (per channel) in the data.
    ///
    /// - Parameters:
    ///   - dataSize: Size of the data in bytes.
    ///   - format: PCM format descriptor.
    /// - Returns: Number of samples per channel.
    public func sampleCount(dataSize: Int, format: PCMFormat) -> Int {
        guard format.bytesPerFrame > 0 else { return 0 }
        return dataSize / format.bytesPerFrame
    }

    /// Calculate the duration in seconds.
    ///
    /// - Parameters:
    ///   - dataSize: Size of the data in bytes.
    ///   - format: PCM format descriptor.
    /// - Returns: Duration in seconds.
    public func duration(dataSize: Int, format: PCMFormat) -> TimeInterval {
        guard format.sampleRate > 0 else { return 0 }
        return TimeInterval(sampleCount(dataSize: dataSize, format: format))
            / format.sampleRate
    }

    /// Calculate the data size for a given duration.
    ///
    /// - Parameters:
    ///   - duration: Duration in seconds.
    ///   - format: PCM format descriptor.
    /// - Returns: Data size in bytes.
    public func dataSize(
        duration: TimeInterval, format: PCMFormat
    ) -> Int {
        let samples = Int(duration * format.sampleRate)
        return samples * format.bytesPerFrame
    }
}
