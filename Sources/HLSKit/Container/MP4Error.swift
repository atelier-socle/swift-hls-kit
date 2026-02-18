// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Errors that can occur during MP4 container operations.
///
/// - SeeAlso: ISO 14496-12
public enum MP4Error: Error, Sendable, Hashable {

    /// The data is not a valid MP4 file (missing ftyp or moov).
    case invalidMP4(String)

    /// A required box is missing.
    case missingBox(String)

    /// A box has invalid or corrupt data.
    case invalidBoxData(box: String, reason: String)

    /// The file is too large to process in memory.
    case fileTooLarge(Int64)

    /// A track has an unsupported codec.
    case unsupportedCodec(String)

    /// File I/O error.
    case ioError(String)
}

// MARK: - LocalizedError

extension MP4Error: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .invalidMP4(let detail):
            return "Invalid MP4 file: \(detail)"
        case .missingBox(let box):
            return "Missing required box: \(box)"
        case .invalidBoxData(let box, let reason):
            return "Invalid data in box '\(box)': \(reason)"
        case .fileTooLarge(let size):
            return
                "File too large to process in memory: "
                + "\(size) bytes"
        case .unsupportedCodec(let codec):
            return "Unsupported codec: \(codec)"
        case .ioError(let detail):
            return "I/O error: \(detail)"
        }
    }
}
