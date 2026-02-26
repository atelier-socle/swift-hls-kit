// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Protocol for spatial audio encoding.
///
/// Implementations handle codec-specific encoding (Atmos, AC-3, E-AC-3).
/// Apple-only implementations use AudioToolbox; stubs provided for Linux.
public protocol SpatialAudioEncoder: Sendable {

    /// The spatial format this encoder produces.
    var format: SpatialAudioConfig.SpatialFormat { get }

    /// The channel layout this encoder expects.
    var channelLayout: MultiChannelLayout { get }

    /// Target bitrate in bits per second.
    var bitrate: Int { get }

    /// Encode PCM audio data to the spatial format.
    ///
    /// - Parameters:
    ///   - pcmData: Raw PCM audio samples (interleaved Float32).
    ///   - sampleRate: Sample rate of the input.
    /// - Returns: Encoded audio data in the target format.
    func encode(pcmData: Data, sampleRate: Double) throws -> Data

    /// Flush any remaining buffered data.
    func flush() throws -> Data?
}

// MARK: - Errors

/// Errors specific to spatial audio encoding.
public enum SpatialAudioEncoderError: Error, Sendable, Equatable {
    /// The current platform does not support this encoder.
    case unsupportedPlatform
    /// The requested spatial format is not supported.
    case unsupportedFormat(SpatialAudioConfig.SpatialFormat)
    /// The channel layout is not compatible with this encoder.
    case unsupportedLayout(MultiChannelLayout.LayoutIdentifier)
    /// Encoding failed with a description.
    case encodingFailed(String)
    /// The input data is invalid.
    case invalidInput(String)
    /// The requested bitrate is outside the valid range.
    case bitrateOutOfRange(requested: Int, valid: ClosedRange<Int>)
}
