// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration for an ``EventPlaylist``.
public struct EventPlaylistConfiguration: Sendable, Equatable {

    /// Expected target segment duration (seconds).
    ///
    /// Default: 6.0.
    public var targetDuration: TimeInterval

    /// HLS version to declare.
    ///
    /// Default: 7.
    public var version: Int

    /// Creates an event playlist configuration.
    ///
    /// - Parameters:
    ///   - targetDuration: Expected target segment duration.
    ///   - version: HLS version to declare.
    public init(
        targetDuration: TimeInterval = 6.0,
        version: Int = 7
    ) {
        self.targetDuration = targetDuration
        self.version = version
    }
}
