// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Manages the lifecycle of EXT-X-DATERANGE tags in a live playlist.
///
/// Handles creation, update, and expiration of date ranges.
/// Integrates with ``TagWriter`` for rendering active ranges as M3U8 lines.
///
/// ```swift
/// let manager = DateRangeManager()
///
/// // Start an ad break
/// await manager.open(id: "ad-break-1", startDate: Date(), attributes: [
///     .class: "com.example.ad",
///     .plannedDuration: "30.0"
/// ])
///
/// // End the ad break
/// await manager.close(id: "ad-break-1", endDate: Date())
///
/// // Get active ranges for playlist rendering
/// let ranges = await manager.activeRanges
/// ```
public actor DateRangeManager {

    // MARK: - Types

    /// Standard EXT-X-DATERANGE attribute keys.
    public enum AttributeKey: String, Sendable, Equatable, CaseIterable {
        /// CLASS attribute.
        case `class` = "CLASS"
        /// START-DATE attribute.
        case startDate = "START-DATE"
        /// END-DATE attribute.
        case endDate = "END-DATE"
        /// DURATION attribute.
        case duration = "DURATION"
        /// PLANNED-DURATION attribute.
        case plannedDuration = "PLANNED-DURATION"
        /// END-ON-NEXT attribute.
        case endOnNext = "END-ON-NEXT"
        /// SCTE35-CMD attribute.
        case scte35Cmd = "SCTE35-CMD"
        /// SCTE35-OUT attribute.
        case scte35Out = "SCTE35-OUT"
        /// SCTE35-IN attribute.
        case scte35In = "SCTE35-IN"
    }

    /// A managed date range with lifecycle state.
    public struct ManagedDateRange: Sendable, Equatable, Identifiable {

        /// Unique identifier for this date range.
        public let id: String

        /// Start date of the range.
        public var startDate: Date

        /// End date of the range (nil if open).
        public var endDate: Date?

        /// Explicit duration in seconds.
        public var duration: TimeInterval?

        /// Planned duration in seconds.
        public var plannedDuration: TimeInterval?

        /// CLASS attribute value.
        public var classAttribute: String?

        /// Whether this range ends on the next range with the same class.
        public var endOnNext: Bool

        /// Custom X-* attributes.
        public var customAttributes: [String: String]

        /// SCTE35-CMD binary data.
        public var scte35Cmd: Data?

        /// SCTE35-OUT binary data.
        public var scte35Out: Data?

        /// SCTE35-IN binary data.
        public var scte35In: Data?

        /// Current lifecycle state.
        public var state: State

        /// Lifecycle states for a managed date range.
        public enum State: Sendable, Equatable {
            /// Active, no end date yet.
            case open
            /// Has end date or duration.
            case closed
            /// Evicted from sliding window.
            case expired
        }
    }

    // MARK: - Storage

    private var ranges: [String: ManagedDateRange] = [:]
    private var insertionOrder: [String] = []

    /// Creates an empty date range manager.
    public init() {}

    // MARK: - Lifecycle

    /// Open a new date range.
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - startDate: Start date of the range.
    ///   - class: Optional CLASS attribute.
    ///   - plannedDuration: Optional planned duration in seconds.
    ///   - customAttributes: Optional X-* custom attributes.
    public func open(
        id: String,
        startDate: Date,
        class classAttribute: String? = nil,
        plannedDuration: TimeInterval? = nil,
        customAttributes: [String: String] = [:]
    ) {
        let range = ManagedDateRange(
            id: id,
            startDate: startDate,
            endDate: nil,
            duration: nil,
            plannedDuration: plannedDuration,
            classAttribute: classAttribute,
            endOnNext: false,
            customAttributes: customAttributes,
            scte35Cmd: nil,
            scte35Out: nil,
            scte35In: nil,
            state: .open
        )
        ranges[id] = range
        if !insertionOrder.contains(id) {
            insertionOrder.append(id)
        }
    }

    /// Update an existing date range with new attributes.
    ///
    /// - Parameters:
    ///   - id: Identifier of the range to update.
    ///   - customAttributes: New custom attributes to merge.
    public func update(
        id: String,
        customAttributes: [String: String]
    ) {
        guard var range = ranges[id] else { return }
        for (key, value) in customAttributes {
            range.customAttributes[key] = value
        }
        ranges[id] = range
    }

    /// Close a date range with an end date or explicit duration.
    ///
    /// - Parameters:
    ///   - id: Identifier of the range to close.
    ///   - endDate: Optional end date.
    ///   - duration: Optional explicit duration.
    public func close(
        id: String,
        endDate: Date? = nil,
        duration: TimeInterval? = nil
    ) {
        guard var range = ranges[id] else { return }
        range.endDate = endDate
        range.duration = duration
        range.state = .closed
        ranges[id] = range
    }

    /// Mark a date range as expired.
    ///
    /// - Parameter id: Identifier of the range to expire.
    public func expire(id: String) {
        guard var range = ranges[id] else { return }
        range.state = .expired
        ranges[id] = range
    }

    /// Remove a date range entirely.
    ///
    /// - Parameter id: Identifier of the range to remove.
    public func remove(id: String) {
        ranges.removeValue(forKey: id)
        insertionOrder.removeAll { $0 == id }
    }

    // MARK: - Query

    /// All active (open or closed, not expired) date ranges.
    public var activeRanges: [ManagedDateRange] {
        insertionOrder.compactMap { id in
            guard let range = ranges[id], range.state != .expired else {
                return nil
            }
            return range
        }
    }

    /// Get a specific date range by identifier.
    ///
    /// - Parameter id: The range identifier.
    /// - Returns: The managed date range, or nil if not found.
    public func range(id: String) -> ManagedDateRange? {
        ranges[id]
    }

    /// All date ranges including expired.
    public var allRanges: [ManagedDateRange] {
        insertionOrder.compactMap { ranges[$0] }
    }

    /// Number of active (non-expired) date ranges.
    public var activeCount: Int {
        ranges.values.filter { $0.state != .expired }.count
    }

    // MARK: - Rendering

    /// Render all active date ranges as EXT-X-DATERANGE M3U8 lines.
    ///
    /// - Returns: Concatenated M3U8 tag lines.
    public func renderDateRanges() -> String {
        let writer = TagWriter()
        let active = activeRanges
        guard !active.isEmpty else { return "" }
        return active.map { managed in
            writer.writeDateRange(managed.toDateRange())
        }.joined(separator: "\n")
    }

    // MARK: - Eviction

    /// Expire date ranges that ended before the given date.
    ///
    /// Call this when the sliding window advances.
    ///
    /// - Parameter date: The cutoff date.
    public func evictBefore(date: Date) {
        for (id, range) in ranges where range.state == .closed {
            let effectiveEnd: Date?
            if let endDate = range.endDate {
                effectiveEnd = endDate
            } else if let duration = range.duration {
                effectiveEnd = range.startDate.addingTimeInterval(duration)
            } else {
                effectiveEnd = nil
            }
            if let end = effectiveEnd, end < date {
                var updated = range
                updated.state = .expired
                ranges[id] = updated
            }
        }
    }

    /// Remove all expired ranges.
    public func purgeExpired() {
        let expiredIds = ranges.filter { $0.value.state == .expired }.map(\.key)
        for id in expiredIds {
            ranges.removeValue(forKey: id)
            insertionOrder.removeAll { $0 == id }
        }
    }

    /// Reset all state.
    public func reset() {
        ranges.removeAll()
        insertionOrder.removeAll()
    }
}

// MARK: - Conversion

extension DateRangeManager.ManagedDateRange {

    /// Convert to the parser's ``DateRange`` model for rendering.
    func toDateRange() -> DateRange {
        DateRange(
            id: id,
            startDate: startDate,
            classAttribute: classAttribute,
            endDate: endDate,
            duration: duration,
            plannedDuration: plannedDuration,
            endOnNext: endOnNext,
            clientAttributes: customAttributes,
            scte35Cmd: scte35Cmd.map { $0.map { String(format: "0x%02X", $0) }.joined() },
            scte35Out: scte35Out.map { $0.map { String(format: "0x%02X", $0) }.joined() },
            scte35In: scte35In.map { $0.map { String(format: "0x%02X", $0) }.joined() }
        )
    }
}
