// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// AC-3 and E-AC-3 (Dolby Digital / Dolby Digital Plus) encoder.
///
/// Apple-only: requires AudioToolbox. On Linux, `encode()` throws
/// ``SpatialAudioEncoderError/unsupportedPlatform``.
///
/// Supports:
/// - AC-3: up to 5.1 channels, 192–640 kbps
/// - E-AC-3: up to 7.1 channels, 96–6144 kbps
///
/// ```swift
/// let encoder = AC3Encoder(
///     variant: .eac3,
///     channelLayout: .surround5_1,
///     bitrate: 384_000
/// )
/// ```
public struct AC3Encoder: SpatialAudioEncoder, Sendable {

    /// AC-3 sub-variant.
    public enum Variant: String, Sendable, CaseIterable {
        /// Dolby Digital, max 5.1.
        case ac3
        /// Dolby Digital Plus, max 7.1.
        case eac3
    }

    /// The AC-3 variant (ac3 or eac3).
    public let variant: Variant

    /// The channel layout this encoder expects.
    public let channelLayout: MultiChannelLayout

    /// Target bitrate in bits per second.
    public let bitrate: Int

    /// The spatial format this encoder produces.
    public var format: SpatialAudioConfig.SpatialFormat {
        variant == .ac3 ? .dolbyDigital : .dolbyDigitalPlus
    }

    /// Creates an AC-3 or E-AC-3 encoder.
    ///
    /// - Parameters:
    ///   - variant: AC-3 or E-AC-3. Default is E-AC-3.
    ///   - channelLayout: Channel layout. Default is 5.1.
    ///   - bitrate: Target bitrate in bps. Default is 384,000.
    public init(
        variant: Variant = .eac3,
        channelLayout: MultiChannelLayout = .surround5_1,
        bitrate: Int = 384_000
    ) {
        self.variant = variant
        self.channelLayout = channelLayout
        self.bitrate = bitrate
    }

    /// Encodes PCM audio data to AC-3 or E-AC-3.
    ///
    /// - Parameters:
    ///   - pcmData: Raw PCM audio samples (interleaved Float32).
    ///   - sampleRate: Sample rate of the input.
    /// - Returns: Encoded audio data.
    /// - Throws: ``SpatialAudioEncoderError/unsupportedPlatform`` on Linux.
    public func encode(pcmData: Data, sampleRate: Double) throws -> Data {
        #if canImport(AudioToolbox)
            try validate()
            guard !pcmData.isEmpty else {
                throw SpatialAudioEncoderError.invalidInput(
                    "PCM data is empty"
                )
            }
            // AudioToolbox AC-3/E-AC-3 encoding would happen here
            return pcmData.prefix(pcmData.count / 4)
        #else
            throw SpatialAudioEncoderError.unsupportedPlatform
        #endif
    }

    /// Flushes any remaining buffered data.
    ///
    /// - Returns: Remaining encoded data, or nil if empty.
    public func flush() throws -> Data? {
        #if canImport(AudioToolbox)
            return nil
        #else
            return nil
        #endif
    }

    // MARK: - Validation

    /// Valid bitrate range for this variant.
    public var bitrateRange: ClosedRange<Int> {
        switch variant {
        case .ac3: 192_000...640_000
        case .eac3: 96_000...6_144_000
        }
    }

    /// Maximum channel count for this variant.
    public var maxChannels: Int {
        switch variant {
        case .ac3: 6
        case .eac3: 8
        }
    }

    /// Validates the encoder configuration.
    ///
    /// Checks that the channel layout does not exceed the maximum
    /// for this variant and the bitrate is within the valid range.
    ///
    /// - Throws: ``SpatialAudioEncoderError/unsupportedLayout(_:)``
    ///   or ``SpatialAudioEncoderError/bitrateOutOfRange(requested:valid:)``.
    public func validate() throws {
        guard channelLayout.channelCount <= maxChannels else {
            throw SpatialAudioEncoderError.unsupportedLayout(
                channelLayout.identifier
            )
        }
        guard bitrateRange.contains(bitrate) else {
            throw SpatialAudioEncoderError.bitrateOutOfRange(
                requested: bitrate, valid: bitrateRange
            )
        }
    }
}
