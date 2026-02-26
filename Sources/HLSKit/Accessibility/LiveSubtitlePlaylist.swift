// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

/// Generates a live media playlist for WebVTT subtitle segments.
///
/// Produces a sliding window playlist of `.vtt` segments synchronized
/// with the main media playlist. Used as a `TYPE=SUBTITLES` rendition.
///
/// ```swift
/// let playlist = LiveSubtitlePlaylist(
///     targetDuration: 6,
///     language: "en",
///     name: "English Subtitles"
/// )
/// var mutable = playlist
/// mutable.addSegment(uri: "sub_001.vtt", duration: 6.0)
/// let m3u8 = mutable.render()
/// ```
public struct LiveSubtitlePlaylist: Sendable {

    /// Target segment duration.
    public let targetDuration: Int

    /// Language code.
    public let language: String

    /// Track name.
    public let name: String

    /// Whether these are forced subtitles (e.g., foreign language translations).
    public let forced: Bool

    /// Sliding window size (number of segments to keep).
    public var windowSize: Int

    /// Segments in the playlist.
    private var segments: [SubtitleSegment] = []

    /// Current media sequence number.
    private var mediaSequence: Int = 0

    /// Creates a live subtitle playlist.
    ///
    /// - Parameters:
    ///   - targetDuration: The target segment duration in seconds.
    ///   - language: The ISO 639-1 language code.
    ///   - name: A human-readable track name.
    ///   - forced: Whether these are forced subtitles.
    ///   - windowSize: The sliding window size.
    public init(
        targetDuration: Int = 6,
        language: String = "en",
        name: String = "English",
        forced: Bool = false,
        windowSize: Int = 5
    ) {
        self.targetDuration = targetDuration
        self.language = language
        self.name = name
        self.forced = forced
        self.windowSize = windowSize
    }

    // MARK: - SubtitleSegment

    /// A subtitle segment entry.
    public struct SubtitleSegment: Sendable, Equatable {
        /// URI of the WebVTT segment.
        public let uri: String
        /// Duration of the segment in seconds.
        public let duration: Double
    }

    // MARK: - Mutation

    /// Add a subtitle segment.
    ///
    /// Trims the playlist to the sliding window size and updates
    /// the media sequence number accordingly.
    ///
    /// - Parameters:
    ///   - uri: The URI of the WebVTT segment.
    ///   - duration: The segment duration in seconds.
    public mutating func addSegment(uri: String, duration: Double) {
        segments.append(SubtitleSegment(uri: uri, duration: duration))
        if segments.count > windowSize {
            segments.removeFirst()
            mediaSequence += 1
        }
    }

    // MARK: - Rendering

    /// Render the playlist as an M3U8 string.
    ///
    /// - Returns: The formatted M3U8 playlist string.
    public func render() -> String {
        var lines: [String] = [
            "#EXTM3U",
            "#EXT-X-TARGETDURATION:\(targetDuration)",
            "#EXT-X-VERSION:3",
            "#EXT-X-MEDIA-SEQUENCE:\(mediaSequence)"
        ]
        for segment in segments {
            lines.append("#EXTINF:\(formatDuration(segment.duration)),")
            lines.append(segment.uri)
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Generate the EXT-X-MEDIA rendition entry for the master playlist.
    ///
    /// - Parameters:
    ///   - groupID: The GROUP-ID for the subtitles group.
    ///   - uri: The URI of this subtitle playlist.
    ///   - isDefault: Whether this is the default subtitle track.
    /// - Returns: The formatted EXT-X-MEDIA tag string.
    public func renditionEntry(
        groupID: String = "subs",
        uri: String,
        isDefault: Bool = false
    ) -> String {
        var attrs: [String] = [
            "TYPE=SUBTITLES",
            "GROUP-ID=\"\(groupID)\"",
            "LANGUAGE=\"\(language)\"",
            "NAME=\"\(name)\"",
            "DEFAULT=\(isDefault ? "YES" : "NO")",
            "AUTOSELECT=YES"
        ]
        if forced {
            attrs.append("FORCED=YES")
        }
        attrs.append("URI=\"\(uri)\"")
        return "#EXT-X-MEDIA:" + attrs.joined(separator: ",")
    }

    /// Current segment count.
    public var segmentCount: Int { segments.count }

    // MARK: - Private

    private func formatDuration(_ duration: Double) -> String {
        if duration == Double(Int(duration)) {
            return String(format: "%.1f", duration)
        }
        return String(format: "%.3f", duration)
    }
}
