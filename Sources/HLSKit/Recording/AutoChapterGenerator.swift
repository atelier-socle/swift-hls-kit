// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Generates chapter markers from live stream metadata.
///
/// Detects chapter boundaries from:
/// - DATERANGE tags with CLASS containing "chapter"
/// - Discontinuity markers
/// - ID3 metadata changes (title/artist)
/// - Custom chapter markers (explicit)
///
/// Outputs chapters in JSON (Podcast Namespace 2.0 format) or WebVTT.
///
/// ```swift
/// var generator = AutoChapterGenerator()
/// generator.addMetadataChange(at: 0.0, title: "Introduction")
/// generator.addMetadataChange(at: 120.5, title: "Interview")
/// generator.addDiscontinuity(at: 300.0)
/// generator.addMetadataChange(at: 300.0, title: "Musical Break")
///
/// generator.finalize(totalDuration: 600.0)
/// let json = generator.generateJSON()
/// let vtt = generator.generateWebVTT()
/// ```
public struct AutoChapterGenerator: Sendable {

    // MARK: - Types

    /// A chapter marker.
    public struct Chapter: Sendable, Equatable, Identifiable {

        /// Unique chapter identifier.
        public var id: String

        /// Chapter title.
        public var title: String

        /// Start time in seconds.
        public var startTime: TimeInterval

        /// End time in seconds (set by ``finalize(totalDuration:)``).
        public var endTime: TimeInterval?

        /// Optional image URL for the chapter.
        public var imageURL: String?

        /// Optional link URL for the chapter.
        public var url: String?
    }

    /// Chapter detection source.
    public enum DetectionSource: Sendable, Equatable {
        /// Chapter detected from a DATERANGE tag.
        case dateRange(id: String, className: String?)
        /// Chapter detected from a discontinuity marker.
        case discontinuity
        /// Chapter detected from ID3 metadata change.
        case id3Metadata(title: String?)
        /// Explicitly added chapter.
        case explicit
    }

    // MARK: - Properties

    /// Accumulated chapters.
    public private(set) var chapters: [Chapter]

    /// Minimum chapter duration (to avoid micro-chapters).
    public var minimumDuration: TimeInterval

    private var nextChapterIndex: Int
    private var sources: [DetectionSource]

    // MARK: - Init

    /// Creates an auto chapter generator.
    ///
    /// - Parameter minimumDuration: Minimum chapter duration in seconds.
    ///   Chapters shorter than this are merged with the previous chapter.
    ///   Defaults to 10 seconds.
    public init(minimumDuration: TimeInterval = 10.0) {
        self.chapters = []
        self.minimumDuration = minimumDuration
        self.nextChapterIndex = 1
        self.sources = []
    }

    // MARK: - Chapter Detection

    /// Add a chapter from a metadata change (ID3 title/artist).
    ///
    /// - Parameters:
    ///   - time: Chapter start time in seconds.
    ///   - title: Chapter title.
    ///   - imageURL: Optional image URL.
    ///   - url: Optional link URL.
    public mutating func addMetadataChange(
        at time: TimeInterval,
        title: String,
        imageURL: String? = nil,
        url: String? = nil
    ) {
        let chapter = Chapter(
            id: "chap-\(nextChapterIndex)",
            title: title,
            startTime: time,
            imageURL: imageURL,
            url: url
        )
        chapters.append(chapter)
        sources.append(.id3Metadata(title: title))
        nextChapterIndex += 1
    }

    /// Add a chapter from a discontinuity.
    ///
    /// - Parameters:
    ///   - time: Discontinuity time in seconds.
    ///   - title: Optional title. Defaults to "Chapter N".
    public mutating func addDiscontinuity(
        at time: TimeInterval,
        title: String? = nil
    ) {
        let chapterTitle = title ?? "Chapter \(nextChapterIndex)"
        let chapter = Chapter(
            id: "chap-\(nextChapterIndex)",
            title: chapterTitle,
            startTime: time
        )
        chapters.append(chapter)
        sources.append(.discontinuity)
        nextChapterIndex += 1
    }

    /// Add a chapter from a DATERANGE tag.
    ///
    /// - Parameters:
    ///   - id: DATERANGE identifier.
    ///   - startTime: Chapter start time in seconds.
    ///   - title: Chapter title.
    ///   - className: Optional DATERANGE CLASS attribute.
    public mutating func addFromDateRange(
        id: String,
        startTime: TimeInterval,
        title: String,
        className: String? = nil
    ) {
        let chapter = Chapter(
            id: "chap-\(nextChapterIndex)",
            title: title,
            startTime: startTime
        )
        chapters.append(chapter)
        sources.append(.dateRange(id: id, className: className))
        nextChapterIndex += 1
    }

