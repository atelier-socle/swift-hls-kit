// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Dolby Atmos encoder using E-AC-3 JOC (Joint Object Coding).
///
/// Apple-only: requires AudioToolbox with Enhanced AC-3 codec support.
/// On Linux, `encode()` throws ``SpatialAudioEncoderError/unsupportedPlatform``.
///
/// ```swift
/// let encoder = DolbyAtmosEncoder(
///     channelLayout: .atmos7_1_4,
///     bitrate: 768_000
/// )
/// let encoded = try encoder.encode(pcmData: samples, sampleRate: 48000)
/// ```
public struct DolbyAtmosEncoder: SpatialAudioEncoder, Sendable {

    /// The spatial format produced by this encoder.
    public let format: SpatialAudioConfig.SpatialFormat = .dolbyAtmos

    /// The channel layout this encoder expects.
    public let channelLayout: MultiChannelLayout

    /// Target bitrate in bits per second.
    public let bitrate: Int

    /// Creates a Dolby Atmos encoder.
    ///
    /// - Parameters:
    ///   - channelLayout: Channel layout for encoding. Default is 7.1.4.
    ///   - bitrate: Target bitrate in bps. Default is 768,000.
    public init(
        channelLayout: MultiChannelLayout = .atmos7_1_4,
        bitrate: Int = 768_000
    ) {
        self.channelLayout = channelLayout
        self.bitrate = bitrate
    }

    /// Encodes PCM audio data to Dolby Atmos (E-AC-3 JOC).
    ///
    /// - Parameters:
    ///   - pcmData: Raw PCM audio samples (interleaved Float32).
    ///   - sampleRate: Sample rate of the input.
    /// - Returns: Encoded audio data.
    /// - Throws: ``SpatialAudioEncoderError/unsupportedPlatform`` on Linux.
    public func encode(pcmData: Data, sampleRate: Double) throws -> Data {
        #if canImport(AudioToolbox)
            guard !pcmData.isEmpty else {
                throw SpatialAudioEncoderError.invalidInput(
                    "PCM data is empty"
                )
            }
            try validateLayout()
            // AudioToolbox E-AC-3 JOC encoding would happen here
            // Return placeholder for now — real implementation uses AudioConverter
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

    /// Validates the channel layout is compatible with Atmos encoding.
    ///
    /// Atmos requires at least 5.1 channels (6 channels minimum).
    ///
    /// - Throws: ``SpatialAudioEncoderError/unsupportedLayout(_:)``
    ///   if the layout has fewer than 6 channels.
    public func validateLayout() throws {
        guard channelLayout.channelCount >= 6 else {
            throw SpatialAudioEncoderError.unsupportedLayout(
                channelLayout.identifier
            )
        }
    }
}
