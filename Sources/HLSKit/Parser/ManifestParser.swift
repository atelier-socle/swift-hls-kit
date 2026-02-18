// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// The result of parsing an HLS manifest.
///
/// An HLS manifest is either a master playlist (listing variant streams)
/// or a media playlist (listing media segments). The parser determines
/// which type based on the tags present.
public enum Manifest: Sendable, Hashable {

    /// A master playlist containing variant stream references.
    case master(MasterPlaylist)

    /// A media playlist containing media segments.
    case media(MediaPlaylist)
}

/// Parses HLS M3U8 manifest strings into typed Swift models.
///
/// The parser reads an M3U8 text string and produces either a
/// ``MasterPlaylist`` or ``MediaPlaylist`` depending on the tags present.
///
/// ```swift
/// let parser = ManifestParser()
/// let manifest = try parser.parse(m3u8String)
/// switch manifest {
/// case .master(let playlist):
///     print("Found \(playlist.variants.count) variants")
/// case .media(let playlist):
///     print("Found \(playlist.segments.count) segments")
/// }
/// ```
///
/// See RFC 8216 for the full M3U8 specification.
public struct ManifestParser: Sendable {

    /// The tag parser used for individual tag processing.
    private let tagParser: TagParser

    /// Creates a manifest parser.
    ///
    /// - Parameter tagParser: The tag parser to use.
    public init(tagParser: TagParser = TagParser()) {
        self.tagParser = tagParser
    }

    /// Parses an M3U8 manifest string.
    ///
    /// Automatically detects whether the manifest is a master or media
    /// playlist based on the presence of type-determining tags.
    ///
    /// - Parameter string: The M3U8 manifest text.
    /// - Returns: A ``Manifest`` value — either `.master` or `.media`.
    /// - Throws: ``ParserError`` if the input is not a valid HLS manifest.
    public func parse(_ string: String) throws(ParserError) -> Manifest {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw .emptyManifest
        }

        let lines = trimmed.components(separatedBy: .newlines)
        let firstNonEmpty = lines.first {
            !$0.trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard firstNonEmpty?.trimmingCharacters(in: .whitespaces) == "#EXTM3U" else {
            throw .missingHeader
        }

        if containsMasterIndicators(lines) {
            return .master(try parseMasterPlaylist(lines: lines))
        } else if containsMediaIndicators(lines) {
            return .media(try parseMediaPlaylist(lines: lines))
        } else {
            throw .ambiguousPlaylistType
        }
    }
}

// MARK: - Playlist Type Detection

extension ManifestParser {

    private func containsMasterIndicators(_ lines: [String]) -> Bool {
        lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("#EXT-X-STREAM-INF:")
                || trimmed.hasPrefix("#EXT-X-I-FRAME-STREAM-INF:")
                || trimmed.hasPrefix("#EXT-X-MEDIA:")
        }
    }

    private func containsMediaIndicators(_ lines: [String]) -> Bool {
        lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("#EXTINF:")
                || trimmed.hasPrefix("#EXT-X-TARGETDURATION:")
        }
    }
}

// MARK: - Master Playlist Parsing State

private struct MasterParsingState {
    var version: HLSVersion?
    var variants: [Variant] = []
    var iFrameVariants: [IFrameVariant] = []
    var renditions: [Rendition] = []
    var sessionDataList: [SessionData] = []
    var sessionKeys: [EncryptionKey] = []
    var contentSteering: ContentSteering?
    var independentSegments = false
    var startOffset: StartOffset?
    var definitions: [VariableDefinition] = []
    var pendingStreamInf: Variant?

    func buildPlaylist() -> MasterPlaylist {
        MasterPlaylist(
            version: version,
            variants: variants,
            iFrameVariants: iFrameVariants,
            renditions: renditions,
            sessionData: sessionDataList,
            sessionKeys: sessionKeys,
            contentSteering: contentSteering,
            independentSegments: independentSegments,
            startOffset: startOffset,
            definitions: definitions
        )
    }
}

// MARK: - Master Playlist Parsing

extension ManifestParser {

