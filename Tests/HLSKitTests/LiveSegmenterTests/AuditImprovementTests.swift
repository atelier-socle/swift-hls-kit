// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

// MARK: - O1: Composition Time Offset (CTS)

@Suite(
    "O1 — sample_composition_time_offset in trun",
    .timeLimit(.minutes(1))
)
struct CompositionTimeOffsetTests {

    let writer = CMAFWriter()

    private func readBoxes(
        from data: Data
    ) throws -> [MP4Box] {
        try MP4BoxReader().readBoxes(from: data)
    }

    @Test("Frames without CTS produce no CTS flag in trun")
    func noCTSFlag() throws {
        let frames = [
            EncodedFrame(
                data: Data(repeating: 0xBB, count: 100),
                timestamp: MediaTimestamp(seconds: 0),
                duration: MediaTimestamp(seconds: 1.0 / 30),
                isKeyframe: true,
                codec: .h264
            ),
            EncodedFrame(
                data: Data(repeating: 0xBB, count: 100),
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
        let moof = try #require(
            boxes.first { $0.type == "moof" }
        )
        let traf = try #require(moof.findChild("traf"))
        let trun = try #require(traf.findChild("trun"))
        let payload = try #require(trun.payload)
        let flags = readFlags(from: payload)
        #expect(flags & 0x0800 == 0)
    }

    @Test("Frames with positive CTS set CTS flag, version 0")
    func positiveCTSFlag() throws {
        let frames = [
            EncodedFrame(
                data: Data(repeating: 0xBB, count: 100),
                timestamp: MediaTimestamp(seconds: 0),
                duration: MediaTimestamp(seconds: 1.0 / 30),
                isKeyframe: true,
                codec: .h264,
                compositionTimeOffset: 3000
            ),
            EncodedFrame(
                data: Data(repeating: 0xBB, count: 100),
                timestamp: MediaTimestamp(seconds: 1.0 / 30),
                duration: MediaTimestamp(seconds: 1.0 / 30),
                isKeyframe: false,
                codec: .h264,
                compositionTimeOffset: 6000
            )
        ]
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 90000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(
            boxes.first { $0.type == "moof" }
        )
        let traf = try #require(moof.findChild("traf"))
        let trun = try #require(traf.findChild("trun"))
        let payload = try #require(trun.payload)
        let flags = readFlags(from: payload)
        #expect(flags & 0x0800 != 0)
        let version = payload[payload.startIndex]
        #expect(version == 0)
    }

    @Test("Frames with negative CTS use trun version 1")
    func negativeCTSVersion1() throws {
        let frames = [
            EncodedFrame(
                data: Data(repeating: 0xBB, count: 100),
                timestamp: MediaTimestamp(seconds: 0),
                duration: MediaTimestamp(seconds: 1.0 / 30),
                isKeyframe: true,
                codec: .h264,
                compositionTimeOffset: -3000
            )
        ]
        let data = writer.generateMediaSegment(
            frames: frames,
            sequenceNumber: 1,
            timescale: 90000
        )
        let boxes = try readBoxes(from: data)
        let moof = try #require(
            boxes.first { $0.type == "moof" }
        )
        let traf = try #require(moof.findChild("traf"))
        let trun = try #require(traf.findChild("trun"))
        let payload = try #require(trun.payload)
        let version = payload[payload.startIndex]
        #expect(version == 1)
    }

    @Test("EncodedFrame compositionTimeOffset defaults to nil")
    func compositionTimeOffsetDefaultNil() {
        let frame = EncodedFrame(
            data: Data(repeating: 0, count: 10),
            timestamp: MediaTimestamp(seconds: 0),
            duration: MediaTimestamp(seconds: 0.033),
            isKeyframe: true,
            codec: .h264
        )
        #expect(frame.compositionTimeOffset == nil)
    }

    @Test("EncodedFrame stores compositionTimeOffset value")
    func compositionTimeOffsetStored() {
        let frame = EncodedFrame(
            data: Data(repeating: 0, count: 10),
            timestamp: MediaTimestamp(seconds: 0),
            duration: MediaTimestamp(seconds: 0.033),
            isKeyframe: true,
            codec: .h264,
            compositionTimeOffset: 9000
        )
        #expect(frame.compositionTimeOffset == 9000)
    }

    private func readFlags(from payload: Data) -> UInt32 {
        let start = payload.startIndex
        return UInt32(payload[start + 1]) << 16
            | UInt32(payload[start + 2]) << 8
            | UInt32(payload[start + 3])
    }
}

// MARK: - O2: ingest() Returns Boundary Signal

@Suite(
    "O2 — ingest() returns Bool boundary signal",
    .timeLimit(.minutes(1))
)
struct IngestReturnsBoolTests {

