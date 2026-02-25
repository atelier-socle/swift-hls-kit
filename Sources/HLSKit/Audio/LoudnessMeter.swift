// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Loudness measurement result.
public struct LoudnessResult: Sendable, Equatable {

    /// Loudness in LUFS (Loudness Units Full Scale).
    public let loudness: Float

    /// Loudness range in LU (Loudness Units).
    public let range: Float?
}

/// Gating block used in integrated loudness calculation.
public struct GatingBlock: Sendable {

    /// Mean square energy per channel (K-weighted).
    public let channelEnergy: [Float]

    /// Block loudness in LUFS.
    public let loudness: Float
}

/// Measures loudness per EBU R 128 / ITU-R BS.1770-4.
///
/// Provides momentary (400ms), short-term (3s), and integrated
/// (whole-programme) loudness measurements in LUFS.
///
/// ```swift
/// var meter = LoudnessMeter(sampleRate: 48000, channels: 2)
/// meter.process(block: pcmBlock)
/// let result = meter.integratedLoudness()
/// print("Integrated: \(result.loudness) LUFS")
/// ```
public struct LoudnessMeter: Sendable {

    // MARK: - Properties

    private let sampleRate: Int
    private let channels: Int
    private let blockSize: Int  // 400ms in samples
    private let stepSize: Int  // 100ms in samples (75% overlap)
    private var kWeightedBuffer: [Float]
    private var gatingBlocks: [GatingBlock]
    // Per channel: [s1_x1, s1_x2, s1_y1, s1_y2, s2_x1, s2_x2, s2_y1, s2_y2]
    private var filterState: [[Double]]

    /// Creates a loudness meter.
    ///
    /// - Parameters:
    ///   - sampleRate: Audio sample rate (e.g. 44100, 48000).
    ///   - channels: Number of channels (1 = mono, 2 = stereo).
    public init(sampleRate: Int, channels: Int) {
        self.sampleRate = sampleRate
        self.channels = max(1, channels)
        self.blockSize = sampleRate * 4 / 10  // 400ms
        self.stepSize = sampleRate / 10  // 100ms
        self.kWeightedBuffer = []
        self.gatingBlocks = []
        self.filterState = Array(
            repeating: Array(repeating: 0.0, count: 8),
            count: self.channels
        )
    }

    /// Process a block of interleaved Float32 PCM data.
    ///
    /// Accumulates K-weighted data for gated loudness calculation.
    /// - Parameter block: Float32 interleaved PCM data.
    public mutating func process(block: Data) {
        guard !block.isEmpty else { return }
        let coeffs = Self.coefficients(for: sampleRate)

        block.withUnsafeBytes { raw in
            let samples = raw.bindMemory(to: Float.self)
            let frameCount = samples.count / channels

            for i in 0..<frameCount {
                var sumSq: Float = 0
                for ch in 0..<channels {
                    let sample = Double(samples[i * channels + ch])
                    let filtered = applyKWeighting(
                        sample, channel: ch, coeffs: coeffs
                    )
                    sumSq += Float(filtered * filtered)
                }
                kWeightedBuffer.append(sumSq / Float(channels))
            }
        }

        buildGatingBlocks()
    }

    /// Reset the meter state.
    public mutating func reset() {
        kWeightedBuffer = []
        gatingBlocks = []
        filterState = Array(
            repeating: Array(repeating: 0.0, count: 8),
            count: channels
        )
    }

    /// Calculate momentary loudness (last 400ms window).
    ///
    /// - Returns: Loudness in LUFS, or nil if not enough data.
    public func momentaryLoudness() -> Float? {
        guard kWeightedBuffer.count >= blockSize else { return nil }
        let start = kWeightedBuffer.count - blockSize
        let window = kWeightedBuffer[start...]
        let mean = window.reduce(Float(0), +) / Float(blockSize)
        return Self.energyToLUFS(mean)
    }

    /// Calculate short-term loudness (last 3s window).
    ///
    /// - Returns: Loudness in LUFS, or nil if not enough data.
    public func shortTermLoudness() -> Float? {
        let shortTermSize = sampleRate * 3
        guard kWeightedBuffer.count >= shortTermSize else { return nil }
        let start = kWeightedBuffer.count - shortTermSize
        let window = kWeightedBuffer[start...]
        let mean = window.reduce(Float(0), +) / Float(shortTermSize)
        return Self.energyToLUFS(mean)
    }

    /// Calculate integrated loudness using EBU R 128 gating.
    ///
    /// Two-stage gating: absolute threshold (-70 LUFS) then
    /// relative threshold (-10 LU below ungated mean).
    /// - Returns: LoudnessResult with loudness and optional range.
    public func integratedLoudness() -> LoudnessResult {
        guard !gatingBlocks.isEmpty else {
            return LoudnessResult(loudness: -.infinity, range: nil)
        }

        // Stage 1: Absolute gate at -70 LUFS
        let absGated = gatingBlocks.filter { $0.loudness > -70.0 }
        guard !absGated.isEmpty else {
            return LoudnessResult(loudness: -.infinity, range: nil)
        }

        // Calculate mean of absolute-gated blocks
        let meanEnergy =
            absGated.reduce(Float(0)) { sum, blk in
                sum + blk.channelEnergy.reduce(0, +) / Float(channels)
            } / Float(absGated.count)
        let ungatedLUFS = Self.energyToLUFS(meanEnergy)

        // Stage 2: Relative gate at (ungatedLUFS - 10)
        let relThreshold = ungatedLUFS - 10.0
        let relGated = absGated.filter { $0.loudness > relThreshold }
        guard !relGated.isEmpty else {
            return LoudnessResult(loudness: -.infinity, range: nil)
        }

        let finalEnergy =
            relGated.reduce(Float(0)) { sum, blk in
                sum + blk.channelEnergy.reduce(0, +) / Float(channels)
            } / Float(relGated.count)

        return LoudnessResult(
            loudness: Self.energyToLUFS(finalEnergy),
            range: loudnessRange()
        )
    }