    private func parseMasterPlaylist(
        lines: [String]
    ) throws(ParserError) -> MasterPlaylist {
        var state = MasterParsingState()

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1

            if line.isEmpty || line == "#EXTM3U" { continue }

            if line.hasPrefix("#EXT-X-VERSION:") {
                state.version = try parseVersion(
                    tagValue(from: line), line: lineNumber
                )
            } else if try handleMasterStreamTag(line, state: &state) {
                continue
            } else if try handleMasterMetadataTag(line, state: &state) {
                continue
            } else if !line.hasPrefix("#") {
                if var variant = state.pendingStreamInf {
                    variant.uri = line
                    state.variants.append(variant)
                    state.pendingStreamInf = nil
                }
            }
        }

        if let pending = state.pendingStreamInf {
            throw .missingURI(
                afterTag: "EXT-X-STREAM-INF",
                line: findLineNumber(
                    for: "#EXT-X-STREAM-INF",
                    bandwidth: pending.bandwidth,
                    in: lines
                )
            )
        }

        return state.buildPlaylist()
    }

    private func handleMasterStreamTag(
        _ line: String, state: inout MasterParsingState
    ) throws(ParserError) -> Bool {
        if line.hasPrefix("#EXT-X-STREAM-INF:") {
            state.pendingStreamInf = try tagParser.parseStreamInf(
                tagValue(from: line)
            )
            return true
        } else if line.hasPrefix("#EXT-X-I-FRAME-STREAM-INF:") {
            state.iFrameVariants.append(
                try tagParser.parseIFrameStreamInf(tagValue(from: line))
            )
            return true
        }
        return false
    }

    private func handleMasterMetadataTag(
        _ line: String, state: inout MasterParsingState
    ) throws(ParserError) -> Bool {
        if line.hasPrefix("#EXT-X-MEDIA:") {
            state.renditions.append(
                try tagParser.parseMedia(tagValue(from: line))
            )
        } else if line.hasPrefix("#EXT-X-SESSION-DATA:") {
            state.sessionDataList.append(
                try tagParser.parseSessionData(tagValue(from: line))
            )
        } else if line.hasPrefix("#EXT-X-SESSION-KEY:") {
            state.sessionKeys.append(
                try tagParser.parseSessionKey(tagValue(from: line))
            )
        } else if line.hasPrefix("#EXT-X-CONTENT-STEERING:") {
            state.contentSteering = try tagParser.parseContentSteering(
                tagValue(from: line)
            )
        } else if line.hasPrefix("#EXT-X-INDEPENDENT-SEGMENTS") {
            state.independentSegments = true
        } else if line.hasPrefix("#EXT-X-START:") {
            state.startOffset = try tagParser.parseStart(tagValue(from: line))
        } else if line.hasPrefix("#EXT-X-DEFINE:") {
            if let def = try tagParser.parseDefine(tagValue(from: line)) {
                state.definitions.append(def)
            }
        } else {
            return false
        }
        return true
    }
}

// MARK: - Media Playlist Parsing State

private struct MediaParsingState {
    var version: HLSVersion?
    var targetDuration: Int?
    var mediaSequence = 0
    var discontinuitySequence = 0
    var playlistType: PlaylistType?
    var hasEndList = false
    var iFramesOnly = false
    var segments: [Segment] = []
    var dateRanges: [DateRange] = []
    var independentSegments = false
    var startOffset: StartOffset?
    var definitions: [VariableDefinition] = []

    // LL-HLS
    var partTargetDuration: Double?
    var serverControl: ServerControl?
    var partialSegments: [PartialSegment] = []
    var preloadHints: [PreloadHint] = []
    var renditionReports: [RenditionReport] = []
    var skip: SkipInfo?

    // Segment state accumulation
    var currentKey: EncryptionKey?
    var currentMap: MapTag?
    var pendingByteRange: ByteRange?
    var pendingProgramDateTime: Date?
    var pendingDiscontinuity = false
    var pendingGap = false
    var currentBitrate: Int?
    var pendingDuration: Double?
    var pendingTitle: String?

    mutating func resetPendingSegmentState() {
        pendingDuration = nil
        pendingTitle = nil
        pendingByteRange = nil
        pendingProgramDateTime = nil
        pendingDiscontinuity = false
        pendingGap = false
    }

