// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Mixes audio channels with configurable matrices.
///
/// Supports common operations:
/// - Mono → stereo (duplication or phantom center)
/// - Stereo → mono (average, left-only, right-only)
/// - 5.1 → stereo (ITU-R BS.775 standard downmix)
/// - 7.1 → stereo downmix
/// - Custom N→M channel mixing via matrix
///
/// All operations work on interleaved Float32 PCM data.
///
/// ```swift
/// let mixer = ChannelMixer()
/// let stereo = mixer.monoToStereo(monoData)
/// let mono = mixer.stereoToMono(stereoData)
/// let downmixed = mixer.surroundToStereo(fiveOneData)
/// ```
public struct ChannelMixer: Sendable {

    // MARK: - Types

    /// Channel layout identifier.
    public enum ChannelLayout: String, Sendable, Equatable, CaseIterable {

        /// 1 channel: C.
        case mono

        /// 2 channels: L R.
        case stereo

        /// 6 channels: L R C LFE Ls Rs.
        case surround51

        /// 8 channels: L R C LFE Ls Rs Lrs Rrs.
        case surround71
    }

    /// A mixing matrix: gains[outputChannel][inputChannel].
    public struct MixMatrix: Sendable, Equatable {

        /// Gain coefficients: gains[outputChannel][inputChannel].
        public var gains: [[Double]]

        /// Creates a mix matrix.
        public init(gains: [[Double]]) {
            self.gains = gains
        }

        /// Number of input channels.
        public var inputChannels: Int { gains.first?.count ?? 0 }

        /// Number of output channels.
        public var outputChannels: Int { gains.count }

        /// Whether the matrix dimensions are consistent.
        public var isValid: Bool {
            guard !gains.isEmpty else { return false }
            let expected = gains[0].count
            return expected > 0 && gains.allSatisfy { $0.count == expected }
        }
    }

    /// Mono to stereo mode.
    public enum MonoToStereoMode: String, Sendable, Equatable {

        /// Same signal on both channels.
        case duplicate

        /// Phantom center (-3dB each channel).
        case center
    }

    /// Stereo to mono mode.
    public enum StereoToMonoMode: String, Sendable, Equatable {

        /// (L + R) / 2.
        case average

        /// Left channel only.
        case left

        /// Right channel only.
        case right
    }

    /// Creates a channel mixer.
    public init() {}

    // MARK: - Standard Conversions

