// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("CMAFWriter Edge Cases", .timeLimit(.minutes(1)))
struct CMAFWriterEdgeCaseTests {

    let writer = CMAFWriter()

    // MARK: - Helpers

    private func readBoxes(from data: Data) throws -> [MP4Box] {
        try MP4BoxReader().readBoxes(from: data)
    }

    // MARK: - Media Segment Edge Cases

    @Test("Empty frames array produces valid segment")
    func emptyFramesSegment() throws {
        let data = writer.generateMediaSegment(
            frames: [],
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes[0].type == "styp")
        #expect(boxes[1].type == "moof")
        #expect(boxes[2].type == "mdat")
    }

    @Test("Single frame produces valid media segment")
    func singleFrameSegment() throws {
        let frame = EncodedFrameFactory.audioFrame(
            timestamp: 0.0
        )
        let data = writer.generateMediaSegment(
            frames: [frame],
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes.count == 3)
        let mdat = try #require(boxes.last)
        // mdat size = 8 (header) + frame data
        #expect(mdat.size == frame.data.count + 8)
    }

    @Test("Large frame data (1MB) produces valid segment")
    func largeFrameSegment() throws {
        let frame = EncodedFrameFactory.audioFrame(
            timestamp: 0.0, dataSize: 1_048_576
        )
        let data = writer.generateMediaSegment(
            frames: [frame],
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes.count == 3)
        let mdat = try #require(boxes.last)
        // mdat size = 8 (header) + 1MB
        #expect(mdat.size == 1_048_576 + 8)
    }

    // MARK: - Audio Config Variations

    @Test("HE-AAC profile → correct AudioSpecificConfig")
    func heAACProfile() {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .he
        )
        let asc = writer.buildAudioSpecificConfig(
            config: config
        )
        #expect(asc.count == 2)
        // objectType=5 for HE-AAC
        #expect(asc[0] == 0x29)
    }

    @Test("HE-AAC v2 profile → correct AudioSpecificConfig")
    func heAACv2Profile() {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .heV2
        )
        let asc = writer.buildAudioSpecificConfig(
            config: config
        )
        #expect(asc.count == 2)
    }

    @Test("Mono audio → correct channel config")
    func monoAudio() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 1, profile: .lc
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes.count == 2)
    }

    @Test("44100 Hz sample rate → correct init segment")
    func sampleRate44100() throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 44100, channels: 2
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes.count == 2)
        #expect(config.timescale == 44100)
    }

    @Test("22050 Hz sample rate → correct index")
    func sampleRate22050() {
        #expect(writer.sampleRateIndex(for: 22050) == 7)
    }

    // MARK: - Video Edge Cases

    @Test("Video init with minimal SPS/PPS")
    func videoInitMinimalSPS() throws {
        let config = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 320, height: 240,
            sps: Data([0x67]),
            pps: Data([0x68])
        )
        let data = writer.generateVideoInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes.count == 2)
        #expect(boxes[0].type == "ftyp")
        #expect(boxes[1].type == "moov")
    }

    // MARK: - Partial Segment

    @Test("Partial segment has no styp")
    func partialSegmentNoStyp() throws {
        let frame = EncodedFrameFactory.audioFrame(
            timestamp: 0.0
        )
        let data = writer.generatePartialSegment(
            frames: [frame],
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes.count == 2)
        #expect(boxes[0].type == "moof")
        #expect(boxes[1].type == "mdat")
    }

    // MARK: - Sequence Number

    @Test("Sequence number UInt32.max → no crash")
    func sequenceNumberMax() throws {
        let frame = EncodedFrameFactory.audioFrame(
            timestamp: 0.0
        )
        let data = writer.generateMediaSegment(
            frames: [frame],
            sequenceNumber: UInt32.max,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes.count == 3)
    }

    // MARK: - Zero Duration Frames

    @Test("Zero-duration frames produce valid segment")
    func zeroDurationFrames() throws {
        let frames = (0..<3).map { _ in
            EncodedFrame(
                data: Data(repeating: 0xCC, count: 64),
                timestamp: MediaTimestamp(seconds: 0),
                duration: MediaTimestamp(seconds: 0),
                isKeyframe: true,
                codec: .aac
            )
        }
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes.count == 3)
    }

    // MARK: - Video with sample flags

    @Test("Video frames have correct moof structure")
    func videoSampleFlags() throws {
        let frames = [
            EncodedFrameFactory.videoFrame(
                timestamp: 0.0, isKeyframe: true
            ),
            EncodedFrameFactory.videoFrame(
                timestamp: 1.0 / 30.0, isKeyframe: false
            ),
            EncodedFrameFactory.videoFrame(
                timestamp: 2.0 / 30.0, isKeyframe: false
            )
        ]
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 90000
        )
        let boxes = try readBoxes(from: data)
        #expect(boxes[1].type == "moof")
    }
}
