// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Converts audio sample rates using interpolation algorithms.
///
/// Supports standard audio rates from 22050 Hz to 192000 Hz.
/// Uses linear interpolation (fast), filtered linear (medium),
/// or windowed sinc / Lanczos (best) for cross-platform compatibility.
///
/// ```swift
/// let converter = SampleRateConverter()
/// let resampled = converter.convert(
///     pcmData, from: 44100, to: 48000,
///     channels: 2, sampleFormat: .float32
/// )
/// ```
public struct SampleRateConverter: Sendable {

    // MARK: - Types

    /// Conversion quality.
    public enum Quality: String, Sendable, Equatable {

        /// Linear interpolation.
        case fast

        /// Linear with anti-aliasing pre-filter for downsampling.
        case medium

        /// Windowed sinc (Lanczos) interpolation.
        case best
    }

    /// Standard audio sample rates.
    public enum StandardRate: Double, Sendable, CaseIterable {

        /// 22050 Hz.
        case hz22050 = 22050

        /// 44100 Hz (CD quality).
        case hz44100 = 44100

        /// 48000 Hz (broadcast/streaming standard).
        case hz48000 = 48000

        /// 88200 Hz.
        case hz88200 = 88200

        /// 96000 Hz.
        case hz96000 = 96000

        /// 176400 Hz.
        case hz176400 = 176400

        /// 192000 Hz.
        case hz192000 = 192000
    }

    /// Conversion configuration.
    public struct Configuration: Sendable, Equatable {

        /// Interpolation quality.
        public var quality: Quality

        /// Creates a configuration.
        public init(quality: Quality = .fast) {
            self.quality = quality
        }

        /// Standard quality (linear interpolation).
        public static let standard = Configuration()

        /// High quality (windowed sinc).
        public static let highQuality = Configuration(quality: .best)
    }

    // MARK: - Properties

    /// Conversion configuration.
    public var configuration: Configuration

    /// Creates a sample rate converter.
    ///
    /// - Parameter configuration: Conversion configuration.
    public init(configuration: Configuration = .standard) {
        self.configuration = configuration
    }

    // MARK: - Conversion

    /// Convert sample rate.
    ///
    /// Internally converts to Float32 for processing, then converts back.
    /// - Parameters:
    ///   - data: PCM audio data.
    ///   - fromRate: Source sample rate in Hz.
    ///   - toRate: Target sample rate in Hz.
    ///   - channels: Number of audio channels.
    ///   - sampleFormat: PCM sample format.
    /// - Returns: Resampled PCM data at the target rate.
    public func convert(
        _ data: Data,
        from fromRate: Double,
        to toRate: Double,
        channels: Int,
        sampleFormat: AudioFormatConverter.SampleFormat
    ) -> Data {
        guard !data.isEmpty else { return Data() }
        guard fromRate != toRate else { return data }

        let fmt = AudioFormatConverter()
        let f32Data =
            sampleFormat != .float32
            ? fmt.convert(data, from: sampleFormat, to: .float32, channels: channels)
            : data

        let inputCount = f32Data.count / (4 * channels)
        let outCount = outputSampleCount(
            inputCount: inputCount, fromRate: fromRate, toRate: toRate
        )
        guard outCount > 0 else { return Data() }

        let resampled: Data = f32Data.withUnsafeBytes { raw in
            let input = raw.bindMemory(to: Float.self)
            let samples: [Float]
            switch configuration.quality {
            case .fast:
                samples = resampleLinear(
                    input: input, outputCount: outCount,
                    fromRate: fromRate, toRate: toRate, channels: channels
                )
            case .medium:
                samples = resampleMedium(
                    input: input, outputCount: outCount,
                    fromRate: fromRate, toRate: toRate, channels: channels
                )
            case .best:
                samples = resampleSinc(
                    input: input, outputCount: outCount,
                    fromRate: fromRate, toRate: toRate, channels: channels
                )
            }
            return samples.withUnsafeBytes { Data($0) }
        }

        if sampleFormat != .float32 {
            return fmt.convert(
                resampled, from: .float32, to: sampleFormat, channels: channels
            )
        }
        return resampled
    }

    /// Check if the conversion ratio is a simple integer ratio.
    ///
    /// - Parameters:
    ///   - from: Source sample rate.
    ///   - to: Target sample rate.
    /// - Returns: True if the ratio is an integer in either direction.
    public func isSimpleRatio(from: Double, to: Double) -> Bool {
        guard from > 0, to > 0 else { return false }
        let ratio = to / from
        if abs(ratio - ratio.rounded()) < 0.001 { return true }
        let inverse = from / to
        return abs(inverse - inverse.rounded()) < 0.001
    }