    /// Convert mono to stereo (interleaved Float32).
    ///
    /// - Parameters:
    ///   - data: Mono interleaved Float32 PCM data.
    ///   - mode: Duplication mode.
    /// - Returns: Stereo interleaved Float32 PCM data.
    public func monoToStereo(
        _ data: Data, mode: MonoToStereoMode = .duplicate
    ) -> Data {
        guard !data.isEmpty else { return Data() }
        let sampleCount = data.count / 4
        var output = Data(count: sampleCount * 2 * 4)
        let gain: Float = mode == .center ? Float(1.0 / sqrt(2.0)) : 1.0

        data.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                let src = raw.bindMemory(to: Float.self)
                let dst = out.bindMemory(to: Float.self)
                for i in 0..<sampleCount {
                    let sample = src[i] * gain
                    dst[i * 2] = sample
                    dst[i * 2 + 1] = sample
                }
            }
        }
        return output
    }

    /// Convert stereo to mono (interleaved Float32).
    ///
    /// - Parameters:
    ///   - data: Stereo interleaved Float32 PCM data.
    ///   - mode: Mixdown mode.
    /// - Returns: Mono Float32 PCM data.
    public func stereoToMono(
        _ data: Data, mode: StereoToMonoMode = .average
    ) -> Data {
        guard !data.isEmpty else { return Data() }
        let frameCount = data.count / 8
        var output = Data(count: frameCount * 4)

        data.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                let src = raw.bindMemory(to: Float.self)
                let dst = out.bindMemory(to: Float.self)
                for i in 0..<frameCount {
                    let left = src[i * 2]
                    let right = src[i * 2 + 1]
                    switch mode {
                    case .average: dst[i] = (left + right) * 0.5
                    case .left: dst[i] = left
                    case .right: dst[i] = right
                    }
                }
            }
        }
        return output
    }

    /// Downmix 5.1 surround to stereo (ITU-R BS.775 standard).
    ///
    /// Channel order: L(0), R(1), C(2), LFE(3), Ls(4), Rs(5).
    /// - L_out = L + 0.707×C + 0.707×Ls
    /// - R_out = R + 0.707×C + 0.707×Rs
    /// - Parameters:
    ///   - data: 5.1 interleaved Float32 PCM data.
    ///   - includeLFE: Whether to mix LFE into the output.
    ///   - lfeGain: Gain for LFE channel when included.
    /// - Returns: Stereo interleaved Float32 PCM data.
    public func surroundToStereo(
        _ data: Data, includeLFE: Bool = false, lfeGain: Double = 0.5
    ) -> Data {
        guard !data.isEmpty else { return Data() }
        let frameCount = data.count / (6 * 4)
        var output = Data(count: frameCount * 2 * 4)
        let coeff = Float(1.0 / sqrt(2.0))
        let lfe = Float(lfeGain)

        data.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                let src = raw.bindMemory(to: Float.self)
                let dst = out.bindMemory(to: Float.self)
                for i in 0..<frameCount {
                    let base = i * 6
                    let l = src[base]
                    let r = src[base + 1]
                    let c = src[base + 2]
                    let lfeVal = src[base + 3]
                    let ls = src[base + 4]
                    let rs = src[base + 5]

                    var lOut = l + coeff * c + coeff * ls
                    var rOut = r + coeff * c + coeff * rs
                    if includeLFE {
                        lOut += lfe * lfeVal
                        rOut += lfe * lfeVal
                    }
                    dst[i * 2] = max(-1.0, min(1.0, lOut))
                    dst[i * 2 + 1] = max(-1.0, min(1.0, rOut))
                }
            }
        }
        return output
    }

    /// Downmix 7.1 surround to stereo.
    ///
    /// Channel order: L(0), R(1), C(2), LFE(3), Ls(4), Rs(5), Lrs(6), Rrs(7).
    /// Uses ``applyMatrix(_:matrix:)`` with the standard 7.1→stereo matrix.
    /// - Parameter data: 7.1 interleaved Float32 PCM data.
    /// - Returns: Stereo interleaved Float32 PCM data.
    public func surround71ToStereo(_ data: Data) -> Data {
        applyMatrix(data, matrix: Self.surround71ToStereoMatrix())
    }

    // MARK: - Custom Matrix Mixing

    /// Apply a custom mix matrix to audio data.
    ///
    /// - Parameters:
    ///   - data: Interleaved Float32 PCM data.
    ///   - matrix: Mix matrix defining input→output channel mapping.
    /// - Returns: Mixed interleaved Float32 PCM data.
    public func applyMatrix(_ data: Data, matrix: MixMatrix) -> Data {
        guard !data.isEmpty, matrix.isValid else { return Data() }
        let frameCount = data.count / (matrix.inputChannels * 4)
        guard frameCount > 0 else { return Data() }
        var output = Data(count: frameCount * matrix.outputChannels * 4)

        data.withUnsafeBytes { raw in
            output.withUnsafeMutableBytes { out in
                let src = raw.bindMemory(to: Float.self)
                let dst = out.bindMemory(to: Float.self)
                for frame in 0..<frameCount {
                    for outCh in 0..<matrix.outputChannels {
                        var sum: Float = 0
                        for inCh in 0..<matrix.inputChannels {
                            sum +=
                                src[frame * matrix.inputChannels + inCh]
                                * Float(matrix.gains[outCh][inCh])
                        }
                        dst[frame * matrix.outputChannels + outCh] =
                            max(-1.0, min(1.0, sum))
                    }
                }
            }
        }
        return output
    }

    // MARK: - Standard Matrices

    /// Standard stereo→mono mixdown matrix.
    ///
    /// - Parameter mode: Mixdown mode.
    /// - Returns: 2→1 mix matrix.
    public static func stereoToMonoMatrix(
        mode: StereoToMonoMode = .average
    ) -> MixMatrix {
        switch mode {
        case .average: return MixMatrix(gains: [[0.5, 0.5]])
        case .left: return MixMatrix(gains: [[1.0, 0.0]])
        case .right: return MixMatrix(gains: [[0.0, 1.0]])
        }
    }

    /// Standard mono→stereo matrix.
    ///
    /// - Parameter mode: Duplication mode.
    /// - Returns: 1→2 mix matrix.
    public static func monoToStereoMatrix(
        mode: MonoToStereoMode = .duplicate
    ) -> MixMatrix {
        let gain = mode == .center ? 1.0 / sqrt(2.0) : 1.0
        return MixMatrix(gains: [[gain], [gain]])
    }

    /// ITU-R BS.775 5.1→stereo downmix matrix.
    ///
    /// - Parameters:
    ///   - includeLFE: Whether to include LFE channel.
    ///   - lfeGain: Gain for LFE channel.
    /// - Returns: 6→2 mix matrix.
    public static func surround51ToStereoMatrix(
        includeLFE: Bool = false, lfeGain: Double = 0.5
    ) -> MixMatrix {
        let c = 1.0 / sqrt(2.0)
        let lfe = includeLFE ? lfeGain : 0.0
        return MixMatrix(gains: [
            [1.0, 0.0, c, lfe, c, 0.0],
            [0.0, 1.0, c, lfe, 0.0, c]
        ])
    }

    /// 7.1→stereo downmix matrix.
    ///
    /// - Returns: 8→2 mix matrix.
    public static func surround71ToStereoMatrix() -> MixMatrix {
        let c = 1.0 / sqrt(2.0)
        return MixMatrix(gains: [
            [1.0, 0.0, c, 0.0, c, 0.0, c, 0.0],
            [0.0, 1.0, c, 0.0, 0.0, c, 0.0, c]
        ])
    }

    // MARK: - Utilities

    /// Calculate output data size for a channel count change.
    ///
    /// Assumes Float32 (4 bytes per sample).
    /// - Parameters:
    ///   - inputSize: Input data size in bytes.
    ///   - inputChannels: Number of input channels.
    ///   - outputChannels: Number of output channels.
    /// - Returns: Output data size in bytes.
    public func outputDataSize(
        inputSize: Int, inputChannels: Int, outputChannels: Int
    ) -> Int {
        guard inputChannels > 0 else { return 0 }
        let frameCount = inputSize / (inputChannels * 4)
        return frameCount * outputChannels * 4
    }

    /// Validate that data size matches expected frame alignment.
    ///
    /// - Parameters:
    ///   - data: PCM data.
    ///   - channels: Number of channels.
    ///   - sampleFormat: Sample format.
    /// - Returns: True if data size is correctly aligned.
    public func validateDataSize(
        _ data: Data, channels: Int,
        sampleFormat: AudioFormatConverter.SampleFormat
    ) -> Bool {
        guard !data.isEmpty else { return true }
        let bps = sampleFormat.bytesPerSample
        return data.count % (channels * bps) == 0
    }
}
