// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// An IMSC1 (TTML-based) subtitle document.
///
/// Represents the full content of an IMSC1 Text Profile document
/// including language, regions, styles, and subtitle cues.
///
/// ```swift
/// let document = IMSC1Document(
///     language: "en",
///     subtitles: [
///         IMSC1Subtitle(begin: 0.0, end: 2.5, text: "Hello")
///     ]
/// )
/// ```
public struct IMSC1Document: Sendable, Equatable {

    /// BCP 47 language tag for this document (e.g. "en", "fr").
    public let language: String

    /// Spatial regions for subtitle placement.
    public let regions: [IMSC1Region]

    /// Style definitions referenced by subtitles.
    public let styles: [IMSC1Style]

    /// The subtitle cues in this document.
    public let subtitles: [IMSC1Subtitle]

    /// Creates a new IMSC1 document.
    ///
    /// - Parameters:
    ///   - language: BCP 47 language tag.
    ///   - regions: Spatial regions for placement.
    ///   - styles: Style definitions.
    ///   - subtitles: Subtitle cues.
    public init(
        language: String,
        regions: [IMSC1Region] = [],
        styles: [IMSC1Style] = [],
        subtitles: [IMSC1Subtitle] = []
    ) {
        self.language = language
        self.regions = regions
        self.styles = styles
        self.subtitles = subtitles
    }
}

// MARK: - IMSC1Subtitle

/// A single subtitle cue within an IMSC1 document.
///
/// Represents a `<p>` element inside the TTML `<body>` with
/// timing attributes and optional region/style references.
public struct IMSC1Subtitle: Sendable, Equatable {

    /// Start time in seconds.
    public let begin: Double

    /// End time in seconds.
    public let end: Double

    /// The subtitle text content.
    public let text: String

    /// Optional region identifier for placement.
    public let region: String?

    /// Optional style identifier for formatting.
    public let style: String?

    /// Creates a new subtitle cue.
    ///
    /// - Parameters:
    ///   - begin: Start time in seconds.
    ///   - end: End time in seconds.
    ///   - text: The subtitle text.
    ///   - region: Optional region identifier.
    ///   - style: Optional style identifier.
    public init(
        begin: Double,
        end: Double,
        text: String,
        region: String? = nil,
        style: String? = nil
    ) {
        self.begin = begin
        self.end = end
        self.text = text
        self.region = region
        self.style = style
    }
}

// MARK: - IMSC1Region

/// A spatial region for IMSC1 subtitle placement.
///
/// Maps to a TTML `<region>` element with origin and extent
/// specified as percentages of the root container.
public struct IMSC1Region: Sendable, Equatable {

    /// Unique identifier for this region.
    public let id: String

    /// Horizontal origin as a percentage (0.0–100.0).
    public let originX: Double

    /// Vertical origin as a percentage (0.0–100.0).
    public let originY: Double

    /// Width as a percentage (0.0–100.0).
    public let extentWidth: Double

    /// Height as a percentage (0.0–100.0).
    public let extentHeight: Double

    /// Creates a new subtitle region.
    ///
    /// - Parameters:
    ///   - id: Unique identifier.
    ///   - originX: Horizontal origin percentage.
    ///   - originY: Vertical origin percentage.
    ///   - extentWidth: Width percentage.
    ///   - extentHeight: Height percentage.
    public init(
        id: String,
        originX: Double,
        originY: Double,
        extentWidth: Double,
        extentHeight: Double
    ) {
        self.id = id
        self.originX = originX
        self.originY = originY
        self.extentWidth = extentWidth
        self.extentHeight = extentHeight
    }
}
