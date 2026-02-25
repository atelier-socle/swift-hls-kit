// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Manages interstitial content insertion in a live stream.
///
/// Built on top of ``DateRangeManager``, provides a higher-level API
/// specifically for scheduling and managing interstitials.
///
/// ```swift
/// let manager = InterstitialManager()
///
/// // Schedule a pre-roll ad
/// await manager.scheduleAd(
///     id: "preroll",
///     at: streamStart,
///     assetURI: "https://ads.example.com/preroll.m3u8",
///     duration: 15.0,
///     restrictions: [.jump, .seek]
/// )
///
/// // Schedule a mid-roll with SCTE-35
/// let scte = SCTE35Marker.spliceInsert(eventId: 42, duration: 30.0)
/// await manager.scheduleFromSCTE35(scte, at: Date(), id: "midroll-42")
/// ```
public actor InterstitialManager {

    // MARK: - Properties

    /// Underlying date range manager.
    public let dateRangeManager: DateRangeManager

    /// All scheduled interstitials (by insertion order).
    private var storage: [String: HLSInterstitial] = [:]

    /// Insertion order tracking.
    private var insertionOrder: [String] = []

    /// IDs of completed interstitials.
    private var completedIds: Set<String> = []

    /// Creates an interstitial manager.
    ///
    /// - Parameter dateRangeManager: Underlying date range manager.
    public init(dateRangeManager: DateRangeManager = DateRangeManager()) {
        self.dateRangeManager = dateRangeManager
    }

    // MARK: - Query

    /// All scheduled interstitials.
    public var interstitials: [HLSInterstitial] {
        insertionOrder.compactMap { storage[$0] }
    }

    /// Active (scheduled, not completed) interstitials.
    public var activeInterstitials: [HLSInterstitial] {
        insertionOrder.compactMap { id in
            guard !completedIds.contains(id) else { return nil }
            return storage[id]
        }
    }

    /// Completed interstitials.
    public var completedInterstitials: [HLSInterstitial] {
        insertionOrder.compactMap { id in
            guard completedIds.contains(id) else { return nil }
            return storage[id]
        }
    }

    /// Get interstitial by ID.
    ///
    /// - Parameter id: The interstitial identifier.
    /// - Returns: The interstitial, or nil if not found.
    public func interstitial(id: String) -> HLSInterstitial? {
        storage[id]
    }

    /// Interstitials scheduled at or after a given date.
    ///
    /// - Parameter date: The cutoff date.
    /// - Returns: Interstitials starting at or after the date.
    public func upcoming(after date: Date) -> [HLSInterstitial] {
        insertionOrder.compactMap { id in
            guard let item = storage[id],
                !completedIds.contains(id),
                item.startDate >= date
            else { return nil }
            return item
        }
    }

    // MARK: - Scheduling

    /// Schedule an interstitial ad.
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - startDate: When the ad starts.
    ///   - assetURI: URI of the ad asset.
    ///   - duration: Expected duration in seconds.
    ///   - restrictions: Playback restrictions.
    ///   - skipControl: Optional skip button control.
    ///   - preload: Optional preload configuration.
    public func scheduleAd(
        id: String,
        at startDate: Date,
        assetURI: String,
        duration: TimeInterval? = nil,
        restrictions: Set<HLSInterstitial.Restriction> = [.jump, .seek],
        skipControl: HLSInterstitial.SkipControl? = nil,
        preload: HLSInterstitial.PreloadConfig? = nil
    ) async {
        var ad = HLSInterstitial(
            id: id,
            startDate: startDate,
            assetURI: assetURI,
            duration: duration,
            restrictions: restrictions
        )
        ad.skipControl = skipControl
        ad.preload = preload
        store(ad)
        let managed = ad.toManagedDateRange()
        await dateRangeManager.open(
            id: managed.id,
            startDate: managed.startDate,
            class: managed.classAttribute,
            plannedDuration: managed.plannedDuration,
            customAttributes: managed.customAttributes
        )
    }

    /// Schedule an interstitial from a SCTE-35 marker.
    ///
    /// - Parameters:
    ///   - marker: The SCTE-35 marker.
    ///   - startDate: When the interstitial starts.
    ///   - id: Unique identifier.
    ///   - assetURI: Optional single asset URI.
    ///   - assetListURI: Optional asset list URI.
    public func scheduleFromSCTE35(
        _ marker: SCTE35Marker,
        at startDate: Date,
        id: String,
        assetURI: String? = nil,
        assetListURI: String? = nil
    ) async {
        let effectiveURI = assetURI ?? ""
        var interstitial: HLSInterstitial
        if let listURI = assetListURI {
            interstitial = HLSInterstitial(
                id: id,
                startDate: startDate,
                assetListURI: listURI,
                duration: marker.breakDuration?.seconds,
                restrictions: [.jump, .seek]
            )
        } else {
            interstitial = HLSInterstitial(
                id: id,
                startDate: startDate,
                assetURI: effectiveURI,
                duration: marker.breakDuration?.seconds,
                restrictions: [.jump, .seek]
            )
        }
        interstitial.scte35 = marker
        store(interstitial)
        let managed = interstitial.toManagedDateRange()
        await dateRangeManager.open(
            id: managed.id,
            startDate: managed.startDate,
            class: managed.classAttribute,
            plannedDuration: managed.plannedDuration,
            customAttributes: managed.customAttributes
        )
    }

    /// Schedule a bumper (short, non-skippable interstitial).
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - startDate: When the bumper starts.
    ///   - assetURI: URI of the bumper asset.
    ///   - duration: Duration in seconds.
    public func scheduleBumper(
        id: String,
        at startDate: Date,
        assetURI: String,
        duration: TimeInterval
    ) async {
        let bumper = HLSInterstitial(
            id: id,
            startDate: startDate,
            assetURI: assetURI,
            duration: duration,
            restrictions: [.jump, .seek]
        )
        store(bumper)
        let managed = bumper.toManagedDateRange()
        await dateRangeManager.open(
            id: managed.id,
            startDate: managed.startDate,
            class: managed.classAttribute,
            plannedDuration: managed.plannedDuration,
            customAttributes: managed.customAttributes
        )
    }

    /// Complete an interstitial (mark as ended).
    ///
    /// - Parameter id: The interstitial identifier.
    public func complete(id: String) async {
        completedIds.insert(id)
        await dateRangeManager.close(id: id, endDate: Date())
    }

    /// Cancel a scheduled interstitial before it starts.
    ///
    /// - Parameter id: The interstitial identifier.
    public func cancel(id: String) async {
        storage.removeValue(forKey: id)
        insertionOrder.removeAll { $0 == id }
        completedIds.remove(id)
        await dateRangeManager.remove(id: id)
    }

    // MARK: - Rendering

    /// Render all active interstitial DATERANGE tags.
    ///
    /// - Returns: Concatenated M3U8 EXT-X-DATERANGE lines.
    public func renderInterstitials() -> String {
        let active = activeInterstitials
        guard !active.isEmpty else { return "" }
        let writer = TagWriter()
        return active.map { item in
            writer.writeDateRange(item.toManagedDateRange().toDateRange())
        }.joined(separator: "\n")
    }

    // MARK: - Reset

    /// Remove all interstitials.
    public func reset() async {
        storage.removeAll()
        insertionOrder.removeAll()
        completedIds.removeAll()
        await dateRangeManager.reset()
    }

    // MARK: - Private

    private func store(_ interstitial: HLSInterstitial) {
        storage[interstitial.id] = interstitial
        if !insertionOrder.contains(interstitial.id) {
            insertionOrder.append(interstitial.id)
        }
    }
}
