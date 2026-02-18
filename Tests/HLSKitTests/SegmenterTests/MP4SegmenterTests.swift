// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MP4Segmenter")
struct MP4SegmenterTests {

    // MARK: - Video-Only Segmentation

    @Test("segment — video-only MP4 produces init + segments")
    func videoOnlySegmentation() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let segmenter = MP4Segmenter()
        let result = try segmenter.segment(data: data)
        #expect(!result.initSegment.isEmpty)
        #expect(result.segmentCount > 0)
    }

    @Test("segment — init segment is parseable")
    func initSegmentParseable() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let reader = MP4BoxReader()
        let boxes = try reader.readBoxes(from: result.initSegment)
        let ftyp = boxes.first { $0.type == "ftyp" }
        let moov = boxes.first { $0.type == "moov" }
        #expect(ftyp != nil)
        #expect(moov != nil)
    }

    @Test("segment — init segment has mvex")
    func initSegmentHasMvex() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let boxes = try MP4BoxReader().readBoxes(
            from: result.initSegment
        )
        let moov = try #require(
            boxes.first { $0.type == "moov" }
        )
        let mvex = moov.findChild("mvex")
        #expect(mvex != nil)
    }

    @Test("segment — init segment has no mdat")
    func initSegmentNoMdat() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let boxes = try MP4BoxReader().readBoxes(
            from: result.initSegment
        )
        let mdat = boxes.first { $0.type == "mdat" }
        #expect(mdat == nil)
    }

    @Test("segment — each segment is parseable")
    func mediaSegmentsParseable() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        for segment in result.mediaSegments {
            let box = try MP4SegmentTestHelper.findBox(
                type: "moof", in: segment.data
            )
            #expect(box != nil)
        }
    }

    @Test("segment — each segment has moof + mdat")
    func mediaSegmentsStructure() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        for segment in result.mediaSegments {
            let moof = try MP4SegmentTestHelper.findBox(
                type: "moof", in: segment.data
            )
            let mdat = try MP4SegmentTestHelper.findBox(
                type: "mdat", in: segment.data
            )
            #expect(moof != nil)
            #expect(mdat != nil)
        }
    }

    // MARK: - Muxed Segmentation

    @Test("segment — A/V MP4 produces muxed segments")
    func avMuxedSegmentation() throws {
        let data = MP4TestDataBuilder.avMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        #expect(!result.initSegment.isEmpty)
        #expect(result.segmentCount > 0)
    }

    @Test("segment — video-only when includeAudio is false")
    func videoOnlyWhenAudioDisabled() throws {
        let data = MP4TestDataBuilder.avMP4WithData()
        var config = SegmentationConfig()
        config.includeAudio = false
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 0)
    }

    // MARK: - Duration

    @Test("segment — total duration approximates source")
    func totalDurationApproximate() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        // 90 samples * 3000 delta / 90000 timescale = 3.0s
        let expectedDuration = 3.0
        let tolerance = 0.1
        #expect(
            abs(result.totalDuration - expectedDuration)
                < tolerance
        )
    }

    // MARK: - Custom Config

    @Test("segment — custom target duration")
    func customTargetDuration() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.targetSegmentDuration = 1.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount >= 2)
    }

    @Test("segment — custom segment naming pattern")
    func customNamingPattern() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.segmentNamePattern = "media_%d.m4s"
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let first = try #require(result.mediaSegments.first)
        #expect(first.filename == "media_0.m4s")
    }

    // MARK: - Playlist

    @Test("segment — generates playlist by default")
    func generatesPlaylist() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        #expect(result.playlist != nil)
    }

    @Test("segment — no playlist when generatePlaylist false")
    func noPlaylistWhenDisabled() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.generatePlaylist = false
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.playlist == nil)
    }

    @Test("segment — playlist has correct target duration")
    func playlistTargetDuration() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let playlist = try #require(result.playlist)
        #expect(playlist.contains("#EXT-X-TARGETDURATION:"))
    }

    @Test("segment — playlist has EXT-X-MAP for init segment")
    func playlistHasMap() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let playlist = try #require(result.playlist)
        #expect(playlist.contains("#EXT-X-MAP:URI=\"init.mp4\""))
    }

    @Test("segment — playlist has EXTINF entries")
    func playlistHasExtinf() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let playlist = try #require(result.playlist)
        let extinfCount =
            playlist.components(
                separatedBy: "#EXTINF:"
            ).count - 1
        #expect(extinfCount == result.segmentCount)
    }

    @Test("segment — playlist has ENDLIST")
    func playlistHasEndlist() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let playlist = try #require(result.playlist)
        #expect(playlist.contains("#EXT-X-ENDLIST"))
    }

    @Test("segment — playlist version >= 7 for fMP4")
    func playlistVersion() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let playlist = try #require(result.playlist)
        #expect(playlist.contains("#EXT-X-VERSION:7"))
    }

    // MARK: - Segment Filename

    @Test("segmentFilename — replaces %d with index")
    func segmentFilenamePattern() {
        let segmenter = MP4Segmenter()
        let name = segmenter.segmentFilename(
            pattern: "segment_%d.m4s", index: 5
        )
        #expect(name == "segment_5.m4s")
    }

    @Test("segmentFilename — no placeholder returns pattern")
    func segmentFilenameNoPlaceholder() {
        let segmenter = MP4Segmenter()
        let name = segmenter.segmentFilename(
            pattern: "fixed.m4s", index: 0
        )
        #expect(name == "fixed.m4s")
    }

    // MARK: - FileInfo

    @Test("segment — fileInfo preserved in result")
    func fileInfoPreserved() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        #expect(result.fileInfo.timescale > 0)
        #expect(result.fileInfo.videoTrack != nil)
    }
}
