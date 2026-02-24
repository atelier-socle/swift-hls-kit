// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Errors thrown by ``LiveEncoder`` implementations.
///
/// Each case corresponds to a specific failure mode in the encoding pipeline.
public enum LiveEncoderError: Error, Sendable, Equatable {

    /// The encoder has not been configured yet. Call ``LiveEncoder/configure(_:)`` first.
    case notConfigured

    /// The requested configuration is not supported by this encoder.
    ///
    /// - Parameter reason: Human-readable explanation of why the configuration is unsupported.
    case unsupportedConfiguration(String)

    /// Encoding failed for a specific buffer.
    ///
    /// - Parameter reason: Human-readable description of the failure.
    case encodingFailed(String)

    /// The input buffer format does not match the configured format.
    ///
    /// - Parameter reason: Human-readable description of the mismatch.
    case formatMismatch(String)

    /// The encoder has already been torn down and cannot accept new input.
    case tornDown

    /// ffmpeg binary is not available on this system.
    case ffmpegNotAvailable

    /// The ffmpeg process exited with an error.
    ///
    /// - Parameter reason: Human-readable description of the ffmpeg error.
    case ffmpegProcessError(String)
}
