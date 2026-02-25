// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Models Apple HLS Interstitials for content insertion in live streams.
///
/// HLS Interstitials (rfc8216bis-20 Appendix D) use EXT-X-DATERANGE tags
/// with special X-* attributes to signal content that should be played
/// instead of the primary content (ads, bumpers, promos).
///
/// Supports:
/// - X-ASSET-URI: single interstitial asset
/// - X-ASSET-LIST: JSON list of assets (for ad pods)
/// - Resume offset and restrictions
/// - WWDC 2025: skip button control (X-SKIP-AFTER, X-SKIP-BUTTON-START)
/// - WWDC 2025: preload schema (com.apple.hls.preload)
///
/// ```swift
/// let ad = HLSInterstitial(
///     id: "ad-break-1",
///     startDate: Date(),
///     assetURI: "https://ads.example.com/ad1.m3u8",
///     duration: 30.0,
///     restrictions: [.jump, .seek]
/// )
/// let dateRange = ad.toManagedDateRange()
/// // → EXT-X-DATERANGE with all interstitial attributes
/// ```
public struct HLSInterstitial: Sendable, Equatable, Identifiable {

    // MARK: - Types

    /// Playback restrictions during interstitial.
    public enum Restriction: String, Sendable, Equatable, CaseIterable {
        /// Prevent jumping past the interstitial.
        case jump = "JUMP"
        /// Prevent seeking within the interstitial.
        case seek = "SEEK"
    }

    /// Navigation control for the interstitial timeline.
    public enum NavigationRestriction: String, Sendable, Equatable {
        /// Client should snap to start of interstitial when joining mid-break.
        case snapToStart = "X-SNAP"
    }

    /// Resume behavior after interstitial ends.
    public enum ResumeMode: Sendable, Equatable {
        /// Resume at the live edge (default for live).
        case liveEdge
        /// Resume at a specific offset from where the interstitial started.
        case offset(TimeInterval)
        /// Resume at a specific date.
        case date(Date)
    }

    /// Asset reference for the interstitial content.
    public enum Asset: Sendable, Equatable {
        /// Single asset URI.
        case uri(String)
        /// Asset list URL (JSON with multiple assets for ad pods).
        case list(String)
    }

    /// Skip button configuration (WWDC 2025).
    public struct SkipControl: Sendable, Equatable {

        /// Seconds after which the user CAN skip (X-SKIP-AFTER).
        public var skipAfter: TimeInterval?

        /// Seconds after interstitial start when skip button appears.
        public var buttonStart: TimeInterval?

        /// Create a skip control configuration.
        ///
        /// - Parameters:
        ///   - skipAfter: Seconds after which the user can skip.
        ///   - buttonStart: Seconds when skip button appears.
        public init(
            skipAfter: TimeInterval,
            buttonStart: TimeInterval? = nil
        ) {
            self.skipAfter = skipAfter
            self.buttonStart = buttonStart
        }
    }

    /// Preload configuration (WWDC 2025).
    public struct PreloadConfig: Sendable, Equatable {

        /// The preload URI for the interstitial asset.
        public var preloadURI: String?

        /// How far in advance to start preloading (seconds before START-DATE).
        public var preloadAhead: TimeInterval?

        /// Creates a preload configuration.
        ///
        /// - Parameters:
        ///   - preloadURI: The preload URI.
        ///   - preloadAhead: Preload lead time in seconds.
        public init(
            preloadURI: String? = nil,
            preloadAhead: TimeInterval? = nil
        ) {
            self.preloadURI = preloadURI
            self.preloadAhead = preloadAhead
        }
    }

    // MARK: - Properties

    /// Unique identifier for this interstitial.
    public var id: String

    /// When the interstitial starts.
    public var startDate: Date

    /// Optional end date.
    public var endDate: Date?

    /// The interstitial asset(s).
    public var asset: Asset

    /// Expected duration of the interstitial.
    public var duration: TimeInterval?

    /// Planned duration (for client-side countdown).
    public var plannedDuration: TimeInterval?

    /// CLASS attribute (e.g., "com.example.ad").
    public var interstitialClass: String?

    /// Playback restrictions.
    public var restrictions: Set<Restriction>

    /// Resume behavior after interstitial.
    public var resumeMode: ResumeMode

    /// Resume offset (X-RESUME-OFFSET).
    public var resumeOffset: TimeInterval?

    /// Whether this interstitial is a "cue" (signals without content).
    public var isCue: Bool

    /// SCTE-35 marker associated with this interstitial.
    public var scte35: SCTE35Marker?

    /// Skip button control (WWDC 2025).
    public var skipControl: SkipControl?

