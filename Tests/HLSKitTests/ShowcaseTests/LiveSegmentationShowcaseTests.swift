// SPDX-License-Identifier: Apache-2.0
// Copyright 2026 Atelier Socle SAS

import Foundation
import Testing

@testable import HLSKit

@Suite(
    "Live Segmentation Showcase",
    .timeLimit(.minutes(1))
)
struct LiveSegmentationShowcaseTests {

    // MARK: - Helpers

    private func readBoxes(from data: Data) throws -> [MP4Box] {
        try MP4BoxReader().readBoxes(from: data)
    }

    private func containsFourCC(
        _ fourCC: String, in data: Data
    ) -> Bool {
        let pattern = Data(fourCC.utf8)
        guard pattern.count == 4, data.count >= 4 else {
            return false
        }
        let range = data.startIndex...(data.endIndex - 4)
        return range.contains { data[$0..<($0 + 4)] == pattern }
    }

    // MARK: - Podcast Live Audio

    @Test("Podcast live: 8s of audio → segments at 2s each")
    func podcastLiveAudio() async throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2, profile: .lc
        )
        let segConfig = LiveSegmenterConfiguration(
            targetDuration: 2.0,
            keyframeAligned: false
        )
        let segmenter = AudioSegmenter(
            audioConfig: config,
            configuration: segConfig
        )

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        // ~8s of audio at 48kHz (1024 samples/frame)
        let frameCount = Int(8.0 * 48000.0 / 1024.0)
        let frames = EncodedFrameFactory.audioFrames(
            count: frameCount
        )
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let emitted = await collector.value
        #expect(emitted.count >= 3)

        // Init segment valid
        let initData = try #require(segmenter.initSegment)
        let initBoxes = try readBoxes(from: initData)
        #expect(initBoxes[0].type == "ftyp")
        #expect(initBoxes[1].type == "moov")

        // All segments valid fMP4
        for segment in emitted {
            let boxes = try readBoxes(from: segment.data)
            #expect(boxes[0].type == "styp")
        }

        // Duration sum ≈ 8s
        let totalDur = emitted.reduce(0.0) {
            $0 + $1.duration
        }
        #expect(abs(totalDur - 8.0) < 1.0)
    }

    // MARK: - Webradio DVR

    @Test("Webradio DVR: 12s audio → ring buffer with eviction")
    func webradioDVR() async throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let segConfig = LiveSegmenterConfiguration(
            targetDuration: 2.0,
            ringBufferSize: 3,
            keyframeAligned: false
        )
        let segmenter = AudioSegmenter(
            audioConfig: config,
            configuration: segConfig
        )

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        // ~12s of audio
        let frameCount = Int(12.0 * 48000.0 / 1024.0)
        let frames = EncodedFrameFactory.audioFrames(
            count: frameCount
        )
        for frame in frames {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let emitted = await collector.value
        #expect(emitted.count >= 5)

        // Ring buffer holds at most 3
        let recent = await segmenter.recentSegments
        #expect(recent.count <= 3)

        // Eviction happened: oldest in buffer > 0
        if let oldest = recent.first {
            #expect(oldest.index > 0)
        }
    }

    // MARK: - Multi-Bitrate Video

    @Test("Multi-bitrate: 3 quality levels from same source")
    func multiBitrateVideo() async throws {
        let configs: [(Int, Int)] = [
            (640, 360), (1280, 720), (1920, 1080)
        ]
        var initSizes: [Int] = []

        for (width, height) in configs {
            let videoConfig = CMAFWriter.VideoConfig(
                codec: .h264,
                width: width, height: height,
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
                    var out: [VideoSegmenter.SegmentOutput] = []
                    for await o in segmenter.segmentOutputs {
                        out.append(o)
                    }
                    return out
                }

            let frames = EncodedFrameFactory.videoFrames(
                count: 60, fps: 30.0, keyframeInterval: 30
            )
            for frame in frames {
                try await segmenter.ingestVideo(frame)
            }
            _ = try await segmenter.finish()

            let outputs = await collector.value
            #expect(outputs.count >= 1)
            initSizes.append(
                segmenter.videoInitSegment.count
            )
        }

        // All 3 produced init segments
        #expect(initSizes.count == 3)
        // All init segments have valid size
        for size in initSizes {
            #expect(size > 0)
        }
    }

    // MARK: - Ad Break

    @Test("Ad break: forceSegmentBoundary creates split")
    func adBreakBoundary() async throws {
        let config = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let segConfig = LiveSegmenterConfiguration(
            targetDuration: 6.0,
            keyframeAligned: false
        )
        let segmenter = AudioSegmenter(
            audioConfig: config,
            configuration: segConfig
        )

        let collector = Task<[LiveSegment], Never> {
            var emitted: [LiveSegment] = []
            for await segment in segmenter.segments {
                emitted.append(segment)
            }
            return emitted
        }

        // Ingest ~3s of audio
        let preAdFrames = Int(3.0 * 48000.0 / 1024.0)
        let frames1 = EncodedFrameFactory.audioFrames(
            count: preAdFrames
        )
        for frame in frames1 {
            try await segmenter.ingest(frame)
        }

        // Ad break: force boundary
        try await segmenter.forceSegmentBoundary()

        // Continue with more audio
        let lastTS = frames1.last?.timestamp.seconds ?? 0
        let frameDur = 1024.0 / 48000.0
        let frames2 = EncodedFrameFactory.audioFrames(
            count: preAdFrames,
            startTimestamp: lastTS + frameDur
        )
        for frame in frames2 {
            try await segmenter.ingest(frame)
        }
        _ = try await segmenter.finish()

        let emitted = await collector.value
        #expect(emitted.count >= 2)

        // First segment should be shorter (~3s)
        let firstDur = emitted[0].duration
        #expect(firstDur < 5.0)
    }

    // MARK: - CMAF Compliance

    @Test("CMAF brands: cmfc in init, msdh in styp")
    func cmafBrandCompliance() throws {
        let writer = CMAFWriter()

        // Audio init: cmfc brand
        let audioConfig = CMAFWriter.AudioConfig(
            sampleRate: 48000, channels: 2
        )
        let audioInit = writer.generateAudioInitSegment(
            config: audioConfig
        )
        let audioBoxes = try readBoxes(from: audioInit)
        let audioFtyp = try #require(audioBoxes.first)
        let audioPayload = try #require(audioFtyp.payload)
        #expect(containsFourCC("cmfc", in: audioPayload))

        // Video init: cmfc brand
        let videoConfig = CMAFWriter.VideoConfig(
            codec: .h264,
            width: 1280, height: 720,
            sps: Data([0x67, 0x42, 0xC0, 0x1E]),
            pps: Data([0x68, 0xCE, 0x38, 0x80])
        )
        let videoInit = writer.generateVideoInitSegment(
            config: videoConfig
        )
        let videoBoxes = try readBoxes(from: videoInit)
        let videoFtyp = try #require(videoBoxes.first)
        let videoPayload = try #require(videoFtyp.payload)
        #expect(containsFourCC("cmfc", in: videoPayload))

        // Media segment: msdh brand in styp
        let frame = EncodedFrameFactory.audioFrame(
            timestamp: 0.0
        )
        let mediaSeg = writer.generateMediaSegment(
            frames: [frame],
            sequenceNumber: 1,
            timescale: 48000
        )
        let mediaBoxes = try readBoxes(from: mediaSeg)
        let styp = try #require(mediaBoxes.first)
        let stypPayload = try #require(styp.payload)
        #expect(containsFourCC("msdh", in: stypPayload))
    }
}
