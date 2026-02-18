// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("MP4TrackAnalysis")
struct MP4TrackAnalysisTests {

    let boxReader = MP4BoxReader()
    let parser = MP4InfoParser()

    @Test("Parse track analysis from synthetic MP4")
    func parseAnalysis() throws {
        let data = MP4TestDataBuilder.segmentableMP4()
        let boxes = try boxReader.readBoxes(from: data)
        let analyses = try parser.parseTrackAnalysis(from: boxes)
        #expect(analyses.count == 1)
    }

    @Test("Video track has sample table with sync samples")
    func videoTrackSyncSamples() throws {
        let data = MP4TestDataBuilder.segmentableMP4(
            videoSamples: 90,
            keyframeInterval: 30,
            sampleDelta: 3000,
            timescale: 90000
        )
        let boxes = try boxReader.readBoxes(from: data)
        let analyses = try parser.parseTrackAnalysis(from: boxes)
        let analysis = try #require(analyses.first)
        #expect(analysis.info.mediaType == .video)
        #expect(analysis.sampleTable.syncSamples != nil)
        let sync = try #require(analysis.sampleTable.syncSamples)
        #expect(sync == [1, 31, 61])
    }

    @Test("Audio track has sample table without sync samples")
    func audioTrackNoSync() throws {
        // Build an audio track with proper sample tables
        let stblBox = MP4TestDataBuilder.stbl(
            codec: "mp4a",
            sttsEntries: [(sampleCount: 100, sampleDelta: 1024)],
            stszSizes: [UInt32](repeating: 512, count: 100),
            stcoOffsets: [0],
            stscEntries: [
                .init(firstChunk: 1, samplesPerChunk: 100, descIndex: 1)
            ]
        )
        let minfBox = MP4TestDataBuilder.containerBox(
            type: "minf", children: [stblBox]
        )
        let mdiaBox = MP4TestDataBuilder.containerBox(
            type: "mdia",
            children: [
                MP4TestDataBuilder.mdhd(
                    timescale: 44100, duration: 102400
                ),
                MP4TestDataBuilder.hdlr(handlerType: "soun"),
                minfBox
            ]
        )
        let trakBox = MP4TestDataBuilder.containerBox(
            type: "trak",
            children: [
                MP4TestDataBuilder.tkhd(
                    trackId: 1, duration: 102400
                ),
                mdiaBox
            ]
        )
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 44100, duration: 102400
                ),
                trakBox
            ]
        )
        var data = Data()
        data.append(MP4TestDataBuilder.ftyp())
        data.append(moovBox)
        let boxes = try boxReader.readBoxes(from: data)
        let analyses = try parser.parseTrackAnalysis(from: boxes)
        let analysis = try #require(analyses.first)
        #expect(analysis.info.mediaType == .audio)
        #expect(analysis.sampleTable.syncSamples == nil)
    }

    @Test("SampleLocator created from analysis")
    func locatorFromAnalysis() throws {
        let data = MP4TestDataBuilder.segmentableMP4(
            videoSamples: 60,
            keyframeInterval: 30,
            sampleDelta: 3000,
            timescale: 90000
        )
        let boxes = try boxReader.readBoxes(from: data)
        let analyses = try parser.parseTrackAnalysis(from: boxes)
        let analysis = try #require(analyses.first)
        let locator = analysis.locator
        #expect(locator.timescale == 90000)
        #expect(locator.sampleTable.sampleCount == 60)
        // DTS of sample 30 = 30 * 3000 = 90000
        #expect(locator.decodingTime(forSample: 30) == 90000)
    }

    @Test("Segment calculation from analysis")
    func segmentsFromAnalysis() throws {
        let data = MP4TestDataBuilder.segmentableMP4(
            videoSamples: 300,
            keyframeInterval: 30,
            sampleDelta: 3000,
            timescale: 90000,
            sampleSize: 50_000
        )
        let boxes = try boxReader.readBoxes(from: data)
        let analyses = try parser.parseTrackAnalysis(from: boxes)
        let locator = try #require(analyses.first).locator
        let segments = locator.calculateSegments(
            targetDuration: 6.0
        )
        #expect(!segments.isEmpty)
        // Total duration: 300 * 3000 / 90000 = 10s
        // With 6s target, expect ~2 segments
        let totalDuration = segments.reduce(0) {
            $0 + $1.duration
        }
        #expect(abs(totalDuration - 10.0) < 0.01)
    }

    @Test("MP4TrackAnalysis — Hashable")
    func hashable() throws {
        let data = MP4TestDataBuilder.segmentableMP4(
            videoSamples: 10,
            keyframeInterval: 10
        )
        let boxes = try boxReader.readBoxes(from: data)
        let analyses = try parser.parseTrackAnalysis(from: boxes)
        let analysis = try #require(analyses.first)
        let set: Set<MP4TrackAnalysis> = [analysis]
        #expect(set.count == 1)
    }

    @Test("parseTrackAnalysis — missing moov throws")
    func missingMoov() throws {
        let data = MP4TestDataBuilder.ftyp()
        let boxes = try boxReader.readBoxes(from: data)
        #expect(throws: MP4Error.self) {
            try parser.parseTrackAnalysis(from: boxes)
        }
    }
}
