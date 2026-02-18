// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation

/// Generates HLS M3U8 manifest strings from typed Swift models.
///
/// The generator produces spec-compliant M3U8 text from
/// ``MasterPlaylist`` or ``MediaPlaylist`` instances.
///
/// ```swift
/// let generator = ManifestGenerator()
/// let m3u8 = generator.generate(.master(playlist))
/// ```
///
/// See RFC 8216 for the full M3U8 specification.
public struct ManifestGenerator: Sendable {

    /// The tag writer used for individual tag serialization.
    private let tagWriter: TagWriter

    /// Creates a manifest generator.
    ///
    /// - Parameter tagWriter: The tag writer to use.
    public init(tagWriter: TagWriter = TagWriter()) {
        self.tagWriter = tagWriter
    }

    /// Generates an M3U8 string from a manifest.
    ///
    /// - Parameter manifest: The manifest to serialize.
    /// - Returns: The M3U8 text string.
    public func generate(_ manifest: Manifest) -> String {
        switch manifest {
        case .master(let playlist):
            return generateMaster(playlist)
        case .media(let playlist):
            return generateMedia(playlist)
        }
    }

    /// Generates an M3U8 string from a master playlist.
    ///
    /// - Parameter playlist: The master playlist.
    /// - Returns: The M3U8 text string.
    public func generateMaster(_ playlist: MasterPlaylist) -> String {
        var lines: [String] = ["#EXTM3U"]
        let version = playlist.version ?? calculateMasterVersion(playlist)
        appendMasterHeader(version, playlist, to: &lines)
        appendMasterRenditions(playlist.renditions, to: &lines)
        appendMasterVariants(playlist, version: version, to: &lines)
        appendMasterTrailer(playlist, to: &lines)
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// Generates an M3U8 string from a media playlist.
    ///
    /// - Parameter playlist: The media playlist.
    /// - Returns: The M3U8 text string.
    public func generateMedia(_ playlist: MediaPlaylist) -> String {
        var lines: [String] = ["#EXTM3U"]
        let version = playlist.version ?? calculateMediaVersion(playlist)
        appendMediaHeader(version, playlist, to: &lines)
        appendMediaSegments(playlist, version: version, to: &lines)
        appendMediaTrailer(playlist, to: &lines)
        lines.append("")
        return lines.joined(separator: "\n")
    }
}

// MARK: - Master Playlist Generation

extension ManifestGenerator {

    private func appendMasterHeader(
        _ version: HLSVersion,
        _ playlist: MasterPlaylist,
        to lines: inout [String]
    ) {
        if version.rawValue > 1 {
            lines.append("#EXT-X-VERSION:\(version.rawValue)")
        }
        if playlist.independentSegments {
            lines.append("#EXT-X-INDEPENDENT-SEGMENTS")
        }
        if let start = playlist.startOffset {
            lines.append(tagWriter.writeStart(start))
        }
        for def in playlist.definitions {
            lines.append(tagWriter.writeDefine(def))
        }
    }

    private func appendMasterRenditions(
        _ renditions: [Rendition], to lines: inout [String]
    ) {
        guard !renditions.isEmpty else { return }
        lines.append("")
        for rendition in renditions {
            lines.append(tagWriter.writeMedia(rendition))
        }
    }

    private func appendMasterVariants(
        _ playlist: MasterPlaylist,
        version: HLSVersion,
        to lines: inout [String]
    ) {
        if !playlist.variants.isEmpty {
            lines.append("")
            for variant in playlist.variants {
                lines.append(tagWriter.writeStreamInf(variant))
                lines.append(variant.uri)
            }
        }
        if !playlist.iFrameVariants.isEmpty {
            lines.append("")
            for iFrame in playlist.iFrameVariants {
                lines.append(tagWriter.writeIFrameStreamInf(iFrame))
            }
        }
    }

