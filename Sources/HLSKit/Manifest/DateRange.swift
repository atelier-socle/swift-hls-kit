// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Timed metadata associated with a date range in a media playlist.
///
/// Corresponds to the `EXT-X-DATERANGE` tag (RFC 8216 Section 4.3.2.7).
/// Date ranges provide a way to associate metadata with a portion of
/// the timeline, such as ad insertion points, chapters, or interstitials.
public struct DateRange: Sendable, Hashable, Codable {

    /// A unique identifier for this date range within the playlist.
    public var id: String

    /// An optional class that groups related date ranges.
    public var classAttribute: String?

    /// The start date of the range.
    public var startDate: Date

    /// The end date of the range.
    public var endDate: Date?

    /// The duration of the range in seconds.
    public var duration: Double?

    /// The planned duration of the range in seconds.
    /// Used for ranges that have not yet ended.
    public var plannedDuration: Double?

    /// Whether to disallow inserting content at this point.
    public var endOnNext: Bool

    /// Client-defined attributes prefixed with `X-`.
    /// Keys are the full attribute names (e.g., `"X-COM-EXAMPLE-AD-ID"`).
    public var clientAttributes: [String: String]

    /// An optional SCTE-35 command as a hexadecimal string.
    public var scte35Cmd: String?

    /// An optional SCTE-35 out signal as a hexadecimal string.
    public var scte35Out: String?

    /// An optional SCTE-35 in signal as a hexadecimal string.
    public var scte35In: String?

    /// Creates a date range.
    ///
    /// - Parameters:
    ///   - id: A unique identifier.
    ///   - startDate: The start date.
    ///   - classAttribute: An optional class attribute.
    ///   - endDate: An optional end date.
    ///   - duration: An optional duration in seconds.
    ///   - plannedDuration: An optional planned duration.
    ///   - endOnNext: Whether to end on the next date range.
    ///   - clientAttributes: Client-defined `X-` attributes.
    ///   - scte35Cmd: An optional SCTE-35 command.
    ///   - scte35Out: An optional SCTE-35 out signal.
    ///   - scte35In: An optional SCTE-35 in signal.
    public init(
        id: String,
        startDate: Date,
        classAttribute: String? = nil,
        endDate: Date? = nil,
        duration: Double? = nil,
        plannedDuration: Double? = nil,
        endOnNext: Bool = false,
        clientAttributes: [String: String] = [:],
        scte35Cmd: String? = nil,
        scte35Out: String? = nil,
        scte35In: String? = nil
    ) {
        self.id = id
        self.startDate = startDate
        self.classAttribute = classAttribute
        self.endDate = endDate
        self.duration = duration
        self.plannedDuration = plannedDuration
        self.endOnNext = endOnNext
        self.clientAttributes = clientAttributes
        self.scte35Cmd = scte35Cmd
        self.scte35Out = scte35Out
        self.scte35In = scte35In
    }
}
