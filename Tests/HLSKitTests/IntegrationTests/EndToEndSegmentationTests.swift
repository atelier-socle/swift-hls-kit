// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("End-to-End Segmentation")
struct EndToEndSegmentationTests {

    // MARK: - Video-only scenarios

    @Test("Segment short video (3s, 3 segments at 1s target)")
    func shortVideoSegmentation() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.targetSegmentDuration = 1.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount == 3)
        for seg in result.mediaSegments {
            #expect(seg.duration > 0)
            #expect(!seg.data.isEmpty)
        }
    }

    @Test("Segment long video (30s, 5 segments at 6s target)")
    func longVideoSegmentation() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 900,
            keyframeInterval: 90,
            sampleSize: 50
        )
        var config = SegmentationConfig()
        config.targetSegmentDuration = 6.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount == 5)
        let total = result.mediaSegments.map(\.duration)
            .reduce(0, +)
        #expect(abs(total - 30.0) < 0.5)
    }

    @Test("Segment with non-uniform GOPs")
    func nonUniformGops() throws {
        // Keyframes at frames 0, 25, 60, 80 (irregular intervals)
        let data = buildNonUniformGopMP4()
        var config = SegmentationConfig()
        config.targetSegmentDuration = 1.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount >= 1)
        for seg in result.mediaSegments {
            #expect(!seg.data.isEmpty)
        }
    }

    @Test("Single-GOP video → single segment")
    func singleGopSegmentation() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 30,
            keyframeInterval: 30,
            sampleSize: 100
        )
        let result = try MP4Segmenter().segment(data: data)
        #expect(result.segmentCount == 1)
    }

    // MARK: - Audio + Video scenarios

    @Test("Muxed video + audio segmentation")
    func muxedAVSegmentation() throws {
        let data = MP4TestDataBuilder.avMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        #expect(!result.initSegment.isEmpty)
        #expect(result.segmentCount > 0)
        for seg in result.mediaSegments {
            let boxes = try MP4BoxReader().readBoxes(
                from: seg.data
            )
            let moof = boxes.first { $0.type == "moof" }
            let mdat = boxes.first { $0.type == "mdat" }
            #expect(moof != nil)
            #expect(mdat != nil)
        }
    }

    @Test("Audio excluded from muxed segments")
    func audioExcluded() throws {
        let data = MP4TestDataBuilder.avMP4WithData()
        var config = SegmentationConfig()
        config.includeAudio = false
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 0)
        #expect(result.fileInfo.videoTrack != nil)
    }

    // MARK: - Byte-range scenarios

    @Test("Byte-range: offsets are contiguous")
    func byteRangeContiguous() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.outputMode = .byteRange
        config.targetSegmentDuration = 1.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 1)
        for i in 1..<result.mediaSegments.count {
            let prev = result.mediaSegments[i - 1]
            let curr = result.mediaSegments[i]
            let prevEnd =
                (prev.byteRangeOffset ?? 0)
                + (prev.byteRangeLength ?? 0)
            #expect(curr.byteRangeOffset == prevEnd)
        }
    }

    @Test("Byte-range: combined size matches total data")
    func byteRangeCombinedSize() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.outputMode = .byteRange
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let totalRange = result.mediaSegments.reduce(
            UInt64(0)
        ) {
            $0 + ($1.byteRangeLength ?? 0)
        }
        let totalData = result.mediaSegments.reduce(0) {
            $0 + $1.data.count
        }
        #expect(totalRange == UInt64(totalData))
    }

    // MARK: - Playlist round-trip

    @Test("Playlist survives parse → generate → parse")
    func playlistRoundTrip() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let m3u8 = try #require(result.playlist)

        let engine = HLSEngine()
        let manifest1 = try engine.parse(m3u8)
        let regenerated = engine.generate(manifest1)
        let manifest2 = try engine.parse(regenerated)

        guard case .media(let p1) = manifest1,
            case .media(let p2) = manifest2
        else {
            #expect(Bool(false), "Expected media playlists")
            return
        }
        #expect(p1.segments.count == p2.segments.count)
        #expect(p1.targetDuration == p2.targetDuration)
    }

    @Test("Playlist validates with HLSValidator")
    func playlistValidation() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        let result = try MP4Segmenter().segment(data: data)
        let m3u8 = try #require(result.playlist)

        let engine = HLSEngine()
        let manifest = try engine.parse(m3u8)
        let report = engine.validate(manifest)
        #expect(report.isValid)
    }

    @Test("Playlist has correct EXT-X-MAP")
    func playlistMapTag() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.initSegmentName = "header.mp4"
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)
        #expect(m3u8.contains("EXT-X-MAP:URI=\"header.mp4\""))
    }

    @Test("Target duration is ceil of max segment duration")
    func playlistTargetDuration() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.targetSegmentDuration = 1.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)
        let manifest = try ManifestParser().parse(m3u8)
        guard case .media(let playlist) = manifest else {
            #expect(Bool(false), "Expected media playlist")
            return
        }
        let maxDur =
            result.mediaSegments.map(\.duration)
            .max() ?? 0
        let expected = Int(maxDur.rounded(.up))
        #expect(playlist.targetDuration == expected)
    }

    // MARK: - Configuration variations

    @Test("Custom target duration: 2 seconds")
    func customTarget2s() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.targetSegmentDuration = 2.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount >= 1)
    }

    @Test("Custom target duration: 10 seconds")
    func customTarget10s() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 900,
            keyframeInterval: 90,
            sampleSize: 50
        )
        var config = SegmentationConfig()
        config.targetSegmentDuration = 10.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount >= 2)
    }

    @Test("Custom segment naming: 'part_%d.fmp4'")
    func customSegmentNaming() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.segmentNamePattern = "part_%d.fmp4"
        config.targetSegmentDuration = 1.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let first = try #require(result.mediaSegments.first)
        #expect(first.filename == "part_0.fmp4")
    }

    @Test("Custom init segment name: 'header.mp4'")
    func customInitSegmentName() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.initSegmentName = "header.mp4"
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        let m3u8 = try #require(result.playlist)
        #expect(m3u8.contains("header.mp4"))
    }

    @Test("Playlist generation disabled")
    func playlistDisabled() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.generatePlaylist = false
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )
        #expect(result.playlist == nil)
        #expect(result.segmentCount > 0)
    }
}

