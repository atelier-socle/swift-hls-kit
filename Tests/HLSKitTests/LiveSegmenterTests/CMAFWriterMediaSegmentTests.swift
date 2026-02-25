// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("CMAFWriter — Media Segments", .timeLimit(.minutes(1)))
struct CMAFWriterMediaSegmentTests {

    let writer = CMAFWriter()

    // MARK: - Helpers

    private func readBoxes(
        from data: Data
    ) throws -> [MP4Box] {
        try MP4BoxReader().readBoxes(from: data)
    }

    private func findBox(
        _ type: String, in boxes: [MP4Box]
    ) -> MP4Box? {
        boxes.first { $0.type == type }
    }

    private func makeAudioFrames(
        count: Int
    ) -> [EncodedFrame] {
        let frameDuration = 1024.0 / 48000.0
        return (0..<count).map { i in
            EncodedFrame(
                data: Data(repeating: 0xAA, count: 256),
                timestamp: MediaTimestamp(
                    seconds: Double(i) * frameDuration
                ),
                duration: MediaTimestamp(
                    seconds: frameDuration
                ),
                isKeyframe: true,
                codec: .aac
            )
        }
    }

    // MARK: - Media Segment Structure

    @Test("Media segment has styp, moof, mdat")
    func mediaSegmentStructure() throws {
        let frames = makeAudioFrames(count: 5)
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)

        #expect(findBox("styp", in: boxes) != nil)
        #expect(findBox("moof", in: boxes) != nil)
        #expect(findBox("mdat", in: boxes) != nil)
    }

    @Test("Media segment styp has msdh brand")
    func mediaSegmentStypBrand() throws {
        let frames = makeAudioFrames(count: 3)
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        let styp = try #require(findBox("styp", in: boxes))
        let payload = try #require(styp.payload)
        let brand = String(
            data: payload.prefix(4),
            encoding: .ascii
        )
        #expect(brand == "msdh")
    }

    @Test("Media segment moof has mfhd and traf")
    func mediaSegmentMoofChildren() throws {
        let frames = makeAudioFrames(count: 3)
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 5,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(findBox("moof", in: boxes))

        #expect(moof.findChild("mfhd") != nil)
        #expect(moof.findChild("traf") != nil)
    }

    @Test("Media segment traf has tfhd, tfdt, trun")
    func mediaSegmentTrafChildren() throws {
        let frames = makeAudioFrames(count: 3)
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(findBox("moof", in: boxes))
        let traf = try #require(moof.findChild("traf"))

        #expect(traf.findChild("tfhd") != nil)
        #expect(traf.findChild("tfdt") != nil)
        #expect(traf.findChild("trun") != nil)
    }

    @Test("Media segment mfhd has correct sequence number")
    func mediaSegmentSequenceNumber() throws {
        let frames = makeAudioFrames(count: 2)
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 42,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(findBox("moof", in: boxes))
        let mfhd = try #require(moof.findChild("mfhd"))
        let payload = try #require(mfhd.payload)
        #expect(payload.count >= 8)
        let seqBytes = payload.suffix(4)
        let seqNum =
            UInt32(seqBytes[seqBytes.startIndex]) << 24
            | UInt32(seqBytes[seqBytes.startIndex + 1]) << 16
            | UInt32(seqBytes[seqBytes.startIndex + 2]) << 8
            | UInt32(seqBytes[seqBytes.startIndex + 3])
        #expect(seqNum == 42)
    }

    @Test("Media segment data_offset is correct")
    func mediaSegmentDataOffset() throws {
        let frames = makeAudioFrames(count: 3)
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(findBox("moof", in: boxes))
        let traf = try #require(moof.findChild("traf"))
        let trun = try #require(traf.findChild("trun"))
        let trunPayload = try #require(trun.payload)
        #expect(trunPayload.count >= 12)
        let offsetStart = trunPayload.startIndex + 8
        let dataOffset =
            Int32(trunPayload[offsetStart]) << 24
            | Int32(trunPayload[offsetStart + 1]) << 16
            | Int32(trunPayload[offsetStart + 2]) << 8
            | Int32(trunPayload[offsetStart + 3])
        let moofSize = Int32(moof.size)
        #expect(dataOffset == moofSize + 8)
    }

    @Test("Media segment with video frames has sample flags")
    func mediaSegmentVideoSampleFlags() throws {
        let frames = [
            EncodedFrame(
                data: Data(repeating: 0xBB, count: 1000),
                timestamp: MediaTimestamp(seconds: 0),
                duration: MediaTimestamp(seconds: 1.0 / 30),
                isKeyframe: true,
                codec: .h264
            ),
            EncodedFrame(
                data: Data(repeating: 0xBB, count: 500),
                timestamp: MediaTimestamp(seconds: 1.0 / 30),
                duration: MediaTimestamp(seconds: 1.0 / 30),
                isKeyframe: false,
                codec: .h264
            )
        ]
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 90000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(findBox("moof", in: boxes))
        let traf = try #require(moof.findChild("traf"))
        let trun = try #require(traf.findChild("trun"))
        let payload = try #require(trun.payload)
        let flagsByte2 = payload[payload.startIndex + 2]
        let flagsByte3 = payload[payload.startIndex + 3]
        let flags =
            UInt32(flagsByte2) << 8 | UInt32(flagsByte3)
        #expect(flags & 0x0400 != 0)
    }

    @Test("Media segment round-trips through MP4BoxReader")
    func mediaSegmentRoundTrip() throws {
        let frames = makeAudioFrames(count: 10)
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)

        #expect(boxes.count == 3)
        #expect(boxes[0].type == "styp")
        #expect(boxes[1].type == "moof")
        #expect(boxes[2].type == "mdat")
    }

    // MARK: - Partial Segment

    @Test("Partial segment has moof and mdat, no styp")
    func partialSegmentNoStyp() throws {
        let frames = makeAudioFrames(count: 2)
        let data = writer.generatePartialSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)

        #expect(findBox("styp", in: boxes) == nil)
        #expect(findBox("moof", in: boxes) != nil)
        #expect(findBox("mdat", in: boxes) != nil)
    }

    @Test("Partial segment moof has correct structure")
    func partialSegmentMoofStructure() throws {
        let frames = makeAudioFrames(count: 2)
        let data = writer.generatePartialSegment(
            frames: frames,
            sequenceNumber: 3,
            timescale: 48000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(findBox("moof", in: boxes))

        #expect(moof.findChild("mfhd") != nil)
        let traf = try #require(moof.findChild("traf"))
        #expect(traf.findChild("tfhd") != nil)
        #expect(traf.findChild("tfdt") != nil)
        #expect(traf.findChild("trun") != nil)
    }
}
