// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("InitSegmentWriter")
struct InitSegmentWriterTests {

    // MARK: - Helpers

    private func makeVideoTrackInfo() -> TrackInfo {
        TrackInfo(
            trackId: 1,
            mediaType: .video,
            timescale: 90000,
            duration: 270000,
            codec: "avc1",
            dimensions: VideoDimensions(width: 1920, height: 1080),
            language: "und",
            sampleDescriptionData: makeFakeStsdPayload(),
            hasSyncSamples: true
        )
    }

    private func makeAudioTrackInfo() -> TrackInfo {
        TrackInfo(
            trackId: 2,
            mediaType: .audio,
            timescale: 44100,
            duration: 441000,
            codec: "mp4a",
            dimensions: nil,
            language: "eng",
            sampleDescriptionData: makeFakeStsdPayload(),
            hasSyncSamples: false
        )
    }

    private func makeFakeStsdPayload() -> Data {
        // Minimal stsd payload: version(1)+flags(3)+entry_count(4)
        var data = Data()
        data.appendUInt32(0)  // version + flags
        data.appendUInt32(1)  // entry count
        return data
    }

    private func makeVideoAnalysis() -> MP4TrackAnalysis {
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
            chunkOffsets: [0],
            syncSamples: [1, 31, 61]
        )
        return MP4TrackAnalysis(
            info: makeVideoTrackInfo(), sampleTable: table
        )
    }

    private func makeAudioAnalysis() -> MP4TrackAnalysis {
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 430, sampleDelta: 1024
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [
                SampleToChunkEntry(
                    firstChunk: 1, samplesPerChunk: 430,
                    sampleDescriptionIndex: 1
                )
            ],
            sampleSizes: [],
            uniformSampleSize: 50,
            chunkOffsets: [9000],
            syncSamples: nil
        )
        return MP4TrackAnalysis(
            info: makeAudioTrackInfo(), sampleTable: table
        )
    }

    private func makeFileInfo() -> MP4FileInfo {
        MP4FileInfo(
            timescale: 90000,
            duration: 270000,
            brands: ["isom", "iso6"],
            tracks: [makeVideoTrackInfo()]
        )
    }

    private func makeAVFileInfo() -> MP4FileInfo {
        MP4FileInfo(
            timescale: 90000,
            duration: 270000,
            brands: ["isom", "iso6"],
            tracks: [makeVideoTrackInfo(), makeAudioTrackInfo()]
        )
    }
}

// MARK: - Box Discovery

extension InitSegmentWriterTests {

    /// Find a top-level box by type in serialized data.
    private func findBox(
        type: String, in data: Data
    ) throws -> (offset: Int, size: Int)? {
        var reader = BinaryReader(data: data)
        while reader.hasRemaining {
            let offset = reader.position
            let size = try reader.readUInt32()
            let boxType = try reader.readFourCC()
            if boxType == type {
                return (offset: offset, size: Int(size))
            }
            guard size >= 8 else { return nil }
            try reader.seek(to: offset + Int(size))
        }
        return nil
    }

    /// Find a child box inside a parent box range.
    private func findChildBox(
        type: String, in data: Data,
        parentOffset: Int, parentSize: Int
    ) throws -> (offset: Int, size: Int)? {
        let headerSize = 8
        let childStart = parentOffset + headerSize
        let childEnd = parentOffset + parentSize
        guard childEnd <= data.count else { return nil }
        let childData = data[childStart..<childEnd]
        var reader = BinaryReader(data: Data(childData))
        while reader.hasRemaining {
            let localOffset = reader.position
            let size = try reader.readUInt32()
            let boxType = try reader.readFourCC()
            if boxType == type {
                return (
                    offset: childStart + localOffset,
                    size: Int(size)
                )
            }
            guard size >= 8 else { return nil }
            try reader.seek(to: localOffset + Int(size))
        }
        return nil
    }
}

// MARK: - Generation Tests

extension InitSegmentWriterTests {

    @Test("generateInitSegment — video only produces ftyp + moov")
    func videoOnlyStructure() throws {
        let writer = InitSegmentWriter()
        let data = try writer.generateInitSegment(
            fileInfo: makeFileInfo(),
            trackAnalyses: [makeVideoAnalysis()]
        )
        let ftyp = try findBox(type: "ftyp", in: data)
        let moov = try findBox(type: "moov", in: data)
        #expect(ftyp != nil)
        #expect(moov != nil)
        // ftyp comes first
        let ftypBox = try #require(ftyp)
        let moovBox = try #require(moov)
        #expect(ftypBox.offset == 0)
        #expect(moovBox.offset == ftypBox.size)
    }

