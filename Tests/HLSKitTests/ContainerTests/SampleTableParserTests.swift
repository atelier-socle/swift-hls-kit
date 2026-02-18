// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("SampleTableParser")
struct SampleTableParserTests {

    let parser = SampleTableParser()
    let boxReader = MP4BoxReader()

    // MARK: - stts

    @Test("Parse stts — single entry")
    func sttsSimple() throws {
        let data = MP4TestDataBuilder.stts(
            entries: [(sampleCount: 300, sampleDelta: 3000)]
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let entries = try parser.parseTimeToSample(from: payload)
        #expect(entries.count == 1)
        #expect(entries[0].sampleCount == 300)
        #expect(entries[0].sampleDelta == 3000)
    }

    @Test("Parse stts — multiple entries")
    func sttsMultiple() throws {
        let data = MP4TestDataBuilder.stts(
            entries: [
                (sampleCount: 100, sampleDelta: 3000),
                (sampleCount: 200, sampleDelta: 6000)
            ]
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let entries = try parser.parseTimeToSample(from: payload)
        #expect(entries.count == 2)
        #expect(entries[1].sampleCount == 200)
        #expect(entries[1].sampleDelta == 6000)
    }

    @Test("Parse stts — empty")
    func sttsEmpty() throws {
        let data = MP4TestDataBuilder.stts(entries: [])
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let entries = try parser.parseTimeToSample(from: payload)
        #expect(entries.isEmpty)
    }

    @Test("Parse stts — total sample count")
    func sttsTotalCount() throws {
        let data = MP4TestDataBuilder.stts(
            entries: [
                (sampleCount: 100, sampleDelta: 3000),
                (sampleCount: 200, sampleDelta: 6000)
            ]
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let entries = try parser.parseTimeToSample(from: payload)
        let total = entries.reduce(0) { $0 + Int($1.sampleCount) }
        #expect(total == 300)
    }

    // MARK: - ctts

    @Test("Parse ctts — version 0 (unsigned offsets)")
    func cttsV0() throws {
        let data = MP4TestDataBuilder.ctts(
            entries: [
                (sampleCount: 10, sampleOffset: 3000),
                (sampleCount: 5, sampleOffset: 6000)
            ],
            version: 0
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let entries = try parser.parseCompositionOffsets(
            from: payload
        )
        #expect(entries.count == 2)
        #expect(entries[0].sampleOffset == 3000)
        #expect(entries[1].sampleOffset == 6000)
    }

    @Test("Parse ctts — version 1 (signed, negative)")
    func cttsV1Negative() throws {
        let data = MP4TestDataBuilder.ctts(
            entries: [
                (sampleCount: 10, sampleOffset: -1024),
                (sampleCount: 5, sampleOffset: 2048)
            ],
            version: 1
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let entries = try parser.parseCompositionOffsets(
            from: payload
        )
        #expect(entries.count == 2)
        #expect(entries[0].sampleOffset == -1024)
        #expect(entries[1].sampleOffset == 2048)
    }

    // MARK: - stsc

    @Test("Parse stsc — single entry")
    func stscSingle() throws {
        let data = MP4TestDataBuilder.stsc(
            entries: [.init(firstChunk: 1, samplesPerChunk: 10, descIndex: 1)]
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let entries = try parser.parseSampleToChunk(from: payload)
        #expect(entries.count == 1)
        #expect(entries[0].firstChunk == 1)
        #expect(entries[0].samplesPerChunk == 10)
        #expect(entries[0].sampleDescriptionIndex == 1)
    }

    @Test("Parse stsc — multiple patterns")
    func stscMultiple() throws {
        let data = MP4TestDataBuilder.stsc(
            entries: [
                .init(firstChunk: 1, samplesPerChunk: 10, descIndex: 1),
                .init(firstChunk: 5, samplesPerChunk: 5, descIndex: 1)
            ]
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let entries = try parser.parseSampleToChunk(from: payload)
        #expect(entries.count == 2)
        #expect(entries[1].firstChunk == 5)
        #expect(entries[1].samplesPerChunk == 5)
    }

    // MARK: - stsz

    @Test("Parse stsz — variable sizes")
    func stszVariable() throws {
        let data = MP4TestDataBuilder.stsz(
            sizes: [100, 200, 300, 400]
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let (uniform, sizes) = try parser.parseSampleSizes(
            from: payload
        )
        #expect(uniform == 0)
        #expect(sizes == [100, 200, 300, 400])
    }

    @Test("Parse stsz — uniform size")
    func stszUniform() throws {
        let data = MP4TestDataBuilder.stszUniform(
            sampleSize: 1024, count: 100
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let (uniform, sizes) = try parser.parseSampleSizes(
            from: payload
        )
        #expect(uniform == 1024)
        #expect(sizes.isEmpty)
    }

    // MARK: - stco / co64

    @Test("Parse stco — 32-bit offsets")
    func stco32() throws {
        let data = MP4TestDataBuilder.stco(
            offsets: [1000, 5000, 10000]
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let offsets = try parser.parseChunkOffsets32(from: payload)
        #expect(offsets == [1000, 5000, 10000])
    }

    @Test("Parse co64 — 64-bit offsets")
    func co6464() throws {
        let data = MP4TestDataBuilder.co64(
            offsets: [0x1_0000_0000, 0x2_0000_0000]
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let offsets = try parser.parseChunkOffsets64(from: payload)
        #expect(offsets == [0x1_0000_0000, 0x2_0000_0000])
    }

    // MARK: - stss

    @Test("Parse stss — sparse keyframes")
    func stssSparse() throws {
        let data = MP4TestDataBuilder.stss(
            syncSamples: [1, 31, 61, 91]
        )
        let boxes = try boxReader.readBoxes(from: data)
        let payload = try #require(boxes.first?.payload)
        let samples = try parser.parseSyncSamples(from: payload)
        #expect(samples == [1, 31, 61, 91])
    }

}

// MARK: - Complete stbl

extension SampleTableParserTests {

    @Test("Parse complete stbl — all tables")
    func completeStbl() throws {
        let stblData = MP4TestDataBuilder.stbl(
            codec: "avc1",
            sttsEntries: [(sampleCount: 90, sampleDelta: 3000)],
            stszSizes: [UInt32](repeating: 50_000, count: 90),
            stcoOffsets: [1000],
            stscEntries: [
                .init(firstChunk: 1, samplesPerChunk: 90, descIndex: 1)
            ],
            stssSyncSamples: [1, 31, 61]
        )
        let boxes = try boxReader.readBoxes(from: stblData)
        let stbl = try #require(boxes.first)
        let table = try parser.parse(stbl: stbl)
        #expect(table.timeToSample.count == 1)
        #expect(table.sampleToChunk.count == 1)
        #expect(table.sampleSizes.count == 90)
        #expect(table.chunkOffsets == [1000])
        #expect(table.syncSamples == [1, 31, 61])
        #expect(table.compositionOffsets == nil)
        #expect(table.sampleCount == 90)
    }

    @Test("Parse stbl — no stss means nil syncSamples")
    func stblNoStss() throws {
        let stblData = MP4TestDataBuilder.stbl(
            codec: "mp4a",
            sttsEntries: [(sampleCount: 100, sampleDelta: 1024)],
            stszSizes: [UInt32](repeating: 512, count: 100),
            stcoOffsets: [2000],
            stscEntries: [
                .init(firstChunk: 1, samplesPerChunk: 100, descIndex: 1)
            ]
        )
        let boxes = try boxReader.readBoxes(from: stblData)
        let stbl = try #require(boxes.first)
        let table = try parser.parse(stbl: stbl)
        #expect(table.syncSamples == nil)
    }

    @Test("Parse stbl — with ctts")
    func stblWithCtts() throws {
        let stblData = MP4TestDataBuilder.stbl(
            sttsEntries: [(sampleCount: 30, sampleDelta: 3000)],
            stszSizes: [UInt32](repeating: 50_000, count: 30),
            stcoOffsets: [1000],
            stscEntries: [
                .init(firstChunk: 1, samplesPerChunk: 30, descIndex: 1)
            ],
            stssSyncSamples: [1],
            cttsEntries: [
                (sampleCount: 10, sampleOffset: 3000),
                (sampleCount: 20, sampleOffset: 6000)
            ]
        )
        let boxes = try boxReader.readBoxes(from: stblData)
        let stbl = try #require(boxes.first)
        let table = try parser.parse(stbl: stbl)
        let ctts = try #require(table.compositionOffsets)
        #expect(ctts.count == 2)
        #expect(ctts[0].sampleOffset == 3000)
    }

    @Test("Parse stbl — co64 fallback when no stco")
    func stblCo64Fallback() throws {
        let entry = MP4TestDataBuilder.StscEntry(
            firstChunk: 1, samplesPerChunk: 1, descIndex: 1
        )
        let stblData = MP4TestDataBuilder.containerBox(
            type: "stbl",
            children: [
                MP4TestDataBuilder.stsd(codec: "avc1"),
                MP4TestDataBuilder.stts(
                    entries: [(sampleCount: 1, sampleDelta: 1)]
                ),
                MP4TestDataBuilder.stsc(entries: [entry]),
                MP4TestDataBuilder.stsz(sizes: [100]),
                MP4TestDataBuilder.co64(
                    offsets: [0x1_0000_0000]
                )
            ]
        )
        let boxes = try boxReader.readBoxes(from: stblData)
        let stbl = try #require(boxes.first)
        let table = try parser.parse(stbl: stbl)
        #expect(table.chunkOffsets == [0x1_0000_0000])
    }

    @Test("SampleTable — uniformSampleSize sampleCount")
    func uniformSampleCount() throws {
        let table = SampleTable(
            timeToSample: [
                TimeToSampleEntry(
                    sampleCount: 50, sampleDelta: 1024
                ),
                TimeToSampleEntry(
                    sampleCount: 50, sampleDelta: 2048
                )
            ],
            compositionOffsets: nil,
            sampleToChunk: [],
            sampleSizes: [],
            uniformSampleSize: 512,
            chunkOffsets: [],
            syncSamples: nil
        )
        #expect(table.sampleCount == 100)
    }
}

// MARK: - Error Cases

extension SampleTableParserTests {

    @Test("Missing stts — throws")
    func missingStts() throws {
        let stblData = MP4TestDataBuilder.containerBox(
            type: "stbl",
            children: [
                MP4TestDataBuilder.stsd(codec: "avc1")
            ]
        )
        let boxes = try boxReader.readBoxes(from: stblData)
        let stbl = try #require(boxes.first)
        #expect(throws: MP4Error.self) {
            try parser.parse(stbl: stbl)
        }
    }

    @Test("Missing stsc — throws")
    func missingStsc() throws {
        let stblData = MP4TestDataBuilder.containerBox(
            type: "stbl",
            children: [
                MP4TestDataBuilder.stsd(codec: "avc1"),
                MP4TestDataBuilder.stts(
                    entries: [(sampleCount: 1, sampleDelta: 1)]
                )
            ]
        )
        let boxes = try boxReader.readBoxes(from: stblData)
        let stbl = try #require(boxes.first)
        #expect(throws: MP4Error.self) {
            try parser.parse(stbl: stbl)
        }
    }

    @Test("Missing stsz — throws")
    func missingStsz() throws {
        let entry = MP4TestDataBuilder.StscEntry(
            firstChunk: 1, samplesPerChunk: 1, descIndex: 1
        )
        let stblData = MP4TestDataBuilder.containerBox(
            type: "stbl",
            children: [
                MP4TestDataBuilder.stsd(codec: "avc1"),
                MP4TestDataBuilder.stts(
                    entries: [(sampleCount: 1, sampleDelta: 1)]
                ),
                MP4TestDataBuilder.stsc(entries: [entry])
            ]
        )
        let boxes = try boxReader.readBoxes(from: stblData)
        let stbl = try #require(boxes.first)
        #expect(throws: MP4Error.self) {
            try parser.parse(stbl: stbl)
        }
    }

    @Test("Missing stco/co64 — throws")
    func missingChunkOffsets() throws {
        let entry = MP4TestDataBuilder.StscEntry(
            firstChunk: 1, samplesPerChunk: 1, descIndex: 1
        )
        let stblData = MP4TestDataBuilder.containerBox(
            type: "stbl",
            children: [
                MP4TestDataBuilder.stsd(codec: "avc1"),
                MP4TestDataBuilder.stts(
                    entries: [(sampleCount: 1, sampleDelta: 1)]
                ),
                MP4TestDataBuilder.stsc(entries: [entry]),
                MP4TestDataBuilder.stsz(sizes: [100])
            ]
        )
        let boxes = try boxReader.readBoxes(from: stblData)
        let stbl = try #require(boxes.first)
        #expect(throws: MP4Error.self) {
            try parser.parse(stbl: stbl)
        }
    }

    @Test("Truncated stts data — throws")
    func truncatedStts() {
        let data = Data([0x00, 0x00])
        #expect(throws: MP4Error.self) {
            try parser.parseTimeToSample(from: data)
        }
    }

    @Test("Truncated ctts data — throws")
    func truncatedCtts() {
        let data = Data([0x00, 0x00])
        #expect(throws: MP4Error.self) {
            try parser.parseCompositionOffsets(from: data)
        }
    }

    @Test("Truncated stsc data — throws")
    func truncatedStsc() {
        let data = Data([0x00, 0x00])
        #expect(throws: MP4Error.self) {
            try parser.parseSampleToChunk(from: data)
        }
    }

    @Test("Truncated stsz data — throws")
    func truncatedStsz() {
        let data = Data([0x00, 0x00])
        #expect(throws: MP4Error.self) {
            try parser.parseSampleSizes(from: data)
        }
    }

    @Test("Truncated stco data — throws")
    func truncatedStco() {
        let data = Data([0x00, 0x00])
        #expect(throws: MP4Error.self) {
            try parser.parseChunkOffsets32(from: data)
        }
    }

    @Test("Truncated co64 data — throws")
    func truncatedCo64() {
        let data = Data([0x00, 0x00])
        #expect(throws: MP4Error.self) {
            try parser.parseChunkOffsets64(from: data)
        }
    }

    @Test("Truncated stss data — throws")
    func truncatedStss() {
        let data = Data([0x00, 0x00])
        #expect(throws: MP4Error.self) {
            try parser.parseSyncSamples(from: data)
        }
    }
}