    func buildPlaylist(targetDuration: Int) -> MediaPlaylist {
        MediaPlaylist(
            version: version,
            targetDuration: targetDuration,
            mediaSequence: mediaSequence,
            discontinuitySequence: discontinuitySequence,
            playlistType: playlistType,
            hasEndList: hasEndList,
            iFramesOnly: iFramesOnly,
            segments: segments,
            dateRanges: dateRanges,
            independentSegments: independentSegments,
            startOffset: startOffset,
            definitions: definitions,
            partTargetDuration: partTargetDuration,
            serverControl: serverControl,
            partialSegments: partialSegments,
            preloadHints: preloadHints,
            renditionReports: renditionReports,
            skip: skip
        )
    }
}

// MARK: - Media Playlist Parsing

extension ManifestParser {

    private func parseMediaPlaylist(
        lines: [String]
    ) throws(ParserError) -> MediaPlaylist {
        var state = MediaParsingState()

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            let lineNumber = index + 1
            if line.isEmpty || line == "#EXTM3U" { continue }
            try processMediaLine(line, lineNumber: lineNumber, state: &state)
        }

        guard let finalTargetDuration = state.targetDuration else {
            throw .missingRequiredTag("EXT-X-TARGETDURATION")
        }
        return state.buildPlaylist(targetDuration: finalTargetDuration)
    }

    private func processMediaLine(
        _ line: String,
        lineNumber: Int,
        state: inout MediaParsingState
    ) throws(ParserError) {
        if line.hasPrefix("#EXT-X-VERSION:") {
            state.version = try parseVersion(
                tagValue(from: line), line: lineNumber
            )
        } else if try handleMediaHeaderTag(
            line, lineNumber: lineNumber, state: &state
        ) {
            return
        } else if try handleMediaSegmentTag(line, state: &state) {
            return
        } else if try handleMediaLLHLSTag(line, state: &state) {
            return
        } else if try handleMediaCommonTag(line, state: &state) {
            return
        } else if !line.hasPrefix("#") {
            handleMediaURI(line, state: &state)
        }
    }

    private func handleMediaHeaderTag(
        _ line: String,
        lineNumber: Int,
        state: inout MediaParsingState
    ) throws(ParserError) -> Bool {
        if line.hasPrefix("#EXT-X-TARGETDURATION:") {
            guard let value = Int(tagValue(from: line)) else {
                throw .invalidTagFormat(
                    tag: "EXT-X-TARGETDURATION", line: lineNumber
                )
            }
            state.targetDuration = value
        } else if line.hasPrefix("#EXT-X-MEDIA-SEQUENCE:") {
            guard let value = Int(tagValue(from: line)) else {
                throw .invalidTagFormat(
                    tag: "EXT-X-MEDIA-SEQUENCE", line: lineNumber
                )
            }
            state.mediaSequence = value
        } else if line.hasPrefix("#EXT-X-DISCONTINUITY-SEQUENCE:") {
            guard let value = Int(tagValue(from: line)) else {
                throw .invalidTagFormat(
                    tag: "EXT-X-DISCONTINUITY-SEQUENCE", line: lineNumber
                )
            }
            state.discontinuitySequence = value
        } else if line.hasPrefix("#EXT-X-PLAYLIST-TYPE:") {
            state.playlistType = PlaylistType(rawValue: tagValue(from: line))
        } else if line.hasPrefix("#EXT-X-ENDLIST") {
            state.hasEndList = true
        } else if line.hasPrefix("#EXT-X-I-FRAMES-ONLY") {
            state.iFramesOnly = true
        } else {
            return false
        }
        return true
    }

    private func handleMediaSegmentTag(
        _ line: String,
        state: inout MediaParsingState
    ) throws(ParserError) -> Bool {
        if line.hasPrefix("#EXTINF:") {
            let (duration, title) = try tagParser.parseExtInf(
                tagValue(from: line)
            )
            state.pendingDuration = duration
            state.pendingTitle = title
        } else if line.hasPrefix("#EXT-X-BYTERANGE:") {
            state.pendingByteRange = try tagParser.parseByteRange(
                tagValue(from: line)
            )
        } else if line.hasPrefix("#EXT-X-KEY:") {
            state.currentKey = try tagParser.parseKey(tagValue(from: line))
        } else if line.hasPrefix("#EXT-X-MAP:") {
            state.currentMap = try tagParser.parseMap(tagValue(from: line))
        } else if line.hasPrefix("#EXT-X-PROGRAM-DATE-TIME:") {
            state.pendingProgramDateTime = try tagParser.parseProgramDateTime(
                tagValue(from: line)
            )
        } else if line.hasPrefix("#EXT-X-DISCONTINUITY"),
            !line.hasPrefix("#EXT-X-DISCONTINUITY-SEQUENCE")
        {
            state.pendingDiscontinuity = true
        } else if line.hasPrefix("#EXT-X-GAP") {
            state.pendingGap = true
        } else if line.hasPrefix("#EXT-X-BITRATE:") {
            state.currentBitrate = Int(tagValue(from: line))
        } else if line.hasPrefix("#EXT-X-DATERANGE:") {
            state.dateRanges.append(
                try tagParser.parseDateRange(tagValue(from: line))
            )
        } else {
            return false
        }
        return true
    }

    private func handleMediaLLHLSTag(
        _ line: String,
        state: inout MediaParsingState
    ) throws(ParserError) -> Bool {
        if line.hasPrefix("#EXT-X-SERVER-CONTROL:") {
            state.serverControl = tagParser.parseServerControl(
                tagValue(from: line)
            )
        } else if line.hasPrefix("#EXT-X-PART-INF:") {
            state.partTargetDuration = try tagParser.parsePartInf(
                tagValue(from: line)
            )
        } else if line.hasPrefix("#EXT-X-PART:") {
            state.partialSegments.append(
                try tagParser.parsePart(tagValue(from: line))
            )
        } else if line.hasPrefix("#EXT-X-PRELOAD-HINT:") {
            state.preloadHints.append(
                try tagParser.parsePreloadHint(tagValue(from: line))
            )
        } else if line.hasPrefix("#EXT-X-RENDITION-REPORT:") {
            state.renditionReports.append(
                try tagParser.parseRenditionReport(tagValue(from: line))
            )
        } else if line.hasPrefix("#EXT-X-SKIP:") {
            state.skip = try tagParser.parseSkip(tagValue(from: line))
        } else {
            return false
        }
        return true
    }

    private func handleMediaCommonTag(
        _ line: String,
        state: inout MediaParsingState
    ) throws(ParserError) -> Bool {
        if line.hasPrefix("#EXT-X-INDEPENDENT-SEGMENTS") {
            state.independentSegments = true
        } else if line.hasPrefix("#EXT-X-START:") {
            state.startOffset = try tagParser.parseStart(tagValue(from: line))
        } else if line.hasPrefix("#EXT-X-DEFINE:") {
            if let def = try tagParser.parseDefine(tagValue(from: line)) {
                state.definitions.append(def)
            }
        } else {
            return false
        }
        return true
    }

    private func handleMediaURI(
        _ line: String, state: inout MediaParsingState
    ) {
        guard let duration = state.pendingDuration else { return }
        let segment = Segment(
            duration: duration,
            uri: line,
            title: state.pendingTitle,
            byteRange: state.pendingByteRange,
            key: state.currentKey,
            map: state.currentMap,
            programDateTime: state.pendingProgramDateTime,
            discontinuity: state.pendingDiscontinuity,
            isGap: state.pendingGap,
            bitrate: state.currentBitrate
        )
        state.segments.append(segment)
        state.resetPendingSegmentState()
    }
}

// MARK: - Helpers

extension ManifestParser {

    private func tagValue(from line: String) -> String {
        guard let colonIndex = line.firstIndex(of: ":") else { return "" }
        return String(line[line.index(after: colonIndex)...])
    }

    private func parseVersion(
        _ value: String, line: Int
    ) throws(ParserError) -> HLSVersion {
        guard let raw = Int(value),
            let version = HLSVersion(rawValue: raw)
        else {
            throw .invalidVersion(value)
        }
        return version
    }

    private func findLineNumber(
        for tag: String, bandwidth: Int, in lines: [String]
    ) -> Int {
        for (index, line) in lines.enumerated()
        where line.contains(tag) && line.contains("BANDWIDTH=\(bandwidth)") {
            return index + 1
        }
        return lines.count
    }
}