    @Test("ingest returns false when no segment emitted")
    func ingestReturnsFalseNoEmit() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 6.0,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let frame = EncodedFrameFactory.audioFrame(
            timestamp: 0
        )
        let result = try await segmenter.ingest(frame)
        #expect(result == false)
        _ = try await segmenter.finish()
    }

    @Test("ingest returns true when segment emitted at target")
    func ingestReturnsTrueOnEmit() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let collector = Task<[LiveSegment], Never> {
            var segs: [LiveSegment] = []
            for await seg in segmenter.segments {
                segs.append(seg)
            }
            return segs
        }

        var emitCount = 0
        let frames = EncodedFrameFactory.audioFrames(
            count: 100
        )
        for frame in frames {
            let didEmit = try await segmenter.ingest(frame)
            emitCount += didEmit ? 1 : 0
        }
        _ = try await segmenter.finish()
        _ = await collector.value

        #expect(emitCount > 0)
    }

    @Test("AudioSegmenter.ingest returns Bool")
    func audioSegmenterReturnsBool() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 0.5,
            keyframeAligned: false
        )
        let segmenter = AudioSegmenter(
            audioConfig: .init(
                sampleRate: 48000, channels: 2
            ),
            configuration: config,
            containerFormat: .rawData
        )
        let collector = Task<[LiveSegment], Never> {
            var segs: [LiveSegment] = []
            for await seg in segmenter.segments {
                segs.append(seg)
            }
            return segs
        }

        var emitCount = 0
        let frames = EncodedFrameFactory.audioFrames(
            count: 100
        )
        for frame in frames {
            let didEmit = try await segmenter.ingest(frame)
            emitCount += didEmit ? 1 : 0
        }
        _ = try await segmenter.finish()
        _ = await collector.value

        #expect(emitCount > 0)
    }

    @Test("ingest returns true on maxDuration force-emit")
    func ingestReturnsTrueOnMaxDuration() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 2.0,
            keyframeAligned: true
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let collector = Task<[LiveSegment], Never> {
            var segs: [LiveSegment] = []
            for await seg in segmenter.segments {
                segs.append(seg)
            }
            return segs
        }

        var sawTrue = false
        let frameDuration = 1.0 / 30.0
        for i in 0..<120 {
            let frame = EncodedFrame(
                data: Data(repeating: 0xBB, count: 100),
                timestamp: MediaTimestamp(
                    seconds: Double(i) * frameDuration
                ),
                duration: MediaTimestamp(
                    seconds: frameDuration
                ),
                isKeyframe: i == 0,
                codec: .h264
            )
            if try await segmenter.ingest(frame) {
                sawTrue = true
            }
        }
        _ = try await segmenter.finish()
        _ = await collector.value

        #expect(sawTrue)
    }
}

// MARK: - O3: Integer Timestamp Precision

@Suite(
    "O3 — Integer duration accumulation",
    .timeLimit(.minutes(1))
)
struct IntegerTimestampTests {

    @Test("computeBaseDecodeTime: matching timescale uses integer")
    func baseDecodeTimeMatchingTimescale() {
        let ts = MediaTimestamp(
            value: 144000, timescale: 48000
        )
        let result = CMAFWriter.computeBaseDecodeTime(
            timestamp: ts, timescale: 48000
        )
        #expect(result == 144000)
    }

    @Test("computeBaseDecodeTime: nil timestamp returns 0")
    func baseDecodeTimeNilTimestamp() {
        let result = CMAFWriter.computeBaseDecodeTime(
            timestamp: nil, timescale: 48000
        )
        #expect(result == 0)
    }

    @Test("computeBaseDecodeTime: cross-timescale rescales")
    func baseDecodeTimeCrossTimescale() {
        let ts = MediaTimestamp(
            value: 96000, timescale: 48000
        )
        let result = CMAFWriter.computeBaseDecodeTime(
            timestamp: ts, timescale: 90000
        )
        #expect(result == 180000)
    }

    @Test("computeSampleDuration: matching timescale")
    func sampleDurationMatchingTimescale() {
        let dur = MediaTimestamp(
            value: 1024, timescale: 48000
        )
        let result = CMAFWriter.computeSampleDuration(
            duration: dur, timescale: 48000
        )
        #expect(result == 1024)
    }

    @Test("computeSampleDuration: cross-timescale rescales")
    func sampleDurationCrossTimescale() {
        let dur = MediaTimestamp(
            value: 3000, timescale: 90000
        )
        let result = CMAFWriter.computeSampleDuration(
            duration: dur, timescale: 48000
        )
        #expect(result == 1600)
    }

    @Test("Integer accumulation avoids float precision drift")
    func integerAccumulationPrecision() async throws {
        let config = LiveSegmenterConfiguration(
            targetDuration: 2.0,
            keyframeAligned: true
        )
        let segmenter = IncrementalSegmenter(
            configuration: config
        )
        let collector = Task<[LiveSegment], Never> {
            var segs: [LiveSegment] = []
            for await seg in segmenter.segments {
                segs.append(seg)
            }
            return segs
        }

        let timescale: Int32 = 30
        for i in 0..<120 {
            let frame = EncodedFrame(
                data: Data(repeating: 0xBB, count: 100),
                timestamp: MediaTimestamp(
                    value: Int64(i), timescale: timescale
                ),
                duration: MediaTimestamp(
                    value: 1, timescale: timescale
                ),
                isKeyframe: i % 60 == 0,
                codec: .h264
            )
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()
        let segments = await collector.value

        for segment in segments {
            let remainder = segment.duration.truncatingRemainder(
                dividingBy: 1.0
            )
            #expect(
                remainder == 0.0,
                "Duration \(segment.duration) has float drift"
            )
        }
    }
}