    private func appendMasterTrailer(
        _ playlist: MasterPlaylist, to lines: inout [String]
    ) {
        if !playlist.sessionData.isEmpty {
            lines.append("")
            for data in playlist.sessionData {
                lines.append(tagWriter.writeSessionData(data))
            }
        }
        for key in playlist.sessionKeys {
            lines.append(tagWriter.writeSessionKey(key))
        }
        if let steering = playlist.contentSteering {
            lines.append("")
            lines.append(tagWriter.writeContentSteering(steering))
        }
    }
}

// MARK: - Segment Generation State

private struct SegmentGenState {
    var currentKey: EncryptionKey?
    var currentMap: MapTag?
    var currentBitrate: Int?
}

// MARK: - Media Playlist Generation

extension ManifestGenerator {

    private func appendMediaHeader(
        _ version: HLSVersion,
        _ playlist: MediaPlaylist,
        to lines: inout [String]
    ) {
        if version.rawValue > 1 {
            lines.append("#EXT-X-VERSION:\(version.rawValue)")
        }
        lines.append("#EXT-X-TARGETDURATION:\(playlist.targetDuration)")
        if playlist.mediaSequence != 0 {
            lines.append(
                "#EXT-X-MEDIA-SEQUENCE:\(playlist.mediaSequence)"
            )
        }
        if playlist.discontinuitySequence != 0 {
            lines.append(
                "#EXT-X-DISCONTINUITY-SEQUENCE:"
                    + "\(playlist.discontinuitySequence)"
            )
        }
        appendMediaHeaderFlags(playlist, to: &lines)
    }

    private func appendMediaHeaderFlags(
        _ playlist: MediaPlaylist, to lines: inout [String]
    ) {
        if let playlistType = playlist.playlistType {
            lines.append("#EXT-X-PLAYLIST-TYPE:\(playlistType.rawValue)")
        }
        if playlist.iFramesOnly {
            lines.append("#EXT-X-I-FRAMES-ONLY")
        }
        if playlist.independentSegments {
            lines.append("#EXT-X-INDEPENDENT-SEGMENTS")
        }
        if let start = playlist.startOffset {
            lines.append(tagWriter.writeStart(start))
        }
        for def in playlist.definitions {
            lines.append(tagWriter.writeDefine(def))
        }
        if let control = playlist.serverControl {
            lines.append(tagWriter.writeServerControl(control))
        }
        if let partTarget = playlist.partTargetDuration {
            lines.append(tagWriter.writePartInf(partTarget: partTarget))
        }
    }

    private func appendMediaSegments(
        _ playlist: MediaPlaylist,
        version: HLSVersion,
        to lines: inout [String]
    ) {
        var state = SegmentGenState()
        lines.append("")
        for segment in playlist.segments {
            emitSegmentTags(
                segment, version: version,
                state: &state, to: &lines
            )
        }
        appendMediaPartialSegments(playlist, to: &lines)
    }

    private func emitSegmentTags(
        _ segment: Segment,
        version: HLSVersion,
        state: inout SegmentGenState,
        to lines: inout [String]
    ) {
        if segment.key != state.currentKey {
            if let key = segment.key {
                lines.append(tagWriter.writeKey(key))
            }
            state.currentKey = segment.key
        }
        if segment.map != state.currentMap {
            if let map = segment.map {
                lines.append(tagWriter.writeMap(map))
            }
            state.currentMap = segment.map
        }
        emitSegmentMetadata(
            segment, version: version,
            state: &state, to: &lines
        )
    }