    /// Calculate output sample count for a given input count and rate ratio.
    ///
    /// - Parameters:
    ///   - inputCount: Number of input samples per channel.
    ///   - fromRate: Source sample rate.
    ///   - toRate: Target sample rate.
    /// - Returns: Number of output samples per channel.
    public func outputSampleCount(
        inputCount: Int, fromRate: Double, toRate: Double
    ) -> Int {
        guard inputCount > 0, fromRate > 0 else { return 0 }
        return Int(ceil(Double(inputCount) * toRate / fromRate))
    }

    /// Calculate output data size.
    ///
    /// - Parameters:
    ///   - inputSize: Input data size in bytes.
    ///   - fromRate: Source sample rate.
    ///   - toRate: Target sample rate.
    ///   - sampleFormat: PCM sample format.
    /// - Returns: Output data size in bytes.
    public func outputDataSize(
        inputSize: Int,
        fromRate: Double,
        toRate: Double,
        sampleFormat: AudioFormatConverter.SampleFormat
    ) -> Int {
        let bps = sampleFormat.bytesPerSample
        guard bps > 0 else { return 0 }
        let inputCount = inputSize / bps
        let outCount = outputSampleCount(
            inputCount: inputCount, fromRate: fromRate, toRate: toRate
        )
        return outCount * bps
    }

    // MARK: - Private

    private func resampleLinear(
        input: UnsafeBufferPointer<Float>,
        outputCount: Int,
        fromRate: Double,
        toRate: Double,
        channels: Int
    ) -> [Float] {
        let inputCount = input.count / channels
        guard inputCount > 0, outputCount > 0 else { return [] }

        var output = [Float](repeating: 0, count: outputCount * channels)
        let ratio = fromRate / toRate

        for i in 0..<outputCount {
            let pos = Double(i) * ratio
            let idx0 = min(Int(pos), inputCount - 1)
            let idx1 = min(idx0 + 1, inputCount - 1)
            let frac = Float(pos - Double(idx0))

            for ch in 0..<channels {
                let s0 = input[idx0 * channels + ch]
                let s1 = input[idx1 * channels + ch]
                output[i * channels + ch] = s0 + frac * (s1 - s0)
            }
        }
        return output
    }

    private func resampleMedium(
        input: UnsafeBufferPointer<Float>,
        outputCount: Int,
        fromRate: Double,
        toRate: Double,
        channels: Int
    ) -> [Float] {
        let inputCount = input.count / channels
        guard inputCount > 0, outputCount > 0 else { return [] }

        guard fromRate > toRate else {
            return resampleLinear(
                input: input, outputCount: outputCount,
                fromRate: fromRate, toRate: toRate, channels: channels
            )
        }

        // Low-pass pre-filter (moving average) for downsampling
        let filterSize = max(2, Int(ceil(fromRate / toRate)))
        let halfWin = filterSize / 2
        var filtered = [Float](repeating: 0, count: input.count)

        for ch in 0..<channels {
            for s in 0..<inputCount {
                var sum: Float = 0
                var count: Float = 0
                let lo = max(0, s - halfWin)
                let hi = min(inputCount - 1, s + halfWin)
                for j in lo...hi {
                    sum += input[j * channels + ch]
                    count += 1
                }
                filtered[s * channels + ch] = sum / count
            }
        }

        return filtered.withUnsafeBufferPointer { buf in
            resampleLinear(
                input: buf, outputCount: outputCount,
                fromRate: fromRate, toRate: toRate, channels: channels
            )
        }
    }

    private func resampleSinc(
        input: UnsafeBufferPointer<Float>,
        outputCount: Int,
        fromRate: Double,
        toRate: Double,
        channels: Int
    ) -> [Float] {
        let inputCount = input.count / channels
        guard inputCount > 0, outputCount > 0 else { return [] }

        let taps = 4
        let ratio = fromRate / toRate
        let scale = max(1.0, ratio)
        let windowRadius = Int(ceil(Double(taps) * scale))
        var output = [Float](repeating: 0, count: outputCount * channels)

        for i in 0..<outputCount {
            let pos = Double(i) * ratio
            let center = Int(pos)

            for ch in 0..<channels {
                var sum: Double = 0
                var weightSum: Double = 0
                let lo = max(0, center - windowRadius)
                let hi = min(inputCount - 1, center + windowRadius)

                for tap in lo...hi {
                    let x = (pos - Double(tap)) / scale
                    let w = Self.lanczos(x, a: taps)
                    sum += Double(input[tap * channels + ch]) * w
                    weightSum += w
                }

                output[i * channels + ch] =
                    weightSum > 0 ? Float(sum / weightSum) : 0
            }
        }
        return output
    }

    private static func lanczos(_ x: Double, a: Int) -> Double {
        guard x != 0 else { return 1.0 }
        guard abs(x) < Double(a) else { return 0.0 }
        let pix = Double.pi * x
        let pixa = pix / Double(a)
        return (sin(pix) / pix) * (sin(pixa) / pixa)
    }
}
