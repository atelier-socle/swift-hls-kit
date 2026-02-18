// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MediaSegmentCoverage")
struct MediaSegmentCoverageTests {

    // MARK: - Composition offsets (ctts → trun ct_offset)

    @Test("Segment with ctts produces trun with ct_offset")
    func cttsProducesCTOffset() throws {
        let data = buildMP4WithCtts()
        let segmenter = MP4Segmenter()
        var config = SegmentationConfig()
        config.targetSegmentDuration = 1.0
        let result = try segmenter.segment(
            data: data, config: config
        )

        #expect(result.segmentCount >= 1)
        let seg = try #require(result.mediaSegments.first)

        // Find trun in the segment
        let moofOpt = try MP4SegmentTestHelper.findBox(
            type: "moof", in: seg.data
        )
        let moof = try #require(moofOpt)
        let trafOpt = try MP4SegmentTestHelper.findChildBox(
            type: "traf", in: seg.data,
            parentOffset: moof.offset,
            parentSize: moof.size
        )
        let traf = try #require(trafOpt)
        let trunOpt = try MP4SegmentTestHelper.findChildBox(
            type: "trun", in: seg.data,
            parentOffset: traf.offset,
            parentSize: traf.size
        )
        let trun = try #require(trunOpt)

        // Check trun flags include 0x800 (ct_offset present)
        let flagsStart =
            seg.data.startIndex + trun.offset + 9
        let f1 = UInt32(seg.data[flagsStart])
        let f2 = UInt32(seg.data[flagsStart + 1])
        let f3 = UInt32(seg.data[flagsStart + 2])
        let flags = (f1 << 16) | (f2 << 8) | f3
        #expect(
            flags & 0x800 != 0,
            "trun should have ct_offset flag"
        )
    }

    @Test("Segment without ctts has no ct_offset flag")
    func noCttsMeansNoCTOffset() throws {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.targetSegmentDuration = 1.0
        let result = try MP4Segmenter().segment(
            data: data, config: config
        )

        let seg = try #require(result.mediaSegments.first)
        let moofOpt = try MP4SegmentTestHelper.findBox(
            type: "moof", in: seg.data
        )
        let moof = try #require(moofOpt)
        let trafOpt = try MP4SegmentTestHelper.findChildBox(
            type: "traf", in: seg.data,
            parentOffset: moof.offset,
            parentSize: moof.size
        )
        let traf = try #require(trafOpt)
        let trunOpt = try MP4SegmentTestHelper.findChildBox(
            type: "trun", in: seg.data,
            parentOffset: traf.offset,
            parentSize: traf.size
        )
        let trun = try #require(trunOpt)

        let flagsStart =
            seg.data.startIndex + trun.offset + 9
        let f1 = UInt32(seg.data[flagsStart])
        let f2 = UInt32(seg.data[flagsStart + 1])
        let f3 = UInt32(seg.data[flagsStart + 2])
        let flags = (f1 << 16) | (f2 << 8) | f3
        #expect(
            flags & 0x800 == 0,
            "trun should not have ct_offset flag"
        )
    }

    // MARK: - Audio-only segments (all samples are sync)

    @Test("Audio segment has no sample_flags in trun")
    func audioSegmentNoSampleFlags() throws {
        // Build audio analysis directly
        let data = MP4TestDataBuilder.avMP4WithData()
        let boxes = try MP4BoxReader().readBoxes(from: data)
        let infoParser = MP4InfoParser()
        let analyses = try infoParser.parseTrackAnalysis(
            from: boxes
        )
        let audio = try #require(
            analyses.first { $0.info.mediaType == .audio }
        )

        // Audio should have no sync samples table
        #expect(!audio.info.hasSyncSamples)

        // Generate a media segment for audio alone
        let audioSegs = audio.locator.calculateSegments(
            targetDuration: 6.0
        )
        guard let firstSeg = audioSegs.first else {
            return
        }

        let writer = MediaSegmentWriter()
        let segData = try writer.generateMediaSegment(
            segmentInfo: firstSeg,
            sequenceNumber: 1,
            trackAnalysis: audio,
            sourceData: data
        )

        // Parse the segment to verify structure
        let moofOpt = try MP4SegmentTestHelper.findBox(
            type: "moof", in: segData
        )
        let moof = try #require(moofOpt)
        let trafOpt = try MP4SegmentTestHelper.findChildBox(
            type: "traf", in: segData,
            parentOffset: moof.offset,
            parentSize: moof.size
        )
        let traf = try #require(trafOpt)
        let trunOpt = try MP4SegmentTestHelper.findChildBox(
            type: "trun", in: segData,
            parentOffset: traf.offset,
            parentSize: traf.size
        )
        let trun = try #require(trunOpt)

        // Verify flags do NOT include sample_flags (0x400)
        let flagsStart =
            segData.startIndex + trun.offset + 9
        let f1 = UInt32(segData[flagsStart])
        let f2 = UInt32(segData[flagsStart + 1])
        let f3 = UInt32(segData[flagsStart + 2])
        let flags = (f1 << 16) | (f2 << 8) | f3
        #expect(
            flags & 0x400 == 0,
            "Audio trun should not have sample-flags"
        )
    }

    // MARK: - patchInt32

    @Test("patchInt32 patches data correctly")
    func patchInt32Works() {
        let writer = MediaSegmentWriter()
        var data = Data(repeating: 0, count: 8)
        writer.patchInt32(in: &data, at: 2, value: 12345)
        var reader = BinaryReader(data: Data(data[2..<6]))
        let value = try? reader.readUInt32()
        #expect(
            value == UInt32(bitPattern: Int32(12345))
        )
    }

    @Test("patchInt32 handles negative values")
    func patchInt32Negative() {
        let writer = MediaSegmentWriter()
        var data = Data(repeating: 0, count: 4)
        writer.patchInt32(in: &data, at: 0, value: -1)
        #expect(data[0] == 0xFF)
        #expect(data[1] == 0xFF)
        #expect(data[2] == 0xFF)
        #expect(data[3] == 0xFF)
    }
}

// MARK: - Helpers

extension MediaSegmentCoverageTests {

    private func buildMP4WithCtts() -> Data {
        let videoSamples = 90
        let sampleDelta: UInt32 = 3000
        let sampleSize: UInt32 = 50
        let duration = UInt32(videoSamples) * sampleDelta
        let sizes = [UInt32](
            repeating: sampleSize, count: videoSamples
        )
        let syncSamples =
            MP4TestDataBuilder.buildSyncSamples(
                count: videoSamples, interval: 30
            )
        // All samples have a composition offset of 1500
        let cttsEntries:
            [(
                sampleCount: UInt32, sampleOffset: Int32
            )] = [
                (UInt32(videoSamples), 1500)
            ]
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
                stssSyncSamples: syncSamples,
                cttsEntries: cttsEntries
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
        stblBox: Data, duration: UInt32
    ) -> Data {
        let timescale: UInt32 = 90000
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