    /// Add an explicit chapter marker.
    ///
    /// - Parameters:
    ///   - title: Chapter title.
    ///   - startTime: Start time in seconds.
    ///   - endTime: Optional end time in seconds.
    ///   - imageURL: Optional image URL.
    ///   - url: Optional link URL.
    public mutating func addExplicit(
        title: String,
        startTime: TimeInterval,
        endTime: TimeInterval? = nil,
        imageURL: String? = nil,
        url: String? = nil
    ) {
        let chapter = Chapter(
            id: "chap-\(nextChapterIndex)",
            title: title,
            startTime: startTime,
            endTime: endTime,
            imageURL: imageURL,
            url: url
        )
        chapters.append(chapter)
        sources.append(.explicit)
        nextChapterIndex += 1
    }

    // MARK: - Generation

    /// Finalize chapters by setting end times and removing short chapters.
    ///
    /// Sets each chapter's end time to the next chapter's start time.
    /// The last chapter ends at `totalDuration`. Chapters shorter than
    /// ``minimumDuration`` are merged with the previous chapter.
    ///
    /// - Parameter totalDuration: Total stream duration in seconds.
    public mutating func finalize(totalDuration: TimeInterval) {
        guard !chapters.isEmpty else { return }
        chapters.sort { $0.startTime < $1.startTime }
        setEndTimes(totalDuration: totalDuration)
        mergeShortChapters(totalDuration: totalDuration)
    }

    /// Generate chapters as Podcast Namespace 2.0 JSON.
    ///
    /// - Returns: JSON string with chapters array.
    public func generateJSON() -> String {
        var result = "{\"version\":\"1.2.0\",\"chapters\":["
        for (index, chapter) in chapters.enumerated() {
            if index > 0 { result += "," }
            result += buildChapterJSON(chapter)
        }
        result += "]}"
        return result
    }

    /// Generate chapters as WebVTT.
    ///
    /// - Returns: WebVTT string with chapter cues.
    public func generateWebVTT() -> String {
        var lines = ["WEBVTT", ""]
        for (index, chapter) in chapters.enumerated() {
            lines.append(String(index + 1))
            let start = formatVTTTimestamp(chapter.startTime)
            let end = formatVTTTimestamp(chapter.endTime ?? chapter.startTime)
            lines.append("\(start) --> \(end)")
            lines.append(chapter.title)
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    /// Number of chapters.
    public var chapterCount: Int { chapters.count }

    /// Total covered duration.
    public var coveredDuration: TimeInterval {
        guard let first = chapters.first,
            let last = chapters.last
        else { return 0 }
        return (last.endTime ?? last.startTime) - first.startTime
    }

    /// Reset all chapters.
    public mutating func reset() {
        chapters = []
        sources = []
        nextChapterIndex = 1
    }

    // MARK: - Private

    private mutating func setEndTimes(totalDuration: TimeInterval) {
        for i in 0..<chapters.count where chapters[i].endTime == nil {
            if i + 1 < chapters.count {
                chapters[i].endTime = chapters[i + 1].startTime
            } else {
                chapters[i].endTime = totalDuration
            }
        }
    }

    private mutating func mergeShortChapters(totalDuration: TimeInterval) {
        var merged = [Chapter]()
        for chapter in chapters {
            if let lastIndex = merged.indices.last {
                let lastDur =
                    (merged[lastIndex].endTime ?? totalDuration)
                    - merged[lastIndex].startTime
                if lastDur < minimumDuration {
                    merged[lastIndex].endTime = chapter.endTime
                    continue
                }
            }
            let duration =
                (chapter.endTime ?? totalDuration) - chapter.startTime
            if duration < minimumDuration, let lastIndex = merged.indices.last {
                merged[lastIndex].endTime = chapter.endTime
            } else {
                merged.append(chapter)
            }
        }
        chapters = merged
    }

    private func buildChapterJSON(_ chapter: Chapter) -> String {
        var parts = [String]()
        parts.append("\"startTime\":\(formatJSONTime(chapter.startTime))")
        if let end = chapter.endTime {
            parts.append("\"endTime\":\(formatJSONTime(end))")
        }
        parts.append("\"title\":\(escapeJSON(chapter.title))")
        if let img = chapter.imageURL {
            parts.append("\"img\":\(escapeJSON(img))")
        }
        if let url = chapter.url {
            parts.append("\"url\":\(escapeJSON(url))")
        }
        return "{\(parts.joined(separator: ","))}"
    }

    private func formatJSONTime(_ time: TimeInterval) -> String {
        if time == time.rounded() && time < 1_000_000 {
            return String(Int(time))
        }
        return String(format: "%.1f", time)
    }

    private func escapeJSON(_ string: String) -> String {
        let escaped =
            string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    private func formatVTTTimestamp(_ seconds: TimeInterval) -> String {
        let totalMs = Int(seconds * 1000)
        let hours = totalMs / 3_600_000
        let minutes = (totalMs % 3_600_000) / 60_000
        let secs = (totalMs % 60_000) / 1_000
        let ms = totalMs % 1_000
        return String(
            format: "%02d:%02d:%02d.%03d", hours, minutes, secs, ms
        )
    }
}
