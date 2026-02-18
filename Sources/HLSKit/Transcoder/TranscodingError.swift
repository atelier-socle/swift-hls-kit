// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Errors during transcoding operations.
///
/// Each case provides a descriptive message explaining the failure.
/// Use these to diagnose issues with source files, output paths,
/// codec availability, or encoding failures.
///
/// - SeeAlso: ``Transcoder``
public enum TranscodingError: Error, Sendable, Hashable {

    /// Source file not found or not readable.
    case sourceNotFound(String)

    /// Source file format not supported.
    case unsupportedSourceFormat(String)

    /// Output directory doesn't exist or isn't writable.
    case outputDirectoryError(String)

    /// Codec not available on this platform.
    case codecNotAvailable(String)

    /// Hardware encoder not available.
    case hardwareEncoderNotAvailable(String)

    /// Encoding failed.
    case encodingFailed(String)

    /// Decoding source failed.
    case decodingFailed(String)

    /// Transcoding was cancelled.
    case cancelled

    /// Configuration error.
    case invalidConfig(String)

    /// Transcoder not available on this platform.
    case transcoderNotAvailable(String)
}

// MARK: - LocalizedError

extension TranscodingError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .sourceNotFound(let message):
            return "Source not found: \(message)"
        case .unsupportedSourceFormat(let message):
            return "Unsupported source format: \(message)"
        case .outputDirectoryError(let message):
            return "Output directory error: \(message)"
        case .codecNotAvailable(let message):
            return "Codec not available: \(message)"
        case .hardwareEncoderNotAvailable(let message):
            return "Hardware encoder not available: \(message)"
        case .encodingFailed(let message):
            return "Encoding failed: \(message)"
        case .decodingFailed(let message):
            return "Decoding failed: \(message)"
        case .cancelled:
            return "Transcoding was cancelled"
        case .invalidConfig(let message):
            return "Invalid configuration: \(message)"
        case .transcoderNotAvailable(let message):
            return "Transcoder not available: \(message)"
        }
    }
}
