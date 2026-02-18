// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("TS Edge Cases")
struct TSEdgeCaseTests {

    // MARK: - Minimal inputs

    @Test("TS segment single sample → single segment")
    func singleSample() throws {
        let config = TSTestDataBuilder.VideoConfig(
            samples: 1,
            keyframeInterval: 1,
            sampleDelta: 3000,
            timescale: 90000,
            sampleSize: 58
        )
        let data = TSTestDataBuilder.videoMP4WithAvcC(
            config: config
        )
        let tsConfig = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: tsConfig
        )
        #expect(result.segmentCount == 1)
        let seg = try #require(result.mediaSegments.first)
        #expect(seg.data[0] == 0x47)
        #expect(seg.data.count % 188 == 0)
    }

    @Test("TS segment two samples, one keyframe → 1 segment")
    func twoSamples() throws {
        let config = TSTestDataBuilder.VideoConfig(
            samples: 2,
            keyframeInterval: 2,
            sampleDelta: 3000,
            timescale: 90000,
            sampleSize: 58
        )
        let data = TSTestDataBuilder.videoMP4WithAvcC(
            config: config
        )
        let tsConfig = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: tsConfig
        )
        #expect(result.segmentCount == 1)
    }

    // MARK: - Codec variations

    @Test("TS segment with uniform sample sizes (audio)")
    func uniformAudioSizes() throws {
        let data = TSTestDataBuilder.audioOnlyMP4WithEsds()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount > 0)
    }

    @Test("TS segment with variable frame durations")
    func variableFrameDurations() throws {
        let data =
            TSEdgeCaseDataBuilder.variableSttsVideoMP4()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount >= 1)
        let total = result.mediaSegments.map(\.duration)
            .reduce(0, +)
        #expect(total > 0)
    }

    @Test("TS segment with composition time offsets")
    func compositionTimeOffsets() throws {
        let data = TSEdgeCaseDataBuilder.mp4WithCtts()
        let config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount >= 1)
    }

    // MARK: - Large inputs

    @Test("TS segment with 10000 samples")
    func largeSampleCount() throws {
        let config = TSTestDataBuilder.VideoConfig(
            samples: 10000,
            keyframeInterval: 300,
            sampleDelta: 3000,
            timescale: 90000,
            sampleSize: 58
        )
        let data = TSTestDataBuilder.videoMP4WithAvcC(
            config: config
        )
        let tsConfig = SegmentationConfig(
            containerFormat: .mpegTS
        )
        let result = try TSSegmenter().segment(
            data: data, config: tsConfig
        )
        #expect(result.segmentCount > 0)
    }

    @Test("TS segment with very short target (0.5s)")
    func veryShortTarget() throws {
        let config = TSTestDataBuilder.VideoConfig(
            samples: 90,
            keyframeInterval: 15,
            sampleDelta: 3000,
            timescale: 90000,
            sampleSize: 58
        )
        let data = TSTestDataBuilder.videoMP4WithAvcC(
            config: config
        )
        var tsConfig = SegmentationConfig(
            containerFormat: .mpegTS
        )
        tsConfig.targetSegmentDuration = 0.5
        let result = try TSSegmenter().segment(
            data: data, config: tsConfig
        )
        #expect(result.segmentCount >= 2)
    }

    @Test("TS segment with very long target (60s)")
    func veryLongTarget() throws {
        let data = TSTestDataBuilder.videoMP4WithAvcC()
        var config = SegmentationConfig(
            containerFormat: .mpegTS
        )
        config.targetSegmentDuration = 60.0
        let result = try TSSegmenter().segment(
            data: data, config: config
        )
        #expect(result.segmentCount == 1)
    }

    // MARK: - Packet boundary edge cases

    @Test("PES data exactly fills TS payload")
    func pesExactFill() {
        let builder = TSSegmentBuilder()
        let samples = [
            SampleData(
                data:
                    TSEdgeCaseDataBuilder
                    .makeLengthPrefixedNAL(size: 50),
                pts: 0, dts: nil, duration: 3000,
                isSync: true
            )
        ]
        let config =
            TSEdgeCaseDataBuilder.makeVideoCodecConfig()
        let data = builder.buildSegment(
            videoSamples: samples, audioSamples: nil,
            config: config, sequenceNumber: 1
        )
        #expect(data.count % 188 == 0)
    }

    @Test("PES data leaves 1 byte in last packet")
    func pesStuffingNeeded() {
        let builder = TSSegmentBuilder()
        let samples = [
            SampleData(
                data:
                    TSEdgeCaseDataBuilder
                    .makeLengthPrefixedNAL(size: 10),
                pts: 0, dts: nil, duration: 3000,
                isSync: false
            )
        ]
        let config =
            TSEdgeCaseDataBuilder.makeVideoCodecConfig()
        let data = builder.buildSegment(
            videoSamples: samples, audioSamples: nil,
            config: config, sequenceNumber: 1
        )
        #expect(data.count % 188 == 0)
        let packetCount = data.count / 188
        for p in 0..<packetCount {
            #expect(data[p * 188] == 0x47)
        }
    }

    @Test("Very large PES → all packets valid")
    func largePES() {
        let builder = TSSegmentBuilder()
        let samples = [
            SampleData(
                data:
                    TSEdgeCaseDataBuilder
                    .makeLengthPrefixedNAL(size: 5000),
                pts: 0, dts: nil, duration: 3000,
                isSync: true
            )
        ]
        let config =
            TSEdgeCaseDataBuilder.makeVideoCodecConfig()
        let data = builder.buildSegment(
            videoSamples: samples, audioSamples: nil,
            config: config, sequenceNumber: 1
        )
        #expect(data.count % 188 == 0)
        let packetCount = data.count / 188
        #expect(packetCount > 10)
        for p in 0..<packetCount {
            #expect(data[p * 188] == 0x47)
        }
    }

    // MARK: - Error paths

    @Test("TS segment empty data → throws error")
    func emptyDataThrows() {
        #expect(throws: MP4Error.self) {
            try TSSegmenter().segment(
                data: Data(),
                config: SegmentationConfig(
                    containerFormat: .mpegTS
                )
            )
        }
    }

    @Test("TS segment non-MP4 data → throws error")
    func nonMP4Throws() {
        let random = Data(repeating: 0xAB, count: 200)
        #expect(throws: MP4Error.self) {
            try TSSegmenter().segment(
                data: random,
                config: SegmentationConfig(
                    containerFormat: .mpegTS
                )
            )
        }
    }

    @Test("TS segment MP4 without video/audio → throws")
    func noTracksThrows() {
        let ftypBox = MP4TestDataBuilder.ftyp()
        let moovBox = MP4TestDataBuilder.containerBox(
            type: "moov",
            children: [
                MP4TestDataBuilder.mvhd(
                    timescale: 600, duration: 6000
                )
            ]
        )
        let mdatBox = MP4TestDataBuilder.box(
            type: "mdat",
            payload: Data(repeating: 0, count: 16)
        )
        var data = Data()
        data.append(ftypBox)
        data.append(moovBox)
        data.append(mdatBox)
        #expect(throws: MP4Error.self) {
            try TSSegmenter().segment(
                data: data,
                config: SegmentationConfig(
                    containerFormat: .mpegTS
                )
            )
        }
    }

    @Test("TS segment unsupported codec → TransportError")
    func unsupportedCodecThrows() throws {
        let data =
            TSEdgeCaseDataBuilder.unsupportedCodecMP4()
        #expect(throws: TransportError.self) {
            try TSSegmenter().segment(
                data: data,
                config: SegmentationConfig(
                    containerFormat: .mpegTS
                )
            )
        }
    }
}
