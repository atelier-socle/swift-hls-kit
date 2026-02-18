// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Segment Structure Verification")
struct SegmentStructureTests {

    private func segmentTestData() throws -> SegmentationResult {
        let data = MP4TestDataBuilder.segmentableMP4WithData()
        var config = SegmentationConfig()
        config.targetSegmentDuration = 1.0
        return try MP4Segmenter().segment(
            data: data, config: config
        )
    }

    // MARK: - Init Segment Structure

    @Test("Init segment: ftyp box present")
    func initSegmentHasFtyp() throws {
        let result = try segmentTestData()
        let boxes = try MP4BoxReader().readBoxes(
            from: result.initSegment
        )
        let ftyp = boxes.first { $0.type == "ftyp" }
        #expect(ftyp != nil)
    }

    @Test("Init segment: moov has zero-duration mvhd")
    func initSegmentMvhdZeroDuration() throws {
        let result = try segmentTestData()
        let boxes = try MP4BoxReader().readBoxes(
            from: result.initSegment
        )
        let moov = try #require(
            boxes.first { $0.type == "moov" }
        )
        let mvhd = try #require(moov.findChild("mvhd"))
        let payload = try #require(mvhd.payload)
        var reader = BinaryReader(data: payload)
        let version = try reader.readUInt8()
        try reader.skip(3)  // flags
        if version == 0 {
            try reader.skip(8)  // creation + modification
            _ = try reader.readUInt32()  // timescale
            let duration = try reader.readUInt32()
            #expect(duration == 0)
        }
    }

    @Test("Init segment: each trak has empty sample tables")
    func initSegmentEmptySampleTables() throws {
        let result = try segmentTestData()
        let boxes = try MP4BoxReader().readBoxes(
            from: result.initSegment
        )
        let moov = try #require(
            boxes.first { $0.type == "moov" }
        )
        let traks = moov.children.filter { $0.type == "trak" }
        #expect(!traks.isEmpty)
        for trak in traks {
            let mdia = try #require(trak.findChild("mdia"))
            let minf = try #require(mdia.findChild("minf"))
            let stbl = try #require(minf.findChild("stbl"))
            let stts = try #require(stbl.findChild("stts"))
            let sttsPayload = try #require(stts.payload)
            if sttsPayload.count >= 8 {
                var rdr = BinaryReader(data: sttsPayload)
                try rdr.skip(4)
                let entryCount = try rdr.readUInt32()
                #expect(entryCount == 0)
            }
        }
    }

    @Test("Init segment: mvex contains trex for each track")
    func initSegmentMvexTrex() throws {
        let result = try segmentTestData()
        let boxes = try MP4BoxReader().readBoxes(
            from: result.initSegment
        )
        let moov = try #require(
            boxes.first { $0.type == "moov" }
        )
        let mvex = try #require(moov.findChild("mvex"))
        let trexBoxes = mvex.children.filter {
            $0.type == "trex"
        }
        let traks = moov.children.filter {
            $0.type == "trak"
        }
        #expect(trexBoxes.count == traks.count)
    }

    @Test("Init segment: stsd preserved from source")
    func initSegmentStsdPreserved() throws {
        let result = try segmentTestData()
        let boxes = try MP4BoxReader().readBoxes(
            from: result.initSegment
        )
        let moov = try #require(
            boxes.first { $0.type == "moov" }
        )
        let trak = try #require(
            moov.children.first { $0.type == "trak" }
        )
        let mdia = try #require(trak.findChild("mdia"))
        let minf = try #require(mdia.findChild("minf"))
        let stbl = try #require(minf.findChild("stbl"))
        let stsd = stbl.findChild("stsd")
        #expect(stsd != nil)
    }

    // MARK: - Media Segment Structure

    @Test("Media segment: styp brands are correct")
    func mediaSegmentStypBrands() throws {
        let result = try segmentTestData()
        let seg = try #require(result.mediaSegments.first)
        let stypOpt = try MP4SegmentTestHelper.findBox(
            type: "styp", in: seg.data
        )
        let styp = try #require(stypOpt)
        let payloadStart =
            seg.data.startIndex + styp.offset + 8
        let payloadEnd =
            seg.data.startIndex + styp.offset + styp.size
        let payload = Data(
            seg.data[payloadStart..<payloadEnd]
        )
        var reader = BinaryReader(data: payload)
        let majorBrand = try reader.readFourCC()
        #expect(majorBrand == "msdh")
    }

    @Test("Media segment: mfhd sequence numbers increment")
    func mediaSegmentSequenceNumbers() throws {
        let result = try segmentTestData()
        #expect(result.segmentCount >= 2)
        for (index, seg) in result.mediaSegments.enumerated() {
            let moofOpt = try MP4SegmentTestHelper.findBox(
                type: "moof", in: seg.data
            )
            let moof = try #require(moofOpt)
            let mfhdOpt = try MP4SegmentTestHelper.findChildBox(
                type: "mfhd", in: seg.data,
                parentOffset: moof.offset,
                parentSize: moof.size
            )
            let mfhd = try #require(mfhdOpt)
            let seqOffset =
                seg.data.startIndex + mfhd.offset + 12
            var reader = BinaryReader(
                data: Data(
                    seg.data[seqOffset..<(seqOffset + 4)]
                )
            )
            let seqNum = try reader.readUInt32()
            #expect(seqNum == UInt32(index + 1))
        }
    }

    @Test("Media segment: tfhd has default-base-is-moof")
    func mediaSegmentTfhdFlags() throws {
        let result = try segmentTestData()
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
        let tfhdOpt = try MP4SegmentTestHelper.findChildBox(
            type: "tfhd", in: seg.data,
            parentOffset: traf.offset,
            parentSize: traf.size
        )
        let tfhd = try #require(tfhdOpt)
        // tfhd: size(4) + type(4) + version(1) + flags(3)
        let flagsStart =
            seg.data.startIndex + tfhd.offset + 9
        let f1 = UInt32(seg.data[flagsStart])
        let f2 = UInt32(seg.data[flagsStart + 1])
        let f3 = UInt32(seg.data[flagsStart + 2])
        let flags = (f1 << 16) | (f2 << 8) | f3
        #expect(flags & 0x020000 != 0)
    }

    @Test("Media segment: tfdt baseMediaDecodeTime correct")
    func mediaSegmentTfdtCorrect() throws {
        let result = try segmentTestData()
        let firstSeg = try #require(
            result.mediaSegments.first
        )
        let moofOpt = try MP4SegmentTestHelper.findBox(
            type: "moof", in: firstSeg.data
        )
        let moof = try #require(moofOpt)
        let trafOpt = try MP4SegmentTestHelper.findChildBox(
            type: "traf", in: firstSeg.data,
            parentOffset: moof.offset,
            parentSize: moof.size
        )
        let traf = try #require(trafOpt)
        let tfdtOpt = try MP4SegmentTestHelper.findChildBox(
            type: "tfdt", in: firstSeg.data,
            parentOffset: traf.offset,
            parentSize: traf.size
        )
        let tfdt = try #require(tfdtOpt)
        // tfdt v1: header(8) + version(1) + flags(3) + time(8)
        let timeStart =
            firstSeg.data.startIndex + tfdt.offset + 12
        var reader = BinaryReader(
            data: Data(
                firstSeg.data[timeStart..<(timeStart + 8)]
            )
        )
        let baseTime = try reader.readUInt64()
        #expect(baseTime == 0)
    }

    @Test("Media segment: trun sample count matches")
    func mediaSegmentTrunSampleCount() throws {
        let result = try segmentTestData()
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
        // trun: header(8) + version(1) + flags(3) + count(4)
        let countStart =
            seg.data.startIndex + trun.offset + 12
        var reader = BinaryReader(
            data: Data(
                seg.data[countStart..<(countStart + 4)]
            )
        )
        let sampleCount = try reader.readUInt32()
        // First segment with 1s target and 30fps = 30 samples
        #expect(sampleCount == 30)
    }

    @Test("Media segment: mdat has data")
    func mediaSegmentMdatHasData() throws {
        let result = try segmentTestData()
        for seg in result.mediaSegments {
            let mdatOpt = try MP4SegmentTestHelper.findBox(
                type: "mdat", in: seg.data
            )
            let mdat = try #require(mdatOpt)
            let mdatPayloadSize = mdat.size - 8
            #expect(mdatPayloadSize > 0)
        }
    }

    @Test("Media segment: first sample has keyframe flags")
    func mediaSegmentKeyframeFlags() throws {
        let result = try segmentTestData()
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
        // trun: header(8) + v/f(4) + count(4) + offset(4) +
        // first sample: duration(4) + size(4) + flags(4)
        let flagsStart =
            seg.data.startIndex + trun.offset + 28
        guard flagsStart + 4 <= seg.data.endIndex else {
            return
        }
        var reader = BinaryReader(
            data: Data(
                seg.data[flagsStart..<(flagsStart + 4)]
            )
        )
        let sampleFlags = try reader.readUInt32()
        // sync sample = 0x02000000
        #expect(
            sampleFlags
                == MediaSegmentWriter.SampleFlags.syncSample
        )
    }
}