    /// Preload configuration (WWDC 2025).
    public var preload: PreloadConfig?

    /// Additional custom X-* attributes.
    public var customAttributes: [String: String]

    // MARK: - Initialization

    /// Create an interstitial with a single asset URI.
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - startDate: When the interstitial starts.
    ///   - assetURI: URI of the interstitial asset.
    ///   - duration: Expected duration in seconds.
    ///   - restrictions: Playback restrictions.
    ///   - resumeMode: Resume behavior after interstitial.
    public init(
        id: String,
        startDate: Date,
        assetURI: String,
        duration: TimeInterval? = nil,
        restrictions: Set<Restriction> = [],
        resumeMode: ResumeMode = .liveEdge
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = nil
        self.asset = .uri(assetURI)
        self.duration = duration
        self.plannedDuration = nil
        self.interstitialClass = nil
        self.restrictions = restrictions
        self.resumeMode = resumeMode
        self.resumeOffset = nil
        self.isCue = false
        self.scte35 = nil
        self.skipControl = nil
        self.preload = nil
        self.customAttributes = [:]
        applyResumeMode()
    }

    /// Create an interstitial with an asset list (ad pod).
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - startDate: When the interstitial starts.
    ///   - assetListURI: URI of the JSON asset list.
    ///   - duration: Expected duration in seconds.
    ///   - restrictions: Playback restrictions.
    ///   - resumeMode: Resume behavior after interstitial.
    public init(
        id: String,
        startDate: Date,
        assetListURI: String,
        duration: TimeInterval? = nil,
        restrictions: Set<Restriction> = [],
        resumeMode: ResumeMode = .liveEdge
    ) {
        self.id = id
        self.startDate = startDate
        self.endDate = nil
        self.asset = .list(assetListURI)
        self.duration = duration
        self.plannedDuration = nil
        self.interstitialClass = nil
        self.restrictions = restrictions
        self.resumeMode = resumeMode
        self.resumeOffset = nil
        self.isCue = false
        self.scte35 = nil
        self.skipControl = nil
        self.preload = nil
        self.customAttributes = [:]
        applyResumeMode()
    }

    private mutating func applyResumeMode() {
        if case .offset(let offset) = resumeMode {
            resumeOffset = offset
        }
    }
}

// MARK: - DateRange Conversion

extension HLSInterstitial {

    /// Convert to a ManagedDateRange for use with DateRangeManager.
    public func toManagedDateRange() -> DateRangeManager.ManagedDateRange {
        var attrs = buildCustomAttributes()
        applySkipAttributes(to: &attrs)
        applyPreloadAttributes(to: &attrs)
        let scteData = buildSCTEData()
        return DateRangeManager.ManagedDateRange(
            id: id,
            startDate: startDate,
            endDate: endDate,
            duration: duration,
            plannedDuration: plannedDuration,
            classAttribute: interstitialClass,
            endOnNext: false,
            customAttributes: attrs,
            scte35Cmd: nil,
            scte35Out: scteData.out,
            scte35In: scteData.in,
            state: .open
        )
    }

    /// Render as EXT-X-DATERANGE M3U8 line directly.
    public func renderTag() -> String {
        let writer = TagWriter()
        return writer.writeDateRange(toManagedDateRange().toDateRange())
    }

    private func buildCustomAttributes() -> [String: String] {
        var attrs = customAttributes
        switch asset {
        case .uri(let uri):
            attrs["X-ASSET-URI"] = uri
        case .list(let uri):
            attrs["X-ASSET-LIST"] = uri
        }
        if !restrictions.isEmpty {
            attrs["X-RESTRICT"] =
                restrictions
                .sorted { $0.rawValue < $1.rawValue }
                .map(\.rawValue)
                .joined(separator: ",")
        }
        if let offset = resumeOffset {
            attrs["X-RESUME-OFFSET"] = String(offset)
        }
        return attrs
    }

    private func applySkipAttributes(to attrs: inout [String: String]) {
        guard let skip = skipControl else { return }
        if let skipAfter = skip.skipAfter {
            attrs["X-SKIP-AFTER"] = String(skipAfter)
        }
        if let buttonStart = skip.buttonStart {
            attrs["X-SKIP-BUTTON-START"] = String(buttonStart)
        }
    }

    private func applyPreloadAttributes(to attrs: inout [String: String]) {
        guard let preloadConfig = preload else { return }
        if let preloadURI = preloadConfig.preloadURI {
            attrs["X-com.apple.hls.preload"] = preloadURI
        }
        if let ahead = preloadConfig.preloadAhead {
            attrs["X-PRELOAD-AHEAD"] = String(ahead)
        }
    }

