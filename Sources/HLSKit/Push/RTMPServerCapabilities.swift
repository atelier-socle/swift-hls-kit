// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// RTMP server capabilities detected during connection handshake.
///
/// Reported by transports that perform server capability detection.
/// In RTMPKit 0.2.0, this information is derived from the server's
/// `_result` response to the `connect` command.
public struct RTMPServerCapabilities: Sendable, Equatable {

    /// Whether the server supports Enhanced RTMP v2.
    ///
    /// When `true`, the transport can negotiate advanced codecs
    /// (HEVC, AV1, VP9) via FourCC extension headers.
    public let supportsEnhancedRTMP: Bool

    /// Server software identification (e.g., `"nginx-rtmp"`, `"Wowza"`).
    ///
    /// Extracted from the `fmsVer` field in the server's connect response.
    public let serverVersion: String?

    /// Supported codecs advertised by the server.
    ///
    /// For Enhanced RTMP v2 servers, this includes FourCC identifiers
    /// (e.g., `"hvc1"`, `"av01"`). For legacy servers, this set is
    /// typically empty.
    public let supportedCodecs: Set<String>

    /// Creates an RTMP server capabilities descriptor.
    ///
    /// - Parameters:
    ///   - supportsEnhancedRTMP: Whether Enhanced RTMP v2 is supported.
    ///   - serverVersion: Server software identification.
    ///   - supportedCodecs: Set of supported codec identifiers.
    public init(
        supportsEnhancedRTMP: Bool,
        serverVersion: String?,
        supportedCodecs: Set<String>
    ) {
        self.supportsEnhancedRTMP = supportsEnhancedRTMP
        self.serverVersion = serverVersion
        self.supportedCodecs = supportedCodecs
    }
}
