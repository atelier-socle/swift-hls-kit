// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MediaSegmentWriter")
struct MediaSegmentWriterTests {

    // MARK: - Helpers

    private func makeVideoAnalysis(
        sourceData: Data
    ) -> (analysis: MP4TrackAnalysis, segments: [SegmentInfo]) {
        let info = TrackInfo(
            trackId: 1,
            mediaType: .video,
            timescale: 90000,
            duration: 270000,
            codec: "avc1",
            dimensions: VideoDimensions(width: 1920, height: 1080),
            language: "und",
            sampleDescriptionData: Data(),
            hasSyncSamples: true
        )
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 90, sampleDelta: 3000
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 90,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [UInt32](repeating: 100, count: 90),
            uniformSampleSize: 0,
            chunkOffsets: [
                UInt64(
                    MP4SegmentTestHelper.mdatPayloadOffset(
                        in: sourceData
                    )
                )
            ],
            syncSamples: [1, 31, 61]
        )
        let analysis = MP4TrackAnalysis(
            info: info, sampleTable: table
        )
        let segments = analysis.locator.calculateSegments(
            targetDuration: 2.0
        )
        return (analysis, segments)
    }

    // MARK: - Structure

    @Test("generateMediaSegment — produces styp + moof + mdat")
    func singleTrackStructure() throws {
        let sourceData = MP4TestDataBuilder.segmentableMP4WithData()
        let (analysis, segments) = makeVideoAnalysis(
            sourceData: sourceData
        )
        let segment = try #require(segments.first)
        let writer = MediaSegmentWriter()
        let data = try writer.generateMediaSegment(
            segmentInfo: segment,
            sequenceNumber: 1,
            trackAnalysis: analysis,
            sourceData: sourceData
        )
        let styp = try MP4SegmentTestHelper.findBox(
            type: "styp", in: data
        )
        let moof = try MP4SegmentTestHelper.findBox(
            type: "moof", in: data
        )
        let mdat = try MP4SegmentTestHelper.findBox(
            type: "mdat", in: data
        )
        #expect(styp != nil)
        #expect(moof != nil)
        #expect(mdat != nil)
    }

    @Test("generateMediaSegment — styp comes first")
    func stypFirst() throws {
        let sourceData = MP4TestDataBuilder.segmentableMP4WithData()
        let (analysis, segments) = makeVideoAnalysis(
            sourceData: sourceData
        )
        let segment = try #require(segments.first)
        let writer = MediaSegmentWriter()
        let data = try writer.generateMediaSegment(
            segmentInfo: segment,
            sequenceNumber: 1,
            trackAnalysis: analysis,
            sourceData: sourceData
        )
        let stypBox = try #require(
            try MP4SegmentTestHelper.findBox(type: "styp", in: data)
        )
        #expect(stypBox.offset == 0)
    }

    @Test("generateMediaSegment — moof contains mfhd")
    func moofHasMfhd() throws {
        let sourceData = MP4TestDataBuilder.segmentableMP4WithData()
        let (analysis, segments) = makeVideoAnalysis(
            sourceData: sourceData
        )
        let segment = try #require(segments.first)
        let writer = MediaSegmentWriter()
        let data = try writer.generateMediaSegment(
            segmentInfo: segment,
            sequenceNumber: 1,
            trackAnalysis: analysis,
            sourceData: sourceData
        )
        let moof = try #require(
            try MP4SegmentTestHelper.findBox(type: "moof", in: data)
        )
        let mfhd = try MP4SegmentTestHelper.findChildBox(
            type: "mfhd", in: data,
            parentOffset: moof.offset, parentSize: moof.size
        )
        #expect(mfhd != nil)
    }

    @Test("generateMediaSegment — moof contains traf")
    func moofHasTraf() throws {
        let sourceData = MP4TestDataBuilder.segmentableMP4WithData()
        let (analysis, segments) = makeVideoAnalysis(
            sourceData: sourceData
        )
        let segment = try #require(segments.first)
        let writer = MediaSegmentWriter()
        let data = try writer.generateMediaSegment(
            segmentInfo: segment,
            sequenceNumber: 1,
            trackAnalysis: analysis,
            sourceData: sourceData
        )
        let moof = try #require(
            try MP4SegmentTestHelper.findBox(type: "moof", in: data)
        )
        let traf = try MP4SegmentTestHelper.findChildBox(
            type: "traf", in: data,
            parentOffset: moof.offset, parentSize: moof.size
        )
        #expect(traf != nil)
    }

    // MARK: - Content Verification

    @Test("generateMediaSegment — mfhd has correct sequence number")
    func mfhdSequenceNumber() throws {
        let sourceData = MP4TestDataBuilder.segmentableMP4WithData()
        let (analysis, segments) = makeVideoAnalysis(
            sourceData: sourceData
        )
        let segment = try #require(segments.first)
        let writer = MediaSegmentWriter()
        let data = try writer.generateMediaSegment(
            segmentInfo: segment,
            sequenceNumber: 42,
            trackAnalysis: analysis,
            sourceData: sourceData
        )
        let moof = try #require(
            try MP4SegmentTestHelper.findBox(type: "moof", in: data)
        )
        let mfhd = try #require(
            try MP4SegmentTestHelper.findChildBox(
                type: "mfhd", in: data,
                parentOffset: moof.offset, parentSize: moof.size
            )
        )
        let seqOffset = mfhd.offset + 12
        var reader = BinaryReader(
            data: Data(data[seqOffset..<(mfhd.offset + mfhd.size)])
        )
        let seqNum = try reader.readUInt32()
        #expect(seqNum == 42)
    }

    @Test("generateMediaSegment — mdat contains sample data")
    func mdatHasSampleData() throws {
        let sourceData = MP4TestDataBuilder.segmentableMP4WithData(
            videoSamples: 30,
            keyframeInterval: 30,
            sampleSize: 10
        )
        let (analysis, segments) = makeVideoAnalysis(
            sourceData: sourceData
        )
        let segment = try #require(segments.first)
        let writer = MediaSegmentWriter()
        let data = try writer.generateMediaSegment(
            segmentInfo: segment,
            sequenceNumber: 1,
            trackAnalysis: analysis,
            sourceData: sourceData
        )
        let mdatBox = try #require(
            try MP4SegmentTestHelper.findBox(type: "mdat", in: data)
        )
        let payloadSize = mdatBox.size - 8
        #expect(payloadSize > 0)
    }

    @Test("generateMediaSegment — parseable by MP4BoxReader")
    func parseableByReader() throws {
        let sourceData = MP4TestDataBuilder.segmentableMP4WithData()
        let (analysis, segments) = makeVideoAnalysis(
            sourceData: sourceData
        )
        let segment = try #require(segments.first)
        let writer = MediaSegmentWriter()
        let data = try writer.generateMediaSegment(
            segmentInfo: segment,
            sequenceNumber: 1,
            trackAnalysis: analysis,
            sourceData: sourceData
        )
        let boxReader = MP4BoxReader()
        let boxes = try boxReader.readBoxes(from: data)
        let types = boxes.map(\.type)
        #expect(types.contains("styp"))
        #expect(types.contains("moof"))
        #expect(types.contains("mdat"))
    }

    @Test("generateMediaSegment — traf has tfhd, tfdt, trun")
    func trafChildren() throws {
        let sourceData = MP4TestDataBuilder.segmentableMP4WithData()
        let (analysis, segments) = makeVideoAnalysis(
            sourceData: sourceData
        )
        let segment = try #require(segments.first)
        let writer = MediaSegmentWriter()
        let data = try writer.generateMediaSegment(
            segmentInfo: segment,
            sequenceNumber: 1,
            trackAnalysis: analysis,
            sourceData: sourceData
        )
        let moof = try #require(
            try MP4SegmentTestHelper.findBox(type: "moof", in: data)
        )
        let traf = try #require(
            try MP4SegmentTestHelper.findChildBox(
                type: "traf", in: data,
                parentOffset: moof.offset, parentSize: moof.size
            )
        )
        let tfhd = try MP4SegmentTestHelper.findChildBox(
            type: "tfhd", in: data,
            parentOffset: traf.offset, parentSize: traf.size
        )
        let tfdt = try MP4SegmentTestHelper.findChildBox(
            type: "tfdt", in: data,
            parentOffset: traf.offset, parentSize: traf.size
        )
        let trun = try MP4SegmentTestHelper.findChildBox(
            type: "trun", in: data,
            parentOffset: traf.offset, parentSize: traf.size
        )
        #expect(tfhd != nil)
        #expect(tfdt != nil)
        #expect(trun != nil)
    }
}
