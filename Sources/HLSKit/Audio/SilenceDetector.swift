// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// A detected silence region in the audio.
public struct SilenceRegion: Sendable, Equatable {

    /// Start time in seconds.
    public let startTime: Double

    /// End time in seconds.
    public let endTime: Double

    /// Duration in seconds.
    public let duration: Double

    /// Average level during silence in dBFS.
    public let averageLevelDB: Float

    /// Start sample index (in frames).
    public let startFrame: Int

    /// End sample index (in frames).
    public let endFrame: Int
}

/// Detects silence regions in audio data.
///
/// Scans Float32 PCM data and identifies contiguous regions where
/// the signal level falls below a configurable threshold for at
/// least a minimum duration.
///
/// ```swift
/// let detector = SilenceDetector(thresholdDB: -40, minimumDuration: 1.0)
/// let regions = detector.detect(
///     data: pcmData, sampleRate: 48000, channels: 2
/// )
/// for region in regions {
///     print("Silence: \(region.startTime)s - \(region.endTime)s")
/// }
/// ```
public struct SilenceDetector: Sendable {

    /// Threshold below which audio is considered silence (in dBFS).
    public let thresholdDB: Float

    /// Minimum silence duration in seconds to report.
    public let minimumDuration: Double

    /// Analysis window size in samples (frames).
    public let windowSize: Int

    /// Creates a silence detector.
    ///
    /// - Parameters:
    ///   - thresholdDB: Silence threshold in dBFS (default: -40).
    ///   - minimumDuration: Minimum silence duration in seconds (default: 1.0).
    ///   - windowSize: Analysis window in frames (default: 1024).
    public init(
        thresholdDB: Float = -40,
        minimumDuration: Double = 1.0,
        windowSize: Int = 1024
    ) {
        self.thresholdDB = thresholdDB
        self.minimumDuration = minimumDuration
        self.windowSize = max(1, windowSize)
    }

    /// Detect silence regions in interleaved Float32 PCM data.
    ///
    /// - Parameters:
    ///   - data: Float32 interleaved PCM data.
    ///   - sampleRate: Sample rate in Hz.
    ///   - channels: Number of channels.
    /// - Returns: Array of SilenceRegion sorted by start time.
    public func detect(
        data: Data, sampleRate: Int, channels: Int
    ) -> [SilenceRegion] {
        guard !data.isEmpty, channels > 0, sampleRate > 0 else { return [] }
        let totalFrames = data.count / (4 * channels)
        guard totalFrames > 0 else { return [] }

        var regions = [SilenceRegion]()
        var silenceStart: Int?
        var silenceLevels = [Float]()

        data.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Float.self)
            var pos = 0

            while pos < totalFrames {
                let end = min(pos + windowSize, totalFrames)
                let windowFrames = end - pos
                let rmsDB = windowRMSdB(
                    samples: samples, start: pos, frameCount: windowFrames,
                    channels: channels
                )

                if rmsDB < thresholdDB {
                    if silenceStart == nil { silenceStart = pos }
                    silenceLevels.append(rmsDB)
                } else {
                    if let start = silenceStart {
                        let region = buildRegion(
                            start: start, end: pos,
                            sampleRate: sampleRate, levels: silenceLevels
                        )
                        if region.duration >= minimumDuration {
                            regions.append(region)
                        }
                        silenceStart = nil
                        silenceLevels = []
                    }
                }
                pos = end
            }

            // Handle silence at end
            if let start = silenceStart {
                let region = buildRegion(
                    start: start, end: totalFrames,
                    sampleRate: sampleRate, levels: silenceLevels
                )
                if region.duration >= minimumDuration {
                    regions.append(region)
                }
            }
        }

        return regions
    }

    /// Check if a specific audio block is silence.
    ///
    /// - Parameters:
    ///   - block: Float32 interleaved PCM data block.
    ///   - channels: Number of channels.
    /// - Returns: True if the block's RMS level is below threshold.
    public func isSilent(block: Data, channels: Int) -> Bool {
        guard !block.isEmpty, channels > 0 else { return true }
        return block.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Float.self)
            let frameCount = samples.count / channels
            let rmsDB = windowRMSdB(
                samples: samples, start: 0, frameCount: frameCount,
                channels: channels
            )
            return rmsDB < thresholdDB
        }
    }

    // MARK: - Private

    private func windowRMSdB(
        samples: UnsafeBufferPointer<Float>,
        start: Int, frameCount: Int, channels: Int
    ) -> Float {
        guard frameCount > 0 else { return -.infinity }
        var sumSq: Double = 0
        let totalSamples = frameCount * channels
        for i in 0..<totalSamples {
            let s = Double(samples[start * channels + i])
            sumSq += s * s
        }
        let rms = Float(sqrt(sumSq / Double(totalSamples)))
        return LevelMeter.toDBFS(rms)
    }

    private func buildRegion(
        start: Int, end: Int, sampleRate: Int, levels: [Float]
    ) -> SilenceRegion {
        let avgLevel =
            levels.isEmpty
            ? -.infinity
            : levels.reduce(Float(0), +) / Float(levels.count)
        return SilenceRegion(
            startTime: Double(start) / Double(sampleRate),
            endTime: Double(end) / Double(sampleRate),
            duration: Double(end - start) / Double(sampleRate),
            averageLevelDB: avgLevel,
            startFrame: start,
            endFrame: end
        )
    }
}