    private func emitSegmentMetadata(
        _ segment: Segment,
        version: HLSVersion,
        state: inout SegmentGenState,
        to lines: inout [String]
    ) {
        if let date = segment.programDateTime {
            lines.append(tagWriter.writeProgramDateTime(date))
        }
        if segment.discontinuity {
            lines.append("#EXT-X-DISCONTINUITY")
        }
        if segment.isGap {
            lines.append("#EXT-X-GAP")
        }
        if segment.bitrate != state.currentBitrate,
            let bitrate = segment.bitrate
        {
            lines.append("#EXT-X-BITRATE:\(bitrate)")
            state.currentBitrate = segment.bitrate
        }
        if let byteRange = segment.byteRange {
            lines.append(tagWriter.writeByteRange(byteRange))
        }
        lines.append(
            tagWriter.writeExtInf(
                duration: segment.duration,
                title: segment.title,
                version: version
            )
        )
        lines.append(segment.uri)
    }
}

// MARK: - Media Playlist Trailer

extension ManifestGenerator {

    private func appendMediaPartialSegments(
        _ playlist: MediaPlaylist, to lines: inout [String]
    ) {
        for part in playlist.partialSegments {
            lines.append(tagWriter.writePart(part))
        }
        for dateRange in playlist.dateRanges {
            lines.append(tagWriter.writeDateRange(dateRange))
        }
        for hint in playlist.preloadHints {
            lines.append(tagWriter.writePreloadHint(hint))
        }
        for report in playlist.renditionReports {
            lines.append(tagWriter.writeRenditionReport(report))
        }
        if let skip = playlist.skip {
            lines.append(tagWriter.writeSkip(skip))
        }
    }

    private func appendMediaTrailer(
        _ playlist: MediaPlaylist, to lines: inout [String]
    ) {
        if playlist.hasEndList {
            lines.append("#EXT-X-ENDLIST")
        }
    }
}

// MARK: - Version Auto-Calculation

extension ManifestGenerator {

    func calculateMediaVersion(
        _ playlist: MediaPlaylist
    ) -> HLSVersion {
        var version = 1
        if hasDecimalDurations(playlist.segments) {
            version = max(version, 3)
        }
        if playlist.segments.contains(where: { $0.byteRange != nil }) {
            version = max(version, 4)
        }
        if playlist.iFramesOnly {
            version = max(version, 4)
        }
        version = checkMediaEncryption(playlist, current: version)
        if !playlist.iFramesOnly
            && playlist.segments.contains(where: { $0.map != nil })
        {
            version = max(version, 6)
        }
        if !playlist.definitions.isEmpty {
            version = max(version, 8)
        }
        if hasLLHLSFeatures(playlist) {
            version = max(version, 9)
        }
        return HLSVersion(rawValue: version) ?? .v9
    }

    private func hasDecimalDurations(_ segments: [Segment]) -> Bool {
        segments.contains {
            $0.duration.truncatingRemainder(dividingBy: 1) != 0
        }
    }

    private func checkMediaEncryption(
        _ playlist: MediaPlaylist, current: Int
    ) -> Int {
        var version = current
        for segment in playlist.segments {
            guard let key = segment.key else { continue }
            if key.iv != nil { version = max(version, 2) }
            if key.keyFormat != nil || key.keyFormatVersions != nil {
                version = max(version, 5)
            }
        }
        return version
    }

    private func hasLLHLSFeatures(_ playlist: MediaPlaylist) -> Bool {
        playlist.serverControl != nil
            || playlist.partTargetDuration != nil
            || !playlist.partialSegments.isEmpty
            || !playlist.preloadHints.isEmpty
    }

    func calculateMasterVersion(
        _ playlist: MasterPlaylist
    ) -> HLSVersion {
        var version = 1
        if hasHDCPLevel(playlist) {
            version = max(version, 7)
        }
        if !playlist.definitions.isEmpty {
            version = max(version, 8)
        }
        if playlist.contentSteering != nil {
            version = max(version, 10)
        }
        return HLSVersion(rawValue: version) ?? .v7
    }

    private func hasHDCPLevel(_ playlist: MasterPlaylist) -> Bool {
        playlist.variants.contains { $0.hdcpLevel != nil }
            || playlist.iFrameVariants.contains { $0.hdcpLevel != nil }
    }
}