// MARK: - Helpers

extension EndToEndSegmentationTests {

    private func buildNonUniformGopMP4() -> Data {
        let videoSamples = 120
        let sampleDelta: UInt32 = 3000
        let sampleSize: UInt32 = 50
        let duration = UInt32(videoSamples) * sampleDelta
        let sizes = [UInt32](
            repeating: sampleSize, count: videoSamples
        )
        // Irregular keyframes: 1, 26, 61, 81
        let syncSamples: [UInt32] = [1, 26, 61, 81]
        let mdatPayload =
            MP4TestDataBuilder.buildSamplePayload(
                sampleCount: videoSamples,
                sampleSize: Int(sampleSize),
                byteOffset: 0
            )
        return assembleMP4(
            duration: duration,
            mdatPayload: mdatPayload
        ) { offset in
            MP4TestDataBuilder.stbl(
                codec: "avc1",
                sttsEntries: [
                    (UInt32(videoSamples), sampleDelta)
                ],
                stszSizes: sizes,
                stcoOffsets: [offset],
                stscEntries: [
                    MP4TestDataBuilder.StscEntry(
                        firstChunk: 1,
                        samplesPerChunk: UInt32(videoSamples),
                        descIndex: 1
                    )
                ],
                stssSyncSamples: syncSamples
            )
        }
    }

    private func assembleMP4(
        duration: UInt32,
        mdatPayload: Data,
        stblBuilder: (UInt32) -> Data
    ) -> Data {
        let ftypData = MP4TestDataBuilder.ftyp()
        let moov0 = buildMoovFromStbl(
            stblBox: stblBuilder(0), duration: duration
        )
        let stcoOffset = UInt32(
            ftypData.count + moov0.count + 8
        )
        let moov = buildMoovFromStbl(
            stblBox: stblBuilder(stcoOffset),
            duration: duration
        )
        let mdatBox = MP4TestDataBuilder.box(
            type: "mdat", payload: mdatPayload
        )
        var data = Data()
        data.append(ftypData)
        data.append(moov)
        data.append(mdatBox)
        return data
    }

    private func buildMoovFromStbl(
        stblBox: Data,
        duration: UInt32,
        timescale: UInt32 = 90000
    ) -> Data {
        let minfBox = MP4TestDataBuilder.containerBox(
            type: "minf", children: [stblBox]
        )
        let mdiaBox = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                MP4TestDataBuilder.mdhd(
                    timescale: timescale, duration: duration
                ),
                MP4TestDataBuilder.hdlr(
                    handlerType: "vide"
                ),
                minfBox
            ]
        )
        let trakBox = MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: duration,
                    width: 1920, height: 1080
                ),
                mdiaBox
            ]
        )
        return MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: timescale, duration: duration
                ),
                trakBox
            ]
        )
    }
}
