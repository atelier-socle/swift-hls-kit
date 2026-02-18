// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Errors during MPEG-TS transport stream operations.
///
/// - SeeAlso: ISO 13818-1
public enum TransportError: Error, Sendable, Hashable {

    /// Invalid avcC box data.
    case invalidAVCConfig(String)

    /// Invalid AudioSpecificConfig / esds data.
    case invalidAudioConfig(String)

    /// PES packetization error.
    case pesError(String)

    /// TS packet writing error.
    case packetError(String)

    /// Unsupported codec for TS packaging.
    case unsupportedCodec(String)
}

// MARK: - LocalizedError

extension TransportError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .invalidAVCConfig(let detail):
            return "Invalid AVC configuration: \(detail)"
        case .invalidAudioConfig(let detail):
            return "Invalid audio configuration: \(detail)"
        case .pesError(let detail):
            return "PES packetization error: \(detail)"
        case .packetError(let detail):
            return "TS packet error: \(detail)"
        case .unsupportedCodec(let codec):
            return "Unsupported codec for TS: \(codec)"
        }
    }
}
