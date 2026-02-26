// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Real-time WebVTT writer for live subtitle segments.
///
/// Accumulates subtitle cues and renders them as WebVTT segments
/// synchronized with the live media segments.
///
/// ```swift
/// let writer = LiveWebVTTWriter(segmentDuration: 6.0)
/// await writer.addCue(WebVTTCue(startTime: 0.5, endTime: 3.0, text: "Hello"))
/// let vtt = await writer.renderSegment()
/// // "WEBVTT\n\n00:00.500 --> 00:03.000\nHello\n"
/// ```
public actor LiveWebVTTWriter {

    /// Segment duration in seconds.
    private let segmentDuration: TimeInterval

    /// Accumulated cues for the current segment.
    private var currentCues: [WebVTTCue] = []

    /// Segment index counter.
    private var segmentIndex: Int = 0

    /// Creates a live WebVTT writer.
    ///
    /// - Parameter segmentDuration: The target segment duration in seconds.
    public init(segmentDuration: TimeInterval = 6.0) {
        self.segmentDuration = segmentDuration
    }

    /// Add a subtitle cue to the current segment.
    ///
    /// - Parameter cue: The WebVTT cue to add.
    public func addCue(_ cue: WebVTTCue) {
        currentCues.append(cue)
    }

    /// Render the current segment as a WebVTT string and advance to the next.
    ///
    /// - Returns: The formatted WebVTT segment string.
    public func renderSegment() -> String {
        let output = formatSegment()
        currentCues.removeAll()
        segmentIndex += 1
        return output
    }

    /// Peek at the current segment without advancing.
    ///
    /// - Returns: The formatted WebVTT segment string.
    public func previewSegment() -> String {
        formatSegment()
    }

    /// Current segment index.
    ///
    /// - Returns: The zero-based segment index.
    public func currentSegmentIndex() -> Int {
        segmentIndex
    }

    /// Number of cues in the current segment.
    ///
    /// - Returns: The cue count.
    public func cueCount() -> Int {
        currentCues.count
    }

    /// Reset the writer for a new stream.
    public func reset() {
        currentCues.removeAll()
        segmentIndex = 0
    }

    // MARK: - Private

    private func formatSegment() -> String {
        var output = "WEBVTT\n"
        for cue in currentCues {
            output += "\n" + cue.format()
        }
        return output
    }
}

// MARK: - WebVTTCue

/// A WebVTT subtitle cue.
public struct WebVTTCue: Sendable, Equatable {

    /// Start time relative to segment start, in seconds.
    public let startTime: TimeInterval

    /// End time relative to segment start, in seconds.
    public let endTime: TimeInterval

    /// Subtitle text (may contain WebVTT formatting tags).
    public let text: String

    /// Horizontal position (percentage, nil for default center).
    public let position: Int?

    /// Text alignment.
    public let alignment: WebVTTAlignment?

    /// Creates a WebVTT cue.
    ///
    /// - Parameters:
    ///   - startTime: Start time in seconds.
    ///   - endTime: End time in seconds.
    ///   - text: The subtitle text.
    ///   - position: Optional horizontal position percentage.
    ///   - alignment: Optional text alignment.
    public init(
        startTime: TimeInterval,
        endTime: TimeInterval,
        text: String,
        position: Int? = nil,
        alignment: WebVTTAlignment? = nil
    ) {
        self.startTime = startTime
        self.endTime = endTime
        self.text = text
        self.position = position
        self.alignment = alignment
    }

    /// Format the cue as a WebVTT cue block.
    ///
    /// - Returns: The formatted cue string.
    public func format() -> String {
        var timing = "\(formatTime(startTime)) --> \(formatTime(endTime))"
        var settings: [String] = []
        if let position {
            settings.append("position:\(position)%")
        }
        if let alignment {
            settings.append("align:\(alignment.rawValue)")
        }
        if !settings.isEmpty {
            timing += " " + settings.joined(separator: " ")
        }
        return timing + "\n" + text + "\n"
    }

    // MARK: - Private

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalMilliseconds = Int(seconds * 1000)
        let ms = totalMilliseconds % 1000
        let s = (totalMilliseconds / 1000) % 60
        let m = (totalMilliseconds / 60000) % 60
        let h = totalMilliseconds / 3_600_000
        if h > 0 {
            return String(format: "%02d:%02d:%02d.%03d", h, m, s, ms)
        }
        return String(format: "%02d:%02d.%03d", m, s, ms)
    }
}

// MARK: - WebVTTAlignment

/// WebVTT text alignment.
public enum WebVTTAlignment: String, Sendable, CaseIterable, Equatable {
    /// Align text to the start.
    case start
    /// Align text to the center.
    case center
    /// Align text to the end.
    case end
    /// Align text to the left.
    case left
    /// Align text to the right.
    case right
}
