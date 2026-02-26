// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration for HLS Content Steering (EXT-X-CONTENT-STEERING).
///
/// Content steering allows dynamic CDN switching by providing a
/// steering manifest URL that clients poll for pathway priorities.
///
/// ```swift
/// let config = ContentSteeringConfig(
///     serverURI: "https://steering.example.com/manifest",
///     pathways: ["CDN-A", "CDN-B", "CDN-C"],
///     defaultPathway: "CDN-A"
/// )
/// ```
public struct ContentSteeringConfig: Sendable, Equatable {

    /// Steering manifest server URI.
    public var serverURI: String

    /// Available pathway IDs.
    public var pathways: [String]

    /// Default pathway (used if steering manifest unavailable).
    public var defaultPathway: String

    /// Polling interval in seconds (TTL).
    public var pollingInterval: TimeInterval

    /// Creates a content steering configuration.
    ///
    /// - Parameters:
    ///   - serverURI: The steering manifest server URI.
    ///   - pathways: Available pathway IDs.
    ///   - defaultPathway: The default pathway ID.
    ///   - pollingInterval: Polling interval in seconds.
    public init(
        serverURI: String,
        pathways: [String],
        defaultPathway: String,
        pollingInterval: TimeInterval = 10
    ) {
        self.serverURI = serverURI
        self.pathways = pathways
        self.defaultPathway = defaultPathway
        self.pollingInterval = pollingInterval
    }

    // MARK: - Tag Generation

    /// Generate the EXT-X-CONTENT-STEERING tag.
    ///
    /// - Returns: The formatted EXT-X-CONTENT-STEERING tag string.
    public func steeringTag() -> String {
        "#EXT-X-CONTENT-STEERING:SERVER-URI=\"\(serverURI)\",PATHWAY-ID=\"\(defaultPathway)\""
    }

    /// Generate a steering manifest JSON response.
    ///
    /// - Parameters:
    ///   - pathwayPriority: Custom pathway priority order. Defaults to `pathways`.
    ///   - ttl: Custom TTL in seconds. Defaults to `pollingInterval`.
    /// - Returns: The JSON manifest string.
    public func steeringManifest(
        pathwayPriority: [String]? = nil,
        ttl: Int? = nil
    ) -> String {
        let priority = pathwayPriority ?? pathways
        let effectiveTTL = ttl ?? Int(pollingInterval)
        let priorityJSON = priority.map { "\"\($0)\"" }.joined(separator: ",")
        return "{\"VERSION\":1,\"TTL\":\(effectiveTTL),\"PATHWAY-PRIORITY\":[\(priorityJSON)]}"
    }

    // MARK: - Validation

    /// Validate the configuration.
    ///
    /// - Returns: An array of validation error messages. Empty if valid.
    public func validate() -> [String] {
        var errors: [String] = []

        if serverURI.isEmpty {
            errors.append("Server URI is empty")
        }

        if pathways.isEmpty {
            errors.append("No pathways configured")
        }

        if !pathways.contains(defaultPathway) {
            errors.append(
                "Default pathway '\(defaultPathway)' not found in pathways list"
            )
        }

        if pollingInterval <= 0 {
            errors.append("Polling interval must be positive")
        }

        return errors
    }
}
