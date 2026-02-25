// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Renders the `EXT-X-SERVER-CONTROL` tag for LL-HLS playlists.
///
/// Produces a tag line with attributes in the order specified by
/// RFC 8216bis:
/// 1. `CAN-BLOCK-RELOAD` (only if `true`)
/// 2. `HOLD-BACK`
/// 3. `PART-HOLD-BACK`
/// 4. `CAN-SKIP-UNTIL` (only if set)
/// 5. `CAN-SKIP-DATERANGES` (only if `true` and skip is enabled)
///
/// ## Example
/// ```
/// #EXT-X-SERVER-CONTROL:CAN-BLOCK-RELOAD=YES,HOLD-BACK=6.0,PART-HOLD-BACK=1.0
/// ```
public struct ServerControlRenderer: Sendable {

    /// Render the complete `EXT-X-SERVER-CONTROL` line.
    ///
    /// - Parameters:
    ///   - config: The server control configuration.
    ///   - targetDuration: The `EXT-X-TARGETDURATION` value, used
    ///     to compute default hold-backs.
    ///   - partTargetDuration: The `PART-TARGET` value, used to
    ///     compute default part hold-backs.
    /// - Returns: A formatted `EXT-X-SERVER-CONTROL` line.
    public static func render(
        config: ServerControlConfig,
        targetDuration: TimeInterval,
        partTargetDuration: TimeInterval
    ) -> String {
        var attrs = [String]()

        if config.canBlockReload {
            attrs.append("CAN-BLOCK-RELOAD=YES")
        }

        let holdBack = config.effectiveHoldBack(
            targetDuration: targetDuration
        )
        attrs.append(
            "HOLD-BACK=\(formatDecimal(holdBack))"
        )

        let partHoldBack = config.effectivePartHoldBack(
            partTargetDuration: partTargetDuration
        )
        attrs.append(
            "PART-HOLD-BACK=\(formatDecimal(partHoldBack))"
        )

        if let skipUntil = config.canSkipUntil {
            attrs.append(
                "CAN-SKIP-UNTIL=\(formatDecimal(skipUntil))"
            )

            if config.canSkipDateRanges {
                attrs.append("CAN-SKIP-DATERANGES=YES")
            }
        }

        return "#EXT-X-SERVER-CONTROL:\(attrs.joined(separator: ","))"
    }

    // MARK: - Private

    private static func formatDecimal(
        _ value: TimeInterval
    ) -> String {
        let formatted = String(format: "%.5f", value)
        var result = formatted
        while result.hasSuffix("0"), !result.hasSuffix(".0") {
            result = String(result.dropLast())
        }
        return result
    }
}
