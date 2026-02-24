// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Errors that can occur when working with media sources.
public enum InputError: Error, Sendable, Hashable {

    /// The input file or data is invalid.
    case invalidInput(String)

    /// No supported media tracks were found.
    case noMediaTracks

    /// The requested sample index is out of bounds.
    case sampleIndexOutOfBounds(index: Int, total: Int)

    /// The source has already finished producing data.
    case sourceExhausted

    /// An underlying I/O error occurred.
    case ioError(String)
}

// MARK: - LocalizedError

extension InputError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .noMediaTracks:
            return "No audio or video tracks found in input"
        case .sampleIndexOutOfBounds(let index, let total):
            return "Sample index \(index) out of bounds (total: \(total))"
        case .sourceExhausted:
            return "Media source has finished producing data"
        case .ioError(let message):
            return "I/O error: \(message)"
        }
    }
}
