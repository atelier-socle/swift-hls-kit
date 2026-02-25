// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Result of level measurement for a single channel.
public struct ChannelLevel: Sendable, Equatable {

    /// RMS level as linear amplitude (0.0...1.0).
    public let rms: Float

    /// RMS level in dBFS.
    public let rmsDB: Float

    /// Peak sample value as linear amplitude (0.0...1.0).
    public let peak: Float

    /// Peak level in dBFS.
    public let peakDB: Float

    /// True peak (intersample) as linear amplitude.
    public let truePeak: Float

    /// True peak in dBFS (per ITU-R BS.1770).
    public let truePeakDB: Float
}

/// Measures audio signal levels from Float32 PCM data.
///
/// Provides RMS (Root Mean Square), peak, and true peak measurements
/// per channel. All inputs are Float32 interleaved PCM data.
///
/// True peak uses 4x oversampling with sinc interpolation per ITU-R BS.1770.
///
/// ```swift
/// let meter = LevelMeter()
/// let levels = meter.measure(data: pcmData, channels: 2)
/// print("Left RMS: \(levels[0].rmsDB) dBFS")
/// print("Right peak: \(levels[1].peakDB) dBFS")
/// ```
public struct LevelMeter: Sendable {

    /// Creates a level meter.
    public init() {}

    /// Measure levels for all channels in interleaved Float32 data.
    ///
    /// - Parameters:
    ///   - data: Float32 interleaved PCM data.
    ///   - channels: Number of channels (1 = mono, 2 = stereo, etc.).
    /// - Returns: Array of ChannelLevel, one per channel.
    public func measure(data: Data, channels: Int) -> [ChannelLevel] {
        guard !data.isEmpty, channels > 0 else { return [] }
        let totalSamples = data.count / 4
        let framesCount = totalSamples / channels
        guard framesCount > 0 else { return [] }

        return data.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Float.self)
            return (0..<channels).map { ch in
                measureChannel(
                    samples: samples, channel: ch,
                    channels: channels, frameCount: framesCount)
            }
        }
    }

    /// Measure levels for a single channel of Float32 data (non-interleaved).
    ///
    /// - Parameter data: Float32 mono PCM data.
    /// - Returns: ChannelLevel for the channel.
    public func measureMono(data: Data) -> ChannelLevel {
        guard !data.isEmpty else {
            return ChannelLevel(
                rms: 0, rmsDB: -.infinity, peak: 0, peakDB: -.infinity,
                truePeak: 0, truePeakDB: -.infinity
            )
        }
        return data.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Float.self)
            return measureChannel(
                samples: samples, channel: 0, channels: 1,
                frameCount: samples.count
            )
        }
    }

    // MARK: - Private

    private func measureChannel(
        samples: UnsafeBufferPointer<Float>,
        channel: Int, channels: Int, frameCount: Int
    ) -> ChannelLevel {
        var sumSquares: Double = 0
        var peakVal: Float = 0

        for i in 0..<frameCount {
            let s = abs(samples[i * channels + channel])
            sumSquares += Double(s) * Double(s)
            if s > peakVal { peakVal = s }
        }

        let rms = Float(sqrt(sumSquares / Double(frameCount)))
        let tp = computeTruePeak(
            samples: samples, channel: channel,
            channels: channels, frameCount: frameCount
        )

        return ChannelLevel(
            rms: rms, rmsDB: Self.toDBFS(rms),
            peak: peakVal, peakDB: Self.toDBFS(peakVal),
            truePeak: tp, truePeakDB: Self.toDBFS(tp)
        )
    }

    private func computeTruePeak(
        samples: UnsafeBufferPointer<Float>,
        channel: Int, channels: Int, frameCount: Int
    ) -> Float {
        guard frameCount > 1 else {
            return frameCount == 1 ? abs(samples[channel]) : 0
        }

        var peak: Float = 0
        // 4x oversampling with 4-tap sinc interpolation
        for i in 0..<frameCount {
            let s = abs(samples[i * channels + channel])
            if s > peak { peak = s }

            guard i + 1 < frameCount else { continue }
            let s0 = samples[max(0, i - 1) * channels + channel]
            let s1 = samples[i * channels + channel]
            let s2 = samples[(i + 1) * channels + channel]
            let s3 = samples[min(frameCount - 1, i + 2) * channels + channel]

            for phase in 1...3 {
                let t = Float(phase) / 4.0
                let v = Self.cubicInterpolate(s0, s1, s2, s3, t: t)
                let av = abs(v)
                if av > peak { peak = av }
            }
        }
        return peak
    }

    private static func cubicInterpolate(
        _ y0: Float, _ y1: Float, _ y2: Float, _ y3: Float, t: Float
    ) -> Float {
        let a0 = y3 - y2 - y0 + y1
        let a1 = y0 - y1 - a0
        let a2 = y2 - y0
        let a3 = y1
        return a0 * t * t * t + a1 * t * t + a2 * t + a3
    }

    /// Convert linear amplitude to dBFS.
    static func toDBFS(_ linear: Float) -> Float {
        guard linear > 0 else { return -.infinity }
        return 20.0 * log10(linear)
    }
}