    private func buildSCTEData() -> (out: Data?, `in`: Data?) {
        guard let marker = scte35 else { return (nil, nil) }
        if marker.outOfNetwork {
            return (marker.serialize(), nil)
        }
        return (nil, marker.serialize())
    }
}

// MARK: - Parsing

extension HLSInterstitial {

    /// Parse an HLSInterstitial from a ManagedDateRange.
    ///
    /// Returns nil if the date range is not an interstitial
    /// (must have X-ASSET-URI or X-ASSET-LIST).
    public static func fromDateRange(
        _ dateRange: DateRangeManager.ManagedDateRange
    ) -> HLSInterstitial? {
        let attrs = dateRange.customAttributes
        guard let asset = parseAsset(from: attrs) else { return nil }
        let restrictions = parseRestrictions(from: attrs)
        let resume = parseResume(from: attrs)
        let skipControl = parseSkipControl(from: attrs)
        let preloadConfig = parsePreload(from: attrs)
        let remainingAttrs = filterInterstitialKeys(from: attrs)
        var interstitial = buildInterstitial(
            from: dateRange, asset: asset,
            restrictions: restrictions, resumeMode: resume.mode
        )
        interstitial.endDate = dateRange.endDate
        interstitial.plannedDuration = dateRange.plannedDuration
        interstitial.interstitialClass = dateRange.classAttribute
        interstitial.resumeOffset = resume.offset
        interstitial.skipControl = skipControl
        interstitial.preload = preloadConfig
        interstitial.customAttributes = remainingAttrs
        return interstitial
    }

    private static func parseAsset(
        from attrs: [String: String]
    ) -> Asset? {
        if let uri = attrs["X-ASSET-URI"] { return .uri(uri) }
        if let list = attrs["X-ASSET-LIST"] { return .list(list) }
        return nil
    }

    private static func parseRestrictions(
        from attrs: [String: String]
    ) -> Set<Restriction> {
        guard let restrictStr = attrs["X-RESTRICT"] else { return [] }
        var result = Set<Restriction>()
        for part in restrictStr.split(separator: ",") {
            if let r = Restriction(rawValue: String(part)) {
                result.insert(r)
            }
        }
        return result
    }

    private static func parseResume(
        from attrs: [String: String]
    ) -> (mode: ResumeMode, offset: TimeInterval?) {
        if let offsetStr = attrs["X-RESUME-OFFSET"],
            let offset = TimeInterval(offsetStr)
        {
            return (.offset(offset), offset)
        }
        return (.liveEdge, nil)
    }

    private static func parseSkipControl(
        from attrs: [String: String]
    ) -> SkipControl? {
        guard let skipAfterStr = attrs["X-SKIP-AFTER"],
            let skipAfter = TimeInterval(skipAfterStr)
        else { return nil }
        let buttonStart = attrs["X-SKIP-BUTTON-START"]
            .flatMap(TimeInterval.init)
        return SkipControl(skipAfter: skipAfter, buttonStart: buttonStart)
    }

    private static func parsePreload(
        from attrs: [String: String]
    ) -> PreloadConfig? {
        guard let preloadURI = attrs["X-com.apple.hls.preload"] else {
            return nil
        }
        let ahead = attrs["X-PRELOAD-AHEAD"].flatMap(TimeInterval.init)
        return PreloadConfig(preloadURI: preloadURI, preloadAhead: ahead)
    }

    private static let interstitialKeys: Set<String> = [
        "X-ASSET-URI", "X-ASSET-LIST", "X-RESTRICT",
        "X-RESUME-OFFSET", "X-SKIP-AFTER", "X-SKIP-BUTTON-START",
        "X-com.apple.hls.preload", "X-PRELOAD-AHEAD"
    ]

    private static func filterInterstitialKeys(
        from attrs: [String: String]
    ) -> [String: String] {
        attrs.filter { !interstitialKeys.contains($0.key) }
    }

    private static func buildInterstitial(
        from dateRange: DateRangeManager.ManagedDateRange,
        asset: Asset,
        restrictions: Set<Restriction>,
        resumeMode: ResumeMode
    ) -> HLSInterstitial {
        switch asset {
        case .uri(let uri):
            return HLSInterstitial(
                id: dateRange.id,
                startDate: dateRange.startDate,
                assetURI: uri,
                duration: dateRange.duration,
                restrictions: restrictions,
                resumeMode: resumeMode
            )
        case .list(let uri):
            return HLSInterstitial(
                id: dateRange.id,
                startDate: dateRange.startDate,
                assetListURI: uri,
                duration: dateRange.duration,
                restrictions: restrictions,
                resumeMode: resumeMode
            )
        }
    }
}
