// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite("Live Pipeline Integration", .timeLimit(.minutes(1)))
struct LivePipelineIntegrationTests {

    // MARK: - Helpers

    private func readBoxes(from data: Data) throws -> [MP4Box] {
        try MP4BoxReader().readBoxes(from: data)
    }

    // MARK: - Audio Pipeline

    @Test("Audio-only pipeline: frames → AudioSegmenter → fMP4")
    func audioOnlyPipeline() async throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .lc
        )
        let segConfig = LiveSegmenterConfiguration(
            targetDuration: 2.0,
            keyframeAligned: false
        )
        let segmenter = AudioSegmenter(
            audioConfig: config,
            configuration: segConfig,
            containerFormat: .fmp4
        )

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        let frames = EncodedFrameFactory.audioFrames(count: 300)
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let emitted = await collector.value
        #expect(emitted.count >= 2)

        // Init segment is valid fMP4
        let initData = try #require(segmenter.initSegment)
        let initBoxes = try readBoxes(from: initData)
        #expect(initBoxes[0].type == "ftyp")
        #expect(initBoxes[1].type == "moov")

        // Each segment is valid fMP4
        for segment in emitted {
            let boxes = try readBoxes(from: segment.data)
            #expect(boxes[0].type == "styp")
            #expect(boxes[1].type == "moof")
            #expect(boxes[2].type == "mdat")
        }

        // Indices are sequential
        for i in 0..<emitted.count {
            #expect(emitted[i].index == i)
        }

        // Duration sum approximates total
        let totalDuration = emitted.reduce(0.0) {
            $0 + $1.duration
        }
        let frameDuration = 1024.0 / 48000.0
        let expectedDuration = Double(300) * frameDuration
        #expect(
            abs(totalDuration - expectedDuration) < 0.5
        )
    }

    @Test("Audio-only pipeline: rawData container")
    func audioRawDataPipeline() async throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let segConfig = LiveSegmenterConfiguration(
            targetDuration: 2.0,
            keyframeAligned: false
        )
        let segmenter = AudioSegmenter(
            audioConfig: config,
            configuration: segConfig,
            containerFormat: .rawData
        )

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        let frames = EncodedFrameFactory.audioFrames(count: 300)
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let emitted = await collector.value
        #expect(segmenter.initSegment == nil)
        #expect(emitted.count >= 2)

        // Raw data contains 0xAA bytes
        let first = try #require(emitted.first)
        #expect(first.data.first == 0xAA)
    }

    // MARK: - Video Pipeline

    @Test("Video-only pipeline: frames → VideoSegmenter → fMP4")
    func videoOnlyPipeline() async throws {
        let videoConfig = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1280, height: 720,
            sps: Data([0x67, 0x42, 0xC0, 0x1E]),
            pps: Data([0x68, 0xCE, 0x38, 0x80])
        )
        let segConfig = LiveSegmenterConfiguration(
            targetDuration: 1.0,
            keyframeAligned: true
        )
        let segmenter = VideoSegmenter(
            videoConfig: videoConfig,
            configuration: segConfig
        )

        let collector =
            Task<[VideoSegmenter.SegmentOutput], Never> {
                var outputs: [VideoSegmenter.SegmentOutput] = []
                for await output in segmenter.segmentOutputs {
                    outputs.append(output)
                }
                return outputs
            }

        let frames = EncodedFrameFactory.videoFrames(
            count: 90, fps: 30.0, keyframeInterval: 30
        )
        for frame in frames {
            try await segmenter.ingestVideo(frame)
        }
        _ = try await segmenter.finish()

        let outputs = await collector.value
        #expect(outputs.count >= 2)

        // Video init segment is valid fMP4
        let initBoxes = try readBoxes(
            from: segmenter.videoInitSegment
        )
        #expect(initBoxes[0].type == "ftyp")
        #expect(initBoxes[1].type == "moov")

        // Video segments start with keyframes
        for output in outputs.dropLast() {
            #expect(output.videoSegment.isIndependent)
        }
    }

    @Test("Video+audio pipeline: interleaved → synced outputs")
    func videoAudioPipeline() async throws {
        let videoConfig = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1920, height: 1080,
            sps: Data([0x67, 0x42, 0xC0, 0x1E]),
            pps: Data([0x68, 0xCE, 0x38, 0x80])
        )
        let audioConfig = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let segConfig = LiveSegmenterConfiguration(
            targetDuration: 1.0,
            keyframeAligned: true
        )
        let segmenter = VideoSegmenter(
            videoConfig: videoConfig,
            audioConfig: audioConfig,
            configuration: segConfig
        )

        let collector =
            Task<[VideoSegmenter.SegmentOutput], Never> {
                var outputs: [VideoSegmenter.SegmentOutput] = []
                for await output in segmenter.segmentOutputs {
                    outputs.append(output)
                }
                return outputs
            }

        let videoFrames = EncodedFrameFactory.videoFrames(
            count: 90, fps: 30.0, keyframeInterval: 30
        )
        let audioFrames = EncodedFrameFactory.audioFrames(
            count: 150
        )

        var audioIdx = 0
        for videoFrame in videoFrames {
            try await segmenter.ingestVideo(videoFrame)
            while audioIdx < audioFrames.count,
                audioFrames[audioIdx].timestamp
                    <= videoFrame.timestamp
            {
                try await segmenter.ingestAudio(
                    audioFrames[audioIdx]
                )
                audioIdx += 1
            }
        }
        while audioIdx < audioFrames.count {
            try await segmenter.ingestAudio(
                audioFrames[audioIdx]
            )
            audioIdx += 1
        }

        _ = try await segmenter.finish()
        let outputs = await collector.value
        #expect(outputs.count >= 2)

        // Each output has both video and audio
        for output in outputs {
            #expect(output.audioSegment != nil)
        }

        // Audio init segment exists
        #expect(segmenter.audioInitSegment != nil)
    }

    // MARK: - CMAFWriter Round-Trips

    @Test("CMAFWriter: audio init → MP4BoxReader → valid")
    func cmafAudioInitRoundTrip() throws {
        let writer = CMAFWriter()
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .lc
        )
        let data = writer.generateAudioInitSegment(
            config: config
        )
        let boxes = try readBoxes(from: data)

        #expect(boxes.count == 2)
        let moov = try #require(boxes.last)
        #expect(moov.type == "moov")
        #expect(moov.findChild("trak") != nil)
        #expect(moov.findChild("mvex") != nil)

        let stbl = try #require(
            moov.findByPath("trak/mdia/minf/stbl")
        )
        #expect(stbl.findChild("stsd") != nil)
        #expect(stbl.findChild("stts") != nil)
    }

    @Test("CMAFWriter: media segment → MP4BoxReader → valid")
    func cmafMediaSegmentRoundTrip() throws {
        let writer = CMAFWriter()
        let frames = (0..<5).map { i in
            EncodedFrameFactory.audioFrame(
                timestamp: Double(i) * 1024.0 / 48000.0
            )
        }
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

        // mdat box size = header (8) + payload
        let expectedMdatPayload = frames.reduce(0) {
            $0 + $1.data.count
        }
        let mdatBox = boxes[2]
        // mdat size includes 8-byte header
        #expect(mdatBox.size == expectedMdatPayload + 8)
    }

    @Test("CMAFWriter: sequential segments have incrementing seq")
    func cmafSequentialSegments() throws {
        let writer = CMAFWriter()
        for seq in UInt32(1)...3 {
            let frames = (0..<3).map { i in
                let baseTime =
                    Double(seq - 1) * 3.0
                    * 1024.0 / 48000.0
                return EncodedFrameFactory.audioFrame(
                    timestamp: baseTime
                        + Double(i) * 1024.0 / 48000.0
                )
            }
            let data = writer.generateMediaSegment(
                frames: frames,
                sequenceNumber: seq,
                timescale: 48000
            )
            let boxes = try readBoxes(from: data)
            let moof = try #require(
                boxes.first { $0.type == "moof" }
            )
            let mfhd = try #require(moof.findChild("mfhd"))
            let payload = try #require(mfhd.payload)
            // mfhd is full box: 4 bytes version+flags,
            // then 4 bytes sequence number
            #expect(payload.count >= 8)
            let readSeq =
                UInt32(payload[4]) << 24
                | UInt32(payload[5]) << 16
                | UInt32(payload[6]) << 8
                | UInt32(payload[7])
            #expect(readSeq == seq)
        }
    }
}