    @Test("generateInitSegment — ftyp has isom brand")
    func ftypBrands() throws {
        let writer = InitSegmentWriter()
        let data = try writer.generateInitSegment(
            fileInfo: makeFileInfo(),
            trackAnalyses: [makeVideoAnalysis()]
        )
        let ftypBox = try #require(try findBox(type: "ftyp", in: data))
        let start = data.startIndex + ftypBox.offset + 8
        var reader = BinaryReader(
            data: Data(data[start..<(start + ftypBox.size - 8)])
        )
        let majorBrand = try reader.readFourCC()
        #expect(majorBrand == "isom")
    }

    @Test("generateInitSegment — moov contains mvhd")
    func moovHasMvhd() throws {
        let writer = InitSegmentWriter()
        let data = try writer.generateInitSegment(
            fileInfo: makeFileInfo(),
            trackAnalyses: [makeVideoAnalysis()]
        )
        let moov = try #require(try findBox(type: "moov", in: data))
        let mvhd = try findChildBox(
            type: "mvhd", in: data,
            parentOffset: moov.offset, parentSize: moov.size
        )
        #expect(mvhd != nil)
    }

    @Test("generateInitSegment — moov contains trak")
    func moovHasTrak() throws {
        let writer = InitSegmentWriter()
        let data = try writer.generateInitSegment(
            fileInfo: makeFileInfo(),
            trackAnalyses: [makeVideoAnalysis()]
        )
        let moov = try #require(try findBox(type: "moov", in: data))
        let trak = try findChildBox(
            type: "trak", in: data,
            parentOffset: moov.offset, parentSize: moov.size
        )
        #expect(trak != nil)
    }

    @Test("generateInitSegment — moov contains mvex")
    func moovHasMvex() throws {
        let writer = InitSegmentWriter()
        let data = try writer.generateInitSegment(
            fileInfo: makeFileInfo(),
            trackAnalyses: [makeVideoAnalysis()]
        )
        let moov = try #require(try findBox(type: "moov", in: data))
        let mvex = try findChildBox(
            type: "mvex", in: data,
            parentOffset: moov.offset, parentSize: moov.size
        )
        #expect(mvex != nil)
    }

    @Test("generateInitSegment — no mdat box present")
    func noMdat() throws {
        let writer = InitSegmentWriter()
        let data = try writer.generateInitSegment(
            fileInfo: makeFileInfo(),
            trackAnalyses: [makeVideoAnalysis()]
        )
        let mdat = try findBox(type: "mdat", in: data)
        #expect(mdat == nil)
    }

    @Test("generateInitSegment — A/V has two traks")
    func avTwoTraks() throws {
        let writer = InitSegmentWriter()
        let data = try writer.generateInitSegment(
            fileInfo: makeAVFileInfo(),
            trackAnalyses: [makeVideoAnalysis(), makeAudioAnalysis()]
        )
        let moov = try #require(try findBox(type: "moov", in: data))
        // Count trak boxes
        var trakCount = 0
        let headerSize = 8
        let childStart = moov.offset + headerSize
        let childEnd = moov.offset + moov.size
        var reader = BinaryReader(
            data: Data(data[childStart..<childEnd])
        )
        while reader.hasRemaining {
            let pos = reader.position
            let size = try reader.readUInt32()
            let boxType = try reader.readFourCC()
            if boxType == "trak" { trakCount += 1 }
            guard size >= 8 else { break }
            try reader.seek(to: pos + Int(size))
        }
        #expect(trakCount == 2)
    }

    @Test("generateInitSegment — output is parseable by MP4BoxReader")
    func parseableByReader() throws {
        let writer = InitSegmentWriter()
        let data = try writer.generateInitSegment(
            fileInfo: makeFileInfo(),
            trackAnalyses: [makeVideoAnalysis()]
        )
        let boxReader = MP4BoxReader()
        let boxes = try boxReader.readBoxes(from: data)
        #expect(boxes.count == 2)
        #expect(boxes[0].type == "ftyp")
        #expect(boxes[1].type == "moov")
    }

    @Test("generateInitSegment — mvhd duration is 0 (fragmented)")
    func mvhdDurationZero() throws {
        let writer = InitSegmentWriter()
        let data = try writer.generateInitSegment(
            fileInfo: makeFileInfo(),
            trackAnalyses: [makeVideoAnalysis()]
        )
        let moov = try #require(try findBox(type: "moov", in: data))
        let mvhd = try #require(
            try findChildBox(
                type: "mvhd", in: data,
                parentOffset: moov.offset, parentSize: moov.size
            )
        )
        // mvhd: size(4)+type(4)+version(1)+flags(3)
        //   +creation(4)+modification(4)+timescale(4)+duration(4)
        let payloadStart = mvhd.offset + 12  // past full box header
        var reader = BinaryReader(
            data: Data(
                data[payloadStart..<(mvhd.offset + mvhd.size)]
            )
        )
        _ = try reader.readUInt32()  // creation
        _ = try reader.readUInt32()  // modification
        _ = try reader.readUInt32()  // timescale
        let duration = try reader.readUInt32()
        #expect(duration == 0)
    }
}
