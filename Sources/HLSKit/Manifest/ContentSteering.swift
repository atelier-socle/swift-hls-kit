// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Content steering configuration from `EXT-X-CONTENT-STEERING`.
///
/// Content steering allows a content distributor to control which CDN
/// serves content to which clients by providing a steering manifest
/// that the client periodically fetches. See RFC 8216bis.
public struct ContentSteering: Sendable, Hashable, Codable {

    /// The URI of the steering server.
    public var serverUri: String

    /// An optional pathway identifier that the client should use
    /// as the initial pathway.
    public var pathwayId: String?

    /// Creates a content steering configuration.
    ///
    /// - Parameters:
    ///   - serverUri: The steering server URI.
    ///   - pathwayId: An optional initial pathway identifier.
    public init(serverUri: String, pathwayId: String? = nil) {
        self.serverUri = serverUri
        self.pathwayId = pathwayId
    }
}
