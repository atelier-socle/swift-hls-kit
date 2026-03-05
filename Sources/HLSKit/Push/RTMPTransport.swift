// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// FLV tag types for RTMP streaming.
///
/// Used to distinguish audio, video, and metadata payloads
/// when sending data over RTMP.
public enum FLVTagType: UInt8, Sendable, Equatable {

    /// Audio data (FLV tag type 8).
    case audio = 8

    /// Video data (FLV tag type 9).
    case video = 9

    /// Script/metadata data (FLV tag type 18).
    case scriptData = 18
}

/// Protocol for RTMP transport operations.
///
/// Users implement this with their preferred RTMP library
/// (e.g., HaishinKit, librtmp wrapper). swift-hls-kit handles
/// the HLS-specific orchestration while the transport handles
/// raw RTMP communication.
public protocol RTMPTransport: Sendable {

    /// Connect to an RTMP server.
    ///
    /// - Parameter url: RTMP URL including stream key
    ///   (e.g., `"rtmp://live.twitch.tv/app/stream_key"`).
    func connect(to url: String) async throws

    /// Disconnect from the RTMP server.
    func disconnect() async

    /// Send FLV-encapsulated data.
    ///
    /// - Parameters:
    ///   - data: The FLV packet data.
    ///   - timestamp: Presentation timestamp in milliseconds.
    ///   - type: The FLV tag type (audio, video, script).
    func send(
        data: Data, timestamp: UInt32, type: FLVTagType
    ) async throws

    /// Whether the transport is currently connected.
    var isConnected: Bool { get async }

    /// Send dynamic metadata during an active stream.
    ///
    /// Transports that support live metadata injection (e.g.,
    /// RTMPKit 0.2.0) override this to update stream metadata
    /// on the fly. The default implementation is a no-op.
    ///
    /// - Parameter metadata: Key-value metadata pairs to send.
    func sendMetadata(_ metadata: [String: String]) async throws

    /// Server capabilities detected during the RTMP handshake.
    ///
    /// Transports that perform capability detection (e.g., Enhanced
    /// RTMP v2 negotiation) override this to report the server's
    /// advertised features. The default implementation returns `nil`.
    var serverCapabilities: RTMPServerCapabilities? { get async }
}

// MARK: - Default Implementations

extension RTMPTransport {

    /// Default no-op implementation for backward compatibility.
    public func sendMetadata(
        _ metadata: [String: String]
    ) async throws {
        // No-op: legacy transports do not support dynamic metadata.
    }

    /// Default implementation returns `nil` for backward compatibility.
    public var serverCapabilities: RTMPServerCapabilities? {
        get async { nil }
    }
}
