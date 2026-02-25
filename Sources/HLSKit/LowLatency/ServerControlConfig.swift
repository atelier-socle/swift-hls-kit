// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Configuration for the `EXT-X-SERVER-CONTROL` tag (RFC 8216bis §4.4.3.8).
///
/// Controls server-side behaviors for Low-Latency HLS, including
/// blocking playlist reload, hold-back distances, and delta update
/// support.
///
/// ## Presets
/// - ``standard(targetDuration:partTargetDuration:)`` — blocking
///   enabled, default hold-backs, no delta updates.
/// - ``withDeltaUpdates(targetDuration:partTargetDuration:)`` — blocking
///   enabled, default hold-backs, delta updates at 6× target duration.
///
/// ## Hold-back rules (RFC 8216bis)
/// - `HOLD-BACK` ≥ 3× `EXT-X-TARGETDURATION`
/// - `PART-HOLD-BACK` ≥ 2× `PART-TARGET` (recommended 3×)
public struct ServerControlConfig: Sendable, Equatable {

    /// Whether the server supports blocking playlist reload requests.
    ///
    /// When `true`, the client can use `_HLS_msn` and `_HLS_part`
    /// query parameters. Required for LL-HLS.
    public var canBlockReload: Bool

    /// Hold-back distance in seconds for standard playlists.
    ///
    /// The client must not request a segment closer than this to the
    /// live edge. Spec requires ≥ 3× `EXT-X-TARGETDURATION`.
    /// If `nil`, defaults to 3× target duration at render time.
    public var holdBack: TimeInterval?

    /// Hold-back distance in seconds for partial segments (LL-HLS).
    ///
    /// The client must not request a partial closer than this to the
    /// live edge. Spec requires ≥ 2× `PART-TARGET` (recommended 3×).
    /// If `nil`, defaults to 3× part target duration at render time.
    public var partHoldBack: TimeInterval?

    /// Maximum duration of playlist skipping (delta updates) in seconds.
    ///
    /// When set, the server supports the `_HLS_skip=YES` query
    /// parameter. Spec recommends 6× `EXT-X-TARGETDURATION`.
    /// If `nil`, delta updates are not supported.
    public var canSkipUntil: TimeInterval?

    /// Whether the server supports skipping `EXT-X-DATERANGE` tags
    /// in delta updates.
    ///
    /// Only meaningful when ``canSkipUntil`` is set. When `true`,
    /// the client can send `_HLS_skip=v2` to also skip date ranges.
    public var canSkipDateRanges: Bool

    /// Creates a server control configuration.
    ///
    /// - Parameters:
    ///   - canBlockReload: Support blocking reload. Default `true`.
    ///   - holdBack: Explicit hold-back in seconds. Default `nil`.
    ///   - partHoldBack: Explicit part hold-back in seconds.
    ///     Default `nil`.
    ///   - canSkipUntil: Delta update skip window in seconds.
    ///     Default `nil`.
    ///   - canSkipDateRanges: Support date-range skipping.
    ///     Default `false`.
    public init(
        canBlockReload: Bool = true,
        holdBack: TimeInterval? = nil,
        partHoldBack: TimeInterval? = nil,
        canSkipUntil: TimeInterval? = nil,
        canSkipDateRanges: Bool = false
    ) {
        self.canBlockReload = canBlockReload
        self.holdBack = holdBack
        self.partHoldBack = partHoldBack
        self.canSkipUntil = canSkipUntil
        self.canSkipDateRanges = canSkipDateRanges
    }

    // MARK: - Computed Hold-backs

    /// Compute effective hold-back distance.
    ///
    /// Returns the explicit ``holdBack`` if set, otherwise falls back
    /// to 3× the provided target duration (per spec requirement).
    ///
    /// - Parameter targetDuration: The `EXT-X-TARGETDURATION` value.
    /// - Returns: The effective hold-back in seconds.
    public func effectiveHoldBack(
        targetDuration: TimeInterval
    ) -> TimeInterval {
        holdBack ?? (3.0 * targetDuration)
    }

    /// Compute effective part hold-back distance.
    ///
    /// Returns the explicit ``partHoldBack`` if set, otherwise falls
    /// back to 3× the provided part target duration (recommended).
    ///
    /// - Parameter partTargetDuration: The `PART-TARGET` value.
    /// - Returns: The effective part hold-back in seconds.
    public func effectivePartHoldBack(
        partTargetDuration: TimeInterval
    ) -> TimeInterval {
        partHoldBack ?? (3.0 * partTargetDuration)
    }

    // MARK: - Skip Recommendation

    /// Compute recommended `CAN-SKIP-UNTIL` based on target duration.
    ///
    /// Per RFC 8216bis, the recommended value is 6× target duration.
    ///
    /// - Parameter targetDuration: The `EXT-X-TARGETDURATION` value.
    /// - Returns: Recommended skip-until in seconds (6× target).
    public static func recommendedSkipUntil(
        targetDuration: TimeInterval
    ) -> TimeInterval {
        6.0 * targetDuration
    }

    // MARK: - Presets

    /// Standard LL-HLS server control.
    ///
    /// Blocking enabled, default hold-backs (3× target durations),
    /// no delta updates.
    ///
    /// - Parameters:
    ///   - targetDuration: The `EXT-X-TARGETDURATION` value.
    ///   - partTargetDuration: The `PART-TARGET` value.
    /// - Returns: A standard server control configuration.
    public static func standard(
        targetDuration: TimeInterval,
        partTargetDuration: TimeInterval
    ) -> ServerControlConfig {
        ServerControlConfig(
            canBlockReload: true,
            holdBack: 3.0 * targetDuration,
            partHoldBack: 3.0 * partTargetDuration
        )
    }

    /// Full LL-HLS server control with delta updates.
    ///
    /// Blocking enabled, default hold-backs, delta updates enabled
    /// at 6× target duration.
    ///
    /// - Parameters:
    ///   - targetDuration: The `EXT-X-TARGETDURATION` value.
    ///   - partTargetDuration: The `PART-TARGET` value.
    /// - Returns: A server control configuration with delta updates.
    public static func withDeltaUpdates(
        targetDuration: TimeInterval,
        partTargetDuration: TimeInterval
    ) -> ServerControlConfig {
        ServerControlConfig(
            canBlockReload: true,
            holdBack: 3.0 * targetDuration,
            partHoldBack: 3.0 * partTargetDuration,
            canSkipUntil: recommendedSkipUntil(
                targetDuration: targetDuration
            )
        )
    }
}