    /// Calculate loudness range (LRA) per EBU R 128 s1.
    ///
    /// - Returns: LRA in LU, or nil if not enough data.
    public func loudnessRange() -> Float? {
        let stBlockSize = sampleRate * 3
        let stStepSize = sampleRate
        guard kWeightedBuffer.count >= stBlockSize else { return nil }

        // Build short-term blocks
        var stBlocks = [Float]()
        var pos = 0
        while pos + stBlockSize <= kWeightedBuffer.count {
            let window = kWeightedBuffer[pos..<(pos + stBlockSize)]
            let mean = window.reduce(Float(0), +) / Float(stBlockSize)
            stBlocks.append(Self.energyToLUFS(mean))
            pos += stStepSize
        }

        // Absolute gate
        let absGated = stBlocks.filter { $0 > -70.0 }
        guard !absGated.isEmpty else { return nil }

        let ungatedMean =
            absGated.reduce(Float(0), +)
            / Float(absGated.count)
        let relGated = absGated.filter { $0 > ungatedMean - 20.0 }
        guard relGated.count >= 2 else { return nil }

        let sorted = relGated.sorted()
        let p10 = sorted[Int(Float(sorted.count) * 0.1)]
        let p95 = sorted[
            Int(
                min(
                    Float(sorted.count) * 0.95,
                    Float(sorted.count - 1)
                ))]
        return p95 - p10
    }

    // MARK: - Private

    private mutating func applyKWeighting(
        _ sample: Double, channel: Int, coeffs: KWeightCoeffs
    ) -> Double {
        // Direct Form I biquad: y = b0*x + b1*x1 + b2*x2 - a1*y1 - a2*y2
        // State indices: s1_x1=0, s1_x2=1, s1_y1=2, s1_y2=3
        //                s2_x1=4, s2_x2=5, s2_y1=6, s2_y2=7

        // Stage 1: Pre-filter (high-shelf)
        let y1 =
            coeffs.s1b0 * sample
            + coeffs.s1b1 * filterState[channel][0]
            + coeffs.s1b2 * filterState[channel][1]
            - coeffs.s1a1 * filterState[channel][2]
            - coeffs.s1a2 * filterState[channel][3]
        filterState[channel][1] = filterState[channel][0]
        filterState[channel][0] = sample
        filterState[channel][3] = filterState[channel][2]
        filterState[channel][2] = y1

        // Stage 2: RLB weighting (high-pass)
        let y2 =
            coeffs.s2b0 * y1
            + coeffs.s2b1 * filterState[channel][4]
            + coeffs.s2b2 * filterState[channel][5]
            - coeffs.s2a1 * filterState[channel][6]
            - coeffs.s2a2 * filterState[channel][7]
        filterState[channel][5] = filterState[channel][4]
        filterState[channel][4] = y1
        filterState[channel][7] = filterState[channel][6]
        filterState[channel][6] = y2

        return y2
    }

    private mutating func buildGatingBlocks() {
        while kWeightedBuffer.count >= blockSize {
            let processed = gatingBlocks.count * stepSize
            let nextStart = processed
            guard nextStart + blockSize <= kWeightedBuffer.count else { break }

            let window = kWeightedBuffer[
                nextStart..<(nextStart + blockSize)
            ]
            let meanEnergy = window.reduce(Float(0), +) / Float(blockSize)
            let channelEnergies = Array(repeating: meanEnergy, count: channels)

            gatingBlocks.append(
                GatingBlock(
                    channelEnergy: channelEnergies,
                    loudness: Self.energyToLUFS(meanEnergy)
                ))
        }
    }

    private static func energyToLUFS(_ energy: Float) -> Float {
        guard energy > 0 else { return -.infinity }
        return -0.691 + 10.0 * log10(energy)
    }

    // MARK: - K-Weighting Coefficients

    struct KWeightCoeffs: Sendable {
        let s1b0: Double
        let s1b1: Double
        let s1b2: Double
        let s1a1: Double
        let s1a2: Double
        let s2b0: Double
        let s2b1: Double
        let s2b2: Double
        let s2a1: Double
        let s2a2: Double
    }

    private static func coefficients(for sampleRate: Int) -> KWeightCoeffs {
        if sampleRate == 44100 {
            return KWeightCoeffs(
                s1b0: 1.53089120535743, s1b1: -2.65065413033401,
                s1b2: 1.16905863028857,
                s1a1: -1.66363794256169, s1a2: 0.71268798052460,
                s2b0: 1.0, s2b1: -2.0, s2b2: 1.0,
                s2a1: -1.98916967592870, s2a2: 0.98919177890368
            )
        }
        // 48000 Hz (default per ITU-R BS.1770-4)
        return KWeightCoeffs(
            s1b0: 1.53512485958697, s1b1: -2.69169618940638,
            s1b2: 1.19839281085285,
            s1a1: -1.69065929318241, s1a2: 0.73248077421585,
            s2b0: 1.0, s2b1: -2.0, s2b2: 1.0,
            s2a1: -1.99004745483398, s2a2: 0.99007225036621
        )
    }
}
