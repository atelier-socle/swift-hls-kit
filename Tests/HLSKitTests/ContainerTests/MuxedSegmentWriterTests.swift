// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MediaSegmentWriter — Muxed")
struct MuxedSegmentWriterTests {

    // MARK: - Muxed Segments

    @Test("generateMuxedSegment — moof has two trafs")
    func muxedTwoTrafs() throws {
        let sourceData = MP4TestDataBuilder.avMP4WithData()
        let (videoAnalysis, audioAnalysis) =
            MP4SegmentTestHelper.makeAVAnalyses(sourceData: sourceData)
        let videoSegments = videoAnalysis.locator.calculateSegments(
            targetDuration: 2.0
        )
        let videoSeg = try #require(videoSegments.first)
        let audioSeg = audioAnalysis.locator.alignedAudioSegment(
            for: videoSeg, videoTimescale: 90000
        )
        let writer = MediaSegmentWriter()
        let data = try writer.generateMuxedSegment(
            video: MuxedTrackInput(
                segment: videoSeg, analysis: videoAnalysis
            ),
            audio: MuxedTrackInput(
                segment: audioSeg, analysis: audioAnalysis
            ),
            sequenceNumber: 1,
            sourceData: sourceData
        )
        let moof = try #require(
            try MP4SegmentTestHelper.findBox(type: "moof", in: data)
        )
        var trafCount = 0
        let childStart = moof.offset + 8
        let childEnd = moof.offset + moof.size
        var reader = BinaryReader(
            data: Data(data[childStart..<childEnd])
        )
        while reader.hasRemaining {
            let pos = reader.position
            let size = try reader.readUInt32()
            let boxType = try reader.readFourCC()
            if boxType == "traf" { trafCount += 1 }
            guard size >= 8 else { break }
            try reader.seek(to: pos + Int(size))
        }
        #expect(trafCount == 2)
    }

    @Test("generateMuxedSegment — produces styp + moof + mdat")
    func muxedStructure() throws {
        let sourceData = MP4TestDataBuilder.avMP4WithData()
        let (videoAnalysis, audioAnalysis) =
            MP4SegmentTestHelper.makeAVAnalyses(sourceData: sourceData)
        let videoSeg = SegmentInfo(
            firstSample: 0, sampleCount: 30,
            duration: 1.0, startDTS: 0, startPTS: 0,
            startsWithKeyframe: true
        )
        let audioSeg = audioAnalysis.locator.alignedAudioSegment(
            for: videoSeg, videoTimescale: 90000
        )
        let writer = MediaSegmentWriter()
        let data = try writer.generateMuxedSegment(
            video: MuxedTrackInput(
                segment: videoSeg, analysis: videoAnalysis
            ),
            audio: MuxedTrackInput(
                segment: audioSeg, analysis: audioAnalysis
            ),
            sequenceNumber: 1,
            sourceData: sourceData
        )
        let boxReader = MP4BoxReader()
        let boxes = try boxReader.readBoxes(from: data)
        let types = boxes.map(\.type)
        #expect(types.contains("styp"))
        #expect(types.contains("moof"))
        #expect(types.contains("mdat"))
    }

    @Test("generateMuxedSegment — mdat combines video and audio data")
    func muxedMdatCombined() throws {
        let sourceData = MP4TestDataBuilder.avMP4WithData()
        let (videoAnalysis, audioAnalysis) =
            MP4SegmentTestHelper.makeAVAnalyses(sourceData: sourceData)
        let videoSeg = SegmentInfo(
            firstSample: 0, sampleCount: 30,
            duration: 1.0, startDTS: 0, startPTS: 0,
            startsWithKeyframe: true
        )
        let audioSeg = audioAnalysis.locator.alignedAudioSegment(
            for: videoSeg, videoTimescale: 90000
        )
        let writer = MediaSegmentWriter()
        let data = try writer.generateMuxedSegment(
            video: MuxedTrackInput(
                segment: videoSeg, analysis: videoAnalysis
            ),
            audio: MuxedTrackInput(
                segment: audioSeg, analysis: audioAnalysis
            ),
            sequenceNumber: 1,
            sourceData: sourceData
        )
        let mdatBox = try #require(
            try MP4SegmentTestHelper.findBox(type: "mdat", in: data)
        )
        let payloadSize = mdatBox.size - 8
        let expectedVideoBytes = 30 * 100
        #expect(payloadSize >= expectedVideoBytes)
    }
}
