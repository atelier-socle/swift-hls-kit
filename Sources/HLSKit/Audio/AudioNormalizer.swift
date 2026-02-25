// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Normalization preset for common targets.
public enum NormalizationPreset: String, Sendable, CaseIterable {

    /// -16 LUFS (Apple, Spotify recommendation).
    case podcast

    /// -14 LUFS (Spotify, YouTube).
    case musicStreaming

    /// -23 LUFS (EBU R 128).
    case broadcast

    /// -24 LKFS (ATSC A/85).
    case film

    /// Target loudness in LUFS.
    public var targetLoudness: Float {
        switch self {
        case .podcast: return -16.0
        case .musicStreaming: return -14.0
        case .broadcast: return -23.0
        case .film: return -24.0
        }
    }
}

/// Result of normalization.
public struct NormalizationResult: Sendable {

    /// Original integrated loudness in LUFS.
    public let originalLoudness: Float

    /// Target loudness in LUFS.
    public let targetLoudness: Float

    /// Applied gain in dB.
    public let gainDB: Float

    /// Applied gain as linear multiplier.
    public let gainLinear: Float

    /// True peak after normalization in dBFS.
    public let truePeakAfter: Float

    /// Whether true peak limiting was applied.
    public let peakLimited: Bool

    /// Normalized audio data (Float32 interleaved PCM).
    public let data: Data
}

/// Normalizes audio to a target loudness level.
///
/// Measures integrated loudness using ``LoudnessMeter``, calculates the
/// required gain adjustment, and applies it to the audio data.
///
/// ```swift
/// let normalizer = AudioNormalizer(targetLoudness: -16.0)
/// let result = normalizer.normalize(
///     data: pcmData, sampleRate: 48000, channels: 2
/// )
/// print("Applied gain: \(result.gainDB) dB")
/// ```
public struct AudioNormalizer: Sendable {

    /// Target loudness in LUFS.
    public let targetLoudness: Float

    /// Maximum true peak in dBFS (default: -1.0 dBFS per EBU R 128).
    public let truePeakLimit: Float

    /// Creates a normalizer with specific target loudness.
    ///
    /// - Parameters:
    ///   - targetLoudness: Target loudness in LUFS.
    ///   - truePeakLimit: Maximum true peak in dBFS.
    public init(targetLoudness: Float, truePeakLimit: Float = -1.0) {
        self.targetLoudness = targetLoudness
        self.truePeakLimit = truePeakLimit
    }

    /// Creates a normalizer with a standard preset.
    ///
    /// - Parameters:
    ///   - preset: Normalization preset.
    ///   - truePeakLimit: Maximum true peak in dBFS.
    public init(preset: NormalizationPreset, truePeakLimit: Float = -1.0) {
        self.targetLoudness = preset.targetLoudness
        self.truePeakLimit = truePeakLimit
    }

    /// Normalize audio data to target loudness.
    ///
    /// - Parameters:
    ///   - data: Float32 interleaved PCM data.
    ///   - sampleRate: Sample rate in Hz.
    ///   - channels: Number of channels.
    /// - Returns: NormalizationResult with normalized data and metadata.
    public func normalize(
        data: Data, sampleRate: Int, channels: Int
    ) -> NormalizationResult {
        let (gainDB, originalLoudness) = calculateGain(
            data: data, sampleRate: sampleRate, channels: channels
        )

        // Handle silence
        guard originalLoudness.isFinite else {
            return NormalizationResult(
                originalLoudness: originalLoudness,
                targetLoudness: targetLoudness,
                gainDB: 0, gainLinear: 1.0,
                truePeakAfter: -.infinity, peakLimited: false,
                data: data
            )
        }

        var linearGain = pow(10.0, gainDB / 20.0)

        // Apply gain
        var normalized = applyGain(data, gain: linearGain)

        // Check true peak and limit if needed
        let meter = LevelMeter()
        let levels = meter.measure(data: normalized, channels: channels)
        let maxTruePeak = levels.map(\.truePeakDB).max() ?? -.infinity
        var peakLimited = false

        if maxTruePeak > truePeakLimit {
            let reduction = truePeakLimit - maxTruePeak
            let reductionLinear = pow(10.0, reduction / 20.0)
            linearGain *= reductionLinear
            normalized = applyGain(data, gain: linearGain)
            peakLimited = true
        }

        let finalLevels = meter.measure(data: normalized, channels: channels)
        let finalPeak = finalLevels.map(\.truePeakDB).max() ?? -.infinity

        return NormalizationResult(
            originalLoudness: originalLoudness,
            targetLoudness: targetLoudness,
            gainDB: 20.0 * log10(linearGain),
            gainLinear: linearGain,
            truePeakAfter: finalPeak,
            peakLimited: peakLimited,
            data: normalized
        )
    }

    /// Calculate required gain without applying it.
    ///
    /// - Parameters:
    ///   - data: Float32 interleaved PCM data.
    ///   - sampleRate: Sample rate in Hz.
    ///   - channels: Number of channels.
    /// - Returns: Gain in dB and original loudness in LUFS.
    public func calculateGain(
        data: Data, sampleRate: Int, channels: Int
    ) -> (gainDB: Float, originalLoudness: Float) {
        var meter = LoudnessMeter(sampleRate: sampleRate, channels: channels)
        meter.process(block: data)
        let result = meter.integratedLoudness()
        let original = result.loudness

        guard original.isFinite else { return (0, original) }
        return (targetLoudness - original, original)
    }

    // MARK: - Private

    private func applyGain(_ data: Data, gain: Float) -> Data {
        let count = data.count / 4
        var output = Data(count: data.count)
        data.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                let src = raw.bindMemory(to: Float.self)
                let dst = out.bindMemory(to: Float.self)
                for i in 0..<count {
                    dst[i] = max(-1.0, min(1.0, src[i] * gain))
                }
            }
        }
        return output
    }
}
